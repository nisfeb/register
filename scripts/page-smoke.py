#!/usr/bin/env python3
"""page-smoke.py HOST
The public page and its assets answer without a cookie, with the right
types, nosniff and no-cache; the backoffice, the check-in app and their
assets refuse without one, and their pages redirect to the login form;
the PWA manifest, worker and icons answer without one on purpose."""
import subprocess, sys

HOST = sys.argv[1]
fails = []


def get(path):
    out = subprocess.run(['curl', '-s', '-m', '30', '-D', '-', HOST + path], capture_output=True, text=True).stdout
    head, _, body = out.partition('\r\n\r\n')
    if not _:
        head, _, body = out.partition('\n\n')
    code = int(head.split(' ')[1]) if head.startswith('HTTP/') else 0
    headers = {}
    for ln in head.split('\n')[1:]:
        k, _, v = ln.partition(':')
        headers[k.strip().lower()] = v.strip()
    return code, headers, body


def check(label, cond, detail=''):
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


code, h, b = get('/apps/register/')
check('the page answers 200 as html without a cookie', code == 200 and h.get('content-type', '').startswith('text/html'), (code, h))
check('the page is not cached', 'no-cache' in h.get('cache-control', ''), h)
check('the page loads its script and style', 'public.js' in b and 'public.css' in b and 'id="view"' in b, b[:200])
code, h, b = get('/apps/register/public.css')
check('the style is text/css with nosniff', code == 200 and h.get('content-type', '').startswith('text/css') and h.get('x-content-type-options') == 'nosniff', (code, h))
code, h, b = get('/apps/register/public.js')
check('the script is text/javascript', code == 200 and h.get('content-type', '').startswith('text/javascript'), (code, h))
code, h, b = get('/apps/register/api/status')
check('status is json and not stored', code == 200 and h.get('content-type', '').startswith('application/json') and 'no-store' in h.get('cache-control', ''), (code, h))
code, h, b = get('/apps/register/api/admin/regs')
check('the admin api refuses without a cookie', code == 403, code)
code, h, b = get('/apps/register/admin')
check('the backoffice without a cookie redirects to the login form',
      code == 302 and '/~/login' in h.get('location', ''), (code, h.get('location')))
code, h, b = get('/apps/register/admin.css')
check('the backoffice style refuses without a cookie', code == 403, code)
code, h, b = get('/apps/register/admin.js')
check('the backoffice script refuses without a cookie', code == 403, code)
code, h, b = get('/apps/register/checkin')
check('the check-in app without a cookie redirects to the login form',
      code == 302 and '/~/login' in h.get('location', '') and 'checkin' in h.get('location', ''), (code, h.get('location')))
code, h, b = get('/apps/register/checkin.js')
check('the check-in script refuses without a cookie', code == 403, code)
# the PWA assets answer without a cookie: a browser fetches a manifest,
# an icon and a service worker uncredentialed, and behind the owner gate
# the install would degrade to a bookmark
code, h, b = get('/apps/register/manifest.json')
check('the manifest answers 200 without a cookie as a manifest',
      code == 200 and h.get('content-type', '').startswith('application/manifest+json'), (code, h))
check('the manifest names the app, its scope and its icons',
      '"BSC Check-in"' in b and '/apps/register/' in b and 'icon-512.png' in b, b[:200])
code, h, b = get('/apps/register/sw.js')
check('the service worker answers 200 without a cookie as javascript',
      code == 200 and h.get('content-type', '').startswith('text/javascript'), (code, h))
check('the worker may claim the whole app scope and is not cached',
      h.get('service-worker-allowed') == '/apps/register/' and 'no-cache' in h.get('cache-control', ''), h)
for icon in ('icon-192.png', 'icon-512.png'):
    code, h, b = get('/apps/register/' + icon)
    check(icon + ' answers 200 without a cookie as a png that may be cached',
          code == 200 and h.get('content-type', '') == 'image/png'
          and 'max-age' in h.get('cache-control', ''), (code, h))
code, h, b = get('/apps/register/nothing')
check('an unknown route is 404', code == 404, code)
print()
print('ALL OK' if not fails else f'{len(fails)} FAILED: ' + '; '.join(fails))
sys.exit(1 if fails else 0)
