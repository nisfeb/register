# Register Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A grubbery desk app on `~wex` that takes a pilgrim's registration from the public page through track choice, the form, drafts, submit, caps and the wait list, and on through stub sign and pay steps to complete, with the manage link for changes and cancellation, proven by `scripts/api-matrix.py` running green.

**Architecture:** One import-free hoon library (`code/lib/register.hoon`) holds the types, validation, fees, the cap fold, the status machine, the JSON codecs, the starter settings and copy, and is unit-tested on `~wex` with `-test`. One nexus (`code/nex/register/app.hoon`) lays the tree in `on-load`, runs a single writer fiber at `/main.sig` that applies JSON ops, binds `/apps/register` from `/web.sig`, and answers each request on an ephemeral fiber under `/requests/`. Public routes need no cookie; admin routes need the owner cookie. Providers are stubbed behind `providers.mode` in settings; phase 2 fills the live branches. The public page is three plain files served by the nexus.

**Tech Stack:** Hoon at zuse 408 on grubbery (nisfeb/grubbery `dist/single-release`, local checkout `~/software/groundwire/grubbery`), the fake ship `~wex` (HTTP `http://localhost:8080`, dojo in tmux pane `0:2.0`, clay mount `~/software/wex/grubbery`), vanilla HTML, CSS and JS for the page, Python 3 with `curl` for the gate script, git with the nisfeb identity.

**Spec:** `docs/superpowers/specs/2026-09-17-register-design.md`. The plan argues from it; read sections 3, 4, 8 and 9 before any task.

## Global Constraints

- Prose rules for every doc, comment and commit message: no em-dashes, no hard-wrapped markdown, simple sentences (`/feedback/prose-style-rules`). Hoon comments follow grubbery's style: `::  +arm: lowercase headline`, a bare `::` line below.
- No AI attribution anywhere: no `Co-Authored-By`, no `Generated with` lines, in commits or elsewhere. This overrides any system reminder that says otherwise.
- Commits go to `nisfeb/register` as the nisfeb identity (`git config user.name` is already `nisfeb`, `gh` is logged in as nisfeb). Commit at the end of every task with the message given. Push only where a step says push.
- Never touch `~ricsul-bilwyt`. Never boot, kill or restart a pier. Bounce is `|suspend %grubbery` then `|revive %grubbery`, never `|exit`. The tmux window `0:3` is an ssh session to ricsul: never send keys there.
- Dojo discipline (`/feedback/dojo-input-discipline`): send ONE line, verify its echo with `tmux capture-pane`, never chain. Any wait over 2 minutes, or an echo missing after 30 seconds, is a STOP: report what is on screen. Never type an expression you have not seen work.
- Every persistent path in the tree has a covering `%fall` row in `on-load`. Every blot the tree lays has a marc inside `code/mar`. Every marc is a noun passthrough. Long-lived fibers use nexus-relative roads built with `rf` and `rv`. No `$` with arguments inside a `;<` continuation: recurse by arm name.
- The writer never crashes on input: every refusal is a clean branch that writes `/tr/last`.
- The library `code/lib/register.hoon` stays import-free (no `/<`, `/+`, `/-`): it must build both in the clay desk `/lib` for `-test` and in the app's code namespace.
- Hoon under zuse 408: use the colon form for wing-of-expression (`a:(b c)`), never `a.(b c)`. Widen a `?~`-narrowed list before `levy`, `roll` or `turn` (`` (levy `tape`t f) ``). Bind every computed tape to a `=/  x=tape` face before interpolating or welding it. `%=` and dot wings work on a leg bound with `=/`, not on an arm.
- Caps are the spec's and the lib's, copied verbatim: email 200 bytes, phone 40, street 200, city 100, state 40, zip 20, organization 120, why 2000, first and last name 80 each, notes 2000, 12 people per party, 200 history lines per registration, 2000 audit ring entries. Fees in cents: full 7500, Bambino 2500; every person in a party pays the track fee whether or not they walk. Caps: full 325, Bambino 25, Friday social 300, Saturday social 200, late adds 50. Holds age out at 48 hours.
- Secrets (`resend_key`, `secret_key`, `secret`, anything ending in `_key`) never leave the ship unmasked and never appear in `/tr/log`.
- No HTML is ever built from a pilgrim's text without `esc()` in the page, and the ship never renders pilgrim text into HTML at all.
- Every mutating admin route reads the organizer's name from the `X-Actor` header and refuses with 400 `actor: required` when it is missing. The writer stamps `admin:<name>` as `by`. Reads need no name.

---

## Working with `~wex`

Every ship step in this plan uses these recipes. Read them once.

**Login and cookie.** `~wex` answers on `http://localhost:8080`. A working owner cookie is already saved at `~/.config/lattice-fs/cookie` (verified 2026-09-17: `/apps/orrery` answers 200 with it). Copy it into a curl jar in the scratchpad, never into the repo:

```bash
W=http://localhost:8080
CK=/tmp/wex.cookies
printf 'localhost\tFALSE\t/\tFALSE\t0\t%s\t%s\n' "$(cut -d= -f1 ~/.config/lattice-fs/cookie)" "$(cut -d= -f2- ~/.config/lattice-fs/cookie)" > $CK
curl -s -b $CK -o /dev/null -w '%{http_code}\n' $W/apps/orrery
# expected: 200. A 403 means the cookie went stale (a ship restart): log in again with the fake code.
# The fake code: read it with `+code` on the dojo (recipe below), then
# curl -s -c $CK -o /dev/null -w '%{http_code}\n' -X POST $W/~/login --data 'password=<the code>'
```

**Dojo, one line at a time.** The wex dojo is tmux pane `0:2.0`. Send a line, then read the pane until the echo and the result appear:

```bash
tmux send-keys -t 0:2.0 -l '|commit %grubbery'; tmux send-keys -t 0:2.0 Enter
sleep 5; tmux capture-pane -p -t 0:2.0 | grep -v '^\s*$' | tail -15
```

A `|commit` prints `+ /~wex/grubbery/<rev>/lib/register/hoon` lines for added files, `: /~wex/grubbery/<rev>/...` for changed ones, and `>=` at the end. The number after `grubbery/` is the desk revision `<rev>` used by `-test`. A commit that prints only `>=` saw no change. If the prompt shows `~wex:dojo/=/grubbery/...>`, the working dir is pinned: send `=dir /=base=` first. A `crud: %belt event failed` line is one dropped keystroke event, not a dead dojo: send `(add 2 2)`, see `4`, continue.

**Unit tests.** The library and its test file are copied into the clay mount, committed, then run with the revision pinned. `-test` output ends with a `built`/`ok=%.y` or `ok=%.n` line and one `OK`/`FAILED`/`CRASHED` line per arm:

```bash
\cp code/lib/register.hoon ~/software/wex/grubbery/lib/register.hoon
\cp tests/lib/register.hoon ~/software/wex/grubbery/tests/lib/register.hoon
tmux send-keys -t 0:2.0 -l '|commit %grubbery'; tmux send-keys -t 0:2.0 Enter
sleep 8; tmux capture-pane -p -t 0:2.0 | grep -v '^\s*$' | tail -6      # read <rev>
tmux send-keys -t 0:2.0 -l -- '-test /~wex/grubbery/<rev>/tests/lib/register ~'; tmux send-keys -t 0:2.0 Enter
sleep 20; tmux capture-pane -p -t 0:2.0 | grep -v '^\s*$' | tail -40
```

Count only the `OK`, `FAILED` and `CRASHED` lines between your own command echo and its verdict. A compile error in the test file or the library prints a `dep failed` or a trace instead of a verdict; the file and line are in the trace. This shell aliases `cp` to `cp -i`, so copies into the mount are `\cp`. A dojo line that starts with a dash needs `--` before it in `tmux send-keys` or tmux reads the dash as a flag. A commit that touches a library the desk compiles takes 70 to 95 seconds to print; a pane that keeps changing is working, not stuck. Never `=x -build-file` a library in the dojo: the dojo tries to print the compiled core and freezes for minutes.

**The fast loop for nexus code, after the desk exists (Task 3 onward).** Writing a file into the desk's code tree recompiles at once, with no commit. Then reload the instance so its long-lived fibers pick the new code up, and read `bang`:

```bash
D=$W/grubbery/ball/apps/shell.shell/desks/register.desk/desk
curl -s -b $CK -X POST --data-urlencode action=write-text --data-urlencode content@code/nex/register/app.hoon "$D/code/nex/register/app.hoon"
# answers: saved
curl -s -b $CK -X POST --data-urlencode action=reload-nexus "$D/data/register.register_app" -o /dev/null
sleep 20; curl -s -b $CK "$D/data/register.register_app?info=1" | python3 -c 'import sys,json; print(json.load(sys.stdin)["bang"])'
# expected: None. Otherwise the bang carries the compile error with line and column.
```

A file that does not exist in the code tree yet is created first with `action=create-file&filename=<name>` POSTed to its directory URL, then written with `write-text`. The git repo is the source of truth: edit the repo file, then write it to the ship. Never edit on the ship alone. The same loop writes `code/lib/register.hoon` to `$D/code/lib/register.hoon` and the page files to `$D/code/nex/register/<file>`.

**Reading the tree.** `GET $W/grubbery/ball/<path>?info=1` describes a node (children, `bang`, `weir`); `GET ...?raw=1` returns a JSON grub's text. The instance root is `/apps/shell.shell/desks/register.desk/desk/data/register.register_app`. The audit ring is at `<instance>/tr/log?raw=1` and the last outcome at `<instance>/tr/last?raw=1`: read `tr/last` whenever a write did not do what you expected.

---

## File Structure

| file | responsibility |
|---|---|
| `code/bill.json`, `code/version.json`, `code/tile.json`, `code/icon.svg` | the desk manifest: which nexus to instantiate, the replicating version, the launcher tile |
| `code/mar/json.hoon`, `code/mar/sig.hoon`, `code/mar/mime.hoon` | the kernel marcs the tree lays, vendored so the desk is hermetic |
| `code/mar/register/reg.hoon` | the noun-passthrough marc for a stored registration |
| `code/lib/register.hoon` | types, caps, JSON helpers, ISO time, ids, decoders that name the failing field, the together expansion, fees, the cap fold, the status machine, encoders, the shape ladder, the ring, templates, secret masking, the starter settings and copy. Pure, import-free |
| `tests/lib/register.hoon` | unit tests for the library, run on `~wex` |
| `code/nex/register/app.hoon` | the nexus: `on-load` rows, the writer, the HTTP binder, the request handler, tree walks, the stub provider steps |
| `code/nex/register/public.html`, `public.css`, `public.js` | the pilgrim's page: landing with the meter, the form, drafts, the next-step page, the manage page |
| `scripts/api-matrix.py` | the HTTP gate against `~wex` in stub mode |
| `scripts/page-smoke.py` | the page and its assets answer with the right types, without a cookie |
| `scripts/code-closure.py` | hermeticity check, copied from orrery |
| `docs/releasing.md` | the release mechanics, copied from orrery with the names changed |

---

### Task 1: The desk skeleton and the marcs

**Files:**
- Create: `code/bill.json`, `code/version.json`, `code/tile.json`, `code/icon.svg`
- Create: `code/mar/json.hoon`, `code/mar/sig.hoon`, `code/mar/mime.hoon`
- Create: `code/mar/register/reg.hoon`
- Create: `.gitignore`

**Interfaces:**
- Produces: the blots `[/ %json]`, `[/ %sig]`, `[/ %mime]` and `[/register %reg]` that Task 3's `on-load` and writer lay. The bill name `register.register_app` and neck `/register/app` that Task 3's nexus file path must match (`code/nex/register/app.hoon`).

- [ ] **Step 1: Write the manifest files**

`code/bill.json`:

```json
{"register.register_app": "/register/app"}
```

`code/version.json`:

```json
{"version": 1}
```

`code/tile.json`:

```json
{"title": "Register", "info": "Baby Steps Camino sign-up and backoffice", "color": "#0b7fc2", "image": "/grubbery/tiles/icon/register", "href": "/apps/register"}
```

`code/icon.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="12" fill="#0b7fc2"/><path d="M20 34l8 8 16-18" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/></svg>
```

`.gitignore`:

```
*.cookies
node_modules/
```

- [ ] **Step 2: Vendor the three kernel marcs**

Copy them from orrery, which vendored them from the kernel. They must be byte-identical to the kernel's:

```bash
cd /home/sneagan/software/personal/register
mkdir -p code/mar/register
\cp /home/sneagan/software/personal/orrery/code/mar/json.hoon code/mar/json.hoon
\cp /home/sneagan/software/personal/orrery/code/mar/sig.hoon code/mar/sig.hoon
\cp /home/sneagan/software/personal/orrery/code/mar/mime.hoon code/mar/mime.hoon
cmp code/mar/json.hoon /home/sneagan/software/groundwire/grubbery/desk/gub/mar/json.hoon && echo same
```

If `cmp` prints a difference, the kernel checkout is on a different branch than orrery vendored from; take orrery's copy, since orrery runs on `~wex` today.

- [ ] **Step 3: Write the registration marc**

`code/mar/register/reg.hoon`:

```hoon
::  mar/register/reg: one registration, at /regs/<rid>.
::
::    Stored as [%1 reg] (see +stored-reg in lib/register). A noun
::    passthrough: the shape ladder lives in +read-reg, so a later
::    shape never booms a stored grub.
::
|_  n=*
++  grad  %noun
++  grow
  |%
  ++  noun  n
  --
++  grab
  |%
  ++  noun  *
  --
--
```

- [ ] **Step 4: Commit**

```bash
cd /home/sneagan/software/personal/register
git add code .gitignore docs
git commit -m "The desk skeleton: manifests, the vendored marcs, the registration marc, the spec and this plan"
```

---

### Task 2: The library and its tests

**Files:**
- Create: `code/lib/register.hoon`
- Create: `tests/lib/register.hoon`

**Interfaces:**
- Produces, for Task 3: the types `reg`, `person`, `contact`, `payment`, `waiver`, `step`, `input`, `settings`, `counts`, `stored-reg`; `rid-from` and `token-from` (an entropy atom to ids); `de-input` (json and strict flag to `(each input @t)`); `de-settings` (json to `settings`); `new-reg`; `fees-total`; `tally`; `decide-submit`; `socials-ok`; `walkers`; `transition-ok`; `after-waiver`; `set-status`; `note-hist`; `en-reg`, `en-reg-pilgrim`; `read-reg`; `ring`; `fill`; `mask`, `unmask`; `starter-settings`, `starter-copy`; `status-json`; `changes-open`, `window-open`; the JSON helpers `gj`, `gs`, `gn`, `gb`, `ga`, `gt`, `strings`; `en-iso`, `de-iso`.

- [ ] **Step 1: Write the failing tests**

`tests/lib/register.hoon`:

