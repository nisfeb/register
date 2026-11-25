// A headless click-through of a tap the ship refuses: the phone holds a
// party as it was, an organizer removes someone from it, and the
// volunteer taps that person from the phone's list. The ship must refuse
// the tap, and the phone must show the person as NOT checked in, with
// what to do, so nobody is waved through on a tick that never landed.
//
// Run: REG_BASE=http://localhost:8126 REG_COOKIE=<file> node scripts/checkin-stale-click.js
//
// It edits one party of three and leaves it a party of two. Run it
// against a test ship only.
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
  const hdr = { cookie, 'content-type': 'application/json', 'x-actor': 'stale-click' };
  const get = async (path) => (await fetch(API + path, { headers: hdr })).json();
  const row = (await get('/checkin/roster?day=fri')).rows.find((r) => r.status === 'complete' &&
    r.wristband.ok && r.people.length === 3 && !r.people.some((p) => p.checked));
  const rid = row.rid;
  const gone = row.people[1];

  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const p = await browser.newPage();
  await p.setCookie({ name: cn, value: cr.join('='), domain: new URL(BASE).hostname, path: '/' });
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  await p.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
  await p.evaluate(() => { localStorage.removeItem('register.queue'); localStorage.setItem('register.actor', 'StaleClick'); });
  await p.reload({ waitUntil: 'networkidle2' });
  await p.click('button[data-day="fri"]');
  await p.waitForSelector('.party', { timeout: 30000 });
  // the phone stops hearing the ship, so its list stays as it was
  await p.setOfflineMode(true);

  // an organizer removes the middle person
  const reg = await get('/admin/reg/' + rid);
  const input = { track: reg.track, contact: reg.contact, org: reg.org, why: reg.why,
    assistance: reg.assistance, together: reg.together,
    people: reg.people.filter((_, i) => i !== 1).map((x) => { const y = Object.assign({}, x); delete y.checkins; return y; }) };
  const ed = await fetch(API + '/admin/reg/' + rid, { method: 'POST', headers: hdr, body: JSON.stringify({ op: 'edit', input }) });
  check('the organizer removed ' + gone.first, ed.ok, ed.status);

  // the volunteer taps that person from the old list, then the signal returns
  await p.type('#q', rid);
  await sleep(300);
  await p.click('[data-tap="' + rid + ':1"]');
  await p.setOfflineMode(false);
  await p.evaluate(() => window.dispatchEvent(new Event('online')));
  const end = Date.now() + 40000;
  let stuck = '';
  while (Date.now() < end) {
    stuck = await p.evaluate(() => { const e = document.querySelector('.stuck'); return e ? e.textContent : ''; });
    if (stuck) break;
    await sleep(500);
  }
  check('the phone says the tap did not land, and what to do', /^Not checked in: this party changed/.test(stuck), stuck);
  const shown = await p.evaluate((r) => {
    const party = Array.from(document.querySelectorAll('.party')).find((x) => x.textContent.includes(r));
    return party ? Array.from(party.querySelectorAll('.tap')).map((b) => b.className + '|' + b.textContent) : [];
  }, rid);
  check('no button on the phone shows a check-in that never landed', shown.every((t) => !/\bon\b/.test(t.split('|')[0])), shown.join(' ; '));
  const after = (await get('/checkin/roster?day=fri')).rows.find((r) => r.rid === rid);
  check('the ship checked nobody in', after.people.every((x) => !x.checked), JSON.stringify(after.people.map((x) => x.first + ':' + x.checked)));
  check('the queue holds nothing waiting', await p.evaluate(() =>
    JSON.parse(localStorage.getItem('register.queue') || '[]').filter((q) => !q.why).length === 0));

  // the same refusal online, with no roster read to cover it: the phone
  // has painted the tap, the ship refuses it, and nothing refetches
  const row2 = (await get('/checkin/roster?day=fri')).rows.find((r) => r.rid !== rid && r.status === 'complete' &&
    r.wristband.ok && r.people.length === 3 && !r.people.some((x) => x.checked));
  const rid2 = row2.rid;
  const q = await browser.newPage();
  await q.setCookie({ name: cn, value: cr.join('='), domain: new URL(BASE).hostname, path: '/' });
  q.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  await q.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
  await q.evaluate(() => { localStorage.removeItem('register.queue'); localStorage.setItem('register.actor', 'StaleClick'); });
  await q.reload({ waitUntil: 'networkidle2' });
  await q.click('button[data-day="fri"]');
  await q.waitForSelector('.party', { timeout: 30000 });
  // from here the phone reads no roster and no beacon: only taps go up
  await q.setRequestInterception(true);
  q.on('request', (r) => {
    const u = r.url();
    if (u.includes('/checkin/roster') || u.includes('/grubbery/api/keep/')) return r.abort();
    r.continue();
  });
  const reg2 = await get('/admin/reg/' + rid2);
  const input2 = { track: reg2.track, contact: reg2.contact, org: reg2.org, why: reg2.why,
    assistance: reg2.assistance, together: reg2.together,
    people: reg2.people.filter((_, i) => i !== 1).map((x) => { const y = Object.assign({}, x); delete y.checkins; return y; }) };
  await fetch(API + '/admin/reg/' + rid2, { method: 'POST', headers: hdr, body: JSON.stringify({ op: 'edit', input: input2 }) });
  await q.type('#q', rid2);
  await sleep(300);
  await q.click('[data-tap="' + rid2 + ':1"]');
  const end2 = Date.now() + 40000;
  let stuck2 = '';
  while (Date.now() < end2) {
    stuck2 = await q.evaluate(() => { const e = document.querySelector('.stuck'); return e ? e.textContent : ''; });
    if (stuck2) break;
    await sleep(500);
  }
  check('online, with no roster read after it, the refused tap says so', /^Not checked in/.test(stuck2), stuck2);
  const shown2 = await q.evaluate((r) => {
    const party = Array.from(document.querySelectorAll('.party')).find((x) => x.textContent.includes(r));
    return party ? Array.from(party.querySelectorAll('.tap')).map((b) => b.className + '|' + b.textContent) : [];
  }, rid2);
  check('and no button shows a check-in that never landed', shown2.every((t) => !/\bon\b/.test(t.split('|')[0])), shown2.join(' ; '));

  await browser.close();
  console.log(fails ? 'FAIL (' + fails + ')' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}
main().catch((e) => { console.log('  CRASH ' + e.stack); process.exit(1); });
