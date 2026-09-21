// register's backoffice: the roster, one registration with every
// organizer action, manual adds, reports, the counts, the copy and the
// settings editors, and the backup box. Owner only; the ship checks.
// The strings here are the organizers' own, not copy.json, which holds
// only what a pilgrim reads.
(function () {
  'use strict';
  var API = '/apps/register/api';
  var ADMIN = API + '/admin';
  var KEEP = '/grubbery/api/keep/apps/shell.shell/desks/register.desk/desk/data/register.register_app/beacon/rev';
  var SHRINE = 350;   // the Sunday capacity at the Shrine, reported not enforced
  var TEMPLATES = ['confirmation', 'manage', 'promoted', 'assistance_approved',
    'assistance_declined', 'reminder', 'cancelled', 'checkin'];
  var DAYS = [['fri', 'Friday'], ['sat', 'Saturday'], ['sun', 'Sunday']];
  var ACTS = [['walk', 'Walk'], ['mass', 'Mass'], ['holy_hour', 'Holy Hour'],
    ['social', 'Social'], ['bus', 'Bus']];
  var SUN_ACTS = [['sun_ten', '10 mile start'], ['sun_short', '2.5 mile start']];
  var SEGMENTS = [['active', 'registrations'], ['all', 'everything'], ['complete', 'complete'], ['pending', 'pending'],
    ['waitlist', 'wait list'], ['assistance', 'financial assistance'], ['unpaid', 'unpaid'],
    ['unsigned', 'unsigned'], ['draft', 'drafts'], ['cancelled', 'cancelled'],
    ['bambino', 'Bambino only'], ['nonwalker', 'non-walkers'],
    ['malta', 'NE Florida Order of Malta and volunteers'], ['exempt', 'exempt'],
    ['admin', 'admin adds']];

  // ---- pure helpers (node tests them) ----
  function esc(s) {
    return String(s === undefined || s === null ? '' : s).replace(/[<>&"']/g, function (c) {
      return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function money(cents) {
    var n = Number(cents) || 0;
    return '$' + (n % 100 ? (n / 100).toFixed(2) : String(n / 100));
  }
  // the {{placeholders}} a template holds, each one once
  function varsOf(s) {
    var seen = {}, out = [];
    (String(s === undefined || s === null ? '' : s).match(/\{\{[a-zA-Z0-9_]+\}\}/g) || []).forEach(function (v) {
      if (seen[v]) return;
      seen[v] = true;
      out.push(v);
    });
    return out;
  }
  // the placeholders an edit dropped. The ship fills those by name, so
  // a template that loses one sends an email with a hole in it.
  function missingVars(orig, next) {
    var have = varsOf(next);
    return varsOf(orig).filter(function (v) { return have.indexOf(v) < 0; });
  }
  // the email templates a copy document holds, each with the keys of
  // its subject and its body
  function mailGroups(doc) {
    var by = {};
    Object.keys(doc || {}).forEach(function (k) {
      var hit = /^email\.([a-z0-9_]+)\.(subject|body)$/.exec(k);
      if (!hit) return;
      by[hit[1]] = by[hit[1]] || {};
      by[hit[1]][hit[2]] = k;
    });
    return by;
  }
  // how old the roster on screen is, in words
  function ageText(then, now) {
    var ms = Number(now) - Number(then);
    if (!(ms >= 0)) return '';
    var mins = Math.round(ms / 60000);
    if (mins < 1) return 'a moment old';
    if (mins < 60) return mins + (mins === 1 ? ' minute old' : ' minutes old');
    var hrs = Math.round(mins / 60);
    return hrs + (hrs === 1 ? ' hour old' : ' hours old');
  }
  // ---- what an action does before the ship has said so ----
  // the registration an op leaves behind, as the ship would leave it.
  // The page paints this at once and the read that follows confirms
  // it. `pending` marks it as painted and not yet confirmed.
  function patchReg(r, body, by, at) {
    var op = (body || {}).op;
    var out = JSON.parse(JSON.stringify(r || {}));
    var what = '';
    if (op === 'promote') {
      out.status = 'waiver';
      out.position = 0;
      what = 'promoted from the wait list';
    } else if (op === 'assist') {
      out.status = body.approve ? 'complete' : 'payment';
      if (body.approve) {
        out.payment = Object.assign({}, out.payment, { method: 'assistance', amount: 0, gift: 0, at: at, refunded: false });
      }
      what = body.approve ? 'assistance approved' : 'assistance declined';
    } else if (op === 'pay') {
      out.payment = { method: body.method, amount: body.amount, gift: body.gift,
        ref: body.ref, note: body.note, at: at, refunded: false };
      out.status = 'complete';
      what = 'payment recorded';
    } else if (op === 'waiver-paper') {
      out.waiver = Object.assign({}, out.waiver, { method: 'paper', status: 'completed', at: at });
      what = 'waiver signed on paper';
    } else if (op === 'refund') {
      out.payment = Object.assign({}, out.payment, { refunded: true });
      what = 'payment refunded';
    } else if (op === 'exempt') {
      out.exempt = !!body.on;
      what = body.on ? 'exempted from the caps' : 'no longer exempt';
    } else if (op === 'reinstate') {
      out.status = out.prior || 'waiver';
      out.prior = '';
      what = 'reinstated';
    } else if (op === 'cancel') {
      out.prior = out.status;
      out.status = 'cancelled';
      out.position = 0;
      what = 'cancelled';
    } else if (op === 'note') {
      out.notes = String(body.notes === undefined ? '' : body.notes);
      what = 'notes changed';
    } else if (op === 'edit') {
      var inp = body.input || {};
      out.track = inp.track;
      out.contact = inp.contact;
      out.org = inp.org;
      out.why = inp.why;
      out.assistance = !!inp.assistance;
      out.together = !!inp.together;
      // an edit replaces the people and keeps each position's check-ins,
      // which is what the ship does with it
      out.people = (inp.people || []).map(function (q, i) {
        var had = ((r || {}).people || [])[i] || {};
        return Object.assign({}, q, { checkins: had.checkins });
      });
      what = 'edited';
    } else if (op === 'resend') {
      what = 'resent ' + String(body.template || '');
    } else {
      return null;
    }
    out.history = ((r || {}).history || []).concat([{ at: at, by: by, what: what }]);
    out.pending = true;
    return out;
  }
  // has the copy the ship answered caught up with what was painted?
  function settled(r, body) {
    var op = (body || {}).op;
    if (!r) return false;
    if (op === 'promote') return r.status === 'waiver';
    if (op === 'assist') return r.status === (body.approve ? 'complete' : 'payment');
    if (op === 'pay') return (r.payment || {}).method === body.method;
    if (op === 'waiver-paper') return (r.waiver || {}).status === 'completed';
    if (op === 'refund') return !!(r.payment || {}).refunded;
    if (op === 'exempt') return !!r.exempt === !!body.on;
    if (op === 'reinstate') return r.status !== 'cancelled';
    if (op === 'cancel') return r.status === 'cancelled';
    if (op === 'note') return String(r.notes || '') === String(body.notes || '');
    return true;
  }
  // how long a painted action may wait for the ship to show it. The
  // writer answers in well under a second, so a patch still unconfirmed
  // after this was refused and is never coming back.
  var HOLD = 15000;
  // what to do with the action this page painted, given the copy the
  // ship just answered: it shows the change ('settled'), it has not
  // shown it yet ('waiting'), or the deadline passed and the local
  // patch must go ('stale').
  function verdict(waiting, got, now) {
    if (!waiting) return 'settled';
    if (settled(got, waiting.body)) return 'settled';
    if (Number(now) - Number(waiting.at) >= HOLD) return 'stale';
    return 'waiting';
  }
  // the roster row a registration makes, keeping what the row holds and
  // the registration does not
  function patchRow(row, r) {
    var out = Object.assign({}, row || {});
    var pay = r.payment || {};
    out.status = r.status;
    if (r.status !== 'waitlist') out.position = 0;
    out.paid = pay.method || 'none';
    out.amount = Number(pay.amount) || 0;
    out.gift = Number(pay.gift) || 0;
    out.refunded = !!pay.refunded;
    out.waiver = (r.waiver || {}).status || 'none';
    out.exempt = !!r.exempt;
    out.assistance = !!r.assistance;
    out.track = r.track || out.track;
    if (r.contact) {
      out.email = r.contact.email;
      out.phone = r.contact.phone;
      out.state = r.contact.state;
    }
    if (r.org !== undefined) out.org = r.org;
    if (r.people) {
      out.people = r.people.length;
      out.names = r.people.map(function (q) { return q.last + ', ' + q.first; });
    }
    out.pending = !!r.pending;
    return out;
  }

  // what a manual add landed as, in the words an organizer uses. The
  // bare status name reads as jargon in a sentence, and it is the one
  // line that tells them whether there is anything left to do.
  function addedText(status) {
    var said = { waitlist: 'Added and wait-listed',
      waiver: 'Added, waiting on the waiver',
      payment: 'Added, waiting on payment',
      assistance: 'Added, waiting on the assistance decision',
      complete: 'Added and complete',
      draft: 'Added, not finished yet' };
    return said[String(status)] || ('Added. It is ' + String(status) + ' now.');
  }

  // the addresses of a set of rows, each once, for a mail client's To
  // line. Lowercased so a pilgrim who typed their address twice with
  // different capitals is one person, and blanks (a phone-only draft)
  // are left out.
  function emailsOf(rows) {
    var seen = {}, out = [];
    (rows || []).forEach(function (r) {
      var e = String(r.email || '').trim().toLowerCase();
      if (!e || seen[e]) return;
      seen[e] = true;
      out.push(e);
    });
    return out;
  }
  // every word typed must be somewhere in the row: "Mary Smith" finds
  // "Smith, Mary", a phone typed with dashes finds one stored bare, and
  // a trailing space matches nothing extra
  function matches(r, q) {
    var words = String(q || '').toLowerCase().split(/\s+/).filter(Boolean);
    if (!words.length) return true;
    var digits = String(r.phone || '').replace(/\D/g, '');
    var hay = [r.email, r.phone, digits, r.org, r.id].concat(r.names || []).join(' ').toLowerCase();
    // the same text with its punctuation dropped, so a phone with
    // dashes and an O'Brien are found either way they are typed
    hay += ' ' + hay.replace(/[^a-z0-9@. ]/g, '');
    return words.every(function (w) {
      var bare = w.replace(/[^a-z0-9@.]/g, '');
      return hay.indexOf(w) >= 0 || (bare && hay.indexOf(bare) >= 0);
    });
  }
  // the emails of every row that is neither a draft nor cancelled: a
  // draft with one of these addresses was finished under another row
  function liveEmails(regs) {
    var out = {};
    (regs || []).forEach(function (r) {
      if (r.status === 'draft' || r.status === 'cancelled') return;
      var e = String(r.email || '').trim().toLowerCase();
      if (e) out[e] = true;
    });
    return out;
  }
  function superseded(r, live) {
    return r.status === 'draft' && !!live[String(r.email || '').trim().toLowerCase()];
  }

  var pure = {
    esc: esc, money: money, varsOf: varsOf, missingVars: missingVars, mailGroups: mailGroups,
    ageText: ageText, patchReg: patchReg, settled: settled, patchRow: patchRow,
    verdict: verdict, addedText: addedText, HOLD: HOLD,
    emailsOf: emailsOf, matches: matches, liveEmails: liveEmails, superseded: superseded,
  };
  if (typeof module !== 'undefined' && module.exports) { module.exports = pure; }
  if (typeof document === 'undefined') { return; }

  var view = document.getElementById('view');
  var sayEl = document.getElementById('say');
  var liveEl = document.getElementById('live');
  var actorEl = document.getElementById('actor');
  var promptEl = document.getElementById('prompt');
  var busyEl = document.getElementById('busy');

  var roster = null, pub = null, detail = null;
  var dayDoc = null, dayFilters = { seg: 'missing', q: '', again: false, force: false }, mailing = null;
  var model = null, before = null;
  var settingsDoc = null, copyDoc = null, countsDoc = null;
  var dry = null, fileBody = null, fileName = '';
  var sortBy = { col: 'created', up: false };
  var filters = { seg: 'active', q: '', track: 'all' };
  var dirty = false;          // something typed on this view and not yet saved
  var lastHash = location.hash, restoring = false;
  var routeGen = 0, lastRev = null, refreshTimer = null;
  var copyWas = null;         // the email templates as the ship last gave them
  var waitingOn = null;       // the op the page painted and the ship has not confirmed
  var rosterAge = '';         // how old the roster on screen is, when it came from this browser
  var busy = 0;               // how many fetches are in flight
  var RKEY = 'register.admin.roster';

  // ---- helpers ----
  function cents(dollars) { return Math.round((Number(dollars) || 0) * 100); }
  function day(t) { return t ? String(t).slice(0, 10) : ''; }
  function when(t) { return t ? String(t).replace('T', ' ').replace('Z', '') : ''; }
  function say(msg, good) {
    sayEl.hidden = !msg;
    sayEl.className = 'say' + (good ? ' ok' : '');
    sayEl.textContent = msg || '';
  }
  // the writer would not take what the page painted. The ship's own copy
  // goes back on screen and this line says why, for a few seconds, which
  // is why the read that follows leaves the line alone.
  var noticeUntil = 0, noticeTimer = null;
  function refused() {
    noticeUntil = Date.now() + 5000;
    say('The ship would not take that change.');
    clearTimeout(noticeTimer);
    noticeTimer = setTimeout(function () { noticeUntil = 0; say(''); }, 5000);
  }
  // the bar at the top counts fetches, not one flag: two calls in
  // flight must not have the first one to answer clear the bar
  function track(p) {
    busy += 1;
    busyEl.hidden = false;
    function done() { busy -= 1; if (busy < 1) { busy = 0; busyEl.hidden = true; } }
    return p.then(function (d) { done(); return d; }, function (e) { done(); throw e; });
  }
  // a button that started a fetch: disabled with a spinner until the
  // ship answers. A button a re-render replaces takes its spinner with
  // it, which is what should happen.
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
  function loading() { return '<div class="loading"><span class="spin"></span>Loading</div>'; }
  function api(url, opts) {
    return track(fetch(url, opts || {}).then(function (r) {
      return r.text().then(function (txt) {
        var d = {};
        try { d = txt ? JSON.parse(txt) : {}; } catch (e) { d = {}; }
        if (!r.ok) {
          var err = new Error(d.error || ('http ' + r.status));
          err.status = r.status; err.code = d.code;
          throw err;
        }
        return d;
      });
    }));
  }
  function read(path) { return api(ADMIN + path); }
  // every mutating call names the organizer; the ship refuses one that
  // does not, and that refusal reopens the prompt
  function write(path, body, method) {
    return api(ADMIN + path, {
      method: method || 'POST',
      headers: { 'content-type': 'application/json', 'x-actor': actor },
      body: JSON.stringify(body === undefined ? {} : body)
    }).catch(function (e) {
      if (e.status === 400 && /actor/.test(String(e.message))) askActor();
      throw e;
    });
  }
  // the check-in route is the volunteers' own, not under /admin, so it
  // needs its own call. It names the organizer the same way.
  function writeApi(path, body) {
    return api(API + path, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-actor': actor },
      body: JSON.stringify(body === undefined ? {} : body)
    }).catch(function (e) {
      if (e.status === 400 && /actor/.test(String(e.message))) askActor();
      throw e;
    });
  }
  // the clipboard API needs https or localhost; on a plain http ship the
  // old selection trick still works
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
    return new Promise(function (resolve, reject) {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed'; ta.style.top = '-1000px';
      document.body.appendChild(ta);
      ta.select();
      var ok = false;
      try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
      document.body.removeChild(ta);
      if (ok) resolve(); else reject(new Error('copy refused'));
    });
  }
  // the party's check-ins for a day, as ticks
  function ticks(r) {
    var got = r.checked || {};
    var out = DAYS.map(function (d) {
      var n = Number(got[d[0]]) || 0;
      if (!n) return '';
      return '<span class="tag">' + esc(d[1].slice(0, 3)) + (n === Number(r.people) ? '' : ' ' + n) + '</span>';
    }).join('');
    return out || '<span class="muted">-</span>';
  }
  function toLocal(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    var p = function (n) { return (n < 10 ? '0' : '') + n; };
    return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) +
      'T' + p(d.getHours()) + ':' + p(d.getMinutes());
  }
  function fromLocal(v) {
    if (!v) return '';
    var d = new Date(v);
    if (isNaN(d.getTime())) return '';
    return d.toISOString().replace(/\.\d+Z$/, 'Z');
  }
  function getPath(obj, path) {
    var ks = String(path).split('.'), o = obj;
    for (var i = 0; i < ks.length; i++) { if (o === undefined || o === null) return undefined; o = o[ks[i]]; }
    return o;
  }
  function setPath(obj, path, val) {
    var ks = String(path).split('.'), o = obj;
    for (var i = 0; i < ks.length - 1; i++) { if (!o[ks[i]]) o[ks[i]] = {}; o = o[ks[i]]; }
    o[ks[ks.length - 1]] = val;
  }

  // ---- the organizer's name ----
  var actor = '';
  try { actor = localStorage.getItem('register.actor') || ''; } catch (e) { }
  var queued = null;
  function drawActor() {
    actorEl.textContent = actor ? 'Acting as ' + actor : 'Set your name';
  }
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
  // a mutating click with no name yet opens the prompt and goes on after
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

  // ---- the party form, the public form's field list ----
  function blankPerson() {
    return {
      first: '', last: '', child: false, days: { fri: false, sat: false, sun: false }, sun_ten: false,
      social_fri: false, social_sat: false, mass_fri: false, holy_hour: false, bus: false,
      first_bsc: false, knight_dame: false, volunteer: false
    };
  }
  function blankParty(track) {
    return {
      track: track || 'full',
      contact: { email: '', phone: '', street: '', city: '', state: '', zip: '' },
      org: '', why: '', assistance: false, together: false, notes: '', exempt: false,
      people: [blankPerson()]
    };
  }
  function fromReg(r) {
    var keys = Object.keys(blankPerson());
    return {
      track: r.track, contact: r.contact, org: r.org, why: r.why,
      assistance: !!r.assistance, together: !!r.together, notes: r.notes || '',
      exempt: !!r.exempt,
      people: (r.people || []).map(function (p) {
        var q = {};
        keys.forEach(function (k) { q[k] = k === 'days' ? { fri: !!p.days.fri, sat: !!p.days.sat, sun: !!p.days.sun } : p[k]; });
        return q;
      })
    };
  }
  function partyInput(m) {
    return {
      track: m.track, contact: m.contact, org: m.org, why: m.why,
      assistance: !!m.assistance, together: !!m.together,
      people: m.people.map(function (p) {
        var q = JSON.parse(JSON.stringify(p));
        delete q.checkins;
        return q;
      })
    };
  }
  function field(k, label, value, type, extra) {
    return '<label>' + esc(label) + '<input type="' + esc(type || 'text') +
      '" data-k="' + esc(k) + '" value="' + esc(value === undefined || value === null ? '' : value) + '"' + (extra || '') + '></label>';
  }
  function box(k, label, on) {
    return '<label class="check"><input type="checkbox" data-k="' + esc(k) + '"' + (on ? ' checked' : '') +
      '><span>' + esc(label) + '</span></label>';
  }
  function personCard(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '<div class="card"><h3>Person ' + (i + 1) +
      (m.people.length > 1 ? ' <button type="button" class="btn quiet small" data-act="remove-person" data-i="' + i + '">Remove</button>' : '') + '</h3>';
    out += '<div class="row">' + field(k + 'first', 'First name', p.first) + field(k + 'last', 'Last name', p.last) + '</div>';
    out += box(k + 'child', 'Under 18', p.child);
    if (i === 0 || !m.together) {
      out += '<h3>Walking days</h3>';
      if (m.track === 'full') {
        out += box(k + 'days.fri', 'Friday', p.days.fri) + box(k + 'days.sat', 'Saturday', p.days.sat) +
          box(k + 'days.sun', 'Sunday', p.days.sun) + box(k + 'sun_ten', 'Sunday: the 10 miles, not the last 2.5', p.sun_ten);
      } else {
        out += box(k + 'days.sun', 'Sunday', p.days.sun);
      }
      out += box(k + 'social_fri', 'Friday social', p.social_fri) + box(k + 'social_sat', 'Saturday social', p.social_sat) +
        box(k + 'mass_fri', 'Friday Mass', p.mass_fri) + box(k + 'holy_hour', 'Holy Hour', p.holy_hour) +
        box(k + 'bus', 'Bus', p.bus);
    }
    out += box(k + 'first_bsc', 'First Baby Steps Camino', p.first_bsc) +
      box(k + 'knight_dame', 'Knight or Dame', p.knight_dame) + box(k + 'volunteer', 'Volunteering', p.volunteer);
    if (p.checkins && Object.keys(p.checkins).length) {
      out += '<p class="help">Checked in on: ' + esc(Object.keys(p.checkins).join(', ')) + '</p>';
    }
    return out + '</div>';
  }
  function partyForm(m) {
    var c = m.contact;
    var out = '<div class="card"><h3>Contact</h3>';
    out += '<label>Track<select data-k="track">' +
      ['full', 'bambino'].map(function (t) {
        return '<option value="' + t + '"' + (m.track === t ? ' selected' : '') + '>' + t + '</option>';
      }).join('') + '</select></label>';
    out += '<div class="row">' + field('contact.email', 'Email', c.email, 'email') + field('contact.phone', 'Phone', c.phone, 'tel') + '</div>';
    if (!m.isAdd && c.email) out += '<p class="help"><a href="mailto:' + esc(c.email) + '">Write to ' + esc(c.email) + '</a></p>';
    out += field('contact.street', 'Street', c.street);
    out += '<div class="row3">' + field('contact.city', 'City', c.city) +
      field('contact.state', 'State', c.state, 'text', ' maxlength="40"') + field('contact.zip', 'ZIP', c.zip) + '</div>';
    out += field('org', 'Organization', m.org);
    out += '<label>Why they are walking<textarea data-k="why">' + esc(m.why) + '</textarea></label>';
    out += box('assistance', 'Requests financial assistance', m.assistance);
    out += box('exempt', 'Exempt from the track caps', m.exempt);
    // a manual add has no notes route yet, so the field waits for the detail
    if (!m.isAdd) out += '<label>Organizers’ notes<textarea data-k="notes">' + esc(m.notes) + '</textarea></label>';
    out += '</div>';
    if (m.people.length > 1) out += '<div class="card soft">' + box('together', 'Copy the first person\'s choices to everyone else', m.together) + '</div>';
    m.people.forEach(function (p, i) { out += personCard(p, i, m); });
    var cap = (roster && roster.caps ? roster.caps.party : 12) || 12;
    if (m.people.length < cap) out += '<p><button type="button" class="btn quiet small" data-act="add-person">Add a person</button></p>';
    return out;
  }

  // ---- the roster ----
  function inSegment(r, seg, liveMail) {
    var live = r.status !== 'draft' && r.status !== 'cancelled';
    if (seg === 'all') return true;
    if (seg === 'active') return live;
    if (seg === 'complete') return r.status === 'complete';
    if (seg === 'pending') return r.status === 'waiver' || r.status === 'payment' || r.status === 'assistance';
    if (seg === 'waitlist') return r.status === 'waitlist';
    if (seg === 'assistance') return r.status === 'assistance' || r.assistance;
    if (seg === 'unpaid') return live && r.paid === 'none';
    if (seg === 'unsigned') return live && r.waiver !== 'completed';
    if (seg === 'draft') return r.status === 'draft' && !superseded(r, liveMail || {});
    if (seg === 'cancelled') return r.status === 'cancelled';
    if (seg === 'bambino') return r.track === 'bambino';
    if (seg === 'nonwalker') return !!r.nonwalker;
    if (seg === 'malta') return (r.knight_dame || r.volunteer) && String(r.state || '').trim().toUpperCase() === 'FL';
    if (seg === 'exempt') return !!r.exempt;
    if (seg === 'admin') return r.source === 'admin';
    return true;
  }
  function sortKey(r, col) {
    if (col === 'name') return String((r.names || [])[0] || '').toLowerCase();
    if (col === 'state') return String(r.state || '').toUpperCase();
    if (col === 'fees') return Number(r.fees) || 0;
    return String(r[col] || '');
  }
  function rows() {
    var liveMail = liveEmails(roster.regs);
    var out = (roster.regs || []).filter(function (r) {
      return inSegment(r, filters.seg, liveMail) && matches(r, filters.q) &&
        (filters.track === 'all' || r.track === filters.track);
    });
    out.sort(function (a, b) {
      var x = sortKey(a, sortBy.col), y = sortKey(b, sortBy.col);
      if (x === y) return String(a.id) < String(b.id) ? -1 : 1;
      return (x < y ? -1 : 1) * (sortBy.up ? 1 : -1);
    });
    return out;
  }
  function head(col, label, extra) {
    var arrow = sortBy.col === col ? (sortBy.up ? ' ↑' : ' ↓') : '';
    return '<th class="sortable' + (extra || '') + '" data-sort="' + col + '">' + esc(label) + arrow + '</th>';
  }
  function rosterView() {
    var all = roster.regs || [];
    var liveMail = liveEmails(all);
    var drafts = all.filter(function (r) { return r.status === 'draft' && !superseded(r, liveMail); }).length;
    var out = '<h1>Roster</h1>';
    out += '<div class="bar">';
    out += '<div><label>Segment</label><select id="f-seg">' + SEGMENTS.map(function (s) {
      return '<option value="' + s[0] + '"' + (filters.seg === s[0] ? ' selected' : '') + '>' + esc(s[1]) + '</option>';
    }).join('') + '</select></div>';
    out += '<div><label>Search</label><input type="text" id="f-q" placeholder="Name, email, phone or group" value="' + esc(filters.q) + '"></div>';
    out += '<div><label>Track</label><select id="f-track">' + ['all', 'full', 'bambino'].map(function (t) {
      return '<option value="' + t + '"' + (filters.track === t ? ' selected' : '') + '>' + t + '</option>';
    }).join('') + '</select></div>';
    out += '<div><label>&nbsp;</label><a class="btn quiet small" href="#add">Add a registration</a></div>';
    var list = rows();
    var mails = emailsOf(list);
    out += '<div><label>&nbsp;</label><button type="button" class="btn quiet small" data-act="copy-emails"' +
      (mails.length ? '' : ' disabled') + ' title="The addresses of the rows shown, for a mail client">Copy ' +
      esc(mails.length) + (mails.length === 1 ? ' email' : ' emails') + '</button></div>';
    out += '</div>';
    out += '<p class="muted">' + esc(roster.counts.full + ' of ' + roster.caps.full + ' pilgrims, ' +
      roster.counts.bambino + ' of ' + roster.caps.bambino + ' Bambino, ' +
      roster.counts.waitlist + ' on the wait list, ' + drafts + ' drafts') +
      (rosterAge ? ' <span class="stale">kept in this browser, ' + esc(rosterAge) + '</span>' : '') + '</p>';
    out += '<table><thead><tr>' +
      head('name', 'Party') + head('state', 'State') + head('status', 'Status') + head('track', 'Track') +
      '<th class="num">People</th><th class="num">Walkers</th>' +
      head('created', 'Created') + head('fees', 'Fees', ' num') +
      '<th>Paid</th><th>Waiver</th><th>Check-ins</th><th>Flags</th></tr></thead><tbody>';
    list.forEach(function (r) {
      var names = (r.names || []).join('; ');
      var flags = '';
      if (r.exempt) flags += '<span class="tag">exempt</span>';
      if (r.assistance) flags += '<span class="tag">assist</span>';
      if (r.source === 'admin') flags += '<span class="tag">admin</span>';
      if (r.nonwalker) flags += '<span class="tag">non-walker</span>';
      if (r.knight_dame) flags += '<span class="tag">K/D</span>';
      if (r.volunteer) flags += '<span class="tag">vol</span>';
      if (r.refunded) flags += '<span class="tag">refunded</span>';
      out += '<tr' + (r.pending ? ' class="pending"' : '') + '><td><a href="#reg/' + esc(r.id) + '">' + esc(names || r.email || r.id) + '</a>' +
        '<div class="muted">' + (r.email ? '<a href="mailto:' + esc(r.email) + '">' + esc(r.email) + '</a>' : '') +
        (r.org ? ' &middot; ' + esc(r.org) : '') + '</div></td>' +
        '<td>' + esc(r.state) + '</td>' +
        '<td><span class="badge ' + esc(r.status) + '">' + esc(r.status) + '</span>' +
        (r.position ? ' <span class="muted">#' + esc(r.position) + '</span>' : '') + '</td>' +
        '<td>' + esc(r.track) + '</td>' +
        '<td class="num">' + esc(r.people) + '</td><td class="num">' + esc(r.walkers) + '</td>' +
        '<td>' + esc(day(r.created)) + '</td>' +
        '<td class="num">' + esc(money(r.fees)) + '</td>' +
        '<td>' + esc(r.paid === 'none' ? '' : r.paid) + '</td>' +
        '<td>' + esc(r.waiver === 'none' ? '' : r.waiver) + '</td>' +
        '<td>' + ticks(r) + '</td>' +
        '<td>' + flags + '</td></tr>';
    });
    out += '</tbody></table>';
    if (!list.length) {
      out += '<p class="muted">' +
        (all.length ? 'No registrations match this filter.' : 'No registrations yet.') + '</p>';
    }
    return out;
  }

  // ---- one registration ----
  function paymentCard(r) {
    var p = r.payment || {};
    var out = '<div class="card"><h3>Payment</h3><dl class="kv">' +
      '<dt>Method</dt><dd>' + esc(p.method) + '</dd>' +
      '<dt>Amount</dt><dd>' + esc(money(p.amount)) + '</dd>' +
      '<dt>Gift</dt><dd>' + esc(money(p.gift)) + '</dd>' +
      '<dt>Paid at</dt><dd>' + esc(when(p.at)) + '</dd>' +
      '<dt>Reference</dt><dd>' + esc(p.ref) + '</dd>' +
      '<dt>Refunded</dt><dd>' + (p.refunded ? 'yes' : 'no') + '</dd>' +
      '<dt>Note</dt><dd>' + esc(p.note) + '</dd></dl>';
    if (r.status === 'payment' || r.status === 'assistance') {
      out += '<h3>Record a payment</h3>' +
        '<label>Method<select id="pay-method"><option value="check">check</option>' +
        '<option value="cash">cash</option><option value="other">other</option></select></label>' +
        '<div class="row">' +
        '<label>Amount<input type="number" id="pay-amount" step="0.01" min="0" value="' + esc((Number(r.fees) / 100).toFixed(2)) + '"></label>' +
        '<label>Gift above the fee<input type="number" id="pay-gift" step="0.01" min="0" value="0.00"></label></div>' +
        '<label>Reference<input type="text" id="pay-ref"></label>' +
        '<label>Note<input type="text" id="pay-note"></label>' +
        '<p><button type="button" class="btn" data-act="pay">Record this payment</button></p>';
    }
    if (p.method && p.method !== 'none' && !p.refunded) {
      out += '<p><button type="button" class="btn danger small" data-act="refund">Mark this payment refunded</button></p>';
    }
    return out + '</div>';
  }
  function waiverCard(r) {
    var w = r.waiver || {};
    var out = '<div class="card"><h3>Waiver</h3><dl class="kv">' +
      '<dt>Method</dt><dd>' + esc(w.method) + '</dd>' +
      '<dt>Status</dt><dd>' + esc(w.status) + '</dd>' +
      '<dt>Envelope</dt><dd>' + esc(w.envelope) + '</dd>' +
      '<dt>Signed at</dt><dd>' + esc(when(w.at)) + '</dd></dl><div class="actions">';
    if (r.status !== 'draft' && r.status !== 'cancelled') {
      out += '<button type="button" class="btn small" data-act="waiver-paper">They signed on paper</button>';
    }
    out += '<button type="button" class="btn quiet small" data-act="recheck-waiver">Check whether they have signed</button>';
    return out + '</div></div>';
  }
  function actionsCard(r) {
    var out = '<div class="card"><h3>Actions</h3><div class="actions">';
    if (r.status === 'waitlist') out += '<button type="button" class="btn small" data-act="promote">Offer them a spot</button>';
    if (r.status === 'assistance') {
      out += '<button type="button" class="btn small" data-act="assist-yes">Approve assistance</button>' +
        '<button type="button" class="btn quiet small" data-act="assist-no">Decline assistance</button>';
    }
    if (r.status !== 'draft' && r.status !== 'cancelled') {
      out += '<button type="button" class="btn danger small" data-act="cancel">Cancel this registration</button>';
    }
    if (r.status === 'cancelled' && r.prior) out += '<button type="button" class="btn small" data-act="reinstate">Put it back</button>';
    out += '</div>';
    if (r.status !== 'draft' && r.status !== 'cancelled') {
      out += '<label>Cancellation note<input type="text" id="cancel-note"></label>';
    }
    out += '<h3>Email</h3><div class="actions">' +
      '<select id="tpl">' + TEMPLATES.map(function (t) { return '<option value="' + t + '">' + esc(t) + '</option>'; }).join('') + '</select>' +
      '<button type="button" class="btn small" data-act="resend">Send this email again</button></div>';
    return out + '</div>';
  }
  // +en-person carries each person's check-ins, so the organizer sees
  // who was there, when, and who tapped, and can take one back
  function checkinCard(r) {
    var out = '<div class="card"><h3>Check-ins</h3>';
    var any = false;
    (r.people || []).forEach(function (p, i) {
      var got = p.checkins || {};
      var mine = DAYS.filter(function (d) { return got[d[0]]; });
      if (mine.length) any = true;
      out += '<p><strong>' + esc(p.first + ' ' + p.last) + '</strong>';
      if (!mine.length) { out += ' <span class="muted">not checked in</span></p>'; return; }
      out += '</p><ul class="hist">';
      mine.forEach(function (d) {
        var c = got[d[0]];
        out += '<li><span class="when">' + esc(when(c.at)) + '</span> ' + esc(d[1]) +
          ', by ' + esc(c.by) +
          ' <button type="button" class="btn quiet small" data-act="undo-checkin" data-day="' +
          esc(d[0]) + '" data-i="' + i + '">Undo</button></li>';
      });
      out += '</ul>';
    });
    if (!any) out += '<p class="muted">Nobody in this party has been checked in yet.</p>';
    return out + '</div>';
  }
  function historyCard(r) {
    var h = (r.history || []).slice().reverse();
    var out = '<div class="card"><h3>History</h3><ul class="hist">';
    h.forEach(function (s) {
      out += '<li><span class="when">' + esc(when(s.at)) + '</span> ' + esc(s.by) + ' &middot; ' + esc(s.what) + '</li>';
    });
    if (!h.length) out += '<li class="muted">Nothing has happened to this registration yet.</li>';
    return out + '</ul></div>';
  }
  function detailView() {
    var r = detail;
    var out = '<h1>' + esc((r.people || []).map(function (p) { return p.first + ' ' + p.last; }).join(', ') || r.id) + '</h1>';
    out += '<p><a href="#roster">Back to the roster</a> &middot; <span class="muted">' + esc(r.id) + '</span></p>';
    var live = r.status !== 'draft' && r.status !== 'cancelled';
    out += '<div class="two"><div>' + partyForm(model) +
      (live ? '<div class="actions"><button type="button" class="btn" data-act="save">Save changes</button></div>'
            : '<p class="help">A ' + esc(r.status) + ' registration cannot be edited here.</p>') + '</div><div>';
    out += '<div class="card' + (r.pending ? ' pending' : '') + '"><h3>Status</h3><p><span class="badge ' + esc(r.status) + '">' + esc(r.status) + '</span>' +
      (r.position ? ' <span class="muted">wait list #' + esc(r.position) + '</span>' : '') +
      (r.pending ? ' <span class="tag">saving</span>' : '') + '</p>' +
      '<dl class="kv"><dt>Track</dt><dd>' + esc(r.track) + '</dd>' +
      '<dt>Came from</dt><dd>' + esc(r.source) + '</dd>' +
      '<dt>Fees</dt><dd>' + esc(money(r.fees)) + '</dd>' +
      '<dt>Created</dt><dd>' + esc(when(r.created)) + '</dd>' +
      '<dt>Last changed</dt><dd>' + esc(when(r.updated)) + '</dd>' +
      '<dt>Exempt from the caps</dt><dd>' + (r.exempt ? 'yes' : 'no') + '</dd>' +
      (r.prior ? '<dt>Was</dt><dd>' + esc(r.prior) + '</dd>' : '') + '</dl></div>';
    out += paymentCard(r) + waiverCard(r) + actionsCard(r) + checkinCard(r) + historyCard(r);
    return out + '</div></div>';
  }
  function addView() {
    var out = '<h1>Add a registration</h1><p class="muted">The registration window and the track caps do not apply here. This one draws on the late-add pool.</p>';
    out += '<div class="two"><div>' + partyForm(model) + '</div><div>';
    var onPaper = !!model.waiver_paper;
    out += '<div class="card"><h3>What you took from them</h3>' +
      box('waiver_paper', 'Waiver signed on paper', model.waiver_paper) +
      '<label>Paid by<select data-k="pay_method"' + (onPaper ? '' : ' disabled') + '><option value="">none</option>' +
      ['check', 'cash', 'other'].map(function (t) {
        return '<option value="' + t + '"' + (model.pay_method === t ? ' selected' : '') + '>' + t + '</option>';
      }).join('') + '</select></label>';
    if (onPaper && model.pay_method) {
      out += '<div class="row"><label>Amount<input type="number" step="0.01" min="0" data-k="pay_amount" value="' + esc(model.pay_amount) + '"></label>' +
        '<label>Gift<input type="number" step="0.01" min="0" data-k="pay_gift" value="' + esc(model.pay_gift) + '"></label></div>' +
        '<label>Reference<input type="text" data-k="pay_ref" value="' + esc(model.pay_ref) + '"></label>';
    }
    out += '<p class="help">Payment follows the waiver, so tick the paper waiver first. ' +
      'The ship refuses a payment without it rather than dropping it.</p>';
    out += '<p><button type="button" class="btn" data-act="submit-add">Add this registration</button></p></div>';
    return out + '</div></div>';
  }

  // ---- reports ----
  function planned(list) {
    var keys = ['fri', 'sat', 'sun', 'sun_ten', 'social_fri', 'social_sat', 'mass_fri', 'holy_hour', 'bus', 'first_bsc', 'children', 'knight_dame', 'volunteer'];
    var sum = { people: 0, walkers: 0 };
    keys.forEach(function (k) { sum[k] = 0; });
    list.forEach(function (r) {
      sum.people += Number(r.people) || 0;
      sum.walkers += Number(r.walkers) || 0;
      keys.forEach(function (k) { sum[k] += Number((r.plan || {})[k]) || 0; });
    });
    return sum;
  }
  function meter(n, cap) {
    var pct = cap ? Math.min(100, Math.round(100 * n / cap)) : 0;
    return '<div class="meter"><i class="' + (n > cap ? 'over' : '') + '" style="width:' + pct + '%"></i></div>';
  }
  function line(label, n, cap) {
    return '<p>' + esc(label) + ': <strong>' + esc(n) + '</strong> of ' + esc(cap) + '</p>' + meter(n, cap);
  }
  function tally(list, key) {
    var by = {};
    list.forEach(function (r) { var k = r[key] || ''; by[k] = (by[k] || 0) + 1; });
    return by;
  }
  function barlist(pairs, total) {
    var out = '<div class="barlist">';
    pairs.forEach(function (p) {
      var pct = total ? Math.round(100 * p[1] / total) : 0;
      out += '<div><span>' + esc(p[0] || '(none)') + '</span><span class="b" style="width:' + pct + '%"></span><span>' +
        esc(p[1]) + (total ? ' (' + pct + '%)' : '') + '</span></div>';
    });
    return out + '</div>';
  }
  function reportsView() {
    var all = roster.regs || [];
    var live = all.filter(function (r) {
      return r.status === 'complete' || r.status === 'assistance' || r.status === 'waiver' || r.status === 'payment';
    });
    var plan = planned(live);
    var caps = roster.caps || {};
    var sunCap = Number(getPath(settingsDoc || {}, 'caps.sunday')) || SHRINE;
    var out = '<h1>Reports</h1>';
    out += '<p class="actions"><a class="btn quiet small" href="' + ADMIN + '/export/people.csv">people.csv</a>' +
      '<a class="btn quiet small" href="' + ADMIN + '/export/regs.csv">regs.csv</a></p>';
    out += '<div class="grid3">';
    out += '<div class="card"><h3>Against the caps</h3>' +
      line('Full track', roster.counts.full, caps.full) +
      line('Bambino', roster.counts.bambino, caps.bambino) +
      line('Friday social', roster.counts.social_fri, caps.social_fri) +
      line('Saturday social', roster.counts.social_sat, caps.social_sat) +
      line('Late adds', roster.counts.late, caps.late_adds) +
      '<p>Wait list: <strong>' + esc(roster.counts.waitlist) + '</strong></p></div>';
    var byStatus = tally(all, 'status');
    var byTrack = tally(all, 'track');
    out += '<div class="card"><h3>By status</h3><table><tbody>';
    Object.keys(byStatus).sort().forEach(function (k) {
      out += '<tr><td>' + esc(k) + '</td><td class="num">' + esc(byStatus[k]) + '</td></tr>';
    });
    out += '</tbody></table><h3>By track</h3><table><tbody>';
    Object.keys(byTrack).sort().forEach(function (k) {
      out += '<tr><td>' + esc(k) + '</td><td class="num">' + esc(byTrack[k]) + '</td></tr>';
    });
    out += '</tbody></table></div>';
    var pay = {};
    all.forEach(function (r) {
      var k = r.paid || 'none';
      if (k === 'none') return;
      pay[k] = pay[k] || { amount: 0, gift: 0, n: 0 };
      pay[k].amount += Number(r.amount) || 0;
      pay[k].gift += Number(r.gift) || 0;
      pay[k].n += 1;
    });
    out += '<div class="card"><h3>Payments</h3><table><thead><tr><th>Method</th><th class="num">How many</th>' +
      '<th class="num">Amount</th><th class="num">Gift</th></tr></thead><tbody>';
    Object.keys(pay).sort().forEach(function (k) {
      out += '<tr><td>' + esc(k) + '</td><td class="num">' + esc(pay[k].n) + '</td><td class="num">' +
        esc(money(pay[k].amount)) + '</td><td class="num">' + esc(money(pay[k].gift)) + '</td></tr>';
    });
    if (!Object.keys(pay).length) out += '<tr><td class="muted" colspan="4">No payments recorded yet.</td></tr>';
    out += '</tbody></table></div>';
    var unpaid = live.filter(function (r) { return !r.paid || r.paid === 'none'; });
    var owed = unpaid.reduce(function (n, r) { return n + (Number(r.fees) || 0); }, 0);
    var unsigned = live.filter(function (r) { return r.waiver !== 'completed'; });
    var heads = unpaid.reduce(function (n, r) { return n + (Number(r.people) || 0); }, 0);
    out += '<div class="card"><h3>Still owing</h3><dl class="kv">' +
      '<dt>Unpaid</dt><dd>' + esc(unpaid.length) + ' registrations, ' + esc(heads) + ' people, ' +
      esc(money(owed)) + ' in fees</dd>' +
      '<dt>Unsigned</dt><dd>' + esc(unsigned.length) + ' registrations without a completed waiver</dd>' +
      '</dl><p class="help">Live registrations only, so a draft or a cancelled one is left out.</p></div>';
    out += '</div>';

    // planned per day per activity, against the actual counts when they
    // exist. The checked-in figure counts the rows the volunteers' app
    // works from, which is every row but a draft, so it agrees with the
    // planned block that app shows.
    var counted = all.filter(function (r) { return r.status !== 'draft'; });
    var cd = countsDoc || {};
    var plans = {
      fri: { walk: plan.fri, mass: plan.mass_fri, holy_hour: plan.holy_hour, social: plan.social_fri, bus: plan.bus },
      sat: { walk: plan.sat, mass: 0, holy_hour: 0, social: plan.social_sat, bus: plan.bus },
      sun: { walk: plan.sun, mass: 0, holy_hour: 0, social: 0, bus: plan.bus }
    };
    out += '<h2>Planned and actual, per day</h2><table><thead><tr><th>Day</th>' +
      ACTS.map(function (a) { return '<th class="num">' + esc(a[1]) + '</th>'; }).join('') +
      '<th class="num">Checked in</th></tr></thead><tbody>';
    DAYS.forEach(function (d) {
      out += '<tr><td>' + esc(d[1]) + '</td>';
      ACTS.forEach(function (a) {
        var want = plans[d[0]][a[0]] || 0;
        var got = getPath(cd, d[0] + '.' + a[0] + '.count');
        out += '<td class="num">' + esc(want) + (got === undefined || got === null || got === '' ? '' : ' / ' + esc(got)) + '</td>';
      });
      var seen = counted.reduce(function (n, r) { return n + (Number((r.checked || {})[d[0]]) || 0); }, 0);
      var self = counted.reduce(function (n, r) { return n + (Number((r.self || {})[d[0]]) || 0); }, 0);
      out += '<td class="num">' + esc(seen) + (seen ? ' <span class="muted">(' + esc(self) + ' themselves)</span>' : '') + '</td></tr>';
    });
    out += '</tbody></table><p class="help">Planned from the registrations, actual from the counts screen, ' +
      'checked in from the volunteers\' app. ' +
      'Mass and the Holy Hour are Friday choices and the bus is a party need, so those figures repeat rather than split by day.</p>';
    out += '<p>Sunday at the Shrine: <strong>' + esc(plan.sun) + '</strong> of ' + esc(sunCap) + ' across both tracks</p>' + meter(plan.sun, sunCap);
    out += '<p class="muted">' + esc(plan.people + ' people planned, ' + plan.walkers + ' walking, ' +
      plan.children + ' children, ' + plan.first_bsc + ' first time, ' + plan.sun_ten + ' walking the full Sunday') + '</p>';

    out += '<div class="grid3">';
    var states = {};
    live.forEach(function (r) { var k = String(r.state || '').toUpperCase(); states[k] = (states[k] || 0) + (Number(r.people) || 0); });
    var topStates = Object.keys(states).map(function (k) { return [k, states[k]]; })
      .sort(function (a, b) { return b[1] - a[1]; }).slice(0, 10);
    out += '<div class="card"><h3>By state, top 10</h3>' + barlist(topStates, plan.people) + '</div>';
    var orgs = {};
    live.forEach(function (r) { var k = String(r.org || ''); orgs[k] = (orgs[k] || 0) + (Number(r.people) || 0); });
    var topOrgs = Object.keys(orgs).map(function (k) { return [k, orgs[k]]; })
      .sort(function (a, b) { return b[1] - a[1]; }).slice(0, 12);
    out += '<div class="card"><h3>By organization</h3>' + barlist(topOrgs, plan.people) + '</div>';
    var perDay = {};
    all.forEach(function (r) { var k = day(r.created); if (k) perDay[k] = (perDay[k] || 0) + 1; });
    var days = Object.keys(perDay).sort();
    if (days.length) {
      // a day nobody registered is a real zero, so the run has no gaps
      var last = day(roster.now) > days[days.length - 1] ? day(roster.now) : days[days.length - 1];
      var walk = Date.parse(days[0] + 'T00:00:00Z');
      var stop = Date.parse(last + 'T00:00:00Z');
      days = [];
      while (walk <= stop && days.length < 400) {
        var k2 = new Date(walk).toISOString().slice(0, 10);
        if (perDay[k2] === undefined) perDay[k2] = 0;
        days.push(k2);
        walk += 86400000;
      }
    }
    var most = days.reduce(function (m, k) { return Math.max(m, perDay[k]); }, 0);
    out += '<div class="card"><h3>Registrations per day</h3>' +
      barlist(days.map(function (k) { return [k, perDay[k]]; }), most) + '</div>';
    return out + '</div>';
  }

  // ---- counts, copy, settings, backup ----
  // the day's activities: the two Sunday walk starts are counted beside
  // the rest, the same grid the volunteers' app shows
  function actsFor(d) {
    return d === 'sun' ? ACTS.concat(SUN_ACTS) : ACTS;
  }
  // ---- the day: who is here ----
  // the event's day today, from the browser's local date the way the
  // volunteers' app picks it; Friday outside the event
  function todayEvent() {
    var days = getPath(settingsDoc || {}, 'event.days') || [];
    if (typeof days === 'string') days = days.split('\n').map(function (x) { return x.trim(); }).filter(Boolean);
    var d = new Date(), p = function (n) { return (n < 10 ? '0' : '') + n; };
    var today = d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
    var i = days.indexOf(today);
    return i >= 0 && i < DAYS.length ? DAYS[i][0] : '';
  }
  function todayKey() { return todayEvent() || 'fri'; }
  // a party is expected that day when someone in it walks it or has
  // its social, the same rule the ship's expected count uses
  function expectedToday(r) {
    return (r.people || []).some(function (p) { return p.walks || p.social; });
  }
  function dayRows() {
    var rows = (dayDoc && dayDoc.rows) || [];
    return rows.filter(function (r) {
      if (r.status !== 'complete') return false;
      var people = r.people || [];
      var here = people.filter(function (p) { return p.checked; }).length;
      // the day's own segments show parties expected today; a family
      // that walks only Sunday is under "everyone" on Friday
      if (dayFilters.seg !== 'all' && !expectedToday(r)) return false;
      if (dayFilters.seg === 'missing' && here >= people.length) return false;
      if (dayFilters.seg === 'absent' && here) return false;
      if (dayFilters.seg === 'here' && here < people.length) return false;
      return matches({ email: r.email, id: r.rid, names: people.map(function (p) { return p.last + ', ' + p.first; }) }, dayFilters.q);
    });
  }
  function byWords(by) {
    if (by === 'pilgrim') return 'themselves';
    return String(by || '').replace(/^admin:/, '') || 'a volunteer';
  }
  function dayView() {
    var d = dayDoc || {};
    var day = d.day || 'fri';
    var label = (DAYS.filter(function (x) { return x[0] === day; })[0] || DAYS[0])[1];
    var expected = Number(d.expected) || 0, done = Number(d.done) || 0;
    var pct = expected ? Math.round(100 * done / expected) : 0;
    var complete = (d.rows || []).filter(function (r) { return r.status === 'complete'; });
    var absent = complete.filter(function (r) { return expectedToday(r) && !(r.people || []).some(function (p) { return p.checked; }); }).length;
    var today = todayEvent();
    var isToday = today === day;
    var out = '<h1>' + esc(label) + '</h1>';
    out += '<p class="actions">' + DAYS.map(function (x) {
      return '<a class="btn small' + (x[0] === day ? '' : ' quiet') + '" href="#day/' + x[0] + '">' + esc(x[1]) + '</a>';
    }).join('') + '</p>';
    out += '<div class="count"><strong>' + esc(done) + '</strong> of ' + esc(expected) + ' expected ' + esc(label) +
      ' checked in, <strong>' + esc(pct) + '%</strong>' + meter(done, expected) + '<span class="muted">' + esc(absent) +
      (absent === 1 ? ' party' : ' parties') + ' not here yet</span></div>';
    // the morning's links. They go out on their day: another day's tab
    // needs the organizer to say so
    var running = !!(mailing && mailing.running);
    var canSend = !running && (isToday || dayFilters.force);
    out += '<div class="card mailbox"><div class="actions">' +
      '<button type="button" class="btn small" data-act="checkin-mail"' + (canSend ? '' : ' disabled') + '>Email ' + esc(label) + '\'s check-in links</button>' +
      '<label class="check"><input type="checkbox" id="d-again"' + (dayFilters.again ? ' checked' : '') + '><span>Send again to everyone who already got one</span></label>' +
      (isToday ? '' : '<label class="check"><input type="checkbox" id="d-force"' + (dayFilters.force ? ' checked' : '') + '><span>It is not ' + esc(label) + ' yet. Send anyway</span></label>') +
      '</div><p class="help" id="mail-said">' + esc(mailSaid(label)) + '</p></div>';
    out += '<div class="bar">';
    out += '<div><label>Show</label><select id="d-seg">' + [['missing', 'someone missing'], ['absent', 'nobody here yet'], ['here', 'everyone here'], ['all', 'everyone, any day']].map(function (s2) {
      return '<option value="' + s2[0] + '"' + (dayFilters.seg === s2[0] ? ' selected' : '') + '>' + esc(s2[1]) + '</option>';
    }).join('') + '</select></div>';
    out += '<div><label>Search</label><input type="text" id="d-q" placeholder="Name or email" value="' + esc(dayFilters.q) + '"></div>';
    out += '</div>';
    var list = dayRows();
    out += '<table><thead><tr><th>Party</th><th>Wristband</th><th>Check in</th></tr></thead><tbody>';
    list.forEach(function (r) {
      var people = r.people || [];
      var left = people.filter(function (p) { return !p.checked; });
      out += '<tr' + (r.pending ? ' class="pending"' : '') + '><td>';
      people.forEach(function (p) {
        out += '<div>' + (p.checked ? '<span class="tick">&#10003;</span> ' : '<span class="notick">&#9675;</span> ') +
          '<a href="#reg/' + esc(r.rid) + '">' + esc(p.first + ' ' + p.last) + '</a>' +
          (p.checked ? '<span class="muted"> ' + esc(byWords(p.by)) + ', ' + esc(clock(p.at)) + '</span>' : '') + '</div>';
      });
      out += '<div class="muted">' + esc(r.email) + '</div></td>';
      out += '<td>' + (r.wristband && r.wristband.ok ? '<span class="badge complete">wristband</span>' :
        '<span class="badge cancelled">' + esc((r.wristband || {}).why || 'no') + '</span>') + '</td>';
      out += '<td>';
      if (left.length > 1) {
        out += '<button type="button" class="btn small" data-act="day-checkin" data-rid="' + esc(r.rid) + '" data-all="1">Check in everyone</button> ';
      }
      left.forEach(function (p) {
        out += '<button type="button" class="btn quiet small" data-act="day-checkin" data-rid="' + esc(r.rid) + '" data-i="' + p.i + '">' +
          esc(people.length > 1 ? p.first : 'Check in') + '</button> ';
      });
      out += '</td></tr>';
    });
    out += '</tbody></table>';
    if (!list.length) {
      out += '<p class="muted">' + (!complete.length ? 'No complete registrations yet.' :
        dayFilters.q ? 'Nobody matches.' :
        dayFilters.seg === 'missing' || dayFilters.seg === 'absent' ? 'Everyone expected ' + esc(label) + ' is here.' :
        'Nobody yet.') + '</p>';
    }
    return out;
  }
  function clock(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    var h = d.getHours(), m = d.getMinutes();
    return ((h % 12) || 12) + ':' + (m < 10 ? '0' : '') + m + (h < 12 ? 'am' : 'pm');
  }
  function mailSaid(label) {
    var m = mailing;
    var stub = pub && pub.mode === 'stub' ? 'Rehearsal: no email leaves the ship. ' : '';
    if (!m) return stub + 'Sends the link to every complete party expected ' + (label || 'today') + ', not yet checked in, that has not had one.';
    if (m.running) return stub + 'Sent ' + m.sent + ', ' + m.remaining + ' to go';
    if (m.error) return stub + m.error;
    if (!m.sent) return stub + 'Sent 0 links: everyone had one already, or is checked in.';
    return stub + 'Sent ' + m.sent + (m.sent === 1 ? ' link.' : ' links.');
  }
  // the day's check-in, painted at once: the tick shows and the read
  // after the write confirms it
  function dayCheckin(rid, idxs, el) {
    var row = ((dayDoc || {}).rows || []).filter(function (r) { return r.rid === rid; })[0];
    if (!row) return;
    var at = new Date().toISOString();
    var was = JSON.parse(JSON.stringify(row));
    var wasDone = dayDoc.done;
    var added = 0;
    row.people.forEach(function (p) {
      if (idxs.indexOf(p.i) >= 0 && !p.checked) { p.checked = true; p.at = at; p.by = 'admin:' + actor; added += 1; }
    });
    if (expectedToday(row)) dayDoc.done = (Number(dayDoc.done) || 0) + added;
    row.pending = true;
    var paint = function () { if (route().name === 'day') render(dayView()); };
    paint();
    var free = spin(el);
    var back = function () { Object.assign(row, was); dayDoc.done = wasDone; row.pending = false; };
    writeApi('/checkin', { day: dayDoc.day, checkins: idxs.map(function (i) { return { rid: rid, i: i }; }) }).then(function (d) {
      free();
      // the ship answers 200 and names what it would not take
      if ((d.rejected || []).length) { back(); paint(); return say(d.rejected[0].why || 'The ship did not take that check-in.'); }
      row.pending = false;
      paint();
      setTimeout(function () { if (route().name === 'day') refresh(); }, 1200);
    }).catch(function (e) {
      free();
      back();
      paint();
      say(e.message);
    });
  }
  // press the route until nothing remains, saying how far it is
  function sendCheckinMail(day, again) {
    var mine = { running: true, sent: 0, remaining: 0 };
    mailing = mine;
    var paint = function () { if (route().name === 'day') render(dayView()); };
    paint();
    function once() {
      return write('/checkin-mail', { day: day, again: again }).then(function (d) {
        mine.sent += Number(d.sent) || 0;
        mine.remaining = Number(d.remaining) || 0;
        again = false;
        var said = document.getElementById('mail-said');
        if (said) said.textContent = mailSaid();
        // the writer takes a moment to land the last party's line, so
        // the next press waits for it rather than sending it twice
        if (mine.remaining > 0 && (Number(d.sent) || 0) > 0) {
          return new Promise(function (r) { setTimeout(r, 1500); }).then(once);
        }
        mine.running = false;
        dayFilters.again = false; dayFilters.force = false;
        paint();
      });
    }
    return once().catch(function (e) {
      mailing = { running: false, sent: mine.sent, remaining: 0, error: e.message };
      paint();
    });
  }
  function countsView() {
    var cd = countsDoc || {};
    var out = '<h1>Counts</h1><p class="muted">What actually happened, per day and per activity.</p>';
    DAYS.forEach(function (d) {
      out += '<h2>' + esc(d[1]) + '</h2><div class="grid3">';
      actsFor(d[0]).forEach(function (a) {
        var base = d[0] + '.' + a[0];
        out += '<div class="card"><h3>' + esc(a[1]) + '</h3>' +
          field(base + '.count', 'Count', getPath(cd, base + '.count'), 'number') +
          field(base + '.time', 'Time', getPath(cd, base + '.time')) +
          field(base + '.note', 'Note', getPath(cd, base + '.note')) + '</div>';
      });
      out += '</div>';
    });
    return out + '<div class="actions"><button type="button" class="btn" data-act="save-counts">Save the counts</button></div>';
  }
  // the email templates, and only those. An email is on no page an
  // organizer can open, so it cannot be edited in place; every other
  // string is edited on the public page with Edit text.
  function emailsView() {
    var by = mailGroups(copyDoc);
    var names = Object.keys(by).sort();
    var out = '<h1>Emails</h1><p class="muted">The templates the ship sends. ' +
      'Every other string a pilgrim reads is edited on the public page itself: ' +
      'open it as the owner and press Edit text.</p>';
    if (!names.length) return out + '<p class="muted">No email templates yet.</p>';
    names.forEach(function (n) {
      var subj = by[n].subject, body = by[n].body;
      out += '<div class="card mail"><h3>' + esc(String(n).replace(/_/g, ' ')) + '</h3><div class="two">';
      out += '<div>' + (subj ? '<label>Subject<input type="text" data-copy="' + esc(subj) + '" value="' +
        esc(copyDoc[subj]) + '"></label>' : '<p class="help">This email has no subject stored.</p>') + '</div>';
      out += '<div>';
      if (body) {
        out += '<label>Body<textarea data-copy="' + esc(body) + '">' + esc(copyDoc[body]) + '</textarea></label>' +
          '<p class="help">Placeholders: ' + esc(varsOf(copyWas ? copyWas[body] : copyDoc[body]).join(' ') || 'none') +
          '. The ship fills them by name, so keep every one.</p>';
      } else {
        out += '<p class="help">This email has no body stored.</p>';
      }
      out += '</div></div><div class="actions"><button type="button" class="btn small" data-act="save-mail" data-mail="' +
        esc(n) + '">Save this email</button></div></div>';
    });
    return out;
  }
  function settingsView() {
    var s = settingsDoc || {};
    // the Shrine capacity is reported, not enforced, so the document
    // often arrives without it. Seed it, or the first Save stores 0.
    if (getPath(s, 'caps.sunday') === undefined || getPath(s, 'caps.sunday') === null) {
      setPath(s, 'caps.sunday', SHRINE);
    }
    var out = '<h1>Settings</h1>';
    out += '<div class="card"><h3>Event</h3>' +
      field('event.name', 'Name', getPath(s, 'event.name')) +
      field('event.utc_offset_hours', 'Hours from UTC', getPath(s, 'event.utc_offset_hours'), 'number', ' step="1" min="-12" max="14"') +
      '<p class="help">-5 in December for Florida. The ship uses it to know which event day it is.</p>' +
      '<label>Days, one per line<textarea data-k="event.days">' + esc((getPath(s, 'event.days') || []).join('\n')) + '</textarea></label>' +
      field('public_url', 'Public URL', s.public_url) + '</div>';
    out += '<div class="card"><h3>Fees, in dollars</h3><div class="row">' +
      field('fees.full', 'Full track', ((Number(getPath(s, 'fees.full')) || 0) / 100).toFixed(2), 'number', ' step="0.01"') +
      field('fees.bambino', 'Bambino', ((Number(getPath(s, 'fees.bambino')) || 0) / 100).toFixed(2), 'number', ' step="0.01"') +
      '</div></div>';
    out += '<div class="card"><h3>Caps</h3><div class="row3">' +
      field('caps.full', 'Full track', getPath(s, 'caps.full'), 'number') +
      field('caps.bambino', 'Bambino', getPath(s, 'caps.bambino'), 'number') +
      field('caps.late_adds', 'Late adds', getPath(s, 'caps.late_adds'), 'number') + '</div><div class="row3">' +
      field('caps.social_fri', 'Friday social', getPath(s, 'caps.social_fri'), 'number') +
      field('caps.social_sat', 'Saturday social', getPath(s, 'caps.social_sat'), 'number') +
      field('caps.sunday', 'Sunday at the Shrine', getPath(s, 'caps.sunday'), 'number') +
      '</div><p class="help">The Shrine capacity is reported, not enforced.</p></div>';
    out += '<div class="card"><h3>Window</h3><div class="row3">' +
      field('window.open', 'Opens', toLocal(getPath(s, 'window.open')), 'datetime-local') +
      field('window.close', 'Closes', toLocal(getPath(s, 'window.close')), 'datetime-local') +
      field('window.change_cutoff', 'Changes close', toLocal(getPath(s, 'window.change_cutoff')), 'datetime-local') + '</div>' +
      field('hold_hours', 'Hold hours', s.hold_hours, 'number') + '</div>';
    out += '<div class="card"><h3>Organizations the form suggests</h3>' +
      '<label>One per line<textarea data-k="orgs">' + esc((s.orgs || []).join('\n')) + '</textarea></label></div>';
    out += '<div class="card"><h3>Providers</h3>' +
      '<label>Mode<select data-k="providers.mode">' + ['stub', 'live'].map(function (t) {
        return '<option value="' + t + '"' + (getPath(s, 'providers.mode') === t ? ' selected' : '') + '>' + t + '</option>';
      }).join('') + '</select></label>' +
      field('mail.from', 'Mail from', getPath(s, 'mail.from')) +
      field('mail.resend_key', 'Resend key', getPath(s, 'mail.resend_key'), 'password') +
      field('stripe.secret_key', 'Stripe secret key', getPath(s, 'stripe.secret_key'), 'password') +
      '<div class="row">' +
      field('docusign.integration_key', 'DocuSign integration key', getPath(s, 'docusign.integration_key'), 'password') +
      field('docusign.secret', 'DocuSign secret', getPath(s, 'docusign.secret'), 'password') + '</div><div class="row">' +
      field('docusign.account_id', 'DocuSign account id', getPath(s, 'docusign.account_id')) +
      field('docusign.template_id', 'DocuSign template id', getPath(s, 'docusign.template_id')) + '</div><div class="row">' +
      field('docusign.base_uri', 'DocuSign base URI', getPath(s, 'docusign.base_uri')) +
      field('docusign.auth_host', 'DocuSign auth host', getPath(s, 'docusign.auth_host')) + '</div>' +
      '<p class="help">A key shown as four stars is stored. Leave it alone to keep it.</p></div>';
    return out + '<div class="actions"><button type="button" class="btn" data-act="save-settings">Save the settings</button></div>';
  }
  function backupView() {
    var out = '<h1>Backup</h1>';
    out += '<div class="card"><h3>Download</h3><p class="actions">' +
      '<a class="btn quiet small" href="' + ADMIN + '/export/bundle.json">JSON bundle</a>' +
      '<a class="btn quiet small" href="' + ADMIN + '/export/bundle.jam">jam</a>' +
      '<a class="btn quiet small" href="' + ADMIN + '/export/people.csv">people.csv</a>' +
      '<a class="btn quiet small" href="' + ADMIN + '/export/regs.csv">regs.csv</a></p>' +
      '<p class="help">The jam is the emergency copy. Secrets are masked in both bundles and a restore keeps the stored ones.</p></div>';
    out += '<div class="card"><h3>Import</h3>' +
      '<label>A .json bundle or a .jam<input type="file" id="file" accept=".json,.jam"></label>' +
      '<p class="actions"><button type="button" class="btn small" data-act="inspect"' + (fileBody ? '' : ' disabled') + '>Read the file</button>' +
      '<button type="button" class="btn danger small" data-act="apply"' + (dry ? '' : ' disabled') + '>Restore</button></p>' +
      box2('wipe', 'Delete every registration the file does not name');
    if (dry) {
      out += '<dl class="kv">' +
        '<dt>Registrations</dt><dd>' + esc(dry.regs) + '</dd>' +
        '<dt>Complete</dt><dd>' + esc(dry.complete) + '</dd>' +
        '<dt>On the wait list</dt><dd>' + esc(dry.waitlist) + '</dd>' +
        '<dt>Cancelled</dt><dd>' + esc(dry.cancelled) + '</dd>' +
        '<dt>Earliest</dt><dd>' + esc(when(dry.earliest)) + '</dd>' +
        '<dt>Latest</dt><dd>' + esc(when(dry.latest)) + '</dd>' +
        '<dt>Event days</dt><dd>' + esc((dry.event_days || []).join(', ')) + '</dd>' +
        '<dt>Would overwrite</dt><dd>' + esc(dry.overwrite) + '</dd></dl>' +
        '<p class="help">A restore stamps every registration it writes as updated now, ' +
        'so the 48 hour hold starts again for each one.</p>';
    } else if (fileBody) {
      out += '<p class="muted">' + esc(fileName) + ' is ready. Read it before you restore from it.</p>';
    }
    return out + '</div>';
  }
  function box2(id, label) {
    return '<label class="check"><input type="checkbox" id="' + id + '"><span>' + esc(label) + '</span></label>';
  }

  // ---- routing ----
  function route() {
    var h = location.hash.replace(/^#\/?/, '') || 'roster';
    var parts = h.split('/');
    // the copy page became the emails page; an old link still lands
    return { name: parts[0] === 'copy' ? 'emails' : parts[0], id: parts[1] || '' };
  }
  function markNav() {
    var r = route();
    Array.prototype.forEach.call(document.querySelectorAll('#nav a'), function (a) {
      a.className = a.getAttribute('href') === '#' + r.name ? 'on' : '';
    });
  }
  function needSettings() {
    if (settingsDoc) return Promise.resolve(settingsDoc);
    return read('/settings').then(function (d) { settingsDoc = d; return d; });
  }
  // the whole roster is one big read, so a view that already has it in
  // memory works from that. The beacon and the minute timer drop it.
  function haveRoster() { return roster ? Promise.resolve(roster) : needRoster(); }
  function needStatus() {
    if (pub) return Promise.resolve(pub);
    return api(API + '/status').then(function (d) { pub = d; return d; });
  }
  function needCounts() {
    if (countsDoc) return Promise.resolve(countsDoc);
    return read('/counts').then(function (d) { countsDoc = d; return d; });
  }
  function needRoster() {
    return read('/regs').then(function (d) {
      roster = d;
      rosterAge = '';
      // the ship's own rows are kept, never the patched ones: a pending
      // row cached here would come back as fact on the next visit
      try { localStorage.setItem(RKEY, JSON.stringify({ at: Date.now(), doc: d })); } catch (e) { }
      keepPainted();
      return d;
    });
  }
  // the roster this browser saw last time, so the table is on screen
  // before the ship answers. Its age is in the line above it.
  function paintKept() {
    if (roster) return true;
    var kept = null;
    try { kept = JSON.parse(localStorage.getItem(RKEY) || 'null'); } catch (e) { kept = null; }
    if (!kept || !kept.doc || !kept.doc.regs) return false;
    roster = kept.doc;
    rosterAge = ageText(kept.at, Date.now());
    return true;
  }
  // a fetched roster does not know about the action this page painted a
  // moment ago, so that row is patched back on top of it
  function keepPainted() {
    if (!waitingOn || !detail || detail.id !== waitingOn.id || !detail.pending) return;
    var row = rowOf(waitingOn.id);
    if (row) putRow(patchRow(row, detail));
  }
  function rowOf(id) {
    return ((roster || {}).regs || []).filter(function (r) { return String(r.id) === String(id); })[0] || null;
  }
  function putRow(row) {
    if (!roster || !roster.regs || !row) return;
    roster.regs = roster.regs.map(function (r) { return String(r.id) === String(row.id) ? row : r; });
  }
  // a re-render replaces the inputs. The filter bar's are rebuilt with
  // their values from `filters`, so the one that had focus gets it back
  // with its caret where it was, and the roster can repaint under a
  // resting cursor.
  function render(html) {
    var had = document.activeElement, id = had ? had.id : '';
    var pos = had && /^[fd]-/.test(id) && had.setSelectionRange ? had.selectionStart : null;
    view.innerHTML = html;
    markNav();
    if (/^[fd]-/.test(id)) {
      var again = document.getElementById(id);
      if (again) {
        again.focus();
        if (pos !== null && again.setSelectionRange) {
          var at = Math.min(pos, again.value.length);
          try { again.setSelectionRange(at, at); } catch (e) { }
        }
      }
    }
  }
  function refresh() {
    var r = route();
    var mine = ++routeGen;
    // a read that answers after the organizer has moved on paints
    // nothing: its view is not the one on screen any more
    function paint(html) { if (mine === routeGen) render(html); }
    var p;
    if (r.name === 'reg' && r.id) {
      if (!detail || detail.id !== r.id) paint(loading());
      p = Promise.all([haveRoster(), read('/reg/' + encodeURIComponent(r.id))]).then(function (d) {
        var got = d[1];
        // an action this page painted outranks a copy the ship answered
        // before its writer had applied it, but only until the deadline:
        // a patch the writer refused would otherwise repaint for ever
        var mineToo = waitingOn && waitingOn.id === got.id;
        var verd = mineToo ? verdict(waitingOn, got, Date.now()) : 'settled';
        if (verd === 'waiting') {
          keepPainted();
          return paint(detailView());
        }
        if (mineToo) waitingOn = null;
        if (verd === 'stale') {
          // the writer refused it, so the ship's copy wins, row and all
          var row = rowOf(got.id);
          if (row) putRow(patchRow(row, got));
        }
        detail = got;
        model = fromReg(detail);
        before = JSON.parse(JSON.stringify(model));
        paint(detailView());
        if (verd === 'stale') refused();
      });
    } else if (r.name === 'add') {
      p = haveRoster().then(function () {
        if (!model || !model.isAdd) {
          model = blankParty('full');
          model.isAdd = true;
          model.waiver_paper = false;
          model.pay_method = ''; model.pay_amount = ''; model.pay_gift = '0.00'; model.pay_ref = '';
        }
        paint(addView());
      });
    } else if (r.name === 'reports') {
      // the reports are arithmetic over the roster this page already
      // holds, so opening the tab reads nothing it does not need
      if (!roster) paint(loading());
      p = Promise.all([haveRoster(), needSettings(), needCounts()]).then(function () {
        paint(reportsView());
      });
    } else if (r.name === 'day') {
      // the volunteers' roster route, with the day's two counts on it
      var want = r.id === 'sat' || r.id === 'sun' ? r.id : r.id === 'fri' ? 'fri' : '';
      if (!want) {
        p = needSettings().then(function () { location.hash = '#day/' + todayKey(); });
      } else {
        if (!dayDoc || dayDoc.day !== want) {
          paint(loading());
          if (mailing && !mailing.running) mailing = null;
          dayFilters.force = false;
        }
        p = Promise.all([needSettings(), needStatus(), api(API + '/checkin/roster?day=' + want)]).then(function (got) {
          dayDoc = got[2];
          paint(dayView());
        });
      }
    } else if (r.name === 'counts') {
      if (!countsDoc) paint(loading());
      p = read('/counts').then(function (d) { countsDoc = d; paint(countsView()); });
    } else if (r.name === 'emails') {
      if (!copyDoc) paint(loading());
      p = read('/copy').then(function (d) {
        copyDoc = d;
        copyWas = JSON.parse(JSON.stringify(d));
        paint(emailsView());
      });
    } else if (r.name === 'settings') {
      if (!settingsDoc) paint(loading());
      p = read('/settings').then(function (d) { settingsDoc = d; paint(settingsView()); });
    } else if (r.name === 'backup') {
      p = Promise.resolve().then(function () { paint(backupView()); });
    } else {
      // the rows this browser saw last time go up first, then the ship's
      if (paintKept()) { model = null; paint(rosterView()); } else paint(loading());
      p = needRoster().then(function () { model = null; paint(rosterView()); });
    }
    return p.then(function () {
      if (mine !== routeGen) return;
      // a refusal notice holds the line for its few seconds
      if (Date.now() >= noticeUntil) say('');
    }).catch(function (e) {
      if (mine !== routeGen) return;
      if (e.status === 403) {
        paint('<p class="bad">This ship refused the request. Log in as the owner and reload.</p>');
      } else {
        paint('<p class="bad">' + esc(e.message) + '</p>');
      }
    });
  }
  function later() { setTimeout(refresh, 400); }
  // ---- an action, painted before the ship has taken it ----
  // the registration and its roster row take the change at once, the
  // page renders, and the read that follows says whether it stuck
  function runAll(bodies, el) {
    if (!detail) return;
    var id = detail.id;
    var wasReg = JSON.parse(JSON.stringify(detail));
    var row = rowOf(id);
    var wasRow = row ? JSON.parse(JSON.stringify(row)) : null;
    var at = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
    var by = 'admin:' + actor;
    var painted = detail;
    bodies.forEach(function (b) {
      var next = patchReg(painted, b, by, at);
      if (next) painted = next;
    });
    var free = spin(el);
    // an op the page cannot paint, recheck-waiver among them, leaves
    // nothing local behind, so there is nothing to reconcile afterwards
    var local = painted !== detail;
    if (local) {
      detail = painted;
      model = fromReg(detail);
      before = JSON.parse(JSON.stringify(model));
      if (row) putRow(patchRow(row, detail));
      waitingOn = { id: id, body: bodies[bodies.length - 1], at: Date.now() };
      render(route().name === 'reg' ? detailView() : rosterView());
    }
    var chain = Promise.resolve();
    bodies.forEach(function (b) {
      chain = chain.then(function () { return write('/reg/' + encodeURIComponent(id), b); });
    });
    return chain.then(function () {
      free();
      say('Saved.', true);
      if (local) setTimeout(reconcile, 1200);
      else later();
    }).catch(function (e) {
      free();
      waitingOn = null;
      detail = wasReg;
      model = fromReg(detail);
      before = JSON.parse(JSON.stringify(model));
      if (wasRow) putRow(wasRow);
      render(route().name === 'reg' ? detailView() : rosterView());
      say(e.message);
    });
  }
  function run(body, el) { return runAll([body], el); }
  // read that one registration again and drop the pending mark once the
  // ship's copy shows the change. One timer, so the beacon and the
  // minute timer asking at once make one chain of reads, not two.
  var reTimer = null;
  function reconcile() {
    if (!waitingOn) return Promise.resolve();
    // typing since the save is not overwritten by the read that
    // confirms it; the read waits for the next Save or the next bump
    if (dirty) {
      clearTimeout(reTimer);
      reTimer = setTimeout(reconcile, 1200);
      return Promise.resolve();
    }
    var mine = waitingOn;
    return read('/reg/' + encodeURIComponent(mine.id)).then(function (d) {
      if (waitingOn !== mine) return;
      // past the deadline an unsettled patch is one the writer refused:
      // the local copy goes and the ship's takes its place
      var verd = verdict(mine, d, Date.now());
      if (verd === 'waiting') {
        clearTimeout(reTimer);
        reTimer = setTimeout(reconcile, 1200);
        return;
      }
      clearTimeout(reTimer);
      waitingOn = null;
      if (detail && detail.id === d.id) {
        detail = d;
        model = fromReg(detail);
        before = JSON.parse(JSON.stringify(model));
      }
      var row = rowOf(mine.id);
      if (row) putRow(patchRow(row, d));
      var name = route().name;
      if (name === 'reg') render(detailView());
      else if (name === 'roster') render(rosterView());
      if (verd === 'stale') refused();
    }).catch(function () { });
  }

  // ---- input ----
  view.addEventListener('input', onChange);
  view.addEventListener('change', onChange);
  function onChange(ev) {
    var el = ev.target;
    var k = el.getAttribute('data-k');
    if (el.id === 'f-seg') { filters.seg = el.value; return render(rosterView()); }
    if (el.id === 'f-track') { filters.track = el.value; return render(rosterView()); }
    if (el.id === 'f-q') { filters.q = el.value; if (view.querySelector('tbody')) render(rosterView()); return; }
    if (el.id === 'd-seg') { dayFilters.seg = el.value; return render(dayView()); }
    if (el.id === 'd-q') { dayFilters.q = el.value; return render(dayView()); }
    if (el.id === 'd-again') { dayFilters.again = el.checked; return; }
    if (el.id === 'd-force') { dayFilters.force = el.checked; return render(dayView()); }
    if (el.id === 'file') return pickFile(el);
    var copyKey = el.getAttribute('data-copy');
    if (copyKey && copyDoc) { copyDoc[copyKey] = el.value; dirty = true; return; }
    if (!k) return;
    var isBox = el.type === 'checkbox';
    if (ev.type === 'change' && !isBox && el.tagName !== 'SELECT') return;
    if (ev.type === 'input' && isBox) return;
    var val = isBox ? el.checked : el.value;
    var r = route();
    dirty = true;
    if (r.name === 'counts') { setPath(countsDoc, k, val); return; }
    if (r.name === 'settings') { setPath(settingsDoc, k, val); return; }
    if (!model) return;
    setPath(model, k, val);
    // a structural change re-renders; a keystroke does not
    if (k === 'together' || k === 'track' || k === 'pay_method' || k === 'waiver_paper') {
      render(r.name === 'add' ? addView() : detailView());
    }
  }
  function pickFile(el) {
    var f = el.files && el.files[0];
    dry = null; fileBody = null; fileName = '';
    if (!f) return render(backupView());
    fileName = f.name;
    if (/\.jam$/i.test(f.name)) {
      var fr = new FileReader();
      fr.onload = function () {
        var bytes = new Uint8Array(fr.result), s = '';
        for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
        fileBody = { jam: btoa(s) };
        render(backupView());
      };
      fr.readAsArrayBuffer(f);
    } else {
      f.text().then(function (txt) {
        try { fileBody = { bundle: JSON.parse(txt) }; }
        catch (e) { say('That file is not JSON.'); return; }
        render(backupView());
      });
    }
  }
  view.addEventListener('click', function (ev) {
    var th = ev.target.closest('th[data-sort]');
    if (th) {
      var col = th.getAttribute('data-sort');
      if (sortBy.col === col) sortBy.up = !sortBy.up; else { sortBy.col = col; sortBy.up = true; }
      return render(rosterView());
    }
    var el = ev.target.closest('[data-act]');
    if (!el) return;
    var a = el.getAttribute('data-act');
    var rid = detail ? detail.id : '';
    function pick(id) { var n = document.getElementById(id); return n ? n.value : ''; }
    function post(body) { return run(body, el); }
    if (a === 'add-person') { dirty = true; model.people.push(blankPerson()); return render(route().name === 'add' ? addView() : detailView()); }
    if (a === 'remove-person') { dirty = true; model.people.splice(+el.getAttribute('data-i'), 1); return render(route().name === 'add' ? addView() : detailView()); }
    if (a === 'day-checkin') {
      var drid = el.getAttribute('data-rid');
      var drow = ((dayDoc || {}).rows || []).filter(function (r) { return r.rid === drid; })[0];
      if (!drow) return;
      var idxs = el.getAttribute('data-all')
        ? drow.people.filter(function (p) { return !p.checked; }).map(function (p) { return p.i; })
        : [Number(el.getAttribute('data-i'))];
      return act(function () { dayCheckin(drid, idxs, el); });
    }
    if (a === 'checkin-mail') {
      return act(function () { sendCheckinMail((dayDoc || {}).day || 'fri', !!dayFilters.again); });
    }
    if (a === 'copy-emails') {
      var addrs = emailsOf(rows()).join(', ');
      if (!addrs) return;
      var freeCopy = spin(el);
      copyText(addrs).then(function () {
        freeCopy();
        say('Copied. Paste into the To line of an email.', true);
      }, function () {
        freeCopy();
        say('This browser would not copy. The addresses are in the console.');
        try { console.log(addrs); } catch (e) { }
      });
      return;
    }
    if (a === 'save') {
      return act(function () {
        // only what changed goes up. The party as an edit only when the
        // party moved: a note alone must not write an "edited" line,
        // restart a lapsed hold, or be refused for a full track.
        var bodies = [];
        if (JSON.stringify(partyInput(model)) !== JSON.stringify(partyInput(before))) bodies.push({ op: 'edit', input: partyInput(model) });
        if (!!model.exempt !== !!before.exempt) bodies.push({ op: 'exempt', on: !!model.exempt });
        if (String(model.notes) !== String(before.notes)) bodies.push({ op: 'note', notes: model.notes });
        if (!bodies.length) { dirty = false; return say('Nothing to save.', true); }
        dirty = false;
        runAll(bodies, el);
      });
    }
    if (a === 'pay') {
      return act(function () {
        post({
          op: 'pay', method: pick('pay-method'), amount: cents(pick('pay-amount')),
          gift: cents(pick('pay-gift')), ref: pick('pay-ref'), note: pick('pay-note')
        });
      });
    }
    if (a === 'refund') {
      if (!window.confirm('Mark this payment as refunded? The registration stays as it is and the roster flags it as refunded.')) return;
      return act(function () { post({ op: 'refund', note: 'refunded by ' + actor }); });
    }
    if (a === 'undo-checkin') {
      var undoDay = el.getAttribute('data-day');
      var undoI = Number(el.getAttribute('data-i'));
      return act(function () {
        var freeUndo = spin(el);
        writeApi('/checkin', { day: undoDay, checkins: [{ rid: rid, i: undoI, undo: true }] })
          .then(function () { freeUndo(); say('Check-in undone.', true); later(); })
          .catch(function (e) { freeUndo(); say(e.message); });
      });
    }
    if (a === 'waiver-paper') return act(function () { post({ op: 'waiver-paper' }); });
    if (a === 'recheck-waiver') return act(function () { post({ op: 'recheck-waiver' }); });
    if (a === 'promote') return act(function () { post({ op: 'promote' }); });
    if (a === 'assist-yes') return act(function () { post({ op: 'assist', approve: true }); });
    if (a === 'assist-no') return act(function () { post({ op: 'assist', approve: false }); });
    if (a === 'cancel') {
      if (!window.confirm('Cancel this registration for everyone in the party? Their spots are released. You can put it back afterwards.')) return;
      return act(function () { post({ op: 'cancel', note: pick('cancel-note') }); });
    }
    if (a === 'reinstate') {
      if (!window.confirm('Put this registration back to ' + detail.prior + '? It takes its spots again.')) return;
      return act(function () { post({ op: 'reinstate' }); });
    }
    if (a === 'resend') return act(function () { post({ op: 'resend', template: pick('tpl') }); });
    if (a === 'submit-add') {
      return act(function () {
        dirty = false;
        var body = { input: partyInput(model), exempt: !!model.exempt, waiver_paper: !!model.waiver_paper };
        if (model.pay_method && model.waiver_paper) {
          body.paid = {
            method: model.pay_method, amount: cents(model.pay_amount),
            gift: cents(model.pay_gift), ref: model.pay_ref, note: 'taken by ' + actor
          };
        }
        var freeAdd = spin(el);
        write('/add', body).then(function (d) {
          freeAdd();
          model = null;
          say(addedText(d.status), true);
          location.hash = '#reg/' + d.rid;
        }).catch(function (e) { freeAdd(); say(e.message); });
      });
    }
    if (a === 'save-counts') {
      return act(function () {
        dirty = false;
        var freeCounts = spin(el);
        say('Counts saved.', true);
        write('/counts', countsDoc, 'PUT').then(function () { freeCounts(); })
          .catch(function (e) { freeCounts(); say(e.message); });
      });
    }
    if (a === 'save-mail') {
      var name = el.getAttribute('data-mail');
      var group = mailGroups(copyDoc)[name] || {};
      var keys = Object.keys(group).map(function (k) { return group[k]; });
      return act(function () {
        var changed = keys.filter(function (k) { return String(copyDoc[k]) !== String((copyWas || {})[k]); });
        if (!changed.length) return say('Nothing changed in this email.', true);
        dirty = false;
        var gone = [];
        changed.forEach(function (k) {
          missingVars((copyWas || {})[k], copyDoc[k]).forEach(function (v) { if (gone.indexOf(v) < 0) gone.push(v); });
        });
        if (gone.length) {
          changed.forEach(function (k) { copyDoc[k] = (copyWas || {})[k]; });
          render(emailsView());
          return say('Put these back before saving: ' + gone.join(' '));
        }
        var freeMail = spin(el);
        say('Saved.', true);
        // each key is written on its own and settles on its own. One
        // refusal rolls back that key alone; the keys the ship took keep
        // their new string and the line names the ones it would not.
        var bad = [];
        Promise.all(changed.map(function (k) {
          return write('/copy/set', { key: k, value: String(copyDoc[k]) }).then(function () {
            copyWas[k] = copyDoc[k];
          }, function (e) {
            bad.push(k + ': ' + e.message);
            copyDoc[k] = (copyWas || {})[k];
          });
        })).then(function () {
          freeMail();
          if (!bad.length) return;
          render(emailsView());
          say(bad.join('; '));
        });
      });
    }
    if (a === 'save-settings') {
      return act(function () {
        dirty = false;
        var doc = JSON.parse(JSON.stringify(settingsDoc));
        ['fees.full', 'fees.bambino'].forEach(function (k) { setPath(doc, k, cents(getPath(settingsDoc, k))); });
        ['caps.full', 'caps.bambino', 'caps.social_fri', 'caps.social_sat', 'caps.late_adds', 'caps.sunday', 'hold_hours']
          .forEach(function (k) { setPath(doc, k, Number(getPath(settingsDoc, k)) || 0); });
        // a blank offset means Eastern, not Greenwich
        var off = getPath(settingsDoc, 'event.utc_offset_hours');
        setPath(doc, 'event.utc_offset_hours', off === '' || off === undefined || off === null ? -5 : Math.round(Number(off) || 0));
        ['window.open', 'window.close', 'window.change_cutoff']
          .forEach(function (k) { setPath(doc, k, fromLocal(getPath(settingsDoc, k))); });
        var days = getPath(settingsDoc, 'event.days');
        setPath(doc, 'event.days', (typeof days === 'string' ? days.split('\n') : days || [])
          .map(function (s) { return String(s).trim(); }).filter(Boolean));
        doc.orgs = (typeof settingsDoc.orgs === 'string' ? settingsDoc.orgs.split('\n') : settingsDoc.orgs || [])
          .map(function (s) { return String(s).trim(); }).filter(Boolean);
        var freeSet = spin(el);
        say('Settings saved.', true);
        write('/settings', doc, 'PUT').then(function () {
          freeSet();
          settingsDoc = null;
          later();
        }).catch(function (e) { freeSet(); say(e.message); });
      });
    }
    if (a === 'inspect') {
      if (!fileBody) return;
      return act(function () {
        var freeDry = spin(el);
        write('/import?dry=1', fileBody).then(function (d) { freeDry(); dry = d; say(''); render(backupView()); })
          .catch(function (e) { freeDry(); dry = null; say(e.message); render(backupView()); });
      });
    }
    if (a === 'apply') {
      if (!dry || !fileBody || !dry.confirm) return;
      var wipe = document.getElementById('wipe');
      var on = wipe && wipe.checked;
      return act(function () {
        // the button is disabled before the dialog opens, so the second
        // half of a double click never starts a second restore
        var freeApply = spin(el);
        if (!window.confirm('Restore ' + dry.regs + ' registrations, overwriting ' + dry.overwrite +
          (on ? ', and delete every registration the file does not name' : '') + '. ' +
          'Every restored registration is stamped as changed now, so its 48 hour hold starts again. ' +
          'Go ahead?')) return freeApply();
        write('/import?wipe=' + (on ? '1' : '0') + '&confirm=' + encodeURIComponent(dry.confirm), fileBody).then(function (d) {
          freeApply();
          dry = null; fileBody = null;
          say('Restored ' + d.applied + ' registrations.', true);
          later();
        }).catch(function (e) { freeApply(); say(e.message); });
      });
    }
  });

  // ---- the beacon, read raw the way orrery's page does ----
  function sseEvent(block) {
    var name = '', data = '';
    String(block).split('\n').forEach(function (ln) {
      if (ln.indexOf('event: ') === 0) name = ln.slice(7).trim();
      else if (ln.indexOf('data: ') === 0) data = ln.slice(6).trim();
    });
    return { name: name, data: data };
  }
  // a re-render replaces the inputs, so a bump waits while one has focus
  function editing() {
    var el = document.activeElement;
    if (dirty) return true;
    if (!el) return false;
    if (!promptEl.hidden) return true;
    // the filter bar is not an edit: render() keeps its focus and caret
    if (/^[fd]-/.test(el.id || '')) return false;
    return (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT') &&
      (view.contains(el) || promptEl.contains(el));
  }
  function bumped() {
    reconcile();
    if (editing()) return;
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(function () {
      if (editing()) return;
      roster = null; countsDoc = null;
      refresh();
    }, 300);
  }
  async function stream() {
    for (;;) {
      if (document.hidden) { await new Promise(function (r) { setTimeout(r, 1000); }); continue; }
      try {
        var resp = await fetch(KEEP, { headers: { Accept: 'text/event-stream' } });
        if (!resp.ok) {
          liveEl.className = 'dot off';
          await new Promise(function (r) { setTimeout(r, 30000); });
          continue;
        }
        liveEl.className = 'dot on';
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
            if (document.hidden) return;
            var parsed = sseEvent(ev);
            if (!parsed.name || parsed.name.slice(-4) !== '/rev') return;
            if (parsed.name.indexOf('old') === 0) {
              if (lastRev !== null && parsed.data && parsed.data !== lastRev) bumped();
              lastRev = parsed.data;
              return;
            }
            lastRev = parsed.data;
            bumped();
          });
        }
      } catch (e) { /* the stream severed: reconnect below */ }
      liveEl.className = 'dot off';
      await new Promise(function (r) { setTimeout(r, 3000); });
    }
  }

  // a view with unsaved typing is not left by accident: the move is put
  // back unless the organizer says to drop the typing
  window.addEventListener('hashchange', function () {
    if (restoring) { restoring = false; return; }
    if (dirty && !window.confirm('You have changes here that are not saved. Leave and lose them?')) {
      if (location.hash !== lastHash) { restoring = true; location.hash = lastHash; }
      return;
    }
    dirty = false;
    lastHash = location.hash;
    model = null; dry = null; refresh();
  });
  document.addEventListener('visibilitychange', function () { if (!document.hidden && !editing()) refresh(); });
  setInterval(function () {
    if (document.hidden || editing()) return;
    roster = null; countsDoc = null;
    refresh();
  }, 60000);
  drawActor();
  refresh();
  stream();
})();
