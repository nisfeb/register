// A headless click-through of /apps/register/checkin: the actor prompt,
// the search, a tap online, a tap offline, the queue draining when the
// signal is back, and the counts tab.
//
// Run: node scripts/checkin-click.js <rid> <lastname>
//
// <rid> is a complete registration with two people on the ship the
// script points at, and <lastname> is that party's last name, which
// must match no other party. It drives a real ship: it leaves the two
// people checked in for Friday, so run it against a test ship and take
// the check-ins back afterwards. It needs the owner cookie at
// ~/.config/lattice-fs/cookie and chromium with puppeteer-core. The
// gate does not call it: it is run by hand.
'use strict';
const { readFileSync } = require('fs');
const { homedir } = require('os');

const BASE = 'http://localhost:8080';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';
const RID = process.argv[2];
const LAST = process.argv[3];

let fails = 0;
const check = (m, c, d) => {
  console.log((c ? '  ok   ' : '  FAIL ') + m + (c || !d ? '' : '   ' + String(d).slice(0, 200)));
  if (!c) fails++;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// the ship reads every registration on a check-in post, so the badge is
// polled rather than read after a fixed wait
const badgeIs = async (page, want, ms) => {
  const end = Date.now() + ms;
  for (;;) {
    const got = await page.$eval('#sync', (e) => e.textContent);
    if (got === want || Date.now() > end) return got;
    await sleep(250);
  }
};

async function main() {
  if (!RID || !LAST) {
    console.log('usage: node scripts/checkin-click.js <rid> <lastname>');
    process.exit(2);
  }
  const puppeteer = (await import(PUPPETEER)).default;
  const cookie = readFileSync(homedir() + '/.config/lattice-fs/cookie', 'utf8').trim();
  const [cn, ...cr] = cookie.split('=');
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const p = await browser.newPage();
  await p.setCookie({ name: cn, value: cr.join('='), domain: 'localhost', path: '/' });
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });

  await p.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
  check('the page is the check-in app', (await p.title()) === 'BSC Check-in');
  await p.waitForSelector('.party', { timeout: 20000 });
  check('the roster painted parties', (await p.$$('.party')).length > 0);

  // the volunteer's name
  await p.click('#actor');
  await p.waitForSelector('#actor-name', { visible: true });
  await p.evaluate(() => { document.getElementById('actor-name').value = ''; });
  await p.type('#actor-name', 'Sarah');
  await p.click('#actor-save');
  await sleep(300);
  check('the header says who is acting', (await p.$eval('#actor', (e) => e.textContent)).includes('Sarah'));

  // the search
  await p.type('#q', LAST);
  await sleep(400);
  const shown = await p.$$eval('.party .rid', (ns) => ns.map((n) => n.textContent));
  check('the search narrowed the roster to that party', shown.length === 1 && shown[0] === RID, shown.join(','));
  const band = await p.$eval('.party', (n) => n.className);
  check('a complete party has no red bar', !band.includes('no'), band);
  const drawn = await p.$eval('.party', (n) => n.textContent);
  check('the card never draws the email it can be searched by', !drawn.includes('@'), drawn.slice(0, 160));

  // the first tap, online
  const taps = await p.$$('.party [data-tap]');
  check('every person has a tap button', taps.length === 2, taps.length);
  await taps[0].click();
  const synced = await badgeIs(p, 'synced', 30000);
  const first = await p.$eval('.party .person:nth-of-type(1) .tap', (n) => [n.className, n.textContent]);
  check('the button turned green and says when and who',
    first[0].includes('on') && /Checked in .* by Sarah/.test(first[1]), first.join(' | '));
  check('the badge says synced once the ship has the tap', synced === 'synced', synced);

  // the second tap, offline
  await p.setOfflineMode(true);
  await sleep(300);
  const off = await p.$$('.party [data-tap]');
  check('the second person is still untapped', off.length === 1, off.length);
  await off[0].click();
  const badge = await badgeIs(p, '1 waiting', 5000);
  check('offline, the badge counts the tap waiting', badge === '1 waiting', badge);
  const second = await p.$eval('.party .person:nth-of-type(2) .tap', (n) => n.className);
  check('the offline tap still paints the person checked in', second.includes('on'), second);

  // back online
  await p.setOfflineMode(false);
  const after = await badgeIs(p, 'synced', 30000);
  check('back online the queue drained and the badge says synced', after === 'synced', after);

  // the ship agrees
  const res = await fetch(BASE + '/apps/register/api/checkin/roster?day=fri', { headers: { cookie } });
  const d = await res.json();
  const row = (d.rows || []).find((r) => r.rid === RID);
  check('the ship has both people checked in for the day',
    row && row.people.every((x) => x.checked === true), row && JSON.stringify(row.people.map((x) => x.checked)));
  check('the ship recorded the volunteer who tapped',
    row && row.people[0].by === 'admin:Sarah', row && row.people[0].by);

  // the counts tab, and what typing in it does before Save
  await p.click('#tabs button[data-tab="counts"]');
  await sleep(800);
  const acts = await p.$$eval('.counts .act h3', (ns) => ns.map((n) => n.textContent));
  check('the counts tab shows the day\'s activities',
    acts.join(',') === 'Walk,Mass,Holy Hour,Social,Bus', acts.join(','));
  const planned = await p.$eval('.counts .act .planned', (n) => n.textContent);
  check('each activity shows its planned figure', /planned: \d+/.test(planned), planned);
  await p.click('[data-count="mass.count"]', { clickCount: 3 });
  await p.type('[data-count="mass.count"]', '137');
  await sleep(600);
  const typed = await p.evaluate(() => document.querySelector('[data-count="mass.count"]').value);
  check('the keystroke stayed in the box', typed === '137', typed);
  const armed = await p.evaluate(() => localStorage.getItem('register.counts.fri.save'));
  check('nothing is queued to go up until Save is pressed', armed === null, armed);
  await p.click('[data-count="walk.count"]', { clickCount: 3 });
  await p.type('[data-count="walk.count"]', '88');
  await sleep(600);
  const draft = await p.evaluate(() => JSON.parse(localStorage.getItem('register.counts.fri') || '{}'));
  check('a second activity typed does not blank the first',
    draft.mass && String(draft.mass.count) === '137' && draft.walk && String(draft.walk.count) === '88',
    JSON.stringify(draft));

  // the Sunday grid counts the two starts as well
  await p.click('#days button[data-day="sun"]');
  await sleep(1500);
  await p.click('#tabs button[data-tab="counts"]');
  await sleep(800);
  const sun = await p.$$eval('.counts .act h3', (ns) => ns.map((n) => n.textContent));
  check('Sunday counts Mass and the Holy Hour as well as the two starts',
    sun.join(',') === 'Walk,Mass,Holy Hour,Social,Bus,10 mile start,2.5 mile start', sun.join(','));

  await browser.close();
  console.log(fails ? fails + ' FAILED' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}

main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
