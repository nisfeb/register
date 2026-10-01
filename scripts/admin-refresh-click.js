// The backoffice refreshes itself every minute. This checks that it
// does so without moving the page under whoever is reading it: the
// scroll position survives, the view is not rewritten when the ship has
// nothing new to say, and no Loading panel is painted over a page that
// already has rows on it. Then a registration arrives and the same
// position survives the repaint that shows it.
//
// Run: node scripts/admin-refresh-click.js
//
// The page's own timer is 60 seconds, which would make this test three
// minutes long, so the test shortens that one timer before the page
// loads. Nothing else is patched: the code under test is the shipped
// code. It drives a real ship and writes one registration, which it
// cancels again, so run it against a test ship. It needs the owner
// cookie at ~/.config/lattice-fs/cookie (or REG_COOKIE) and chromium
// with puppeteer-core. The gate does not call it: it is run by hand.
'use strict';
const { readFileSync } = require('fs');
const { homedir } = require('os');

const BASE = process.env.REG_BASE || 'http://localhost:8080';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';
const TICK = 1500;   // what the page's minute timer is shortened to

let fails = 0;
const check = (m, c, d) => {
  console.log((c ? '  ok   ' : '  FAIL ') + m + (c || !d ? '' : '   ' + String(d).slice(0, 180)));
  if (!c) fails++;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const cookie = readFileSync(process.env.REG_COOKIE || homedir() + '/.config/lattice-fs/cookie', 'utf8').trim();
  const [cn, ...cr] = cookie.split('=');
  const hdr = { 'content-type': 'application/json', cookie: cookie };
  const api = (path, body, actor) =>
    fetch(BASE + '/apps/register/api' + path, {
      method: 'POST', headers: actor ? Object.assign({ 'x-actor': actor }, hdr) : hdr, body: JSON.stringify(body)
    }).then((r) => r.json());

  const puppeteer = require(PUPPETEER);
  const browser = await puppeteer.launch({ executablePath: CHROME, args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1100, height: 800 });
    await page.setCookie({ name: cn, value: cr.join('='), domain: new URL(BASE).hostname });
    // the one timer the page sets for a minute becomes a second and a
    // half, so this test is seconds rather than minutes
    await page.evaluateOnNewDocument((tick) => {
      const real = window.setInterval;
      window.setInterval = function (fn, ms) { return real(fn, ms === 60000 ? tick : ms); };
    }, TICK);
    // not networkidle: the shortened timer keeps the page talking to the
    // ship, so the network is never idle and the wait would never end
    await page.goto(BASE + '/apps/register/admin', { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('#view table tbody tr', { timeout: 20000 });
    await sleep(1200);

    // the default segment is the active rows. A test ship's are mostly
    // drafts, so show everything: the page has to be taller than the
    // window before scrolling it means anything.
    await page.select('#f-seg', 'all');
    await sleep(2000);
    const rows = await page.evaluate(() => document.querySelectorAll('#view table tbody tr').length);
    check('there are rows enough to scroll', rows > 20, rows);

    // every rewrite of the view from here on is counted
    await page.evaluate(() => {
      window.__writes = 0;
      new MutationObserver((ms) => {
        ms.forEach((m) => { if (m.type === 'childList') window.__writes++; });
      }).observe(document.getElementById('view'), { childList: true });
    });

    await page.evaluate(() => window.scrollTo(0, 1200));
    await sleep(300);
    const was = await page.evaluate(() => window.scrollY);
    check('the roster scrolls', was > 800, was);

    // several ticks pass with nothing new on the ship
    await sleep(TICK * 4);
    check('the refresh left the scroll where it was',
          (await page.evaluate(() => window.scrollY)) === was, was);
    check('and never rewrote the view, because nothing had changed',
          (await page.evaluate(() => window.__writes)) === 0,
          (await page.evaluate(() => window.__writes)) + ' rewrites');
    check('no Loading panel was painted over it',
          !(await page.evaluate(() => /class="loading"/.test(document.getElementById('view').innerHTML))));
    check('the roster is still on screen', (await page.$('#view table tbody tr')) !== null);

    // now the list changes under them
    const add = await api('/submit', {
      track: 'full', org: 'Order of Malta', why: 'refresh click-through',
      assistance: false, together: false,
      contact: { email: 'refresh-' + Date.now() + '@example.com', phone: '904-555-0100',
                 street: '1 Beach Rd', city: 'Jacksonville Beach', state: 'FL', zip: '32250' },
      people: [{ first: 'Scro', last: 'Ller', child: false,
                 days: { fri: true, sat: true, sun: true }, sun_ten: true,
                 social_fri: false, social_sat: false, mass_fri: false, mass_sat: false,
                 mass_sun: true, holy_hour: false, bus: false, trolley: false,
                 first_bsc: true, knight_dame: false, volunteer: false }]
    });
    check('the new registration was taken', !!add.rid, JSON.stringify(add).slice(0, 120));
    await sleep(TICK * 3);
    check('the list that changed was repainted', (await page.evaluate(() => window.__writes)) > 0);
    check('and the organizer kept their place through it',
          Math.abs((await page.evaluate(() => window.scrollY)) - was) < 40,
          was + ' -> ' + (await page.evaluate(() => window.scrollY)));
    check('the new row is on the page',
          await page.evaluate(() => /Ller/.test(document.getElementById('view').innerHTML)));
    if (add.rid) {
      await api('/admin/reg/' + add.rid, { op: 'cancel', note: 'refresh click-through cleanup' }, 'admin:click');
      check('the registration it made is cancelled again', true);
    }

    // a move to another view starts at that view's top, which the page
    // now has to ask for: it used to happen by accident
    await page.evaluate(() => { location.hash = '#reports'; });
    await sleep(2500);
    check('a different view starts at the top',
          (await page.evaluate(() => window.scrollY)) < 40,
          await page.evaluate(() => window.scrollY));
  } finally {
    await browser.close();
  }
  console.log(fails ? 'FAILED: ' + fails : 'ALL OK');
  process.exit(fails ? 1 : 0);
}

main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
