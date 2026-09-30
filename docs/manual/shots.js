// Screenshots for the admin manual, taken against a ship with register
// installed and a handful of plausible sample parties. Creates the
// parties, shoots every screen, then cancels what it made.
//
//   node shots.js
//   REG_BASE=http://localhost:8080 REG_COOKIE=/path/to/cookie node shots.js
//
// The ship must be in STUB mode: the script signs and pays by posting to
// the pilgrim's own routes, which in live mode would want a real card.
// Never point it at the ship the organizers are using.
'use strict';
const { readFileSync, mkdirSync } = require('fs');
const { homedir } = require('os');
const BASE = process.env.REG_BASE || 'http://localhost:8080';
const API = BASE + '/apps/register/api';
const OUT = __dirname + '/img';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';
const cookie = readFileSync(process.env.REG_COOKIE || homedir() + '/.config/lattice-fs/cookie', 'utf8').trim();
const [cn, ...cr] = cookie.split('=');
const hdr = { 'content-type': 'application/json', cookie, 'x-actor': 'Susan' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const j = async (r) => { try { return await r.json(); } catch (e) { return {}; } };
const post = (p, b, own) => fetch(API + p, { method: 'POST', headers: own ? hdr : { 'content-type': 'application/json' }, body: JSON.stringify(b || {}) });
const put = (p, b) => fetch(API + p, { method: 'PUT', headers: hdr, body: JSON.stringify(b) });

const who = (first, last, o = {}) => ({
  first, last, child: !!o.child,
  days: { fri: o.fri !== false, sat: o.sat !== false, sun: o.sun !== false },
  sun_ten: o.sun_ten !== false, social_fri: !!o.social_fri, social_sat: !!o.social_sat,
  mass_fri: !!o.mass_fri, mass_sat: !!o.mass_sat, mass_sun: !!o.mass_sun,
  holy_hour: !!o.holy_hour, bus: !!o.bus, trolley: !!o.trolley,
  first_bsc: !!o.first_bsc, knight_dame: !!o.knight_dame, volunteer: !!o.volunteer,
});
const party = (track, mail, people, o = {}) => ({
  track, contact: { email: mail, phone: o.phone || '904-555-0143', street: o.street || '1220 Beach Boulevard',
    city: o.city || 'Jacksonville Beach', state: o.state || 'FL', zip: o.zip || '32250' },
  org: o.org || 'Order of Malta', why: o.why || 'To walk in thanksgiving for a good year.',
  assistance: !!o.assistance, together: false, people,
});

// the hash of the terms as the ship now holds them: what the page sends
// back when a pilgrim adopts them, and what a live ship checks
let hash = null;
async function waiverHash() {
  if (hash === null) hash = (await j(await fetch(API + '/status'))).waiver_hash || '';
  return hash;
}

const made = [];
async function make(track, mail, people, opts = {}) {
  const d = await j(await post('/submit', party(track, mail, people, opts)));
  if (!d.rid) throw new Error('submit: ' + JSON.stringify(d));
  made.push([d.rid, d.token]);
  if (opts.stop === 'waiver') return d;
  await post(`/reg/${d.rid}/sign?t=${d.token}`, { agreed: true, text_hash: await waiverHash() });
  await sleep(1200);
  if (opts.stop === 'payment') return d;
  await post(`/reg/${d.rid}/pay?t=${d.token}`, {});
  await sleep(1200);
  return d;
}

async function main() {
  mkdirSync(OUT, { recursive: true });
  const settings = await j(await fetch(API + '/admin/settings', { headers: hdr }));
  const wasEvent = JSON.parse(JSON.stringify(settings.event));
  const st = await j(await fetch(API + '/status'));
  const off = Number(settings.event.utc_offset_hours ?? -5) || 0;
  const local = new Date(Date.parse(st.now) + off * 3600000);
  const day = (k) => new Date(local.getTime() + k * 86400000).toISOString().slice(0, 10);

  // ---- a handful of parties that read like real ones ----
  const alvarez = await make('full', 'm.alvarez@example.com',
    [who('Margaret', 'Alvarez', { social_fri: true, social_sat: true, mass_fri: true, holy_hour: true, bus: true, first_bsc: true }),
     who('Thomas', 'Alvarez', { social_fri: true, social_sat: true, bus: true }),
     who('Lucy', 'Alvarez', { child: true, sun_ten: false, social_sat: true, bus: true })],
    { org: 'St. Paul’s, Jacksonville Beach', why: 'Our whole family is walking for my mother.' });
  await make('full', 'rita.donnelly@example.com',
    [who('Rita', 'Donnelly', { social_fri: true, mass_fri: true, knight_dame: true })],
    { org: 'Order of Malta', state: 'GA', city: 'Savannah', why: 'I have walked every year since it began.' });
  await make('bambino', 'g.whitfield@example.com',
    [who('Grace', 'Whitfield', { fri: false, sat: false, social_sat: true }),
     who('Ellis', 'Whitfield', { fri: false, sat: false, child: true })],
    { org: '', why: 'The last stretch with the little ones.' });
  const okafor = await make('full', 'daniel.okafor@example.com', [who('Daniel', 'Okafor', { bus: true, first_bsc: true })],
    { stop: 'payment', state: 'NC', city: 'Charlotte', why: 'A friend told me about the walk.' });
  const brennan = await make('full', 'brennan.family@example.com', [who('Peter', 'Brennan'), who('Anne', 'Brennan')],
    { stop: 'waiver', why: 'For our fortieth anniversary.' });
  await post('/draft', { track: 'full', contact: { email: 'j.costa@example.com', phone: '904-555-0190' }, people: [] });
  await sleep(1500);

  const puppeteer = (await import(PUPPETEER)).default;
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const shot = async (page, file, opts = {}) => {
    await page.screenshot({ path: `${OUT}/${file}.png`, ...opts });
    console.log('  shot ' + file);
  };
  const open = async (w, h, scale) => {
    const p = await browser.newPage();
    await p.setViewport({ width: w, height: h, deviceScaleFactor: scale || 2 });
    await p.setCookie({ name: cn, value: cr.join('='), domain: new URL(BASE).hostname, path: '/' });
    return p;
  };
  const name = async (p) => {
    await p.evaluate(() => { try { localStorage.setItem('register.actor', 'Susan'); } catch (e) {} });
  };

  try {
    // ---- the backoffice, desktop ----
    const p = await open(1180, 900);
    await p.goto(BASE + '/apps/register/admin#roster', { waitUntil: 'networkidle2' });
    await p.waitForSelector('table tbody tr', { timeout: 60000 });
    await shot(p, 'roster', { clip: { x: 0, y: 0, width: 1180, height: 700 } });

    // the name prompt, as a first-time organizer meets it
    const q = await open(1180, 500);
    await q.goto(BASE + '/apps/register/admin#roster', { waitUntil: 'networkidle2' });
    await q.waitForSelector('#actor', { timeout: 60000 });
    await q.click('#actor');
    await sleep(500);
    await shot(q, 'name-prompt', { clip: { x: 0, y: 0, width: 1180, height: 250 } });
    await q.close();

    // Today, wide: the table needs the room
    await name(p);
    await p.goto(BASE + '/apps/register/admin#day/fri', { waitUntil: 'networkidle2' });
    await p.waitForSelector('.count', { timeout: 60000 });
    await shot(p, 'today', { clip: { x: 0, y: 0, width: 1180, height: 780 } });
    await p.close();

    // the rest at a narrower width, where the two-column layouts stack
    // and every word is big enough to read on a printed page
    const w = await open(820, 1000);
    await name(w);
    await w.goto(BASE + '/apps/register/admin#reg/' + alvarez.rid, { waitUntil: 'networkidle2' });
    await w.waitForSelector('[data-act="save"]', { timeout: 60000 });
    await shot(w, 'registration', { clip: { x: 0, y: 0, width: 820, height: 900 } });

    await w.goto(BASE + '/apps/register/admin#reports', { waitUntil: 'networkidle2' });
    await w.waitForSelector('.grid3', { timeout: 60000 });
    await shot(w, 'reports', { clip: { x: 0, y: 0, width: 820, height: 900 } });

    await w.goto(BASE + '/apps/register/admin#settings', { waitUntil: 'networkidle2' });
    await w.waitForSelector('[data-act="save-settings"]', { timeout: 60000 });
    await shot(w, 'settings', { clip: { x: 0, y: 0, width: 820, height: 900 } });

    await w.goto(BASE + '/apps/register/admin#emails', { waitUntil: 'networkidle2' });
    await w.waitForSelector('.card.mail', { timeout: 60000 });
    await shot(w, 'emails', { clip: { x: 0, y: 0, width: 820, height: 820 } });

    await w.goto(BASE + '/apps/register/admin#backup', { waitUntil: 'networkidle2' });
    await w.waitForSelector('[data-act="inspect"]', { timeout: 60000 });
    await shot(w, 'backup', { clip: { x: 0, y: 0, width: 820, height: 760 } });

    await w.goto(BASE + '/apps/register/admin#add', { waitUntil: 'networkidle2' });
    await w.waitForSelector('[data-act="submit-add"]', { timeout: 60000 });
    await w.evaluate(() => { const h = [...document.querySelectorAll('.card h3')].find((x) => x.textContent.trim() === 'What you took from them'); if (h) h.closest('.card').scrollIntoView({ block: 'center' }); });
    await sleep(300);
    await w.goto(BASE + '/apps/register/admin#add', { waitUntil: 'networkidle2' });
    await w.waitForSelector('[data-act="submit-add"]', { timeout: 60000 });
    await shot(w, 'add', { clip: { x: 0, y: 0, width: 820, height: 760 } });
    await w.close();

    // ---- the phone screens ----
    const m = await open(414, 860);
    await name(m);
    await m.goto(BASE + '/apps/register/checkin', { waitUntil: 'networkidle2' });
    await m.waitForSelector('#view', { timeout: 60000 });
    await sleep(2500);
    await shot(m, 'checkin-app', { fullPage: false });

    // the pilgrim's own link, on the day
    settings.event.days = [day(0), day(1), day(2)];
    await put('/admin/settings', settings);
    await sleep(1800);
    await m.goto(BASE + `/apps/register/#checkin/${alvarez.rid}/${alvarez.token}`, { waitUntil: 'networkidle2' });
    await m.reload({ waitUntil: 'networkidle2' });
    await m.waitForSelector('input[data-here]', { timeout: 60000 });
    await shot(m, 'pilgrim-checkin', { clip: { x: 0, y: 0, width: 414, height: 620 } });
    settings.event = wasEvent;
    await put('/admin/settings', settings);
    await sleep(1500);

    await m.goto(BASE + '/apps/register/', { waitUntil: 'networkidle2' });
    await m.waitForSelector('.doors, .card.soft', { timeout: 60000 });
    await shot(m, 'pilgrim-landing', { clip: { x: 0, y: 0, width: 414, height: 800 } });
    await m.close();

    // ---- the two steps a pilgrim takes on their own ----
    // Wide enough that the words are legible on paper; these are the
    // screens the organizers get asked about on the telephone.
    const s2 = await open(820, 1000);
    await s2.goto(BASE + `/apps/register/#next/${brennan.rid}/${brennan.token}`, { waitUntil: 'networkidle2' });
    await s2.waitForSelector('[data-act="waiver-open"]', { timeout: 60000 });
    await sleep(600);
    await shot(s2, 'pilgrim-waiver', { clip: { x: 0, y: 0, width: 820, height: 480 } });

    // The dialog itself, as an element: a page clip of it is mostly the
    // greyed-out page behind, and too tall to sit on a printed page.
    await s2.click('[data-act="waiver-open"]');
    await s2.waitForSelector('#waiver-terms', { timeout: 60000 });
    await sleep(700);
    const modal = async (file) => {
      const el = await s2.$('.modal');
      await el.screenshot({ path: `${OUT}/${file}.png` });
      console.log('  shot ' + file);
    };
    await modal('pilgrim-terms');
    // read to the end and tick: the close-up is the footer alone, which
    // is the part of the dialog that changes
    await s2.evaluate(() => { const t = document.getElementById('waiver-terms'); t.scrollTop = t.scrollHeight; });
    await sleep(600);
    await s2.evaluate(() => {
      const b = document.getElementById('waiver-agree');
      b.checked = true; b.dispatchEvent(new Event('change', { bubbles: true }));
      // wrap the footer so it can be shot on its own
      const m = document.querySelector('.modal');
      const box = document.createElement('div');
      box.id = 'shot-footer';
      box.style.padding = '4px 0';
      m.appendChild(box);
      box.appendChild(m.querySelector('label.check'));
      box.appendChild(document.getElementById('waiver-note'));
      box.appendChild(m.querySelector('.actions'));
    });
    await sleep(400);
    const foot = await s2.$('#shot-footer');
    await foot.screenshot({ path: `${OUT}/pilgrim-terms-agreed.png` });
    console.log('  shot pilgrim-terms-agreed');

    // the amount the pilgrim chooses
    await s2.goto(BASE + `/apps/register/#next/${okafor.rid}/${okafor.token}`, { waitUntil: 'networkidle2' });
    await s2.waitForSelector('[data-act="pay"]', { timeout: 60000 });
    await sleep(600);
    await shot(s2, 'pilgrim-payment', { clip: { x: 0, y: 0, width: 820, height: 620 } });
    await s2.close();
  } finally {
    await browser.close();
    for (const [rid, tok] of made) await post(`/reg/${rid}/cancel?t=${tok}`, {});
    console.log('sample parties cancelled: ' + made.length);
  }
}
main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
