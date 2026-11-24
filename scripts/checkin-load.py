#!/usr/bin/env python3
"""Friday morning at the start line, against a TEST ship (plan phase 4).

usage: checkin-load.py BASE JAR LOG [--minutes 10] [--phones 8] [--taps 52] [--selfs 22] [--pier DIR]

Each phone does what the check-in app does: it holds the beacon stream
open and refetches the whole roster on every beacon change and every
60 s, and it sends its taps every 15 s as one batch, names included.
--taps is check-in taps a minute across all phones, --selfs pilgrim self
check-ins a minute. At the start the morning mail is pressed until none
remain. Every request is timed; every write is logged to LOG in the
format checkin-durability.py verify reads, so run that afterwards.
With --pier, the ship's serf is sampled for CPU and memory.

The ship must take self check-ins today (event days moved), and be in
stub mode so the mail goes nowhere.
"""
import json, os, random, subprocess, sys, threading, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util
spec = importlib.util.spec_from_file_location('dur', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'checkin-durability.py'))
dur = importlib.util.module_from_spec(spec); spec.loader.exec_module(dur)

API = '/apps/register/api'
KEEP = '/grubbery/api/keep/apps/shell/desks/register.desk/desk/data/register.register_app/beacon/rev'
GAP = float(os.environ.get('ROSTER_GAP', '15'))
times = {}
errors = {}
lock = threading.Lock()


def timed(kind, fn):
    t = time.time()
    try:
        st, d = fn()
    except Exception as e:
        st, d = 0, {'error': str(e)}
    dt = time.time() - t
    with lock:
        times.setdefault(kind, []).append(dt)
        if st != 200:
            errors.setdefault(kind, []).append(st)
    return st, d


def stream(ship, wake, until):
    """the beacon, the way the page reads it: every event wakes a refetch"""
    while time.time() < until:
        try:
            r = urllib.request.Request(ship.base + KEEP, headers={'cookie': ship.cookie, 'accept': 'text/event-stream'})
            with urllib.request.urlopen(r, timeout=30) as resp:
                for line in resp:
                    if time.time() >= until:
                        return
                    if line.startswith(b'event:') and b'/rev' in line:
                        wake.set()
        except Exception:
            time.sleep(3)


def phone(ship, log, people, rate, until, k):
    wake = threading.Event()
    threading.Thread(target=stream, args=(ship, wake, until), daemon=True).start()
    queue, last_fetch, last_drain, last_tap = [], 0, time.time(), time.time()
    gap = 60.0 / rate if rate else 1e9
    while time.time() < until:
        now = time.time()
        # the app (version 21): a beacon change rereads at most every 15 s
        if (wake.is_set() and now - last_fetch >= GAP) or now - last_fetch > 60:
            wake.clear()
            timed('roster', lambda: ship.req('GET', API + '/checkin/roster?day=fri'))
            last_fetch = time.time()
        if now - last_tap > gap and people:
            p = people.pop(random.randrange(len(people)))
            queue.append(p)
            last_tap = now
        if now - last_drain > 15 and queue:
            batch, queue = queue[:200], queue[200:]
            body = {'day': 'fri', 'checkins': [{'rid': p['rid'], 'i': p['i'], 'first': p['first'], 'last': p['last']} for p in batch]}
            st, d = timed('tap-batch', lambda: ship.req('POST', API + '/checkin', body))
            bad = {(str(b.get('rid')), int(b.get('i', -1))) for b in (d.get('rejected') or [])} if st == 200 else set()
            for p in batch:
                acked = st == 200 and (p['rid'], p['i']) not in bad
                log.write(kind='vol', rid=p['rid'], i=p['i'], day='fri', undo=False, acked=acked, status=st)
                if not acked:
                    queue.append(p)
            last_drain = time.time()
        time.sleep(0.2)


def pilgrims(ship, log, parties, rate, until):
    gap = 60.0 / rate if rate else 1e9
    while time.time() < until and parties:
        p = parties.pop(random.randrange(len(parties)))
        idx = list(range(p['n']))
        st, d = timed('self', lambda: ship.req('POST', API + '/reg/' + p['rid'] + '/checkin?t=' + p['token'], {'people': idx}, auth=False))
        for i in idx:
            log.write(kind='self', rid=p['rid'], i=i, day='fri', undo=False, acked=st == 200, status=st)
        time.sleep(gap)


def mailer(ship):
    for _ in range(20):
        st, d = timed('mail-press', lambda: ship.req('POST', API + '/admin/checkin-mail', {'day': 'fri', 'again': False}))
        if st != 200 or not d.get('remaining'):
            return
        time.sleep(1.5)


def sampler(pier, until, out):
    while time.time() < until:
        r = subprocess.run(['bash', '-c', f"ps -o pcpu=,rss= -p $(pgrep -f 'work --snap-dir {pier} ' | head -1)"], capture_output=True, text=True)
        try:
            c, m = r.stdout.split()
            out.append((float(c), int(m) // 1024))
        except ValueError:
            pass
        time.sleep(5)


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))]


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    base, jar, path = sys.argv[1:4]
    opt = dict(zip(sys.argv[4::2], sys.argv[5::2]))
    minutes = float(opt.get('--minutes', 10)); phones = int(opt.get('--phones', 8))
    taps = float(opt.get('--taps', 52)); selfs = float(opt.get('--selfs', 22)); pier = opt.get('--pier')
    ship = dur.Ship(base, jar)
    log = dur.Log(path)
    st, d = ship.req('GET', API + '/checkin/roster?day=fri')
    rows = [r for r in d['rows'] if r['status'] == 'complete']
    random.shuffle(rows)
    half = len(rows) * 2 // 3
    people = [{'rid': r['rid'], 'i': int(p['i']), 'first': p['first'], 'last': p['last']}
              for r in rows[:half] for p in r['people'] if not p['checked']]
    st, b = ship.req('GET', API + '/admin/export/bundle.json')
    tok = {r['id']: r.get('token', '') for r in b['regs']}
    selfp = [{'rid': r['rid'], 'n': len(r['people']), 'token': tok.get(r['rid'], '')} for r in rows[half:] if tok.get(r['rid'])]
    print(f'load: {phones} phones over {len(people)} people, {len(selfp)} parties for self check-in, {minutes} min')
    until = time.time() + minutes * 60
    samples = []
    ts = [threading.Thread(target=mailer, args=(ship,))]
    for k in range(phones):
        ts.append(threading.Thread(target=phone, args=(ship, log, people[k::phones], taps / phones, until, k)))
    ts.append(threading.Thread(target=pilgrims, args=(ship, log, selfp, selfs, until)))
    if pier:
        ts.append(threading.Thread(target=sampler, args=(pier, until, samples)))
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    for kind, xs in sorted(times.items()):
        print(f'  {kind:10s} n={len(xs):5d}  p50={pct(xs, .5):6.2f}s  p95={pct(xs, .95):6.2f}s  max={max(xs):6.2f}s  errors={len(errors.get(kind, []))} {sorted(set(errors.get(kind, [])))}')
    if samples:
        print(f'  serf cpu  mean={sum(c for c, _ in samples) / len(samples):5.1f}%  max={max(c for c, _ in samples):5.1f}%   rss max={max(m for _, m in samples)} MB')


if __name__ == '__main__':
    main()