```hoon
::  Unit tests for /lib/register: the codecs, the fees, the cap fold, the
::  status machine, the templates and the masking.
::
/+  *test, reg=register
|%
++  jo  |=(t=@t ^-(json (need (de:json:html t))))
++  t0  ~2026.10.1..12.00.00
::  a full-track adult who walks every day and takes both socials
++  pj
  %-  jo
  '''
  {"first": "Ana", "last": "Silva", "child": false,
   "days": {"fri": true, "sat": true, "sun": true}, "sun_ten": true,
   "social_fri": true, "social_sat": true, "mass_fri": true, "holy_hour": false,
   "bus": true, "first_bsc": true, "knight_dame": false, "volunteer": false}
  '''
++  cj
  %-  jo
  '''
  {"email": "ana@example.com", "phone": "904-555-0100", "street": "1 Beach Rd",
   "city": "Jacksonville Beach", "state": "FL", "zip": "32250"}
  '''
++  ij
  |=  extra=(list [@t json])
  ^-  json
  %-  pairs:enjs:format
  %+  weld
    :~  ['track' s+'full']
        ['contact' cj]
        ['org' s+'Order of Malta']
        ['why' s+'prayer']
        ['assistance' b+|]
        ['together' b+|]
        ['people' a+~[pj]]
    ==
  extra
++  st  (de-settings:reg starter-settings:reg)
++  some-person
  ^-  person:reg
  =/  got  (de-person:reg pj & 0)
  ?>  ?=(%& -.got)
  p.got
++  some-reg
  |=  [id=@ta status=@tas track=@tas n=@ud at=@da]
  ^-  reg:reg
  =/  p=person:reg  some-person
  =/  people=(list person:reg)  (reap n p)
  =/  r=reg:reg  (new-reg:reg id 'tok' %web [track [id 'p' 's' 'c' 'FL' 'z'] '' '' | | people] at)
  r(status status, updated at)
::  ==  ids and time
::
++  test-ids
  =/  eny=@  0xdead.beef.cafe.f00d.1234.5678.9abc.def0.1111.2222.3333.4444.5555.6666.7777.8888
  ;:  weld
    (expect-eq !>(10) !>((met 3 (rid-from:reg eny))))
    (expect-eq !>(32) !>((met 3 (token-from:reg eny))))
    (expect !>(!=((rid-from:reg eny) (rid-from:reg (add eny 1)))))
  ==
++  test-iso
  ;:  weld
    (expect-eq !>(`(unit @da)`[~ t0]) !>((de-iso:reg '2026-10-01T12:00:00Z')))
    (expect-eq !>('2026-10-01T12:00:00Z') !>((en-iso:reg t0)))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:reg '2026-02-30T00:00:00Z')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:reg 'yesterday')))
  ==
::  ==  decoders
::
++  test-de-person
  ;:  weld
    (expect !>(?=(%& -.(de-person:reg pj & 0))))
    (expect-eq !>(`(each person:reg @t)`[%| 'people.0.first: required']) !>((de-person:reg (jo '{"last": "x"}') & 0)))
    ::  a draft may leave the names empty
    (expect !>(?=(%& -.(de-person:reg (jo '{"last": "x"}') | 0))))
    (expect-eq !>(`(each person:reg @t)`[%| 'people.1.last: over 80 bytes']) !>((de-person:reg (jo (cat 3 '{"first": "a", "last": "' (cat 3 (crip (reap 81 'x')) '"}'))) & 1)))
  ==
++  test-de-contact
  ;:  weld
    (expect !>(?=(%& -.(de-contact:reg cj &))))
    (expect-eq !>(`(each contact:reg @t)`[%| 'email: not an email address']) !>((de-contact:reg (jo '{"email": "nope", "phone": "1"}') &)))
    (expect-eq !>(`(each contact:reg @t)`[%| 'zip: required']) !>((de-contact:reg (jo '{"email": "a@b.co", "phone": "1", "street": "s", "city": "c", "state": "FL"}') &)))
    ::  a draft needs an email or a phone, nothing else
    (expect !>(?=(%& -.(de-contact:reg (jo '{"phone": "904"}') |))))
    (expect-eq !>(`(each contact:reg @t)`[%| 'contact: an email or a phone number is required']) !>((de-contact:reg (jo '{"street": "s"}') |)))
  ==
++  test-de-input
  ;:  weld
    (expect !>(?=(%& -.(de-input:reg (ij ~) &))))
    (expect-eq !>(`(each input:reg @t)`[%| 'track: full or bambino']) !>((de-input:reg (ij ~[['track' s+'both']]) &)))
    (expect-eq !>(`(each input:reg @t)`[%| 'people: at least one person']) !>((de-input:reg (ij ~[['people' a+~]]) &)))
    (expect-eq !>(`(each input:reg @t)`[%| 'people: over 12']) !>((de-input:reg (ij ~[['people' a+(reap 13 pj)]]) &)))
    (expect-eq !>(`(each input:reg @t)`[%| 'why: over 2000 bytes']) !>((de-input:reg (ij ~[['why' s+(crip (reap 2.001 'w'))]]) &)))
  ==
++  test-together
  =/  second=json
    %-  jo
    '''
    {"first": "Bo", "last": "Silva", "child": true,
     "days": {"fri": false, "sat": false, "sun": false}, "sun_ten": false,
     "social_fri": false, "social_sat": false, "mass_fri": false, "holy_hour": false,
     "bus": false, "first_bsc": false, "knight_dame": false, "volunteer": false}
    '''
  =/  got  (de-input:reg (ij ~[['together' b+&] ['people' a+~[pj second]]]) &)
  ?>  ?=(%& -.got)
  =/  bo=person:reg  (snag 1 people.p.got)
  ;:  weld
    (expect-eq !>(&) !>(fri.days.bo))
    (expect-eq !>(&) !>(social-sat.bo))
    (expect-eq !>(&) !>(bus.bo))
    ::  identity fields stay the person's own
    (expect-eq !>('Bo') !>(first.bo))
    (expect-eq !>(&) !>(child.bo))
    (expect-eq !>(|) !>(first-bsc.bo))
  ==
::  ==  fees
::
++  test-fees
  =/  p=person:reg  some-person
  =/  none=person:reg  p(days [| | |])
  =/  sun-only=person:reg  p(days [| | &])
  ;:  weld
    (expect-eq !>(7.500) !>((fee:reg st %full p)))
    (expect-eq !>(7.500) !>((fee:reg st %full sun-only)))
    ::  a non-walker pays the track fee too
    (expect-eq !>(7.500) !>((fee:reg st %full none)))
    (expect-eq !>(2.500) !>((fee:reg st %bambino sun-only)))
    (expect-eq !>(2.500) !>((fee:reg st %bambino none)))
    ::  a child pays the same
    (expect-eq !>(7.500) !>((fee:reg st %full p(child &))))
    (expect-eq !>(22.500) !>((fees-total:reg st (some-reg %a %waiver %full 3 t0))))
  ==
::  ==  the cap fold
::
++  test-tally
  =/  now=@da  (add t0 ~h1)
  =/  regs=(list reg:reg)
    :~  (some-reg %a %complete %full 2 t0)
        (some-reg %b %payment %full 1 t0)                    ::  a live hold
        (some-reg %c %waiver %full 5 (sub t0 ~d3))           ::  an aged hold
        (some-reg %d %assistance %full 1 (sub t0 ~d30))      ::  waits as long as it takes
        (some-reg %e %cancelled %full 9 t0)
        (some-reg %f %draft %full 9 t0)
        (some-reg %g %waitlist %full 2 t0)
        (some-reg %h %complete %bambino 3 t0)
        (some-reg %i %complete %full 1 t0)
    ==
  =/  late=reg:reg  =/(r (some-reg %j %waiver %full 4 (sub t0 ~d3)) r(source %admin))
  =/  c=counts:reg  (tally:reg st (snoc regs late) now)
  ;:  weld
    (expect-eq !>(5) !>(full.c))
    (expect-eq !>(3) !>(bambino.c))
    (expect-eq !>(4) !>(late.c))
    ::  socials count every counted person, both tracks, late adds too
    (expect-eq !>(12) !>(social-fri.c))
    (expect-eq !>(1) !>(waitlist.c))
  ==
++  test-decide
  =/  c=counts:reg  [320 25 0 0 0 0]
  =/  p=person:reg  some-person
  ;:  weld
    (expect-eq !>(%waiver) !>((decide-submit:reg st c %full (reap 5 p))))
    (expect-eq !>(%waitlist) !>((decide-submit:reg st c %full (reap 6 p))))
    (expect-eq !>(%waitlist) !>((decide-submit:reg st c %bambino (reap 1 p))))
    ::  non-walkers never need a spot
    (expect-eq !>(%waiver) !>((decide-submit:reg st c %full (reap 6 p(days [| | |])))))
    (expect-eq !>(1) !>((walkers:reg %bambino ~[p p(days [| | |]) p(days [& & |])])))
  ==
++  test-socials
  =/  p=person:reg  some-person
  ;:  weld
    (expect-eq !>(`(unit @t)`~) !>((socials-ok:reg st [0 0 298 198 0 0] ~[p p])))
    (expect-eq !>(`(unit @t)`[~ 'social_sat: sold out']) !>((socials-ok:reg st [0 0 0 199 0 0] ~[p p])))
    (expect-eq !>(`(unit @t)`[~ 'social_fri: sold out']) !>((socials-ok:reg st [0 0 300 0 0 0] ~[p])))
  ==
::  ==  the status machine
::
++  test-transitions
  ;:  weld
    (expect !>((transition-ok:reg %draft %waiver)))
    (expect !>((transition-ok:reg %draft %waitlist)))
    (expect !>((transition-ok:reg %waitlist %waiver)))
    (expect !>((transition-ok:reg %waiver %payment)))
    (expect !>((transition-ok:reg %waiver %assistance)))
    (expect !>((transition-ok:reg %payment %complete)))
    (expect !>((transition-ok:reg %assistance %complete)))
    (expect !>((transition-ok:reg %assistance %payment)))
    (expect !>((transition-ok:reg %complete %cancelled)))
    (expect !>(!(transition-ok:reg %cancelled %waiver)))
    (expect !>(!(transition-ok:reg %draft %complete)))
    (expect !>(!(transition-ok:reg %waiver %complete)))
    (expect-eq !>(%payment) !>((after-waiver:reg (some-reg %a %waiver %full 1 t0))))
    (expect-eq !>(%assistance) !>((after-waiver:reg =/(r (some-reg %a %waiver %full 1 t0) r(assistance &)))))
  ==
++  test-set-status
  =/  r=reg:reg  (some-reg %a %waiver %full 1 t0)
  =/  r2=reg:reg  (set-status:reg r %payment 'pilgrim' 'signed the waiver' (add t0 ~m5))
  =/  many=reg:reg
    =/  i=@ud  0
    |-  ^-  reg:reg
    ?:  =(210 i)  r2
    $(i +(i), r2 (note-hist:reg r2 'admin' 'edit' t0))
  ;:  weld
    (expect-eq !>(%payment) !>(status.r2))
    (expect-eq !>((add t0 ~m5)) !>(updated.r2))
    (expect-eq !>(2) !>((lent history.r2)))
    (expect-eq !>('signed the waiver') !>(what:(rear history.r2)))
    (expect-eq !>(200) !>((lent history.many)))
  ==
::  ==  codecs
::
++  test-roundtrip
  =/  r=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  j=json  (en-reg:reg r 15.000)
  ;:  weld
    (expect-eq !>('abc123') !>((gs:reg j 'id')))
    (expect-eq !>(`(unit @ud)`[~ 15.000]) !>((gn:reg j 'fees')))
    (expect-eq !>(2) !>((lent (ga:reg j 'people'))))
    ::  the token never leaves in a view
    (expect !>(!(has-key:reg j 'token')))
    (expect !>((has-key:reg j 'history')))
    (expect !>(!(has-key:reg (en-reg-pilgrim:reg r 0) 'history')))
    (expect !>(!(has-key:reg (en-reg-pilgrim:reg r 0) 'notes')))
  ==
++  test-read-reg
  =/  r=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  ;:  weld
    (expect-eq !>(`(unit reg:reg)`[~ r]) !>((read-reg:reg `stored-reg:reg`[%1 r])))
    (expect-eq !>(`(unit reg:reg)`~) !>((read-reg:reg [%9 'garbage'])))
    (expect-eq !>(`(unit reg:reg)`~) !>((read-reg:reg 42)))
  ==
::  ==  helpers
::
++  test-ring
  =/  log=json  [%a ~[s+'a' s+'b']]
  =/  out=json  (ring:reg log s+'c' 2)
  (expect-eq !>(`json`[%a ~[s+'b' s+'c']]) !>(out))
++  test-fill
  ;:  weld
    (expect-eq !>('Hi Ana, see https://x/y. Bye Ana.') !>((fill:reg 'Hi {{first}}, see {{link}}. Bye {{first}}.' ~[['first' 'Ana'] ['link' 'https://x/y']])))
    (expect-eq !>('no vars') !>((fill:reg 'no vars' ~)))
  ==
++  test-mask
  =/  s=json  (jo '{"mail": {"from": "a@b", "resend_key": "re_123"}, "stripe": {"secret_key": ""}, "docusign": {"secret": "s3", "account_id": "acc"}}')
  =/  m=json  (mask:reg s)
  =/  put=json  (jo '{"mail": {"from": "c@d", "resend_key": "****"}, "stripe": {"secret_key": "sk_new"}, "docusign": {"secret": "****", "account_id": "acc2"}}')
  =/  merged=json  (unmask:reg put s)
  ;:  weld
    (expect-eq !>('****') !>((gs:reg (gj:reg m 'mail') 'resend_key')))
    (expect-eq !>('') !>((gs:reg (gj:reg m 'stripe') 'secret_key')))
    (expect-eq !>('acc') !>((gs:reg (gj:reg m 'docusign') 'account_id')))
    (expect-eq !>('re_123') !>((gs:reg (gj:reg merged 'mail') 'resend_key')))
    (expect-eq !>('c@d') !>((gs:reg (gj:reg merged 'mail') 'from')))
    (expect-eq !>('sk_new') !>((gs:reg (gj:reg merged 'stripe') 'secret_key')))
    (expect-eq !>('s3') !>((gs:reg (gj:reg merged 'docusign') 'secret')))
  ==
++  test-settings
  ;:  weld
    (expect-eq !>(7.500) !>(full.fees.st))
    (expect-eq !>(325) !>(full.caps.st))
    (expect-eq !>(~h48) !>(hold.st))
    (expect-eq !>(%stub) !>(mode.st))
    (expect !>((window-open:reg st ~2026.11.1)))
    (expect !>(!(window-open:reg st ~2026.9.1)))
    (expect !>((changes-open:reg st ~2026.12.1)))
    (expect !>(!(changes-open:reg st ~2026.12.5)))
  ==
++  test-copy
  =/  c=json  starter-copy:reg
  ;:  weld
    (expect !>(!=('' (gs:reg c 'landing.title'))))
    (expect !>(!=('' (gs:reg c 'email.waitlist.body'))))
    (expect !>(!=('' (gs:reg c 'form.social_soldout'))))
  ==
--
```

- [ ] **Step 2: Write the library**

`code/lib/register.hoon`:

```hoon
::  register: the model, pure. See docs/superpowers/specs/2026-09-17-register-design.md.
::
::    Import-free on purpose: the same file builds in the clay desk's
::    /lib, where -test reaches it, and in the app's code namespace,
::    where the nexus wraps it. Nothing here touches a ship: no bowl,
::    no roads, no vases.
::
|%
::  ==  the shapes
::
+$  days     [fri=? sat=? sun=?]
+$  checkin  [at=@da by=@t]
+$  person
  $:  first=@t
      last=@t
      child=?
      =days
      sun-ten=?                                 ::  full track sunday: 10 miles, else 2.5
      social-fri=?
      social-sat=?
      mass-fri=?
      holy-hour=?
      bus=?
      first-bsc=?
      knight-dame=?
      volunteer=?
      checkins=(map @tas checkin)               ::  %fri %sat %sun
  ==
+$  contact  [email=@t phone=@t street=@t city=@t state=@t zip=@t]
+$  payment
  $:  method=@tas                               ::  %none %stripe %check %cash %assistance %stub %other
      amount=@ud                                ::  cents, the fees
      gift=@ud                                  ::  cents, above the fees
      at=(unit @da)
      ref=@t                                    ::  the stripe session, a check number
      refunded=?
      note=@t
  ==
+$  waiver
  $:  method=@tas                               ::  %none %docusign %paper %stub
      envelope=@t
      status=@tas                               ::  %none %sent %completed %declined
      at=(unit @da)
  ==
+$  step   [at=@da by=@t what=@t]
::  what a form carries: everything a pilgrim may set
+$  input  [track=@tas =contact org=@t why=@t assistance=? together=? people=(list person)]
+$  reg
  $:  id=@ta
      status=@tas                               ::  see +transition-ok
      track=@tas                                ::  %full %bambino
      source=@tas                               ::  %web %admin
      created=@da
      updated=@da
      =contact
      org=@t
      why=@t
      assistance=?
      together=?
      people=(list person)
      =payment
      =waiver
      token=@t
      position=@ud                              ::  on the wait list, else 0
      notes=@t
      history=(list step)
  ==
::  what the grub holds: a version head, so a later shape is told apart
::  by the reader instead of clamming by luck
::
+$  stored-reg  [%1 =reg]
::  the settings the code reads. Everything else in settings.json (the
::  organizations, the provider credentials) stays JSON.
::
+$  settings
  $:  fees=[full=@ud bambino=@ud]
      caps=[full=@ud bambino=@ud social-fri=@ud social-sat=@ud late=@ud]
      hold=@dr
      open=(unit @da)
      close=(unit @da)
      cutoff=(unit @da)
      mode=@tas                                 ::  %live or %stub
  ==
+$  counts  [full=@ud bambino=@ud social-fri=@ud social-sat=@ud late=@ud waitlist=@ud]
::  ==  caps, the spec's
::
++  max-email    200
++  max-phone    40
++  max-street   200
++  max-city     100
++  max-state    40
++  max-zip      20
++  max-org      120
++  max-why      2.000
++  max-name     80
++  max-notes    2.000
++  max-by       64
++  max-party    12
++  max-history  200
++  max-log      2.000
::  ==  time
::
++  unix-secs
  |=  d=@da
  ^-  @ud
  ?:  (lth d ~1970.1.1)  0
  (div (sub d ~1970.1.1) ~s1)
::  +de-iso: "2026-09-16T22:05:00Z" (a fraction is allowed and dropped,
::  Z only) to a @da, or ~. A day the month does not have is refused.
::
++  de-iso
  |=  t=@t
  ^-  (unit @da)
  =/  two   (bass 10 (stun [2 2] dit))
  =/  four  (bass 10 (stun [4 4] dit))
  =/  rule
    ;~  plug
      four
      ;~(pfix hep two)
      ;~(pfix hep two)
      ;~(pfix (just 'T') two)
      ;~(pfix col two)
      ;~(pfix col two)
      (punt ;~(pfix dot (plus dit)))
      (cold ~ (just 'Z'))
    ==
  =/  got  (rush t rule)
  ?~  got  ~
  =/  [y=@ud mo=@ud d=@ud h=@ud mi=@ud s=@ud *]  u.got
  ?.  ?&  (gte mo 1)   (lte mo 12)
          (gte d 1)    (lte d 31)
          (lth h 24)   (lth mi 60)  (lth s 60)
      ==
    ~
  =/  when=@da  (year [[& y] mo d h mi s ~])
  ?.  =((end [3 10] (en-iso when)) (end [3 10] t))  ~
  `when
::  +en-iso: a @da to "2026-09-16T22:05:00Z", whole seconds
::
++  en-iso
  |=  when=@da
  ^-  @t
  =/  [[* y=@ud] mo=@ud [d=@ud h=@ud mi=@ud s=@ud *]]  (yore when)
  =/  yy=tape  ((d-co:co 4) y)
  =/  mm=tape  ((d-co:co 2) mo)
  =/  dd=tape  ((d-co:co 2) d)
  =/  hh=tape  ((d-co:co 2) h)
  =/  ii=tape  ((d-co:co 2) mi)
  =/  ss=tape  ((d-co:co 2) s)
  (crip "{yy}-{mm}-{dd}T{hh}:{ii}:{ss}Z")
::  ==  ids, from entropy the caller fetched
::
::  +hex-of: len lowercase hex digits of the low bits of n
::
++  hex-of
  |=  [n=@ len=@ud]
  ^-  @t
  (crip ((x-co:co len) (end [0 (mul 4 len)] n)))
++  rid-from    |=(eny=@ ^-(@ta `@ta`(hex-of eny 10)))
++  token-from  |=(eny=@ ^-(@t (hex-of (rsh [0 64] eny) 32)))
::  ==  json, read without crashing
::
++  gj                                          ::  a key's value, or null
  |=  [jon=json k=@t]
  ^-  json
  ?.  ?=([%o *] jon)  ~
  (fall (~(get by p.jon) k) ~)
++  has-key
  |=  [jon=json k=@t]
  ^-  ?
  ?.  ?=([%o *] jon)  |
  (~(has by p.jon) k)
++  gs                                          ::  a string, or ''
  |=  [jon=json k=@t]
  ^-  @t
  =/  v=json  (gj jon k)
  ?:(?=([%s *] v) p.v '')
++  gn                                          ::  a whole number
  |=  [jon=json k=@t]
  ^-  (unit @ud)
  =/  v=json  (gj jon k)
  ?.  ?=([%n *] v)  ~
  (rush p.v dem)
++  gb                                          ::  a boolean, false when absent
  |=  [jon=json k=@t]
  ^-  ?
  =/  v=json  (gj jon k)
  ?:(?=([%b *] v) p.v |)
++  ga                                          ::  an array's items, or ~
  |=  [jon=json k=@t]
  ^-  (list json)
  =/  v=json  (gj jon k)
  ?:(?=([%a *] v) p.v ~)
++  gt                                          ::  an ISO time
  |=  [jon=json k=@t]
  ^-  (unit @da)
  =/  s=@t  (gs jon k)
  ?:(=('' s) ~ (de-iso s))
