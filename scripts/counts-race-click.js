// A headless click-through of the counts lost-update: an organizer has
// the backoffice Counts screen open, a volunteer's phone saves a figure
// meanwhile, then the organizer changes a different figure and saves.
// Both figures must be on the ship afterwards, and an emptied count must
// be no count rather than zero.
//
// Run: REG_BASE=http://localhost:8126 REG_COOKIE=<file> node scripts/counts-race-click.js
//
// It writes Friday's walk and Mass counts and clears them afterwards.
// Run it against a test ship only.
'use strict';
const { readFileSync } = require('fs');

const BASE = process.env.REG_BASE || 'http://localhost:8126';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';
const API = BASE + '/apps/register/api';

let fails = 0;
const check = (m, c, d) => {
  console.log((c ? '  ok   ' : '  FAIL ') + m + (c || !d ? '' : '   ' + String(d).slice(0, 300)));
  if (!c) fails++;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const puppeteer = (await import(PUPPETEER)).default;
  const cookie = readFileSync(process.env.REG_COOKIE, 'utf8').trim();
  const [cn, ...cr] = cookie.split('=');
  const hdr = { cookie, 'content-type': 'application/json', 'x-actor': 'counts-race' };
  const counts = async () => (await (await fetch(API + '/admin/counts', { headers: hdr })).json());
  const put = (doc) => fetch(API + '/admin/counts', { method: 'PUT', headers: hdr, body: JSON.stringify(doc) });
  await put({ fri: { walk: { count: null, note: null }, mass: { count: null } } });

  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const p = await browser.newPage();
  await p.setCookie({ name: cn, value: cr.join('='), domain: new URL(BASE).hostname, path: '/' });
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  p.on('dialog', (d) => d.accept('Organizer'));
  await p.goto(BASE + '/apps/register/admin#counts', { waitUntil: 'networkidle2' });
  await p.evaluate(() => { try { localStorage.setItem('register.admin.actor', 'Organizer'); } catch (e) { } });
  await p.waitForSelector('[data-k="fri.mass.count"]', { timeout: 30000 });

  // a volunteer's phone saves Friday's walk while the screen is open
  const r = await put({ fri: { walk: { count: 120, note: 'windy' } } });
  check('the phone saved its walk count', r.ok, r.status);

  // the organizer types Friday's Mass and saves
  await p.evaluate(() => { document.querySelector('[data-k="fri.mass.count"]').value = ''; });
  await p.type('[data-k="fri.mass.count"]', '80');
  await p.evaluate(() => document.querySelector('[data-k="fri.mass.count"]').dispatchEvent(new Event('change', { bubbles: true })));
  await p.click('[data-act="save-counts"]');
  const nameBox = await p.$('#actor-name');
  if (nameBox && await p.$eval('#actor-name', (e) => e.offsetParent !== null).catch(() => false)) {
    await p.type('#actor-name', 'Organizer');
    await p.click('#actor-save');
  }
  await sleep(3000);
  let c = await counts();
  check('the organizer\'s Mass count is saved', c.fri && c.fri.mass && Number(c.fri.mass.count) === 80, JSON.stringify(c.fri));
  check('the phone\'s walk count is still there', c.fri && c.fri.walk && Number(c.fri.walk.count) === 120, JSON.stringify(c.fri));
  check('and its note', c.fri && c.fri.walk && c.fri.walk.note === 'windy', JSON.stringify(c.fri));
  const shown = await p.$eval('[data-k="fri.walk.count"]', (e) => e.value);
  check('the screen shows the phone\'s figure after the save', shown === '120', shown);

  // the organizer empties the Mass count: no count, not zero
  // a triple click does not select a number box on every chromium
  // build, so the box is emptied the way a person's delete leaves it
  await p.evaluate(() => {
    const el = document.querySelector('[data-k="fri.mass.count"]');
    el.value = '';
    el.dispatchEvent(new Event('input', { bubbles: true }));
  });
  await p.click('[data-act="save-counts"]');
  await sleep(3000);
  c = await counts();
  check('an emptied count is no count', c.fri && c.fri.mass && (c.fri.mass.count === null || c.fri.mass.count === undefined),
    JSON.stringify(c.fri && c.fri.mass));
  check('the walk count survives that save too', c.fri && c.fri.walk && Number(c.fri.walk.count) === 120);

  await put({ fri: { walk: { count: null, note: null }, mass: { count: null } } });
  await browser.close();
  console.log(fails ? 'FAIL (' + fails + ')' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}
main().catch((e) => { console.log('  CRASH ' + e.stack); process.exit(1); });
