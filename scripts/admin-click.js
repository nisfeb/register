// A headless click-through of the backoffice: the roster's check-ins
// column, the reports' checked-in figure, the Sunday counts grid, the
// detail card that takes a check-in back, the emails page that
// replaced the copy page, and an action painted before the ship has
// taken it.
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
// the pending mark clears on a read the page makes a second later, so
// it is polled for rather than read after a fixed wait
const gone = async (page, sel, ms) => {
  const end = Date.now() + ms;
  for (;;) {
    if (!(await page.$(sel))) return true;
    if (Date.now() > end) return false;
    await sleep(150);
  }
};

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

  // ---- an action is on screen before the ship has taken it ----
  await p.goto(BASE + '/apps/register/admin#reg/' + RID, { waitUntil: 'networkidle2' });
  await p.waitForSelector('[data-act="save"]', { timeout: 20000 });
  const wasNote = await p.$eval('[data-k="notes"]', (n) => n.value);
  const mark = 'clicked at ' + Date.now();
  await p.evaluate((t) => {
    const el = document.querySelector('[data-k="notes"]');
    el.value = t;
    el.dispatchEvent(new Event('input', { bubbles: true }));
  }, mark);
  await p.click('[data-act="save"]');
  const painted = await p.evaluate(() => ({
    pending: !!document.querySelector('.card.pending'),
    saying: !!document.querySelector('.card.pending .tag'),
    note: (document.querySelector('[data-k="notes"]') || {}).value,
  }));
  check('the change is on screen the moment the request goes up',
    painted.pending && painted.saying && painted.note === mark, JSON.stringify(painted));
  check('and the faint mark goes once the ship has confirmed it', await gone(p, '.card.pending', 20000));
  const settled = await p.$eval('[data-k="notes"]', (n) => n.value);
  check('the note the ship answers is the note that was typed', settled === mark, settled);
  const hist = await p.$$eval('.hist li', (ns) => ns.map((n) => n.textContent));
  check('the history names the organizer who made the change',
    hist.some((h) => h.includes('Organizer')), hist.slice(0, 3).join(' | '));
  // put the note back
  await p.evaluate((t) => {
    const el = document.querySelector('[data-k="notes"]');
    el.value = t;
    el.dispatchEvent(new Event('input', { bubbles: true }));
  }, wasNote);
  await p.click('[data-act="save"]');
  await gone(p, '.card.pending', 20000);
  check('the note it started with is back', (await p.$eval('[data-k="notes"]', (n) => n.value)) === wasNote);

  // ---- the roster keeps its rows rather than reading them again ----
  await p.goto(BASE + '/apps/register/admin#roster', { waitUntil: 'networkidle2' });
  await p.waitForSelector('table tbody tr', { timeout: 20000 });
  const kept = await p.evaluate(() => {
    try { return JSON.parse(localStorage.getItem('register.admin.roster') || 'null'); } catch (e) { return null; }
  });
  check('the roster is kept in this browser for the next visit',
    kept && kept.doc && Array.isArray(kept.doc.regs) && kept.doc.regs.length > 0, kept && Object.keys(kept));

  // ---- the copy page is the emails page now ----
  const nav = await p.$$eval('#nav a', (ns) => ns.map((n) => n.textContent));
  check('the nav offers Emails and no longer Copy',
    nav.includes('Emails') && !nav.includes('Copy'), nav.join(','));
  const toCheckin = await p.$$eval('#nav a[href="/apps/register/checkin"]',
    (ns) => ns.map((n) => [n.textContent, n.getAttribute('target')]));
  check('the nav offers the way to the check-in app, in the same tab',
    toCheckin.length === 1 && toCheckin[0][0] === 'Check-in' && toCheckin[0][1] === null,
    JSON.stringify(toCheckin));
  await p.goto(BASE + '/apps/register/admin#emails', { waitUntil: 'networkidle2' });
  await p.waitForSelector('.card.mail', { timeout: 20000 });
  const keys = await p.$$eval('[data-copy]', (ns) => ns.map((n) => n.getAttribute('data-copy')));
  check('the emails page edits the email templates and nothing else',
    keys.length > 4 && keys.every((k) => k.indexOf('email.') === 0), keys.join(','));
  check('every template has a Save of its own',
    (await p.$$('[data-act="save-mail"]')).length === (await p.$$('.card.mail')).length);
  const help = await p.$$eval('.card.mail .help', (ns) => ns.map((n) => n.textContent));
  check('the body lists the placeholders the ship fills',
    help.some((h) => h.includes('{{link}}')), help.slice(0, 2).join(' | '));
  const top = await p.$eval('#view > p', (n) => n.textContent);
  check('a line says where every other string is edited',
    top.includes('Edit text'), top);
  // a change that drops a placeholder never leaves the browser
  const bodyKey = keys.filter((k) => /\.body$/.test(k))[0];
  const wasBody = await p.$eval('[data-copy="' + bodyKey + '"]', (n) => n.value);
  await p.evaluate((k) => {
    const el = document.querySelector('[data-copy="' + k + '"]');
    el.value = 'no placeholders here';
    el.dispatchEvent(new Event('input', { bubbles: true }));
  }, bodyKey);
  await p.click('.card.mail [data-act="save-mail"]');
  await sleep(600);
  const said = await p.$eval('#say', (n) => n.textContent);
  check('an email that loses a placeholder is refused in the page',
    said.startsWith('Put these back before saving: {{'), said);
  check('and the template it was typed over comes straight back',
    (await p.$eval('[data-copy="' + bodyKey + '"]', (n) => n.value)) === wasBody);

  await browser.close();
  console.log(fails ? fails + ' FAILED' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}

main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
