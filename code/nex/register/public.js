// register's public page: the landing with the meter, the form with its
// drafts, the next step, and the manage page, over /apps/register/api.
// Every string a pilgrim reads comes from copy.json through /api/status.
// The owner, and nobody else, can turn the page into an editor and type
// over those strings where they stand. Pure helpers first (node tests
// them), then the app.
(function () {
  'use strict';

  // ---- pure helpers ----
  function esc(s) {
    return String(s === undefined || s === null ? '' : s).replace(/[<>&"']/g, function (c) {
      return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
    });
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
  // a string that loses one loses the number or the link it stood for,
  // and the page refuses the edit rather than storing it.
  function missingVars(orig, next) {
    var have = varsOf(next);
    return varsOf(orig).filter(function (v) { return have.indexOf(v) < 0; });
  }
  // a key whose string is prose: Enter makes a new line there. Anywhere
  // else a string is one line and Enter means done.
  function multiline(key) {
    var k = String(key === undefined || key === null ? '' : key);
    if (k === 'landing.intro' || k === 'form.assistance.help' || k === 'stub.banner') return true;
    if (/^next\..+\.body$/.test(k)) return true;
    return k === 'manage.closed' || k === 'manage.pay_more' || k === 'manage.cancel.confirm';
  }

  var pure = { esc: esc, varsOf: varsOf, missingVars: missingVars, multiline: multiline };
  if (typeof module !== 'undefined' && module.exports) { module.exports = pure; }
  if (typeof document === 'undefined') { return; }

  // ---- the app ----
  var API = '/apps/register/api';
  var view = document.getElementById('view');
  var banner = document.getElementById('banner');
  var busyEl = document.getElementById('busy');
  var toggleEl = document.getElementById('edit-copy');
  var stepsEl = document.getElementById('steps');
  var promptEl = document.getElementById('prompt');
  var status = null;          // the last /api/status
  var model = null;           // the form's data, the shape /api/submit takes
  var rid = null, token = null, mode = 'new';
  var saveTimer = null, dirty = false, pending = null;
  var leaving = null;         // the status the last write left; #next waits past it
  var routeGen = 0;           // bumped on every route() call; stale callbacks bail out
  var fresh = null;           // what a write just answered, painted before the read
  var lastReg = null;         // the registration #next last painted
  var editing = false;        // edit mode, the owner's alone
  var step = '';              // the step being previewed, or ''
  var busy = 0;               // how many fetches are in flight

  // the twelve pilgrim views, each reachable from edit mode with a
  // fixture, and the strings that belong to no view of their own
  var STEPS = [['landing', 'Landing'], ['form', 'Form (full)'], ['bambino', 'Form (Bambino)'],
    ['waiver', 'Waiver step'], ['payment', 'Payment step'], ['assistance', 'Assistance'],
    ['waitlist', 'Wait list'], ['complete', 'Complete'], ['cancelled', 'Cancelled'],
    ['manage', 'Manage'], ['closed', 'Closed'], ['soldout', 'Sold out'],
    ['other', 'Other strings']];
  var OTHER = ['form.saving', 'form.error.duplicate', 'form.resend', 'form.resend.done',
    'manage.closed', 'manage.pay_more', 'manage.cancel.confirm', 'stub.banner'];

  // ---- helpers ----
  function raw(key) { return (status && status.copy && status.copy[key]) || key; }
  function t(key, vars) {
    var s = raw(key);
    Object.keys(vars || {}).forEach(function (k) { s = s.split('{{' + k + '}}').join(String(vars[k])); });
    return s;
  }
  // every string that lands in innerHTML goes through here, so no call
  // site knows about edit mode. In edit mode the raw template is shown,
  // placeholders and all, in a span the organizer types into.
  function tx(key, vars) {
    if (!editing) return esc(t(key, vars));
    return '<span class="copy" data-copy="' + esc(key) + '" contenteditable="plaintext-only" spellcheck="true">' +
      esc(raw(key)) + '</span>';
  }
  function money(cents) {
    var d = cents / 100;
    return '$' + (cents % 100 ? d.toFixed(2) : d.toFixed(0));
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
  // ship answers, so a slow ship never reads as a dead page
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
  function api(path, opts) {
    return track(fetch(API + path, opts).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        if (!r.ok) { var e = new Error(d.error || ('http ' + r.status)); e.code = d.code; e.status = r.status; throw e; }
        return d;
      });
    }));
  }
  function post(path, body, asActor) {
    var heads = { 'content-type': 'application/json' };
    if (asActor) heads['x-actor'] = actor;
    return api(path, { method: 'POST', keepalive: true, headers: heads, body: JSON.stringify(body || {}) });
  }
  function wait(ms) { return new Promise(function (res) { setTimeout(res, ms); }); }
  // the writer applies after the answer leaves, so a read right after a
  // write can still see the old status. Retry while it does.
  function loadReg(id, tok, expectNot) {
    var tries = 0;
    function once() {
      return api('/reg/' + id + '?t=' + encodeURIComponent(tok)).then(function (r) {
        if (expectNot && r.status === expectNot && tries++ < 8) return wait(300).then(once);
        return r;
      }, function (e) {
        if (expectNot && e.status === 404 && tries++ < 8) return wait(300).then(once);
        throw e;
      });
    }
    return once();
  }
  function blankPerson() {
    return { first: '', last: '', child: false, days: { fri: false, sat: false, sun: false }, sun_ten: false,
      social_fri: false, social_sat: false, mass_fri: false, holy_hour: false, bus: false,
      first_bsc: false, knight_dame: false, volunteer: false };
  }
  function blankModel(track) {
    return { track: track, contact: { email: '', phone: '', street: '', city: '', state: '', zip: '' },
      org: '', why: '', assistance: false, together: false, people: [blankPerson()] };
  }
  function fromReg(r) {
    return { track: r.track, contact: r.contact, org: r.org, why: r.why, assistance: r.assistance,
      together: r.together, people: r.people.map(function (p) { var q = {}; Object.keys(blankPerson()).forEach(function (k) { q[k] = p[k]; }); return q; }) };
  }
  function fee(p, track) { return track === 'bambino' ? status.fees.bambino : status.fees.full; }
  function feeLines(m) {
    var by = {};
    m.people.forEach(function (p) { var c = fee(p, m.track); by[c] = (by[c] || 0) + 1; });
    return Object.keys(by).map(function (c) { return { each: +c, n: by[c] }; });
  }
  function fees(m) { return m.people.reduce(function (s, p) { return s + fee(p, m.track); }, 0); }
  function soldOut(which) { return status.counts[which] >= status.caps[which]; }
  function trackFull(track) {
    return track === 'bambino' ? status.counts.bambino >= status.caps.bambino : status.counts.full >= status.caps.full;
  }
  function setPath(obj, path, val) {
    var ks = path.split('.'), o = obj;
    for (var i = 0; i < ks.length - 1; i++) o = o[ks[i]];
    o[ks[ks.length - 1]] = val;
  }

  // ---- render ----
  function landing() {
    var pct = Math.min(100, Math.round(100 * status.counts.full / Math.max(1, status.caps.full)));
    var out = '<h1>' + tx('landing.title') + '</h1><p>' + tx('landing.intro') + '</p>';
    out += '<div class="meter"><div class="bar" role="progressbar" aria-valuenow="' + pct + '" aria-valuemin="0" aria-valuemax="100">' +
      '<div class="fill" style="width:' + pct + '%"></div></div>' +
      '<div class="label">' + tx('landing.meter', { count: status.counts.full, cap: status.caps.full, percent: pct }) + '</div></div>';
    if (!status.open) return out + '<div class="card soft"><p>' + tx('landing.closed') + '</p></div>';
    function door(track) {
      var full = trackFull(track);
      return '<div class="card"><h2>' + tx('landing.' + track + '.title') + '</h2><p>' + tx('landing.' + track + '.blurb') + '</p>' +
        (full ? '<p class="muted">' + tx('landing.soldout') + '</p><a class="btn quiet" href="#form/' + track + '">' + tx('landing.waitlist.button') + '</a>'
              : '<a class="btn" href="#form/' + track + '">' + tx('landing.' + track + '.button') + '</a>') + '</div>';
    }
    return out + '<div class="doors">' + door('full') + door('bambino') + '</div>';
  }
  // in edit mode a field's caption is a plain block, not a <label>: a
  // click inside a <label> jumps to the field it names, which would
  // take the caret straight out of the span being typed into
  function input(k, key, value, type, extra) {
    var box = '<input type="' + (type || 'text') + '" data-k="' + k + '" value="' + esc(value) + '"' + (extra || '') + '>';
    if (editing) return '<div class="field">' + tx(key) + box + '</div>';
    return '<label>' + esc(t(key)) + box + '</label>';
  }
  function check(k, key, on, off, noteKey) {
    var body = '<input type="checkbox" data-k="' + k + '"' + (on ? ' checked' : '') + (off ? ' disabled' : '') + '>' +
      '<span>' + tx(key) + (noteKey ? ' <span class="note">' + tx(noteKey) + '</span>' : '') + '</span>';
    var cls = 'check' + (off ? ' off' : '');
    if (editing) return '<div class="' + cls + '">' + body + '</div>';
    return '<label class="' + cls + '">' + body + '</label>';
  }
  function choices(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '<h3>' + tx('form.days') + '</h3>';
    if (m.track === 'full') {
      out += check(k + 'days.fri', 'form.fri', p.days.fri) + check(k + 'days.sat', 'form.sat', p.days.sat) + check(k + 'days.sun', 'form.sun', p.days.sun);
      if (p.days.sun) out += check(k + 'sun_ten', 'form.sun_ten', p.sun_ten);
    } else {
      out += check(k + 'days.sun', 'form.sun', p.days.sun);
    }
    out += check(k + 'social_fri', 'form.social_fri', p.social_fri, soldOut('social_fri') && !p.social_fri, soldOut('social_fri') && !p.social_fri ? 'form.social_soldout' : '');
    out += check(k + 'social_sat', 'form.social_sat', p.social_sat, soldOut('social_sat') && !p.social_sat, soldOut('social_sat') && !p.social_sat ? 'form.social_soldout' : '');
    out += check(k + 'mass_fri', 'form.mass_fri', p.mass_fri) + check(k + 'holy_hour', 'form.holy_hour', p.holy_hour) + check(k + 'bus', 'form.bus', p.bus);
    return out;
  }
  function person(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '<div class="card person"><h2>' + tx('form.person', { n: i + 1 }) + '</h2>';
    if (m.people.length > 1) out += '<button type="button" class="btn quiet small remove" data-act="remove" data-i="' + i + '">' + tx('form.remove_person') + '</button>';
    out += '<div class="row">' + input(k + 'first', 'form.first', p.first) + input(k + 'last', 'form.last', p.last) + '</div>';
    out += check(k + 'child', 'form.child', p.child);
    if (i === 0 || !m.together) out += choices(p, i, m);
    out += check(k + 'first_bsc', 'form.first_bsc', p.first_bsc) + check(k + 'knight_dame', 'form.knight_dame', p.knight_dame) + check(k + 'volunteer', 'form.volunteer', p.volunteer);
    return out + '</div>';
  }
  function feesBox(m) {
    var out = '<div class="card soft fees"><h2>' + tx('form.fees.title') + '</h2><table>';
    feeLines(m).forEach(function (l) { out += '<tr><td>' + tx('form.fees.line', { n: l.n, each: money(l.each) }) + '</td><td>' + esc(money(l.n * l.each)) + '</td></tr>'; });
    return out + '<tr class="total"><td>' + tx('form.fees.total') + '</td><td>' + esc(money(fees(m))) + '</td></tr></table>' +
      '<p class="help">' + tx('form.fees.nonrefundable') + '</p></div>';
  }
  function form(m) {
    var c = m.contact;
    var out = '<h1>' + tx(mode === 'manage' ? 'manage.title' : 'form.title') + '</h1>';
    if (mode === 'manage' && !status.changes_open) out += '<div class="card soft"><p>' + tx('manage.closed') + '</p></div>';
    out += '<div id="error"></div>';
    out += '<div class="card"><h2>' + tx('form.contact.title') + '</h2>';
    out += '<div class="row">' + input('contact.email', 'form.email', c.email, 'email', ' autocomplete="email"') + input('contact.phone', 'form.phone', c.phone, 'tel', ' autocomplete="tel"') + '</div>';
    out += input('contact.street', 'form.street', c.street, 'text', ' autocomplete="street-address"');
    out += '<div class="row3">' + input('contact.city', 'form.city', c.city, 'text', ' autocomplete="address-level2"') +
      input('contact.state', 'form.state', c.state, 'text', ' autocomplete="address-level1" maxlength="40"') +
      input('contact.zip', 'form.zip', c.zip, 'text', ' autocomplete="postal-code"') + '</div>';
    out += input('org', 'form.org', m.org, 'text', ' list="orgs"') + '<datalist id="orgs">' +
      (status.orgs || []).map(function (o) { return '<option value="' + esc(o) + '">'; }).join('') + '</datalist>';
    out += '</div>';
    out += '<h2>' + tx('form.people.title') + '</h2>';
    if (m.people.length > 1) out += check('together', 'form.together', m.together);
    m.people.forEach(function (p, i) { out += person(p, i, m); });
    if (m.people.length < status.caps.party) out += '<button type="button" class="btn quiet small" data-act="add">' + tx('form.add_person') + '</button>';
    var why = '<textarea data-k="why">' + esc(m.why) + '</textarea>';
    out += '<div class="card">' + (editing ? '<div class="field">' + tx('form.why') + why + '</div>' : '<label>' + esc(t('form.why')) + why + '</label>');
    out += check('assistance', 'form.assistance', m.assistance) + '<p class="help">' + tx('form.assistance.help') + '</p></div>';
    out += feesBox(m);
    out += '<div class="actions">';
    if (mode === 'manage') {
      if (status.changes_open) {
        out += '<button type="button" class="btn" data-act="save">' + tx('manage.save') + '</button>' +
          '<button type="button" class="btn danger" data-act="cancel">' + tx('manage.cancel') + '</button>';
      }
    } else {
      out += '<button type="button" class="btn" data-act="submit">' + tx('form.submit') + '</button>';
    }
    return out + '<span id="save-status" class="status"></span></div>';
  }
  function nextStep(r) {
    var s = r.status, out = '';
    function block(key, vars) { return '<h1>' + tx('next.' + key + '.title') + '</h1><p>' + tx('next.' + key + '.body', vars) + '</p>'; }
    var lapsed = r.lapsed && (s === 'waiver' || s === 'payment') ? '<p class="muted">' + tx('next.lapsed') + '</p>' : '';
    if (s === 'waiver') out = block('waiver') + lapsed + '<button type="button" class="btn" data-act="sign">' + tx('next.waiver.button') + '</button>';
    else if (s === 'payment') out = block('payment') + lapsed + '<button type="button" class="btn" data-act="pay">' + tx('next.payment.button', { total: money(r.fees) }) + '</button>';
    else if (s === 'assistance') out = block('assistance');
    else if (s === 'waitlist') out = block('waitlist', { position: r.position });
    else if (s === 'complete') out = block('complete', { email: (r.contact || {}).email }) + '<p><a class="btn quiet" href="#manage/' + esc(rid) + '/' + esc(token) + '">' + tx('manage.title') + '</a></p>';
    else if (s === 'cancelled') out = block('cancelled');
    else out = '<h1>' + esc(s) + '</h1>';
    return '<div id="error"></div>' + out;
  }

  // ---- edit mode, the owner's alone ----
  var actor = '';
  try { actor = localStorage.getItem('register.actor') || ''; } catch (e) { }
  var remembered = false;   // edit mode from the last visit, applied once the ship says owner
  try { remembered = localStorage.getItem('register.editcopy') === '1'; } catch (e) { }
  var queued = null;
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
    var q = queued; queued = null;
    if (q) q();
  }
  // a change with no name yet opens the prompt and goes on once it has one
  function act(fn) {
    if (actor) return fn();
    queued = fn;
    askActor();
  }
  document.getElementById('actor-save').addEventListener('click', saveActor);
  document.getElementById('actor-cancel').addEventListener('click', function () {
    queued = null; promptEl.hidden = true;
  });
  document.getElementById('actor-name').addEventListener('keydown', function (ev) {
    if (ev.key === 'Enter') { ev.preventDefault(); saveActor(); }
  });
  function labelOf(name) {
    var hit = STEPS.filter(function (s) { return s[0] === name; })[0];
    return hit ? hit[1] : name;
  }
  function stepsHtml() {
    return '<span class="lead">Show all steps</span>' + STEPS.map(function (s) {
      return '<button type="button" data-step="' + s[0] + '"' + (step === s[0] ? ' class="on"' : '') + '>' + esc(s[1]) + '</button>';
    }).join('') + '<button type="button" data-step="">Back to the page</button>';
  }
  function drawEdit() {
    // a stranger, and an owner before the first status, sees no trace
    // of edit mode. What the last visit remembered is applied only
    // once the ship has said the page belongs to whoever is reading.
    var mine = !!(status && status.owner);
    if (!mine) editing = false;
    else if (remembered) { editing = true; remembered = false; }
    toggleEl.hidden = !mine;
    toggleEl.className = 'editcopy' + (editing ? ' on' : '');
    toggleEl.textContent = editing ? 'Editing text' : 'Edit text';
    document.body.className = editing ? 'editing' : '';
    stepsEl.hidden = !editing;
    stepsEl.innerHTML = editing ? stepsHtml() : '';
  }
  // the fixtures: a fake registration and a fake status, so every
  // string a pilgrim reads is on screen without walking the flow
  function fixtureReg(st) {
    return { status: st, fees: 22500, position: 3, lapsed: true, contact: { email: 'pilgrim@example.com' } };
  }
  function fixtureModel(track) {
    var m = blankModel(track);
    if (track === 'full') m.people.push(blankPerson());
    m.people[0].days.sun = true;
    return m;
  }
  function otherHtml() {
    return '<h1>Other strings</h1><p class="muted">A status line, a dialog and what an error says. ' +
      'They belong to no step of their own.</p><div class="card otherlist">' +
      OTHER.map(function (k) { return '<span class="key">' + esc(k) + '</span><p>' + tx(k) + '</p>'; }).join('') +
      '</div>';
  }
  function previewHtml(name) {
    var keep = { status: status, model: model, mode: mode, rid: rid, token: token };
    var out = '';
    try {
      status = JSON.parse(JSON.stringify(keep.status));
      rid = 'preview001'; token = 'preview';
      if (name === 'landing' || name === 'closed' || name === 'soldout') {
        mode = 'landing';
        status.open = name !== 'closed';
        status.counts.full = name === 'soldout' ? status.caps.full : Math.round(status.caps.full / 2);
        status.counts.bambino = name === 'soldout' ? status.caps.bambino : 0;
        out = landing();
      } else if (name === 'form' || name === 'bambino') {
        mode = 'new';
        status.counts.social_fri = status.caps.social_fri;
        status.counts.social_sat = status.caps.social_sat;
        model = fixtureModel(name === 'form' ? 'full' : 'bambino');
        out = form(model);
      } else if (name === 'manage') {
        mode = 'manage';
        status.changes_open = true;
        model = fixtureModel('full');
        out = form(model);
      } else if (name === 'other') {
        out = otherHtml();
      } else {
        mode = 'next';
        out = nextStep(fixtureReg(name));
      }
    } finally {
      status = keep.status; model = keep.model; mode = keep.mode; rid = keep.rid; token = keep.token;
    }
    return '<div class="ribbon">Preview: ' + esc(labelOf(name)) +
      '. Nothing here is real and no button works.</div>' + out;
  }
  function showStep(name) {
    step = name;
    stepsEl.innerHTML = stepsHtml();
    if (!name) return route();
    render(previewHtml(name));
  }
  stepsEl.addEventListener('click', function (ev) {
    var b = ev.target.closest ? ev.target.closest('button[data-step]') : null;
    if (!b) return;
    showStep(b.getAttribute('data-step'));
  });
  toggleEl.addEventListener('click', function () {
    editing = !editing;
    try { localStorage.setItem('register.editcopy', editing ? '1' : ''); } catch (e) { }
    clearTimeout(saveTimer);
    dirty = false;
    step = '';
    drawEdit();
    route();
  });
  // a tick for three tenths of a second, or the refusal in red until
  // the next edit of that string
  function flag(el, text, bad) {
    var sib = el.nextSibling;
    if (sib && sib.nodeType === 1 && /^(tick|copy-bad)$/.test(sib.className)) el.parentNode.removeChild(sib);
    var tag = document.createElement('span');
    tag.className = bad ? 'copy-bad' : 'tick';
    tag.textContent = text;
    if (el.nextSibling) el.parentNode.insertBefore(tag, el.nextSibling);
    else el.parentNode.appendChild(tag);
    if (!bad) setTimeout(function () { if (tag.parentNode) tag.parentNode.removeChild(tag); }, 300);
  }
  function sendCopy(el, key, next, was) {
    // the page shows the new string the moment the request goes up, so
    // a re-render keeps it; a refusal puts the old one back
    status.copy[key] = next;
    post('/admin/copy/set', { key: key, value: next }, true).then(function () {
      flag(el, '✓', false);
    }).catch(function (e) {
      status.copy[key] = was;
      el.textContent = was;
      flag(el, e.message, true);
      if (e.status === 400 && /actor/.test(String(e.message))) askActor();
    });
  }
  document.addEventListener('blur', function (ev) {
    var el = ev.target;
    if (!editing || !el || !el.classList || !el.classList.contains('copy')) return;
    var key = el.getAttribute('data-copy');
    var was = raw(key);
    var next = String(el.textContent);
    if (next === was) return;
    var gone = missingVars(was, next);
    if (gone.length) {
      el.textContent = was;
      flag(el, 'keep ' + gone.join(' '), true);
      return;
    }
    act(function () { sendCopy(el, key, next, was); });
  }, true);
  document.addEventListener('keydown', function (ev) {
    var el = ev.target;
    if (!editing || !el || !el.classList || !el.classList.contains('copy')) return;
    if (ev.key !== 'Enter' || ev.shiftKey) return;
    if (multiline(el.getAttribute('data-copy'))) return;
    ev.preventDefault();
    el.blur();
  });

  // ---- the app ----
  function showError(msg, extra) {
    var el = document.getElementById('error');
    if (el) el.innerHTML = msg ? '<div class="error">' + esc(msg) + (extra || '') + '</div>' : '';
  }
  function say(msg) { var el = document.getElementById('save-status'); if (el) el.textContent = msg; }
  function remember() { try { sessionStorage.setItem('bsc.draft', JSON.stringify({ rid: rid, token: token, track: model.track })); } catch (e) { } }
  function recall(track) {
    try { var d = JSON.parse(sessionStorage.getItem('bsc.draft') || 'null'); if (d && d.track === track) return d; } catch (e) { }
    return null;
  }
  function scheduleSave() {
    if (mode !== 'new' || editing) return;
    dirty = true;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(save, 1200);
  }
  function save() {
    if (mode !== 'new' || !dirty || editing) return;
    if (!model.contact.email && !model.contact.phone) return;
    dirty = false;
    var body = JSON.parse(JSON.stringify(model));
    if (rid) { body.rid = rid; body.token = token; }
    pending = post('/draft', body).then(function (d) {
      if (mode !== 'new') return;   // the form moved on; its rid is the submit's now
      rid = d.rid; token = d.token; remember(); say(t('form.saving'));
    }).catch(function () { say(''); });
    return pending;
  }
  function submit(el) {
    showError('');
    var free = spin(el);
    // an autosave in flight owns the rid, so let it land first
    Promise.resolve(pending).then(function () {
      var body = JSON.parse(JSON.stringify(model));
      if (rid) { body.rid = rid; body.token = token; }
      return post('/submit', body).then(function (d) {
        rid = d.rid; token = d.token; try { sessionStorage.removeItem('bsc.draft'); } catch (e) { }
        leaving = 'draft';
        // the answer carries the status, the position and the fees, so
        // the next step paints now and the read only confirms it
        fresh = { status: d.status, position: d.position, fees: d.fees, contact: model.contact, lapsed: false };
        location.hash = '#next/' + rid + '/' + token;
      });
    }).catch(function (e) {
      free();
      if (e.code === 'duplicate') {
        showError(t('form.error.duplicate'), '<p><button type="button" class="btn quiet small" data-act="resend">' + esc(t('form.resend')) + '</button></p>');
      } else showError(e.message);
      window.scrollTo(0, 0);
    });
  }
  function refreshStatus() {
    return api('/status').then(function (d) {
      status = d;
      drawEdit();
      banner.hidden = d.mode !== 'stub';
      if (!banner.hidden) banner.innerHTML = tx('stub.banner');
    });
  }
  function render(html) {
    view.innerHTML = html;
    // in edit mode the pilgrim flow is frozen: only the text is live
    if (!editing) return;
    Array.prototype.forEach.call(view.querySelectorAll('input, textarea'), function (el) {
      if (el.type !== 'checkbox' && el.type !== 'radio') el.readOnly = true;
    });
  }
  function route() {
    var h = location.hash.replace(/^#\/?/, '');
    var parts = h.split('/');
    var gen = ++routeGen;
    var seed = fresh; fresh = null;
    step = '';
    if (stepsEl.innerHTML) stepsEl.innerHTML = stepsHtml();
    if (!status) render(loading());
    refreshStatus().then(function () {
      if (gen !== routeGen) return;
      if (parts[0] === 'form' && (parts[1] === 'full' || parts[1] === 'bambino')) {
        if (!status.open) { mode = 'landing'; return render('<div class="card soft"><p>' + tx('landing.closed') + '</p></div>'); }
        mode = 'new';
        if (!model || model.track !== parts[1]) {
          model = blankModel(parts[1]);
          var d = recall(parts[1]); rid = d ? d.rid : null; token = d ? d.token : null;
          if (rid) {
            render(loading());
            return api('/reg/' + rid + '?t=' + encodeURIComponent(token)).then(function (r) {
              if (gen !== routeGen) return;
              if (r.status === 'draft') model = fromReg(r); else { rid = null; token = null; }
              render(form(model));
            }).catch(function () {
              if (gen !== routeGen) return;
              rid = null; token = null; render(form(model));
            });
          }
        }
        return render(form(model));
      }
      if (parts[0] === 'next' && parts[1] && parts[2]) {
        rid = parts[1]; token = parts[2]; mode = 'next';
        var was = leaving;
        // what the write just answered paints at once; the read that
        // follows only reconciles it
        if (seed) { lastReg = seed; render(nextStep(seed)); } else render(loading());
        return loadReg(rid, token, was).then(function (r) {
          leaving = null;
          if (gen !== routeGen) return;
          lastReg = r;
          render(nextStep(r));
        }).catch(function (e) {
          leaving = null;
          if (gen !== routeGen) return;
          render('<div id="error"></div>'); showError(e.message);
        });
      }
      if (parts[0] === 'manage' && parts[1] && parts[2]) {
        rid = parts[1]; token = parts[2]; mode = 'manage';
        render(loading());
        return api('/reg/' + rid + '?t=' + encodeURIComponent(token)).then(function (r) {
          if (gen !== routeGen) return;
          status.changes_open = r.changes_open;
          if (r.status === 'draft' || r.status === 'cancelled') { location.hash = '#next/' + rid + '/' + token; return; }
          model = fromReg(r); render(form(model));
        }).catch(function (e) {
          if (gen !== routeGen) return;
          render('<div id="error"></div>'); showError(e.message);
        });
      }
      model = null; rid = null; token = null; mode = 'landing';
      render(landing());
    }).catch(function (e) {
      if (gen !== routeGen) return;
      render('<p class="bad">' + esc(e.message) + '</p>');
    });
  }
  view.addEventListener('input', onChange);
  view.addEventListener('change', onChange);
  function onChange(ev) {
    if (editing) return;
    var el = ev.target, k = el.getAttribute('data-k');
    if (!k || !model) return;
    var box = el.type === 'checkbox';
    if (ev.type === 'change' && !box) return;
    if (ev.type === 'input' && box) return;
    var val = el.type === 'checkbox' ? el.checked : el.value;
    setPath(model, k, val);
    // structural changes re-render; a keystroke only updates the fees
    if (k === 'together' || /\.days\.sun$/.test(k)) { render(form(model)); }
    else { var fb = view.querySelector('.fees'); if (fb) fb.outerHTML = feesBox(model); }
    scheduleSave();
  }
  view.addEventListener('click', function (ev) {
    if (editing) {
      // a button, a link and a check box all do nothing here
      ev.preventDefault();
      return;
    }
    var el = ev.target.closest('[data-act]');
    if (!el) return;
    var act2 = el.getAttribute('data-act');
    if (act2 === 'add') { model.people.push(blankPerson()); render(form(model)); scheduleSave(); }
    else if (act2 === 'remove') { model.people.splice(+el.getAttribute('data-i'), 1); render(form(model)); scheduleSave(); }
    else if (act2 === 'submit') { clearTimeout(saveTimer); dirty = false; submit(el); }
    else if (act2 === 'save') {
      showError('');
      var freeSave = spin(el);
      say(t('form.saving'));
      post('/reg/' + rid + '/edit?t=' + encodeURIComponent(token), model).then(function (d) {
        freeSave();
        if (d.fees > d.fees_before) showError(t('manage.pay_more', { diff: money(d.fees - d.fees_before) }));
      }).catch(function (e) { freeSave(); say(''); showError(e.message); window.scrollTo(0, 0); });
    }
    else if (act2 === 'cancel') {
      if (!window.confirm(t('manage.cancel.confirm'))) return;
      var freeCancel = spin(el);
      post('/reg/' + rid + '/cancel?t=' + encodeURIComponent(token), {}).then(function () {
        fresh = { status: 'cancelled' };
        location.hash = '#next/' + rid + '/' + token;
      }).catch(function (e) { freeCancel(); showError(e.message); });
    }
    else if (act2 === 'sign' || act2 === 'pay') {
      var freeStep = spin(el);
      leaving = act2 === 'sign' ? 'waiver' : 'payment';
      post('/reg/' + rid + '/' + act2 + '?t=' + encodeURIComponent(token), {}).then(function (d) {
        if (d.url) { location.href = d.url; return; }
        // the ship named the step it moved to, so it paints now
        if (d.next && lastReg) fresh = Object.assign({}, lastReg, { status: d.next, lapsed: false });
        route();
      }).catch(function (e) {
        freeStep();
        // the hold lapsed and the track filled: the reg is wait listed now
        if (e.code === 'waitlist') return route();
        leaving = null;
        showError(e.message);
      });
    }
    else if (act2 === 'resend') {
      var freeResend = spin(el);
      post('/resend-link', { email: model.contact.email }).then(function () { freeResend(); showError(t('form.resend.done')); })
        .catch(function (e) { freeResend(); showError(e.message); });
    }
  });
  window.addEventListener('hashchange', route);
  window.addEventListener('beforeunload', function () { if (dirty) save(); });
  drawEdit();
  route();
})();
