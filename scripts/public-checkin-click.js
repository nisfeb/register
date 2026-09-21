// A headless click-through of the pilgrim's check-in link: a party of
// two made through the API and completed in stub mode, the event's
// dates moved so that today is Friday, the link showing a box per
// person, one ticked and sent, the tick locked with the time, the
// second arriving later on the same link; then a solo party and its
// one button. Before the day the link names the date.
//
// Run: node scripts/public-checkin-click.js
//
// It drives a real ship, moves event.days in its settings for the run
// and puts them back, and cancels the registrations it made. Owner
// cookie from ~/.config/lattice-fs/cookie. Run it against a test ship.
'use strict';

const { readFileSync } = require('fs');
const { homedir } = require('os');
const BASE = 'http://localhost:8080';
const PAGE = BASE + '/apps/register/';
const API = BASE + '/apps/register/api';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';

let fails = 0;
const check = (m, c, d) => {
  console.log((c ? '  ok   ' : '  FAIL ') + m + (c || !d ? '' : '   ' + String(d).slice(0, 220)));
  if (!c) fails++;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const cookie = readFileSync(homedir() + '/.config/lattice-fs/cookie', 'utf8').trim();
const hdr = { 'content-type': 'application/json', cookie: cookie, 'x-actor': 'click' };
const j = async (res) => { try { return await res.json(); } catch (e) { return {}; } };
const post = (path, body, own) => fetch(API + path, { method: 'POST', headers: own ? hdr : { 'content-type': 'application/json' }, body: JSON.stringify(body || {}) });
const put = (path, body) => fetch(API + path, { method: 'PUT', headers: hdr, body: JSON.stringify(body) });
const person = (first, last) => ({ first, last, child: false, days: { fri: true, sat: true, sun: true }, sun_ten: true,
  social_fri: false, social_sat: false, mass_fri: false, holy_hour: false, bus: false, first_bsc: true, knight_dame: false, volunteer: false });
const party = (mail, people) => ({ track: 'full', contact: { email: mail, phone: '904 555 0100', street: '1 Beach Rd', city: 'Jacksonville Beach', state: 'FL', zip: '32250' },
  org: '', why: 'click', assistance: false, together: false, people });

async function complete(mail, people) {
  const d = await j(await post('/submit', party(mail, people)));
  if (!d.rid) throw new Error('submit failed: ' + JSON.stringify(d));
  await j(await post('/reg/' + d.rid + '/sign?t=' + d.token, {}));
  await sleep(1500);
  await j(await post('/reg/' + d.rid + '/pay?t=' + d.token, {}));
  await sleep(1500);
  return d;
}

async function main() {
  const puppeteer = (await import(PUPPETEER)).default;
  const settings = await j(await fetch(API + '/admin/settings', { headers: hdr }));
  if (!settings.event) throw new Error('no settings: is the cookie good?');
  const wasEvent = JSON.parse(JSON.stringify(settings.event));
  const st = await j(await fetch(API + '/status'));
  const offset = Number(settings.event.utc_offset_hours === undefined ? -5 : settings.event.utc_offset_hours) || 0;
  const local = new Date(Date.parse(st.now) + offset * 3600000);
  const day = (n) => new Date(local.getTime() + n * 86400000).toISOString().slice(0, 10);
  const stamp = Date.now();
  let two = null, one = null;
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  try {
    two = await complete('checkin-click+two' + stamp + '@example.com', [person('Ana', 'Silva'), person('Bo', 'Silva')]);
    one = await complete('checkin-click+one' + stamp + '@example.com', [person('Cy', 'Solo')]);

    // ---- before the day ----
    settings.event.days = [day(7), day(8), day(9)];
    await put('/admin/settings', settings); await sleep(1500);
    const p = await browser.newPage();
    p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
    await p.goto(PAGE + '#checkin/' + two.rid + '/' + two.token, { waitUntil: 'networkidle2' });
    await p.waitForSelector('#view .card', { timeout: 60000 });
    const early = await p.$eval('#view .card', (n) => n.textContent);
    check('a week early the link names the day it opens', /opens on/.test(early) && !/Check us in/.test(early), early);

    // ---- on the day ----
    settings.event.days = [day(0), day(1), day(2)];
    await put('/admin/settings', settings); await sleep(1500);
    await p.goto(PAGE + '#checkin/' + two.rid + '/' + two.token, { waitUntil: 'networkidle2' });
    await p.reload({ waitUntil: 'networkidle2' });
    await p.waitForSelector('input[data-here]', { timeout: 60000 });
    const boxes = await p.$$eval('input[data-here]', (ns) => ns.map((n) => [n.getAttribute('data-here'), n.checked, n.disabled]));
    check('a party of two sees a box per person, none ticked', boxes.length === 2 && boxes.every((b) => !b[1] && !b[2]), JSON.stringify(boxes));
    check('and one button', (await p.$$('[data-act="checkin"]')).length === 1);
    await p.click('[data-act="checkin"]');
    await sleep(800);
    check('pressing with nobody ticked is refused on the page', /at least one/.test(await p.$eval('#error', (n) => n.textContent)));
    await p.click('input[data-here="0"]');
    await p.click('[data-act="checkin"]');
    await p.waitForSelector('input[data-here="0"][disabled]', { timeout: 60000 });
    const after = await p.$$eval('input[data-here]', (ns) => ns.map((n) => [n.checked, n.disabled]));
    check('the ticked person is locked as checked in, the other is still open',
      after[0][0] && after[0][1] && !after[1][0] && !after[1][1], JSON.stringify(after));
    const said = await p.$eval('#view .card', (n) => n.textContent);
    check('the page names who is in and says the link still works', /Ana Silva checked in/.test(said) && /arrive/.test(said), said);
    check('and shows the time beside the name', /\d{1,2}:\d\d(am|pm)/.test(said), said);
    const roster = await j(await fetch(API + '/checkin/roster?day=fri', { headers: hdr }));
    const row = (roster.rows || []).find((r) => r.rid === two.rid);
    check('the volunteers\' roster shows the check-in by pilgrim',
      row && row.people[0].checked && row.people[0].by === 'pilgrim' && !row.people[1].checked, JSON.stringify(row && row.people));
    await p.click('input[data-here="1"]');
    await p.click('[data-act="checkin"]');
    await p.waitForFunction(() => /checked in\. A volunteer/.test(document.querySelector('#view .card').textContent), { timeout: 60000 });
    check('the second arrives later and the page says everyone is in', true);

    // ---- solo ----
    await p.goto(PAGE + '#checkin/' + one.rid + '/' + one.token, { waitUntil: 'networkidle2' });
    await p.reload({ waitUntil: 'networkidle2' });
    await p.waitForSelector('[data-act="checkin"]', { timeout: 60000 });
    check('a solo party sees no boxes', (await p.$$('input[data-here]')).length === 0);
    const solo = await p.$eval('#view .card', (n) => n.textContent);
    check('and is greeted by name', /Welcome, Cy/.test(solo), solo);
    await p.click('[data-act="checkin"]');
    await p.waitForFunction(() => /checked in\. A volunteer/.test(document.querySelector('#view .card').textContent), { timeout: 60000 });
    check('one press checks them in', true);
    await p.reload({ waitUntil: 'networkidle2' });
    await p.waitForSelector('#view .card', { timeout: 60000 });
    check('and reloading the link keeps saying so', /checked in\. A volunteer/.test(await p.$eval('#view .card', (n) => n.textContent)));
  } finally {
    await browser.close();
    settings.event = wasEvent;
    await put('/admin/settings', settings);
    for (const r of [two, one]) {
      if (r) await post('/reg/' + r.rid + '/cancel?t=' + r.token, {});
    }
    await sleep(1500);
  }
  console.log(fails ? fails + ' FAILED' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}

main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
