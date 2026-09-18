# Register: a design and language pass on the pilgrim's page

sneagan, 2026-09-18, after using the form: "the UI says 'same as chuck clerk' but has no context to indicate what is the same. there are other UI elements with what appear to be literal representations of what I asked for without considering the user ... the list of names for the checkboxes. the social locations aren't even clickable links even though I gave you the urls." This pass restructures the form around how a pilgrim thinks about the weekend, and rewrites every string a pilgrim reads. One implementer, one review, one fix pass.

## Principles

- A section answers one question the pilgrim has: who is coming, what will each of them do each day, how do we reach you, what does it cost.
- Group by day, because the event is three days. Never a flat list of eleven checkboxes.
- Every choice carries the fact a pilgrim needs to make it: the time, the place, the distance, a link to the venue.
- Speak to the registrant about themselves in the second person and about the others by name. Never "Person 2" once a name exists.
- Show, do not reference: "Same schedule as Ana" is meaningless unless Ana's schedule is right there.
- Links in copy: an organizer must be able to put a venue link into any string. Copy supports one markup: `[text](https://…)` renders as a link that opens in a new tab. Nothing else. `tx()` escapes first, then turns that pattern into an anchor, only for `http://` and `https://` targets. In edit mode the raw brackets are edited.

## The landing

- Title and intro stay editable; the default intro adds one line: "The full schedule, parking and what to bring are on [babystepscamino.com](https://babystepscamino.com/schedule-1)."
- Two doors, each a card with a title, one line saying what it is, one line saying who it is for, the fee, and the button:
  - **The full Camino.** "Friday, Saturday and Sunday, December 4 to 6. About 10 miles a day along the beach, with Mass, a Holy Hour, and a social each afternoon. Walk all three days or any of them." "$75 per person, adults and children alike." Button: "Register for the full Camino".
  - **The Bambino Camino.** "Sunday only: the last 2.5 miles from Vilano Beach to the Shrine of Our Lady of La Leche, walking from 11am after prayer." "$25 per person." "Made for young children, grandparents and anyone who wants to finish the walk with us." Button: "Register for the Bambino Camino".
- Under the doors: "Not sure? If you will walk on Friday or Saturday at all, choose the full Camino. On Sunday every full-Camino pilgrim may choose the 10 miles or the last 2.5."
- The meter keeps "{{percent}}% full" and adds a second line when over 80 percent: "Spots are going fast."

## The form, in order

**1. Who is coming.** Heading "Who is coming?" with the help "Add everyone you are registering, children included. You will sign the waiver and pay for the whole party." A card per person. The first card's heading is "You" until a name is typed, then the name; later cards "Person 2" until a name, then the name. Fields: First name, Last name, and a checkbox "Under 18" (replaces "This is a child"). Remove is a quiet text button "Remove {{name}}" at the card's corner.

