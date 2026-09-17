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

let n = 0;
function ok(label, cond) { n += 1; assert.ok(cond, label); console.log('  ok   ' + label); }

// ---- the day the app opens on ----
const days = ['2026-12-04', '2026-12-05', '2026-12-06'];
ok('today is the event day it is', page.dayFor(days, '2026-12-05') === 'sat');
ok('the first day is Friday and the last is Sunday',
  page.dayFor(days, '2026-12-04') === 'fri' && page.dayFor(days, '2026-12-06') === 'sun');
ok('a day outside the event opens on Friday', page.dayFor(days, '2026-11-30') === 'fri');
ok('no days at all still opens on Friday', page.dayFor(undefined, '2026-12-05') === 'fri');

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
let merged = page.mergeRoster(rows(), [
  { rid: 'aaa', i: 0, day: 'fri', undo: false, at: '2026-12-04T14:00:00Z', by: 'admin:Pat' },
  { rid: 'aaa', i: 1, day: 'fri', undo: true },
], 'fri');
ok('a queued tap paints the person checked in before the ship knows',
  merged[0].people[0].checked === true && merged[0].people[0].by === 'admin:Pat');
ok('a queued undo unpaints one the ship still has checked in',
  merged[0].people[1].checked === false && !merged[0].people[1].at);
merged = page.mergeRoster(rows(), [{ rid: 'aaa', i: 0, day: 'sat', undo: false, at: 'x' }], 'fri');
ok('a tap for another day is left alone', merged[0].people[0].checked === false);
merged = page.mergeRoster(rows(), [{ rid: 'zzz', i: 0, day: 'fri' }, { rid: 'aaa', i: 7, day: 'fri' }], 'fri');
ok('a tap for a party or a person the roster does not have is skipped',
  merged[0].people[0].checked === false && merged.length === 2);
merged = page.mergeRoster(rows(), [{ rid: 'bbb', i: 0, day: 'fri', why: 'no such registration' }], 'fri');
ok('a rejected tap shows its reason on the person', merged[1].people[0].why === 'no such registration');

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
ok('Sunday counts the two starts instead',
  page.actsFor('sun').map(function (a) { return a[0]; }).join(',') === 'walk,sun_ten,sun_short,bus');

// ---- what is written into a card ----
ok('esc handles the five characters', page.esc('<&>"\'') === '&lt;&amp;&gt;&quot;&#39;');
ok('esc takes nothing at all', page.esc(undefined) === '' && page.esc(null) === '');
ok('a time reads as a clock', typeof page.clock('2026-12-04T13:05:00Z') === 'string' && page.clock('') === '');

console.log('ALL OK (' + n + ' checks)');
