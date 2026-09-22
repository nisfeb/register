# The organizers' manual

`register-manual.pdf` is the printed manual for the people who run the
event: Susan, Bob and Beth in the backoffice, Sarah and her volunteers on
the beach. It assumes no technical knowledge and no vocabulary from this
repository. 36 pages, letter paper, large type, one picture per screen.

## Building it

```sh
cd docs/manual
xelatex manual.tex && xelatex manual.tex      # twice, for the contents page
```

TeX Live or TinyTeX with `fontspec`, `geometry`, `xcolor`, `graphicx`,
`enumitem`, `array`, `tabularx`, `booktabs` and `hyperref`, and the DejaVu
Sans font. The second run fills in the table of contents.

## The pictures

Every screenshot is of the real program, taken against `~wex` with a few
sample parties that are created and then cancelled by the script. To take
them again after a change to the app:

```sh
node shots.js      # the whole screens, desktop and phone
node cards.js      # one card at a time, close up
```

Both need `~wex` running with register installed, an owner cookie at
`~/.config/lattice-fs/cookie`, and chromium. `shots.js` writes the wide
screens at a 1180 pixel window and the rest at 820, where the two-column
layouts stack and the type is big enough to read on paper. `cards.js`
shoots single cards as elements, which is the only reliable way to get
their coordinates.

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
- The version number is the last line of the file.
