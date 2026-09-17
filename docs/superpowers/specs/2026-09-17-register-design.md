# Register: sign-up and event backoffice for the Baby Steps Camino, on a ship

Status: draft for review, 2026-09-17. Decisions taken in the brainstorm are in section 15.

## 1. What this is

Register takes sign-ups for the Baby Steps Camino, the three-day Advent beach pilgrimage from Jacksonville Beach to the Shrine of Our Lady of La Leche in St. Augustine, 2026-12-04 through 2026-12-06, and gives the organizers a backoffice to run it: caps and a wait list, payment, the waiver, changes and cancellations, reports, a daily check-in app that works on the beach without signal, and the actual counts per activity per day.

It is a grubbery desk app in the nisfeb family, laid out like orrery and installed the same way. One ship runs it for the event. Its public page is served at a subdomain of the event site (assumed `register.babystepscamino.com`, reverse-proxied to the ship), and the Squarespace site's Registration button links there. The page is styled after babystepscamino.com: white, dark grey text, a blue accent, Open Sans body and Poppins headings.

Every piece of text a pilgrim reads, every fee, every cap and every date is a setting an organizer edits in the backoffice. The code knows the shape of the event, not its words or its numbers.

## 2. The people involved

- A **pilgrim** registers a party of one or more people from the public page. They need no account. Their email gets a confirmation carrying a private link that lets them change or cancel their registration until the change cutoff.
- An **organizer** logs into the ship with its code and uses the backoffice at `/apps/register/admin`. Every organizer is the ship's owner as far as the ship knows, so the backoffice and the check-in app ask each person for their name once, keep it in the browser's local storage, and show "acting as Susan" in the header. Every change an organizer makes carries that name to the ship in an `X-Actor` header and lands in the registration's history and the audit ring as `admin:susan`. A browser with no name stored is prompted for one the first time it tries to change anything, and a change without a name is refused by the ship. Volunteers running check-in use the same login on their phones, with the same name prompt.
- **Stripe** takes the money. **DocuSign** takes the signature. **Resend** sends the mail. The ship talks to all three over HTTPS through iris, and trusts only what it reads back from them, never what they post to it.

## 3. The registration flow, as the pilgrim sees it

1. **Choose a track.** The landing page shows how full the event is (a meter whose default wording is a percentage, "65% full", since the organizers would rather not publish the exact count; the exact count is a placeholder the copy may use) and two doors: the full three-day Camino, or the Bambino Camino, the last 2.5 miles on Sunday. A track that has hit its cap says so and offers the wait list instead. A sold-out social shows as sold out inside the form.
2. **The form.** Contact details for the party (email, phone, address), then one card per person: name, child or adult, which days they walk, Sunday's distance (10 miles or 2.5) for the full track, the Friday and Saturday socials, Friday 8am Mass, the Holy Hour, transportation, first Camino, Knight or Dame, volunteer. A switch, "everyone in my party is doing the same things", copies the first person's choices to the rest and hides the repeats. Then organization, why you are walking, and the financial assistance request. The form saves itself as a draft the moment an email or a phone number is entered, so an abandoned sign-up is a row an organizer can follow up.
3. **Submit.** The ship validates, checks the caps, and either holds the party's spots and moves on, or, when the track is full, files the party on the wait list and sends the wait list email. Everything after this point is skipped for a wait-listed party until an organizer promotes it.
4. **Sign the waiver.** The pilgrim is sent into DocuSign embedded signing. One envelope per party. The registrant signs once, for themselves and on behalf of every other person in the party, whose names are printed into the document. On return the ship reads the envelope's status from DocuSign and refuses to move on unless it is completed.
5. **Pay.** Stripe Checkout, one line per fee and an optional extra gift. The registrant is sent to Stripe and back. A party that asked for financial assistance skips this step and waits for an organizer's decision instead.
6. **Done.** The confirmation email carries the manage link. Until the change cutoff the pilgrim can change anything on the form, add or remove people (paying the difference through Stripe when the fee rises, or leaving a refund to the organizers when it falls), or cancel.

A party's spots are held from submit. A hold that has not reached completion in 48 hours no longer counts against the cap, so an abandoned checkout does not keep a real pilgrim out. The party keeps its row and can still finish, and if the track filled in the meantime its next step tells it so and offers the wait list.

## 4. The rules

