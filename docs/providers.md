# Stripe and Resend: turning the money and the mail on

Register runs in one of two modes, set on the backoffice's **Settings**
page under *Providers*:

- **stub** — the ship takes registrations, signs the waiver and marks
  payments itself. No card is charged and no email leaves the ship; each
  send is written to the audit ring instead. This is the mode to
  rehearse in.
- **live** — the waiver is adopted by the pilgrim, the payment goes
  through Stripe Checkout, and the mail goes through Resend.

Nothing else changes between them. The same routes, the same records.

## What has to be in place before live

1. **A Stripe secret key** in *Settings → Providers → Stripe secret key*.
   Test keys start `sk_test_`, live keys `sk_live_`. The ship masks the
   key the moment it is stored, so press **Check the Stripe key** beside
   it to find out which one is in there: it asks Stripe and answers
   either *This is a test key* or *This is a LIVE key*. A live key plus a
   real card is real money.
2. **A Resend API key** in *Mail → Resend key*.
3. **A verified sending domain at Resend.** This is the one that bites.
   Resend will not send from `register@babystepscamino.com` until that
   domain is added and its DNS records are verified at
   <https://resend.com/domains>. Until it is, every send comes back
   `403 The babystepscamino.com domain is not verified` and the ring
   note says so. Resend's own `onboarding@resend.dev` works from any
   account and is what the test ship uses.
4. **The public url**, in *Settings → Public URL*. Every emailed link and
   every Stripe return address is built from it. Point it at whatever
   domain actually serves the app; a wrong one sends pilgrims nowhere.
5. **The weir.** Live mode needs `/sys/iris/` (the outbound call) and
   `/sys/behn/` (its two-minute deadline). Both are new as of version 15,
   so the app must be re-approved on the permissions page after the
   upgrade. Without them nothing spins — the calls simply fail and the
   ring says the provider could not be reached.

## The webhook

Stripe does not need one for the app to work: the pilgrim's return trip
settles the payment, and it settles it by asking Stripe rather than by
believing the browser. The webhook is the safety net for a pilgrim who
pays and then closes the tab.

Point it at `https://<your domain>/apps/register/hooks/stripe` and send
it `checkout.session.completed`. There is no signing secret to paste,
and there is nothing useful an attacker can post: the route reads one
thing out of the body, the session id, and then asks Stripe itself what
that session did. Everything else in the body is ignored. It answers 200
to everything so Stripe stops retrying.

The route is public, and asking Stripe costs an outbound call, so the id
has to look like one first: `+webhook-sid` refuses anything that is not
a `checkout.session.*` event carrying an id that begins `cs_`. That is a
filter against rubbish, not a signature check, and it is not one.

## Where to look when a send or a charge does not happen

**Backup → Recent activity**, which shows the last of the 2,000 lines
the writer keeps. Every attempt writes one:

- `by: stub` — the app was in stub mode, or no key was set. Nothing was
  sent, by design.
- `by: mail`, `ok: true` — Resend accepted the message.
- `by: mail`, `ok: false` — Resend refused it, and the line carries the
  status and Resend's own words, e.g.
  `not sent (403: The babystepscamino.com domain is not verified...)`.

A card that fails never reaches the ship at all: the pilgrim stays on
the payment step and Stripe tells them why.

The line that matters most is `stripe.unsettled`. It means Stripe took
the money and the ship could not write it down — the only case where
money has moved and nothing else records it. It carries the session id,
which is what to quote to Stripe. Everything else on that path is either
ordinary (a session that was never paid, a registration the other of the
two return paths already completed) or is visible as the pilgrim's own
error on screen.

## What is deliberately not here

No retrying outbox: a failed send is a line in the ring and a button in
the backoffice, not a queue. No Stripe signature check, for the reason
above. No separate waiver per adult — the registrant adopts for the
whole party, as the organizers decided.

## Upgrading a ship the organizers have been editing

Every string a pilgrim reads lives in `copy.json`, and organizers edit
them in place on the page. **A release never overwrites them.** The
nexus lays `copy.json` with `%fall`, which writes only when the document
is absent, and `+with-starter` unions the library's defaults *under*
what is stored: a stored string always wins, and a string a release adds
appears with its default. The same holds for `settings.json`, the
registrations and the counts.