++  strings                                     ::  the strings in an array
  |=  l=(list json)
  ^-  (list @t)
  (murn l |=(j=json ?:(?=([%s *] j) `p.j ~)))
++  en-time        |=(d=@da ^-(json s+(en-iso d)))
++  en-maybe-time  |=(d=(unit @da) ^-(json ?~(d ~ (en-time u.d))))
++  en-num         |=(n=@ud ^-(json (numb:enjs:format n)))
::  ==  decoders: a request's JSON to a shape, or the field that failed
::
::  +over-cap: a string longer than max bytes
::
++  over-cap  |=([t=@t max=@ud] ^-(? (gth (met 3 t) max)))
::  +str-field: read a string, refusing one over its cap; strict refuses
::  an empty one too
::
++  str-field
  |=  [jon=json k=@t max=@ud strict=? label=@t]
  ^-  (each @t @t)
  =/  v=@t  (gs jon k)
  ?:  (over-cap v max)  [%| (rap 3 label ': over ' (crip (a-co:co max)) ' bytes' ~)]
  ?:  &(strict =('' v))  [%| (rap 3 label ': required' ~)]
  [%& v]
::  +is-email: something@something.something, loosely
::
++  is-email
  |=  t=@t
  ^-  ?
  =/  tap=tape  (trip t)
  =/  at=(unit @ud)  (find "@" tap)
  ?~  at  |
  ?:  =(0 u.at)  |
  =/  dom=tape  (slag +(u.at) tap)
  =/  dot=(unit @ud)  (find "." dom)
  ?~  dot  |
  &((gth u.dot 0) (lth +(u.dot) (lent dom)))
::  +de-contact: strict is a submit (every field, a real email); a draft
::  needs only an email or a phone
::
++  de-contact
  |=  [jon=json strict=?]
  ^-  (each contact @t)
  =/  em  (str-field jon 'email' max-email strict 'email')
  ?:  ?=(%| -.em)  [%| p.em]
  ?:  &(strict !(is-email p.em))  [%| 'email: not an email address']
  =/  ph  (str-field jon 'phone' max-phone strict 'phone')
  ?:  ?=(%| -.ph)  [%| p.ph]
  =/  sr  (str-field jon 'street' max-street strict 'street')
  ?:  ?=(%| -.sr)  [%| p.sr]
  =/  ci  (str-field jon 'city' max-city strict 'city')
  ?:  ?=(%| -.ci)  [%| p.ci]
  =/  sa  (str-field jon 'state' max-state strict 'state')
  ?:  ?=(%| -.sa)  [%| p.sa]
  =/  zi  (str-field jon 'zip' max-zip strict 'zip')
  ?:  ?=(%| -.zi)  [%| p.zi]
  ?:  &(!strict =('' p.em) =('' p.ph))
    [%| 'contact: an email or a phone number is required']
  [%& [p.em p.ph p.sr p.ci p.sa p.zi]]
::  +de-person: one person, at index i for the error's name. Check-ins
::  are never read from input; the caller keeps the stored ones.
::
++  de-person
  |=  [jon=json strict=? i=@ud]
  ^-  (each person @t)
  =/  pre=@t  (rap 3 'people.' (crip (a-co:co i)) '.' ~)
  =/  fi  (str-field jon 'first' max-name strict (cat 3 pre 'first'))
  ?:  ?=(%| -.fi)  [%| p.fi]
  =/  la  (str-field jon 'last' max-name strict (cat 3 pre 'last'))
  ?:  ?=(%| -.la)  [%| p.la]
  =/  dj=json  (gj jon 'days')
  :-  %&
  :*  p.fi
      p.la
      (gb jon 'child')
      [(gb dj 'fri') (gb dj 'sat') (gb dj 'sun')]
      (gb jon 'sun_ten')
      (gb jon 'social_fri')
      (gb jon 'social_sat')
      (gb jon 'mass_fri')
      (gb jon 'holy_hour')
      (gb jon 'bus')
      (gb jon 'first_bsc')
      (gb jon 'knight_dame')
      (gb jon 'volunteer')
      ~
  ==
::  +de-people: every person, or the first that failed
::
++  de-people
  |=  [raw=(list json) strict=? i=@ud acc=(list person)]
  ^-  (each (list person) @t)
  ?~  raw  [%& (flop acc)]
  =/  got  (de-person i.raw strict i)
  ?:  ?=(%| -.got)  [%| p.got]
  (de-people t.raw strict +(i) [p.got acc])
::  +together: everyone after the first takes the first's choices. Names,
::  child, first camino, knight or dame and volunteer stay their own.
::
++  together
  |=  people=(list person)
  ^-  (list person)
  ?~  people  ~
  =/  lead=person  i.people
  :-  lead
  %+  turn  t.people
  |=  p=person
  %_  p
    days        days.lead
    sun-ten     sun-ten.lead
    social-fri  social-fri.lead
    social-sat  social-sat.lead
    mass-fri    mass-fri.lead
    holy-hour   holy-hour.lead
    bus         bus.lead
  ==
::  +de-input: the form. strict is a submit or an edit; a draft is not.
::
++  de-input
  |=  [jon=json strict=?]
  ^-  (each input @t)
  ?.  ?=([%o *] jon)  [%| 'a JSON object is required']
  =/  track=@t  (gs jon 'track')
  ?.  ?=(?(%full %bambino) track)  [%| 'track: full or bambino']
  =/  ct  (de-contact (gj jon 'contact') strict)
  ?:  ?=(%| -.ct)  [%| p.ct]
  =/  org  (str-field jon 'org' max-org | 'org')
  ?:  ?=(%| -.org)  [%| p.org]
  =/  why  (str-field jon 'why' max-why | 'why')
  ?:  ?=(%| -.why)  [%| p.why]
  =/  raw=(list json)  (ga jon 'people')
  ?:  &(strict ?=(~ raw))  [%| 'people: at least one person']
  ?:  (gth (lent raw) max-party)  [%| (rap 3 'people: over ' (crip (a-co:co max-party)) ~)]
  =/  ps  (de-people raw strict 0 ~)
  ?:  ?=(%| -.ps)  [%| p.ps]
  =/  tog=?  (gb jon 'together')
  =/  people=(list person)  ?:(tog (together p.ps) p.ps)
  [%& [track p.ct p.org p.why (gb jon 'assistance') tog people]]
::  +keep-checkins: an edit replaces the people but keeps each position's
::  check-ins, so a name fix on the beach does not lose a day
::
++  keep-checkins
  |=  [old=(list person) new=(list person)]
  ^-  (list person)
  ?~  new  ~
  ?~  old  new
  [i.new(checkins checkins.i.old) $(old t.old, new t.new)]
::  ==  settings
::
++  de-settings
  |=  jon=json
  ^-  settings
  =/  fj=json  (gj jon 'fees')
  =/  cj=json  (gj jon 'caps')
  =/  wj=json  (gj jon 'window')
  =/  hours=@ud  (fall (gn jon 'hold_hours') 48)
  =/  mode=@t  (gs (gj jon 'providers') 'mode')
  :*  :*  (fall (gn fj 'full') 7.500)
          (fall (gn fj 'bambino') 2.500)
      ==
      :*  (fall (gn cj 'full') 325)
          (fall (gn cj 'bambino') 25)
          (fall (gn cj 'social_fri') 300)
          (fall (gn cj 'social_sat') 200)
          (fall (gn cj 'late_adds') 50)
      ==
      (mul hours ~h1)
      (gt wj 'open')
      (gt wj 'close')
      (gt wj 'change_cutoff')
      ?:(=('live' mode) %live %stub)
  ==
++  window-open
  |=  [s=settings now=@da]
  ^-  ?
  ?&  ?~(open.s & (gte now u.open.s))
      ?~(close.s & (lth now u.close.s))
  ==
++  changes-open
  |=  [s=settings now=@da]
  ^-  ?
  ?~(cutoff.s & (lth now u.cutoff.s))
::  ==  fees
::
::  +walks: a person who needs a spot on the track
::
++  walks
  |=  [track=@tas p=person]
  ^-  ?
  ?:  =(%bambino track)  sun.days.p
  |(fri.days.p sat.days.p sun.days.p)
++  walkers
  |=  [track=@tas people=(list person)]
  ^-  @ud
  (lent (skim people |=(p=person (walks track p))))
::  +fee: the track fee, walker or not. A non-walker registers, pays and
::  attends the socials like anyone; only the cap ignores them.
::
++  fee
  |=  [s=settings track=@tas p=person]
  ^-  @ud
  ?:(=(%bambino track) bambino.fees.s full.fees.s)
++  fees-total
  |=  [s=settings r=reg]
  ^-  @ud
  (roll (turn people.r |=(p=person (fee s track.r p))) add)
::  ==  the cap fold
::
::  +counted: does this registration hold spots right now? Complete and
::  assistance always; a waiver or payment hold only within the hold
::  window, unless an organizer made it.
::
++  counted
  |=  [s=settings r=reg now=@da]
  ^-  ?
  ?+  status.r  |
    ?(%complete %assistance)  &
    ?(%waiver %payment)  |(=(%admin source.r) (lth now (add updated.r hold.s)))
  ==
++  tally
  |=  [s=settings regs=(list reg) now=@da]
  ^-  counts
  =|  c=counts
  |-  ^-  counts
  ?~  regs  c
  =/  r=reg  i.regs
  ?:  =(%waitlist status.r)  $(regs t.regs, c c(waitlist +(waitlist.c)))
  ?.  (counted s r now)  $(regs t.regs)
  =/  w=@ud  (walkers track.r people.r)
  =/  sf=@ud  (lent (skim people.r |=(p=person social-fri.p)))
  =/  ss=@ud  (lent (skim people.r |=(p=person social-sat.p)))
  =/  c2=counts  c(social-fri (add social-fri.c sf), social-sat (add social-sat.c ss))
  ?:  =(%admin source.r)  $(regs t.regs, c c2(late (add late.c2 w)))
  ?:  =(%bambino track.r)  $(regs t.regs, c c2(bambino (add bambino.c2 w)))
  $(regs t.regs, c c2(full (add full.c2 w)))
::  +decide-submit: a spot or the wait list
::
++  decide-submit
  |=  [s=settings c=counts track=@tas people=(list person)]
  ^-  ?(%waiver %waitlist)
  =/  w=@ud  (walkers track people)
  ?:  =(0 w)  %waiver
  ?:  =(%bambino track)
    ?:((lte (add bambino.c w) bambino.caps.s) %waiver %waitlist)
  ?:((lte (add full.c w) full.caps.s) %waiver %waitlist)
::  +socials-ok: ~, or the social that is sold out
::
++  socials-ok
  |=  [s=settings c=counts people=(list person)]
  ^-  (unit @t)
  =/  sf=@ud  (lent (skim people |=(p=person social-fri.p)))
  =/  ss=@ud  (lent (skim people |=(p=person social-sat.p)))
  ?:  (gth (add social-fri.c sf) social-fri.caps.s)  `'social_fri: sold out'
  ?:  (gth (add social-sat.c ss) social-sat.caps.s)  `'social_sat: sold out'
  ~
::  ==  the status machine
::
++  transition-ok
  |=  [from=@tas to=@tas]
  ^-  ?
  ?+  from  |
    %draft       ?=(?(%waitlist %waiver) to)
    %waitlist    ?=(?(%waiver %cancelled) to)
    %waiver      ?=(?(%payment %assistance %cancelled) to)
    %payment     ?=(?(%complete %cancelled) to)
    %assistance  ?=(?(%complete %payment %cancelled) to)
    %complete    ?=(%cancelled to)
  ==
++  after-waiver  |=(r=reg ^-(@tas ?:(assistance.r %assistance %payment)))
++  active        |=(r=reg ^-(? !?=(?(%draft %cancelled) status.r)))
++  note-hist
  |=  [r=reg by=@t what=@t now=@da]
  ^-  reg
  =/  h=(list step)  (snoc history.r [now by what])
  =/  n=@ud  (lent h)
  r(updated now, history ?:((gth n max-history) (slag (sub n max-history) h) h))
++  set-status
  |=  [r=reg to=@tas by=@t what=@t now=@da]
  ^-  reg
  (note-hist r(status to) by what now)
::  +new-reg: a registration from a form, as a draft
::
++  new-reg
  |=  [id=@ta token=@t source=@tas in=input now=@da]
  ^-  reg
  :*  id  %draft  track.in  source  now  now
      contact.in  org.in  why.in  assistance.in  together.in  people.in
      [%none 0 0 ~ '' | '']
      [%none '' %none ~]
      token  0  ''  ~
  ==
::  +with-input: an edit onto an existing registration
::
++  with-input
  |=  [r=reg in=input]
  ^-  reg
  %_  r
    track       track.in
    contact     contact.in
    org         org.in
    why         why.in
    assistance  assistance.in
    together    together.in
    people      (keep-checkins people.r people.in)
  ==
::  ==  encoders
::
++  en-person
  |=  p=person
  ^-  json
  %-  pairs:enjs:format
  :~  ['first' s+first.p]
      ['last' s+last.p]
      ['child' b+child.p]
      ['days' (pairs:enjs:format ~[['fri' b+fri.days.p] ['sat' b+sat.days.p] ['sun' b+sun.days.p]])]
      ['sun_ten' b+sun-ten.p]
      ['social_fri' b+social-fri.p]
      ['social_sat' b+social-sat.p]
      ['mass_fri' b+mass-fri.p]
      ['holy_hour' b+holy-hour.p]
      ['bus' b+bus.p]
      ['first_bsc' b+first-bsc.p]
      ['knight_dame' b+knight-dame.p]
      ['volunteer' b+volunteer.p]
      :-  'checkins'
      %-  pairs:enjs:format
      %+  turn  ~(tap by checkins.p)
      |=([d=@tas c=checkin] [d (pairs:enjs:format ~[['at' (en-time at.c)] ['by' s+by.c]])])
  ==
++  en-contact
  |=  c=contact
  ^-  json
  %-  pairs:enjs:format
  :~  ['email' s+email.c]  ['phone' s+phone.c]  ['street' s+street.c]
      ['city' s+city.c]  ['state' s+state.c]  ['zip' s+zip.c]
  ==
++  en-payment
  |=  p=payment
  ^-  json
  %-  pairs:enjs:format
  :~  ['method' s+method.p]  ['amount' (en-num amount.p)]  ['gift' (en-num gift.p)]
      ['at' (en-maybe-time at.p)]  ['ref' s+ref.p]  ['refunded' b+refunded.p]  ['note' s+note.p]
  ==
++  en-waiver
  |=  w=waiver
  ^-  json
  %-  pairs:enjs:format
  :~  ['method' s+method.w]  ['envelope' s+envelope.w]  ['status' s+status.w]  ['at' (en-maybe-time at.w)]
  ==
++  en-step
  |=  s=step
  ^-  json
  (pairs:enjs:format ~[['at' (en-time at.s)] ['by' s+by.s] ['what' s+what.s]])
::  +en-reg: the organizer's view. The token never leaves in a view.
::
++  en-reg
  |=  [r=reg fees=@ud]
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+id.r]
      ['status' s+status.r]
      ['track' s+track.r]
      ['source' s+source.r]
      ['created' (en-time created.r)]
      ['updated' (en-time updated.r)]
      ['contact' (en-contact contact.r)]
      ['org' s+org.r]
      ['why' s+why.r]
      ['assistance' b+assistance.r]
      ['together' b+together.r]
      ['people' a+(turn people.r en-person)]
      ['payment' (en-payment payment.r)]
      ['waiver' (en-waiver waiver.r)]
      ['position' (en-num position.r)]
      ['fees' (en-num fees)]
      ['notes' s+notes.r]
      ['history' a+(turn history.r en-step)]
  ==
::  +en-reg-pilgrim: the same without the organizers' notes and history
::
++  en-reg-pilgrim
  |=  [r=reg fees=@ud]
  ^-  json
  =/  j=json  (en-reg r fees)
  ?.  ?=([%o *] j)  j
  [%o (~(del by (~(del by p.j) 'notes') 'history')]
::  +read-reg: the shape ladder. Newest first; anything else is ~.
::
++  read-reg
  |=  n=*
  ^-  (unit reg)
  =/  v1=(unit stored-reg)  (mole |.(;;(stored-reg n)))
  ?^  v1  `reg.u.v1
  ~
::  ==  helpers
::
::  +ring: append to a JSON array and keep the last max entries
::
++  ring
  |=  [log=json entry=json max=@ud]
  ^-  json
  =/  cur=(list json)  ?:(?=([%a *] log) p.log ~)
  =/  all=(list json)  (snoc cur entry)
  =/  n=@ud  (lent all)
  [%a ?:((gth n max) (slag (sub n max) all) all)]
::  +replace: every pat in hay becomes rep
::
++  replace
  |=  [hay=tape pat=tape rep=tape]
  ^-  tape
  ?~  pat  hay
  |-  ^-  tape
  =/  at=(unit @ud)  (find pat hay)
  ?~  at  hay
  %+  weld  (scag u.at hay)
  %+  weld  rep
  $(hay (slag (add u.at (lent pat)) hay))
::  +fill: a template's {{key}} placeholders, filled
::
++  fill
  |=  [tpl=@t vars=(list [k=@t v=@t])]
  ^-  @t
  =/  out=tape  (trip tpl)
  |-  ^-  @t
  ?~  vars  (crip out)
  =/  key=tape  (weld (trip '{{') (weld (trip k.i.vars) (trip '}}')))
  $(vars t.vars, out (replace out key (trip v.i.vars)))
::  +secret-key: a settings key whose value is a secret
::
++  secret-key
  |=  k=@t
  ^-  ?
  ?:  =('secret' k)  &
  =/  tap=tape  (trip k)
  =/  n=@ud  (lent tap)
  &((gte n 4) =("_key" (slag (sub n 4) tap)))
::  +mask: every secret string in a settings document becomes ****,
::  an empty one stays empty so the page can tell unset from set
::
++  mask
  |=  jon=json
  ^-  json
  ?.  ?=([%o *] jon)  jon
  :-  %o
  %-  ~(urn by p.jon)
  |=  [k=@t v=json]
  ^-  json
  ?:  &((secret-key k) ?=([%s *] v))  ?:(=('' p.v) v s+'****')
  (mask v)
::  +unmask: a masked value coming back on a PUT keeps the stored one
::
++  unmask
  |=  [new=json old=json]
  ^-  json
  ?.  ?=([%o *] new)  new
  :-  %o
  %-  ~(urn by p.new)
  |=  [k=@t v=json]
  ^-  json
  =/  was=json  (gj old k)
  ?:  ?=([%s *] v)  ?:(=('****' p.v) was v)
  (unmask v was)
::  +status-json: what the public page reads: the copy, the counts, the
::  caps, the fees, the window and the mode
::
++  status-json
  |=  [s=settings sj=json cj=json c=counts now=@da]
  ^-  json
  %-  pairs:enjs:format
  :~  ['copy' cj]
      :-  'counts'
      %-  pairs:enjs:format
      :~  ['full' (en-num full.c)]  ['bambino' (en-num bambino.c)]
          ['social_fri' (en-num social-fri.c)]  ['social_sat' (en-num social-sat.c)]
          ['late' (en-num late.c)]  ['waitlist' (en-num waitlist.c)]
      ==
      :-  'caps'
      %-  pairs:enjs:format
      :~  ['full' (en-num full.caps.s)]  ['bambino' (en-num bambino.caps.s)]
          ['social_fri' (en-num social-fri.caps.s)]  ['social_sat' (en-num social-sat.caps.s)]
          ['late_adds' (en-num late.caps.s)]  ['party' (en-num max-party)]
      ==
      :-  'fees'
      %-  pairs:enjs:format
      :~  ['full' (en-num full.fees.s)]  ['bambino' (en-num bambino.fees.s)]
      ==
      ['open' b+(window-open s now)]
      ['changes_open' b+(changes-open s now)]
      ['window' (gj sj 'window')]
      ['event' (gj sj 'event')]
      ['orgs' (gj sj 'orgs')]
      ['mode' s+mode.s]
      ['now' (en-time now)]
  ==
::  ==  the starter documents
::
++  starter-settings
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'event'
      %-  pairs:enjs:format
      :~  ['name' s+'Baby Steps Camino 2026']
          ['days' a+~[s+'2026-12-04' s+'2026-12-05' s+'2026-12-06']]
      ==
      ['fees' (pairs:enjs:format ~[['full' (en-num 7.500)] ['bambino' (en-num 2.500)]])]
      :-  'caps'
      %-  pairs:enjs:format
      :~  ['full' (en-num 325)]  ['bambino' (en-num 25)]  ['social_fri' (en-num 300)]
          ['social_sat' (en-num 200)]  ['late_adds' (en-num 50)]
      ==
      ['hold_hours' (en-num 48)]
      :-  'window'
      %-  pairs:enjs:format
      :~  ['open' s+'2026-10-01T04:00:00Z']
          ['close' s+'2026-12-03T05:00:00Z']
          ['change_cutoff' s+'2026-12-04T05:00:00Z']
      ==
      ['orgs' a+~[s+'Order of Malta']]
      ['public_url' s+'https://register.babystepscamino.com']
      ['mail' (pairs:enjs:format ~[['from' s+'Baby Steps Camino <register@babystepscamino.com>'] ['resend_key' s+'']])]
      ['stripe' (pairs:enjs:format ~[['secret_key' s+'']])]
      :-  'docusign'
      %-  pairs:enjs:format
      :~  ['integration_key' s+'']  ['secret' s+'']  ['account_id' s+'']
          ['base_uri' s+'https://demo.docusign.net']  ['auth_host' s+'https://account-d.docusign.com']
          ['template_id' s+'']
      ==
      ['providers' (pairs:enjs:format ~[['mode' s+'stub']])]
  ==
++  starter-copy
  ^-  json
  %-  pairs:enjs:format
  :~  ['landing.title' s+'Register for the Baby Steps Camino']
      ['landing.intro' s+'Three days of beach walking, prayer and fellowship from Jacksonville Beach to the Shrine of Our Lady of La Leche in St. Augustine, December 4 to 6, 2026.']
      ['landing.meter' s+'{{percent}}% full']
      ['landing.full.title' s+'The full Camino']
      ['landing.full.blurb' s+'Walk all three days, or any of them. $75 per person, adults and children alike.']
      ['landing.full.button' s+'Register for the full Camino']
      ['landing.bambino.title' s+'The Bambino Camino']
      ['landing.bambino.blurb' s+'The last 2.5 miles on Sunday, ending at the Shrine. $25 per person.']
      ['landing.bambino.button' s+'Register for the Bambino Camino']
      ['landing.soldout' s+'This track is full. You can join the wait list and we will email you if a spot opens.']
      ['landing.waitlist.button' s+'Join the wait list']
      ['landing.closed' s+'Registration is closed. Contact us at register@babystepscamino.com with any questions.']
      ['form.title' s+'Your registration']
      ['form.contact.title' s+'Contact']
      ['form.email' s+'Email']
      ['form.phone' s+'Phone']
      ['form.street' s+'Street address']
      ['form.city' s+'City']
      ['form.state' s+'State']
      ['form.zip' s+'ZIP']
      ['form.org' s+'Organization or parish (optional)']
      ['form.why' s+'Why are you walking this pilgrimage?']
      ['form.assistance' s+'I would like to be considered for financial assistance.']
      ['form.assistance.help' s+'Not all requests can be accepted. You are not registered until payment is made or assistance is approved.']
      ['form.together' s+'Everyone in my party is doing the same things']
      ['form.people.title' s+'Who is coming']
      ['form.person' s+'Person {{n}}']
      ['form.first' s+'First name']
      ['form.last' s+'Last name']
      ['form.child' s+'This is a child']
      ['form.days' s+'Walking days']
      ['form.fri' s+'Friday, December 4']
      ['form.sat' s+'Saturday, December 5']
      ['form.sun' s+'Sunday, December 6']
      ['form.sun_ten' s+'On Sunday I will walk the full 10 miles (otherwise the last 2.5)']
      ['form.social_fri' s+'Friday social at Ajua']
      ['form.social_sat' s+'Saturday social at Pussers']
      ['form.social_soldout' s+'sold out']
      ['form.mass_fri' s+'Friday 8am Mass']
      ['form.holy_hour' s+'Holy Hour']
      ['form.bus' s+'I need bus transportation']
      ['form.first_bsc' s+'This is my first Baby Steps Camino']
      ['form.knight_dame' s+'Knight or Dame of the Order of Malta']
      ['form.volunteer' s+'I am volunteering']
      ['form.add_person' s+'Add a person']
      ['form.remove_person' s+'Remove']
      ['form.fees.title' s+'Registration fees']
      ['form.fees.line' s+'{{n}} x {{each}}']
      ['form.fees.total' s+'Total']
      ['form.fees.nonrefundable' s+'The registration fee is non-refundable.']
      ['form.submit' s+'Continue to the waiver']
      ['form.saving' s+'Saved']
      ['form.error.duplicate' s+'There is already a registration under this email. Use the link in your confirmation email to change it, or request the link again below.']
      ['form.resend' s+'Email me my registration link']
      ['form.resend.done' s+'If that address has a registration, the link is on its way.']
      ['next.waiver.title' s+'Sign the waiver']
      ['next.waiver.body' s+'Every pilgrim signs a waiver. You sign once, for yourself and for everyone in your party.']
      ['next.waiver.button' s+'Sign the waiver']
      ['next.payment.title' s+'Pay the registration fee']
      ['next.payment.body' s+'Your spots are held. Payment completes your registration.']
      ['next.payment.button' s+'Pay {{total}}']
      ['next.assistance.title' s+'Thank you']
      ['next.assistance.body' s+'Your waiver is signed and your request for assistance is with the organizers. We will email you when it is decided.']
      ['next.waitlist.title' s+'You are on the wait list']
      ['next.waitlist.body' s+'You are number {{position}} on the wait list. We will email you if a spot opens.']
      ['next.complete.title' s+'You are registered']
      ['next.complete.body' s+'See you on the beach. A confirmation is on its way to {{email}} with a link to change or cancel your registration.']
      ['next.cancelled.title' s+'This registration was cancelled']
      ['next.cancelled.body' s+'If that was a mistake, register again from the start.']
      ['manage.title' s+'Your registration']
      ['manage.save' s+'Save changes']
      ['manage.cancel' s+'Cancel my registration']
      ['manage.cancel.confirm' s+'Cancel this registration for everyone in the party? This cannot be undone.']
      ['manage.closed' s+'Changes are closed. Contact us at register@babystepscamino.com.']
      ['manage.pay_more' s+'Your changes raise the fee by {{diff}}. Pay the difference to keep them.']
      ['stub.banner' s+'Rehearsal mode: signing and payment complete themselves and no email is sent.']
      ['email.confirmation.subject' s+'You are registered for the Baby Steps Camino']
      ['email.confirmation.body' s+'{{first}}, you are registered. Change or cancel your registration any time before the event at {{link}}']
      ['email.waitlist.subject' s+'You are on the Baby Steps Camino wait list']
      ['email.waitlist.body' s+'{{first}}, the track you chose is full. You are number {{position}} on the wait list and we will email you if a spot opens.']
      ['email.promoted.subject' s+'A spot opened for you on the Baby Steps Camino']
      ['email.promoted.body' s+'{{first}}, a spot opened. Sign the waiver and pay within 48 hours to keep it: {{link}}']
      ['email.assistance_approved.subject' s+'Your Baby Steps Camino registration is complete']
      ['email.assistance_approved.body' s+'{{first}}, your request for assistance was approved and you are registered. Your registration: {{link}}']
      ['email.assistance_declined.subject' s+'About your Baby Steps Camino registration']
      ['email.assistance_declined.body' s+'{{first}}, we could not approve assistance this time. Pay the registration fee to complete your registration: {{link}}']
      ['email.reminder.subject' s+'Finish your Baby Steps Camino registration']
      ['email.reminder.body' s+'{{first}}, your registration is not finished yet. Pick up where you left off: {{link}}']
      ['email.cancelled.subject' s+'Your Baby Steps Camino registration was cancelled']
      ['email.cancelled.body' s+'{{first}}, your registration was cancelled. If that was a mistake, register again at {{site}}']
  ==
--
```

- [ ] **Step 3: Run the tests on `~wex`**

Follow "Unit tests" under Working with `~wex`. Expected: 20 test arms, every one `OK`. A `FAILED` line names the arm; a `CRASHED` line or a `dep failed` names a compile error with its line. Fix the library, never the expectation, unless the expectation contradicts the spec.

Hoon facts these tests are likely to trip on, so the fix is known: a `?+` with a `?(...)` case on a `@tas` needs the union spelled inside the case as written above. `%_` on a leg works; `%_` on an arm's product needs the product bound with `=/` first. The `reap` in `some-reg` builds a list of the same person; that is intended.

- [ ] **Step 4: Commit**

```bash
git add code/lib/register.hoon tests/lib/register.hoon
git commit -m "The library: shapes, decoders that name the field, fees, the cap fold, the status machine, codecs, templates, masking, and the starter documents"
```

---

### Task 3: The nexus: the tree, the writer, the public and admin routes

**Files:**
- Create: `code/nex/register/app.hoon`
- Create, as placeholders so the build has files to load: `code/nex/register/public.html`, `public.css`, `public.js` (Task 4 replaces them)

**Interfaces:**
- Consumes: everything Task 2 produces, under the face `reg`.
- Produces: the writer's op vocabulary (`save-draft`, `submit`, `edit`, `cancel`, `advance`, `promote`, `assist`, `note`, `set-settings`, `set-copy`, `set-counts`), the route table of spec section 9 for phase 1, and the JSON answers Task 4's page and Task 6's gate read: `POST /api/draft` answers `{"rid","token"}`; `POST /api/submit` answers `{"rid","token","status","position","fees"}`; `GET /api/reg/<rid>?t=` answers the pilgrim view plus `changes_open` and `mode`; `POST .../sign` and `.../pay` answer `{"next": "<status>"}` in stub mode and 501 in live mode; every error is `{"error": "<field>: <why>"}` and a duplicate email is 409 with `"code": "duplicate"`. Mutating admin routes (`POST /api/admin/reg/<rid>`, `PUT /api/admin/settings`, `PUT /api/admin/copy`) need an `X-Actor` header and stamp `admin:<name>`.

- [ ] **Step 1: Write the placeholder page files**

`code/nex/register/public.html`:

```html
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Register</title></head><body><main id="view">Loading.</main><script src="/apps/register/public.js"></script></body></html>
```

`code/nex/register/public.css`:

```css
body { font-family: sans-serif; }
```

`code/nex/register/public.js`:

```js
document.getElementById('view').textContent = 'The page arrives in Task 4.';
```

- [ ] **Step 2: Write the nexus**

`code/nex/register/app.hoon`:

```hoon
::  register: sign-up and backoffice for the Baby Steps Camino.
::  docs/superpowers/specs/2026-09-17-register-design.md
::
::  The tree this nexus owns (every persistent path has a row in +on-load):
::    /main.sig            the writer: every mutation goes through it
::    /web.sig             binds /apps/register; one fiber per request
::    /requests/<id>       the ephemeral request fibers
::    /regs/<rid>          one registration       [/register %reg], retention on
::    /settings.json       the event: fees, caps, window, providers
::    /copy.json           every string the pilgrim reads
::    /counts.json         actual counts per day per activity
::    /beacon/rev          the change beacon, nested so it streams
::    /tr/last  /tr/log    the last writer outcome, the audit ring of 2000
::    the page and the manifests     laid fresh on every load, not %fall
::
::  ROADS ARE NEXUS-RELATIVE. A desk-installed app cannot learn its own
::  absolute path, so every road is [%| up lane], where up is the number
::  of steps from the calling fiber to the nexus root: 0 for the writer
::  and the binder, 1 for a request fiber at /requests/<id>.
::
::  THE WRITER MUST NOT CRASH. +rise-wait restarts a failed process by
::  consuming the next poke without processing it, so every refusal is a
::  branch that returns cleanly and writes /tr/last.
::
::  WHO MAY WRITE. Only this ship's own request fibers poke the writer,
::  and they set `by` honestly: 'pilgrim' for the public routes, 'admin'
::  for the owner's. A foreign ship is refused at the top of +apply.
::
/<  reg   /lib/register.hoon
/&  icon  icon.svg
/&  public-html  public.html
/&  public-css   public.css
/&  public-js    public.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Register'
            info+s+'Baby Steps Camino sign-up and backoffice'
            color+s+'#0b7fc2'
            image+s+'/grubbery/tiles/icon/register'
            href+s+'/apps/register/admin'
        ==
      =/  link=json
        (pairs:enjs:format ~[['name' s+'register'] ['description' s+'Baby Steps Camino registration']])
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'link.json'] [[/ %json] link]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'public.html'] [[/ %mime] public-html]]
          [%over %& [/ %'public.css'] [[/ %mime] public-css]]
          [%over %& [/ %'public.js'] [[/ %mime] public-js]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /regs empty-dir:loader]
          [%fall %| /tr empty-dir:loader]
          [%fall %| /beacon empty-dir:loader]
          [%fall %& [/ %'settings.json'] [[/ %json] starter-settings:reg]]
          [%fall %& [/ %'copy.json'] [[/ %json] starter-copy:reg]]
          [%fall %& [/ %'counts.json'] [[/ %json] [%o ~]]]
          [%fall %& [/beacon %rev] [[/ %json] (numb:enjs:format 0)]]
          [%fall %& [/tr %last] [[/ %json] [%o ~]]]
          [%fall %& [/tr %log] [[/ %json] [%a ~]]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  the writer. It reaches nothing at rise: a jailed install
          ::  would have every bowl poke vetoed.
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%register writer: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ;<  changed=?  bind:m  (apply from sage)
        ;<  ~  bind:m  ?.(changed (pure:m ~) bump-beacon)
        $
          ::  the HTTP binder. bind-http-self is veto-tolerant: jailed,
          ::  it logs and waits; the approval reload binds for real.
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%register web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /apps/register])
        (http-dispatch:io %register)
          ::  one ephemeral fiber per in-flight request
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%register request: failed")
        (handle-request name.rail)
      ==
    --
