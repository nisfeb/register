#!/usr/bin/env python3
"""Check-in durability: does every check-in the ship acknowledged survive?

Two modes, run against a TEST ship (it writes check-ins and undoes):

  checkin-durability.py BASE JAR burst LOG [--seconds N] [--day fri] [--parties N]
                        [--volunteers N] [--editor 1]
  checkin-durability.py BASE JAR verify LOG

burst fires volunteer taps (POST /api/checkin, check-ins and undos, one
to five per batch) and pilgrim self check-ins (POST /api/reg/<rid>/checkin)
at the ship for N seconds, on two disjoint sets of complete parties, and
appends one line to LOG for every write: acked (the ship answered 200 and
did not name the item as rejected) or not. Each line is flushed and
fsynced before the next request, so a line in LOG is a write the phone
or pilgrim was told about. Kill the ship whenever you like during a
burst; the script keeps trying and logs the failures as not acked.

verify reads the ship's roster for every day in LOG and holds it against
the last acked write for each person and day:

  - acked check-in, then no later attempt   -> must be checked in
  - acked undo, then no later attempt       -> must not be checked in
  - any later attempt that was not acked    -> either is fine (the phone
                                               would still hold it)

Anything else is printed and the exit status is 1. Self check-ins on a
person the volunteer side never touches cannot be undone, so they only
ever expect checked.

The ship must take self check-ins today: set its event days so today is
--day, and keep it in stub mode. JAR is a curl cookie jar or a file with
one line `urbauth-~ship=0v...`.
"""
import json
import os
import random
import sys
import threading
import time
import urllib.error
import urllib.request


def cookie(jar):
    text = open(jar).read()
    for line in text.splitlines():
        parts = line.split('\t')
        if len(parts) >= 7 and parts[5].startswith('urbauth'):
            return parts[5] + '=' + parts[6]
        if line.startswith('urbauth'):
            return line.strip()
    sys.exit('checkin-durability: no urbauth cookie in ' + jar)


class Ship:
    def __init__(self, base, jar):
        self.base = base.rstrip('/')
        self.cookie = cookie(jar)

    def req(self, method, path, body=None, auth=True, timeout=60):
        data = json.dumps(body).encode() if body is not None else None
        h = {'content-type': 'application/json', 'x-actor': 'durability'}
        if auth:
            h['cookie'] = self.cookie
        r = urllib.request.Request(self.base + path, data=data, headers=h, method=method)
        try:
            with urllib.request.urlopen(r, timeout=timeout) as resp:
                return resp.status, json.loads(resp.read() or b'{}')
        except urllib.error.HTTPError as e:
            try:
                return e.code, json.loads(e.read() or b'{}')
            except ValueError:
                return e.code, {}


API = '/apps/register/api'


class Log:
    def __init__(self, path):
        self.f = open(path, 'a')
        self.lock = threading.Lock()
        self.seq = 0

    def write(self, **kw):
        with self.lock:
            self.seq += 1
            kw['seq'] = self.seq
            kw['t'] = time.time()
            self.f.write(json.dumps(kw) + '\n')
            self.f.flush()
            os.fsync(self.f.fileno())


def parties(ship, n):
    st, d = ship.req('GET', API + '/admin/regs')
    if st != 200:
        sys.exit('checkin-durability: regs %s' % st)
    rows = d if isinstance(d, list) else d.get('regs') or d.get('rows') or []
    done = [r for r in rows if r.get('status') == 'complete' and int(r.get('people') or 0) > 0]
    random.shuffle(done)
    # the pilgrim's link token is in the backup bundle, not in the
    # backoffice's record view
    st, b = ship.req('GET', API + '/admin/export/bundle.json')
    if st != 200:
        sys.exit('checkin-durability: bundle %s' % st)
    tokens = {r['id']: r.get('token', '') for r in b.get('regs', [])}
    return [{'rid': r['id'], 'n': int(r['people']), 'token': tokens.get(r['id'], '')}
            for r in done[:n] if tokens.get(r['id'])]


def volunteer(ship, log, mine, day, until):
    while time.time() < until:
        batch = []
        for _ in range(random.randint(1, 5)):
            p = random.choice(mine)
            batch.append({'rid': p['rid'], 'i': random.randrange(p['n']), 'undo': random.random() < 0.3})
        try:
            st, d = ship.req('POST', API + '/checkin', {'day': day, 'checkins': batch})
        except Exception as e:  # the ship is down, or the socket died
            st, d = 0, {'error': str(e)}
        bad = {(str(b.get('rid')), int(b.get('i', -1))) for b in (d.get('rejected') or [])} if st == 200 else set()
        for it in batch:
            acked = st == 200 and (it['rid'], it['i']) not in bad
            log.write(kind='vol', rid=it['rid'], i=it['i'], day=day, undo=it['undo'], acked=acked, status=st)
        if st != 200:
            time.sleep(1)


