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
  function bandText(band) {
    if (band && band.ok) return 'Wristband';
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
  // what the ship answered: the applied items leave the queue, a
  // rejected one stays with its reason so the card can show it
  function drained(queue, answer) {
    var bad = (answer && answer.rejected) || [];
    return (queue || []).map(function (q) {
      var hit = bad.filter(function (b) { return String(b.rid) === String(q.rid) && Number(b.i) === Number(q.i); })[0];
      return hit ? Object.assign({}, q, { why: hit.why || 'rejected' }) : null;
    }).filter(Boolean);
  }
  // the fetched rows are the ship's truth; the queue is what this phone
  // did since. Apply the rows, then the queue on top, so a refresh
  // never wipes the tap a volunteer just made.
  function mergeRoster(rows, queue, day) {
    var by = {};
    (rows || []).forEach(function (r) { by[r.rid] = r; });
    (queue || []).forEach(function (q) {
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
  // the day's activity grid: Sunday trades the social for the two walk
  // starts, which are the only per-day difference the counts screen has
  function actsFor(day) {
    var out = [['walk', 'Walk'], ['mass', 'Mass'], ['holy_hour', 'Holy Hour'],
      ['social', 'Social'], ['bus', 'Bus']];
    if (day === 'sun') {
      out = [['walk', 'Walk'], ['sun_ten', '10 mile start'], ['sun_short', '2.5 mile start'], ['bus', 'Bus']];
    }
    return out;
  }

  var pure = {
    esc: esc, dayFor: dayFor, bandText: bandText, queueAdd: queueAdd, drained: drained,
    mergeRoster: mergeRoster, matches: matches, tags: tags, actsFor: actsFor, waiting: waiting,
    clock: clock,
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
  function api(url, opts) {
    return fetch(url, opts || {}).then(function (r) {
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
    });
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
  function drawActor() { actorEl.textContent = actor ? 'acting as ' + actor : 'set your name'; }
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
      syncEl.textContent = n ? n + ' waiting' : 'offline';
      return;
    }
    syncEl.className = 'sync' + (n ? ' waiting' : '');
    syncEl.textContent = n ? n + ' waiting' : 'synced';
  }

  // ---- the roster ----
  function rosterKey() { return 'register.roster.' + day; }
  function countsKey() { return 'register.counts.' + day; }
  function paintStored() {
    var kept = recall(rosterKey(), null);
    if (!kept) return;
    rows = kept.rows || [];
    plan = kept.planned || {};
    counts = kept.counts || {};
    render();
  }
  function fetchRoster() {
    if (!navigator.onLine) return Promise.resolve();
    return api(API + '/checkin/roster?day=' + day).then(function (d) {
      rows = d.rows || [];
      plan = d.planned || {};
      counts = d.counts || {};
      store(rosterKey(), { rows: rows, planned: plan, counts: counts, at: new Date().toISOString() });
      render();
    }).catch(function (e) {
      if (e.status === 403) return locked();
      say(e.message);
    });
  }
  function locked() {
    stopped = true;
    reloginEl.hidden = false;
  }

  // ---- the queue ----
  function tap(rid, i, undo) {
    queue = queueAdd(queue, {
      rid: rid, i: i, day: day, undo: !!undo, at: new Date().toISOString(), by: 'admin:' + actor
    });
    store(QKEY, queue);
    render();
    drain();
  }
  function drain() {
    if (stopped || !navigator.onLine) { drawSync(); return Promise.resolve(); }
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
        drawSync();
        render();
      }).catch(function (e) {
        if (e.status === 403) return locked();
        drawSync();
      });
    });
  }
  function drainCounts() {
    var pending = recall(countsKey(), null);
    if (!pending) return Promise.resolve();
    return api(API + '/admin/counts').then(function (doc) {
      var merged = Object.assign({}, doc || {});
      merged[day] = pending;
      return put('/admin/counts', merged).then(function () {
        try { localStorage.removeItem(countsKey()); } catch (e) { }
        countsDoc = merged;
        say('counts saved', true);
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
  function rosterView() {
    var live = mergeRoster(rows, queue.concat(fresh()), day);
    var q = qEl.value;
    var list = live.filter(function (r) { return matches(r, q); });
    var out = '<div class="totals">' + esc(plan.walk || 0) + ' walking, ' +
      esc(plan.checked || 0) + ' checked in';
    if (day === 'fri') out += ', ' + esc(plan.mass || 0) + ' at Mass';
    out += '</div>';
    if (!list.length) return out + '<p class="muted">Nothing matches that search.</p>';
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
      if (p.why) out += '<div class="stuck">' + esc('the ship refused this tap: ' + p.why) + '</div>';
      out += '</div>';
    });
    if ((r.people || []).length > 1) {
      out += '<button type="button" class="btn quiet everyone" data-all="' + esc(r.rid) +
        '">Check in everyone</button>';
    }
    return out + '</div>';
  }
  function countsView() {
    var doc = recall(countsKey(), null) || (countsDoc || {})[day] || counts || {};
    var out = '<h2>' + esc(labelOf(day)) + ' counts</h2>' +
      '<p class="muted">Planned comes from the registrations. Type what actually happened.</p><div class="counts">';
    actsFor(day).forEach(function (a) {
      var got = doc[a[0]] || {};
      out += '<div class="act"><h3>' + esc(a[1]) + '</h3>' +
        '<p class="planned">planned: ' + esc(plan[a[0]] === undefined ? 0 : plan[a[0]]) + '</p>' +
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
      return act(function () {
        var row = rows.filter(function (r) { return r.rid === all; })[0];
        if (!row) return;
        asking = null;
        (row.people || []).forEach(function (p) {
          if (!p.checked) {
            queue = queueAdd(queue, {
              rid: all, i: p.i, day: day, undo: false,
              at: new Date().toISOString(), by: 'admin:' + actor
            });
          }
        });
        store(QKEY, queue);
        render();
        drain();
      });
    }
    if (el.getAttribute('data-act') === 'save-counts') {
      return act(function () { saveCounts(); });
    }
  });
  view.addEventListener('input', function (ev) {
    var k = ev.target.getAttribute('data-count');
    if (!k) return;
    var pending = recall(countsKey(), null) || {};
    var parts = k.split('.');
    pending[parts[0]] = pending[parts[0]] || {};
    pending[parts[0]][parts[1]] = parts[1] === 'count' ? Number(ev.target.value) : ev.target.value;
    store(countsKey(), pending);
    drawSync();
  });
  function saveCounts() {
    if (!recall(countsKey(), null)) return say('nothing to save');
    if (!navigator.onLine) return say('saved on the phone, it will go up when there is signal', true);
    drainCounts().then(function () { drawSync(); });
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
  day = recall('register.day', 'fri') || 'fri';
  drawActor();
  paintStored();
  render();
  fetch(API + '/status').then(function (r) { return r.json(); }).then(function (d) {
    var today = new Date().toISOString().slice(0, 10);
    var want = dayFor(((d || {}).event || {}).days, today);
    if (!recall('register.day', null)) { day = want; store('register.day', day); }
    paintStored();
    render();
    fetchRoster();
  }).catch(function () { fetchRoster(); });
  document.getElementById('days').addEventListener('click', function () { store('register.day', day); });
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
