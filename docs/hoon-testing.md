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

`DIALECT` stays at its clay default. `code/lib/register.hoon` is
import-free by design, with no `/<` and no `/&`, so none of the kit's
grubbery translation applies to it and the suite's `/+ *test, reg=register`
resolves the ordinary way. The whole config is the desk name, the one
library, and the tests directory.

The suite is 47 arms over a 1,802-line library.

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
consuming them. **It needs `/sys/behn/` in `weir.json`**, which is a new
permission and so a re-approval on every ship that runs register. That is
a decision, not a tidy-up, and it is not made here.

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

## What to do next, in order

1. Start a fake ship, run `setup`, and take a baseline: `hoon-test.sh`
   should exit 0 with 47 `OK` lines.
2. Run the cheap mutation pass over the library and triage every
   survivor. Re-trace each one before writing a test: many are equivalent,
   and the playbook lists the usual kinds.
3. Run `--ops branch,equal,flag`, checking the no-build rate per op first.
4. Write what the run found back into this file.
5. Decide on finding 1. It is the only one that can lose a registration.