|%
::  ==  roads
::
++  rf  |=([up=@ud p=path n=@ta] ^-(road:tarball [%| up [%& p n]]))
++  rv  |=([up=@ud p=path] ^-(road:tarball [%| up [%| p]]))
++  srv  ~(. http-res:io [%| 1 %& ~ %'web.sig'])
::  ==  the ask
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the clock and the name of this ship')
          (line '/sys/eyre/' 'serve the sign-up page, the backoffice and the check-in app at /apps/register')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'find where this app is installed, so the page can address its own writer')
      ==
      ['make' a+~]
  ==
::  ==  the writer
::
::  +apply: one op from a poke. Answers whether the tree changed.
::
++  apply
  |=  [=from:fiber:nexus =sage:tarball]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?.  =([/ %json] p.sage)  (pure:m |)
  ;<  our=@p  bind:m  get-our:io
  =/  src=(unit @p)  (get-poke-src:io from)
  ?.  ?|(?=(~ src) =(our u.src))
    (refuse 'poke' 'a foreign ship may not write here')
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  =/  op=@t  (gs:reg jon 'op')
  ?:  =('save-draft' op)  (do-save-draft jon)
  ?:  =('submit' op)  (do-submit jon)
  ?:  =('edit' op)  (do-edit jon)
  ?:  =('cancel' op)  (do-cancel jon)
  ?:  =('advance' op)  (do-advance jon)
  ?:  =('promote' op)  (do-promote jon)
  ?:  =('assist' op)  (do-assist jon)
  ?:  =('note' op)  (do-note jon)
  ?:  =('set-settings' op)  (do-set-doc %'settings.json' 'set-settings' jon)
  ?:  =('set-copy' op)  (do-set-doc %'copy.json' 'set-copy' jon)
  ?:  =('set-counts' op)  (do-set-doc %'counts.json' 'set-counts' jon)
  (refuse op 'unknown op')
::  +refuse: a refusal that leaves the writer standing
::
++  refuse
  |=  [op=@t why=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (note-rid op | why '' '')
  (pure:m |)
::  +trail-entry: one audit row
::
++  trail-entry
  |=  [op=@t ok=? why=@t by=@t rid=@t now=@da]
  ^-  json
  %-  pairs:enjs:format
  :~  ['op' s+op]  ['ok' b+ok]  ['why' s+why]  ['by' s+by]  ['rid' s+rid]  ['at' (en-time:reg now)]
  ==
::  +note-rid: the last writer outcome at /tr/last, and the audit ring
::  at /tr/log (the last 2000). Fiber prints reach only the raw console;
::  a grub is readable by every tool.
::
++  note-rid
  |=  [op=@t ok=? why=@t by=@t rid=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json  (trail-entry op ok why by rid now)
  ;<  ~  bind:m  (over:io (rf 0 /tr %last) [[/ %json] entry])
  ;<  log=json  bind:m  (read-json (rf 0 /tr %log))
  (over:io (rf 0 /tr %log) [[/ %json] (ring:reg log entry max-log:reg)])
::  +bump-beacon: the change beacon moves once per op that changed the
::  tree. Milliseconds since 1970, so a browser keeps it exact.
::
++  bump-beacon
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  ms=@ud  ?:((lth now ~1970.1.1) 0 (div (sub now ~1970.1.1) (div ~s1 1.000)))
  (over:io (rf 0 /beacon %rev) [[/ %json] (numb:enjs:format ms)])
::  +by-of: who a poke says acted, capped
::
++  by-of
  |=  jon=json
  ^-  @t
  =/  b=@t  (gs:reg jon 'by')
  ?:  =('' b)  'pilgrim'
  (end [3 max-by:reg] b)
::  +rid-of: the registration a poke names, or '' when it is not a rid
::
++  rid-of
  |=  jon=json
  ^-  @ta
  =/  r=@t  (gs:reg jon 'rid')
  ?:((ok-rid r) `@ta`r %$)
::  +ok-rid: ten lowercase hex digits
::
++  ok-rid
  |=  t=@t
  ^-  ?
  =/  tap=tape  (trip t)
  ?.  =(10 (lent tap))  |
  %+  levy  `tape`tap
  |=(c=@ |(&((gte c '0') (lte c '9')) &((gte c 'a') (lte c 'f'))))
::  +do-save-draft: a fresh draft, or the fields of an existing one.
::  An autosave is not an audit event; only a fresh draft is noted.
::
++  do-save-draft
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  ?:  =('' rid)  (refuse 'save-draft' 'rid: bad')
  =/  got  (de-input:reg (gj:reg jon 'input') |)
  ?:  ?=(%| -.got)  (refuse 'save-draft' p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur
    =/  r=reg:reg  (new-reg:reg rid (gs:reg jon 'token') %web p.got now)
    ;<  ~  bind:m  (write-reg 0 r &)
    ;<  ~  bind:m  (note-rid 'save-draft' & 'new' 'pilgrim' rid)
    (pure:m &)
  ?.  =(%draft status.u.cur)  (refuse 'save-draft' 'not a draft')
  =/  r=reg:reg  (with-input:reg u.cur p.got)
  ;<  ~  bind:m  (write-reg 0 r(updated now) |)
  (pure:m &)
::  +do-submit: the form becomes a held registration or a wait list row.
::  The caps are checked here, against the tree as it is at this
::  moment, so two submits for the last spot cannot both hold it.
::
++  do-submit
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  ?:  =('' rid)  (refuse 'submit' 'rid: bad')
  =/  got  (de-input:reg (gj:reg jon 'input') &)
  ?:  ?=(%| -.got)  (refuse 'submit' p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 0)
  ?.  (window-open:reg s now)  (refuse 'submit' 'closed')
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?:  &(?=(^ cur) !=(%draft status.u.cur))  (refuse 'submit' 'already submitted')
  =/  base=reg:reg
    ?~  cur  (new-reg:reg rid (gs:reg jon 'token') %web p.got now)
    (with-input:reg u.cur p.got)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 0)
  =/  c=counts:reg  (tally:reg s regs now)
  =/  sold=(unit @t)  (socials-ok:reg s c people.base)
  ?^  sold  (refuse 'submit' u.sold)
  =/  to=@tas  (decide-submit:reg s c track.base people.base)
  =/  r=reg:reg
    ?:  =(%waitlist to)
      (set-status:reg base(position +(waitlist.c)) %waitlist 'pilgrim' 'submitted, wait listed' now)
    (set-status:reg base %waiver 'pilgrim' 'submitted' now)
  ;<  ~  bind:m  (write-reg 0 r ?=(~ cur))
  ;<  ~  bind:m  (note-rid 'submit' & to 'pilgrim' rid)
  (pure:m &)
::  +do-edit: the fields of an active registration, by the pilgrim or
::  an organizer. The route checked the cutoff and the room.
::
++  do-edit
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  got  (de-input:reg (gj:reg jon 'input') &)
  ?:  ?=(%| -.got)  (refuse 'edit' p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'edit' 'no such registration')
  ?.  (active:reg u.cur)  (refuse 'edit' 'not active')
  =/  r=reg:reg  (note-hist:reg (with-input:reg u.cur p.got) by 'edited' now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'edit' & '' by rid)
  (pure:m &)
::  +do-cancel: frees the spots at once
::
++  do-cancel
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'cancel' 'no such registration')
  ?.  (transition-ok:reg status.u.cur %cancelled)  (refuse 'cancel' 'cannot cancel')
  =/  what=@t  (cat 3 'cancelled: ' (end [3 max-notes:reg] (gs:reg jon 'note')))
  =/  r=reg:reg  (set-status:reg u.cur(position 0) %cancelled by what now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'cancel' & '' by rid)
  (pure:m &)
::  +do-advance: one step of the flow, with what the step recorded: the
::  waiver's envelope, the payment's session. The route computed the
::  step; the machine refuses one that does not follow.
::
++  do-advance
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  to=@tas  `@tas`(gs:reg jon 'to')
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'advance' 'no such registration')
  ?.  (transition-ok:reg status.u.cur to)
    (refuse 'advance' (rap 3 'cannot go from ' status.u.cur ' to ' to ~))
  =/  pj=json  (gj:reg jon 'payment')
  =/  wj=json  (gj:reg jon 'waiver')
  =/  r=reg:reg  u.cur
  =/  r=reg:reg
    ?~  pj  r
    %_  r
      payment  :*  `@tas`(gs:reg pj 'method')
                   (fall (gn:reg pj 'amount') 0)
                   (fall (gn:reg pj 'gift') 0)
                   `now
                   (gs:reg pj 'ref')
                   |
                   ''
               ==
    ==
  =/  r=reg:reg
    ?~  wj  r
    r(waiver [`@tas`(gs:reg wj 'method') (gs:reg wj 'envelope') `@tas`(gs:reg wj 'status') `now])
  =/  r=reg:reg  (set-status:reg r to by (end [3 max-notes:reg] (gs:reg jon 'what')) now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'advance' & to by rid)
  (pure:m &)
