#!/usr/bin/env node
// The check-in app's pure helpers against fixtures: the queue, the
// drain, the roster merge, the wristband text and the day default. The
// page exports them when module.exports exists and runs nothing without
// a document, the way orrery's page does. Run: node
// scripts/checkin-test.js. Exits 1 on the first failed assertion.
'use strict';
const assert = require('assert');
const path = require('path');

// the shims the page would find in a browser. The app half never runs
// here (it returns as soon as it sees no document), so these only prove
// that loading the file touches nothing it should not.
const store = {};
global.localStorage = {
  getItem: (k) => (k in store ? store[k] : null),
  setItem: (k, v) => { store[k] = String(v); },
  removeItem: (k) => { delete store[k]; },
};
global.fetch = () => Promise.reject(new Error('the node test makes no requests'));

const page = require(path.join(__dirname, '..', 'code', 'nex', 'register', 'checkin.js'));
const worker = require(path.join(__dirname, '..', 'code', 'nex', 'register', 'sw.js'));
// the other two pages export their pure halves the same way: the
// public page's rule about placeholders, and the backoffice's
// optimistic patch
const pub = require(path.join(__dirname, '..', 'code', 'nex', 'register', 'public.js'));
const back = require(path.join(__dirname, '..', 'code', 'nex', 'register', 'admin.js'));

let n = 0;
function ok(label, cond) { n += 1; assert.ok(cond, label); console.log('  ok   ' + label); }

// ---- the day the app opens on ----
const days = ['2026-12-04', '2026-12-05', '2026-12-06'];
ok('today is the event day it is', page.dayFor(days, '2026-12-05') === 'sat');
ok('the first day is Friday and the last is Sunday',
  page.dayFor(days, '2026-12-04') === 'fri' && page.dayFor(days, '2026-12-06') === 'sun');
ok('a day outside the event opens on Friday', page.dayFor(days, '2026-11-30') === 'fri');
ok('no days at all still opens on Friday', page.dayFor(undefined, '2026-12-05') === 'fri');
// eight in the evening on the Friday: UTC has rolled over to Saturday
// and the local date has not
ok('the day is read off the local clock, not UTC',
  page.localDay(new Date(2026, 11, 4, 20, 0, 0)) === '2026-12-04');
ok('a one digit month and day are padded',
  page.localDay(new Date(2026, 0, 5, 9, 0, 0)) === '2026-01-05');
ok('at 8pm local on the Friday the app opens on Friday',
  page.openDay(days, page.localDay(new Date(2026, 11, 4, 20, 0, 0)), null) === 'fri');
ok('a day picked by hand today outranks the event day',
  page.openDay(days, '2026-12-05', { day: 'fri', on: '2026-12-05' }) === 'fri');
ok('yesterday\'s pick does not outrank today\'s event day',
  page.openDay(days, '2026-12-05', { day: 'fri', on: '2026-12-04' }) === 'sat');
ok('the pick the old page stored as a bare string is ignored',
  page.openDay(days, '2026-12-05', 'sun') === 'sat');

// ---- the wristband answer ----
ok('a green band says wristband', page.bandText({ ok: true, why: '' }) === 'Wristband');
[['unpaid', 'No wristband: unpaid'],
['awaiting assistance decision', 'No wristband: awaiting assistance decision'],
['waiver not signed', 'No wristband: waiver not signed'],
['on the wait list', 'No wristband: on the wait list'],
['cancelled', 'No wristband: cancelled'],
['draft', 'No wristband: draft'],
['not registered', 'No wristband: not registered']].forEach(function (pair) {
  ok('a red band says "' + pair[0] + '"', page.bandText({ ok: false, why: pair[0] }) === pair[1]);
});
ok('a band with no reason still reads', page.bandText(null) === 'No wristband: not registered');

// ---- the queue ----
let queue = [];
queue = page.queueAdd(queue, { rid: 'aaa', i: 0, day: 'fri', undo: false, at: '1' });
queue = page.queueAdd(queue, { rid: 'aaa', i: 1, day: 'fri', undo: false, at: '2' });
ok('a tap is appended', queue.length === 2 && queue[1].i === 1);
queue = page.queueAdd(queue, { rid: 'aaa', i: 0, day: 'sat', undo: false, at: '3' });
ok('the same person on another day is its own item', queue.length === 3);
queue = page.queueAdd(queue, { rid: 'aaa', i: 0, day: 'fri', undo: true, at: '4' });
ok('a tap and its undo collapse into the later one',
  queue.length === 3 && queue[queue.length - 1].undo === true && queue[queue.length - 1].at === '4');
