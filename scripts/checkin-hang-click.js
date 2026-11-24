// A headless click-through of R9 in the check-in test plan: a request
// that hangs (a dead cell connection that never errors) must not stall
// the check-in queue. The app gives up on it after a minute, says why,
// and sends the tap again once the line works.
//
// Run: REG_BASE=http://localhost:8126 REG_COOKIE=<file> node scripts/checkin-hang-click.js
//
// It holds every POST to /api/checkin open without answering, taps one
// person, waits for the timeout, lets the posts through, and reads the
// ship. It takes the check-in back afterwards. Takes about 90 seconds.
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
  const hdr = { cookie, 'content-type': 'application/json', 'x-actor': 'hang-click' };
  const rows = async () => (await (await fetch(API + '/checkin/roster?day=fri', { headers: hdr })).json()).rows;
  const r0 = (await rows()).find((r) => r.status === 'complete' && r.wristband.ok && r.people.length && !r.people[0].checked);
  check('a complete party with its first person not checked in', !!r0);
  const rid = r0.rid;

  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const p = await browser.newPage();
  await p.setCookie({ name: cn, value: cr.join('='), domain: new URL(BASE).hostname, path: '/' });
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  let hang = true, held = 0, sent = 0;
  await p.setRequestInterception(true);
  p.on('request', (q) => {
    const isTap = q.method() === 'POST' && q.url().endsWith('/apps/register/api/checkin');
    if (isTap && hang) { held += 1; return; }   // never answered: the line is dead
    if (isTap) sent += 1;
    q.continue();
  });
  await p.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
  await p.evaluate(() => { localStorage.removeItem('register.queue'); localStorage.setItem('register.actor', 'HangClick'); });
  await p.reload({ waitUntil: 'networkidle2' });
  await p.click('button[data-day="fri"]');
  await p.waitForSelector('.party', { timeout: 30000 });
  await p.type('#q', rid);
  await sleep(300);
  await p.click('[data-tap="' + rid + ':0"]');
  await sleep(2000);
  check('the tap went up and is being held', held === 1, held);

  // past the minute the app waits, it says why and keeps the tap
  await sleep(62000);
  const badge = await p.$eval('#sync', (e) => e.textContent);
  check('the badge says the ship took too long', /too long/.test(badge), badge);
  const q = await p.evaluate(() => JSON.parse(localStorage.getItem('register.queue') || '[]'));
  check('the tap is still on the phone', q.length === 1 && q[0].rid === rid, JSON.stringify(q));

  // the line works again: the next tick sends it
  hang = false;
  const end = Date.now() + 40000;
  let left = 1;
  while (Date.now() < end) {
    left = await p.evaluate(() => JSON.parse(localStorage.getItem('register.queue') || '[]').length);
    if (left === 0) break;
    await sleep(500);
  }
  check('once the line works the queue drains without a reload', left === 0, left + ' left');
  check('the tap went up again', sent >= 1, sent);
  await sleep(1500);
  const after = (await rows()).find((r) => r.rid === rid);
  check('the ship has the check-in', after && after.people[0].checked);

  await fetch(API + '/checkin', { method: 'POST', headers: hdr,
    body: JSON.stringify({ day: 'fri', checkins: [{ rid, i: 0, undo: true }] }) });
  await browser.close();
  console.log(fails ? 'FAIL (' + fails + ')' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}
main().catch((e) => { console.log('  CRASH ' + e.stack); process.exit(1); });