Two consequences worth knowing:

- A ship that has been running keeps its edits across the upgrade. On
  the comet at version 15 those were six: the trademark symbols in
  `landing.title`, `landing.full.title` and `landing.bambino.title`, the
  reworded `landing.full.blurb` and `landing.full.who`, and the
  non-refundable note on `manage.cancel`.
- **Changing a default in `+starter-copy` does not reach a ship that
  already stores that key.** If the wording of an existing string has to
  change everywhere, an organizer edits it on the page, or it goes out
  by `POST /api/admin/copy/set` with the key and the new value. Only
  genuinely new keys arrive from a release.
- **A key the code retires is dropped**, not carried for ever. Nothing
  renders a retired string, so nobody could reach it to correct it, and
  it would sit in the document looking like one that matters.
  `+with-starter` answers the code's key list with the stored values
  laid over it, so `next.waiver.button` went away when the waiver step
  stopped using it. This only ever removes keys the code no longer knows;
  an edit to a string still in use is never touched.

Take a backup before any upgrade anyway — *Backup → JSON bundle* in the
backoffice, and the jam beside it.

### The copy document cannot be damaged

Three rules, and between them nothing a caller does can take an
organizer's words away:

1. **The pages write one key at a time.** Both the public page's inline
   editing and the backoffice's Emails page use
   `POST /api/admin/copy/set`, one key per call, and that route refuses
   a key the library does not have.
2. **The whole-document write merges.** `PUT /api/admin/copy` unions what
   it is given over what is stored: a key it leaves out is kept, and a
   key the library does not have is dropped. Nothing in the app uses this
   route, which is exactly why it had to be made safe — it was the one
   way left to replace the document, and a caller who sent the wrong
   shape would have replaced every string with one key. That is not a
   hypothetical; it happened once on the test ship while this was being
   written, and the merge is what made it harmless.
3. **Backups read the document raw.** `+read-bundle` reads `copy.json`
   itself, not the `+with-starter` view, so a key the library has retired
   still round-trips through a backup and a restore.

The gate pins all three.

### Pushing a changed default to a ship

`scripts/set-copy.py` is the tool for the second case. With no key names
it lists every string whose stored value differs from the library's and
changes nothing:

```sh
scripts/set-copy.py https://<host> <cookie-jar>
```

Name the keys to push, and it pushes those and only those, so an
organizer's own wording is never touched unless it is asked for by name:

```sh
scripts/set-copy.py https://<host> <cookie-jar> form.weekend form.same_weekend
```

On the comet at version 16 the organizers had already rewritten ten
strings of their own — the trademark marks, the button labels, and
`form.mass_sat`, which reads "1:00 pm Mass at St. John Paul II, Nocatee"
and not what the library says. Always run it with no arguments first and
read the list.

## The emails themselves

Nine templates, edited in the backoffice under **Emails**: confirmation,
manage, wait list, promoted, assistance approved, assistance declined,
reminder, cancelled and check-in. Each has a subject and a body, and the
body may hold any of ten words in double curly brackets, which the card
at the top of that page lists in full:

`{{first}}` `{{link}}` `{{total}}` `{{track}}` `{{people}}`
`{{position}}` `{{day}}` `{{email}}` `{{site}}` `{{event}}`

They are filled by `+send-mail`, and the legend in `admin.js` and
`+test-email-vars` in the suite are the same list written twice more.
Adding one means touching all three; the test is what catches forgetting.

An organizer may add a variable to a template but may not lose one that
is already there — the save is refused and names it.

## The address suggestions, and why they are gone

