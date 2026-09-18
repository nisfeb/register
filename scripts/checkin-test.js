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

console.log('ALL OK (' + n + ' checks)');
