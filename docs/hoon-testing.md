# Testing register's Hoon

Register's suite runs through [hoon-test-kit](https://github.com/nisfeb/hoon-test-kit),
vendored at `scripts/hoon-test-kit/` and configured by `hoon-test.conf` at
the repo root. The kit runs every `test-` arm on a fake ship over its
`conn.sock`, with no dojo, in seconds rather than the minutes a commit to
the app's own desk costs. It also mutation-tests the library: it breaks one
thing at a time and reports every break no test noticed.

Read the kit's `PLAYBOOK.md` before the first run. This file is register's
own half: how the suite is set up here, and what an audit against the
playbook found.

## Running it

Once per ship, in that ship's dojo:

```
|new-desk %register-test
|mount %register-test
```

then from the repo:

```sh
scripts/hoon-test-kit/hoon-test.sh <pier> setup     # once
scripts/hoon-test-kit/hoon-test.sh <pier>           # every suite
scripts/hoon-test-kit/hoon-test.sh <pier> register  # just this file
```

Exit 0 is a pass. Exit 3 means the library did not build, and the
compiler's message is only on the ship's terminal. **Exit 4 means the ship
did not answer and is never a test result**: stop and say so.

Sizing a mutation run before starting it is not optional, because each
mutant costs a commit and every commit costs the ship loom:

```sh
scripts/hoon-test-kit/hoon-mutate.py <pier> --list
scripts/hoon-test-kit/hoon-mutate.py <pier>                    # boundary,conjunct
scripts/hoon-test-kit/hoon-mutate.py <pier> --since HEAD~1     # only what a change touched
```

## How register is configured

`DIALECT` stays at its clay default. All four of register's libraries are
import-free by design, with no `/<` and no `/&`, so none of the kit's
grubbery translation applies to them and the suite's
`/+ *test, reg=register` resolves the ordinary way. The whole config is
the desk name, the libraries, and the tests directory.

The suite is 90 arms over five libraries: `register.hoon` (the event and
its rules), and phase 2's `register-http.hoon` (percent-encoding and form
bodies), `register-stripe.hoon` (the Checkout calls, built and read) and
`register-mail.hoon` (the Resend send) and `register-places.hoon` (the
address suggestions). The three new ones are pure text
in and pure text out, which is the whole reason they are libraries: an
outbound call is untestable, but everything that decides what goes out
and what comes back is not.

**The nexus is not under test.** `code/nex/register/app.hoon` is 1,940
lines and nothing in it is reached by a unit test today; the HTTP gate
(`scripts/api-matrix.py`) covers it, and that needs a live ship. Putting it
under test means `DIALECT=grubbery`, a `PRELUDE` and `SHIP_FILES` for the
faces grubbery gives a nexus, and driving its fibers through
`hoon/fiber-test.hoon`, entering at `+on-file`. The playbook's "Testing
nexus code" is the order to do it in, cheapest first.

## What an audit against the crash-loop rules found

The playbook's "Never ship a crash loop" comes from calendar releases that
locked their users' ships. Register was read against all eight rules on
2026-09-29 without a ship to test on, so these are findings from the code,
not from a run. Two are worth acting on.

### 1. A crashed writer swallows the next real poke, silently

All three of register's long-lived fibers restart with `rise-wait:io`.
That arm waits for a poke and **consumes it without processing it**;
grubbery's own comment says so, and `+take-poke` answers `[%done sage]`,
which acks the sender. Register's writer is poked for every mutation.

So after any writer crash, the next poke to arrive is acked and dropped.
The request fiber that sent it used `poke-soft:io`, saw no error, and
answers the pilgrim 200. A submit, a payment or a cancellation is lost
with nothing on screen to say so, and `/tr/last` records nothing because
the writer never ran the op.

The writer is written never to crash on input, so this needs an
unexpected crash first. It is still the worst failure register has: it
loses a registration and reports success.

The fix is calendar's shape, named in the playbook: `+rise-later`,
`+soft-behn`, `+soft-now` and `+rise-park`, which park on a timer instead
of eating a poke, back off, and refuse pokes while crashed rather than
consuming them.

**The reason this was deferred is gone.** It needed `/sys/behn/` in
`weir.json`, a new permission and so a re-approval on every ship. Version
15 asks for behn anyway, for the deadline on an outbound call, and every
ship running register has already been re-approved for it. The fix is now
an ordinary change to the three fibers' first step, with no permission
consequence. It is the next thing to do here.

### 2. The HTTP binder and the request fibers park until a reload

