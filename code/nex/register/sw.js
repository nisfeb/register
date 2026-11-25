// The check-in app's service worker: the shell is cached on install and
// served cache first, so a phone with no signal still opens the app. The
// API is never cached: the roster the volunteer works from is the copy
// in localStorage, not a stale HTTP answer.
(function () {
  'use strict';
  // the release this shell belongs to. The version bump step changes
  // this number and code/version.json together, so every release lands a
  // new cache instead of serving the last release's files, and
  // page-smoke.py refuses a worker whose number has fallen behind.
  var VERSION = 21;
  var V = 'register-checkin-' + VERSION;
  // each shell path with the type its answer must carry. A ship that
  // wants the login again answers the page with the login form, and a
  // login form cached under checkin.js would brick the app on the next
  // cold start.
  var TYPES = {
    '/apps/register/checkin': 'text/html',
    '/apps/register/checkin.css': 'text/css',
    '/apps/register/checkin.js': 'javascript',
    '/apps/register/manifest.json': 'json',
    '/apps/register/icon-192.png': 'image/png',
    '/apps/register/icon-512.png': 'image/png'
  };
  var SHELL = Object.keys(TYPES);

  // what may go into the shell cache: this ship's own answer, not a
  // redirect, not an opaque one from elsewhere, and of the type the
  // path is meant to carry
  function keepable(path, r) {
    if (!r || !r.ok || r.redirected || r.type !== 'basic') return false;
    var want = TYPES[path];
    if (!want) return false;
    var got = String((r.headers && r.headers.get('content-type')) || '').toLowerCase();
    return got.indexOf(want) >= 0;
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { keepable: keepable, SHELL: SHELL, TYPES: TYPES, VERSION: VERSION, V: V };
  }
  if (typeof self === 'undefined' || !self.addEventListener) { return; }

  // all or nothing: a new worker takes over, and deletes the last
  // release's cache, only once it holds every shell file. Opened first
  // on a weak signal or logged out, it used to install with gaps and
  // throw the working cache away, and the next cold start with no
  // signal had no app. A failed install leaves the old worker and its
  // cache in place, and the browser tries again on a later open.
  self.addEventListener('install', function (e) {
    e.waitUntil(Promise.all(SHELL.map(function (u) {
      return fetch(u).then(function (r) {
        if (!keepable(u, r)) throw new Error('not keepable: ' + u);
        return [u, r];
      });
    })).then(function (got) {
      return caches.open(V).then(function (c) {
        return Promise.all(got.map(function (p) { return c.put(p[0], p[1]); }));
      });
    }).then(function () { return self.skipWaiting(); }));
  });

  self.addEventListener('activate', function (e) {
    e.waitUntil(caches.keys().then(function (ks) {
      return Promise.all(ks.filter(function (k) { return k !== V; }).map(function (k) {
        return caches.delete(k);
      }));
    }).then(function () { return self.clients.claim(); }));
  });

  self.addEventListener('fetch', function (e) {
    var q = e.request;
    if (q.method !== 'GET') return;
    var u = new URL(q.url);
    if (u.origin !== self.location.origin) return;
    if (u.pathname.indexOf('/apps/register/api/') === 0) return;
    if (SHELL.indexOf(u.pathname) < 0) return;
    e.respondWith(caches.open(V).then(function (c) {
      return c.match(u.pathname).then(function (hit) {
        var live = fetch(q).then(function (r) {
          if (keepable(u.pathname, r)) { c.put(u.pathname, r.clone()); }
          return r;
        });
        if (hit) { live.catch(function () { }); return hit; }
        return live.catch(function () { return new Response('offline', { status: 503 }); });
      });
    }).catch(function () { return fetch(q); }));
  });
})();
