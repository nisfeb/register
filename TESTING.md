# Testing register

Register is tested on its own fleet set from
[hoon-development](https://github.com/nisfeb/hoon-development), never on
the user-test comet ~hadmyn or any real ship. docs/hoon-testing.md is
the case study behind the Hoon suites; docs/releasing.md says what a
push does.

| | |
|---|---|
| set | `register` (in hoon-development's `fleet/sets.conf`) |
| ship | `~tev`, fake, pier `~/fleet/piers/tev` |
| HTTP | http://localhost:8126 |
| dojo | `tmux attach -t fleet`, window `tev` |
| grubbery | nisfeb/grubbery dist/single-release `900f7bb0`, the kernel the production comet ~hadmyn runs (its `/code/nex/desk.hoon` and `shell.hoon` match from `ae800da2` to `900f7bb0`). Built 2026-11-24 with `GRUBBERY_SRC=<worktree at 900f7bb0> PLATFORM_SET=register platform/build.sh`. The old eed73a6 set is kept as `~/fleet/snaps/register.old-eed73a6/` |
| register | a dev desk at `/apps/shell/desks/register.desk`, the path a real ship uses, following `/register-dev/code` in the ball; weir approved, stub mode |
| test desk | `%register-test`, mounted, set up for the kit |

Below, `F=~/software/personal/hoon-development/fleet/fleet` and
`U=~/software/personal/hoon-development/bridge/u`. Set `FLEET_WHO` to
your session's name so claims know who is asking.

## Reset

```sh
$F reset register prod-copy-v21  # register 21 holding a copy of production (579 registrations, nobody checked in), stub mode
$F reset register prod-copy-v19  # the same copy on register 19, as production ran it on 2026-11-24
$F reset register            # golden: grubbery and %unix, no register
$F ls                        # is ~tev up?
$F up register               # restart it from its event log (vere 4.6 sometimes segfaults)
$F down register             # stop it when you are done
```

The `prod-copy` snapshots hold real attendee data: they are mode 600 and never leave this machine. They were loaded through the Backup page's restore from a production `bundle.jam`, then checked record by record against production's export; `prod-copy-v21` keeps the real event days (4 to 6 December). The gates that make new registrations (`public-checkin-click.js`, `weekend-sim.py`, `api-matrix.py`) need an open window and free places, so run them on the golden with register installed, not on a production copy. For a throwaway point,
`$F --fast snap register before-x` takes seconds.

## Offline tests (no ship)

```sh
scripts/offline-tests.sh                 # all four suites, 95 tests, ~9 s
scripts/offline-tests.sh register-http   # one suite
python3 scripts/hoon-test-kit/offline-test.py tests/lib/register.hoon test-ids   # one arm
node scripts/checkin-test.js             # the pages' pure halves, 201 checks
python3 scripts/code-closure.py code     # code/ is closed under what a guest resolves
```

The Hoon suites run through `vere eval` with the kit's `offline-test.py`.
All four libraries are import-free, so every suite runs offline: register
65, register-http 11, register-mail 5, register-stripe 14. The nexus
(`code/nex/register/app.hoon`) is not under unit test; the HTTP gate
covers it. The ship run is the verdict.

## Ship tests

```sh
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/tev            # all four suites, 95 tests, ~8 s
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/tev register   # one suite
```

The kit finds vere in `~/software`, so `VERE` need not be set. On a fresh
set (golden, or a rebuilt pier) make the test desk once:
`|new-desk %register-test` and `|mount %register-test` in the dojo, then
`scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/tev setup`.

The HTTP gates write registrations, so reset afterwards. Get a cookie
jar first; `compiled` keeps the session it was minted for:

```sh
J=/tmp/tev.jar
scripts/hoon-test-kit/ship-cookie.sh ~/fleet/piers/tev http://localhost:8126 $J
python3 scripts/api-matrix.py http://localhost:8126 $J    # the HTTP gate, stub mode: 332 checks, ~8 min
python3 scripts/page-smoke.py http://localhost:8126       # pages, types, auth: ~5 s
python3 scripts/weekend-sim.py http://localhost:8126 $J   # the event weekend, day by day: 43 checks, ~2 min
$F reset register prod-copy-v21
```

## Check-in tests

The check-in test plan is `docs/superpowers/plans/2026-11-24-checkin-test-plan.md`. On a production copy, with `C` a file holding the one cookie line (`urbauth-~tev=0v...`):

```sh
REG_BASE=http://localhost:8126 REG_COOKIE=$C node scripts/checkin-day-click.js   # R1: offline Friday taps stay Friday after a switch to Saturday
REG_BASE=http://localhost:8126 REG_COOKIE=$C node scripts/checkin-hang-click.js  # R9: a hung request does not stall the queue, ~90 s
REG_BASE=http://localhost:8126 REG_COOKIE=$C node scripts/checkin-login-click.js # R3: a lapsed login (401 and 403) asks for it, keeps the taps, drains after
REG_BASE=http://localhost:8126 REG_COOKIE=$C node scripts/counts-race-click.js   # an open Counts screen never writes over a phone's figures
python3 scripts/checkin-edit-probe.py http://localhost:8126 $J                     # removing a person keeps every check-in with its person; stale phones tap by name
scripts/checkin-crash.sh 30 150    # a burst of taps and self check-ins, kill -9 of ~tev at 30 s, then verify every acked write
python3 scripts/checkin-durability.py http://localhost:8126 $J burst /tmp/c.jsonl --volunteers 3 --editor 1 --seconds 120   # three phones, pilgrims and an organizer re-saving the same parties
python3 scripts/checkin-load.py http://localhost:8126 $J /tmp/l.jsonl --minutes 10 --phones 8 --pier ~/fleet/piers/tev        # Friday morning: beacon-driven rereads, taps, self check-ins, the mail
```

Run `checkin-durability.py ... verify LOG` after a burst or a load run: it fails on any acknowledged check-in the ship does not hold. The crash, concurrency and load runs need self check-in to work today, so move the event days on the test ship first (Settings, or PUT `/api/admin/settings`). Start from `prod-copy-v21`: the earlier `prod-copy-v20` was taken after test bursts and held test check-ins, and is deleted.

`checkin-crash.sh` drives `checkin-durability.py`, which logs every write the ship acknowledged (fsynced per line) and then holds the ship's roster against it: a lost check-in or a surviving undo fails. Self check-ins need today to be an event day on the ship. On 2026-11-24, five crash runs (kill at 5, 15, 30, 45 and 70 s) lost nothing.

Register stays in stub mode here: no Stripe or Resend key is set, so no
card is charged and no mail leaves the ship. `providers.mode` live needs
real test keys and is not exercised on this set.

The click-throughs (`scripts/*-click.js`) drive chromium through
puppeteer-core. They default to `http://localhost:8080`, which is
another set's ship, so always set `REG_BASE`, and give them the cookie
as a `name=value` file in `REG_COOKIE`:

```sh
grep -h urbauth $J | awk '{print $6"="$7}' > /tmp/tev.cookie
export REG_BASE=http://localhost:8126 REG_COOKIE=/tmp/tev.cookie
node scripts/public-form-click.js       # these four need nothing on the ship
node scripts/public-edit-click.js
node scripts/public-checkin-click.js
node scripts/admin-refresh-click.js
node scripts/checkin-click.js <rid> <lastname>   # then admin-click on the same party
node scripts/admin-click.js <rid>
```

`checkin-click.js` wants a complete two-person party whose last name no
other party has; make one through the API the way `weekend-sim.py`'s
`make()` does (submit, sign, pay, all in stub mode). It leaves the two
checked in for Friday, which is what `admin-click.js` wants.

On ~tev `admin-click.js` fails one check, "saying no keeps the page and
the typing": the note it types right after a note save is repainted
away within a second. A note is an op the page does not paint locally,
so the save ends in `later()`, a `refresh()` 400 ms after the write
returns, and `refresh()` repaints the record without asking `dirty`.
On a slow ship the write took longer than the test; on a fast fake one
the race shows.

## Deploying a change to ~tev

```sh
scripts/dev-deploy.py http://localhost:8126 $J
```

It writes the files of `code/` that differ into `/register-dev/code`
through the grubbery API (`peek` to read, `make` to write; the PNGs as their bytes, so they stay `%mime`) and
stamps that tree's `version.json` with a dev version, which makes the
desk pull. It refuses any ship that is not on localhost. A release that
adds a road needs approving again: `--approve` posts the roads of the
instance's own `weir.json` as `granted` to `/apps/grubbery/permits`
(`approve-weir`) and reloads its permits. `--wait` waits for the desk to take the new version and fails if anything under it is banged. `scripts/kernel.py` asks the ship where its shell lives.

A fresh install from the golden: `dev-deploy.py ... --add --wait --approve`.

## Looking inside with u

```sh
$U register our
$U register kids /register-dev/code
$U register kids /apps/shell/desks/register.desk/desk/data/register.register_app
$U register file /apps/shell/desks/register.desk/desk/code/version.json
```

`u` guards its subcommands. A raw `.^` in an expression that misses kills
every thread on the ship: check a path with `kids` first. Never point u,
the fleet commands or these scripts at a ship outside `register`.