For a few hours the street box asked the ship, and the ship asked
[Photon](https://photon.komoot.io), the OpenStreetMap geocoder. It was
removed on 2026-09-30, the day it shipped: the suggestions were wrong
often enough to confuse the people filling the form, which is worse than
no suggestions at all.

Kept from that work, because it stands on its own: the **state is a
dropdown**, storing the two-letter code.

If it is ever tried again, the two things that made it hard are worth
knowing before starting. **Photon invents house numbers** — asked for
"1220 Penman Rd" it answers "1220 East 3rd Avenue, Mount Dora", matching
the number against a different street and offering it with every
appearance of confidence. Suggesting street names only was the way round
that, and it still was not good enough. And **iris will not carry a
space in a url**, which is documented in `docs/hoon-testing.md` and cost
an hour on its own.

A paid provider with an address-completion product would not have either
problem. That is a question of a billing account, not of code.

## Upgrading a ship the organizers have been editing

Every string a pilgrim reads lives in `copy.json`, and organizers edit
them in place on the page. **A release never overwrites them.** The
nexus lays `copy.json` with `%fall`, which writes only when the document
is absent, and `+with-starter` unions the library's defaults *under*
what is stored: a stored string always wins, and a string a release adds
appears with its default. The same holds for `settings.json`, the
registrations and the counts.

Two consequences worth knowing:

- A ship that has been running keeps its edits across the upgrade. On
  the comet at version 15 those were six: the trademark symbols in
  `landing.title`, `landing.full.title` and `landing.bambino.title`, the
  reworded `landing.full.blurb` and `landing.full.who`, and the
  non-refundable note on `manage.cancel`.
- **Changing a default in `+starter-copy` does not reach a ship that
  already stores that key.** If the wording of an existing string has to
  change everywhere, an organizer edits it on the page, or it goes out
  by `POST /api/admin/copy/set` with the key and the new value. Only
  genuinely new keys arrive from a release.
- **A key the code retires is dropped**, not carried for ever. Nothing
  renders a retired string, so nobody could reach it to correct it, and
  it would sit in the document looking like one that matters.
  `+with-starter` answers the code's key list with the stored values
  laid over it, so `next.waiver.button` went away when the waiver step
  stopped using it. This only ever removes keys the code no longer knows;
  an edit to a string still in use is never touched.

Take a backup before any upgrade anyway — *Backup → JSON bundle* in the
backoffice, and the jam beside it.

### The copy document cannot be damaged

Three rules, and between them nothing a caller does can take an
organizer's words away:

1. **The pages write one key at a time.** Both the public page's inline
   editing and the backoffice's Emails page use
   `POST /api/admin/copy/set`, one key per call, and that route refuses
   a key the library does not have.
2. **The whole-document write merges.** `PUT /api/admin/copy` unions what
   it is given over what is stored: a key it leaves out is kept, and a
   key the library does not have is dropped. Nothing in the app uses this
   route, which is exactly why it had to be made safe — it was the one
   way left to replace the document, and a caller who sent the wrong
   shape would have replaced every string with one key. That is not a
   hypothetical; it happened once on the test ship while this was being
   written, and the merge is what made it harmless.
3. **Backups read the document raw.** `+read-bundle` reads `copy.json`
   itself, not the `+with-starter` view, so a key the library has retired
   still round-trips through a backup and a restore.

The gate pins all three.

### Pushing a changed default to a ship

`scripts/set-copy.py` is the tool for the second case. With no key names
it lists every string whose stored value differs from the library's and
changes nothing:

```sh
scripts/set-copy.py https://<host> <cookie-jar>
```

Name the keys to push, and it pushes those and only those, so an
organizer's own wording is never touched unless it is asked for by name:

```sh
scripts/set-copy.py https://<host> <cookie-jar> form.weekend form.same_weekend
```

On the comet at version 16 the organizers had already rewritten ten
strings of their own — the trademark marks, the button labels, and
`form.mass_sat`, which reads "1:00 pm Mass at St. John Paul II, Nocatee"
and not what the library says. Always run it with no arguments first and
read the list.

## The emails themselves

Nine templates, edited in the backoffice under **Emails**: confirmation,
manage, wait list, promoted, assistance approved, assistance declined,
reminder, cancelled and check-in. Each has a subject and a body, and the
body may hold any of ten words in double curly brackets, which the card
at the top of that page lists in full:

`{{first}}` `{{link}}` `{{total}}` `{{track}}` `{{people}}`
`{{position}}` `{{day}}` `{{email}}` `{{site}}` `{{event}}`

They are filled by `+send-mail`, and the legend in `admin.js` and
`+test-email-vars` in the suite are the same list written twice more.
Adding one means touching all three; the test is what catches forgetting.

An organizer may add a variable to a template but may not lose one that
is already there — the save is refused and names it.