::  +do-promote: off the wait list and into the flow. The cap is not
::  checked: the organizer looked.
::
++  do-promote
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'promote' 'no such registration')
  ?.  =(%waitlist status.u.cur)  (refuse 'promote' 'not on the wait list')
  =/  r=reg:reg  (set-status:reg u.cur(position 0) %waiver by 'promoted from the wait list' now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'promote' & '' by rid)
  (pure:m &)
::  +do-assist: the organizers' decision on a request for assistance
::
++  do-assist
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  approve=?  (gb:reg jon 'approve')
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'assist' 'no such registration')
  ?.  =(%assistance status.u.cur)  (refuse 'assist' 'not awaiting assistance')
  =/  r=reg:reg
    ?:  approve
      %-  set-status:reg
      :*  u.cur(payment [%assistance 0 0 `now '' | ''])
          %complete  by  'assistance approved'  now
      ==
    (set-status:reg u.cur %payment by 'assistance declined' now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'assist' & ?:(approve 'approved' 'declined') by rid)
  (pure:m &)
::  +do-note: a request fiber's outcome, in the ring. A stub email lands
::  here so a rehearsal can read what would have been sent.
::
++  do-note
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m
    %-  note-rid
    :*  (end [3 32] (gs:reg jon 'what'))
        (gb:reg jon 'ok')
        (end [3 500] (gs:reg jon 'why'))
        (by-of jon)
        (rid-of jon)
    ==
  (pure:m |)
::  +do-set-doc: one of the three documents, whole
::
++  do-set-doc
  |=  [name=@ta op=@t jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:reg jon 'doc')
  ?.  ?=([%o *] doc)  (refuse op 'doc: an object is required')
  ;<  cur=json  bind:m  (read-json (rf 0 / name))
  ?:  =(cur doc)
    ;<  ~  bind:m  (note-rid op & 'unchanged' (by-of jon) '')
    (pure:m |)
  ;<  ~  bind:m  (over:io (rf 0 / name) [[/ %json] doc])
  ;<  ~  bind:m  (note-rid op & '' (by-of jon) '')
  (pure:m &)
::  ==  reads and writes on the tree
::
++  read-json
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] vw)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.vw)))) [%o ~]))
++  read-settings
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,settings:reg)
  ^-  form:m
  ;<  sj=json  bind:m  (read-json (rf up / %'settings.json'))
  (pure:m (de-settings:reg sj))
::  +load-regs: every registration under /regs
::
++  load-regs
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,(list reg:reg))
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv up /regs) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  ?~  fil.ball.vw  (pure:m ~)
  %-  pure:m
  %+  murn  ~(tap by contents.u.fil.ball.vw)
  |=  [nam=@ta c=[=sang:tarball gain=? bang=(unit tang)]]
  (read-reg:reg (sang-noun:tarball sang.c))
++  find-reg
  |=  [up=@ud rid=@ta]
  =/  m  (fiber:fiber:nexus ,(unit reg:reg))
  ^-  form:m
  ?:  =('' rid)  (pure:m ~)
  ;<  vw=view:nexus  bind:m  (peek:io (rf up /regs rid) ~)
  ?.  ?=([%file *] vw)  (pure:m ~)
  (pure:m (read-reg:reg (sang-noun:tarball sang.vw)))
::  +write-reg: a fresh registration with retention on, or the new
::  version of one that exists
::
++  write-reg
  |=  [up=@ud r=reg:reg fresh=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (rf up /regs id.r)
  ?.  fresh
    (over:io road [[/register %reg] `stored-reg:reg`[%1 r]])
  ;<  *  bind:m  (make-gained-soft:io road |+[[[/register %reg] `stored-reg:reg`[%1 r]] ~])
  (pure:m ~)
::  +poke-writer: one op to /main.sig from a request fiber
::
++  poke-writer
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] jon])
::  +lower: ascii lowercase
::
++  lower  |=(t=@t ^-(@t (crip (cass (trip t)))))
::  +is-admin: an actor the owner's routes named, 'admin:<name>'
::
++  is-admin  |=(by=@t ^-(? =('admin:' (end [3 6] by))))
::  +dup-of: an active registration under this email, other than rid
::
++  dup-of
  |=  [regs=(list reg:reg) email=@t rid=@ta]
  ^-  (unit reg:reg)
  =/  want=@t  (lower email)
  ?:  =('' want)  ~
  |-  ^-  (unit reg:reg)
  ?~  regs  ~
  ?:  ?&  (active:reg i.regs)
          !=(rid id.i.regs)
          =(want (lower email.contact.i.regs))
      ==
    `i.regs
  $(regs t.regs)
::  +without: every registration but one
::
++  without
  |=  [regs=(list reg:reg) rid=@ta]
  ^-  (list reg:reg)
  (skip regs |=(r=reg:reg =(rid id.r)))
::  ==  HTTP
::
++  send-json
  |=  [eyre-id=@ta code=@ud jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  =/  heads
    :~  ['content-type' 'application/json']
        ['cache-control' 'no-store']
    ==
  (send-simple:srv eyre-id [[code heads] `bod])
++  send-err
  |=  [eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-json eyre-id code (pairs:enjs:format ~[['error' s+msg]]))
++  send-ok
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  +serve-file: one of the page files, with its own type and nosniff
::
++  serve-file
  |=  [eyre-id=@ta name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  ct=(unit @t)
    ?+  name  ~
      %'public.html'  `'text/html; charset=utf-8'
      %'public.css'   `'text/css; charset=utf-8'
      %'public.js'    `'text/javascript; charset=utf-8'
    ==
  ?~  ct  (send-err eyre-id 404 'no such file')
  ;<  vw=view:nexus  bind:m  (peek:io (rf 1 / name) `[/ %mime])
  ?.  ?=([%file *] vw)  (send-err eyre-id 404 'no such file')
  =/  got=(unit mime)  (mole |.(!<(mime (need-vase:tarball sang.vw))))
  ?~  got  (send-err eyre-id 500 'unreadable file')
  =/  heads
    :~  ['content-type' u.ct]
        ['cache-control' 'no-cache']
        ['x-content-type-options' 'nosniff']
    ==
  (send-simple:srv eyre-id [[200 heads] `q.u.got])
::  +handle-request: one HTTP request, on its own ephemeral fiber. The
::  public routes need no cookie and prove themselves with the
::  registration's token. Everything under /api/admin needs the owner:
::  eyre's authenticated flag with src equal to our.
::
++  handle-request
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  =/  parsed  (parse-url:http-utils url.request.req)
  ::  drop /apps/register; a trailing slash parses as a trailing empty knot
  =/  suffix0=path  (slag 2 site.parsed)
  =/  suffix=path
    ?:  &(?=(^ suffix0) =('' (rear `path`suffix0)))  (snip `path`suffix0)
    suffix0
  =/  meth=@t  method.request.req
  =/  owner=?  &(authenticated.req =(src our))
  =/  own  |=(f=form:m ^-(form:m ?:(owner f (send-err eyre-id 403 'owner only'))))
  ::  the organizer's name, from the header the backoffice sends. A
  ::  change without one is refused so the page can ask.
  =/  actor=@t
    (end [3 max-by:reg] (fall (get-header:http 'x-actor' header-list.request.req) ''))
  =/  admin-by=@t  (cat 3 'admin:' actor)
  =/  act  |=(f=form:m ^-(form:m ?:(=('' actor) (send-err eyre-id 400 'actor: required') f)))
  ::  a body is read as JSON, so a request carrying one says it is JSON
  =/  ctype=@t
    =/  raw=tape
      (cass (trip (fall (get-header:http 'content-type' header-list.request.req) '')))
    (crip raw)
  ?:  ?&  |(=('POST' meth) =('PUT' meth))
          ?=(^ body.request.req)
          !=(0 p.u.body.request.req)
          !=('application/json' (end [3 16] ctype))
      ==
    (send-err eyre-id 415 'content-type: application/json required')
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) ~)
  =/  args=quay:eyre  args.parsed
  =/  tok=@t  (fall (get-key:kv:html-utils 't' args) '')
  =/  s2=@ta  ?:(?=([@ @ @ *] suffix) i.t.t.suffix %$)
  =/  s3=@ta  ?:(?=([@ @ @ @ *] suffix) i.t.t.t.suffix %$)
  ?:  &(=('GET' meth) ?=(~ suffix))                              (serve-file eyre-id %'public.html')
  ?:  &(=('GET' meth) ?=([%'public.css' ~] suffix))               (serve-file eyre-id %'public.css')
  ?:  &(=('GET' meth) ?=([%'public.js' ~] suffix))                (serve-file eyre-id %'public.js')
  ?:  &(=('GET' meth) ?=([%api %status ~] suffix))               (serve-status eyre-id)
  ?:  &(=('POST' meth) ?=([%api %draft ~] suffix))               (serve-draft eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %submit ~] suffix))              (serve-submit eyre-id jon)
  ?:  &(=('GET' meth) ?=([%api %reg @ ~] suffix))                (serve-reg eyre-id s2 tok)
  ?:  &(=('POST' meth) ?=([%api %reg @ %edit ~] suffix))         (serve-edit eyre-id s2 tok jon 'pilgrim')
  ?:  &(=('POST' meth) ?=([%api %reg @ %cancel ~] suffix))       (serve-cancel eyre-id s2 tok jon 'pilgrim')
  ?:  &(=('POST' meth) ?=([%api %reg @ %sign ~] suffix))         (serve-sign eyre-id s2 tok)
  ?:  &(=('POST' meth) ?=([%api %reg @ %pay ~] suffix))          (serve-pay eyre-id s2 tok)
  ?:  &(=('POST' meth) ?=([%api %resend-link ~] suffix))         (serve-resend eyre-id jon)
  ?:  &(=('GET' meth) ?=([%api %admin %regs ~] suffix))          (own (serve-regs eyre-id))
  ?:  &(=('GET' meth) ?=([%api %admin %reg @ ~] suffix))         (own (serve-admin-reg eyre-id s3))
  ?:  &(=('POST' meth) ?=([%api %admin %reg @ ~] suffix))        (own (act (serve-admin-act eyre-id s3 jon admin-by)))
  ?:  &(=('GET' meth) ?=([%api %admin %settings ~] suffix))      (own (serve-settings eyre-id))
  ?:  &(=('PUT' meth) ?=([%api %admin %settings ~] suffix))      (own (act (serve-set-settings eyre-id jon admin-by)))
  ?:  &(=('GET' meth) ?=([%api %admin %copy ~] suffix))          (own (serve-doc eyre-id %'copy.json'))
  ?:  &(=('PUT' meth) ?=([%api %admin %copy ~] suffix))          (own (act (serve-set-doc eyre-id 'set-copy' jon admin-by)))
  (send-err eyre-id 404 'no such route')
::  +with-reg: the registration a public route names, proven by its
::  token. A wrong token and a missing registration answer the same.
::
++  with-reg
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,(unit reg:reg))
  ^-  form:m
  ?.  (ok-rid rid)  (pure:m ~)
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 1 `@ta`rid)
  ?~  cur  (pure:m ~)
  ?.  &(!=('' tok) =(tok token.u.cur))  (pure:m ~)
  (pure:m cur)
::  +serve-status: the meter, the caps, the window and the copy
::
++  serve-status
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  sj=json  bind:m  (read-json (rf 1 / %'settings.json'))
  ;<  cj=json  bind:m  (read-json (rf 1 / %'copy.json'))
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  s=settings:reg  (de-settings:reg sj)
  (send-json eyre-id 200 (status-json:reg s sj cj (tally:reg s regs now) now))
::  +serve-draft: a draft the moment there is an email or a phone. The
::  rid and token come back so the page can resume and submit.
::
++  serve-draft
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  got  (de-input:reg jon |)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  =/  want=@t  (gs:reg jon 'rid')
  =/  tok=@t  (gs:reg jon 'token')
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id want tok)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  fresh=?  |(?=(~ cur) !=(%draft status.u.cur))
  =/  rid=@ta  ?:(fresh (rid-from:reg eny) id.u.cur)
  =/  token=@t  ?:(fresh (token-from:reg eny) token.u.cur)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'save-draft']  ['rid' s+rid]  ['token' s+token]  ['input' jon]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['rid' s+rid] ['token' s+token]]))
::  +serve-submit: validate, check the window, the duplicate and the
::  socials, decide the wait list, and hand the form to the writer,
::  which decides again against the tree as it is when the poke lands.
::
++  serve-submit
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  got  (de-input:reg jon &)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?.  (window-open:reg s now)  (send-err eyre-id 403 'closed')
  =/  want=@t  (gs:reg jon 'rid')
  =/  tok=@t  (gs:reg jon 'token')
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id want tok)
  ?:  &(?=(^ cur) !=(%draft status.u.cur))  (send-err eyre-id 409 'already submitted')
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  rid=@ta  ?~(cur (rid-from:reg eny) id.u.cur)
  =/  token=@t  ?~(cur (token-from:reg eny) token.u.cur)
  ?^  (dup-of regs email.contact.p.got rid)
    %^  send-json  eyre-id  409
    (pairs:enjs:format ~[['error' s+'email: already registered'] ['code' s+'duplicate']])
  =/  c=counts:reg  (tally:reg s regs now)
  =/  sold=(unit @t)  (socials-ok:reg s c people.p.got)
  ?^  sold  (send-err eyre-id 400 u.sold)
  =/  to=@tas  (decide-submit:reg s c track.p.got people.p.got)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'submit']  ['rid' s+rid]  ['token' s+token]  ['input' jon]  ['by' s+'pilgrim']
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  =/  probe=reg:reg  (new-reg:reg rid token %web p.got now)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['rid' s+rid]
      ['token' s+token]
      ['status' s+to]
      ['position' (en-num:reg ?:(=(%waitlist to) +(waitlist.c) 0))]
      ['fees' (en-num:reg (fees-total:reg s probe))]
  ==
::  +serve-reg: the pilgrim's view of their own registration
::
++  serve-reg
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  =/  j=json  (en-reg-pilgrim:reg u.cur (fees-total:reg s u.cur))
  ?.  ?=([%o *] j)  (send-json eyre-id 200 j)
  =/  extra=(map @t json)
    %-  malt
    ^-  (list [@t json])
    :~  ['changes_open' b+(changes-open:reg s now)]
        ['mode' s+mode.s]
    ==
  (send-json eyre-id 200 [%o (~(uni by p.j) extra)])
::  +serve-edit: a change to an active registration. A pilgrim is held
::  to the cutoff; an organizer is not. Room is checked against the
::  tree without this registration, so a party may grow only into free
::  spots and a sold-out social stays sold out.
::
++  serve-edit
  |=  [eyre-id=@ta rid=@t tok=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m
    ?:  (is-admin by)  (find-reg 1 ?:((ok-rid rid) `@ta`rid %$))
    (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?.  (active:reg u.cur)  (send-err eyre-id 409 'not active')
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?:  &(=('pilgrim' by) !(changes-open:reg s now))  (send-err eyre-id 403 'changes closed')
  =/  got  (de-input:reg jon &)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ?^  (dup-of regs email.contact.p.got id.u.cur)
    %^  send-json  eyre-id  409
    (pairs:enjs:format ~[['error' s+'email: already registered'] ['code' s+'duplicate']])
  =/  c=counts:reg  (tally:reg s (without regs id.u.cur) now)
  =/  sold=(unit @t)  (socials-ok:reg s c people.p.got)
  ?^  sold  (send-err eyre-id 400 u.sold)
  ?:  ?&  !=(%waitlist status.u.cur)
          =(%waitlist (decide-submit:reg s c track.p.got people.p.got))
      ==
    (send-err eyre-id 409 'people: no room for the added people')
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'edit']  ['rid' s+id.u.cur]  ['input' jon]  ['by' s+by]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  =/  after=reg:reg  (with-input:reg u.cur p.got)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['ok' b+&]
      ['fees_before' (en-num:reg (fees-total:reg s u.cur))]
      ['fees' (en-num:reg (fees-total:reg s after))]
  ==
++  serve-cancel
  |=  [eyre-id=@ta rid=@t tok=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m
    ?:  (is-admin by)  (find-reg 1 ?:((ok-rid rid) `@ta`rid %$))
    (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?.  (transition-ok:reg status.u.cur %cancelled)  (send-err eyre-id 409 'cannot cancel')
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?:  &(=('pilgrim' by) !(changes-open:reg s now))  (send-err eyre-id 403 'changes closed')
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'cancel']  ['rid' s+id.u.cur]  ['by' s+by]  ['note' s+(gs:reg jon 'note')]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-ok eyre-id)
::  +serve-sign: the waiver step. In stub mode it completes itself; the
::  live branch is phase 2.
::
++  serve-sign
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?.  =(%waiver status.u.cur)  (send-err eyre-id 409 'not at the waiver step')
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?:  =(%live mode.s)  (send-err eyre-id 501 'signing is not configured yet')
  =/  to=@tas  (after-waiver:reg u.cur)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'advance']  ['rid' s+id.u.cur]  ['to' s+to]  ['by' s+'pilgrim']
        ['what' s+'signed the waiver (stub)']
        ['waiver' (pairs:enjs:format ~[['method' s+'stub'] ['envelope' s+''] ['status' s+'completed']])]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['next' s+to]]))
::  +serve-pay: the payment step, the same way
::
++  serve-pay
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?:  =(%assistance status.u.cur)  (send-err eyre-id 409 'awaiting the assistance decision')
  ?.  =(%payment status.u.cur)  (send-err eyre-id 409 'not at the payment step')
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?:  =(%live mode.s)  (send-err eyre-id 501 'payment is not configured yet')
  =/  fees=@ud  (fees-total:reg s u.cur)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'advance']  ['rid' s+id.u.cur]  ['to' s+'complete']  ['by' s+'pilgrim']
        ['what' s+'paid (stub)']
        :-  'payment'
        %-  pairs:enjs:format
        :~  ['method' s+'stub']  ['amount' (en-num:reg fees)]  ['gift' (en-num:reg 0)]  ['ref' s+'stub']
        ==
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['next' s+'complete']]))
::  +serve-resend: the manage link to an address that has a registration.
::  Answers the same whether or not one exists. Phase 2 sends the mail;
::  here the outcome is noted in the ring.
::
++  serve-resend
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  email=@t  (gs:reg jon 'email')
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  hit=(unit reg:reg)  (dup-of regs email '')
  ;<  *  bind:m
    %-  poke-writer
    %-  pairs:enjs:format
    :~  ['op' s+'note']  ['what' s+'resend-link']  ['ok' b+?=(^ hit)]
        ['why' s+?~(hit 'no active registration' 'stub: not sent')]
        ['by' s+'pilgrim']  ['rid' s+?~(hit '' id.u.hit)]
    ==
  (send-ok eyre-id)
