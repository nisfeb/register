# register

Sign-up and event backoffice for the Baby Steps Camino, on an Urbit ship running grubbery. Pilgrims register a party, sign the waiver, pay, and manage their registration from a link. Organizers run caps, the wait list, financial assistance, reports, exports and the daily check-in from `/apps/register/admin`.

The design is in `docs/superpowers/specs/2026-09-17-register-design.md`. The release mechanics are in `docs/releasing.md`. Phase 1 (this release) covers the pilgrim's flow with the providers stubbed; phase 2 adds Stripe, DocuSign and Resend.

## Try it on a ship

```bash
W=http://localhost:8080
curl -s $W/apps/register/api/status | python3 -m json.tool | head -30     # the meter, the caps, the copy
```

Open `$W/apps/register/` in a browser. Nothing on the public page needs a login. The owner's routes under `/apps/register/api/admin` need the ship's cookie and an `X-Actor` header naming the organizer.