ok('every item is waiting while none is rejected', page.waiting(queue) === 3);

// ---- the drain ----
const batch = [
  { rid: 'aaa', i: 0, day: 'fri', undo: false },
  { rid: 'bbb', i: 0, day: 'fri', undo: false },
  { rid: 'ccc', i: 2, day: 'fri', undo: false },
];
let left = page.drained(batch, { applied: 2, rejected: [{ rid: 'ccc', i: 2, why: 'no such person' }] });
ok('the applied items leave the queue', left.length === 1 && left[0].rid === 'ccc');
ok('the rejected one keeps its reason', left[0].why === 'no such person');
ok('a rejected item no longer counts as waiting', page.waiting(left) === 0);
ok('an answer with nothing rejected empties the queue',
  page.drained(batch, { applied: 3, rejected: [] }).length === 0);
ok('an answer with no rejected list at all empties the queue',
  page.drained(batch, { applied: 3 }).length === 0);
// the ship's writer refusing a poke is the ship's trouble: the tap
// waits and goes up again. A refusal that names the row is parked.
let held = page.drained(batch, { applied: 2, rejected: [{ rid: 'ccc', i: 2, why: page.RETRY }] });
ok('a tap the writer would not take stays in the queue',
  held.length === 1 && held[0].rid === 'ccc' && !held[0].why);
ok('and it is waiting again, so the next drain retries it', page.waiting(held) === 1);
[['no such registration', 1], ['no such person', 1], ['bad index', 1]].forEach(function (pair) {
  const parked = page.drained(batch, { applied: 2, rejected: [{ rid: 'ccc', i: 2, why: pair[0] }] });
  ok('"' + pair[0] + '" parks the tap with its reason shown',
    parked.length === pair[1] && parked[0].why === pair[0] && page.waiting(parked) === 0);
});

// ---- the roster merge ----
function rows() {
  return [
    {
      rid: 'aaa', status: 'complete', wristband: { ok: true, why: '' },
      people: [
        { i: 0, first: 'Ana', last: 'Silva', walks: true, checked: false, at: null, by: '' },
        { i: 1, first: 'Bo', last: 'Silva', walks: true, checked: true, at: '2026-12-04T13:00:00Z', by: 'admin:Sue' },
      ]
    },
    {
      rid: 'bbb', status: 'waitlist', wristband: { ok: false, why: 'on the wait list' },
      people: [{ i: 0, first: 'Cy', last: 'Abbot', walks: true, checked: false, at: null, by: '' }]
    },
  ];
}
let merged = page.mergeRoster(rows(), [], [
  { rid: 'aaa', i: 0, day: 'fri', undo: false, at: '2026-12-04T14:00:00Z', by: 'admin:Pat' },
  { rid: 'aaa', i: 1, day: 'fri', undo: true },
], 'fri');
ok('a queued tap paints the person checked in before the ship knows',
  merged[0].people[0].checked === true && merged[0].people[0].by === 'admin:Pat');
ok('a queued undo unpaints one the ship still has checked in',
  merged[0].people[1].checked === false && !merged[0].people[1].at);
merged = page.mergeRoster(rows(), [], [{ rid: 'aaa', i: 0, day: 'sat', undo: false, at: 'x' }], 'fri');
ok('a tap for another day is left alone', merged[0].people[0].checked === false);
merged = page.mergeRoster(rows(), [], [{ rid: 'zzz', i: 0, day: 'fri' }, { rid: 'aaa', i: 7, day: 'fri' }], 'fri');
ok('a tap for a party or a person the roster does not have is skipped',
  merged[0].people[0].checked === false && merged.length === 2);
merged = page.mergeRoster(rows(), [], [{ rid: 'bbb', i: 0, day: 'fri', why: 'no such registration' }], 'fri');
ok('a rejected tap shows its reason on the person', merged[1].people[0].why === 'no such registration');
// a tap the ship took seconds ago, then the volunteer taking it back:
// the undo is later, so it wins however fresh the tap is
const justTapped = [{ rid: 'aaa', i: 0, day: 'fri', undo: false, at: '2026-12-04T14:00:00Z', by: 'admin:Pat' }];
merged = page.mergeRoster(rows(), justTapped, [{ rid: 'aaa', i: 0, day: 'fri', undo: true }], 'fri');
ok('an undo beats the tap the ship has just taken', merged[0].people[0].checked === false);
merged = page.mergeRoster(rows(), justTapped, [], 'fri');
ok('with nothing queued the fresh tap still paints the tick',
  merged[0].people[0].checked === true && merged[0].people[0].by === 'admin:Pat');