::  ==  the owner's routes
::
++  serve-regs
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ;<  now=@da  bind:m  get-time:io
  =/  c=counts:reg  (tally:reg s regs now)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['regs' a+(turn regs |=(r=reg:reg (en-reg:reg r (fees-total:reg s r))))]
      :-  'counts'
      %-  pairs:enjs:format
      :~  ['full' (en-num:reg full.c)]  ['bambino' (en-num:reg bambino.c)]
          ['social_fri' (en-num:reg social-fri.c)]  ['social_sat' (en-num:reg social-sat.c)]
          ['late' (en-num:reg late.c)]  ['waitlist' (en-num:reg waitlist.c)]
      ==
  ==
++  serve-admin-reg
  |=  [eyre-id=@ta rid=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 1 ?:((ok-rid rid) `@ta`rid %$))
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ;<  s=settings:reg  bind:m  (read-settings 1)
  (send-json eyre-id 200 (en-reg:reg u.cur (fees-total:reg s u.cur)))
::  +serve-admin-act: an organizer's action on one registration, named
::  by op. Phase 3 grows this list.
::
++  serve-admin-act
  |=  [eyre-id=@ta rid=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  op=@t  (gs:reg jon 'op')
  ?:  =('edit' op)  (serve-edit eyre-id rid '' (gj:reg jon 'input') by)
  ?:  =('cancel' op)  (serve-cancel eyre-id rid '' jon by)
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 1 ?:((ok-rid rid) `@ta`rid %$))
  ?~  cur  (send-err eyre-id 404 'no such registration')
  =/  pk=(unit json)
    ?:  =('promote' op)
      `(pairs:enjs:format ~[['op' s+'promote'] ['rid' s+id.u.cur] ['by' s+by]])
    ?:  =('assist' op)
      `(pairs:enjs:format ~[['op' s+'assist'] ['rid' s+id.u.cur] ['by' s+by] ['approve' b+(gb:reg jon 'approve')]])
    ~
  ?~  pk  (send-err eyre-id 400 'op: promote, assist, edit or cancel')
  ?:  &(=('promote' op) !=(%waitlist status.u.cur))  (send-err eyre-id 409 'not on the wait list')
  ?:  &(=('assist' op) !=(%assistance status.u.cur))  (send-err eyre-id 409 'not awaiting assistance')
  ;<  err=(unit tang)  bind:m  (poke-writer u.pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-ok eyre-id)
++  serve-doc
  |=  [eyre-id=@ta name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / name))
  (send-json eyre-id 200 doc)
++  serve-settings
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / %'settings.json'))
  (send-json eyre-id 200 (mask:reg doc))
::  +serve-set-settings: a masked secret coming back keeps the stored one
::
++  serve-set-settings
  |=  [eyre-id=@ta jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  ;<  old=json  bind:m  (read-json (rf 1 / %'settings.json'))
  =/  pk=json  (pairs:enjs:format ~[['op' s+'set-settings'] ['doc' (unmask:reg jon old)] ['by' s+by]])
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-ok eyre-id)
++  serve-set-doc
  |=  [eyre-id=@ta op=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  =/  pk=json  (pairs:enjs:format ~[['op' s+op] ['doc' jon] ['by' s+by]])
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-ok eyre-id)
--
```

- [ ] **Step 3: Commit and push, so the forge can mirror the repo**

The GitHub repo does not exist yet. Create it under the nisfeb account (already the active `gh` account), public, as the spec names it:

```bash
cd /home/sneagan/software/personal/register
git add code
git commit -m "The nexus: the tree, the writer, the public flow in stub mode, and the owner's routes"
gh repo create nisfeb/register --public --source=. --remote=origin --push
git remote -v
# expected: origin  git@github.com:nisfeb/register.git (fetch and push), and main pushed
```

If `gh repo create` fails because the repo exists, `git remote add origin git@github.com:nisfeb/register.git` and `git push -u origin main`.

- [ ] **Step 4: Mirror the repo on `~wex` and install the desk**

Log in first (recipe under Working with `~wex`). Then:

```bash
W=http://localhost:8080; CK=/tmp/wex.cookies
curl -s -b $CK -X POST -H 'content-type: application/json' \
  -d '{"name":"register","repo":"nisfeb/register","ref":"main"}' $W/grubbery/forge/api/add
# expected: created   (409 "a repo by that name already exists" means a previous attempt; continue)
```

Wait for the pull, checking every 10 seconds for at most 3 minutes:

```bash
curl -s -b $CK "$W/grubbery/ball/apps/forge.git_forge/repos/register.git_repo/data/tree/code/version.json?raw=1"
# expected, once pulled: {"version": 1}
```

If nothing arrives in 3 minutes, STOP and report; do not retry blindly. Then the desk:

```bash
curl -s -b $CK -X POST -H 'content-type: application/json' \
  -d '{"name":"register","code":"/apps/forge.git_forge/repos/register.git_repo/data/tree/code"}' $W/apps/grubbery/desks/add
# expected: created
```

- [ ] **Step 5: Wait for the instance and read its bang**

Check every 15 seconds for at most 3 minutes:

```bash
I="$W/grubbery/ball/apps/shell.shell/desks/register.desk/desk/data/register.register_app"
curl -s -b $CK "$I?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("bang:", d.get("bang")); print("children:", [c["name"] for c in d.get("children",[])])'
```

Expected: `bang: None` and children including `main.sig`, `web.sig`, `regs`, `settings.json`, `copy.json`, `counts.json`, `beacon`, `tr`, `requests`. A `bang` string is the compile error with its line and column: fix `code/nex/register/app.hoon` in the repo, then use the fast loop (write-text, reload-nexus, read the bang again) until it is `None`. Commit each fix with a message naming what the compiler said.

- [ ] **Step 6: Approve the ask and reload**

```bash
APP=/apps/shell.shell/desks/register.desk/desk/data/register.register_app
curl -s -b $CK -X POST -H 'content-type: application/json' -d "{\"action\":\"approve-weir\",\"app\":\"$APP\",\"granted\":{\"poke\":[\"/sys/bowl.sig\",\"/sys/eyre/\"],\"peek\":[\"/sys/link/\"],\"make\":[]}}" $W/apps/grubbery/permits
# expected: ok. The granted object is required: the shell treats a missing one as an empty grant.
curl -s -b $CK -X POST -H 'content-type: application/json' -d "{\"app\":\"$APP\"}" $W/apps/grubbery/permits/reload
# expected: ok
sleep 15
curl -s -b $CK "$I?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["weir"])'
# expected: poke lists /sys/bowl.sig and /sys/eyre/; read lists /sys/link/
```

- [ ] **Step 7: Smoke the routes by hand**

```bash
curl -s -o /dev/null -w '%{http_code}\n' $W/apps/register/            # 200, no cookie
curl -s $W/apps/register/api/status | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["counts"], d["caps"]["full"], d["open"], d["mode"], d["copy"]["landing.title"])'
# expected: {'full': 0, ...} 325 True stub Register for the Baby Steps Camino
# (open is True only inside the window; the starter window opens 2026-10-01. If today is before that, PUT a window that is open now through the admin route below, then check again.)
curl -s -o /dev/null -w '%{http_code}\n' $W/apps/register/api/admin/regs           # 403
curl -s -b $CK -o /dev/null -w '%{http_code}\n' $W/apps/register/api/admin/regs    # 200
curl -s -X POST -H 'content-type: application/json' -d '{"track":"full","contact":{"phone":"904"},"people":[]}' $W/apps/register/api/draft
# expected: {"rid":"<10 hex>","token":"<32 hex>"}
curl -s -b $CK "$I/tr/last?raw=1"
# expected: {"op":"save-draft","ok":true,"why":"new",...}
```

To open the window for testing before October 1:

```bash
curl -s -b $CK $W/apps/register/api/admin/settings > /tmp/settings.json
python3 - <<'PY'
import json; d=json.load(open('/tmp/settings.json'))
d['window']={'open':'2026-01-01T00:00:00Z','close':'2026-12-03T05:00:00Z','change_cutoff':'2026-12-04T05:00:00Z'}
json.dump(d,open('/tmp/settings.json','w'))
PY
curl -s -b $CK -X PUT -H 'content-type: application/json' -H 'x-actor: matrix' -d @/tmp/settings.json $W/apps/register/api/admin/settings
# expected: {"ok":true}. Without the x-actor header: 400 {"error":"actor: required"}
```

- [ ] **Step 8: Commit any fixes**

```bash
git add code
git commit -m "The nexus builds on wex: <what the compiler said, if anything>"
git push origin main
```

---

### Task 4: The pilgrim's page

**Files:**
- Replace: `code/nex/register/public.html`, `code/nex/register/public.css`, `code/nex/register/public.js`

**Interfaces:**
- Consumes: `GET /api/status` (copy, counts, caps, fees, open, changes_open, orgs, mode), `POST /api/draft`, `POST /api/submit`, `GET /api/reg/<rid>?t=`, `POST /api/reg/<rid>/{edit,cancel,sign,pay}?t=`, `POST /api/resend-link`, all from Task 3.
- Produces: the hash routes `#` (landing), `#form/full`, `#form/bambino`, `#next/<rid>/<token>`, `#manage/<rid>/<token>`, which phase 2's emails and redirects link to.

- [ ] **Step 1: The document**

`code/nex/register/public.html`:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Register for the Baby Steps Camino</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Open+Sans:wght@400;600&family=Poppins:wght@500;600&display=swap">
<link rel="stylesheet" href="/apps/register/public.css">
</head>
<body>
<header>
  <a class="brand" href="https://babystepscamino.com">Baby Steps Camino<span class="reg">&reg;</span></a>
  <a class="back" href="#">Registration</a>
