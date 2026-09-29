# Register Phase 2: the waiver in the app, Stripe, and Resend

> **Built and proved on the comet, 2026-09-29, as version 15.** A
> registration was carried end to end in live mode: submitted, the
> waiver adopted with its text hash, paid with 4242 4242 4242 4242
> through Stripe Checkout, and the confirmation sent by Resend. A second
> run paid $150 against a $75 fee and the ship recorded
> `amount 7500, gift 7500`. The webhook is idempotent and answers 200 to
> a duplicate, to an event it does not care about and to junk. Two
> things are the organizers' to finish, not the code's: the Resend
> sending domain is unverified (see `docs/providers.md`), and the Stripe
> key on the comet is a test key, which the new key check confirms.

sneagan, 2026-09-29: "begin phase 2, except that instead of docusign we
will have a scrollable modal with a checkbox saying I have read and
agree.... and a button saying 'adopt and sign' which records their
acceptance of the terms. set up resend and stripe with the secrets in
forgave-infect."

This replaces `2026-09-17-register-phase-2-providers.md`, whose DocuSign
half is now dropped. Stripe and Resend follow that plan closely; the
waiver becomes something the app does itself, with no third party, no
OAuth and no outbound call.

One implementer, one review, one fix pass. The only ship running register
is the comet `~hadmyn` (forgave-infect.nisfeb.com); `~wex` is down and
`~feb` runs the Hoon test kit but not the app.

## Before any of it: three things about the comet

1. **`public_url` is wrong for that ship.** It reads
   `https://register.babystepscamino.com`, which nothing serves yet. Every
   Stripe return and every emailed link is built from it, so a pilgrim
   would be sent to a dead domain. Set it to
   `https://forgave-infect.nisfeb.com` while the comet is the ship under
   test, and to the real domain when there is one.
2. **The weir must grow.** Outbound HTTP is `poke /sys/iris/`, and a
   deadline on it is `poke /sys/behn/`. Both are new, so the app must be
   re-approved on every ship that runs it. The comet's approval is one
   call to `/apps/grubbery/permits` with the enlarged grant, then a
   reload.
3. **Nobody has checked whether the stored keys are test or live.** The
   ship masks them on read, and it must: so the build adds an admin route
   that asks Stripe `GET /v1/balance` and answers only `livemode` and the
   account id. **Do not move `providers.mode` to `live` until that answers
   `livemode: false`, or until sneagan says the live key is intended.**
   A live key plus a real card is real money.

## 1. The waiver, in the app

No envelope, no redirect. The pilgrim reads the terms on the page and
adopts them.

**The text** is a copy key, `waiver.text`, so the organizers own it and
edit it in place like everything else. It is long, so the copy route's
4,000-byte cap on one key is raised to 20,000 for this key alone
(`+max-copy-value`, which takes the key and answers the cap). The starter
value is a short placeholder that says in terms what the real waiver must
say, and a line telling the organizers to paste their own text in. It
renders with the same `[text](url)` markup the rest of the copy allows,
and paragraphs split on a blank line.

**The step.** `#next/<rid>/<token>` at status `%waiver` today shows a
"Sign the waiver" button. It now opens a modal:

- A dialog, `role="dialog"` and `aria-modal`, its body scrollable, with
  the waiver text and the party's names printed into it (the registrant
  signs for everyone, children named).
- Under the text, a checkbox: copy key `waiver.agree`, default
  "I have read and agree to the terms above, for myself and for everyone
  in my party."
- A button, copy key `waiver.adopt`, default "Adopt and sign". It is
  disabled until the box is ticked **and** the body has been scrolled to
  its end, so nobody adopts terms the page never showed them. A line says
  so while it is disabled: `waiver.scroll`, "Read to the end to continue."
- Escape and a Close button leave it unsigned.

**What the ship records.** `POST /api/reg/<rid>/sign?t=` keeps its name
and its place in the flow. In `%live` mode it now takes
`{"agreed": true, "text_hash": "<hex>"}`: the page sends the hash of the
exact text it displayed. The route recomputes the hash from `copy.json`
itself and refuses a mismatch with 409 `waiver: the terms changed while
you were reading; reload and read them again`. Then it writes
`waiver [%adopt <hash> %completed now]` and advances by `+after-waiver`,
with the history line `adopted the waiver`.

`+de-waiver`'s method list gains `adopt`. The record's shape does not
change: `envelope` carries the hash, which is what proves *which* text
was adopted. `+en-waiver` already emits all four fields, so the
backoffice shows the method as `adopt` and the hash beside it.

**The hash** is `+hash-text |=(t=@t @t)`: `(scot %ux (shax t))`, the
library's only new pure arm for this, unit-tested for stability and for
differing on a one-character change.

Stub mode keeps completing the step by itself, so the gate is unchanged.

## 2. The plumbing: one outbound request, with a deadline

`code/lib/register-http.hoon`, pure, import-free like the rest:

- `+url-encode |=(t=@t @t)`: percent-encode all but the unreserved set,
  uppercase hex.
- `+form-body |=(kvs=(list [@t @t]) @t)`: `k=v` joined by `&`, values
  encoded.
- `+bearer |=(t=@t @t)`: `Bearer <t>`.
- `+basic |=([user=@t pass=@t] @t)`: `Basic <base64 of user:pass>`.

Tests: a space, an ampersand and a UTF-8 byte; a two-key body; `a:b` is
`Basic YTpi`.

In the nexus, `+fetch |=(request:http (fiber ,[status=@ud body=@t]))`:
sends through `send-request:io`, sets a behn timer at two minutes on a
fixed wire, and answers `[0 '']` when the timer wins. **Both the request
and the timer are soft**: a weir that refuses either must park the fiber,
never spin it, which is the crash rule register already keeps everywhere
else. The three marcs the timer lays (`timer-set`, `timer-rest`,
`timer-wake`) are vendored from orrery's `code/mar/`.

## 3. Stripe

`code/lib/register-stripe.hoon`, pure:

- `+checkout-request |=([key rid email lines success cancel expires] request:http)`:
  POST `https://api.stripe.com/v1/checkout/sessions`, form-encoded,
  `mode=payment`, `customer_email`, `metadata[rid]`, one
  `line_items[i][price_data]` group per line, `success_url` with
  `&sid={CHECKOUT_SESSION_ID}` appended **after** encoding so the braces
  survive, `cancel_url`, `expires_at`.
- `+session-request |=([key sid] request:http)`: GET the session.
- `+read-session |=(body=@t (unit [id paid=? total=@ud rid=@t url=@t]))`.
- `+webhook-sid |=(body=@t (unit @t))`: the `data.object.id` of a
  `checkout.session.*` event, `~` for anything else.
- `+balance-request |=(key=@t request:http)` and
  `+read-livemode |=(body=@t (unit ?))`, for the key check above.

Tests: every key present in the built body; a paid and an unpaid fixture;
a `payment_intent.succeeded` event answering `~`.

**The routes.** `POST /api/reg/<rid>/pay?t=` in `%live` mode builds the
session and answers `{"url"}`; the page navigates. The body may carry
`amount` in cents, refused under the fee; anything above it is a second
line, "Gift to the Baby Steps Camino", so registration income and gifts
stay apart in Stripe. `GET /pay/return?rid&t&sid` reads the session from
Stripe, and **only** what Stripe says: paid, the total, and a matching
`metadata.rid`. It advances to `%complete` with
`payment [%stripe fees gift now sid | '']` and sends the confirmation.
`POST /hooks/stripe` takes the session id out of the body and asks Stripe
the same way; the body is never trusted for anything else, which is why
no signature is checked. It answers 200 always, so Stripe stops retrying.

## 4. Resend

`code/lib/register-mail.hoon`, pure: `+send-request |=([key from to subject text] request:http)`
POST `https://api.resend.com/emails`, JSON, Bearer; `+read-send |=([status body] (unit @t))`
answering the id on 200 or 201.

`+send-mail` in the nexus fills a template from `copy.json` with the
registration's own values (`first`, `email`, `event`, `link`, `site`,
`position`, `total`, `day`) and sends it. In stub mode, or with an empty
key, it writes the ring note it writes today and sends nothing. **The ring
never holds the body or the link**, only the template, the recipient and
the subject: a manage link is a password.

Send points, all of which already have their stub: confirmation on every
path to `%complete`, wait list on a wait-listed submit, promoted on
promote, assistance approved and declined, cancelled on a cancel, the
reminder and the manage link from the backoffice's resend, and the
morning check-in links, which already batch a hundred at a time.

## 5. The pay step's chooser

The page's payment step becomes three radios: the registration fee, the
full cost (`fees.suggested_full`, default $150 a person, a new setting),
and another amount with a dollars box whose minimum is the fee. Copy keys
`next.payment.minimum`, `.suggested`, `.custom`, `.custom_help`. The
button posts `{amount}`.

## Proof

- Unit, on the kit against `~feb`: the four new libraries' arms, the hash,
  and the waiver method. `hoon-test.sh` stays under ten seconds.
- Gate, in stub mode, unchanged except: `sign` with `agreed` false is 400;
  with a stale hash 409; the waiver record reads `adopt` with the hash;
  `pay` under the fee is 400; over it records the gift.
- A live matrix, run by hand once against Stripe test mode and Resend:
  submit, adopt the waiver, pay with 4242 4242 4242 4242, and read back
  the payment record and the confirmation's id.
- The comet: the weir re-approved, `public_url` corrected, the key check
  answering `livemode`, and **`providers.mode` left at `stub` until that
  answer is read**.

## Not in this change

A retrying outbox. Timed reminders. Stripe signature verification, which
the GET makes unnecessary. Separate waivers per adult: the registrant
adopts for the party, as the organizers decided.
