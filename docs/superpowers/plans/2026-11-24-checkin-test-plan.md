# Check-in: test plan before the event

The Baby Steps Camino runs Friday 4 to Sunday 6 December 2026. Check-in has to be rock solid, with no data loss. This plan says what that means, what reading the code turned up, and the tests, fixes and event-day measures that get us there. Written 2026-11-24 against register version 19 (44d512e).

## What "no data loss" means here

1. Every check-in a volunteer or a pilgrim was told succeeded is on the ship afterwards, on the right person and the right day.
2. Nothing sits silently on a phone. A tap that has not reached the ship is visible as waiting, and it reaches the ship once there is signal, even after the app is closed, the phone restarts, or the login lapses.
3. If the ship itself fails, nothing acknowledged is lost, and check-in carries on (offline on the phones, or on paper) until it is back.

## How check-in works today

Three ways in, one writer.

- **Volunteer app** (`/apps/register/checkin`, `checkin.js`). Owner login. A roster per day, refetched every 60 s and kept in `localStorage`. Each tap goes into a queue in `localStorage` (`register.queue`), a newer tap on the same person replaces the older one, and the queue drains every 15 s and on `online`, up to 200 a batch, to `POST /api/checkin`. A service worker (`sw.js`) caches the shell so the app opens with no signal.
- **Pilgrim's own link** (`#checkin/<rid>/<token>`, `POST /api/reg/<rid>/checkin`). Only on the event day, only adds, never undoes.
- **Backoffice Today screen**, with per-person and per-party buttons and the morning "Email Friday's check-in links" button (100 per press).

On the ship, `apply-checkins` sends one writer poke per item and waits for its ack. A refused poke comes back as "the ship did not take this tap", and the phone keeps the item and sends it again. A tap that changes nothing writes nothing, so a repeat is harmless.

## What reading the code turned up

These are the risks the tests below are aimed at, most serious first.

**R1. Queued taps can land on the wrong day (likely bug).** Each queued tap carries its own `day`, but `drainBatch` (`checkin.js`, about line 389) posts the whole batch under the screen's current day: `post('/checkin', {day: day, checkins: ...})`, and the items sent do not carry theirs. Two ways this bites: a phone offline at the end of Friday that reopens Saturday morning (the app opens on the event's own day) sends Friday's taps as Saturday check-ins, and a volunteer who switches the day tab while taps are waiting does the same. Fix: send each item's own day, or drain one day per batch. Needs a test in `checkin-test.js` and a ship-side check.

**R2. The time recorded is when the ship heard the tap, not when it was made.** The batch carries only `rid`, `i` and `undo`. A tap made offline at 7:05 and sent at 9:40 reads 9:40, and `by` is the sending session, not the tap's own. Not loss, but the record is wrong in a way organizers will notice. Decided 2026-11-24: the time the ship heard it is fine. No change.

**R3. Login lasts seven days.** The ship's cookie is `Max-Age=604800`. A phone logged in on Saturday 28 November locks on Saturday 5 December. The app stops draining and shows "log in again" (the queue survives in `localStorage`), but a volunteer at the start line may not have the code. Mitigation: everyone logs in fresh on Thursday 3 December, and the code is on the volunteer lead's card. Test that a relogin drains what waited.

**R4. Self check-in answers before the writer applies.** `serve-self-checkin` paints the answer from the same rule the writer runs, after the poke is acked but before the writer's change is certain to be on disk. If the ship dies in that gap, the pilgrim was told they are in and the record may say not. Needs the crash test in phase 3.

**R5. The comet under a morning rush.** On 16 November two heavy reads kept the comet's serf at 100% for several minutes. Friday morning stacks many phones refetching the roster every 60 s, draining every 15 s, self check-ins, and the mail button, on a comet that shares asimov with ~ricsul-bilwyt. Nobody has measured how it holds up.

**R6. A restart takes minutes.** vere 4.6 sometimes segfaults. gwsup brings the comet back, but on 4 October the comet took more than 6 minutes to open its sockets after a reboot. During that time the self check-in links fail outright; only the volunteer app's queue absorbs it.

**R7. Phone storage is not guaranteed.** Private browsing, a cleared browser, or iOS evicting a site's storage loses whatever was queued and not sent. The badge shows the count waiting, which is the only warning.

**R8. The test ship does not match production.** ~tev runs grubbery eed73a6; the comet runs the moved kernel. Version 18 onward builds only on the moved kernel, so nothing since 16 November has run on a test ship.

## Phase 0: a test ship that matches production (half a day)

1. Bring the `register` fleet set (~tev) to the kernel the comet runs. Read the comet's grubbery commit first; the 14 November rollout was dist 33da424.
2. Install register 19 with `scripts/dev-deploy.py`, approve its weir, confirm `/apps/register` answers 200.
3. Load a copy of production: import the `bundle.jam` from `~/register-backups/pre-v19-20261124-1533/` through the Backup page's restore. Then, **before anything else**, confirm Settings, Providers, Mode reads `stub`, so no email can leave the test ship. The bundle leaves keys out, but check the mode by eye.
4. Snapshot it: `fleet snap register prod-copy`. Every test run starts from that snapshot.

## Phase 1: fixes (a day)

1. R1: drain per day, or carry the day per item, so a tap is always recorded on the day it was made. Add fixture tests to `checkin-test.js`: a Friday tap drained on Saturday stays Friday; a day switch with taps waiting.
2. Release as version 20 using the 24 November recipe: export, push, rebuild, export again, diff every registration.