**Fees.** $75 per person on the full track, adults and children alike. $25 per person on the Bambino track. Every person in a party pays the track fee whether or not they walk: a non-walker who comes for the socials and the Shrine registers, pays, signs and attends like anyone else. Every fee is a setting. The fee is non-refundable and the form says so above the total; refunds are the organizers' discretion, done in Stripe. The pay step shows the minimum, invites the pilgrim to pay the full cost instead (a suggested amount per track in settings, default $150 per person on the full track, with copy the organizers write), and takes any custom amount at or above the minimum. Anything above the fee is a separate Stripe line so the organizers can tell registration income from donations. The registration page carries no donate button and no link to one: one call to action, so nobody pays a donation thinking it registered them.

**Caps.** Counted on read by folding every registration; nothing is stored. A person counts against the full-track cap when they are on a full-track party with at least one walking day checked, and against the Bambino cap when on a Bambino party with Sunday checked. Non-walkers count against nothing but the socials and the bus. An organizer can mark a registration exempt from the caps, for the northeast Florida Order of Malta members and volunteers who walk some days but are not pilgrims in the count; an exempt party still counts toward the socials and the bus. The Shrine can feed 350 on Sunday, so reports show the Sunday total across both tracks against that number, which is a setting; it is reported, not enforced, since the late-add pool is the organizers' call. A registration counts while it is complete, or pending and less than 48 hours old, or an organizer's manual add. Defaults: full track 325, Bambino 25, Friday social at Ajua 300, Saturday social at Pusser's 200. Organizers may add 50 more by hand over the cap (in advance or as walk-ins) and that pool is its own setting. The public page refuses a submit that would cross a cap and offers the wait list; a social at its cap is shown sold out and cannot be checked.

**Wait list.** A wait-listed party has a row, a position, and an email saying so. It has not signed and has not paid. An organizer promotes it from the backoffice, which holds its spots and emails a link to continue with the waiver and payment. Promotion ignores the cap, because the organizer has looked.

**Payment.** A registration is complete only when paid, or when financial assistance was approved, or when an organizer records a check, cash or other manual payment. Financial assistance is a request on the form; the pilgrim signs the waiver and then waits. An organizer approves it (complete) or declines it (an email with a link to pay). Refunds are done in the Stripe dashboard; the organizer then marks the registration refunded with a note.

**Waiver.** Signed at sign-up, before payment, one envelope per party, by the registrant for everyone in the party. An organizer can record a waiver signed on paper for a walk-in, and can ask the ship to re-read an envelope's status.

**Changes and cancellations.** Self-service through the manage link until the change cutoff (a setting, default midnight before day one, Eastern time). After that the page says to contact the organizers. An organizer may edit or cancel any registration at any time. A cancellation frees the spots at once. An organizer can reinstate a cancelled registration: it returns to the status it held before the cancel, its spots are held again whatever the cap, and the history says who did it.

**Duplicates.** A submit whose email matches an active registration is refused with a message that offers to resend the manage link. Organizers can merge by hand: cancel one.

**History.** Every registration carries its own history: who changed what and when, whether the pilgrim, an organizer, Stripe, DocuSign or the wait list promotion. The writer also keeps an audit ring of the last 2000 operations. The registration grubs are laid with retention on, so grubbery keeps every prior version as well.

**Registration window.** Opens and closes on dates in settings. Outside it the public page shows the closed message and takes nothing. Organizers can always add.

## 5. The check-in app, during the event

`/apps/register/checkin` is a PWA behind the owner login, meant for several volunteers at once on phones with poor signal. On open it caches its shell and pulls the roster: every person, their party, their status, what they registered for that day. It stores the roster locally and works from it. A day is chosen, a name is searched by last name, and one tap checks the person in. The tap goes into a local queue and posts to the ship whenever the phone has a connection; a check-in is a set, so two volunteers checking in the same person is harmless.

The tap answers the wristband question. Green with "wristband" when the party is complete (paid or assisted, waiver signed). Red with the reason when not: unpaid, unsigned, wait-listed, cancelled. The volunteer can still check them in and the reason stays on the record.

The same app has the day's counts screen: for each activity that day (Mass, Holy Hour or confession, the walk, the social, the bus), the organizers enter the actual count and time, beside the planned count from registrations. This is also reachable from the backoffice.

## 6. The backoffice

`/apps/register/admin`, owner only. Views:

- **Roster.** Every registration, one row per person, sortable by last name, state, status, track and date, with filters for the segments the organizers asked for: Bambino only, non-walkers, Order of Malta members and volunteers in northeast Florida (Knight or Dame or volunteer, with a Florida address), wait list, financial assistance pending, unpaid, unsigned, drafts (abandoned sign-ups), cancelled. Search by name, email, phone, organization.
- **A registration.** Every field editable, the party's people, the payment record, the waiver record, the history, and the actions: promote from the wait list, approve or decline assistance, record a manual payment, record a paper waiver, re-read the DocuSign envelope, resend the confirmation or manage link, send the finish-your-registration reminder, mark refunded, mark exempt from the caps, cancel, reinstate.
- **Add.** An organizer's manual registration, in advance or as a walk-in, over the cap, drawing from the late-add pool. It goes through the same waiver and payment steps by emailed link, or the organizer records both by hand on the spot.
- **Reports.** Totals by track, by day, by activity, by state and by organization. Paid, assisted, unpaid, unsigned, wait-listed, cancelled. Registrations per day since opening, as a trend. Planned versus actual per activity per day. Two CSV exports, one row per person and one row per registration, with every field, for Excel.
- **Backup.** Export the whole data set in three formats and import it back. The **jam** is the emergency copy: every registration, the settings, the copy, the counts and the DocuSign tokens as one noun, jammed, with a format version at its head, downloaded as `register-<date>.jam`. The **JSON bundle** is the same data as one readable document. The **CSV** exports above are for spreadsheets and carry no history or tokens, so they are export only. Import takes a jam or a JSON bundle, shows what it holds (how many registrations, their date range, the settings' event dates) and how many existing registrations it would overwrite, and applies only on a second confirming click. Import replaces registrations by id and leaves ones the file does not name alone; a checkbox wipes those too, for a true restore. Every import is one entry in the audit ring and one history line on every registration it touched.
- **Copy.** Every string the pilgrim reads, editable: page headings, field labels, help text, option labels, the sold-out and closed messages, the waiver instructions, the email templates with their placeholders.
- **Settings.** Event dates, the fee table and the suggested full-cost amounts, the caps, the late-add pool and the Sunday Shrine capacity, the registration window and change cutoff, the organizations list the form suggests from, the sender address, the provider credentials (Stripe secret key, Resend key, DocuSign integration key, secret, account id, base URI, template id) shown masked, a Connect DocuSign button, and the provider mode (live, or stub for rehearsals).

## 7. Shape of the desk

```
code/
  bill.json          {"register.register_app": "/register/app"}
  version.json       what replicates: a subscriber re-syncs only when it changes
  tile.json  icon.svg
  nex/register/app.hoon              the nexus: the writer, the web fiber, every route
  nex/register/public.html  public.js  public.css     the pilgrim's page
  nex/register/admin.html   admin.js   admin.css      the backoffice
  nex/register/checkin.html checkin.js checkin.css sw.js manifest.json   the PWA
  lib/register.hoon                  import-free: types, validation, fees, the cap fold, status transitions, csv, templates, codecs
  lib/register-stripe.hoon  register-docusign.hoon  register-mail.hoon   one core per provider: request builders and response readers, pure
  mar/register/reg.hoon              noun passthrough
  mar/json.hoon  sig.hoon  mime.hoon  timer-set.hoon  timer-rest.hoon  timer-wake.hoon   vendored kernel marcs
tests/lib/register.hoon              unit tests, run on ~wex with the revision pinned
scripts/api-matrix.py                the HTTP gate against ~wex in stub mode
scripts/live-matrix.py               the same flow against the Stripe test mode, the DocuSign developer sandbox and Resend
scripts/checkin-test.js              the PWA's queue and roster logic under node
scripts/code-closure.py              the desk is hermetic
docs/                                this spec, releasing.md from orrery, providers.md (how to set up the three accounts), deploy.md (the subdomain proxy)
```

Repo `nisfeb/register`, branch `main`.

## 8. The tree and the writer

```
/main.sig                     the writer: every mutation goes through it
/web.sig  /requests/<id>      binds /apps/register, one fiber per request
/regs/<rid>                   one grub per registration        [/register %reg]   retention on
/settings.json  /copy.json    seeded with defaults once, edits survive a reload
/counts.json                  actual counts per day per activity
/docusign-auth.json           the OAuth tokens, rotated on use
/beacon/rev                   the change beacon, nested so it streams
/tr/last  /tr/log             the last writer outcome and the ring of 2000
/tile.json /icon.svg /link.json /weir.json and the page files     replaced on every reload
```

A registration is one JSON grub: id, status, track, source (`web` or `admin`), created, updated, contact, organization, why, assistance requested, together flag, people, payment, waiver, manage token, wait list position, notes, history, check-ins. Its id is short and random, and the manage token is a second random secret never shown to organizers in listings.

Statuses: `draft`, `waitlist`, `waiver`, `payment`, `assistance`, `complete`, `cancelled`. The transitions and who may make them live in the lib and are unit tested. The writer takes `[/ %json]` pokes carrying one op: `save-draft`, `submit`, `set-waiver`, `set-payment`, `promote`, `assist`, `edit`, `cancel`, `check-in`, `set-counts`, `set-settings`, `set-copy`, `set-auth`, `add`, `restore`. It never crashes on input, writes `/tr/last` on every refusal, and bumps the beacon once per op that changed the tree.

Callers answer from their own computation, the orrery shape: a request fiber validates with the lib, computes the outcome, pokes the writer, and answers. The one race, two submits for the last spot at the same instant, is resolved by the writer re-checking the cap before it writes and recording the loser in `/tr/last`; the loser sees the wait list on its next step. There is no stored index and no stored count: four hundred grubs fold in a blink.

## 9. Surfaces

### Public, unauthenticated, under `/apps/register`

| method and path | does |
|---|---|
| `GET /` | the page |
| `GET /api/status` | the meter and the caps: spots taken and available per track and social, the registration window, and every string in `copy.json` |
| `POST /api/draft` | save or update a draft; answers the rid. Needs an email or a phone |
| `POST /api/submit` | validate, hold or wait-list; answers the next step |
| `GET /api/reg/<rid>?t=<token>` | the registration, for the manage page and the continue links |
| `POST /api/reg/<rid>/edit?t=` | a change from the pilgrim, before the cutoff |
| `POST /api/reg/<rid>/cancel?t=` | cancel |
| `POST /api/reg/<rid>/sign?t=` | make the DocuSign envelope and answer the signing URL |
| `GET /sign/return?rid=&t=` | back from DocuSign: read the envelope, advance, redirect to the next step |
| `POST /api/reg/<rid>/pay?t=` | make the Checkout session and answer its URL |
| `GET /pay/return?rid=&t=&sid=` | back from Stripe: read the session, advance, redirect to done |
| `POST /hooks/stripe` | Stripe's webhook. The body is a hint: the ship reads the session id out of it and asks Stripe. Answers 200 always |
| `POST /api/resend-link` | email the manage link to an address that has an active registration. Answers 200 whether or not one exists |

Every token check is constant on failure: a wrong token is a 404, the same as a missing registration.

### Owner only

| method and path | does |
|---|---|
| `GET /admin`, `GET /checkin` and their assets | the two apps |
| `GET /api/admin/regs?…` | the roster with filters and sort |
| `GET /api/admin/reg/<rid>` | one registration whole |
| `POST /api/admin/reg/<rid>` | an edit, or one of the actions, named by `op` |
| `POST /api/admin/add` | a manual registration |
| `GET /api/admin/reports` | the counts |
| `GET /api/admin/export/people.csv` and `regs.csv` | the spreadsheet exports |
| `GET /api/admin/export/bundle.json` and `bundle.jam` | the whole data set, readable or as a jammed noun |
| `POST /api/admin/import?dry=1` | inspect a jam or JSON bundle: what it holds and what it would overwrite |
| `POST /api/admin/import?wipe=0|1` | apply it. Owner only, refused without the confirming flag the dry run answered |
| `GET` and `PUT /api/admin/settings`, `/api/admin/copy`, `/api/admin/counts` | the documents. Secrets come back masked and a masked value on PUT keeps the stored one |
| `GET /api/admin/docusign/connect` and `GET /admin/docusign/return` | the one-time OAuth consent |
| `GET /api/checkin/roster?day=` | the roster the PWA caches |
| `POST /api/checkin` | a batch of check-ins from the queue |

Live updates: `/beacon/rev` streams through grubbery's keep-SSE like orrery's. The backoffice refetches what it shows when it moves. The public page reads the meter once per load.

### The providers

**Stripe.** `POST /v1/checkout/sessions`, form-encoded, Bearer secret key: one line per fee with quantity, one line for the gift when given, `metadata[rid]`, `success_url` with `{CHECKOUT_SESSION_ID}`, `cancel_url`, `expires_at` 24 hours. On return and on webhook the ship does `GET /v1/checkout/sessions/<id>` and applies the payment only when `payment_status` is `paid` and the metadata names the registration. The webhook's signature is not verified, because nothing in its body is trusted; only the GET is. A fee increase after an edit makes a new session for the difference.

**DocuSign.** OAuth authorization code grant, the shape calendar uses for Google: the organizer clicks Connect once, the ship exchanges the code for tokens and stores them, and refreshes on use. Then `POST /v2.1/accounts/<id>/envelopes` from the template with one embedded signer (the registrant, `clientUserId` the rid) and the party's names and the guardian statement prefilled into text tabs, `POST …/envelopes/<id>/views/recipient` for the signing URL, and `GET …/envelopes/<id>` on return. Statuses: `sent`, `completed`, `declined`, `voided`. A `declined` sends the pilgrim back to the sign step with the message from copy.

**Resend.** `POST /emails` with the key, from the sender in settings, subject and body from the template in copy with the placeholders filled. Seven templates: confirmation, wait list, promoted, assistance approved, assistance declined, finish your registration, cancelled. Mail is sent from the request fiber after the write, outcome in `/tr/log`, and every template has a resend button in the backoffice. A retrying outbox is the upgrade if Resend ever fails for more than a moment.

Every outbound request runs against a deadline, calendar's two minutes, so a response iris forgets across a reload cannot wedge a fiber.

**Stub mode.** With `providers.mode` set to `stub`, the sign step and the pay step complete themselves and mail is written to `/tr/log` instead of sent. The page shows a banner saying so. This is how the HTTP gate runs and how an organizer rehearses on a test ship.

## 10. The ask

`weir.json`, in words for the person granting it:

- poke `/sys/bowl.sig`: read the clock and this ship's name
- poke `/sys/eyre/`: serve the sign-up page, the backoffice and the check-in app at `/apps/register`
- poke `/sys/iris/`: talk to Stripe to take payments, to DocuSign to take signatures, and to Resend to send the pilgrims their emails. Refuse this and nothing can be paid, signed or sent
- poke `/sys/behn/`: give up on a provider that does not answer within two minutes
- peek `/sys/link/`: find where this app is installed, so the page can address its own writer

No ames roads. One ship runs the event.

## 11. The page

The public page is one document, its style inlined, one script, no build step, served no-cache. It reads the site's look: white background, `#272727` text, a blue accent, Open Sans for body text and Poppins for headings from Google Fonts, generous whitespace, a single column at phone width with a 16px gutter. Native inputs, styled. The meter is the first thing on the landing. Every string comes from `copy.json` through `/api/status`, so the page renders nothing it did not fetch.

The backoffice is plain and dense: tables, filters, a detail panel. The check-in app is large-tap, one search box, one list, one big green or red answer.

## 12. Constraints this build honors

From the lattice, auspex, calendar and orrery releases:

1. Every blot the tree lays has a marc inside the desk, or the poke parks silently.
2. Every marc is a noun passthrough; the shape ladder lives in the reader.
3. Every persistent path has a covering row in `on-load`.
4. Long-lived fibers use absolute roads.
5. No `$` with arguments inside a `;<` continuation.
6. The writer never crashes on input.
7. Every outbound request has a deadline.
8. A release is a `code/version.json` bump, and the instance's `bang` is the proof it landed.
9. Nothing touches `~ricsul-bilwyt` until it has passed on `~wex`, and nothing touches the event ship until sneagan says so.
10. Secrets never leave the ship unmasked and never appear in `/tr/log`.
11. An import never crashes the writer or the request fiber: cue under `mole`, the shape checked under `mule`, and a refusal names what was wrong.
12. Public input is untrusted: length caps on every string, a cap on people per party (default 12), and no HTML rendered from anything a pilgrim typed.

## 13. Testing

- **Unit**, `tests/lib/register.hoon`: fee computation for both tracks, children, non-walkers and the gift; the cap fold with pending holds aging out; every status transition and its actor; validation of every field with the failing field named; the together flag expansion; CSV escaping; template placeholder filling; the JSON round trip of a registration; masking of secrets; the bundle's jam and cue round trip, and a cue of a truncated or foreign noun refused without a crash.
- **HTTP gate**, `scripts/api-matrix.py` against `~wex` in stub mode: the whole pilgrim flow for both tracks; a draft with only a phone; the cap reached and the wait list taken; promotion; financial assistance approved and declined; an edit that raises the fee; a cancel that frees a spot; the duplicate refused; a wrong token a 404; every owner route a 403 without the cookie; the exports parse and carry every field; the check-in batch idempotent; a jam export imported onto a wiped tree restores every registration byte for byte, and a JSON bundle does the same.
- **Live gate**, `scripts/live-matrix.py`: the same flow once against Stripe test mode (the Stripe CLI forwards the webhook to the ship), the DocuSign developer sandbox and Resend's test address. Run by hand before the event ship is set up.
- **PWA**, `scripts/checkin-test.js`: the roster cache, the queue, the replay, and the wristband answer under node against fixtures. Offline behavior is checked by hand in a browser with the network off.
- **Page**, a smoke script like orrery's: the three pages and their assets answer with the right types, the public page without a cookie and the other two only with it.

## 14. Phases

Each is installable and useful on its own. Estimates are for the implementer with the ship at hand.

1. **Desk, model, the pilgrim's page, caps and wait list.** The repo as section 7, the lib with its tests, the writer, the public routes without the providers, drafts, the meter, the wait list email as a stub, the page styled after the site. Gate: the unit tests and the matrix green through submit and wait list. About three days.
2. **Stripe, DocuSign, Resend.** The three provider cores, the connect flow, the sign and pay steps, the webhook, the seven emails, stub mode, the live matrix. Gate: the matrix in stub mode green end to end, the live matrix green once. About three days.
3. **The backoffice.** The roster, the detail panel and every action, manual adds, reports, exports, copy and settings editors. Gate: the admin routes in the matrix, the exports checked in a spreadsheet. About three days.
4. **Check-in and counts.** The PWA, the roster cache, the queue, the wristband answer, the counts screen, planned versus actual in reports. Gate: the node test and the offline check by hand. About two days.
5. **Release.** `docs/releasing.md`, `docs/providers.md` with the three account setups and the DocuSign template, `docs/deploy.md` with the subdomain proxy, the version bump, install on the event ship, the organizers' walkthrough. Sneagan runs the ship steps.

## 15. Decisions recorded

- A linked subdomain over an iframe in Squarespace, sneagan's choice on 2026-09-17. The Stripe and DocuSign redirects would break out of a frame anyway.
- DocuSign over an in-app signature, sneagan's choice on 2026-09-17. Embedded signing so the pilgrim never leaves the flow, one envelope per party signed by the registrant for everyone, OAuth authorization code grant so no RSA signing is needed in Hoon. The JWT grant is the upgrade if the refresh token ever lapses from disuse.
- Resend for mail, sneagan's choice on 2026-09-17.
- Waiver before payment, so an abandoned flow never needs a refund.
- Stripe Checkout over Elements: no card data touches the ship, and the webhook is verified by asking Stripe rather than by checking a signature.
- Caps computed on read, holds aging out at 48 hours, no stored counters: the tree is the index.
- Non-walkers are not counted against any cap, as asked, and pay the track fee like everyone else (sneagan, 2026-09-17: they still register, pay, sign and attend the socials).
- The Bambino fee is $25 per person, since the Bambino walk is Sunday only.
- Organizers and check-in volunteers share the ship's login, as asked. A name typed once into each browser, kept in local storage and sent as `X-Actor`, is stamped on every change so the record still says who. Added 2026-09-17 at sneagan's request.
- History inside each registration grub plus the audit ring and grubbery's retention, over a separate audit table: one read shows a registration's whole story.
- Sorting by state is in; distance from St. Augustine is not, since it needs geocoding.
- Abandoned sign-ups are followed up by an organizer's click, not by a timer.
- CSV for the spreadsheet exports; Excel opens it.
- From the organizers' meeting (transcript read 2026-09-17): the fee is stated non-refundable; the pay step suggests the full cost ($150 default, a setting) and takes more; no donate button on the registration page; an organizer-set exempt flag for in-town Order of Malta members and volunteers rather than a self-declared one, which anyone could tick; the Sunday Shrine capacity of 350 reported, not enforced; reinstating a cancelled registration, since the organizers asked for undo; the meter wording defaults to a percentage.
- Three backup formats, added 2026-09-17 at sneagan's request: a jammed noun for emergency recovery (exact, small, and cue is the only parser), a JSON bundle for reading and for recovery by hand, and CSV for spreadsheets only. Import is dry-run first, then confirmed, because it overwrites.

## 16. Not in v1

DocuSign Connect webhooks (the return read and the recheck button cover it). Separate waivers for each adult in a party. Stripe signature verification. A retrying mail outbox. Timed reminder emails. Distance from St. Augustine. Multiple events on one ship. Accounts for pilgrims. Per-organizer logins. A public schedule page (the site has one).