`rise-wait` waits for a poke, and **nobody pokes `web.sig` or a request
grub**. If either crashes it stays down until the nexus is reloaded: for
`web.sig` that means the whole app stops answering, with the worker idle
rather than spinning. The playbook names this case exactly. The same fix
covers it.

### 3. The rules register already keeps

- **Rule 1**, a restartable fiber's first step takes the kick and never
  sends: all three start with `rise-wait`, which sends nothing.
- **Rule 4**, everything at start is total over old data: every read of a
  stored noun goes through `mole`. `+read-reg` tries each stored shape
  under `mole`, `+cue-bundle` cues under `mole`, `+de-settings` falls back
  on every field, and `+with-starter` fills in copy a release added.
- **Rule 5**, data-driven loops are capped: check-in batches at 200, the
  morning mail at 100, the audit ring at 2,000, a party at 12 people.
- **Rule 6**, validate at the door: `+de-input` caps every string and
  refuses what it cannot read, naming the field.
- **Rule 7**, test the upgrade rather than just the new code: version 14
  changed the stored registration from `%2` to `%3`, and the lift was
  proved on the comet against three real registrations, which kept their
  history and their fees. Do this for every shape change.
- Register asks for no timers at all, so none of the timer traps apply.

**Rule 8, a refusing weir, has not been tested.** On a test ship, remove
`/sys/eyre/` and then `/sys/bowl.sig` from the instance's poke weir and
watch: register should park with the worker near 0% CPU, never spin.
Measure from `/proc/<pid>/stat` deltas, not `ps %cpu`.

## The first baseline and mutation run, 2026-09-29

On `~feb`, against the library at version 14.

**A note on wet gates and narrowed lists.** `+site-url` first read the
last character of the public url with `(snag n raw)` after `?~ raw`.
That does not compile: `snag`, `scag` and `rear` are wet and rebind the
list to its own tail, which a `?~`-narrowed non-empty type refuses with
`mull-grow` / `nest-fail`. Test the length instead of narrowing.

**The baseline found three breaks in five seconds**, all of them in tests
written while no ship was up to run them: a stored-shape head still
reading `%2` after the change to `%3`, two arms reading `i.people.r`
where the list's type is a fork so it could not compile, and the pinned
CSV width, which really had changed from 45 columns to 48. The suite now
runs green, 47 arms in about 4.5 seconds.

**The cheap mutation pass** (`boundary,conjunct`, 94 sites, 145 mutants)
came back 40 killed, 95 survived, 2 no-build, 8 timed out. The full log is
`docs/mutation-2026-09-29.log`. Nothing here is triaged yet, and the
playbook is clear that many survivors are equivalent rather than gaps.
The clusters worth reading first:

| arm | survivors | what the mutants drop |
|---|---|---|
| `+en-roster-person` | 6 | the day gate on Mass, the Holy Hour, the trolley and the Sunday distance |
| `+planned` | 5 | the same gates in the day's counts |
| `+de-iso` | 5 | the month, day and hour bounds |
| `+is-email` | 4 | the parts of an address |
| `+window-open` | 3 | each end of the registration window |
| `+walks` | 3 | each day of the walk |

The `+en-roster-person` and `+planned` clusters are one gap wearing two
hats: **no test pins what each day's encoder shows on the other two
days**, so dropping `=(%fri day)` from a Friday-only flag changes nothing
any test reads. `+de-iso`'s five say no test parses a date in January, on
the 31st, or at 23:59. Those are the two to close first, and closing them
is one table test each.

**8 mutants spun the ship.** `DOJO_PANE` typed the interrupt and the run
went on, which is what it is for; without it the run stops at the first
one. A spin is not a verdict, so those 8 are unjudged.

## The phase-2 pass, 2026-09-29

