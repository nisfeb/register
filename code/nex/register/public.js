// register's public page: the landing with the two doors, the form the
// party fills in, the next step, and the manage page, over
// /apps/register/api. Every string a pilgrim reads comes from copy.json
// through /api/status. The owner, and nobody else, can turn the page
// into an editor and type over those strings where they stand. Pure
// helpers first (node tests them), then the app.
(function () {
  'use strict';

  // ---- pure helpers ----
  function esc(s) {
    return String(s === undefined || s === null ? '' : s).replace(/[<>&"']/g, function (c) {
      return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  // the one markup a copy string carries: [text](url) becomes a link in
  // a new tab. It runs over already escaped text, so the text and the
  // url both arrive safe, and only http and https ever become an
  // anchor: anything else is left as the brackets the organizer typed.
  function links(html) {
    return String(html === undefined || html === null ? '' : html)
      .replace(/\[([^\]]*)\]\(([^)\s]+)\)/g, function (all, text, url) {
        if (!/^https?:\/\//i.test(url)) return all;
        return '<a href="' + url + '" target="_blank" rel="noopener noreferrer">' + text + '</a>';
      });
  }
  // a copy template becomes the html a pilgrim reads. The template is
  // escaped and the link rule runs over it, and only then do the values
  // go in, each one escaped on its own. A value is never read as
  // markup, so a name a pilgrim typed can never become an anchor. A
  // {{placeholder}} carries no character esc touches and none the link
  // rule matches, so it survives both and is still there to fill.
  function fill(s, vars) {
    var out = links(esc(s));
    Object.keys(vars || {}).forEach(function (k) {
      out = out.split('{{' + k + '}}').join(esc(vars[k]));
    });
    return out;
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
    if (/\.(help|blurb|body|who|fee|closed|nonrefundable)$/.test(k)) return true;
    if (k === 'landing.intro' || k === 'landing.choose' || k === 'stub.banner') return true;
    if (k === 'next.lapsed' || k === 'landing.soldout') return true;
    return k === 'manage.line' || k === 'manage.pay_more' || k === 'manage.cancel.confirm';
  }

  // the name a person is called by everywhere on the form, as soon as
  // either half of it is typed. Nothing typed yet gives '', and the
  // caller falls back to the copy's "You" or "Person {{n}}".
  function typedName(p) {
    var f = String((p && p.first) || '').trim();
    var l = String((p && p.last) || '').trim();
    return (f + ' ' + l).trim();
  }
  // "Ana", "Ana and Bo", "Ana, Bo and Cy"
  function joinWords(list) {
    var xs = (list || []).filter(function (x) { return x; });
    if (xs.length < 2) return xs.join('');
    return xs.slice(0, -1).join(', ') + ' and ' + xs[xs.length - 1];
  }
  // the short name of each social's venue. The copy holds the long
  // line a pilgrim ticks, so it holds these too, and the page hands
  // them to weekendWords. A caller with no copy in hand, which is what
  // the node tests are, gets these.
  var VENUES = { social_fri: 'Ajua', social_sat: "Pusser's" };
  // one person's weekend in words. The Same-weekend radio shows the
  // first person's, and the last page shows the whole party's, so a
  // pilgrim never has to hold a list of check boxes in their head.
  // `words` names the venues; leaving it out uses the defaults above.
  function weekendWords(p, track, words) {
    var q = p || {};
    var w = words || {};
    var d = q.days || {};
    var out = [];
    if (track === 'bambino') {
      out.push(d.sun ? 'Walking the last 2.5 miles on Sunday.' : 'Not walking.');
    } else {
      var days = [];
      if (d.fri) days.push('Friday');
      if (d.sat) days.push('Saturday');
      if (d.sun) days.push('Sunday');
      if (!days.length) out.push('Not walking.');
      // which Sunday it is belongs to Sunday, not to the whole list: a
      // party that walks all three days walks 10 miles on each of them
      else out.push('Walking ' + joinWords(days) +
        (d.sun ? (q.sun_ten ? ', the 10 miles on Sunday' : ', the last 2.5 miles on Sunday') : '') + '.');
    }
    var fri = [];
    if (q.mass_fri) fri.push('Mass');
    if (q.holy_hour) fri.push('Holy Hour');
    if (fri.length) out.push('Friday ' + joinWords(fri) + '.');
    var soc = [];
    if (q.social_fri) soc.push(w.social_fri || VENUES.social_fri);
    if (q.social_sat) soc.push(w.social_sat || VENUES.social_sat);
    if (soc.length) out.push((soc.length > 1 ? 'Socials at ' : 'Social at ') + joinWords(soc) + '.');
    if (q.bus) out.push('Needs the bus.');
    return out.join(' ');
  }
  // what one person copies from another when their weekend follows the
  // first person's: the choices, and nothing that is theirs alone
  var CHOICES = ['days', 'sun_ten', 'social_fri', 'social_sat', 'mass_fri', 'holy_hour', 'bus'];
  function copyChoices(from, to) {
    var out = JSON.parse(JSON.stringify(to || {}));
    CHOICES.forEach(function (k) {
      var v = (from || {})[k];
      out[k] = v && typeof v === 'object' ? JSON.parse(JSON.stringify(v)) : v;
    });
    return out;
  }
  // the first person's choices, flowed to everyone following them. The
  // first person is never a copy of anybody.
  function syncSame(people, same) {
    return (people || []).map(function (p, i) {
      return i > 0 && (same || [])[i] ? copyChoices((people || [])[0], p) : p;
    });
  }
  // who on the manage page is doing what the first person is doing.
  // Nothing on the ship records that, because what was submitted is
  // each person's own values, so the page works it out again from the
  // values themselves: a person whose every choice matches the first
  // person's is shown as following them.
  function sameFrom(people) {
    var xs = people || [];
    var lead = xs[0] || {};
    return xs.map(function (p, i) {
      return i > 0 && CHOICES.every(function (k) {
        return JSON.stringify((p || {})[k]) === JSON.stringify(lead[k]);
      });
    });
  }
  // a person with nothing filled in. On the full Camino the Sunday
  // choice starts on the 10 miles, which is what the full track is;
  // the Bambino track has no such choice and leaves it off.
  function blankPerson(track) {
    return { first: '', last: '', child: false, days: { fri: false, sat: false, sun: false },
      sun_ten: track !== 'bambino',
      social_fri: false, social_sat: false, mass_fri: false, holy_hour: false, bus: false,
      first_bsc: false, knight_dame: false, volunteer: false };
  }
  function blankModel(track) {
    var m = { track: track, contact: { email: '', phone: '', street: '', city: '', state: '', zip: '' },
      org: '', why: '', assistance: false, together: false, people: [blankPerson(track)] };
    // the Bambino track is the Sunday walk, so the one row it offers is
    // ticked from the start: nobody registers for it to stay home
    if (track === 'bambino') m.people[0].days.sun = true;
    return m;
  }
  // a stored registration, as the form holds it. `together` is always
  // false here: the ship was sent every person's own values, expanded,
  // so there is nothing left to expand and the form must not fold the
  // party back up under the first person.
  function fromReg(r) {
    return { track: r.track, contact: r.contact, org: r.org, why: r.why, assistance: r.assistance,
      together: false,
      people: r.people.map(function (p) {
        var q = {};
        Object.keys(blankPerson(r.track)).forEach(function (k) { q[k] = p[k]; });
        return q;
      }) };
  }
  // one fee line per person, not one per price: a pilgrim checks their
  // own name against the total. `kind` names the word beside the name,
  // which the page reads out of the copy.
  function feeLines(people, track, fees) {
    var each = track === 'bambino' ? (fees || {}).bambino : (fees || {}).full;
    return (people || []).map(function (p, i) {
      return { i: i, name: typedName(p), kind: p && p.child ? 'child' : track, each: Number(each) || 0 };
    });
  }
  function feesTotal(lines) {
    return (lines || []).reduce(function (n, l) { return n + (Number(l.each) || 0); }, 0);
  }

  var pure = { esc: esc, links: links, fill: fill, varsOf: varsOf, missingVars: missingVars,
    multiline: multiline, typedName: typedName, joinWords: joinWords, weekendWords: weekendWords,
    copyChoices: copyChoices, syncSame: syncSame, sameFrom: sameFrom, feeLines: feeLines,
    feesTotal: feesTotal, blankPerson: blankPerson, blankModel: blankModel, fromReg: fromReg,
    CHOICES: CHOICES };
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
  // which people after the first are following the first one's weekend.
  // This lives in the page alone: what goes to the ship is the copied
  // values themselves, so the ship never learns who copied whom.
  var sameAs = [];
  var manageWas = null;       // the status the manage view loaded
  var manageMade = '';        // when the registration the manage view holds was made

  // the twelve pilgrim views, each reachable from edit mode with a
  // fixture, and the strings that belong to no view of their own
  var STEPS = [['landing', 'Landing'], ['form', 'Form (full)'], ['bambino', 'Form (Bambino)'],
    ['waiver', 'Waiver step'], ['payment', 'Payment step'], ['assistance', 'Assistance'],
    ['waitlist', 'Wait list'], ['complete', 'Complete'], ['cancelled', 'Cancelled'],
    ['manage', 'Manage'], ['closed', 'Closed'], ['soldout', 'Sold out'],
    ['other', 'Other strings']];
  // the strings no fixture puts on screen as a span of their own: a
  // status line, a dialog, what an error says, the few that only show
  // when a track is full or a party is one person, and the words the
  // page drops into another string's placeholder, which land there as
  // plain text and so are editable only here.
  var OTHER = ['form.saving', 'form.error.duplicate', 'form.resend', 'form.resend.done',
    'form.you.lower', 'form.friday.closed', 'form.submit.waitlist', 'form.submit.full',
    'form.fees.full', 'form.fees.bambino', 'form.fees.child',
    'form.social_fri.short', 'form.social_sat.short',
    'track.full', 'track.bambino',
    'next.payment.spots', 'next.payment.body.one', 'next.draft.title', 'next.draft.body',
    'manage.closed', 'manage.pay_more', 'manage.cancel.confirm', 'stub.banner'];
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'];

  // ---- helpers ----
  function raw(key) { return (status && status.copy && status.copy[key]) || key; }
  function t(key, vars) {
    var s = raw(key);
    Object.keys(vars || {}).forEach(function (k) { s = s.split('{{' + k + '}}').join(String(vars[k])); });
    return s;
  }
  // every string that lands in innerHTML goes through here, so no call
  // site knows about edit mode. In edit mode the raw template is shown,
  // placeholders, brackets and all, in a span the organizer types into.
  // A string inside an attribute value is not editable in place.
  function tx(key, vars) {
    if (!editing) return fill(raw(key), vars);
    return '<span class="copy" data-copy="' + esc(key) + '" contenteditable="plaintext-only" spellcheck="true">' +
      esc(raw(key)) + '</span>';
  }
  function money(cents) {
    var d = cents / 100;
    return '$' + (cents % 100 ? d.toFixed(2) : d.toFixed(0));
  }
  // a date a pilgrim reads, not an ISO stamp
  function dateWords(iso) {
    var d = new Date(String(iso || ''));
    if (isNaN(d.getTime())) return String(iso || '');
    return MONTHS[d.getMonth()] + ' ' + d.getDate() + ', ' + d.getFullYear();
  }
  function getPath(obj, path) {
    var ks = String(path).split('.'), o = obj;
    for (var i = 0; i < ks.length; i++) { if (o === undefined || o === null) return undefined; o = o[ks[i]]; }
    return o;
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
  function lines(m) { return feeLines(m.people, m.track, status.fees); }
  function fees(m) { return feesTotal(lines(m)); }
  function soldOut(which) { return status.counts[which] >= status.caps[which]; }
  function trackFull(track) {
    return track === 'bambino' ? status.counts.bambino >= status.caps.bambino : status.counts.full >= status.caps.full;
  }
  function trackWords(track) { return t(track === 'bambino' ? 'track.bambino' : 'track.full'); }
  // the short venue names the weekend summary reads, out of the copy, so
  // an organizer who moves a social moves the summary with it
  function venueWords() {
    return { social_fri: t('form.social_fri.short'), social_sat: t('form.social_sat.short') };
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
      '<div class="label">' + tx('landing.meter', { count: status.counts.full, cap: status.caps.full, percent: pct }) + '</div>' +
      (pct > 80 ? '<div class="label hurry">' + tx('landing.meter.hurry') + '</div>' : '') + '</div>';
    if (!status.open) return out + '<div class="card soft"><p>' + tx('landing.closed') + '</p></div>';
    function door(track) {
      var full = trackFull(track);
      return '<div class="card door"><h2>' + tx('landing.' + track + '.title') + '</h2>' +
        '<p>' + tx('landing.' + track + '.blurb') + '</p>' +
        '<p class="for">' + tx('landing.' + track + '.who') + '</p>' +
        '<p class="fee">' + tx('landing.' + track + '.fee') + '</p>' +
        (full ? '<p class="muted">' + tx('landing.soldout') + '</p><a class="btn quiet" href="#form/' + track + '">' + tx('landing.waitlist.button') + '</a>'
              : '<a class="btn" href="#form/' + track + '">' + tx('landing.' + track + '.button') + '</a>') + '</div>';
    }
    return out + '<div class="doors">' + door('full') + door('bambino') + '</div>' +
      '<p class="help choose">' + tx('landing.choose') + '</p>';
  }
  // in edit mode a field's caption is a plain block, not a <label>: a
  // click inside a <label> jumps to the field it names, which would
  // take the caret straight out of the span being typed into
  function input(k, key, value, type, extra) {
    var box = '<input type="' + (type || 'text') + '" data-k="' + k + '" value="' + esc(value) + '"' + (extra || '') + '>';
    if (editing) return '<div class="field">' + tx(key) + box + '</div>';
    return '<label>' + esc(t(key)) + box + '</label>';
  }
  // `vars` fills the string's placeholders; `mark` is put on the span
  // that holds it, so a live rename can rewrite that span alone
  function check(k, key, on, off, noteKey, vars, mark, extraCls) {
    var body = '<input type="checkbox" data-k="' + k + '"' + (on ? ' checked' : '') + (off ? ' disabled' : '') + '>' +
      '<span' + (mark || '') + '>' + tx(key, vars) + (noteKey ? ' <span class="note">' + tx(noteKey) + '</span>' : '') + '</span>';
    var cls = 'check' + (off ? ' off' : '') + (extraCls || '');
    if (editing) return '<div class="' + cls + '">' + body + '</div>';
    return '<label class="' + cls + '">' + body + '</label>';
  }
  // a two-option choice. `val` is what the change handler reads back,
  // and `group` keeps the pair together for the keyboard.
  function radio(k, group, val, key, on, vars, mark, bool) {
    var body = '<input type="radio" name="' + group + '" data-k="' + k + '" value="' + esc(val) + '"' +
      (bool ? ' data-bool="1"' : '') + (on ? ' checked' : '') + '>' +
      '<span' + (mark || '') + '>' + tx(key, vars) + '</span>';
    if (editing) return '<div class="check">' + body + '</div>';
    return '<label class="check">' + body + '</label>';
  }
  // the name a person is called by on screen: what has been typed for
  // them, else the copy's "You" for the registrant and "Person {{n}}"
  // for everybody else
  function who(p, i) {
    return typedName(p) || (i === 0 ? t('form.you') : t('form.person', { n: i + 1 }));
  }
  // the first person, as the rest of the party's radio names them. Its
  // fallback is the lower-case "you", because it sits in a sentence.
  function leadName(m) {
    return typedName(m.people[0]) || t('form.you.lower');
  }
  // the card's heading. A typed name is the pilgrim's own text, so it is
  // escaped and never editable; the fallback is copy, so it is.
  function personHead(p, i) {
    var name = typedName(p);
    if (name) return esc(name);
    return i === 0 ? tx('form.you') : tx('form.person', { n: i + 1 });
  }
  // "Your weekend" until the registrant types a name, "Ana's weekend"
  // after it, and "Person 2's weekend" for anybody else not yet named
  function weekendTitle(p, i) {
    var name = typedName(p);
    if (i === 0 && !name) return tx('form.weekend.you');
    return tx('form.weekend', { name: name || t('form.person', { n: i + 1 }) });
  }
  // the first card is the registrant's own, so this section and the
  // first-time box speak to them in the second person throughout
  function aboutTitle(p, i) {
    if (i === 0) return tx('form.about.you');
    return tx('form.about', { name: typedName(p) || t('form.person', { n: i + 1 }) });
  }
  function firstBscLabel(i) { return i === 0 ? 'form.first_bsc.you' : 'form.first_bsc'; }
  // the words under the "Same weekend" radio: what the first person
  // chose, spelled out, so the choice being offered is on the screen
  function summaryOf(m) {
    return esc(weekendWords(m.people[0], m.track, venueWords()));
  }
  // the whole party's weekend, for the last page
  function partyWords(people, track) {
    return (people || []).map(function (p, i) {
      return who(p, i) + ': ' + weekendWords(p, track, venueWords());
    }).join(' ');
  }
  // the pair of radios that opens a second person's weekend, with the
  // first person's choices written out under the one that copies them
  function sameBox(i, m) {
    var g = 'weekend' + i;
    var name = { first: leadName(m) };
    return '<div class="sameas">' +
      radio('same.' + i, g, 'same', 'form.same_weekend', !!sameAs[i], name,
        ' class="who" data-who="same" data-i="' + i + '"') +
      '<p class="summary who" data-who="summary" data-i="' + i + '">' + summaryOf(m) + '</p>' +
      radio('same.' + i, g, 'own', 'form.own_weekend', !sameAs[i], null) +
      '</div>';
  }
  // one group of choices, headed by the question it answers
  function group(title, body) { return '<div class="group"><h4>' + title + '</h4>' + body + '</div>'; }
  function socialRow(k, key, on, which) {
    var gone = soldOut(which) && !on;
    return check(k, key, on, gone, gone ? 'form.social_soldout' : '');
  }
  function choices(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '';
    if (m.track === 'full') {
      var days = check(k + 'days.fri', 'form.fri', p.days.fri) +
        check(k + 'days.sat', 'form.sat', p.days.sat) +
        check(k + 'days.sun', 'form.sun', p.days.sun);
      if (p.days.sun) {
        days += '<div class="sub">' +
          radio(k + 'sun_ten', 'sun' + i, '1', 'form.sun.ten', !!p.sun_ten, null, '', true) +
          radio(k + 'sun_ten', 'sun' + i, '', 'form.sun.short', !p.sun_ten, null, '', true) + '</div>';
      }
      out += group(tx('form.days'), days);
      out += group(tx('form.friday.title'), p.days.fri
        ? check(k + 'mass_fri', 'form.mass_fri', p.mass_fri) +
          check(k + 'holy_hour', 'form.holy_hour', p.holy_hour) +
          socialRow(k + 'social_fri', 'form.social_fri', p.social_fri, 'social_fri')
        : '<p class="closed">' + tx('form.friday.closed') + '</p>');
      out += group(tx('form.saturday.title'), p.days.sat
        ? socialRow(k + 'social_sat', 'form.social_sat', p.social_sat, 'social_sat')
        : '<p class="closed">' + tx('form.saturday.closed') + '</p>');
    } else {
      // the Bambino weekend is the Sunday walk and the socials, which
      // are open to everyone who comes
      out += group(tx('form.days'), check(k + 'days.sun', 'form.sun.bambino', p.days.sun));
      out += group(tx('form.also.title'),
        check(k + 'mass_fri', 'form.mass_fri', p.mass_fri) +
        check(k + 'holy_hour', 'form.holy_hour', p.holy_hour) +
        socialRow(k + 'social_fri', 'form.social_fri', p.social_fri, 'social_fri') +
        socialRow(k + 'social_sat', 'form.social_sat', p.social_sat, 'social_sat'));
    }
    out += group(tx('form.around.title'), check(k + 'bus', 'form.bus', p.bus));
    return out;
  }
  function person(p, i, m) {
    var k = 'people.' + i + '.';
    var out = '<div class="card person"><h2 class="who" data-who="head" data-i="' + i + '">' + personHead(p, i) + '</h2>';
    if (m.people.length > 1) {
      out += '<button type="button" class="remove who" data-act="remove" data-who="remove" data-i="' + i +
        '" aria-label="' + esc(t('form.remove_person', { name: who(p, i) })) + '">' +
        tx('form.remove_person', { name: who(p, i) }) + '</button>';
    }
    out += '<div class="row">' + input(k + 'first', 'form.first', p.first) + input(k + 'last', 'form.last', p.last) + '</div>';
    out += check(k + 'child', 'form.child', p.child);
    out += '<div class="weekend"><h3 class="who" data-who="weekend" data-i="' + i + '">' + weekendTitle(p, i) + '</h3>';
    // everybody after the first says for themselves whether their
    // weekend is the first person's or their own
    if (i > 0) out += sameBox(i, m);
    if (i === 0 || !sameAs[i]) out += choices(p, i, m);
    out += '</div>';
    out += '<div class="about"><h3 class="who" data-who="about" data-i="' + i + '">' + aboutTitle(p, i) + '</h3>';
    out += check(k + 'first_bsc', firstBscLabel(i), p.first_bsc, false, '',
      { name: who(p, i) }, ' class="who" data-who="first_bsc" data-i="' + i + '"');
    out += check(k + 'knight_dame', 'form.knight_dame', p.knight_dame) + check(k + 'volunteer', 'form.volunteer', p.volunteer);
    return out + '</div></div>';
  }
  function feesBox(m) {
    var out = '<div class="card soft fees"><h2>' + tx('form.fees.title') + '</h2><table>';
    lines(m).forEach(function (l) {
      out += '<tr><td>' + tx('form.fees.line', {
        name: l.name || who(m.people[l.i], l.i),
        what: t('form.fees.' + l.kind),
        each: money(l.each)
      }) + '</td><td>' + esc(money(l.each)) + '</td></tr>';
    });
    return out + '<tr class="total"><td>' + tx('form.fees.total') + '</td><td>' + esc(money(fees(m))) + '</td></tr></table>' +
      '<p class="help">' + tx('form.fees.nonrefundable') + '</p></div>';
  }
  function form(m) {
    var c = m.contact;
    var out = '<h1>' + tx(mode === 'manage' ? 'manage.title' : 'form.title') + '</h1>';
    if (mode === 'manage') {
      out += '<p class="help">' + tx('manage.line', {
        created: dateWords(manageMade),
        cutoff: dateWords(getPath(status, 'window.change_cutoff'))
      }) + '</p>';
      if (!status.changes_open) out += '<div class="card soft"><p>' + tx('manage.closed') + '</p></div>';
    }
    out += '<div id="error"></div>';
    // 1. who is coming
    out += '<h2>' + tx('form.people.title') + '</h2><p class="help">' + tx('form.people.help') + '</p>';
    m.people.forEach(function (p, i) { out += person(p, i, m); });
    if (m.people.length < status.caps.party) out += '<button type="button" class="btn quiet small" data-act="add">' + tx('form.add_person') + '</button>';
    // 2. how we reach you
    out += '<div class="card"><h2>' + tx('form.contact.title') + '</h2><p class="help">' + tx('form.contact.help') + '</p>';
    out += '<div class="row">' + input('contact.email', 'form.email', c.email, 'email', ' autocomplete="email"') + input('contact.phone', 'form.phone', c.phone, 'tel', ' autocomplete="tel"') + '</div>';
    out += input('contact.street', 'form.street', c.street, 'text', ' autocomplete="street-address"');
    out += '<div class="row3">' + input('contact.city', 'form.city', c.city, 'text', ' autocomplete="address-level2"') +
      input('contact.state', 'form.state', c.state, 'text', ' autocomplete="address-level1" maxlength="40"') +
      input('contact.zip', 'form.zip', c.zip, 'text', ' autocomplete="postal-code"') + '</div>';
    out += '<p class="help">' + tx('form.address.help') + '</p>';
    out += input('org', 'form.org', m.org, 'text', ' list="orgs"') + '<datalist id="orgs">' +
      (status.orgs || []).map(function (o) { return '<option value="' + esc(o) + '">'; }).join('') + '</datalist>';
    out += '<p class="help">' + tx('form.org.help') + '</p></div>';
    // 3. why are you walking
    var why = '<textarea data-k="why" aria-label="' + esc(t('form.why')) + '">' + esc(m.why) + '</textarea>';
    out += '<div class="card"><h2>' + tx('form.why') + '</h2><p class="help">' + tx('form.why.help') + '</p>' + why;
    out += check('assistance', 'form.assistance', m.assistance) + '<p class="help">' + tx('form.assistance.help') + '</p></div>';
    // 4. what it costs, and the button
    out += feesBox(m);
    out += '<div class="actions">';
    if (mode === 'manage') {
      if (status.changes_open) {
        out += '<button type="button" class="btn" data-act="save">' + tx('manage.save') + '</button>' +
          '<button type="button" class="btn danger" data-act="cancel">' + tx('manage.cancel') + '</button>';
      }
    } else {
      var full = trackFull(m.track);
      out += '<button type="button" class="btn" data-act="submit">' +
        tx(full ? 'form.submit.waitlist' : 'form.submit') + '</button>';
    }
    out += '<span id="save-status" class="status"></span></div>';
    if (mode !== 'manage') {
      out += '<p class="help room">' + tx(trackFull(m.track) ? 'form.submit.full' : 'form.submit.room',
        { track: trackWords(m.track) }) + '</p>';
    }
    return out;
  }
  function nextStep(r) {
    var s = r.status, out = '';
    var people = r.people || [];
    var names = joinWords(people.map(function (p, i) { return who(p, i); }));
    var spots = people.length === 1 ? '' : t('next.payment.spots', { n: people.length });
    function block(key, vars) { return '<h1>' + tx('next.' + key + '.title') + '</h1><p>' + tx('next.' + key + '.body', vars) + '</p>'; }
    var lapsed = r.lapsed && (s === 'waiver' || s === 'payment') ? '<p class="muted">' + tx('next.lapsed') + '</p>' : '';
    if (s === 'waiver') out = block('waiver', { names: names }) + lapsed + '<button type="button" class="btn" data-act="sign">' + tx('next.waiver.button') + '</button>';
    else if (s === 'payment') {
      out = '<h1>' + tx('next.payment.title') + '</h1><p>' +
        tx(spots ? 'next.payment.body' : 'next.payment.body.one',
          { spots: spots, names: names, total: money(r.fees) }) + '</p>' + lapsed +
        '<button type="button" class="btn" data-act="pay">' + tx('next.payment.button', { total: money(r.fees) }) + '</button>';
    }
    else if (s === 'assistance') out = block('assistance');
    else if (s === 'waitlist') out = block('waitlist', { position: r.position, track: trackWords(r.track) });
    else if (s === 'complete') {
      // the last page greets the registrant, so it uses the given name
      // they typed and falls back to whatever the form calls them
      out = block('complete', {
        first: String((people[0] || {}).first || '').trim() || who(people[0], 0),
        email: (r.contact || {}).email,
        summary: partyWords(people, r.track)
      }) + '<p><a class="btn quiet" href="#manage/' + esc(rid) + '/' + esc(token) + '">' + tx('manage.title') + '</a></p>';
    }
    else if (s === 'cancelled') out = block('cancelled');
    else out = block('draft');
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
    document.body.classList.toggle('editing', editing);
    stepsEl.hidden = !editing;
    stepsEl.innerHTML = editing ? stepsHtml() : '';
  }
  // the fixtures: a fake registration and a fake status, so every
  // string a pilgrim reads is on screen without walking the flow
  function fixtureReg(st) {
    var m = fixtureModel('full');
    return { status: st, fees: 22500, position: 3, lapsed: true, track: 'full',
      people: m.people, contact: { email: 'pilgrim@example.com' } };
  }
  // the full-track fixture is a named party of two, so the weekend radio,
  // its summary and every string that carries a name are on screen. The
  // Bambino fixture is one person with nothing typed, which is how the
  // strings that speak to the registrant as "you" get on screen too.
  function fixtureModel(track) {
    var m = blankModel(track);
    m.people[0].days.sun = true;
    m.people[0].mass_fri = true;
    if (track !== 'full') return m;
    m.people.push(blankPerson(track));
    m.people[0].first = 'Ana';
    m.people[0].last = 'Silva';
    m.people[0].days.fri = true;
    m.people[0].sun_ten = true;
    m.people[1] = copyChoices(m.people[0], m.people[1]);
    // the second person is a child, so the fee table shows the word a
    // child's line carries as well as the one an adult's does
    m.people[1].child = true;
    return m;
  }
  // the second person of a fixture party follows the first, the way a
  // person added to a real party does
  function fixtureSame(m) {
    return m.people.map(function (p, i) { return i > 0; });
  }
  function otherHtml() {
    return '<h1>Other strings</h1><p class="muted">A status line, a dialog and what an error says. ' +
      'They belong to no step of their own.</p><div class="card otherlist">' +
      OTHER.map(function (k) { return '<span class="key">' + esc(k) + '</span><p>' + tx(k) + '</p>'; }).join('') +
      '</div>';
  }
  function previewHtml(name) {
    // every module variable a preview may touch must be listed here
    var keep = { status: status, model: model, mode: mode, rid: rid, token: token, sameAs: sameAs,
      manageMade: manageMade };
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
        sameAs = fixtureSame(model);
        out = form(model);
      } else if (name === 'manage') {
        mode = 'manage';
        status.changes_open = true;
        manageMade = status.now;
        model = fixtureModel('full');
        sameAs = fixtureSame(model);
        out = form(model);
      } else if (name === 'other') {
        out = otherHtml();
      } else {
        mode = 'next';
        out = nextStep(fixtureReg(name));
      }
    } finally {
      status = keep.status; model = keep.model; mode = keep.mode; rid = keep.rid; token = keep.token;
      sameAs = keep.sameAs; manageMade = keep.manageMade;
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
  // the view on screen, drawn again from the copy the page now holds. No
  // read: the document in hand is already the one the ship took.
  function repaint() {
    var on = document.activeElement;
    var held = on && on.classList && on.classList.contains('copy') ? on.getAttribute('data-copy') : '';
    if (step) render(previewHtml(step));
    else if (mode === 'landing') render(landing());
    else if ((mode === 'new' || mode === 'manage') && model) render(form(model));
    else if (mode === 'next' && lastReg) render(nextStep(lastReg));
    else return;
    if (!held) return;
    var back = document.querySelector('.copy[data-copy="' + held + '"]');
    if (back) back.focus();
  }
  function sendCopy(el, key, next, was) {
    // the page shows the new string the moment the request goes up, so
    // a re-render keeps it; a refusal puts the old one back
    status.copy[key] = next;
    post('/admin/copy/set', { key: key, value: next }, true).then(function () {
      // one key can stand in more than one place, so the whole view is
      // drawn again and the tick goes on the span that is there now
      repaint();
      flag(document.querySelector('.copy[data-copy="' + key + '"]') || el, '✓', false);
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
        fresh = { status: d.status, position: d.position, fees: d.fees, contact: model.contact,
          people: JSON.parse(JSON.stringify(model.people)), track: model.track, lapsed: false };
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
          // a party that came from somewhere else is taken as it stands:
          // nobody is following anybody until the pilgrim says so
          sameAs = [];
          var d = recall(parts[1]); rid = d ? d.rid : null; token = d ? d.token : null;
          if (rid) {
            render(loading());
            return api('/reg/' + rid + '?t=' + encodeURIComponent(token)).then(function (r) {
              if (gen !== routeGen) return;
              if (r.status === 'draft') model = fromReg(r); else { rid = null; token = null; }
              sameAs = [];
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
          manageWas = r.status;
          manageMade = r.created;
          model = fromReg(r);
          // a party that registered together comes back with the same
          // choices on every card, so the radio says so rather than
          // opening every card's boxes again
          sameAs = sameFrom(model.people);
          render(form(model));
        }).catch(function (e) {
          if (gen !== routeGen) return;
          render('<div id="error"></div>'); showError(e.message);
        });
      }
      model = null; sameAs = []; rid = null; token = null; mode = 'landing';
      render(landing());
    }).catch(function (e) {
      if (gen !== routeGen) return;
      render('<p class="bad">' + esc(e.message) + '</p>');
    });
  }
  view.addEventListener('input', onChange);
  view.addEventListener('change', onChange);
  // a typed name moves the card headings, the weekend and About lines,
  // the first-time box, the remove buttons and the fee lines; a change
  // to the first person's weekend moves every summary that shows it.
  // Only those nodes are rewritten, so the field being typed into keeps
  // its caret.
  function retouch() {
    var first = leadName(model);
    Array.prototype.forEach.call(view.querySelectorAll('.who'), function (el) {
      var kind = el.getAttribute('data-who');
      var i = Number(el.getAttribute('data-i'));
      var p = model.people[i];
      if (!p) return;
      if (kind === 'head') el.innerHTML = personHead(p, i);
      else if (kind === 'weekend') el.innerHTML = weekendTitle(p, i);
      else if (kind === 'about') el.innerHTML = aboutTitle(p, i);
      else if (kind === 'first_bsc') el.innerHTML = tx(firstBscLabel(i), { name: who(p, i) });
      else if (kind === 'same') el.innerHTML = tx('form.same_weekend', { first: first });
      else if (kind === 'summary') el.innerHTML = summaryOf(model);
      else if (kind === 'remove') {
        el.innerHTML = tx('form.remove_person', { name: who(p, i) });
        el.setAttribute('aria-label', t('form.remove_person', { name: who(p, i) }));
      }
    });
    var fb = view.querySelector('.fees');
    if (fb) fb.outerHTML = feesBox(model);
  }
  // a day tick and the weekend radio both draw the form again, which
  // replaces the control that was just operated and takes the keyboard
  // back to the top of the page. Put it on the new control instead. A
  // pair of radios shares one data-k, so the value tells them apart.
  function refocus(k, val) {
    var sel = '[data-k="' + k + '"]' + (val === undefined ? '' : '[value="' + val + '"]');
    var el = view.querySelector(sel);
    if (el) el.focus();
  }
  function onChange(ev) {
    if (editing) return;
    var el = ev.target, k = el.getAttribute('data-k');
    if (!k || !model) return;
    var box = el.type === 'checkbox';
    if (ev.type === 'change' && !box) return;
    if (ev.type === 'input' && box) return;
    var val = el.type === 'checkbox' ? el.checked : el.value;
    if (el.type === 'radio' && el.getAttribute('data-bool')) val = el.value === '1';
    // the weekend radio is the page's own, not a field of the model: it
    // copies the first person's choices in and hides the groups
    var same = /^same\.(\d+)$/.exec(k);
    if (same) {
      var j = Number(same[1]);
      sameAs[j] = el.value === 'same';
      if (sameAs[j]) model.people[j] = copyChoices(model.people[0], model.people[j]);
      render(form(model));
      refocus(k, el.value);
      scheduleSave();
      return;
    }
    setPath(model, k, val);
    // a change to the first person's weekend follows through to everyone
    // still copying it
    if (/^people\.0\.(days\.|sun_ten$|social_|mass_fri$|holy_hour$|bus$)/.test(k)) {
      model.people = syncSame(model.people, sameAs);
    }
    // a day opens or closes that day's group, so it re-renders; a name
    // or another choice only moves the lines that carry it
    if (/\.days\.(fri|sat|sun)$/.test(k)) { render(form(model)); refocus(k); }
    else retouch();
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
    if (act2 === 'add') {
      model.people.push(blankPerson(model.track));
      // somebody added to the party is doing what the first person is
      // doing until they say otherwise
      sameAs[model.people.length - 1] = true;
      model.people = syncSame(model.people, sameAs);
      render(form(model));
      scheduleSave();
    }
    else if (act2 === 'remove') {
      var gone = +el.getAttribute('data-i');
      model.people.splice(gone, 1);
      sameAs.splice(gone, 1);
      render(form(model));
      scheduleSave();
    }
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
      // the writer applies after the answer leaves, so the next page
      // must read past the status this one was loaded with, or a fast
      // read repaints the old status with nothing to correct it
      leaving = manageWas;
      post('/reg/' + rid + '/cancel?t=' + encodeURIComponent(token), {}).then(function () {
        fresh = { status: 'cancelled' };
        location.hash = '#next/' + rid + '/' + token;
      }).catch(function (e) { freeCancel(); leaving = null; showError(e.message); });
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
