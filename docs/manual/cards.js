// The per-card close-ups, shot as elements so the coordinates are the
// browser's problem and not mine. Seeds the same sample parties, shoots,
// then cancels them. Run: node cards.js
'use strict';
const { readFileSync } = require('fs');
const { homedir } = require('os');
const BASE = 'http://localhost:8080';
const API = BASE + '/apps/register/api';
const OUT = __dirname + '/img';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';
const cookie = readFileSync(homedir() + '/.config/lattice-fs/cookie', 'utf8').trim();
const [cn, ...cr] = cookie.split('=');
const hdr = { 'content-type': 'application/json', cookie, 'x-actor': 'Susan' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const j = async (r) => { try { return await r.json(); } catch (e) { return {}; } };
const post = (p, b) => fetch(API + p, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(b || {}) });

const who = (first, last, o = {}) => ({
  first, last, child: !!o.child,
  days: { fri: o.fri !== false, sat: o.sat !== false, sun: o.sun !== false },
  sun_ten: o.sun_ten !== false, social_fri: !!o.social_fri, social_sat: !!o.social_sat,
  mass_fri: !!o.mass_fri, holy_hour: !!o.holy_hour, bus: !!o.bus,
  first_bsc: !!o.first_bsc, knight_dame: !!o.knight_dame, volunteer: !!o.volunteer,
});
const party = (track, mail, people, o = {}) => ({
  track, contact: { email: mail, phone: '904-555-0143', street: '1220 Beach Boulevard',
    city: o.city || 'Jacksonville Beach', state: o.state || 'FL', zip: '32250' },
  org: o.org === undefined ? 'Order of Malta' : o.org, why: o.why || 'To walk in thanksgiving.',
  assistance: !!o.assistance, together: false, people,
});
const made = [];
async function make(track, mail, people, opts = {}) {
  const d = await j(await post('/submit', party(track, mail, people, opts)));
  if (!d.rid) throw new Error('submit: ' + JSON.stringify(d));
  made.push([d.rid, d.token]);
  await post(`/reg/${d.rid}/sign?t=${d.token}`, {});
  await sleep(1200);
  await post(`/reg/${d.rid}/pay?t=${d.token}`, {});
  await sleep(1200);
  return d;
}

async function main() {
  const alvarez = await make('full', 'm.alvarez@example.com',
    [who('Margaret', 'Alvarez', { social_fri: true, social_sat: true, mass_fri: true, holy_hour: true, bus: true, first_bsc: true }),
     who('Thomas', 'Alvarez', { social_fri: true, social_sat: true, bus: true }),
     who('Lucy', 'Alvarez', { child: true, sun_ten: false, social_sat: true, bus: true })],
    { org: 'St. Paul’s, Jacksonville Beach', why: 'Our whole family is walking for my mother.' });
  await make('full', 'rita.donnelly@example.com', [who('Rita', 'Donnelly', { knight_dame: true })], { state: 'GA', city: 'Savannah' });
  await make('bambino', 'g.whitfield@example.com',
    [who('Grace', 'Whitfield', { fri: false, sat: false }), who('Ellis', 'Whitfield', { fri: false, sat: false, child: true })], { org: '' });
  await sleep(1500);

  const puppeteer = (await import(PUPPETEER)).default;
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  try {
    const p = await browser.newPage();
    await p.setViewport({ width: 820, height: 1000, deviceScaleFactor: 2 });
    await p.setCookie({ name: cn, value: cr.join('='), domain: 'localhost', path: '/' });
    await p.evaluateOnNewDocument(() => { try { localStorage.setItem('register.actor', 'Susan'); } catch (e) {} });

    // an element screenshot: the browser scrolls it into view and gets
    // the coordinates right, which a hand-computed clip did not
    const card = async (file, title) => {
      const found = await p.evaluate((t) => {
        const h = [...document.querySelectorAll('.card h3, .card h2')].find((x) => x.textContent.trim() === t);
        if (!h) return false;
        h.closest('.card').setAttribute('data-shot', '1');
        return true;
      }, title);
      if (!found) { console.log('  MISSING ' + title); return; }
      const el = await p.$('[data-shot="1"]');
      await el.screenshot({ path: `${OUT}/${file}.png` });
      await p.evaluate(() => { const c = document.querySelector('[data-shot="1"]'); if (c) c.removeAttribute('data-shot'); });
      console.log('  card ' + file + ' <- ' + title);
    };

    await p.goto(BASE + '/apps/register/admin#reg/' + alvarez.rid, { waitUntil: 'networkidle2' });
    await p.waitForSelector('[data-act="save"]', { timeout: 60000 });
    await card('reg-status', 'Status');
    await card('reg-payment', 'Payment');
    await card('reg-waiver', 'Waiver');
    await card('reg-actions', 'Actions');
    await card('reg-history', 'History');

    await p.goto(BASE + '/apps/register/admin#reports', { waitUntil: 'networkidle2' });
    await p.waitForSelector('.grid3', { timeout: 60000 });
    await card('reports-caps', 'Against the caps');
    await card('reports-owing', 'Still owing');

    await p.goto(BASE + '/apps/register/admin#settings', { waitUntil: 'networkidle2' });
    await p.waitForSelector('[data-act="save-settings"]', { timeout: 60000 });
    await card('settings-fees', 'Fees, in dollars');
    await card('settings-window', 'Window');
    await card('settings-event', 'Event');

    await p.goto(BASE + '/apps/register/admin#add', { waitUntil: 'networkidle2' });
    await p.waitForSelector('[data-act="submit-add"]', { timeout: 60000 });
    await card('add-took', 'What you took from them');
    await p.close();
  } finally {
    await browser.close();
    for (const [rid, tok] of made) await post(`/reg/${rid}/cancel?t=${tok}`, {});
    console.log('sample parties cancelled: ' + made.length);
  }
}
main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
