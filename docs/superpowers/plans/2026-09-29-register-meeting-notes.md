# Register: the five things from the 2026-09-29 meeting

sneagan's notes, verbatim:

1. make sure pilgrims can't add more people in their edit page once the
   limit has been reached.
2. indicate the days to registration close under the save button on the
   pilgrim edit page.
3. missing saturday's mass on the registration page.
4. missing the trolley on sunday and mass on sunday as separate items.
   also the trolley and mass should be options for both full pilgrims
   and bambino camino pilgrims.
5. every time we save a setting an extra 0 is added to the fee. it was
   as high as 75000.00 before i noticed.

Answered in the session: the trolley is **a separate Sunday ride**, not
the motorcoach already on the form; the countdown in item 2 runs to
**registration close** (`window.close`), which the organizers say is
November 25, not the December 3 the starter settings carry.

One implementer, one review, one fix pass. `~wex` is not running as this
is written, so the ship steps wait on it; everything that does not need a
ship is done first. The comet `~hadmyn` holds three registrations already,
so the shape lift in item 4 must carry them.

## 5. The fee gains two zeros on every save (do this first)

`+settingsView` prints the fee box in dollars, `(cents / 100)`, but
`settingsDoc` still holds the ship's cents. The save then runs
`cents(getPath(settingsDoc, 'fees.full'))` over that untouched cents
value, so 7500 is stored as 750000 and read back as $7500.00. Touching
the box masks it, because typing writes dollars into `settingsDoc`; any
save that leaves the fees alone multiplies both fees by a hundred.
Two saves reach the $75,000 the organizers saw.

Fix in `admin.js`, without touching the ship:

- The two fee inputs get their own keys, `fees_dollars.full` and
  `fees_dollars.bambino`, seeded from the stored cents. `onChange` then
  writes a typed dollar amount there and never over the cents.
- `save-settings` converts `fees_dollars.*` to cents **only for a box
  that holds something**, leaves the stored value alone otherwise, and
  deletes the helper key before the PUT.
- The same rule for the numbers beside them: a blank cap, hold or
  offset box keeps what is stored rather than saving zero, which is the
  other half of the same bug and was already on the backlog.
- A node assertion over a pure `settingsBody(doc, typed)` helper: an
  untouched document round-trips unchanged through a save, a typed 80
  becomes 8000, a blank box keeps the stored cents, and two saves in a
  row change nothing.

Then repair the live ships: read `/api/admin/settings` on each, and if a
fee is not a sane number of cents, PUT the right one back. The comet read
$75 and $25 correctly on 2026-09-29; check again after the release.

## 1. No adding people to a full track from the edit page

The ship already refuses it: `+serve-edit` answers 409 `people: no room
for the added people` when the edited party would be wait-listed. The
page does not know that, so a pilgrim fills in a fourth person and loses
the typing to a refusal they cannot act on.

In `public.js` `+form`, the `Add a person` button already hides at the
party cap of twelve. In `manage` mode it also hides when
`trackFull(m.track)`, and a line takes its place: copy key
`manage.full`, default "The {{track}} is full, so nobody can be added to
this registration. Write to us and we will see what we can do." The
submit path is untouched: a new party that does not fit is still offered
the wait list, which is the right answer there.

## 2. How long is left, under the Save button

