#!/usr/bin/env python3
"""Deploy this checkout's code/ to register on a FAKE grubbery ship.

usage: dev-deploy.py <base-url> <cookie-jar> [--add] [--approve] [--wait] [--code DIR]

Mirrors code/ into the ball at /register-dev/code with the grubbery API
(GET /grubbery/api/peek to list and read, PUT /grubbery/api/make to
write, ?force=1 over a grub that is there), then stamps that tree's
version.json with a dev version, which makes the desk pull. Source is
made as /hoon, the desk-level json files (bill.json, tile.json,
version.json) as /json, and everything else as %mime typed by its
extension, which the nexus's /< imports expect; the four PNGs go up as
their bytes. With --add it first makes the desk: POST
/apps/grubbery/desks/add {name: register, code: /register-dev/code}, so
register lands where a real ship has it, <shell>/desks/register.desk
(kernel.py asks the ship which shell path it has). Files are written
only when they differ. --approve then grants the instance the roads of
its own weir.json and reloads its permits. --wait waits for the desk to
take the stamp, then fails if anything under the desk is banged.

Ported from calendar's dev-deploy.py (a7674b6) when register moved to
the current kernel. Never point this at a real ship: it is for fleet
ships (TESTING.md). Get a cookie jar with scripts/hoon-test-kit/ship-cookie.sh.
"""
import argparse, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kernel

ROOT = '/register-dev/code'
MITES = {'js': 'application/javascript', 'html': 'text/html', 'css': 'text/css',
         'svg': 'image/svg+xml', 'txt': 'text/plain', 'md': 'text/markdown',
         'json': 'application/json', 'hoon': 'text/plain', 'png': 'image/png'}


def cookie(jar):
    """the urbauth cookie from a curl jar (#HttpOnly_ lines included)"""
    for line in open(jar):
        f = line.removeprefix('#HttpOnly_').rstrip('\n').split('\t')
        if len(f) == 7 and f[5].startswith('urbauth-'):
            return f'{f[5]}={f[6]}'
    sys.exit(f'dev-deploy: no urbauth cookie in {jar}')


class Ship:
    def __init__(self, base, jar):
        self.base, self.cookie = base.rstrip('/'), cookie(jar)

    def req(self, path, data=None, ctype='application/json', method=None):
        url = self.base + urllib.parse.quote(path, safe='/?=&.~-_')
        h = {'Cookie': self.cookie}
        body = None if data is None else (data if isinstance(data, bytes) else data.encode())
        if body is not None:
            h['Content-Type'] = ctype
        r = urllib.request.Request(url, data=body, headers=h, method=method)
        try:
            with urllib.request.urlopen(r, timeout=600) as resp:
                return resp.status, resp.read()
        except urllib.error.HTTPError as e:
            return e.code, e.read()

    def children(self, d):
        """{'files': [...], 'dirs': [...]} for a ball dir, or None if it does not exist"""
        st, body = self.req('/grubbery/api/peek' + d + '/')
        if st == 404:
            return None
        if st != 200:
            sys.exit(f'dev-deploy: list {d}: {st} {body[:200]!r}')
        return json.loads(body)

    def mkdir(self, d):
        st, body = self.req('/grubbery/api/make' + d + '/', '{}', method='PUT')
        if st not in (200, 201, 409):
            sys.exit(f'dev-deploy: make {d}/: {st} {body[:400].decode(errors="replace")}')

    def put(self, f, src, blot, exists):
        """make the grub, or with ?force=1 overwrite the one that is there"""
        q = '&'.join(x for x in ('force=1' if exists else '', f'blot={blot}' if blot else '') if x)
        mite = MITES.get(f.rsplit('.', 1)[-1], 'text/plain')
        st, body = self.req('/grubbery/api/make' + f + ('?' + q if q else ''), src, mite, method='PUT')
        if st not in (200, 201):
            sys.exit(f'dev-deploy: make {f}: {st} {body[:400].decode(errors="replace")}')

    def raw(self, f):
        st, body = self.req('/grubbery/api/peek' + f)
        return body if st == 200 else None

    def text(self, f):
        b = self.raw(f)
        return b.decode(errors='replace') if b is not None else None


def ensure_dir(ship, d):
    if ship.children(d) is not None:
        return
    parent = d.rsplit('/', 1)[0]
    if parent:
        ensure_dir(ship, parent)
    ship.mkdir(d)


def same(there, src, name):
    """is the grub already this source? json is compared parsed: the ship
    renders it its own way"""
    if there is None:
        return False
    if name.endswith('.json'):
        try:
            return json.loads(there) == json.loads(src)
        except ValueError:
            return False
    return there == src


