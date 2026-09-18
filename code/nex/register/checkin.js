// register's check-in app: the roster a volunteer works from, a queue
// that survives a dead signal, and the day's counts. Pure helpers first
// (node tests them), then the app that wires them to the API, the
// beacon and the service worker.
(function () {
  'use strict';
  var API = '/apps/register/api';
  var KEEP = '/grubbery/api/keep/apps/shell.shell/desks/register.desk/desk/data/register.register_app/beacon/rev';
  var DAYS = [['fri', 'Fri'], ['sat', 'Sat'], ['sun', 'Sun']];
  var QKEY = 'register.queue';
  var BATCH = 200;

  // ---- pure helpers ----
  function esc(s) {
    return String(s === undefined || s === null ? '' : s).replace(/[<>&"']/g, function (c) {
      return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  // the event's three days are its settings dates in order, so today is
  // fri, sat or sun when it is one of them, and Fri when it is not
  function dayFor(days, today) {
    var i = (days || []).indexOf(String(today || ''));
    return i >= 0 && i < DAYS.length ? DAYS[i][0] : 'fri';
  }
  // the date here, not in London. toISOString is UTC, so at eight on a
  // Friday evening in Florida it already reads Saturday and the app
  // would open on the wrong day.
  function localDay(d) {
    var t = d || new Date();
    var p = function (n) { return (n < 10 ? '0' : '') + n; };
    return t.getFullYear() + '-' + p(t.getMonth() + 1) + '-' + p(t.getDate());
  }
  // the day the app opens on. A day the volunteer picked by hand wins,
  // but only for the rest of the day they picked it: on the next
  // morning the event's own day takes over again.
  function openDay(days, today, picked) {
    var pick = picked || {};
    if (pick.day && pick.on === today) return pick.day;
    return dayFor(days, today);
  }
  // what a volunteer says out loud while the pilgrim is standing there
  function bandText(band) {
    if (band && band.ok) return 'Wristband: give one';
    return 'No wristband: ' + ((band && band.why) || 'not registered');
  }
  function clock(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return String(iso).slice(11, 16);
    var h = d.getHours(), m = d.getMinutes();
    return ((h % 12) || 12) + ':' + (m < 10 ? '0' : '') + m + (h < 12 ? 'am' : 'pm');
  }
  function sameTap(a, b) { return a.rid === b.rid && a.i === b.i && a.day === b.day; }
  // the latest intent for a person wins: a tap and its undo collapse
  // into one queued item rather than racing each other at the ship
  function queueAdd(queue, tap) {
    var out = (queue || []).filter(function (q) { return !sameTap(q, tap); });
    out.push(tap);
    return out;
  }
  function waiting(queue) {
    return (queue || []).filter(function (q) { return !q.why; }).length;
  }
  // the ship answers this when its writer would not take the tap. The
  // volunteer can do nothing about that, so the tap waits and goes up
  // again instead of parking with a reason nobody can act on.
  var RETRY = 'the ship did not take this tap';
  // what the ship answered: the applied items leave the queue. A
  // refusal that names the registration or the index parks with its
  // reason; the retry reason keeps the item waiting for the next drain.
  function drained(queue, answer) {
    var bad = (answer && answer.rejected) || [];
    return (queue || []).map(function (q) {
      var hit = bad.filter(function (b) { return String(b.rid) === String(q.rid) && Number(b.i) === Number(q.i); })[0];
      if (!hit) return null;
      var why = hit.why || 'rejected';
      return Object.assign({}, q, { why: why === RETRY ? '' : why });
    }).filter(Boolean);
  }
  // the fetched rows are the ship's truth; the recent taps and the
  // queue are what this phone did since. Apply the rows, then the taps
  // the ship has already taken, then the queue on top, so an undo made
  // a moment ago outranks the tap it takes back.
  function mergeRoster(rows, recent, queue, day) {
    var by = {};
    (rows || []).forEach(function (r) { by[r.rid] = r; });
    (recent || []).concat(queue || []).forEach(function (q) {
      if (q.day !== day) return;
      var row = by[q.rid];
      if (!row) return;
      var p = (row.people || []).filter(function (x) { return Number(x.i) === Number(q.i); })[0];
      if (!p) return;
      if (q.undo) { p.checked = false; p.at = null; p.by = ''; }
      else { p.checked = true; p.at = p.at || q.at; p.by = p.by || q.by || ''; }
      p.why = q.why || '';
    });
    return rows || [];
  }
  function matches(row, q) {
    if (!q) return true;
    var hay = [row.rid].concat((row.people || []).map(function (p) {
      return p.first + ' ' + p.last;
    })).concat([row.email || '']).join(' ').toLowerCase();
    return hay.indexOf(String(q).toLowerCase()) >= 0;
  }
  function tags(p, day) {
    var out = [];
    if (p.walks) out.push(day === 'sun' ? (p.sun_ten ? '10 mi' : '2.5 mi') : 'walk');
    if (p.bus) out.push('bus');
    if (p.mass_fri) out.push('Mass');
    if (p.holy_hour) out.push('Holy Hour');
    if (p.social) out.push('social');
    if (p.child) out.push('child');
    return out;
  }
  // the day's activity grid. Every day counts the walk, Mass, the Holy
  // Hour, the social and the bus, because a Sunday Mass is still a Mass
  // to count. Sunday adds the two walk starts.
  function actsFor(day) {
    var out = [['walk', 'Walk'], ['mass', 'Mass'], ['holy_hour', 'Holy Hour'],
      ['social', 'Social'], ['bus', 'Bus']];
    if (day === 'sun') {
      out = out.concat([['sun_ten', '10 mile start'], ['sun_short', '2.5 mile start']]);
    }
    return out;
  }
  // the counts this phone has typed, laid over the day the ship holds.
  // An activity nobody touched keeps the ship's figures, so a keystroke
  // in one box never blanks the others.
  function mergeCounts(day, pending) {
    var out = Object.assign({}, day || {});
    Object.keys(pending || {}).forEach(function (k) {
      out[k] = Object.assign({}, out[k] || {}, pending[k]);
    });
    return out;
  }
  // a typed day goes up only once Save has armed it. Typing alone sends
  // nothing, so the fifteen second drain cannot write a half typed day
  // over what the ship already has.
  function countsToSend(pending, armed) {
    if (!armed || !pending) return null;
    return Object.keys(pending).length ? pending : null;
  }
  // what the badge reads: how many taps are waiting, and why the last
  // drain failed when it failed for a reason other than the login
  function syncText(online, n, why) {
    if (!online) return n ? n + ' to send, offline' : 'Offline';
    if (why) return n ? n + ' to send: ' + why : why;
    return n ? n + ' to send' : 'Synced';
  }

  var pure = {
    esc: esc, dayFor: dayFor, bandText: bandText, queueAdd: queueAdd, drained: drained,
    mergeRoster: mergeRoster, matches: matches, tags: tags, actsFor: actsFor, waiting: waiting,
    clock: clock, localDay: localDay, openDay: openDay, mergeCounts: mergeCounts,
    countsToSend: countsToSend, syncText: syncText, RETRY: RETRY,
  };
  if (typeof module !== 'undefined' && module.exports) { module.exports = pure; }
  if (typeof document === 'undefined') { return; }

  // ---- the app ----
  var view = document.getElementById('view');
  var sayEl = document.getElementById('say');
  var syncEl = document.getElementById('sync');
  var actorEl = document.getElementById('actor');
  var promptEl = document.getElementById('prompt');
  var reloginEl = document.getElementById('relogin');
  var qEl = document.getElementById('q');
  var searchEl = document.getElementById('search');
  var busyEl = document.getElementById('busy');

  var day = 'fri';
  var tab = 'roster';
  var rows = [];
  var plan = {};
  var counts = {};
  var countsDoc = null;
  var queue = [];
  // a tap the ship took stays here for a moment: the writer applies
  // after the answer leaves, so a roster fetched in that gap would
  // paint the person unchecked again and the tick would flicker
  var recent = [];
  var actor = '';
  var queued = null;
  var stopped = false;
  var lastRev = null;
  var asking = null;
  // one drain at a time: the fifteen second timer, the beacon and a tap
  // can all ask at once, and two batches in flight would send the same
  // taps twice
  var draining = false;
  // the drain in flight, so a button that started one can wait on it
  var inFlight = null;
  var syncFail = '';
  // how many fetches are in flight, for the bar across the top
  var busy = 0;
  // the first roster has not landed and this phone kept nothing: the
  // screen says so rather than showing an empty day
  var firstLoad = true;

  function fresh() {
    var now = Date.now();
    recent = recent.filter(function (r) { return now - r.done < 20000; });
    return recent;
  }
  function store(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { } }
  function recall(k, dflt) {
    try {
      var raw = localStorage.getItem(k);
      return raw ? JSON.parse(raw) : dflt;
    } catch (e) { return dflt; }
  }
  function say(msg, good) {
    sayEl.hidden = !msg;
    sayEl.className = 'say' + (good ? ' ok' : '');
    sayEl.textContent = msg || '';
  }
  // the bar counts fetches, not one flag: two calls in flight must not
  // have the first one to answer clear the bar
  function track(p) {
    busy += 1;
    busyEl.hidden = false;
    function done() { busy -= 1; if (busy < 1) { busy = 0; busyEl.hidden = true; } }
    return p.then(function (d) { done(); return d; }, function (e) { done(); throw e; });
  }
  // a button that started a call: disabled with a spinner until the
  // ship answers
  function spin(el) {
    if (!el || el.disabled) return function () { };
    el.disabled = true;
    var tag = document.createElement('span');
    tag.className = 'spin';
    el.appendChild(tag);
    return function () {
      el.disabled = false;
      if (tag.parentNode) tag.parentNode.removeChild(tag);
    };
  }
  function loadingView() { return '<div class="loading"><span class="spin"></span>Loading</div>'; }
  function api(url, opts) {
    return track(fetch(url, opts || {}).then(function (r) {
      return r.text().then(function (txt) {
        var d = {};
        try { d = txt ? JSON.parse(txt) : {}; } catch (e) { d = {}; }
        if (!r.ok) {
          var err = new Error(d.error || ('http ' + r.status));
          err.status = r.status;
          throw err;
        }
        return d;
      });
    }));
  }
  function post(path, body) {
    return api(API + path, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-actor': actor },
      body: JSON.stringify(body)
    });
  }
  function put(path, body) {
    return api(API + path, {
      method: 'PUT',
      headers: { 'content-type': 'application/json', 'x-actor': actor },
      body: JSON.stringify(body)
    });
  }

  // ---- the volunteer's name, the backoffice's own key ----
  actor = recallActor();
  function recallActor() {
    try { return localStorage.getItem('register.actor') || ''; } catch (e) { return ''; }
  }
  function drawActor() { actorEl.textContent = actor ? 'Checking in as ' + actor : 'Set your name'; }
  function askActor() {
    promptEl.hidden = false;
    var f = document.getElementById('actor-name');
    f.value = actor;
    f.focus();
  }
  function saveActor() {
    var v = String(document.getElementById('actor-name').value || '').trim();
    if (!v) return;
    actor = v.slice(0, 64);
    try { localStorage.setItem('register.actor', actor); } catch (e) { }
    promptEl.hidden = true;
    drawActor();
    var q = queued; queued = null;
    if (q) q();
  }
  // every tap is signed, so a first tap with no name asks for one and
  // carries on once it has it
  function act(fn) {
    if (actor) return fn();
    queued = fn;
    askActor();
  }
  actorEl.addEventListener('click', askActor);
  document.getElementById('actor-save').addEventListener('click', saveActor);
  document.getElementById('actor-cancel').addEventListener('click', function () {
    queued = null; promptEl.hidden = true;
  });
  document.getElementById('actor-name').addEventListener('keydown', function (ev) {
    if (ev.key === 'Enter') { ev.preventDefault(); saveActor(); }
  });

  // ---- the sync badge ----
  function drawSync() {
    var n = waiting(queue);
    if (!navigator.onLine) {
      syncEl.className = 'sync offline';
      syncEl.textContent = syncText(false, n, '');
      return;
    }
    syncEl.className = 'sync' + (n || syncFail ? ' waiting' : '');
    syncEl.textContent = syncText(true, n, syncFail);
  }

  // ---- the roster ----
  function rosterKey() { return 'register.roster.' + day; }
  function countsKey() { return 'register.counts.' + day; }
  function armKey() { return 'register.counts.' + day + '.save'; }
  // the day's counts as the screen shows them: what the ship holds for
  // the day, under what this phone has typed and not sent yet
  function shownCounts() {
    return mergeCounts((countsDoc || {})[day] || counts || {}, recall(countsKey(), null) || {});
  }
  function paintStored() {
    var kept = recall(rosterKey(), null);
    if (!kept) return;
    firstLoad = false;
    rows = kept.rows || [];
    plan = kept.planned || {};
    counts = kept.counts || {};
  }
  function fetchRoster() {
    // offline on a first open, with nothing kept on the phone: the
    // screen says so rather than spinning for a roster that cannot come
    if (!navigator.onLine) {
      firstLoad = false;
      refreshed();
      return Promise.resolve();
    }
    return api(API + '/checkin/roster?day=' + day).then(function (d) {
      rows = d.rows || [];
      plan = d.planned || {};
      counts = d.counts || {};
      store(rosterKey(), { rows: rows, planned: plan, counts: counts, at: new Date().toISOString() });
      firstLoad = false;
      refreshed();
    }).catch(function (e) {
      firstLoad = false;
      if (e.status === 403) return locked();
      say(e.message);
      refreshed();
    });
  }
  function locked() {
    stopped = true;
    reloginEl.hidden = false;
  }

  // ---- the queue ----
  // a new intent for a person replaces both the item waiting and the
  // tap the ship took a moment ago, so an undo is not repainted away
  function enqueue(item) {
    recent = fresh().filter(function (r) { return !sameTap(r, item); });
    queue = queueAdd(queue, item);
  }
  function tap(rid, i, undo) {
    enqueue({
      rid: rid, i: i, day: day, undo: !!undo, at: new Date().toISOString(), by: 'admin:' + actor
    });
    store(QKEY, queue);
    render();
    drain();
  }
  function drain() {
    if (stopped || !navigator.onLine) { drawSync(); return Promise.resolve(); }
    // a caller that wants to know when the taps are up gets the drain
    // already running, not an answer that arrives before it has
    if (draining) return inFlight || Promise.resolve();
    draining = true;
    var done = function () { draining = false; inFlight = null; };
    inFlight = drainBatch().then(done, done);
    return inFlight;
  }
  function drainBatch() {
    return drainCounts().then(function () {
      var live = queue.filter(function (q) { return !q.why; });
      if (!live.length) { drawSync(); return; }
      var batch = live.slice(0, BATCH);
      return post('/checkin', {
        day: day,
        checkins: batch.map(function (q) { return { rid: q.rid, i: q.i, undo: !!q.undo }; })
      }).then(function (d) {
        var kept = drained(batch, d);
        var stuck = {};
        kept.forEach(function (q) { stuck[q.rid + ':' + q.i] = true; });
        recent = fresh().concat(batch.filter(function (q) {
          return !stuck[q.rid + ':' + q.i];
        }).map(function (q) { return Object.assign({}, q, { done: Date.now() }); }));
        queue = kept.concat(queue.filter(function (q) { return batch.indexOf(q) < 0; }));
        store(QKEY, queue);
        syncFail = '';
        drawSync();
        refreshed();
      }).catch(function (e) {
        if (e.status === 403) return locked();
        syncFail = e.message || 'the taps did not go up';
        drawSync();
      });
    });
  }
  // the typed day goes up on Save, and after a Save made offline on the
  // first drain with a signal. A bare keystroke sends nothing.
  function drainCounts() {
    var pending = countsToSend(recall(countsKey(), null), recall(armKey(), false));
    if (!pending) return Promise.resolve();
    return api(API + '/admin/counts').then(function (doc) {
      var merged = Object.assign({}, doc || {});
      merged[day] = mergeCounts(merged[day], pending);
      return put('/admin/counts', merged).then(function () {
        try { localStorage.removeItem(countsKey()); } catch (e) { }
        try { localStorage.removeItem(armKey()); } catch (e) { }
        countsDoc = merged;
        say('Counts saved.', true);
      });
    }).catch(function (e) {
      if (e.status === 403) locked();
    });
  }

  // ---- render ----
  function render() {
    searchEl.hidden = tab !== 'roster';
    Array.prototype.forEach.call(document.querySelectorAll('#days button'), function (b) {
      b.className = b.getAttribute('data-day') === day ? 'on' : '';
    });
    Array.prototype.forEach.call(document.querySelectorAll('#tabs button[data-tab]'), function (b) {
      b.className = b.getAttribute('data-tab') === tab ? 'on' : '';
    });
    drawSync();
    view.innerHTML = tab === 'counts' ? countsView() : rosterView();
  }
  // a refresh is data arriving, not the volunteer asking for anything.
  // Repainting the counts screen under a typing thumb would eat the
  // keystroke, so the data is kept and the screen is left alone.
  function refreshed() {
    if (tab !== 'roster') { drawSync(); return; }
    render();
  }
  function rosterView() {
    if (firstLoad && !rows.length) return loadingView();
    if (!rows.length && !navigator.onLine) return '<p class="muted">No roster on this phone yet, and no signal to fetch one.</p>';
    var live = mergeRoster(rows, fresh(), queue, day);
    var q = qEl.value;
    var list = live.filter(function (r) { return matches(r, q); });
    var out = '<div class="totals">' + esc(plan.walk || 0) + ' walking today, ' +
      esc(plan.checked || 0) + ' checked in';
    if (day === 'fri') out += ', ' + esc(plan.mass || 0) + ' at Mass';
    out += '</div>';
    if (!list.length) {
      return out + '<p class="muted">' +
        (q ? 'Nobody matches that search.' : 'No registrations for this day yet.') + '</p>';
    }
    list.forEach(function (r) { out += partyCard(r); });
    return out;
  }
  function partyCard(r) {
    var band = r.wristband || {};
    var out = '<div class="party' + (band.ok ? '' : ' no') + '">' +
      '<span class="rid">' + esc(r.rid) + '</span>';
    if (!band.ok) out += '<div class="why">' + esc(bandText(band)) + '</div>';
    (r.people || []).forEach(function (p) {
      out += '<div class="person"><div class="name">' + esc(p.first + ' ' + p.last) +
        (p.checked ? ' <span class="tick">&check;</span>' : '') + '</div>';
      var tg = tags(p, day);
      if (tg.length) {
        out += '<div class="tags">' + tg.map(function (t) {
          return '<span class="tag">' + esc(t) + '</span>';
        }).join('') + '</div>';
      }
      var asked = asking && asking.rid === r.rid && Number(asking.i) === Number(p.i);
      if (asked) {
        out += '<button type="button" class="tap undo" data-undo="' + esc(r.rid) + ':' + esc(p.i) + '">' +
          'Undo this check-in?</button>';
      } else if (p.checked) {
        out += '<button type="button" class="tap on" data-ask="' + esc(r.rid) + ':' + esc(p.i) + '">' +
          esc('Checked in ' + clock(p.at) + (p.by ? ' by ' + String(p.by).replace(/^admin:/, '') : '')) +
          '</button>';
      } else {
        out += '<button type="button" class="tap' + (band.ok ? '' : ' no') + '" data-tap="' +
          esc(r.rid) + ':' + esc(p.i) + '">' +
          esc(band.ok ? 'Check in' : 'Check in, ' + bandText(band).toLowerCase()) + '</button>';
      }
      if (p.why) out += '<div class="stuck">' + esc('The ship would not take this tap: ' + p.why) + '</div>';
      out += '</div>';
    });
    if ((r.people || []).length > 1) {
      out += '<button type="button" class="btn quiet everyone" data-all="' + esc(r.rid) +
        '">Check in everyone</button>';
    }
    return out + '</div>';
  }
  function countsView() {
    var doc = shownCounts();
    var out = '<h2>' + esc(labelOf(day)) + ' counts</h2>' +
      '<p class="muted">Planned comes from the registrations. Type what actually happened.</p><div class="counts">';
    actsFor(day).forEach(function (a) {
      var got = doc[a[0]] || {};
      out += '<div class="act"><h3>' + esc(a[1]) + '</h3>' +
        '<p class="planned">Planned: ' + esc(plan[a[0]] === undefined ? 0 : plan[a[0]]) + '</p>' +
        '<label>Actual<input type="number" min="0" data-count="' + esc(a[0]) + '.count" value="' + esc(got.count === undefined ? '' : got.count) + '"></label>' +
        '<label>Time<input type="text" data-count="' + esc(a[0]) + '.time" value="' + esc(got.time || '') + '"></label>' +
        '<label>Note<input type="text" data-count="' + esc(a[0]) + '.note" value="' + esc(got.note || '') + '"></label>' +
        '</div>';
    });
    out += '</div><p><button type="button" class="btn" data-act="save-counts">Save the counts</button></p>';
    return out;
  }
  function labelOf(d) {
    var hit = DAYS.filter(function (x) { return x[0] === d; })[0];
    return hit ? hit[1] : d;
  }

  // ---- input ----
  document.getElementById('days').addEventListener('click', function (ev) {
    var b = ev.target.closest('button[data-day]');
    if (!b) return;
    day = b.getAttribute('data-day');
    // the pick carries the date it was made, so it rules today and no
    // longer than today
    store('register.day', { day: day, on: localDay(new Date()) });
    asking = null;
    paintStored();
    render();
    fetchRoster();
  });
  document.getElementById('tabs').addEventListener('click', function (ev) {
    var b = ev.target.closest('button[data-tab]');
    if (!b) return;
    tab = b.getAttribute('data-tab');
    if (tab === 'counts' && !countsDoc && navigator.onLine) {
      api(API + '/admin/counts').then(function (d) { countsDoc = d; render(); }).catch(function () { });
    }
    render();
  });
  qEl.addEventListener('input', function () {
    view.innerHTML = rosterView();
  });
  view.addEventListener('click', function (ev) {
    var el = ev.target.closest('[data-tap], [data-ask], [data-undo], [data-all], [data-act]');
    if (!el) return;
    var one = el.getAttribute('data-tap');
    if (one) {
      var parts = one.split(':');
      return act(function () { asking = null; tap(parts[0], Number(parts[1]), false); });
    }
    var ask = el.getAttribute('data-ask');
    if (ask) {
      var a = ask.split(':');
      asking = { rid: a[0], i: Number(a[1]) };
      return render();
    }
    var un = el.getAttribute('data-undo');
    if (un) {
      var u = un.split(':');
      return act(function () { asking = null; tap(u[0], Number(u[1]), true); });
    }
    var all = el.getAttribute('data-all');
    if (all) {
      // the spinner starts once the name is in hand: a prompt the
      // volunteer cancels must not leave a button disabled for ever
      return act(function () {
        var row = rows.filter(function (r) { return r.rid === all; })[0];
        if (!row) return;
        asking = null;
        (row.people || []).forEach(function (p) {
          if (!p.checked) {
            enqueue({
              rid: all, i: p.i, day: day, undo: false,
              at: new Date().toISOString(), by: 'admin:' + actor
            });
          }
        });
        store(QKEY, queue);
        render();
        // the paint above replaced the button, so the spinner goes on
        // the one now on screen, and it holds until the taps are up
        var freeAll = spin(view.querySelector('[data-all="' + all + '"]') || el);
        drain().then(freeAll, freeAll);
      });
    }
    if (el.getAttribute('data-act') === 'save-counts') {
      return act(function () { saveCounts(spin(el)); });
    }
  });
  view.addEventListener('input', function (ev) {
    var k = ev.target.getAttribute('data-count');
    if (!k) return;
    // the draft starts as the day on screen, so the figures the
    // volunteer did not retype are still there when it goes up
    var pending = recall(countsKey(), null) || mergeCounts({}, shownCounts());
    var parts = k.split('.');
    pending[parts[0]] = Object.assign({}, pending[parts[0]]);
    pending[parts[0]][parts[1]] = parts[1] === 'count' ? Number(ev.target.value) : ev.target.value;
    store(countsKey(), pending);
    drawSync();
  });
  function saveCounts(free) {
    var done = free || function () { };
    if (!recall(countsKey(), null)) { done(); return say('Nothing typed yet, so there is nothing to save.'); }
    store(armKey(), true);
    if (!navigator.onLine) { done(); return say('Saved on this phone. It goes up when there is signal.', true); }
    drainCounts().then(function () { done(); drawSync(); }, function () { done(); });
  }

  // ---- the beacon, read raw the way the backoffice does ----
  function sseEvent(block) {
    var name = '', data = '';
    String(block).split('\n').forEach(function (ln) {
      if (ln.indexOf('event: ') === 0) name = ln.slice(7).trim();
      else if (ln.indexOf('data: ') === 0) data = ln.slice(6).trim();
    });
    return { name: name, data: data };
  }
  async function stream() {
    for (;;) {
      if (document.hidden || stopped) { await new Promise(function (r) { setTimeout(r, 1000); }); continue; }
      try {
        var resp = await fetch(KEEP, { headers: { Accept: 'text/event-stream' } });
        if (!resp.ok) { await new Promise(function (r) { setTimeout(r, 30000); }); continue; }
        var rd = resp.body.getReader();
        var dec = new TextDecoder();
        var buf = '';
        for (;;) {
          var chunk = await rd.read();
          if (chunk.done) break;
          buf += dec.decode(chunk.value, { stream: true });
          var evs = buf.split('\n\n');
          buf = evs.pop();
          evs.forEach(function (ev) {
            var parsed = sseEvent(ev);
            if (!parsed.name || parsed.name.slice(-4) !== '/rev') return;
            if (parsed.name.indexOf('old') === 0) {
              if (lastRev !== null && parsed.data && parsed.data !== lastRev) fetchRoster();
              lastRev = parsed.data;
              return;
            }
            lastRev = parsed.data;
            fetchRoster();
          });
        }
      } catch (e) { /* the stream severed: reconnect below */ }
      await new Promise(function (r) { setTimeout(r, 3000); });
    }
  }

  // ---- boot ----
  queue = recall(QKEY, []) || [];
  day = openDay(null, localDay(new Date()), recall('register.day', null));
  drawActor();
  paintStored();
  render();
  track(fetch(API + '/status').then(function (r) { return r.json(); })).then(function (d) {
    var want = openDay(((d || {}).event || {}).days, localDay(new Date()), recall('register.day', null));
    if (want !== day) { day = want; }
    paintStored();
    render();
    fetchRoster();
  }).catch(function () { fetchRoster(); });
  window.addEventListener('online', function () { stopped = false; drain(); fetchRoster(); });
  window.addEventListener('offline', drawSync);
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) return;
    stopped = false;
    reloginEl.hidden = true;
    drain();
    fetchRoster();
  });
  setInterval(function () { if (!document.hidden) drain(); }, 15000);
  setInterval(function () { if (!document.hidden) fetchRoster(); }, 60000);
  drain();
  stream();
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/apps/register/sw.js', { scope: '/apps/register/' }).catch(function () { });
  }
})();