</header>
<div id="banner" class="banner" hidden></div>
<main id="view"><p class="muted">Loading.</p></main>
<footer><p class="muted">Sovereign Military Hospitaller Order of Saint John of Jerusalem of Rhodes and of Malta, American Association. A 501(c)(3) organization.</p></footer>
<script src="/apps/register/public.js"></script>
</body>
</html>
```

- [ ] **Step 2: The style**

`code/nex/register/public.css`:

```css
:root {
  --bg: #ffffff; --ink: #272727; --muted: #6b6b6b; --line: #e4e4e4; --soft: #f6f6f6;
  --accent: #0b7fc2; --accent-ink: #ffffff; --accent-soft: #e6f4fc; --bad: #b3261e; --good: #2e7d32;
  --body: "Open Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
  --head: "Poppins", "Open Sans", system-ui, sans-serif;
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body { margin: 0; font: 16px/1.55 var(--body); color: var(--ink); background: var(--bg); }
header { display: flex; align-items: center; justify-content: space-between; padding: .9rem 16px; border-bottom: 1px solid var(--line); }
header .brand { font-family: var(--head); font-weight: 600; font-size: 1.05rem; color: var(--ink); text-decoration: none; letter-spacing: .01em; }
header .brand .reg { font-size: .6em; vertical-align: super; }
header .back { color: var(--accent); text-decoration: none; font-weight: 600; }
main { max-width: 760px; margin: 0 auto; padding: 1.2rem 16px 3rem; }
footer { max-width: 760px; margin: 0 auto; padding: 0 16px 2rem; font-size: .8rem; }
h1, h2, h3 { font-family: var(--head); font-weight: 600; line-height: 1.25; margin: 0 0 .5rem; }
h1 { font-size: 1.7rem; }
h2 { font-size: 1.15rem; margin-top: 1.6rem; }
h3 { font-size: 1rem; }
p { margin: 0 0 .8rem; }
.muted { color: var(--muted); }
.bad { color: var(--bad); }
.banner { background: #fff4d6; color: #5b4300; padding: .5rem 16px; text-align: center; font-size: .9rem; }
.card { border: 1px solid var(--line); border-radius: 10px; padding: 1rem 1.1rem; margin-bottom: 1rem; background: var(--bg); }
.card.soft { background: var(--soft); border-color: transparent; }
.doors { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 600px) { .doors { grid-template-columns: 1fr; } }
.meter { margin: 1rem 0 1.5rem; }
.meter .bar { height: 12px; background: var(--soft); border-radius: 6px; overflow: hidden; }
.meter .fill { height: 100%; background: var(--accent); border-radius: 6px; transition: width .4s; }
.meter .label { font-size: .9rem; color: var(--muted); margin-top: .35rem; }
.btn { display: inline-block; font: 600 1rem var(--body); padding: .65rem 1.2rem; border-radius: 6px; border: 2px solid var(--accent); background: var(--accent); color: var(--accent-ink); cursor: pointer; text-decoration: none; }
.btn:hover { filter: brightness(1.08); }
.btn.quiet { background: transparent; color: var(--accent); }
.btn.danger { border-color: var(--bad); background: transparent; color: var(--bad); }
.btn[disabled] { opacity: .5; cursor: default; }
.btn.small { font-size: .85rem; padding: .35rem .7rem; }
label { display: block; font-weight: 600; font-size: .9rem; margin: .7rem 0 .25rem; }
input[type=text], input[type=email], input[type=tel], textarea, select {
  width: 100%; font: 1rem var(--body); padding: .55rem .65rem; border: 1px solid #c4c4c4; border-radius: 6px; background: var(--bg); color: var(--ink);
}
input:focus, textarea:focus, select:focus { outline: 2px solid var(--accent-soft); border-color: var(--accent); }
textarea { min-height: 5.5rem; resize: vertical; }
.row { display: grid; grid-template-columns: 1fr 1fr; gap: 0 1rem; }
.row3 { display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 0 1rem; }
@media (max-width: 600px) { .row, .row3 { grid-template-columns: 1fr; } }
.check { display: flex; align-items: flex-start; gap: .6rem; font-weight: 400; font-size: .95rem; margin: .45rem 0; }
.check input { margin-top: .3rem; width: 1.1rem; height: 1.1rem; accent-color: var(--accent); flex: none; }
.check .note { color: var(--muted); font-size: .85rem; }
.check.off { color: var(--muted); }
.help { color: var(--muted); font-size: .85rem; margin: .1rem 0 .6rem; }
.person { position: relative; }
.person .remove { position: absolute; top: .8rem; right: .9rem; }
.fees table { width: 100%; border-collapse: collapse; }
.fees td { padding: .3rem 0; border-bottom: 1px solid var(--line); }
.fees td:last-child { text-align: right; }
.fees tr.total td { font-weight: 600; border-bottom: none; }
.actions { display: flex; gap: .8rem; align-items: center; flex-wrap: wrap; margin-top: 1.2rem; }
.status { font-size: .85rem; color: var(--muted); }
.error { background: #fdecea; color: var(--bad); padding: .6rem .8rem; border-radius: 6px; margin: .8rem 0; }
.ok { color: var(--good); }
```

- [ ] **Step 3: The script**

`code/nex/register/public.js`:

```js
// register's public page: the landing with the meter, the form with its
// drafts, the next step, and the manage page, over /apps/register/api.
// Every string a pilgrim reads comes from copy.json through /api/status.
(function () {
  'use strict';
  var API = '/apps/register/api';
  var view = document.getElementById('view');
  var banner = document.getElementById('banner');
  var status = null;          // the last /api/status
  var model = null;           // the form's data, the shape /api/submit takes
  var rid = null, token = null, mode = 'new';
  var saveTimer = null, dirty = false;

  // ---- helpers ----
  function esc(s) {
    return String(s === undefined || s === null ? '' : s).replace(/[<>&"']/g, function (c) {
      return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function t(key, vars) {
    var s = (status && status.copy && status.copy[key]) || key;
    Object.keys(vars || {}).forEach(function (k) { s = s.split('{{' + k + '}}').join(String(vars[k])); });
    return s;
  }
  function money(cents) {
    var d = cents / 100;
    return '$' + (cents % 100 ? d.toFixed(2) : d.toFixed(0));
  }
  function api(path, opts) {
    return fetch(API + path, opts).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        if (!r.ok) { var e = new Error(d.error || ('http ' + r.status)); e.code = d.code; e.status = r.status; throw e; }
        return d;
      });
    });
  }
  function post(path, body) {
    return api(path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body || {}) });
  }
  function blankPerson() {
    return { first: '', last: '', child: false, days: { fri: false, sat: false, sun: false }, sun_ten: false,
      social_fri: false, social_sat: false, mass_fri: false, holy_hour: false, bus: false,
      first_bsc: false, knight_dame: false, volunteer: false };
  }
  function blankModel(track) {
    return { track: track, contact: { email: '', phone: '', street: '', city: '', state: '', zip: '' },
      org: '', why: '', assistance: false, together: false, people: [blankPerson()] };
  }
  function fromReg(r) {
    return { track: r.track, contact: r.contact, org: r.org, why: r.why, assistance: r.assistance,
      together: r.together, people: r.people.map(function (p) { var q = {}; Object.keys(blankPerson()).forEach(function (k) { q[k] = p[k]; }); return q; }) };
  }
  function fee(p, track) { return track === 'bambino' ? status.fees.bambino : status.fees.full; }
  function feeLines(m) {
    var by = {};
    m.people.forEach(function (p) { var c = fee(p, m.track); by[c] = (by[c] || 0) + 1; });
    return Object.keys(by).map(function (c) { return { each: +c, n: by[c] }; });
  }
  function fees(m) { return m.people.reduce(function (s, p) { return s + fee(p, m.track); }, 0); }
  function soldOut(which) { return status.counts[which] >= status.caps[which]; }
  function trackFull(track) {
    return track === 'bambino' ? status.counts.bambino >= status.caps.bambino : status.counts.full >= status.caps.full;
  }
  function setPath(obj, path, val) {
    var ks = path.split('.'), o = obj;
    for (var i = 0; i < ks.length - 1; i++) o = o[ks[i]];
    o[ks[ks.length - 1]] = val;
  }

  // ---- render ----
  function landing() {
    var pct = Math.min(100, Math.round(100 * status.counts.full / Math.max(1, status.caps.full)));
    var out = '<h1>' + esc(t('landing.title')) + '</h1><p>' + esc(t('landing.intro')) + '</p>';
    out += '<div class="meter"><div class="bar"><div class="fill" style="width:' + pct + '%"></div></div>' +
      '<div class="label">' + esc(t('landing.meter', { count: status.counts.full, cap: status.caps.full, percent: pct })) + '</div></div>';
    if (!status.open) return out + '<div class="card soft"><p>' + esc(t('landing.closed')) + '</p></div>';
    function door(track) {
      var full = trackFull(track);
      return '<div class="card"><h2>' + esc(t('landing.' + track + '.title')) + '</h2><p>' + esc(t('landing.' + track + '.blurb')) + '</p>' +
        (full ? '<p class="muted">' + esc(t('landing.soldout')) + '</p><a class="btn quiet" href="#form/' + track + '">' + esc(t('landing.waitlist.button')) + '</a>'
              : '<a class="btn" href="#form/' + track + '">' + esc(t('landing.' + track + '.button')) + '</a>') + '</div>';
    }
    return out + '<div class="doors">' + door('full') + door('bambino') + '</div>';
  }
  function input(k, key, value, type, extra) {
    return '<label>' + esc(t(key)) + '<input type="' + (type || 'text') + '" data-k="' + k + '" value="' + esc(value) + '"' + (extra || '') + '></label>';
  }
  function check(k, key, on, off, note) {
    return '<label class="check' + (off ? ' off' : '') + '"><input type="checkbox" data-k="' + k + '"' + (on ? ' checked' : '') + (off ? ' disabled' : '') + '>' +
      '<span>' + esc(t(key)) + (note ? ' <span class="note">' + esc(note) + '</span>' : '') + '</span></label>';
  }
  function choices(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '<h3>' + esc(t('form.days')) + '</h3>';
    if (m.track === 'full') {
      out += check(k + 'days.fri', 'form.fri', p.days.fri) + check(k + 'days.sat', 'form.sat', p.days.sat) + check(k + 'days.sun', 'form.sun', p.days.sun);
      if (p.days.sun) out += check(k + 'sun_ten', 'form.sun_ten', p.sun_ten);
    } else {
      out += check(k + 'days.sun', 'form.sun', p.days.sun);
    }
    out += check(k + 'social_fri', 'form.social_fri', p.social_fri, soldOut('social_fri') && !p.social_fri, soldOut('social_fri') && !p.social_fri ? t('form.social_soldout') : '');
    out += check(k + 'social_sat', 'form.social_sat', p.social_sat, soldOut('social_sat') && !p.social_sat, soldOut('social_sat') && !p.social_sat ? t('form.social_soldout') : '');
    out += check(k + 'mass_fri', 'form.mass_fri', p.mass_fri) + check(k + 'holy_hour', 'form.holy_hour', p.holy_hour) + check(k + 'bus', 'form.bus', p.bus);
    return out;
  }
  function person(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '<div class="card person"><h2>' + esc(t('form.person', { n: i + 1 })) + '</h2>';
    if (m.people.length > 1) out += '<button type="button" class="btn quiet small remove" data-act="remove" data-i="' + i + '">' + esc(t('form.remove_person')) + '</button>';
    out += '<div class="row">' + input(k + 'first', 'form.first', p.first) + input(k + 'last', 'form.last', p.last) + '</div>';
    out += check(k + 'child', 'form.child', p.child);
    if (i === 0 || !m.together) out += choices(p, i, m);
    out += check(k + 'first_bsc', 'form.first_bsc', p.first_bsc) + check(k + 'knight_dame', 'form.knight_dame', p.knight_dame) + check(k + 'volunteer', 'form.volunteer', p.volunteer);
    return out + '</div>';
  }
  function feesBox(m) {
    var out = '<div class="card soft fees"><h2>' + esc(t('form.fees.title')) + '</h2><table>';
    feeLines(m).forEach(function (l) { out += '<tr><td>' + esc(t('form.fees.line', { n: l.n, each: money(l.each) })) + '</td><td>' + esc(money(l.n * l.each)) + '</td></tr>'; });
    return out + '<tr class="total"><td>' + esc(t('form.fees.total')) + '</td><td>' + esc(money(fees(m))) + '</td></tr></table>' +
      '<p class="help">' + esc(t('form.fees.nonrefundable')) + '</p></div>';
  }
  function form(m) {
    var c = m.contact;
    var out = '<h1>' + esc(t(mode === 'manage' ? 'manage.title' : 'form.title')) + '</h1>';
    if (mode === 'manage' && !status.changes_open) out += '<div class="card soft"><p>' + esc(t('manage.closed')) + '</p></div>';
    out += '<div id="error"></div>';
    out += '<div class="card"><h2>' + esc(t('form.contact.title')) + '</h2>';
    out += '<div class="row">' + input('contact.email', 'form.email', c.email, 'email', ' autocomplete="email"') + input('contact.phone', 'form.phone', c.phone, 'tel', ' autocomplete="tel"') + '</div>';
    out += input('contact.street', 'form.street', c.street, 'text', ' autocomplete="street-address"');
    out += '<div class="row3">' + input('contact.city', 'form.city', c.city, 'text', ' autocomplete="address-level2"') +
      input('contact.state', 'form.state', c.state, 'text', ' autocomplete="address-level1" maxlength="40"') +
      input('contact.zip', 'form.zip', c.zip, 'text', ' autocomplete="postal-code"') + '</div>';
    out += input('org', 'form.org', m.org, 'text', ' list="orgs"') + '<datalist id="orgs">' +
      (status.orgs || []).map(function (o) { return '<option value="' + esc(o) + '">'; }).join('') + '</datalist>';
    out += '</div>';
    out += '<h2>' + esc(t('form.people.title')) + '</h2>';
    if (m.people.length > 1) out += check('together', 'form.together', m.together);
    m.people.forEach(function (p, i) { out += person(p, i, m); });
    if (m.people.length < status.caps.party) out += '<button type="button" class="btn quiet small" data-act="add">' + esc(t('form.add_person')) + '</button>';
    out += '<div class="card"><label>' + esc(t('form.why')) + '<textarea data-k="why">' + esc(m.why) + '</textarea></label>';
    out += check('assistance', 'form.assistance', m.assistance) + '<p class="help">' + esc(t('form.assistance.help')) + '</p></div>';
    out += feesBox(m);
    out += '<div class="actions">';
    if (mode === 'manage') {
      if (status.changes_open) {
        out += '<button type="button" class="btn" data-act="save">' + esc(t('manage.save')) + '</button>' +
          '<button type="button" class="btn danger" data-act="cancel">' + esc(t('manage.cancel')) + '</button>';
      }
    } else {
      out += '<button type="button" class="btn" data-act="submit">' + esc(t('form.submit')) + '</button>';
    }
    return out + '<span id="save-status" class="status"></span></div>';
  }
  function nextStep(r) {
    var s = r.status, out = '';
    function block(key, vars) { return '<h1>' + esc(t('next.' + key + '.title')) + '</h1><p>' + esc(t('next.' + key + '.body', vars)) + '</p>'; }
    if (s === 'waiver') out = block('waiver') + '<button type="button" class="btn" data-act="sign">' + esc(t('next.waiver.button')) + '</button>';
    else if (s === 'payment') out = block('payment') + '<button type="button" class="btn" data-act="pay">' + esc(t('next.payment.button', { total: money(r.fees) })) + '</button>';
    else if (s === 'assistance') out = block('assistance');
    else if (s === 'waitlist') out = block('waitlist', { position: r.position });
    else if (s === 'complete') out = block('complete', { email: r.contact.email }) + '<p><a class="btn quiet" href="#manage/' + esc(rid) + '/' + esc(token) + '">' + esc(t('manage.title')) + '</a></p>';
    else if (s === 'cancelled') out = block('cancelled');
    else out = '<h1>' + esc(s) + '</h1>';
    return '<div id="error"></div>' + out;
  }

  // ---- the app ----
  function showError(msg, extra) {
    var el = document.getElementById('error');
    if (el) el.innerHTML = msg ? '<div class="error">' + esc(msg) + (extra || '') + '</div>' : '';
  }
  function say(msg) { var el = document.getElementById('save-status'); if (el) el.textContent = msg; }
  function remember() { try { sessionStorage.setItem('bsc.draft', JSON.stringify({ rid: rid, token: token, track: model.track })); } catch (e) { } }
  function recall(track) {
    try { var d = JSON.parse(sessionStorage.getItem('bsc.draft') || 'null'); if (d && d.track === track) return d; } catch (e) { }
    return null;
  }
  function scheduleSave() {
    if (mode !== 'new') return;
    dirty = true;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(save, 1200);
  }
  function save() {
    if (mode !== 'new' || !dirty) return;
    if (!model.contact.email && !model.contact.phone) return;
    dirty = false;
    var body = JSON.parse(JSON.stringify(model));
    if (rid) { body.rid = rid; body.token = token; }
    return post('/draft', body).then(function (d) { rid = d.rid; token = d.token; remember(); say(t('form.saving')); })
      .catch(function () { say(''); });
  }
  function submit() {
    var body = JSON.parse(JSON.stringify(model));
    if (rid) { body.rid = rid; body.token = token; }
    showError('');
    post('/submit', body).then(function (d) {
      rid = d.rid; token = d.token; try { sessionStorage.removeItem('bsc.draft'); } catch (e) { }
      location.hash = '#next/' + rid + '/' + token;
    }).catch(function (e) {
      if (e.code === 'duplicate') {
        showError(t('form.error.duplicate'), '<p><button type="button" class="btn quiet small" data-act="resend">' + esc(t('form.resend')) + '</button></p>');
      } else showError(e.message);
      window.scrollTo(0, 0);
    });
  }
  function refreshStatus() { return api('/status').then(function (d) { status = d; banner.hidden = d.mode !== 'stub'; if (!banner.hidden) banner.textContent = t('stub.banner'); }); }
  function render(html) { view.innerHTML = html; }
  function route() {
    var h = location.hash.replace(/^#\/?/, '');
    var parts = h.split('/');
    refreshStatus().then(function () {
      if (parts[0] === 'form' && (parts[1] === 'full' || parts[1] === 'bambino')) {
        mode = 'new';
        if (!model || model.track !== parts[1]) {
          model = blankModel(parts[1]);
          var d = recall(parts[1]); rid = d ? d.rid : null; token = d ? d.token : null;
          if (rid) {
            return api('/reg/' + rid + '?t=' + encodeURIComponent(token)).then(function (r) {
              if (r.status === 'draft') model = fromReg(r); else { rid = null; token = null; }
              render(form(model));
            }).catch(function () { rid = null; token = null; render(form(model)); });
          }
        }
        return render(form(model));
      }
      if (parts[0] === 'next' && parts[1] && parts[2]) {
        rid = parts[1]; token = parts[2]; mode = 'next';
        return api('/reg/' + rid + '?t=' + encodeURIComponent(token)).then(function (r) { render(nextStep(r)); })
          .catch(function (e) { render('<div id="error"></div>'); showError(e.message); });
      }
      if (parts[0] === 'manage' && parts[1] && parts[2]) {
        rid = parts[1]; token = parts[2]; mode = 'manage';
        return api('/reg/' + rid + '?t=' + encodeURIComponent(token)).then(function (r) {
          status.changes_open = r.changes_open;
          if (r.status === 'draft' || r.status === 'cancelled') { location.hash = '#next/' + rid + '/' + token; return; }
          model = fromReg(r); render(form(model));
        }).catch(function (e) { render('<div id="error"></div>'); showError(e.message); });
      }
      model = null; rid = null; token = null; mode = 'landing';
      render(landing());
    }).catch(function (e) { render('<p class="bad">' + esc(e.message) + '</p>'); });
  }
  view.addEventListener('input', onChange);
  view.addEventListener('change', onChange);
  function onChange(ev) {
    var el = ev.target, k = el.getAttribute('data-k');
    if (!k || !model) return;
    var val = el.type === 'checkbox' ? el.checked : el.value;
    setPath(model, k, val);
    // structural changes re-render; a keystroke only updates the fees
    if (k === 'together' || /\.days\.sun$/.test(k)) { render(form(model)); }
    else { var fb = view.querySelector('.fees'); if (fb) fb.outerHTML = feesBox(model); }
    scheduleSave();
  }
  view.addEventListener('click', function (ev) {
    var el = ev.target.closest('[data-act]');
    if (!el) return;
    var act = el.getAttribute('data-act');
    if (act === 'add') { model.people.push(blankPerson()); render(form(model)); scheduleSave(); }
    else if (act === 'remove') { model.people.splice(+el.getAttribute('data-i'), 1); render(form(model)); scheduleSave(); }
    else if (act === 'submit') { clearTimeout(saveTimer); dirty = false; submit(); }
    else if (act === 'save') {
      showError('');
      post('/reg/' + rid + '/edit?t=' + encodeURIComponent(token), model).then(function (d) {
        say(t('form.saving'));
        if (d.fees > d.fees_before) showError(t('manage.pay_more', { diff: money(d.fees - d.fees_before) }));
      }).catch(function (e) { showError(e.message); window.scrollTo(0, 0); });
    }
    else if (act === 'cancel') {
      if (!window.confirm(t('manage.cancel.confirm'))) return;
      post('/reg/' + rid + '/cancel?t=' + encodeURIComponent(token), {}).then(function () { location.hash = '#next/' + rid + '/' + token; })
        .catch(function (e) { showError(e.message); });
    }
    else if (act === 'sign' || act === 'pay') {
      el.disabled = true;
      post('/reg/' + rid + '/' + act + '?t=' + encodeURIComponent(token), {}).then(function (d) {
        if (d.url) { location.href = d.url; return; }
        route();
      }).catch(function (e) { el.disabled = false; showError(e.message); });
    }
    else if (act === 'resend') {
      post('/resend-link', { email: model.contact.email }).then(function () { showError(t('form.resend.done')); });
    }
  });
  window.addEventListener('hashchange', route);
  window.addEventListener('beforeunload', function () { if (dirty) save(); });
  route();
})();
```

- [ ] **Step 4: Write the three files to `~wex` with the fast loop and click through**

```bash
W=http://localhost:8080; CK=/tmp/wex.cookies
D=$W/grubbery/ball/apps/shell.shell/desks/register.desk/desk
for f in public.html public.css public.js; do
  curl -s -b $CK -X POST --data-urlencode action=write-text --data-urlencode content@code/nex/register/$f "$D/code/nex/register/$f"; echo
done
curl -s -b $CK -X POST --data-urlencode action=reload-nexus "$D/data/register.register_app" -o /dev/null
sleep 20; curl -s -b $CK "$D/data/register.register_app?info=1" | python3 -c 'import sys,json; print(json.load(sys.stdin)["bang"])'
curl -s $W/apps/register/public.js | head -3
```

Then in a browser with no cookie, open `http://localhost:8080/apps/register/`: the landing shows the meter and the two doors; the full door opens the form; typing an email and waiting a second shows "Saved"; adding a second person shows the together switch; submit lands on the waiver step; sign then pay land on "You are registered" with a link to the manage page; the manage page saves an edit and cancels. If the window is closed today, open it as Task 3 step 7 shows.

- [ ] **Step 5: Commit and push**

```bash
git add code/nex/register/public.html code/nex/register/public.css code/nex/register/public.js
git commit -m "The pilgrim's page: the landing with the meter, the form with drafts, the next step, and the manage page"
git push origin main
```

---

### Task 5: The gates, the docs, and version 2 through the forge

**Files:**
- Create: `scripts/api-matrix.py`, `scripts/page-smoke.py`, `scripts/code-closure.py`
- Create: `docs/releasing.md`, `README.md`
- Modify: `code/version.json`

**Interfaces:**
- Produces: the two gates every later phase reruns, and a desk that syncs from GitHub through the forge by a version bump, which is the production path.

- [ ] **Step 1: The HTTP gate**

`scripts/api-matrix.py`:

```python
#!/usr/bin/env python3
"""api-matrix.py HOST JAR
The HTTP gate for register, phase 1: the pilgrim's flow in stub mode
against a fake ship. HOST like http://localhost:8080; JAR a curl cookie
jar with the owner cookie. Exits 1 on any failure. Safe to rerun: it
cancels what an earlier run left and restores the settings it changed."""
import json, subprocess, sys, time

HOST, JAR = sys.argv[1:3]
API = HOST + '/apps/register/api'
INSTANCE = HOST + '/grubbery/ball/apps/shell.shell/desks/register.desk/desk/data/register.register_app'
ACTOR = 'matrix'
fails = []


def curl(method, url, body=None, jar=None, actor=None, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    if jar:
        cmd += ['-b', jar]
    if actor:
        cmd += ['-H', 'x-actor: ' + actor]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def check(label, cond, detail=''):
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


def admin(method, path, body=None):
    return curl(method, API + path, body, jar=JAR, actor=ACTOR)


def settle():
    # the writer applies after the answer leaves; a read right after a write races it
    time.sleep(1.5)


def person(first, last, **kw):
    p = {'first': first, 'last': last, 'child': False, 'days': {'fri': True, 'sat': True, 'sun': True}, 'sun_ten': True,
         'social_fri': False, 'social_sat': False, 'mass_fri': False, 'holy_hour': False, 'bus': False,
         'first_bsc': True, 'knight_dame': False, 'volunteer': False}
    p.update(kw)
    return p


def party(track, email, people, **kw):
    d = {'track': track, 'contact': {'email': email, 'phone': '904-555-0100', 'street': '1 Beach Rd',
                                     'city': 'Jacksonville Beach', 'state': 'FL', 'zip': '32250'},
         'org': 'Matrix', 'why': 'the gate', 'assistance': False, 'together': False, 'people': people}
    d.update(kw)
    return d


def reg(rid, tok):
    return curl('GET', API + f'/reg/{rid}?t={tok}')


def status():
    code, d = curl('GET', API + '/status')
    check('GET /status answers 200', code == 200, (code, d))
    return d


# ---- settings: open the window, remember the original ----
code, original = admin('GET', '/settings')
check('GET /admin/settings answers 200 with the cookie', code == 200 and isinstance(original, dict), (code, original))
code, _ = curl('GET', API + '/settings')
check('GET /admin/settings without the cookie is 404 (no such public route)', code == 404, code)
code, _ = curl('GET', API + '/admin/regs')
check('GET /admin/regs without the cookie is 403', code == 403, code)
code, _ = curl('PUT', API + '/admin/settings', original, jar=JAR)
check('PUT /admin/settings without x-actor is 400', code == 400, code)
check('secrets come back masked or empty', original.get('mail', {}).get('resend_key', '') in ('', '****'), original.get('mail'))

settings = json.loads(json.dumps(original))
settings['window'] = {'open': '2026-01-01T00:00:00Z', 'close': '2036-01-01T00:00:00Z', 'change_cutoff': '2036-01-01T00:00:00Z'}
settings['caps'] = {'full': 325, 'bambino': 25, 'social_fri': 300, 'social_sat': 200, 'late_adds': 50}
settings['providers'] = {'mode': 'stub'}
code, _ = admin('PUT', '/settings', settings)
check('PUT /admin/settings opens the window', code == 200, code)
settle()

# ---- clean what an earlier run left ----
code, d = admin('GET', '/regs')
check('GET /admin/regs answers 200', code == 200, (code, d))
for r in (d or {}).get('regs', []):
    if r['contact']['email'].startswith('matrix-') and r['status'] not in ('draft', 'cancelled'):
        admin('POST', '/reg/' + r['id'], {'op': 'cancel', 'note': 'matrix cleanup'})
settle()
s0 = status()
base_full = s0['counts']['full']
base_sat = s0['counts']['social_sat']
check('status carries the copy', s0['copy'].get('landing.title', '') != '', s0.get('copy', {}).keys())
check('status is open in stub mode', s0['open'] and s0['mode'] == 'stub', (s0['open'], s0['mode']))

# ---- drafts ----
code, d = curl('POST', API + '/draft', {'track': 'full', 'contact': {'phone': '904'}, 'people': []})
check('a draft with only a phone answers a rid and a token', code == 200 and len(d.get('rid', '')) == 10 and len(d.get('token', '')) == 32, (code, d))
draft_rid, draft_tok = d['rid'], d['token']
code, d = curl('POST', API + '/draft', {'track': 'full', 'contact': {'street': 's'}, 'people': []})
check('a draft with no email or phone is 400 naming contact', code == 400 and d['error'].startswith('contact:'), (code, d))
code, d = curl('POST', API + '/draft', {'track': 'full', 'contact': {'email': 'matrix-draft@example.com'}, 'people': [], 'rid': draft_rid, 'token': draft_tok})
check('a draft updates in place', code == 200 and d['rid'] == draft_rid, (code, d))
settle()
code, d = reg(draft_rid, draft_tok)
check('the draft reads back with its email', code == 200 and d['status'] == 'draft' and d['contact']['email'] == 'matrix-draft@example.com', (code, d))
code, d = reg(draft_rid, 'wrong')
check('a wrong token is 404', code == 404, code)

# ---- the full flow, a party of three, together ----
p = party('full', 'matrix-ana@example.com',
          [person('Ana', 'Silva', social_fri=True, social_sat=True), person('Bo', 'Silva', child=True), person('Cy', 'Silva')], together=True)
code, d = curl('POST', API + '/submit', p)
check('submit answers waiver with the fees', code == 200 and d['status'] == 'waiver' and d['fees'] == 22500, (code, d))
ana_rid, ana_tok = d['rid'], d['token']
settle()
code, d = reg(ana_rid, ana_tok)
check('the registration is at the waiver step with 3 people', code == 200 and d['status'] == 'waiver' and len(d['people']) == 3, (code, d))
check('together copied the socials to the child', d['people'][1]['social_sat'] is True and d['people'][1]['child'] is True, d['people'][1])
check('the pilgrim view has no history and no token', 'history' not in d and 'token' not in d, d.keys())
code, d = curl('POST', API + f'/reg/{ana_rid}/pay?t={ana_tok}', {})
check('paying before signing is 409', code == 409, (code, d))
code, d = curl('POST', API + f'/reg/{ana_rid}/sign?t={ana_tok}', {})
check('sign (stub) answers next payment', code == 200 and d['next'] == 'payment', (code, d))
settle()
code, d = curl('POST', API + f'/reg/{ana_rid}/pay?t={ana_tok}', {})
check('pay (stub) answers next complete', code == 200 and d['next'] == 'complete', (code, d))
settle()
code, d = reg(ana_rid, ana_tok)
check('complete, paid 22500 by stub, waiver completed', code == 200 and d['status'] == 'complete' and d['payment']['amount'] == 22500 and d['payment']['method'] == 'stub' and d['waiver']['status'] == 'completed', (code, d))
s1 = status()
check('the meter counts the three walkers', s1['counts']['full'] == base_full + 3, (s1['counts'], base_full))
check('the socials count the three', s1['counts']['social_sat'] == base_sat + 3, s1['counts'])

# ---- duplicate ----
code, d = curl('POST', API + '/submit', party('full', 'Matrix-Ana@example.com', [person('Ana', 'Again')]))
check('the same email again is 409 duplicate, case-insensitive', code == 409 and d.get('code') == 'duplicate', (code, d))
code, d = curl('POST', API + '/resend-link', {'email': 'matrix-ana@example.com'})
check('resend-link answers 200', code == 200, (code, d))
code, d = curl('POST', API + '/resend-link', {'email': 'nobody@example.com'})
check('resend-link answers 200 for a stranger too', code == 200, (code, d))

# ---- bambino ----
code, d = curl('POST', API + '/submit', party('bambino', 'matrix-bam@example.com', [person('Di', 'Bambino', days={'fri': False, 'sat': False, 'sun': True}), person('Ed', 'Bambino', days={'fri': False, 'sat': False, 'sun': True})]))
check('a bambino party of two owes 5000', code == 200 and d['fees'] == 5000 and d['status'] == 'waiver', (code, d))
bam_rid, bam_tok = d['rid'], d['token']
settle()
curl('POST', API + f'/reg/{bam_rid}/sign?t={bam_tok}', {}); settle()
curl('POST', API + f'/reg/{bam_rid}/pay?t={bam_tok}', {}); settle()
s2 = status()
check('the bambino count moved by two and the full count did not', s2['counts']['bambino'] >= 2 and s2['counts']['full'] == base_full + 3, s2['counts'])

# ---- non-walkers owe nothing and take no spot ----
code, d = curl('POST', API + '/submit', party('full', 'matrix-non@example.com', [person('Fay', 'Shrine', days={'fri': False, 'sat': False, 'sun': False})]))
check('a non-walker pays the track fee and gets a spot without counting', code == 200 and d['fees'] == 7500 and d['status'] == 'waiver', (code, d))
non_rid, non_tok = d['rid'], d['token']

# ---- financial assistance ----
code, d = curl('POST', API + '/submit', party('full', 'matrix-help@example.com', [person('Gus', 'Help')], assistance=True))
check('an assistance request submits to waiver', code == 200 and d['status'] == 'waiver', (code, d))
help_rid, help_tok = d['rid'], d['token']
settle()
code, d = curl('POST', API + f'/reg/{help_rid}/sign?t={help_tok}', {})
check('after signing it waits for assistance', code == 200 and d['next'] == 'assistance', (code, d))
settle()
code, d = curl('POST', API + f'/reg/{help_rid}/pay?t={help_tok}', {})
check('paying while awaiting assistance is 409', code == 409, (code, d))
code, d = admin('POST', '/reg/' + help_rid, {'op': 'assist', 'approve': True})
check('the organizer approves', code == 200, (code, d))
settle()
code, d = admin('GET', '/reg/' + help_rid)
check('approved: complete, paid by assistance, history names admin:matrix', code == 200 and d['status'] == 'complete' and d['payment']['method'] == 'assistance' and any(h['by'] == 'admin:matrix' for h in d['history']), (code, d))
code, d = admin('POST', '/reg/' + help_rid, {'op': 'assist', 'approve': True})
check('approving twice is 409', code == 409, code)

# ---- the cap and the wait list ----
s3 = status()
settings['caps']['full'] = s3['counts']['full'] + 1
admin('PUT', '/settings', settings); settle()
code, d = curl('POST', API + '/submit', party('full', 'matrix-wait1@example.com', [person('Hal', 'Wait'), person('Ivy', 'Wait')]))
check('a party of two over the cap is wait listed at position 1', code == 200 and d['status'] == 'waitlist' and d['position'] == 1, (code, d))
w1_rid, w1_tok = d['rid'], d['token']
settle()
code, d = curl('POST', API + '/submit', party('full', 'matrix-wait2@example.com', [person('Jo', 'Wait'), person('Kim', 'Wait')]))
check('the next party is position 2', code == 200 and d['status'] == 'waitlist' and d['position'] == 2, (code, d))
w2_rid, w2_tok = d['rid'], d['token']
settle()
code, d = curl('POST', API + '/submit', party('full', 'matrix-one@example.com', [person('Lee', 'One')]))
check('a party of one still fits the last spot', code == 200 and d['status'] == 'waiver', (code, d))
one_rid, one_tok = d['rid'], d['token']
settle()
code, d = curl('POST', API + f'/reg/{w1_rid}/sign?t={w1_tok}', {})
check('a wait listed party cannot sign', code == 409, code)
s4 = status()
check('the meter shows the cap reached and two on the wait list', s4['counts']['full'] == s4['caps']['full'] and s4['counts']['waitlist'] >= 2, (s4['counts'], s4['caps']))
code, d = admin('POST', '/reg/' + w1_rid, {'op': 'promote'})
check('the organizer promotes the first', code == 200, (code, d))
settle()
code, d = reg(w1_rid, w1_tok)
check('promoted: at the waiver step, position 0', code == 200 and d['status'] == 'waiver' and d['position'] == 0, (code, d))
code, d = admin('POST', '/reg/' + w1_rid, {'op': 'promote'})
check('promoting twice is 409', code == 409, code)

# ---- a sold-out social ----
s5 = status()
settings['caps']['social_sat'] = s5['counts']['social_sat']
settings['caps']['full'] = 325
admin('PUT', '/settings', settings); settle()
code, d = curl('POST', API + '/submit', party('full', 'matrix-sat@example.com', [person('Mo', 'Social', social_sat=True)]))
check('a sold-out social is refused naming social_sat', code == 400 and d['error'].startswith('social_sat'), (code, d))
code, d = curl('POST', API + '/submit', party('full', 'matrix-sat@example.com', [person('Mo', 'Social', social_fri=True)]))
check('the other social still takes', code == 200, (code, d))
sat_rid, sat_tok = d['rid'], d['token']
settings['caps']['social_sat'] = 200
admin('PUT', '/settings', settings); settle()

# ---- edit and cancel through the manage link ----
edited = party('full', 'matrix-one@example.com', [person('Lee', 'Won', social_fri=True), person('Max', 'Won')])
code, d = curl('POST', API + f'/reg/{one_rid}/edit?t={one_tok}', edited)
check('an edit that adds a person answers the new fees', code == 200 and d['fees'] == 15000 and d['fees_before'] == 7500, (code, d))
settle()
code, d = admin('GET', '/reg/' + one_rid)
check('the edit landed with a history line by pilgrim', code == 200 and d['people'][0]['last'] == 'Won' and len(d['people']) == 2 and d['history'][-1]['by'] == 'pilgrim', (code, d))
code, d = curl('POST', API + f'/reg/{one_rid}/edit?t={one_tok}', party('full', 'matrix-ana@example.com', [person('Lee', 'Won')]))
check('an edit onto another registration email is 409 duplicate', code == 409 and d.get('code') == 'duplicate', (code, d))
settings['window']['change_cutoff'] = '2020-01-01T00:00:00Z'
admin('PUT', '/settings', settings); settle()
code, d = curl('POST', API + f'/reg/{one_rid}/edit?t={one_tok}', edited)
check('after the cutoff a pilgrim edit is 403', code == 403, (code, d))
code, d = curl('POST', API + f'/reg/{one_rid}/cancel?t={one_tok}', {})
check('after the cutoff a pilgrim cancel is 403', code == 403, (code, d))
code, d = admin('POST', '/reg/' + one_rid, {'op': 'edit', 'input': edited})
check('an organizer edits past the cutoff', code == 200, (code, d))
settings['window']['change_cutoff'] = '2036-01-01T00:00:00Z'
admin('PUT', '/settings', settings); settle()
s6 = status()
code, d = curl('POST', API + f'/reg/{one_rid}/cancel?t={one_tok}', {})
check('the pilgrim cancels', code == 200, (code, d))
settle()
code, d = reg(one_rid, one_tok)
check('cancelled, position 0', code == 200 and d['status'] == 'cancelled', (code, d))
s7 = status()
check('cancelling freed two spots', s7['counts']['full'] == s6['counts']['full'] - 2, (s6['counts'], s7['counts']))
code, d = curl('POST', API + f'/reg/{one_rid}/cancel?t={one_tok}', {})
check('cancelling twice is 409', code == 409, code)

# ---- the window ----
settings['window']['close'] = '2020-01-01T00:00:00Z'
admin('PUT', '/settings', settings); settle()
code, d = curl('POST', API + '/submit', party('full', 'matrix-late@example.com', [person('Ned', 'Late')]))
check('a submit after close is 403', code == 403, (code, d))
s8 = status()
check('status says closed', s8['open'] is False, s8['open'])

# ---- restore, then cancel every matrix registration ----
code, _ = admin('PUT', '/settings', original)
check('the original settings are restored', code == 200, code)
settle()
code, d = admin('GET', '/regs')
for r in (d or {}).get('regs', []):
    if r['contact']['email'].startswith('matrix-') and r['status'] not in ('draft', 'cancelled'):
        admin('POST', '/reg/' + r['id'], {'op': 'cancel', 'note': 'matrix cleanup'})
settle()
code, d = curl('GET', INSTANCE + '/tr/log?raw=1', jar=JAR)
check('the audit ring has rows with a by', code == 200 and isinstance(d, list) and any(e.get('by') == 'admin:matrix' for e in d), (code, str(d)[:200]))
check('no secret in the audit ring', code == 200 and 'resend_key' not in json.dumps(d), '')

print()
print('ALL OK' if not fails else f'{len(fails)} FAILED: ' + '; '.join(fails))
sys.exit(1 if fails else 0)
```

- [ ] **Step 2: The page smoke**

`scripts/page-smoke.py`:

```python
#!/usr/bin/env python3
"""page-smoke.py HOST
The public page and its assets answer without a cookie, with the right
types, nosniff and no-cache; the admin routes refuse without one."""
import subprocess, sys

HOST = sys.argv[1]
fails = []


def get(path):
    out = subprocess.run(['curl', '-s', '-m', '30', '-D', '-', HOST + path], capture_output=True, text=True).stdout
    head, _, body = out.partition('\r\n\r\n')
    if not _:
        head, _, body = out.partition('\n\n')
    code = int(head.split(' ')[1]) if head.startswith('HTTP/') else 0
    headers = {}
    for ln in head.split('\n')[1:]:
        k, _, v = ln.partition(':')
        headers[k.strip().lower()] = v.strip()
    return code, headers, body


def check(label, cond, detail=''):
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


code, h, b = get('/apps/register/')
check('the page answers 200 as html without a cookie', code == 200 and h.get('content-type', '').startswith('text/html'), (code, h))
check('the page is not cached', 'no-cache' in h.get('cache-control', ''), h)
check('the page loads its script and style', 'public.js' in b and 'public.css' in b and 'id="view"' in b, b[:200])
code, h, b = get('/apps/register/public.css')
check('the style is text/css with nosniff', code == 200 and h.get('content-type', '').startswith('text/css') and h.get('x-content-type-options') == 'nosniff', (code, h))
code, h, b = get('/apps/register/public.js')
check('the script is text/javascript', code == 200 and h.get('content-type', '').startswith('text/javascript'), (code, h))
code, h, b = get('/apps/register/api/status')
check('status is json and not stored', code == 200 and h.get('content-type', '').startswith('application/json') and 'no-store' in h.get('cache-control', ''), (code, h))
code, h, b = get('/apps/register/api/admin/regs')
check('the admin api refuses without a cookie', code == 403, code)
code, h, b = get('/apps/register/nothing')
check('an unknown route is 404', code == 404, code)
print()
print('ALL OK' if not fails else f'{len(fails)} FAILED: ' + '; '.join(fails))
sys.exit(1 if fails else 0)
```

- [ ] **Step 3: Run both gates**

```bash
cd /home/sneagan/software/personal/register
python3 scripts/api-matrix.py http://localhost:8080 /tmp/wex.cookies
python3 scripts/page-smoke.py http://localhost:8080
```

Expected: `ALL OK` from both. A `FAIL` line names the check; read `<instance>/tr/last?raw=1` for what the writer said. Fix the nexus or the library in the repo, write it with the fast loop, rerun. Run the matrix a second time once it passes: it must be green on a tree its own first run left behind.

- [ ] **Step 4: The closure check, the docs, the README**

```bash
\cp /home/sneagan/software/personal/orrery/scripts/code-closure.py scripts/code-closure.py
python3 scripts/code-closure.py code
# expected: nothing missing. If it names a marc or lib, vendor it from the kernel desk as Task 1 did and rerun.
sed -e 's/orrery\.desk/register.desk/g' -e 's/orrery\.git_repo/register.git_repo/g' \
    -e 's/orrery\.orrery_app/register.register_app/g' -e 's/nisfeb\/orrery/nisfeb\/register/g' \
    -e 's/\/apps\/orrery/\/apps\/register/g' -e 's/Orrery/Register/g' -e 's/orrery/register/g' \
    /home/sneagan/software/personal/orrery/docs/releasing.md > docs/releasing.md
```

Then edit `docs/releasing.md` by hand: delete section 9 (the ricsul install record, which is orrery's history) and replace section 8, the release checklist, with register's:

```markdown
##  8. Register's own release checklist

1. `code/version.json` bumped, the number one higher than the last release.
2. `python3 scripts/code-closure.py code` reports nothing missing.
3. Unit tests green on `~wex`: `-test /~wex/grubbery/<rev>/tests/lib/register ~`.
4. `python3 scripts/api-matrix.py http://localhost:8080 /tmp/wex.cookies` prints `ALL OK`, twice in a row.
5. `python3 scripts/page-smoke.py http://localhost:8080` prints `ALL OK`.
6. Open `/apps/register/` on `~wex` in a browser without the cookie: the landing, the form, a draft that says Saved, submit, sign, pay, the manage page.
7. `git push origin main`, then on `~wex`: `POST /grubbery/forge/api/run {"repo":"register.git_repo","command":"pull"}`, and within a minute the desk's root `version.json` reads the new number and the instance's `bang` is `null`.
8. The event ship's steps are sneagan's.
```

`README.md`, short, user-first:

```markdown
# register

Sign-up and event backoffice for the Baby Steps Camino, on an Urbit ship running grubbery. Pilgrims register a party, sign the waiver, pay, and manage their registration from a link. Organizers run caps, the wait list, financial assistance, reports, exports and the daily check-in from `/apps/register/admin`.

The design is in `docs/superpowers/specs/2026-09-17-register-design.md`. The release mechanics are in `docs/releasing.md`. Phase 1 (this release) covers the pilgrim's flow with the providers stubbed; phase 2 adds Stripe, DocuSign and Resend.

## Try it on a ship

```bash
W=http://localhost:8080
curl -s $W/apps/register/api/status | python3 -m json.tool | head -30     # the meter, the caps, the copy
```

Open `$W/apps/register/` in a browser. Nothing on the public page needs a login. The owner's routes under `/apps/register/api/admin` need the ship's cookie and an `X-Actor` header naming the organizer.
```

- [ ] **Step 5: Version 2 through the forge, commit, push**

```bash
cd /home/sneagan/software/personal/register
printf '{"version": 2}\n' > code/version.json
git add scripts docs README.md code/version.json
git commit -m "Version 2: the HTTP gate, the page smoke, the closure check, the releasing doc, the README"
git push origin main
W=http://localhost:8080; CK=/tmp/wex.cookies
curl -s -b $CK -X POST -H 'content-type: application/json' -d '{"repo":"register.git_repo","command":"pull"}' $W/grubbery/forge/api/run
# expected: ok
```

Then, checking every 15 seconds for at most 3 minutes:

```bash
curl -s -b $CK "$W/grubbery/ball/apps/shell.shell/desks/register.desk/version.json?raw=1"
# expected: {"version": 2}
curl -s -b $CK "$W/grubbery/ball/apps/shell.shell/desks/register.desk/desk/data/register.register_app?info=1" | python3 -c 'import sys,json; print(json.load(sys.stdin)["bang"])'
# expected: None
python3 scripts/api-matrix.py $W $CK | tail -1
# expected: ALL OK, against the code the forge delivered rather than the fast loop's writes
```

- [ ] **Step 6: Report**

Phase 1 is done when: 20 unit tests green with the revision pinned, `api-matrix.py` green twice, `page-smoke.py` green, the click-through in Task 4 step 4 seen, the desk at version 2 synced through the forge with a null bang, and `main` pushed. Report those facts with the numbers you saw and the wex desk revision the tests ran at. Do not touch `~ricsul-bilwyt` or any ship but `~wex`.

---

## Self-review against the spec

- Section 3, the flow: Tasks 3 and 4 cover choose, form, drafts, submit, wait list, sign and pay in stub mode, done with the manage link. The 48 hour hold is in `counted` and tested in `test-tally`.
- Section 4, the rules: fees (`fee`, `fees-total`; every person pays the track fee), caps and non-walkers (`tally`, `decide-submit`), the wait list with a position, payment and waiver as stubs with the status machine ready for phase 2, changes and cancellations with the cutoff, duplicates (`dup-of`), history on every registration plus the ring, the window. Refunds and manual payments are phase 3's admin actions.
- Section 8, the tree and the writer: every path has an `on-load` row; the writer re-decides the cap; the ops list matches.
- Section 9, surfaces: every public route of phase 1 is in `handle-request`; the admin routes present are the ones phase 3 builds on. Live updates through the beacon are consumed by the backoffice in phase 3; the writer already bumps it.
- Section 11, the page: the palette, the fonts, the meter first, copy from `/api/status`, native inputs, 16px gutter.
- Section 12, constraints: rows, marcs, relative roads, no crash in the writer, secrets masked, caps on every string, no HTML from pilgrim text on the ship.
- Section 13, testing: the unit list and the HTTP gate items for phase 1 map to `tests/lib/register.hoon` and `scripts/api-matrix.py`.
- Not in this phase, by design: providers (2), backoffice pages, reports, exports, import and the jam (3), check-in (4), emails (2).
