// A headless click-through of the backoffice's check-in touches: the
// roster's check-ins column, the reports' checked-in figure, the
// Sunday counts grid, and the detail card that takes a check-in back.
//
// Run: node scripts/admin-click.js <rid>
//
// <rid> is a registration with two people checked in for Friday, which
// is what scripts/checkin-click.js leaves behind, so run that one
// first. It drives a real ship and undoes the second check-in, so run
// it against a test ship. It needs the owner cookie at
// ~/.config/lattice-fs/cookie and chromium with puppeteer-core. The
// gate does not call it: it is run by hand.
'use strict';
const { readFileSync } = require('fs');
const { homedir } = require('os');

const BASE = 'http://localhost:8080';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';
const RID = process.argv[2];

let fails = 0;
const check = (m, c, d) => {
  console.log((c ? '  ok   ' : '  FAIL ') + m + (c || !d ? '' : '   ' + String(d).slice(0, 200)));
  if (!c) fails++;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  if (!RID) {
    console.log('usage: node scripts/admin-click.js <rid>');
    process.exit(2);
  }
  const puppeteer = (await import(PUPPETEER)).default;
  const cookie = readFileSync(homedir() + '/.config/lattice-fs/cookie', 'utf8').trim();
  const [cn, ...cr] = cookie.split('=');
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const p = await browser.newPage();
  await p.setCookie({ name: cn, value: cr.join('='), domain: 'localhost', path: '/' });
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });

  await p.goto(BASE + '/apps/register/admin#roster', { waitUntil: 'networkidle2' });
  await p.waitForSelector('table tbody tr', { timeout: 20000 });
  const heads = await p.$$eval('thead th', (ns) => ns.map((n) => n.textContent));
  check('the roster has a check-ins column', heads.includes('Check-ins'), heads.join(','));
  const ticked = await p.$$eval('tbody tr', (ns) => ns.map((n) => n.textContent).filter((t) => t.includes('Fri')).length);
  check('at least one party shows a Friday tick', ticked > 0, ticked);

  await p.goto(BASE + '/apps/register/admin#reports', { waitUntil: 'networkidle2' });
  await sleep(4000);
  const rheads = await p.$$eval('th', (ns) => ns.map((n) => n.textContent));
  check('the per-day table has a checked-in column', rheads.includes('Checked in'), rheads.join(','));

  await p.goto(BASE + '/apps/register/admin#counts', { waitUntil: 'networkidle2' });
  await sleep(4000);
  const grids = await p.$$eval('h2 ~ .grid3', (ns) => ns.map((n) => n.textContent));
  const sun = grids[grids.length - 1] || '';
  check('the Sunday counts grid keeps Mass and the Holy Hour',
    sun.includes('Mass') && sun.includes('Holy Hour'), sun.slice(0, 120));
  check('and adds the two Sunday walk starts',
    sun.includes('10 mile start') && sun.includes('2.5 mile start'), sun.slice(0, 200));

  await p.goto(BASE + '/apps/register/admin#reg/' + RID, { waitUntil: 'networkidle2' });
  await sleep(4000);
  const cards = await p.$$eval('.card h3', (ns) => ns.map((n) => n.textContent));
  check('the registration has a check-ins card', cards.includes('Check-ins'), cards.join(','));
  const undo = await p.$$('[data-act="undo-checkin"]');
  check('each check-in offers an undo', undo.length === 2, undo.length);
  const text = await p.$eval('[data-act="undo-checkin"]', (n) => n.closest('.card').textContent);
  check('the card names the day and the volunteer',
    text.includes('Friday') && text.includes('admin:Sarah'), text.slice(0, 160));

  // set the actor, then undo one through the backoffice
  await p.click('#actor');
  await p.waitForSelector('#actor-name', { visible: true });
  await p.evaluate(() => { document.getElementById('actor-name').value = ''; });
  await p.type('#actor-name', 'Organizer');
  await p.click('#actor-save');
  await sleep(300);
  await (await p.$$('[data-act="undo-checkin"]'))[1].click();
  await sleep(3000);
  const res = await fetch(BASE + '/apps/register/api/checkin/roster?day=fri', { headers: { cookie } });
  const d = await res.json();
  const row = (d.rows || []).find((r) => r.rid === RID);
  check('the backoffice undo took the second check-in back',
    row && row.people[0].checked === true && row.people[1].checked === false,
    row && JSON.stringify(row.people.map((x) => x.checked)));

  await browser.close();
  console.log(fails ? fails + ' FAILED' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}

main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
