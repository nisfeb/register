// A headless click-through of R1 in the check-in test plan: taps made
// offline on one day must reach the ship as that day's, even when the
// volunteer has moved the app to another day before the signal comes
// back. The same drain runs when a phone offline on Friday evening
// opens on Saturday morning.
//
// Run: REG_BASE=http://localhost:8126 REG_COOKIE=<file> node scripts/checkin-day-click.js
//
// REG_COOKIE is a file holding one line, urbauth-~ship=0v... It picks
// three complete parties with nobody checked in on Friday or Saturday,
// taps each one's first person offline on Friday, switches to Saturday,
// goes back online, and reads both days' rosters from the ship. It takes
// the check-ins back afterwards. Run it against a test ship only.
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
  const hdr = { cookie, 'content-type': 'application/json', 'x-actor': 'day-click' };
  const roster = async (day) => (await (await fetch(API + '/checkin/roster?day=' + day, { headers: hdr })).json()).rows;
  const checked = (rows, rid, i) => {
    const r = rows.find((x) => x.rid === rid);
    const p = r && r.people.find((x) => Number(x.i) === i);
    return !!(p && p.checked);
  };

  // three complete parties, nobody in on either day
  const fri = await roster('fri');
  const sat = await roster('sat');
  const free = fri.filter((r) => r.status === 'complete' && r.wristband.ok && r.people.length &&
    r.people.every((p) => !p.checked) &&
    (sat.find((s) => s.rid === r.rid) || { people: [] }).people.every((p) => !p.checked));
  const pick = free.slice(0, 3).map((r) => r.rid);
  check('three complete parties with nobody checked in', pick.length === 3, pick.join(','));

  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const p = await browser.newPage();
  await p.setCookie({ name: cn, value: cr.join('='), domain: new URL(BASE).hostname, path: '/' });
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  await p.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
  await p.evaluate(() => { localStorage.removeItem('register.queue'); localStorage.setItem('register.actor', 'DayClick'); });
  await p.reload({ waitUntil: 'networkidle2' });
  await p.click('button[data-day="fri"]');
  await p.waitForSelector('.party', { timeout: 30000 });

  // offline, three Friday taps
  await p.setOfflineMode(true);
  await sleep(300);
  for (const rid of pick) {
    await p.evaluate(() => { const q = document.getElementById('q'); q.value = ''; });
    await p.type('#q', rid);
    await sleep(300);
    await p.click('[data-tap="' + rid + ':0"]');
    await sleep(200);
  }
  const q = await p.evaluate(() => JSON.parse(localStorage.getItem('register.queue') || '[]'));
  check('three taps wait on the phone, each marked Friday',
    q.length === 3 && q.every((x) => x.day === 'fri'), JSON.stringify(q.map((x) => x.day)));

  // the volunteer moves to Saturday before the signal comes back
  await p.evaluate(() => { const q = document.getElementById('q'); q.value = ''; q.dispatchEvent(new Event('input')); });
  await p.click('button[data-day="sat"]');
  await sleep(300);
  await p.setOfflineMode(false);
  await p.evaluate(() => window.dispatchEvent(new Event('online')));
  const end = Date.now() + 60000;
  let left = 3;
  while (Date.now() < end) {
    left = await p.evaluate(() => JSON.parse(localStorage.getItem('register.queue') || '[]').length);
    if (left === 0) break;
    await sleep(500);
  }
  check('the queue drained once the signal came back', left === 0, left + ' left');
  await sleep(2000);

  const fri2 = await roster('fri');
  const sat2 = await roster('sat');
  for (const rid of pick) {
    check(rid + ': on the ship as Friday\'s check-in', checked(fri2, rid, 0));
    check(rid + ': not on the ship as Saturday\'s', !checked(sat2, rid, 0));
  }

  // put both days back as they were
  for (const day of ['fri', 'sat']) {
    await fetch(API + '/checkin', {
      method: 'POST', headers: hdr,
      body: JSON.stringify({ day, checkins: pick.map((rid) => ({ rid, i: 0, undo: true })) }),
    });
  }
  await browser.close();
  console.log(fails ? 'FAIL (' + fails + ')' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}
main().catch((e) => { console.log('  CRASH ' + e.stack); process.exit(1); });
