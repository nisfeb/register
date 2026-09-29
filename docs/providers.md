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

## Where to look when a send or a charge does not happen

The audit ring, at the bottom of the backoffice. Every attempt writes a
line:

- `by: stub` — the app was in stub mode, or no key was set. Nothing was
  sent, by design.
- `by: mail`, `ok: true` — Resend accepted the message.
- `by: mail`, `ok: false` — Resend refused it, and the line carries the
  status and Resend's own words, e.g.
  `not sent (403: The babystepscamino.com domain is not verified...)`.

A card that fails never reaches the ship at all: the pilgrim stays on
the payment step and Stripe tells them why.

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

Take a backup before any upgrade anyway — *Backup → JSON bundle* in the
backoffice, and the jam beside it.