def editor(ship, log, theirs, until):
    """an organizer re-saving parties that are being checked in: the
    backoffice's edit, with the people as they are and the org toggled,
    so every save is a real write racing the taps"""
    n = 0
    while time.time() < until:
        p = random.choice(theirs)
        try:
            st, reg = ship.req('GET', API + '/admin/reg/' + p['rid'])
            if st == 200:
                inp = {k: reg[k] for k in ('track', 'contact', 'org', 'why', 'assistance', 'together') if k in reg}
                inp['org'] = (inp.get('org') or '').rstrip('.') + ('' if (inp.get('org') or '').endswith('.') else '.')
                inp['people'] = [{k: v for k, v in q.items() if k != 'checkins'} for q in reg['people']]
                st, _ = ship.req('POST', API + '/admin/reg/' + p['rid'], {'op': 'edit', 'input': inp})
                n += st == 200
        except Exception:
            pass
        time.sleep(0.3)
    log.write(kind='editor', rid='-', i=-1, day='-', undo=False, acked=False, status=n)


def pilgrim(ship, log, mine, day, until):
    while time.time() < until:
        p = random.choice(mine)
        idx = sorted(random.sample(range(p['n']), random.randint(1, p['n'])))
        path = API + '/reg/' + p['rid'] + '/checkin?t=' + p['token']
        try:
            st, d = ship.req('POST', path, {'people': idx}, auth=False)
        except Exception as e:
            st, d = 0, {'error': str(e)}
        for i in idx:
            log.write(kind='self', rid=p['rid'], i=i, day=day, undo=False, acked=st == 200, status=st)
        if st != 200:
            time.sleep(1)


def burst(ship, path, argv):
    seconds, day, n, vols, edit = 120, 'fri', 40, 1, False
    for k, v in zip(argv[::2], argv[1::2]):
        if k == '--seconds':
            seconds = int(v)
        elif k == '--day':
            day = v
        elif k == '--parties':
            n = int(v)
        elif k == '--volunteers':
            vols = int(v)
        elif k == '--editor':
            edit = v == '1'
    ps = parties(ship, n)
    if len(ps) < 4:
        sys.exit('checkin-durability: need at least 4 complete parties, have %d' % len(ps))
    half = len(ps) // 2
    log = Log(path)
    until = time.time() + seconds
    # each volunteer works its own slice, so the order of one person's
    # taps is the order they were sent; the editor races all of them
    vp = ps[:half]
    ts = [threading.Thread(target=volunteer, args=(ship, log, vp[k::vols], day, until)) for k in range(vols)]
    ts.append(threading.Thread(target=pilgrim, args=(ship, log, ps[half:], day, until)))
    if edit:
        ts.append(threading.Thread(target=editor, args=(ship, log, ps, until)))
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    print('burst: %d writes logged to %s' % (log.seq, path))


def verify(ship, path):
    last = {}       # key -> the last acked line
    after = {}      # key -> an attempt after the last ack was not acked
    for line in open(path):
        e = json.loads(line)
        if e['kind'] == 'editor':
            print('verify: the editor saved %d edits during the burst' % e['status'])
            continue
        key = (e['rid'], int(e['i']), e['day'])
        if e['acked']:
            last[key] = e
            after[key] = False
        else:
            after[key] = True
    days = sorted({k[2] for k in last})
    held = {}
    for day in days:
        st, d = ship.req('GET', API + '/checkin/roster?day=' + day)
        if st != 200:
            sys.exit('checkin-durability: roster %s %s' % (day, st))
        for r in d.get('rows', []):
            for p in r.get('people', []):
                held[(r['rid'], int(p['i']), day)] = bool(p.get('checked'))
    lost, ghost, loose, good = [], [], 0, 0
    for key, e in sorted(last.items()):
        want = not e['undo']
        have = held.get(key)
        if after.get(key):
            loose += 1
            continue
        if have == want:
            good += 1
        elif want:
            lost.append((key, e))
        else:
            ghost.append((key, e))
    print('verify: %d people-days held as acked, %d left open by a later unacked try' % (good, loose))
    for key, e in lost:
        print('  LOST   %s person %d %s: acked %s check-in at seq %d, the ship has none' % (key[0], key[1], key[2], e['kind'], e['seq']))
    for key, e in ghost:
        print('  GHOST  %s person %d %s: acked undo at seq %d, the ship still has the check-in' % (key[0], key[1], key[2], e['seq']))
    if lost or ghost:
        print('verify: FAIL, %d lost, %d ghost' % (len(lost), len(ghost)))
        sys.exit(1)
    print('verify: ALL OK')


def main():
    if len(sys.argv) < 5 or sys.argv[3] not in ('burst', 'verify'):
        sys.exit(__doc__)
    ship = Ship(sys.argv[1], sys.argv[2])
    if sys.argv[3] == 'burst':
        burst(ship, sys.argv[4], sys.argv[5:])
    else:
        verify(ship, sys.argv[4])


if __name__ == '__main__':
    main()