**2. Each person's weekend**, inside their card, under the names. Heading "{{name}}'s weekend" ("Your weekend" for the first person before a name; "Ana's weekend" after). For every person after the first, the section opens with a two-option radio, not a checkbox:
- ( ) "Same weekend as {{first}}" with, directly under it, a read-only summary of the first person's choices in words: "Walking Friday, Saturday and Sunday (10 miles). Friday Mass and Holy Hour. Socials at Ajua and Pusser's. Needs the bus." The summary updates live as the first person's choices change. While selected, the person's own choice groups are hidden and their values follow the first person.
- ( ) "A different weekend" which shows the groups below with the copied values as a start.
Default for a newly added person: same. The party-wide switch is gone from the page (the model's `together` stays false; the copied values are what the ship receives).

The groups, for the full track:
- **Walking** with one row per day, each a checkbox whose label carries the fact: "Friday, December 4: 10 miles, Jacksonville Beach to Mickler's Landing" · "Saturday, December 5: 10 miles, Mickler's Landing to GTM Reserve" · "Sunday, December 6: to the Shrine in St. Augustine". When Sunday is checked, an indented radio: "10 miles from GTM Reserve" / "The last 2.5 miles from Vilano Beach (the Bambino route)". This replaces `form.sun_ten`.
- **Friday** (shown when Friday is checked, else collapsed with a note "Check Friday to see Friday's events"): "8:00am Mass at St. Paul's, Jacksonville Beach" · "Holy Hour: Adoration and Benediction, 1:50pm" · "Pilgrim social at [Ajua Mexican Kitchen](https://ajuajax.com/), 3pm" with "(sold out)" appended when the cap is reached and the box disabled.
- **Saturday** (when Saturday is checked): "Pilgrim social at [Pusser's](https://pusserspvb.com/), 3pm" with the sold-out rule.
- **Getting around**: "Needs a seat on the motorcoach (back to the start each day; to the start on Sunday)".
For the Bambino track: the Walking group is one checked-by-default row "Sunday, December 6: the last 2.5 miles from Vilano Beach to the Shrine, 11am"; the Friday and Saturday socials still offer (they are open to everyone) under a heading "Also this weekend"; Getting around the same.

**3. About {{name}}** (still inside the card): "This is {{name}}'s first Baby Steps Camino" (second person for the first card: "This is my first Baby Steps Camino") · "Knight or Dame of the Order of Malta" · "Volunteering at the event".

**4. How we reach you.** Heading "How do we reach you?" with help "Your confirmation, your link to make changes, and any news about the weekend go here." Email, mobile phone, then the address with the help "Street, city, state and ZIP. We like to know how far our pilgrims travel." Then "Parish, school or group (optional)" with the help "If you are coming with others, name the group so we can keep you together in the counts."

**5. Why are you walking?** Heading as the question, help "A sentence or two is plenty. The organizers read every answer." Then the assistance checkbox reworded: "I would like to be considered for financial assistance" with the existing help text.

**6. What it costs.** One line per person: "Ana Silva · full Camino · $75", "Bo Silva · under 18 · $75", then "Total · $225", then "The registration fee is non-refundable. The full cost of a pilgrim's weekend is about $150; at payment you can choose to cover it." (the suggested amount comes from settings when present, else the literal). The Bambino line reads "Bambino Camino · $25".

**7. The button.** "Continue to the waiver" when there is room, "Join the wait list" when the track is full at that moment (status counts), with a line under it saying which.

## The next steps

- Waiver: title "Sign the waiver", body "Every pilgrim signs a liability waiver before walking. You sign once, for yourself and for everyone in your party: {{names}}." Button "Sign the waiver".
- Payment: title "Pay the registration fee", body "Your {{spots}} are held. Registration fee for {{names}}: {{total}}." Button "Pay {{total}}" (the amount chooser arrives with phase 2).
- Complete: title "You are registered", body "See you on the beach, {{first}}. A confirmation is on its way to {{email}} with your link to change or cancel. Your weekend: {{summary}}." where summary is the same words as the Same-weekend summary, for the whole party.
- Wait list: "You are number {{position}} on the wait list for the {{track}}. We email as soon as a spot opens; in past years many have." Cancelled, assistance, lapsed, pending: reread and tighten in the same voice.

## The manage page

Title "Your registration" with a line "Registered {{created}}. Change anything below until {{cutoff}}, or cancel for the whole party." The same form. Save says "Save changes"; Cancel says "Cancel the whole registration".

## Mechanics

- New copy keys for every new string; old keys that no longer render are removed from `+starter-copy` (the ship's copy.json keeps them harmlessly; `+with-starter` adds the new ones on the next load; on wex, after the release, PUT the starter copy through `PUT /api/admin/copy` once so the new defaults show, and say so in the report). Placeholders used: `{{name}}`, `{{first}}`, `{{names}}`, `{{spots}}`, `{{total}}`, `{{summary}}`, `{{track}}`, `{{created}}`, `{{cutoff}}`, `{{position}}`, `{{email}}`, `{{percent}}`.
- The summary in words is one function `weekendWords(p, track)` in public.js, exported and node-tested; the complete page and the Same-weekend radio both use it.
- The Sunday distance radio maps onto the existing `sun_ten` boolean; the per-person radio replaces the `sameAs` checkbox; nothing changes on the ship except copy.
- Links: `tx()` gains the `[text](url)` rule after escaping; `esc(t(...))` sites that should render links use `tx` too. Edit mode edits raw brackets; the placeholder rule extends to keep the link text and url intact only if the organizer keeps the brackets (no enforcement beyond the existing placeholder check).
- Focus: heading and summary re-renders are targeted (the existing `data-who` mechanism), never the whole form on a keystroke.
- Phone width: the day rows wrap; the radio and its summary stack; nothing scrolls horizontally.

## A language pass on the other two pages

Read every string in admin.js and checkin.js as an organizer or a volunteer would. Fix: button labels that name the mechanism instead of the outcome ("PUT", "op", "apply" become "Save", "Restore"), empty states that say "No rows" instead of "No registrations yet", confirms that do not say what will happen, the actor prompt ("Who is making changes? Your name goes in the history." with a Save button), the check-in wristband texts ("Wristband: give one" / "No wristband: unpaid", said as a volunteer would say it), and the sync badge words. Keep it a pass, not a rewrite: list what you changed.

## Proof

- Node: `weekendWords` cases (all days, one day, Sunday 2.5, no socials, bus; Bambino), the link rule (a link renders, a javascript: url does not, brackets without a url stay text), the fee lines per person.
- `scripts/public-edit-click.js` and a new `scripts/public-form-click.js`: add a second person, see "Same weekend as Ana" selected with Ana's summary; change Ana's Friday, the summary updates; choose "A different weekend", the groups appear with Ana's values; uncheck Friday on person 2, the Friday group collapses; the Ajua link is an anchor with the right href and `target=_blank`; the fee box names both people; submit lands on the waiver page naming both.
- The gate unchanged except copy keys it reads (update the labels it checks).
- Version 10 (bump sw.js V too), gate twice, smoke, node, click-throughs, push, forge pull, version and bang, gate once more; PUT the starter copy on wex afterwards as above.

Commit in units (lib copy; pilgrim page; backoffice and check-in language; tests and click-throughs; version 10), plain sentences, no attribution.
