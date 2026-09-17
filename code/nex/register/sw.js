// The check-in app's service worker: the shell is cached on install and
// served cache first, so a phone with no signal still opens the app. The
// API is never cached: the roster the volunteer works from is the copy
// in localStorage, not a stale HTTP answer.
var V = 'register-checkin-5';
var SHELL = [
  '/apps/register/checkin',
  '/apps/register/checkin.css',
  '/apps/register/checkin.js',
  '/apps/register/manifest.json',
  '/apps/register/icon-192.png',
  '/apps/register/icon-512.png'
];

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(V).then(function (c) {
    return Promise.all(SHELL.map(function (u) { return c.add(u).catch(function () { }); }));
  }).catch(function () { }));
  self.skipWaiting();
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
        if (r && r.ok) { c.put(u.pathname, r.clone()); }
        return r;
      });
      if (hit) { live.catch(function () { }); return hit; }
      return live.catch(function () { return new Response('offline', { status: 503 }); });
    });
  }).catch(function () { return fetch(q); }));
});
