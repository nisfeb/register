// A headless click-through of R3 in the check-in test plan: a login that
// runs out while taps wait on the phone. Taps queued offline must stay on
// the phone while the ship refuses the login, the app must ask for the
// login (for a cookie the ship no longer knows, which eyre answers 401,
// and for no cookie at all, which the app answers 403), and once logged
// in again every tap must reach the ship.
//
// Run: REG_BASE=http://localhost:8126 REG_COOKIE=<file> node scripts/checkin-login-click.js
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

async function run(browser, cookie, how) {
  const [cn, ...cr] = cookie.split('=');
  const host = new URL(BASE).hostname;
  const hdr = { cookie, 'content-type': 'application/json', 'x-actor': 'login-click' };
  const rows = async () => (await (await fetch(API + '/checkin/roster?day=fri', { headers: hdr })).json()).rows;
  const free = (await rows()).filter((r) => r.status === 'complete' && r.wristband.ok && r.people.length &&
    !r.people[0].checked).slice(how === 'expired' ? 0 : 2, how === 'expired' ? 2 : 4);
  const rids = free.map((r) => r.rid);
  console.log('case: the login ' + (how === 'expired' ? 'the ship no longer knows (401)' : 'gone from the browser (403)'));

  const ctx = await browser.createBrowserContext();
  const p = await ctx.newPage();
  await p.setCookie({ name: cn, value: cr.join('='), domain: host, path: '/' });
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  await p.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
  await p.evaluate(() => { localStorage.removeItem('register.queue'); localStorage.setItem('register.actor', 'LoginClick'); });
  await p.reload({ waitUntil: 'networkidle2' });
  await p.click('button[data-day="fri"]');
  await p.waitForSelector('.party', { timeout: 30000 });

  await p.setOfflineMode(true);
  for (const rid of rids) {
    await p.evaluate(() => { document.getElementById('q').value = ''; });
    await p.type('#q', rid);
    await sleep(300);
    await p.click('[data-tap="' + rid + ':0"]');
    await sleep(200);
  }
  // the login goes bad while the phone has no signal
  if (how === 'expired') await p.setCookie({ name: cn, value: '0v1.abcde.fghij', domain: host, path: '/' });
  else await p.deleteCookie({ name: cn, domain: host, path: '/' });
  await p.setOfflineMode(false);
  await p.evaluate(() => window.dispatchEvent(new Event('online')));
  await sleep(4000);
  const shown = await p.$eval('#relogin', (e) => !e.hidden);
  check('the app asks for the login again', shown);
  const q = await p.evaluate(() => JSON.parse(localStorage.getItem('register.queue') || '[]').length);
  check('both taps are still on the phone', q === 2, q);
  const before = await rows();
  check('nothing reached the ship without a login',
    rids.every((rid) => !before.find((r) => r.rid === rid).people[0].checked));

  // logged in again: the login page sends the phone back to the app
  await p.setCookie({ name: cn, value: cr.join('='), domain: host, path: '/' });
  await p.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
  const end = Date.now() + 40000;
  let left = 2;
  while (Date.now() < end) {
    left = await p.evaluate(() => JSON.parse(localStorage.getItem('register.queue') || '[]').length);
    if (left === 0) break;
    await sleep(500);
  }
  check('logged in again, the queue drained', left === 0, left + ' left');
  await sleep(1500);
  const after = await rows();
  check('the ship has both taps', rids.every((rid) => after.find((r) => r.rid === rid).people[0].checked));
  await fetch(API + '/checkin', { method: 'POST', headers: hdr,
    body: JSON.stringify({ day: 'fri', checkins: rids.map((rid) => ({ rid, i: 0, undo: true })) }) });
  await ctx.close();
}

async function main() {
  const puppeteer = (await import(PUPPETEER)).default;
  const cookie = readFileSync(process.env.REG_COOKIE, 'utf8').trim();
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  await run(browser, cookie, 'expired');
  await run(browser, cookie, 'gone');
  await browser.close();
  console.log(fails ? 'FAIL (' + fails + ')' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}
main().catch((e) => { console.log('  CRASH ' + e.stack); process.exit(1); });
