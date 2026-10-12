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
| grubbery | the dev platform's pin (hoon-development `platform/grubbery.ref`) |
| register | a dev desk at `/apps/shell.shell/desks/register.desk`, the path a real ship uses, following `/register-dev/code` in the ball; weir approved, stub mode |
| test desk | `%register-test`, mounted, set up for the kit |

Below, `F=~/software/personal/hoon-development/fleet/fleet` and
`U=~/software/personal/hoon-development/bridge/u`. Set `FLEET_WHO` to
your session's name so claims know who is asking.

## Reset

```sh
$F reset register compiled   # register installed and approved, test desk set up
$F reset register            # golden: grubbery and %unix, no register
$F ls                        # is ~tev up?
$F up register               # restart it from its event log (vere 4.6 sometimes segfaults)
$F down register             # stop it when you are done
```

Start every test from `compiled`. Refresh it after a deploy that tests
should start from: `$F snap register compiled`. For a throwaway point,
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
$F reset register compiled
```

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
(the PNGs by the explorer's multipart upload, so they stay `%mime`) and
stamps that tree's `version.json` with a dev version, which makes the
desk pull. It refuses any ship that is not on localhost. A release that
adds a road needs approving again: `--approve` posts the roads of the
instance's own `weir.json` as `granted` to `/apps/grubbery/permits`
(`approve-weir`), culls a fiber that parked while jailed, and reloads its
permits.

How `compiled` was made, from the golden: `dev-deploy.py ... --add
--approve`, then the test desk.

## Looking inside with u

```sh
$U register our
$U register kids /register-dev/code
$U register kids /apps/shell.shell/desks/register.desk/desk/data/register.register_app
$U register file /apps/shell.shell/desks/register.desk/desk/code/version.json
```

`u` guards its subcommands. A raw `.^` in an expression that misses kills
every thread on the ship: check a path with `kids` first. Never point u,
the fleet commands or these scripts at a ship outside `register`.
