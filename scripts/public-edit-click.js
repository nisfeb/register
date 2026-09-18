// A headless click-through of edit mode on the pilgrim's page: the
// toggle only the owner sees, a string typed over where it stands, the
// tick, the new string still there after a reload, every step of the
// flow rendered from a fixture, and an edit that drops a placeholder
// refused before it leaves the browser.
//
// Run: node scripts/public-edit-click.js
//
// It drives a real ship and writes to copy.json, so run it against a
// test ship. It puts every string it changed back before it ends. It
// needs the owner cookie at ~/.config/lattice-fs/cookie and chromium
// with puppeteer-core. The gate does not call it: it is run by hand.
'use strict';
const { readFileSync } = require('fs');
const { homedir } = require('os');

const BASE = 'http://localhost:8080';
const PAGE = BASE + '/apps/register/';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';
const TITLE = 'landing.full.title';
const METER = 'landing.meter';

let fails = 0;
const check = (m, c, d) => {
  console.log((c ? '  ok   ' : '  FAIL ') + m + (c || !d ? '' : '   ' + String(d).slice(0, 200)));
  if (!c) fails++;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// the tick lives three tenths of a second, which is shorter than a
// round trip to the browser, so it is watched for rather than polled
const watchTicks = (page) => page.evaluate(() => {
  window.__ticks = 0;
  new MutationObserver(function (recs) {
    recs.forEach(function (r) {
      Array.prototype.forEach.call(r.addedNodes, function (n) {
        if (n.nodeType === 1 && n.className === 'tick') window.__ticks += 1;
      });
    });
  }).observe(document.body, { childList: true, subtree: true });
});
const ticked = async (page, ms) => {
  const end = Date.now() + ms;
  for (;;) {
    if (await page.evaluate(() => window.__ticks > 0)) return true;
    if (Date.now() > end) return false;
    await sleep(100);
  }
};
// /api/status reads every registration, so a route that waits on it
// can take a moment: poll rather than guess at a delay
const gone = async (page, sel, ms) => {
  const end = Date.now() + ms;
  for (;;) {
    if (!(await page.$(sel))) return true;
    if (Date.now() > end) return false;
    await sleep(100);
  }
};
const spanOf = (key) => '.copy[data-copy="' + key + '"]';
// type over a string where it stands, then leave it
const retype = async (page, key, text) => {
  await page.evaluate((sel, t) => {
    const el = document.querySelector(sel);
    el.focus();
    el.textContent = t;
  }, spanOf(key), text);
  await page.evaluate((sel) => document.querySelector(sel).blur(), spanOf(key));
};

async function main() {
  const puppeteer = (await import(PUPPETEER)).default;
  const cookie = readFileSync(homedir() + '/.config/lattice-fs/cookie', 'utf8').trim();
  const [cn, ...cr] = cookie.split('=');
  const api = BASE + '/apps/register/api';
  const before = await (await fetch(api + '/status')).json();
  const wasTitle = before.copy[TITLE];
  const wasMeter = before.copy[METER];
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });

  // ---- a stranger sees no trace of any of this ----
  const s = await browser.newPage();
  s.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  await s.goto(PAGE, { waitUntil: 'networkidle2' });
  await s.waitForSelector('.doors', { timeout: 20000 });
  check('the status tells a stranger the page is not theirs', before.owner === false, before.owner);
  check('a stranger sees no Edit text button', (await s.$eval('#edit-copy', (n) => n.hidden)) === true);
  check('a stranger sees no step row and no editable span',
    (await s.$eval('#steps', (n) => n.hidden)) === true && (await s.$$('.copy')).length === 0);
  check('the stranger body carries no editing class', (await s.evaluate(() => document.body.className)) === '');

  // ---- the party form calls people by the name typed for them ----
  const head = (n) => s.evaluate((i) => document.querySelectorAll('.card.person h2')[i].textContent, n);
  const labelOf = (sel) => s.evaluate((q) => {
    const el = document.querySelector(q);
    return el ? (el.closest('label') || el.parentNode).textContent.trim() : null;
  }, sel);
  await s.goto(PAGE + '#form/full', { waitUntil: 'networkidle2' });
  await s.waitForSelector('.card.person', { timeout: 20000 });
  check('a card with no name yet is headed by the copy', (await head(0)) === 'Person 1', await head(0));
  await s.click('[data-k="people.0.first"]');
  await s.type('[data-k="people.0.first"]', 'Ana');
  await sleep(300);
  check('a first name alone heads the card', (await head(0)) === 'Ana', await head(0));
  check('and the caret never left the field being typed into',
    (await s.evaluate(() => (document.activeElement || {}).getAttribute
      ? document.activeElement.getAttribute('data-k') : null)) === 'people.0.first');
  await s.click('[data-k="people.0.last"]');
  await s.type('[data-k="people.0.last"]', 'Silva');
  await sleep(300);
  check('both halves make the heading', (await head(0)) === 'Ana Silva', await head(0));

  await s.click('[data-act="add"]');
  await s.waitForSelector('[data-k="same.1"]', { timeout: 10000 });
  check('a second person joins the party', (await s.$$('.card.person')).length === 2);
  check('and is headed by the copy until they are named', (await head(1)) === 'Person 2', await head(1));
  // the page fills {{name}} from the ship's own string, so the check is
  // against that string, and against the ship holding one to fill
  check('the ship\'s party switch string carries the name placeholder',
    String(before.copy['form.together']).includes('{{name}}'), before.copy['form.together']);
  check('the party switch names the first person by name',
    (await labelOf('[data-k="together"]')) ===
      String(before.copy['form.together']).split('{{name}}').join('Ana Silva'),
    await labelOf('[data-k="together"]'));
  check('the new person starts out copying the first',
    (await s.$eval('[data-k="same.1"]', (n) => n.checked)) === true);
  check('and the box names who they are copying',
    (await labelOf('[data-k="same.1"]')) ===
      String(before.copy['form.same_as']).split('{{name}}').join('Ana Silva'),
    await labelOf('[data-k="same.1"]'));
  const own = await s.evaluate(() =>
    document.querySelectorAll('.card.person')[1].querySelectorAll('[data-k^="people.1.days"]').length);
  check('while they copy, they show no choices of their own', own === 0, own);
  check('the remove button is labelled with the person it removes',
    (await s.$eval('[data-act="remove"][data-i="0"]', (n) => n.getAttribute('aria-label')))
      .includes('Ana Silva'),
    await s.$eval('[data-act="remove"][data-i="0"]', (n) => n.getAttribute('aria-label')));

  // person one changes their Friday; person two is copying, so it follows
  await s.click('[data-k="people.0.days.fri"]');
  await sleep(300);
  await s.click('[data-k="same.1"]');
  await s.waitForSelector('[data-k="people.1.days.fri"]', { timeout: 10000 });
  check('unticked, the second person shows their choices again',
    (await s.$$('[data-k^="people.1.days"]')).length > 0);
  check('and they hold what was copied while the box was ticked',
    (await s.$eval('[data-k="people.1.days.fri"]', (n) => n.checked)) === true);
  await s.click('[data-k="people.0.days.sat"]');
  await sleep(300);
  check('a person no longer copying does not follow the first any more',
    (await s.$eval('[data-k="people.1.days.sat"]', (n) => n.checked)) === false);
  check('a party with no contact yet was never sent to the ship',
    (await s.evaluate(() => sessionStorage.getItem('bsc.draft'))) === null);
  await s.close();

  const p = await browser.newPage();
  await p.setCookie({ name: cn, value: cr.join('='), domain: 'localhost', path: '/' });
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  await p.goto(PAGE, { waitUntil: 'networkidle2' });
  await p.waitForSelector('.doors', { timeout: 20000 });
  check('the owner sees the Edit text button', (await p.$eval('#edit-copy', (n) => n.hidden)) === false);
  check('and the page is not in edit mode until it is asked',
    (await p.evaluate(() => document.body.className)) === '' && (await p.$$('.copy')).length === 0);

  // ---- edit mode ----
  await p.click('#edit-copy');
  await sleep(1200);
  check('the toggle turns edit mode on', (await p.evaluate(() => document.body.className)) === 'editing');
  check('every string on the landing is editable', (await p.$$('.copy')).length > 6, (await p.$$('.copy')).length);
  check('the raw template is on screen, placeholders and all',
    (await p.$eval(spanOf(METER), (n) => n.textContent)).includes('{{percent}}'),
    await p.$eval(spanOf(METER), (n) => n.textContent));
  check('the step row is open', (await p.$eval('#steps', (n) => n.hidden)) === false);

  // ---- the flow is frozen ----
  const hash = await p.evaluate(() => {
    document.querySelector('a.btn').click();
    return location.hash;
  });
  check('a door does not open the form in edit mode', hash === '', hash);

  // ---- a string typed over where it stands ----
  await watchTicks(p);
  await retype(p, TITLE, 'The full Camino, edited');
  await p.waitForSelector('#actor-name', { visible: true, timeout: 8000 });
  check('a first change with no name asks for one', (await p.$eval('#prompt', (n) => n.hidden)) === false);
  await p.evaluate(() => { document.getElementById('actor-name').value = ''; });
  await p.type('#actor-name', 'Clicker');
  await p.click('#actor-save');
  check('the prompt closes once it has a name', (await p.$eval('#prompt', (n) => n.hidden)) === true);
  check('the tick says the ship took it', await ticked(p, 10000));
  await sleep(1500);
  const live = await (await fetch(api + '/status')).json();
  check('the ship holds the new string', live.copy[TITLE] === 'The full Camino, edited', live.copy[TITLE]);
  check('nothing else in the document moved', live.copy[METER] === wasMeter, live.copy[METER]);

  // ---- and it is still there after a reload ----
  await p.reload({ waitUntil: 'networkidle2' });
  await p.waitForSelector('.copy', { timeout: 20000 });
  check('edit mode is remembered', (await p.evaluate(() => document.body.className)) === 'editing');
  check('the new string is on the page after a reload',
    (await p.$eval(spanOf(TITLE), (n) => n.textContent)) === 'The full Camino, edited');

  // ---- an edit that drops a placeholder never leaves the browser ----
  await retype(p, METER, 'nearly full');
  await sleep(400);
  const bad = await p.$eval('.copy-bad', (n) => n.textContent).catch(() => '');
  check('a dropped placeholder is refused in the page', bad === 'keep {{percent}}', bad);
  check('and the string it was typed over comes straight back',
    (await p.$eval(spanOf(METER), (n) => n.textContent)) === wasMeter);
  const after = await (await fetch(api + '/status')).json();
  check('the ship was never asked', after.copy[METER] === wasMeter, after.copy[METER]);

  // ---- every step, from a fixture ----
  const steps = await p.$$eval('#steps button[data-step]', (ns) => ns.map((n) => n.getAttribute('data-step')).filter(Boolean));
  check('the step row offers the twelve views and the leftover strings', steps.length === 13, steps.join(','));
  for (const name of steps) {
    await p.click('#steps button[data-step="' + name + '"]');
    await sleep(250);
    const shape = await p.evaluate(() => ({
      ribbon: !!document.querySelector('#view .ribbon'),
      spans: document.querySelectorAll('#view .copy').length,
      len: document.getElementById('view').textContent.length,
    }));
    check('the ' + name + ' preview renders with its strings editable',
      shape.ribbon && shape.spans > 0 && shape.len > 40, JSON.stringify(shape));
  }
  // ---- the Form fixture is a party of two, so both party strings show ----
  await p.click('#steps button[data-step="form"]');
  await sleep(400);
  check('the Form fixture shows a party of two',
    (await p.$$('#view .card.person')).length === 2, (await p.$$('#view .card.person')).length);
  const partyKeys = await p.$$eval('#view .copy', (ns) => ns.map((n) => n.getAttribute('data-copy')));
  check('the party switch and the "Same as" box are both editable there',
    partyKeys.includes('form.together') && partyKeys.includes('form.same_as'),
    partyKeys.filter((k) => /together|same_as|person/.test(k)).join(','));

  // ---- the pilgrim flow is frozen: nothing moves and nothing is sent ----
  await p.evaluate(() => {
    window.__fetches = 0;
    const real = window.fetch;
    window.fetch = function () { window.__fetches += 1; return real.apply(this, arguments); };
  });
  const was = await p.evaluate(() => ({
    checked: document.querySelector('#view .card.person input[type=checkbox]').checked,
    value: document.querySelector('#view input[data-k="contact.email"]').value,
    hash: location.hash,
  }));
  await p.click('#view .card.person input[type=checkbox]');
  await p.click('#view input[data-k="contact.email"]');
  await p.type('#view input[data-k="contact.email"]', 'nobody@example.com');
  await p.click('#view [data-act="submit"]');
  // past the draft timer, which is what would send anything at all
  await sleep(1800);
  const still = await p.evaluate(() => ({
    checked: document.querySelector('#view .card.person input[type=checkbox]').checked,
    value: document.querySelector('#view input[data-k="contact.email"]').value,
    hash: location.hash,
    ribbon: !!document.querySelector('#view .ribbon'),
    fetches: window.__fetches,
  }));
  check('a check box in edit mode does not move', still.checked === was.checked, JSON.stringify(still));
  check('a text field in edit mode takes no typing', still.value === was.value, still.value);
  check('Submit in edit mode goes nowhere',
    still.hash === was.hash && still.ribbon, JSON.stringify(still));
  check('and not one request left the browser', still.fetches === 0, still.fetches);

  await p.click('#steps button[data-step=""]');
  check('back to the page leaves the preview', await gone(p, '#view .ribbon', 15000));
  await p.waitForSelector(spanOf(TITLE), { timeout: 15000 });

  // ---- put the string back ----
  await watchTicks(p);
  await retype(p, TITLE, wasTitle);
  check('the tick says the string went back', await ticked(p, 10000));
  await sleep(1500);
  const end = await (await fetch(api + '/status')).json();
  check('the copy document is as it was found', end.copy[TITLE] === wasTitle && end.copy[METER] === wasMeter,
    end.copy[TITLE]);

  // ---- and edit mode turns off ----
  await p.click('#edit-copy');
  check('the toggle turns edit mode off again', await gone(p, '.copy', 15000));
  check('and the body no longer says it is editing',
    (await p.evaluate(() => document.body.className)) === '' &&
    (await p.$eval('#steps', (n) => n.hidden)) === true);

  await browser.close();
  console.log(fails ? fails + ' FAILED' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}

main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
