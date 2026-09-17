// register's public page: the landing with the meter, the form with its
// drafts, the next step, and the manage page, over /apps/register/api.
// Every string a pilgrim reads comes from copy.json through /api/status.
(function () {
  'use strict';
  var API = '/apps/register/api';
  var view = document.getElementById('view');
  var banner = document.getElementById('banner');
  var status = null;          // the last /api/status
  var model = null;           // the form's data, the shape /api/submit takes
  var rid = null, token = null, mode = 'new';
  var saveTimer = null, dirty = false, pending = null;
  var leaving = null;         // the status the last write left; #next waits past it
  var routeGen = 0;           // bumped on every route() call; stale callbacks bail out

  // ---- helpers ----
  function esc(s) {
    return String(s === undefined || s === null ? '' : s).replace(/[<>&"']/g, function (c) {
      return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function t(key, vars) {
    var s = (status && status.copy && status.copy[key]) || key;
    Object.keys(vars || {}).forEach(function (k) { s = s.split('{{' + k + '}}').join(String(vars[k])); });
    return s;
  }
  function money(cents) {
    var d = cents / 100;
    return '$' + (cents % 100 ? d.toFixed(2) : d.toFixed(0));
  }
  function api(path, opts) {
    return fetch(API + path, opts).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        if (!r.ok) { var e = new Error(d.error || ('http ' + r.status)); e.code = d.code; e.status = r.status; throw e; }
        return d;
      });
    });
  }
  function post(path, body) {
    return api(path, { method: 'POST', keepalive: true, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body || {}) });
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
    var out = '<h1>' + esc(t('landing.title')) + '</h1><p>' + esc(t('landing.intro')) + '</p>';
    out += '<div class="meter"><div class="bar" role="progressbar" aria-valuenow="' + pct + '" aria-valuemin="0" aria-valuemax="100">' +
      '<div class="fill" style="width:' + pct + '%"></div></div>' +
      '<div class="label">' + esc(t('landing.meter', { count: status.counts.full, cap: status.caps.full, percent: pct })) + '</div></div>';
    if (!status.open) return out + '<div class="card soft"><p>' + esc(t('landing.closed')) + '</p></div>';
    function door(track) {
      var full = trackFull(track);
      return '<div class="card"><h2>' + esc(t('landing.' + track + '.title')) + '</h2><p>' + esc(t('landing.' + track + '.blurb')) + '</p>' +
        (full ? '<p class="muted">' + esc(t('landing.soldout')) + '</p><a class="btn quiet" href="#form/' + track + '">' + esc(t('landing.waitlist.button')) + '</a>'
              : '<a class="btn" href="#form/' + track + '">' + esc(t('landing.' + track + '.button')) + '</a>') + '</div>';
    }
    return out + '<div class="doors">' + door('full') + door('bambino') + '</div>';
  }
  function input(k, key, value, type, extra) {
    return '<label>' + esc(t(key)) + '<input type="' + (type || 'text') + '" data-k="' + k + '" value="' + esc(value) + '"' + (extra || '') + '></label>';
  }
  function check(k, key, on, off, note) {
    return '<label class="check' + (off ? ' off' : '') + '"><input type="checkbox" data-k="' + k + '"' + (on ? ' checked' : '') + (off ? ' disabled' : '') + '>' +
      '<span>' + esc(t(key)) + (note ? ' <span class="note">' + esc(note) + '</span>' : '') + '</span></label>';
  }
  function choices(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '<h3>' + esc(t('form.days')) + '</h3>';
    if (m.track === 'full') {
      out += check(k + 'days.fri', 'form.fri', p.days.fri) + check(k + 'days.sat', 'form.sat', p.days.sat) + check(k + 'days.sun', 'form.sun', p.days.sun);
      if (p.days.sun) out += check(k + 'sun_ten', 'form.sun_ten', p.sun_ten);
    } else {
      out += check(k + 'days.sun', 'form.sun', p.days.sun);
    }
    out += check(k + 'social_fri', 'form.social_fri', p.social_fri, soldOut('social_fri') && !p.social_fri, soldOut('social_fri') && !p.social_fri ? t('form.social_soldout') : '');
    out += check(k + 'social_sat', 'form.social_sat', p.social_sat, soldOut('social_sat') && !p.social_sat, soldOut('social_sat') && !p.social_sat ? t('form.social_soldout') : '');
    out += check(k + 'mass_fri', 'form.mass_fri', p.mass_fri) + check(k + 'holy_hour', 'form.holy_hour', p.holy_hour) + check(k + 'bus', 'form.bus', p.bus);
    return out;
  }
  function person(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '<div class="card person"><h2>' + esc(t('form.person', { n: i + 1 })) + '</h2>';
    if (m.people.length > 1) out += '<button type="button" class="btn quiet small remove" data-act="remove" data-i="' + i + '">' + esc(t('form.remove_person')) + '</button>';
    out += '<div class="row">' + input(k + 'first', 'form.first', p.first) + input(k + 'last', 'form.last', p.last) + '</div>';
    out += check(k + 'child', 'form.child', p.child);
    if (i === 0 || !m.together) out += choices(p, i, m);
    out += check(k + 'first_bsc', 'form.first_bsc', p.first_bsc) + check(k + 'knight_dame', 'form.knight_dame', p.knight_dame) + check(k + 'volunteer', 'form.volunteer', p.volunteer);
    return out + '</div>';
  }
  function feesBox(m) {
    var out = '<div class="card soft fees"><h2>' + esc(t('form.fees.title')) + '</h2><table>';
    feeLines(m).forEach(function (l) { out += '<tr><td>' + esc(t('form.fees.line', { n: l.n, each: money(l.each) })) + '</td><td>' + esc(money(l.n * l.each)) + '</td></tr>'; });
    return out + '<tr class="total"><td>' + esc(t('form.fees.total')) + '</td><td>' + esc(money(fees(m))) + '</td></tr></table>' +
      '<p class="help">' + esc(t('form.fees.nonrefundable')) + '</p></div>';
  }
  function form(m) {
    var c = m.contact;
    var out = '<h1>' + esc(t(mode === 'manage' ? 'manage.title' : 'form.title')) + '</h1>';
    if (mode === 'manage' && !status.changes_open) out += '<div class="card soft"><p>' + esc(t('manage.closed')) + '</p></div>';
    out += '<div id="error"></div>';
    out += '<div class="card"><h2>' + esc(t('form.contact.title')) + '</h2>';
    out += '<div class="row">' + input('contact.email', 'form.email', c.email, 'email', ' autocomplete="email"') + input('contact.phone', 'form.phone', c.phone, 'tel', ' autocomplete="tel"') + '</div>';
    out += input('contact.street', 'form.street', c.street, 'text', ' autocomplete="street-address"');
    out += '<div class="row3">' + input('contact.city', 'form.city', c.city, 'text', ' autocomplete="address-level2"') +
      input('contact.state', 'form.state', c.state, 'text', ' autocomplete="address-level1" maxlength="40"') +
      input('contact.zip', 'form.zip', c.zip, 'text', ' autocomplete="postal-code"') + '</div>';
    out += input('org', 'form.org', m.org, 'text', ' list="orgs"') + '<datalist id="orgs">' +
      (status.orgs || []).map(function (o) { return '<option value="' + esc(o) + '">'; }).join('') + '</datalist>';
    out += '</div>';
    out += '<h2>' + esc(t('form.people.title')) + '</h2>';
    if (m.people.length > 1) out += check('together', 'form.together', m.together);
    m.people.forEach(function (p, i) { out += person(p, i, m); });
    if (m.people.length < status.caps.party) out += '<button type="button" class="btn quiet small" data-act="add">' + esc(t('form.add_person')) + '</button>';
    out += '<div class="card"><label>' + esc(t('form.why')) + '<textarea data-k="why">' + esc(m.why) + '</textarea></label>';
    out += check('assistance', 'form.assistance', m.assistance) + '<p class="help">' + esc(t('form.assistance.help')) + '</p></div>';
    out += feesBox(m);
    out += '<div class="actions">';
    if (mode === 'manage') {
      if (status.changes_open) {
        out += '<button type="button" class="btn" data-act="save">' + esc(t('manage.save')) + '</button>' +
          '<button type="button" class="btn danger" data-act="cancel">' + esc(t('manage.cancel')) + '</button>';
      }
    } else {
      out += '<button type="button" class="btn" data-act="submit">' + esc(t('form.submit')) + '</button>';
    }
    return out + '<span id="save-status" class="status"></span></div>';
  }
  function nextStep(r) {
    var s = r.status, out = '';
    function block(key, vars) { return '<h1>' + esc(t('next.' + key + '.title')) + '</h1><p>' + esc(t('next.' + key + '.body', vars)) + '</p>'; }
    var lapsed = r.lapsed && (s === 'waiver' || s === 'payment') ? '<p class="muted">' + esc(t('next.lapsed')) + '</p>' : '';
    if (s === 'waiver') out = block('waiver') + lapsed + '<button type="button" class="btn" data-act="sign">' + esc(t('next.waiver.button')) + '</button>';
    else if (s === 'payment') out = block('payment') + lapsed + '<button type="button" class="btn" data-act="pay">' + esc(t('next.payment.button', { total: money(r.fees) })) + '</button>';
    else if (s === 'assistance') out = block('assistance');
    else if (s === 'waitlist') out = block('waitlist', { position: r.position });
    else if (s === 'complete') out = block('complete', { email: r.contact.email }) + '<p><a class="btn quiet" href="#manage/' + esc(rid) + '/' + esc(token) + '">' + esc(t('manage.title')) + '</a></p>';
    else if (s === 'cancelled') out = block('cancelled');
    else out = '<h1>' + esc(s) + '</h1>';
    return '<div id="error"></div>' + out;
  }

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
    if (mode !== 'new') return;
    dirty = true;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(save, 1200);
  }
  function save() {
    if (mode !== 'new' || !dirty) return;
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
  function submit() {
    showError('');
    // an autosave in flight owns the rid, so let it land first
    Promise.resolve(pending).then(function () {
      var body = JSON.parse(JSON.stringify(model));
      if (rid) { body.rid = rid; body.token = token; }
      return post('/submit', body).then(function (d) {
        rid = d.rid; token = d.token; try { sessionStorage.removeItem('bsc.draft'); } catch (e) { }
        leaving = 'draft';
        location.hash = '#next/' + rid + '/' + token;
      });
    }).catch(function (e) {
      if (e.code === 'duplicate') {
        showError(t('form.error.duplicate'), '<p><button type="button" class="btn quiet small" data-act="resend">' + esc(t('form.resend')) + '</button></p>');
      } else showError(e.message);
      window.scrollTo(0, 0);
    });
  }
  function refreshStatus() { return api('/status').then(function (d) { status = d; banner.hidden = d.mode !== 'stub'; if (!banner.hidden) banner.textContent = t('stub.banner'); }); }
  function render(html) { view.innerHTML = html; }
  function route() {
    var h = location.hash.replace(/^#\/?/, '');
    var parts = h.split('/');
    var gen = ++routeGen;
    refreshStatus().then(function () {
      if (gen !== routeGen) return;
      if (parts[0] === 'form' && (parts[1] === 'full' || parts[1] === 'bambino')) {
        if (!status.open) { mode = 'landing'; return render('<div class="card soft"><p>' + esc(t('landing.closed')) + '</p></div>'); }
        mode = 'new';
        if (!model || model.track !== parts[1]) {
          model = blankModel(parts[1]);
          var d = recall(parts[1]); rid = d ? d.rid : null; token = d ? d.token : null;
          if (rid) {
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
        return loadReg(rid, token, was).then(function (r) {
          leaving = null;
          if (gen !== routeGen) return;
          render(nextStep(r));
        }).catch(function (e) {
          leaving = null;
          if (gen !== routeGen) return;
          render('<div id="error"></div>'); showError(e.message);
        });
      }
      if (parts[0] === 'manage' && parts[1] && parts[2]) {
        rid = parts[1]; token = parts[2]; mode = 'manage';
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
    var el = ev.target.closest('[data-act]');
    if (!el) return;
    var act = el.getAttribute('data-act');
    if (act === 'add') { model.people.push(blankPerson()); render(form(model)); scheduleSave(); }
    else if (act === 'remove') { model.people.splice(+el.getAttribute('data-i'), 1); render(form(model)); scheduleSave(); }
    else if (act === 'submit') { clearTimeout(saveTimer); dirty = false; submit(); }
    else if (act === 'save') {
      showError('');
      post('/reg/' + rid + '/edit?t=' + encodeURIComponent(token), model).then(function (d) {
        say(t('form.saving'));
        if (d.fees > d.fees_before) showError(t('manage.pay_more', { diff: money(d.fees - d.fees_before) }));
      }).catch(function (e) { showError(e.message); window.scrollTo(0, 0); });
    }
    else if (act === 'cancel') {
      if (!window.confirm(t('manage.cancel.confirm'))) return;
      post('/reg/' + rid + '/cancel?t=' + encodeURIComponent(token), {}).then(function () { location.hash = '#next/' + rid + '/' + token; })
        .catch(function (e) { showError(e.message); });
    }
    else if (act === 'sign' || act === 'pay') {
      el.disabled = true;
      leaving = act === 'sign' ? 'waiver' : 'payment';
      post('/reg/' + rid + '/' + act + '?t=' + encodeURIComponent(token), {}).then(function (d) {
        if (d.url) { location.href = d.url; return; }
        route();
      }).catch(function (e) {
        el.disabled = false;
        // the hold lapsed and the track filled: the reg is wait listed now
        if (e.code === 'waitlist') return route();
        leaving = null;
        showError(e.message);
      });
    }
    else if (act === 'resend') {
      post('/resend-link', { email: model.contact.email }).then(function () { showError(t('form.resend.done')); })
        .catch(function (e) { showError(e.message); });
    }
  });
  window.addEventListener('hashchange', route);
  window.addEventListener('beforeunload', function () { if (dirty) save(); });
  route();
})();