`--since HEAD~1` over the phase-2 change: 21 mutants, 7 survived, 1 timed
out. Two were real, both in `+url-encode`, and both the same shape: the
suite's "plain" fixture was `abcXYZ019-._~`, which happens to contain
neither `z` nor `A`, so a mutant could shrink the lower-case range at
its top or the upper-case range at its bottom and no test noticed.
`+test-url-encode-edges` now pins all six ends and the six bytes just
outside them (`@ [ ` { / :`), and `+test-iso-bounds` does the same for
`+de-iso`'s month, day and clock. That took the two arms from 7
survivors to 1.

**The one that remains is equivalent, and worth writing down.**
`(lth h 24)` mutated to `lte` still rejects `2026-01-01T24:00:00Z`,
because `+year` normalizes hour 24 into the next day and the arm's last
line re-encodes the result and compares its first ten bytes with the
input's. The date no longer matches, so the parse fails anyway. A bound
standing behind a round-trip check cannot be killed by moving it; the
check is the real guard.

**`--since` was broken before this run.** `+touched_arms` unpacked a
`LIBS` entry as a pair when entries have been triples for some time, so
every `--since` died on the unpack. Fixed in the kit and re-vendored.

## The review pass, 2026-09-29

The suite is 79 arms. What the gate and the click-throughs found when
they were pointed at version 15 is in the commit; two of it is worth
keeping here because it is about how this app is tested, not about the
app.

**A click-through's fixed sleep is a test that lies.** `public-edit-click`
slept 250 ms after pressing a preview and then read what was on screen.
On a busy ship that was too short, and the failure it produced was
"every string a pilgrim reads is editable" naming forty-nine perfectly
editable strings. The preview's ribbon now carries `data-step`, and the
script waits for the one it asked for. The same lesson as the check-in
click-throughs, learned again.

**A shot of one card must be an element screenshot.**
`page.screenshot({clip})` measures from the top of the document;
`getBoundingClientRect` measures from the top of the window. Every
close-up below the fold was therefore a picture of whatever sat at those
document coordinates, with the sticky nav painted through the middle.
`docs/manual/cards.js` owns every close-up now and takes them as
elements.

## Iris will not carry a space in a url, 2026-09-30

Worth writing down because it cost an hour and the symptom points
nowhere near the cause. The address suggestions call Photon with a
search term. One word worked. Two words came back as a bare nginx
`400 Bad Request` from the far end, with no clue in it.

It is not the far end. The same url from `curl` answers 200. Iris
decodes the query string it is handed, finds a space, and puts a raw
space into the request line. **Both spellings of a space go the same
way**, `%20` and `+`, because both decode to one. Every other
percent-escape rides through untouched, which is the way out:
`+space-plus` in `code/lib/register-places.hoon` turns a space into a
literal `+` *before* encoding, so it reaches the far end as `%2B`.
Photon reads that back as a `+` and breaks words on it, and the answers
are identical to a real space.

The shape to recognise: **one word searches fine and two words do not.**
If iris is ever fixed, that arm can go.

`+form-body` also learned to spell a space `+` rather than `%20`, which
is what `application/x-www-form-urlencoded` specifies anyway; `url-encode`
still writes `%20`, which is right for a path.

## The day-gating, pinned at last, 2026-09-30

The first mutation run named this as the gap to close first and it sat
open for a day: **no test pinned what each day's encoder shows on the
other two days.** Dropping `=(%fri day)` off the Holy Hour, or
`=(%sun day)` off the trolley, changed nothing any test read. A ticked
box appearing on the wrong day is a pilgrim counted for a meal they
never asked for, and it is the sort of thing nobody finds until the
morning of the walk.

`+test-roster-row-every-box` and `+test-planned-every-box` are table
tests over four people — one who ticked everything, one who ticked
nothing, one who unticked Sunday with the Sunday answers still stored,
and one who unticked Sunday having never chosen a distance — read across
all three days. `--only en-roster-person,planned` went from **3 killed,
16 survived** to **19 killed, 0 survived**.

The fourth person is the one worth explaining. `sun_short` is
`&(=(%sun day) sun.days.p !sun-ten.p)`, and until somebody in the
fixtures both skipped Sunday *and* never chose the ten miles, dropping
`sun.days.p` changed no count. Two of the four fixtures had to exist
before that gate was tested at all.

They also pin a decision rather than an accident: **the Sunday distance
is gated on actually walking Sunday; the Sunday Mass and the trolley are
not.** Somebody may come to the Cathedral without walking the last
stretch, and the form stops offering a day's events when the day is
unticked without erasing what was already stored. That asymmetry is now
written down in a test instead of living in three arms.

The gate carries the other half: one party ticks every box on the form
and is read back through the record, the three day rosters, the planned
counts and people.csv, against a truth table per day. Eleven checks.

## What to do next, in order

1. Start a fake ship, run `setup`, and take a baseline: `hoon-test.sh`
   should exit 0 with 90 `OK` lines.
2. Run the cheap mutation pass over the library and triage every
   survivor. Re-trace each one before writing a test: many are equivalent,
   and the playbook lists the usual kinds.
3. Run `--ops branch,equal,flag`, checking the no-build rate per op first.
4. Write what the run found back into this file.
5. Decide on finding 1. It is the only one that can lose a registration.