// ---- the search ----
const list = rows();
ok('the search matches a last name', page.matches(list[0], 'silva') && !page.matches(list[1], 'silva'));
ok('the search matches a first name', page.matches(list[1], 'cy'));
ok('the search matches the rid', page.matches(list[0], 'aaa'));
ok('an empty search matches everything', page.matches(list[0], '') && page.matches(list[1], ''));

// ---- the day's tags and the counts grid ----
const p = { walks: true, bus: true, mass_fri: true, holy_hour: false, social: true, sun_ten: true, child: false };
ok('Friday tags the walk, the bus, Mass and the social',
  page.tags(p, 'fri').join(',') === 'walk,bus,Mass,social');
ok('Sunday tags the distance instead of the walk', page.tags(p, 'sun')[0] === '10 mi');
ok('the short Sunday walk says so',
  page.tags(Object.assign({}, p, { sun_ten: false }), 'sun')[0] === '2.5 mi');
ok('a person with nothing that day has no tags', page.tags({}, 'sat').length === 0);
ok('Friday counts Mass, the Holy Hour, the social and the bus',
  page.actsFor('fri').map(function (a) { return a[0]; }).join(',') === 'walk,mass,holy_hour,social,bus');
ok('Saturday counts the same five', page.actsFor('sat').length === 5);
ok('Sunday counts the two starts as well as the five',
  page.actsFor('sun').map(function (a) { return a[0]; }).join(',') ===
  'walk,mass,holy_hour,social,bus,sun_ten,sun_short');

// ---- the day's counts ----
const held_day = { walk: { count: 90, time: '7:00' }, mass: { count: 140 }, bus: { count: 20 } };
let mergedCounts = page.mergeCounts(held_day, { walk: { count: 91 } });
ok('a merge keeps the activities nobody touched',
  mergedCounts.mass.count === 140 && mergedCounts.bus.count === 20);
ok('and takes the figure that was typed', mergedCounts.walk.count === 91);
ok('and keeps the other fields of the activity that was typed', mergedCounts.walk.time === '7:00');
ok('the day the ship holds is not changed in place',
  held_day.walk.count === 90 && Object.keys(page.mergeCounts(held_day, {})).length === 3);
ok('an activity the ship has never had is added',
  page.mergeCounts(held_day, { social: { count: 3 } }).social.count === 3);
ok('a keystroke without Save queues nothing',
  page.countsToSend({ walk: { count: 91 } }, false) === null);
ok('Save queues the typed day', page.countsToSend({ walk: { count: 91 } }, true) !== null);
ok('Save with nothing typed queues nothing',
  page.countsToSend(null, true) === null && page.countsToSend({}, true) === null);

// ---- the sync badge ----
ok('nothing waiting reads synced', page.syncText(true, 0, '') === 'synced');
ok('taps waiting are counted', page.syncText(true, 3, '') === '3 waiting');
ok('offline with nothing waiting says so', page.syncText(false, 0, '') === 'offline');
ok('a failed drain shows why', page.syncText(true, 0, 'http 500') === 'http 500');
ok('a failed drain with taps waiting shows both',
  page.syncText(true, 2, 'http 500') === '2 waiting: http 500');
ok('offline never shows a drain error', page.syncText(false, 2, 'http 500') === '2 waiting');

// ---- what the service worker will keep ----
function answer(type, extra) {
  return Object.assign({ ok: true, redirected: false, type: 'basic',
    headers: { get: function () { return type; } } }, extra || {});
}
ok('the page is cached when it answers as html',
  worker.keepable('/apps/register/checkin', answer('text/html; charset=utf-8')) === true);
ok('the script and the style are cached under their own types',
  worker.keepable('/apps/register/checkin.js', answer('text/javascript')) === true &&
  worker.keepable('/apps/register/checkin.css', answer('text/css; charset=utf-8')) === true);
ok('the manifest and an icon are cached under theirs',
  worker.keepable('/apps/register/manifest.json', answer('application/manifest+json')) === true &&
  worker.keepable('/apps/register/icon-192.png', answer('image/png')) === true);
ok('a login page arriving after a redirect is never cached',
  worker.keepable('/apps/register/checkin', answer('text/html', { redirected: true })) === false);
ok('a login page arriving under the script path is never cached',
  worker.keepable('/apps/register/checkin.js', answer('text/html; charset=utf-8')) === false);
ok('an answer from somewhere else is never cached',
  worker.keepable('/apps/register/checkin', answer('text/html', { type: 'opaque' })) === false);
ok('a failed answer is never cached',
  worker.keepable('/apps/register/checkin', answer('text/html', { ok: false })) === false);
