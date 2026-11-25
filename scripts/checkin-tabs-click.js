// A headless click-through of two copies of the check-in app on one
// phone (the home-screen app and a browser tab share their storage):
// each taps a different person offline, then the signal returns. Both
// taps must reach the ship; neither tab may overwrite the other's.
//
// Run: REG_BASE=http://localhost:8126 REG_COOKIE=<file> node scripts/checkin-tabs-click.js
//
// It takes the check-ins back afterwards. Run it against a test ship only.
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
  const hdr = { cookie, 'content-type': 'application/json', 'x-actor': 'tabs-click' };
  const rows = async () => (await (await fetch(API + '/checkin/roster?day=fri', { headers: hdr })).json()).rows;
  const free = (await rows()).filter((r) => r.status === 'complete' && r.wristband.ok && r.people.length && !r.people[0].checked);
  const [ra, rb] = [free[0].rid, free[1].rid];

  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const open = async () => {
    const p = await browser.newPage();
    await p.setCookie({ name: cn, value: cr.join('='), domain: new URL(BASE).hostname, path: '/' });
    p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
    await p.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
    await p.click('button[data-day="fri"]');
    await p.waitForSelector('.party', { timeout: 30000 });
    return p;
  };
  const one = await open();
  await one.evaluate(() => { localStorage.removeItem('register.queue'); localStorage.setItem('register.actor', 'TabsClick'); });
  await one.reload({ waitUntil: 'networkidle2' });
  await one.click('button[data-day="fri"]');
  await one.waitForSelector('.party', { timeout: 30000 });
  const two = await open();
  const tap = async (p, rid) => {
    // a page in the background is throttled: bring it forward to use it
    await p.bringToFront();
    await p.evaluate(() => { document.getElementById('q').value = ''; });
    await p.type('#q', rid);
    await sleep(300);
    await p.click('[data-tap="' + rid + ':0"]');
    await sleep(300);
  };
  await one.setOfflineMode(true);
  await two.setOfflineMode(true);
  await tap(one, ra);
  await tap(two, rb);
  // tab one stores again after tab two did, as it would on its next tick
  await one.bringToFront();
  await one.evaluate(() => window.dispatchEvent(new Event('offline')));
  await sleep(500);
  const stored = await one.evaluate(() => JSON.parse(localStorage.getItem('register.queue') || '[]').map((q) => q.rid));
  check('the phone\'s storage holds both tabs\' taps', stored.includes(ra) && stored.includes(rb), stored.join(','));
  // only tab one comes back online; tab two is closed with its tap unsent
  await two.close();
  await one.setOfflineMode(false);
  await one.evaluate(() => window.dispatchEvent(new Event('online')));
  const end = Date.now() + 40000;
  let left = 2;
  while (Date.now() < end) {
    left = await one.evaluate(() => JSON.parse(localStorage.getItem('register.queue') || '[]').filter((q) => !q.why).length);
    if (left === 0) break;
    await sleep(500);
  }
  check('the tab left open sent both', left === 0, left + ' left');
  await sleep(1500);
  const after = await rows();
  check('the ship has the first tab\'s tap', after.find((r) => r.rid === ra).people[0].checked);
  check('and the closed tab\'s tap', after.find((r) => r.rid === rb).people[0].checked);
  await fetch(API + '/checkin', { method: 'POST', headers: hdr,
    body: JSON.stringify({ day: 'fri', checkins: [{ rid: ra, i: 0, undo: true }, { rid: rb, i: 0, undo: true }] }) });
  await browser.close();
  console.log(fails ? 'FAIL (' + fails + ')' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}
main().catch((e) => { console.log('  CRASH ' + e.stack); process.exit(1); });