## Phase 2: behaviour on the test ship (a day)

Each test states what must be true afterwards, read from the ship (`/api/admin/regs` and the per-registration record), not from the phone.

1. **Online taps.** Two volunteers in two browsers check in the same 50 people, some twice, some with an undo. Afterwards each person is checked in or not exactly as the last action said, with one history line per real change.
2. **Offline and back.** Go offline (DevTools, then a real phone in airplane mode), tap 30 people, close the tab, reopen it offline, see 30 waiting, come back online. All 30 on the ship, none twice.
3. **Across midnight (R1).** Queue Friday taps offline, move the event days so the phone opens on Saturday, go online. Every tap is on Friday.
4. **Day switch with taps waiting (R1).** Same, by switching the tab by hand.
5. **Login lapses (R3).** Expire the session with taps waiting. The app asks for the login; after it, the queue drains and nothing is lost.
6. **Self check-in.** A party of four checks in two people from the link, then the other two later. A volunteer then undoes one. Afterwards the record matches, and the link shows the right state.
7. **Mail button.** In stub mode, press "Email Friday's check-in links" until none remain. Every complete party expected Friday gets exactly one history line; a second press sends nothing; `again` sends to those not yet in.
8. **Bad input.** A tap on a cancelled registration, a person index out of range, a registration added after the phone's roster fetch. Each is named, parked with its reason, and nothing else in its batch is lost.
9. **The existing scripts**, pointed at ~tev with `REG_BASE`: `checkin-click.js`, `public-checkin-click.js`, `weekend-sim.py` (43 checks), `api-matrix.py`, `page-smoke.py`.

## Phase 3: durability under failure (half a day)

A small script fires taps and self check-ins at ~tev and logs every one the ship acknowledged. Mid-burst, `kill -9` the ship's vere (king and serf), restart it from its pier, and compare the log of acknowledged writes with what the ship holds.

- Pass: every acknowledged volunteer tap and every acknowledged self check-in is present (R4). Unacknowledged ones are either present or still in the phone's queue, never silently gone.
- Run it five times at different points in the burst. Repeat with the ship stopped for 10 minutes, to stand in for a slow restart (R6), with the volunteer app open the whole time.

## Phase 4: load (half a day)

On ~tev with the production copy, simulate Friday morning at the start line for 30 minutes:

- 8 volunteer phones, each refetching the roster every 60 s and draining every 15 s, together checking in about 350 people in the first 20 minutes;
- 150 self check-ins over the same window;
- the mail button pressed until none remain, at the start.

Measure the time to answer a tap batch, a roster fetch and a self check-in, the serf's CPU, and its memory against the loom. Pass: no tap batch over 10 s at the median or 30 s at the worst, no error, and phase 2's read-back still exact. If it fails, the levers are a slower roster refetch, smaller batches, and a heavier loom on the comet.

## Phase 5: real phones (half a day)

A service worker needs HTTPS, so the phones reach the test ship over Tailscale: `tailscale serve` on the laptop gives ~tev an HTTPS address on the tailnet, and the phones join the tailnet.

On an iPhone (Safari, and added to the home screen) and an Android phone (Chrome):

1. Open the volunteer app with signal, then airplane mode, then kill the app and reopen it. The roster is there and taps queue.
2. Restart the phone with taps waiting. They are still waiting, and they go up with signal.
3. A pilgrim's link from a real email in a real mail app, opened on the day.
4. The "Saved on this phone" and waiting badge read clearly in sunlight.

## Phase 6: the weekend itself

sneagan takes the backups by hand, so there is no backup job, watch or pier copy. What remains:

1. **Freeze.** No releases from Wednesday 2 December until Monday 7 December, except to fix a check-in failure, and then only by the release recipe (export, push, rebuild, export again, diff every registration).
2. **Dress rehearsal on production, Thursday 3 December.** An organizer adds a test registration, a volunteer checks it in and undoes it from a phone at the start line, then the registration is cancelled. Everyone who will use the volunteer app logs in fresh then (R3).
3. **Paper, suggested.** Each day's roster printed from `people.csv`, for the start line if the ship is down.
4. **If the ship goes down.** Volunteers keep tapping: the app queues offline. Pilgrims with links are sent to a volunteer. Restart by the asimov procedure (`boot.sh --stop`, relaunch in `ships:7`, adopt).

## Acceptance

Check-in is ready when phases 2 to 5 pass on a ship that matches production, and R1 is fixed and released. No release goes out with a known way to lose or mislabel a check-in.

## Proposed schedule

| Day | Work |
|---|---|
| Tue 24 Nov | This plan |
| Wed 25 Nov | Phase 0, phase 1 fixes |
| Thu 26 Nov | Thanksgiving: nothing scheduled |
| Fri 27 Nov | Release 20, phase 2 |
| Sat 28 Nov | Phases 3 and 4 |
| Mon 30 Nov | Phase 5 on real phones |
| Tue 1 Dec | Fixes from the tests |
| Wed 2 Dec | Freeze |
| Thu 3 Dec | Dress rehearsal, fresh logins |
| Fri 4 to Sun 6 Dec | The event |

## Decisions (sneagan, 2026-11-24)

1. R2: the time the ship heard the tap is fine.
2. Phase 5: the test ship reaches the phones over Tailscale.
3. and 4. No backup job, watch or pier copy: sneagan takes backups by hand. The work is making sure no data-loss bug ships.
