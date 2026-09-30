# The organizers' manual

`register-manual.pdf` is the printed manual for the people who run the
event: Susan, Bob and Beth in the backoffice, Sarah and her volunteers on
the beach. It assumes no technical knowledge and no vocabulary from this
repository. 51 pages, letter paper, large type, one picture per screen,
in the event's own colours.

## Building it

```sh
cd docs/manual
xelatex manual.tex && xelatex manual.tex      # twice, for the contents page
cp manual.pdf register-manual.pdf
```

TeX Live or TinyTeX with `fontspec`, `geometry`, `xcolor`, `graphicx`,
`enumitem`, `array`, `tabularx`, `booktabs` and `hyperref`, and the DejaVu
Sans font. The second run fills in the table of contents.

## The pictures

Every screenshot is of the real program, with a few sample parties that
are created and then cancelled by the script.

```sh
REG_BASE=http://localhost:8080 REG_COOKIE=/path/to/cookie node shots.js
REG_BASE=http://localhost:8080 REG_COOKIE=/path/to/cookie node cards.js
```

`shots.js` takes the whole screens; `cards.js` takes every close-up.
Both need chromium and a cookie file holding one line,
`urbauth-~ship=0v...`. Without the two variables they fall back to
`http://localhost:8080` and `~/.config/lattice-fs/cookie`.

**The ship must be in stub mode, and must not be the one the organizers
are using.** The scripts sign and pay by posting to the pilgrim's own
routes, which in live mode would want a real card, and they create and
cancel half a dozen registrations. Installing register on a fake ship
for this takes about a minute: add the repo to forge, add a desk
following its `code` tree, approve the weir with the app's own
`weir.json` as the `granted` object, and reload.

`shots.js` writes the wide screens at a 1180 pixel window and the rest at
820, where the two-column layouts stack and the type is big enough to
read on paper.

Everything that is one control or one card is an **element** screenshot,
never a clip. `page.screenshot({clip})` measures from the top of the
document while `getBoundingClientRect` measures from the top of the
window, so a clip of anything below the fold comes out as whatever
happened to sit at those document coordinates, with the sticky navigation
bar painted through the middle of it. That bug ate the Providers card
once already.

The close-ups whose names begin `cu-` are cut out of `roster.png`,
`today.png` and `name-prompt.png` with ImageMagick, and the `ov-` ones are
the tall screens cropped to their useful top. Both sets of crops are in
the session notes rather than a script; if a screen's layout changes
enough to break a crop, take the shot again and cut it by eye.

## What to change when the event changes

- The addresses appear in `\siteroot` near the top of `manual.tex`, and
  written out in the two-address table, the login steps, the Edit text
  steps and the one-page reminder.
- The year and the dates are on the cover and in the check-in chapter.
- The logo on the cover is `img/logo.png`, copied from
  `code/nex/register/logo.png`.
- The version number is the last line of the file.