def blot_for(name, top):
    """/hoon for source; /json only for the desk-level files; anything
    else, json under nex/ included, stays %mime"""
    ext = name.rsplit('.', 1)[-1]
    if ext == 'hoon':
        return '/hoon'
    return '/json' if ext == 'json' and top else None


def wait(ship, desk, stamp):
    """until the desk's code carries the stamp, then any bang under it"""
    for _ in range(240):
        try:
            if json.loads(ship.text(desk + '/desk/code/version.json') or 'null')['version'] == stamp:
                break
        except (TypeError, KeyError, ValueError):
            pass
        time.sleep(5)
    else:
        sys.exit(f'dev-deploy: {desk} did not take {stamp} in 20 minutes')
    time.sleep(10)  # the instance reloads after the code lands
    st, body = ship.req('/grubbery/api/bang' + desk + '/')
    bang = json.loads(body) if st == 200 else {'banged': f'HTTP {st}'}
    print(f'dev-deploy: {desk} took {stamp}; banged: {bang["banged"]}')
    for h in bang.get('hits', []):
        print(f'  {h["where"]}: {" ".join(h["error"][:6])}')
    if bang['banged'] != 0:
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('base'); ap.add_argument('jar')
    ap.add_argument('--add', action='store_true', help='also make the desk (first deploy)')
    ap.add_argument('--approve', action='store_true', help='grant the instance its weir.json')
    ap.add_argument('--wait', action='store_true', help='wait for the desk to take the stamp; fail if banged')
    ap.add_argument('--code', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'code'))
    a = ap.parse_args()
    ship = Ship(a.base, a.jar)
    if not re.match(r'https?://(localhost|127\.0\.0\.1)(:\d+)?$', ship.base):
        sys.exit('dev-deploy: refusing a non-local ship; this is for fake fleet ships only')

    code = os.path.normpath(a.code)
    sent = 0
    for dirpath, dirs, files in os.walk(code):
        dirs.sort()
        rel = os.path.relpath(dirpath, code)
        d = ROOT if rel == '.' else ROOT + '/' + rel.replace(os.sep, '/')
        ensure_dir(ship, d)
        kids = ship.children(d) or {'files': []}
        for f in sorted(files):
            if rel == '.' and f == 'version.json':
                continue  # stamped last: changing it is what makes the desk pull
            data = open(os.path.join(dirpath, f), 'rb').read()
            on = f in kids['files']
            try:
                src = data.decode('utf-8')
                if on and same(ship.text(d + '/' + f), src, f):
                    continue
                ship.put(d + '/' + f, src, blot_for(f, rel == '.'), on)
            except UnicodeDecodeError:  # an image: its bytes, as %mime
                if on and ship.raw(d + '/' + f) == data:
                    continue
                ship.put(d + '/' + f, data, None, on)
            sent += 1
            print(f'  {d}/{f}', flush=True)

    ver = json.load(open(os.path.join(code, 'version.json')))['version']
    stamp = f'{ver}-dev-{int(time.time())}'
    on = 'version.json' in (ship.children(ROOT) or {'files': []})['files']
    ship.put(ROOT + '/version.json', json.dumps({'version': stamp}), '/json', on)
    print(f'dev-deploy: {sent} files written, version.json = {stamp}')

    if a.add:
        st, body = ship.req('/apps/grubbery/desks/add',
                            json.dumps({'name': 'register', 'code': ROOT}), 'application/json')
        print(f'dev-deploy: desks/add: {st} {body.decode(errors="replace")}')
        if st not in (200, 409):
            sys.exit(1)

    APP = kernel.app(ship.base, a.jar)
    if a.wait:
        wait(ship, kernel.desk(ship.base, a.jar), stamp)

    if a.approve:
        weir = None
        for _ in range(180):  # the instance appears once the desk has built (minutes)
            weir = ship.text(APP + '/weir.json')
            if weir:
                break
            time.sleep(5)
        if not weir:
            sys.exit(f'dev-deploy: no {APP}/weir.json yet; run --approve again later')
        # register's weir.json lists {road, why}; a grant is the roads
        granted = {k: [r['road'] if isinstance(r, dict) else r for r in v]
                   for k, v in json.loads(weir).items()}
        body = {'action': 'approve-weir', 'app': APP, 'picks': {}, 'granted': granted}
        for path, data in (('/apps/grubbery/permits', body), ('/apps/grubbery/permits/reload', {'app': APP})):
            st, out = ship.req(path, json.dumps(data), 'application/json')
            print(f'dev-deploy: {path}: {st}')
            if st not in (200, 303):
                sys.exit(out[:400].decode(errors='replace'))


if __name__ == '__main__':
    main()
