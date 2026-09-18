// A headless click-through of the pilgrim's form: a party of two, the
// second person's weekend following the first and then going its own
// way, a day group that opens and closes with its day, the venue link
// in the copy, the fee box naming both people, and a submit that lands
// on the waiver step naming them both.
//
// Run: node scripts/public-form-click.js
//
// It drives a real ship and writes one registration, so run it against
// a test ship. It cancels the registration it made before it ends, so
// the spots go back. It needs chromium with puppeteer-core. The gate
// does not call it: it is run by hand.
'use strict';

const BASE = 'http://localhost:8080';
const PAGE = BASE + '/apps/register/';
const API = BASE + '/apps/register/api';
const CHROME = '/usr/bin/chromium';
const PUPPETEER = '/home/sneagan/software/personal/lattice/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js';

let fails = 0;
const check = (m, c, d) => {
  console.log((c ? '  ok   ' : '  FAIL ') + m + (c || !d ? '' : '   ' + String(d).slice(0, 220)));
  if (!c) fails++;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const puppeteer = (await import(PUPPETEER)).default;
  const st = await (await fetch(API + '/status')).json();
  check('the registration window is open on this ship', st.open === true, st.open);
  check('the full track has room, so the form offers the waiver',
    st.counts.full < st.caps.full, st.counts.full + ' of ' + st.caps.full);
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const p = await browser.newPage();
  p.on('pageerror', (e) => { console.log('  PAGE ERROR ' + e.message); fails++; });
  const text = (sel) => p.$eval(sel, (n) => n.textContent.trim()).catch(() => null);
  const seen = (sel) => p.$(sel).then((n) => !!n);
  const type = async (sel, s) => { await p.click(sel); await p.type(sel, s); await sleep(150); };

  await p.goto(PAGE + '#form/full', { waitUntil: 'networkidle2' });
  await p.waitForSelector('.card.person', { timeout: 20000 });

  // ---- the first person, and the day rows that carry the facts ----
  await type('[data-k="people.0.first"]', 'Ana');
  await type('[data-k="people.0.last"]', 'Silva');
  check('the card is headed by the name that was typed',
    (await text('.card.person h2')) === 'Ana Silva', await text('.card.person h2'));
  check('the weekend section is headed by the name too',
    (await text('[data-who="weekend"][data-i="0"]')) === "Ana Silva's weekend",
    await text('[data-who="weekend"][data-i="0"]'));
  check('Friday\'s events are closed until Friday is checked',
    await seen('.group .closed'), 'no note');
  await p.click('[data-k="people.0.days.fri"]');
  await p.waitForSelector('[data-k="people.0.mass_fri"]', { timeout: 10000 });
  check('checking Friday opens Friday\'s events',
    await seen('[data-k="people.0.social_fri"]'));
  const ajua = await p.$eval('.card.person a[href]', (n) => ({
    href: n.getAttribute('href'), tab: n.getAttribute('target'), rel: n.getAttribute('rel'), text: n.textContent
  })).catch(() => null);
  check('the social row carries the venue as a link that opens a new tab',
    !!ajua && ajua.href === 'https://ajuajax.com/' && ajua.tab === '_blank' &&
    /noopener/.test(ajua.rel || ''), JSON.stringify(ajua));
  check('the day that was ticked keeps the keyboard after the form redraws',
    (await p.evaluate(() => (document.activeElement || {}).getAttribute
      ? document.activeElement.getAttribute('data-k') : null)) === 'people.0.days.fri',
    await p.evaluate(() => (document.activeElement || {}).getAttribute
      ? document.activeElement.getAttribute('data-k') : null));
  await p.click('[data-k="people.0.days.sun"]');
  await p.waitForSelector('[data-k="people.0.sun_ten"]', { timeout: 10000 });
  check('checking Sunday asks which Sunday walk it is',
    (await p.$$('[data-k="people.0.sun_ten"]')).length === 2,
    (await p.$$('[data-k="people.0.sun_ten"]')).length);
  check('and the full Camino starts on the 10 miles, not the short walk',
    (await p.$eval('[data-k="people.0.sun_ten"][value="1"]', (n) => n.checked)) === true);

  // ---- a second person, following the first ----
  await p.click('[data-act="add"]');
  await p.waitForSelector('[data-k="same.1"]', { timeout: 10000 });
  check('a person added to the party follows the first by default',
    (await p.$eval('[data-k="same.1"][value="same"]', (n) => n.checked)) === true);
  const sum = () => text('[data-who="summary"][data-i="1"]');
  check('and the first person\'s weekend is written out under the radio',
    /Walking Friday and Sunday/.test(await sum()), await sum());
  check('a person following shows no choices of their own',
    (await p.$$('[data-k^="people.1.days"]')).length === 0);
  // Remove is a quiet text link in the card's corner, not a bordered
  // button under the name that reads as the thing to press next
  const gone = await p.$eval('[data-act="remove"][data-i="1"]', (n) => {
    const s = getComputedStyle(n);
    const card = n.closest('.card.person').getBoundingClientRect();
    const box = n.getBoundingClientRect();
    return { cls: n.className, border: s.borderTopWidth, pos: s.position,
      right: Math.round(card.right - box.right), top: Math.round(box.top - card.top) };
  });
  check('the Remove link is unbordered and sits in the card\'s top corner',
    !/\bbtn\b/.test(gone.cls) && gone.border === '0px' && gone.pos === 'absolute' &&
    gone.right < 30 && gone.top < 40, JSON.stringify(gone));
  await p.click('[data-k="people.0.days.sat"]');
  await sleep(300);
  check('the summary follows the first person\'s choices as they change',
    /Walking Friday, Saturday and Sunday/.test(await sum()), await sum());
  await p.click('[data-k="people.0.social_fri"]');
  await sleep(300);
  check('and it says the social by name once it is chosen',
    /Social at Ajua/.test(await sum()), await sum());

  // ---- and then going their own way ----
  await p.click('[data-k="same.1"][value="own"]');
  await p.waitForSelector('[data-k="people.1.days.fri"]', { timeout: 10000 });
  check('a different weekend opens their own groups',
    (await p.$$('[data-k^="people.1.days"]')).length === 3);
  check('and the radio that was picked keeps the keyboard',
    (await p.evaluate(() => {
      const el = document.activeElement || {};
      return el.getAttribute ? el.getAttribute('data-k') + '=' + el.value : null;
    })) === 'same.1=own',
    await p.evaluate(() => {
      const el = document.activeElement || {};
      return el.getAttribute ? el.getAttribute('data-k') + '=' + el.value : null;
    }));
  check('and it starts from what they were copying',
    (await p.$eval('[data-k="people.1.days.fri"]', (n) => n.checked)) === true &&
    (await p.$eval('[data-k="people.1.social_fri"]', (n) => n.checked)) === true);
  await p.click('[data-k="people.1.days.fri"]');
  await sleep(300);
  check('unchecking their Friday closes their Friday events',
    (await p.$$('[data-k="people.1.social_fri"]')).length === 0);
  check('and the first person keeps theirs',
    (await p.$eval('[data-k="people.0.social_fri"]', (n) => n.checked)) === true);

  // ---- the fee box names everybody ----
  await type('[data-k="people.1.first"]', 'Bo');
  await type('[data-k="people.1.last"]', 'Silva');
  await p.click('[data-k="people.1.child"]');
  await sleep(300);
  const fees = await text('.fees');
  check('the fee box has one line per person, by name',
    /Ana Silva/.test(fees) && /Bo Silva/.test(fees), fees);
  check('and it says what each of them is paying for',
    /full Camino/.test(fees) && /under 18/.test(fees), fees);
  check('the button offers the waiver while there is room',
    (await text('[data-act="submit"]')) === String(st.copy['form.submit']),
    await text('[data-act="submit"]'));

  // ---- submit ----
  const mail = 'form-click+' + Date.now() + '@example.com';
  await type('[data-k="contact.email"]', mail);
  await type('[data-k="contact.phone"]', '904 555 0143');
  await type('[data-k="contact.street"]', '1 Beach Road');
  await type('[data-k="contact.city"]', 'Jacksonville');
  await type('[data-k="contact.state"]', 'FL');
  await type('[data-k="contact.zip"]', '32250');
  await p.click('[data-act="submit"]');
  await p.waitForSelector('[data-act="sign"]', { timeout: 25000 })
    .catch(async () => { console.log('  the page said: ' + await text('#error')); throw new Error('no waiver step'); });
  const body = await text('#view p');
  check('the waiver step names everybody the signature covers',
    /Ana Silva and Bo Silva/.test(body), body);
  const hash = await p.evaluate(() => location.hash);
  check('and the page is on the registration it just made', /^#next\//.test(hash), hash);
  await browser.close();

  // ---- put the spots back ----
  const parts = hash.replace('#next/', '').split('/');
  const res = await fetch(API + '/reg/' + parts[0] + '/cancel?t=' + encodeURIComponent(parts[1]),
    { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' });
  check('the registration it made is cancelled again', res.ok, res.status);
  console.log(fails ? fails + ' FAILED' : 'ALL OK');
  process.exit(fails ? 1 : 0);
}

main().catch((e) => { console.log('CRASHED ' + e.message); process.exit(1); });