ok('a path outside the shell is never cached',
  worker.keepable('/apps/register/api/status', answer('application/json')) === false);
ok('the shell is the six files the worker knows the types of',
  worker.SHELL.length === 6 && worker.SHELL.every(function (u) { return !!worker.TYPES[u]; }));

// ---- what is written into a card ----
ok('esc handles the five characters', page.esc('<&>"\'') === '&lt;&amp;&gt;&quot;&#39;');
ok('esc takes nothing at all', page.esc(undefined) === '' && page.esc(null) === '');
ok('a time reads as a clock on this phone',
  /^([1-9]|1[0-2]):[0-5][0-9](am|pm)$/.test(page.clock('2026-12-04T13:05:00Z')));
ok('midnight reads as twelve', page.clock(new Date(2026, 11, 4, 0, 7).toISOString()) === '12:07am');
ok('noon reads as twelve too', page.clock(new Date(2026, 11, 4, 12, 30).toISOString()) === '12:30pm');
ok('no time at all reads as nothing', page.clock('') === '');

// ---- the public page: a string keeps the placeholders it had ----
ok('a placeholder the original had and the edit dropped is named',
  JSON.stringify(pub.missingVars('{{n}} x {{each}}', '5 x {{each}}')) === '["{{n}}"]');
ok('an edit that keeps every placeholder is allowed',
  pub.missingVars('{{percent}}% full', 'we are {{percent}} per cent full').length === 0);
ok('a placeholder written twice is named once',
  JSON.stringify(pub.missingVars('{{first}}, hello {{first}}', 'hello')) === '["{{first}}"]');
ok('a string that never had one is free to change',
  pub.missingVars('The full Camino', 'Il Cammino').length === 0);
ok('an edit may add a placeholder the original did not have',
  pub.missingVars('Pay now', 'Pay {{total}}').length === 0);
ok('a template lists each of its placeholders once',
  JSON.stringify(pub.varsOf('{{a}} {{b}} {{a}}')) === '["{{a}}","{{b}}"]');
ok('nothing at all holds no placeholders',
  pub.varsOf(undefined).length === 0 && pub.varsOf(null).length === 0);
ok('Enter makes a new line in prose and ends the edit anywhere else',
  pub.multiline('next.waiver.body') === true && pub.multiline('landing.intro') === true &&
  pub.multiline('manage.closed') === true && pub.multiline('stub.banner') === true &&
  pub.multiline('landing.title') === false && pub.multiline('manage.save') === false);
ok('the public page escapes the five characters too',
  pub.esc('<&>"\'') === '&lt;&amp;&gt;&quot;&#39;');

// ---- the backoffice: an action painted before the ship takes it ----
const AT = '2026-09-18T12:00:00Z';
const waitlisted = {
  id: 'abc0000001', status: 'waitlist', track: 'full', position: 4, exempt: false,
  contact: { email: 'ana@example.com', phone: '904', state: 'FL' }, org: 'Malta',
  people: [{ first: 'Ana', last: 'Silva', checkins: { fri: { at: AT, by: 'admin:Sarah' } } }],
  payment: { method: 'none', amount: 0, gift: 0, refunded: false },
  waiver: { method: 'none', status: 'none' }, history: [{ at: AT, by: 'pilgrim', what: 'registered' }],
};
const promoted = back.patchReg(waitlisted, { op: 'promote' }, 'admin:Sarah', AT);
ok('a promotion paints the waiver step and drops the wait list number',
  promoted.status === 'waiver' && promoted.position === 0);
ok('it stamps a history line with the organizer and the time',
  promoted.history.length === 2 && promoted.history[1].by === 'admin:Sarah' &&
  promoted.history[1].at === AT && /promoted/.test(promoted.history[1].what));
ok('what was painted is marked as not yet confirmed', promoted.pending === true);
ok('the registration it was made from is untouched, so a refusal rolls back',
  waitlisted.status === 'waitlist' && waitlisted.position === 4 && waitlisted.history.length === 1);
const paid = back.patchReg(promoted, { op: 'pay', method: 'check', amount: 7500, gift: 500, ref: '19', note: '' }, 'admin:Sarah', AT);
ok('a payment paints complete with the method, the amount and the gift',
  paid.status === 'complete' && paid.payment.method === 'check' &&
  paid.payment.amount === 7500 && paid.payment.gift === 500);
const papered = back.patchReg(paid, { op: 'waiver-paper' }, 'admin:Sarah', AT);
ok('a paper waiver is completed and leaves the status alone',
  papered.waiver.status === 'completed' && papered.waiver.method === 'paper' && papered.status === 'complete');