Under Save and Cancel on the manage page, one line from the ship's own
clock: copy key `manage.closes_in`, default "Registration closes in
{{days}} days." With `{{days}}` at 1 the copy reads oddly, so the page
picks between three keys: `manage.closes_in`, `manage.closes_today`
("Registration closes today.") and `manage.closed_already`
("Registration has closed. You can still change this registration until
{{cutoff}}."). The count is whole days from `status.now` to
`status.window.close`, rounded up, so the last day reads "closes in 1
day" rather than zero.

Nothing on the ship changes. The organizers must set the close date to
November 25 in Settings for the number to be right; the starter value is
December 3.

## 3 and 4. Mass on all three days, and the Sunday trolley

`person` today carries `mass-fri`, `holy-hour`, `social-fri`,
`social-sat` and `bus`. It gains three fields:

```
mass-sat=?     mass-sun=?     trolley=?
```

`bus` keeps its meaning, the motorcoach that runs each day. `trolley` is
the separate Sunday ride.

**The shape ladder.** `person` changes, so every stored registration
must be lifted. `stored-reg` becomes `[%3 =reg]`. The current shapes are
kept under their own names for the reader: `person-2` (today's person),
`reg-2` (today's reg, over `person-2`) and `reg-1` (the pre-exempt reg,
also over `person-2`). `+lift-person` maps a `person-2` to a `person`
with the three new fields false. `+read-reg` tries `%3`, then `%2`
lifting every person, then `%1` lifting the people and filling `exempt`
and `prior` as it already does. Tests: a `%1` noun and a `%2` noun both
read as `%3` with the new fields false and everything else intact.

**The form** (`public.js` `+choices`), for the full track:

- Friday keeps Mass, the Holy Hour and the Ajua social.
- Saturday gains `mass_sat` above the Pusser's social.
- A new Sunday group, shown when Sunday is ticked, holds `mass_sun` and
  `trolley`. It sits between Saturday and Getting around.
- Getting around keeps the motorcoach alone.

For the Bambino track the "Also this weekend" group gains `mass_sat`,
`mass_sun` and `trolley` beside what it already offers, because both
tracks may come to any of it. The Sunday group's contents appear there
rather than as a fourth group, since a Bambino pilgrim's whole weekend
is Sunday.

New copy, all editable in place afterwards:

```
form.mass_sat   8:00am Mass at Our Lady Star of the Sea, Ponte Vedra
form.mass_sun   Sunday Mass at the Shrine
form.sunday.title   Sunday
form.trolley    Needs a seat on the trolley on Sunday
```

The venue and the times are the organizers' to correct with Edit text;
the defaults name a plausible place so the line is not empty.

**Everything that lists a person's fields** moves with it: `+de-person`
and `+en-person`, `+en-reg-full` and `+de-reg-full`, `+en-plan`,
`+planned`, `+en-roster-person`, `+csv-people`'s header and rows, the
backoffice's `personCard`, the check-in app's `tags`, `weekendWords` on
the pilgrim page, and every fixture in the tests, the gate, the node
tests and the click-throughs.

**Where the new counts show.** `+planned` gains `mass_sat` and
`mass_sun` beside `mass`, and `trolley` beside `bus`; the reports table's
activity list and the counts screen gain rows for them, so the actual
head counts have somewhere to go. The check-in card's tags gain Mass and
the trolley on the days they apply.

## Proof

- Node: the settings round-trip from item 5, `weekendWords` with the new
  options, and the check-in `tags` for a Sunday Mass and a trolley.
- Unit: the shape lift from `%1` and from `%2`; `+planned` counting the
  three Masses and the trolley separately; `+csv-people`'s header and
  every row the same width.
- Gate: a submit carrying the new fields reads back with them; the
  roster row and the check-in roster carry them; an edit that adds a
  person to a full track is still a 409, and the page no longer offers
  the button.
- Click-throughs: the Saturday and Sunday groups appear and take ticks;
  the manage page shows the countdown line and hides Add a person when
  the track is full.
- The manual's screenshots are retaken for the registration form, the
  counts screen and the reports table, and its Settings chapter gains a
  line about the fee box.
- Version 14, `sw.js` bumped with it, the gate twice, page smoke, the
  weekend simulation, push, forge pull on the comet, version and bang
  read back there.

## Not in this change

Renaming `bus`. Asking the pilgrims who already signed up whether they
want the trolley: the three on the comet read as %3 with the new boxes
unticked, and an organizer can tick them on the registration's own page.