const refunded = back.patchReg(papered, { op: 'refund', note: 'x' }, 'admin:Sarah', AT);
ok('a refund marks the payment and keeps its method', refunded.payment.refunded === true && refunded.payment.method === 'check');
const cancelled = back.patchReg(refunded, { op: 'cancel', note: '' }, 'admin:Sarah', AT);
ok('a cancellation remembers what it was', cancelled.status === 'cancelled' && cancelled.prior === 'complete');
ok('a reinstatement puts it back', back.patchReg(cancelled, { op: 'reinstate' }, 'admin:Sarah', AT).status === 'complete');
ok('an exemption is taken and given back',
  back.patchReg(waitlisted, { op: 'exempt', on: true }, 'a', AT).exempt === true &&
  back.patchReg(waitlisted, { op: 'exempt', on: false }, 'a', AT).exempt === false);
ok('assistance approved completes and declined asks for payment',
  back.patchReg(waitlisted, { op: 'assist', approve: true }, 'a', AT).status === 'complete' &&
  back.patchReg(waitlisted, { op: 'assist', approve: false }, 'a', AT).status === 'payment');
ok('a note is painted as typed', back.patchReg(waitlisted, { op: 'note', notes: 'called her' }, 'a', AT).notes === 'called her');
const edited = back.patchReg(waitlisted, {
  op: 'edit',
  input: { track: 'bambino', contact: { email: 'bo@example.com', phone: '1', state: 'GA' }, org: 'None', why: '', people: [{ first: 'Bo', last: 'Silva' }] },
}, 'a', AT);
ok('an edit paints the new party and keeps the check-ins that position had',
  edited.people[0].first === 'Bo' && edited.people[0].checkins.fri.by === 'admin:Sarah' && edited.track === 'bambino');
ok('an op the page does not know paints nothing', back.patchReg(waitlisted, { op: 'nonsense' }, 'a', AT) === null);

const row = { id: 'abc0000001', status: 'waitlist', position: 4, paid: 'none', amount: 0, gift: 0,
  refunded: false, waiver: 'none', exempt: false, assistance: false, track: 'full',
  email: 'ana@example.com', org: 'Malta', state: 'FL', people: 1, names: ['Silva, Ana'], walkers: 1 };
const patched = back.patchRow(row, paid);
ok('the roster row takes the new status, payment and waiver',
  patched.status === 'complete' && patched.paid === 'check' && patched.amount === 7500 && patched.position === 0);
ok('the row keeps what only the row holds', patched.walkers === 1);
ok('the row is marked as not yet confirmed too', patched.pending === true);
ok('the row it was made from is untouched, so a refusal rolls back',
  row.status === 'waitlist' && row.paid === 'none' && row.position === 4);
ok('a wait listed row keeps its number', back.patchRow(row, back.patchReg(waitlisted, { op: 'note', notes: 'x' }, 'a', AT)).position === 4);

ok('the pending mark stays while the ship still shows the old copy',
  back.settled(waitlisted, { op: 'promote' }) === false);
ok('and clears once the ship shows the change',
  back.settled({ status: 'waiver' }, { op: 'promote' }) === true);
ok('a payment is settled by its method',
  back.settled({ payment: { method: 'check' } }, { op: 'pay', method: 'check' }) === true &&
  back.settled({ payment: { method: 'none' } }, { op: 'pay', method: 'check' }) === false);
ok('an exemption is settled by the flag it set',
  back.settled({ exempt: true }, { op: 'exempt', on: true }) === true &&
  back.settled({ exempt: false }, { op: 'exempt', on: true }) === false);
ok('a resend has nothing to wait for', back.settled({}, { op: 'resend', template: 'reminder' }) === true);
ok('nothing at all is never settled', back.settled(null, { op: 'cancel' }) === false);

ok('the email templates are found by their subject and body keys',
  JSON.stringify(back.mailGroups({ 'email.reminder.subject': 'a', 'email.reminder.body': 'b', 'landing.title': 'c' })) ===
  '{"reminder":{"subject":"email.reminder.subject","body":"email.reminder.body"}}');
ok('a copy document with no emails makes no groups', Object.keys(back.mailGroups({ 'landing.title': 'a' })).length === 0);
ok('a dropped placeholder is refused in an email too',
  back.missingVars('Hello {{first}}, see {{link}}', 'Hello {{first}}').length === 1);
ok('the age of a kept roster reads in words',
  back.ageText(1000, 1000) === 'a moment old' && back.ageText(0, 60000) === '1 minute old' &&
  back.ageText(0, 300000) === '5 minutes old' && back.ageText(0, 7200000) === '2 hours old');

console.log('ALL OK (' + n + ' checks)');
