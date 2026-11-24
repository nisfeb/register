#!/usr/bin/env python3
"""Check-ins across an edit that removes a person: do they stay with the
people who checked in?

usage: checkin-edit-probe.py BASE JAR [--from-public]

Picks a complete party of three with nobody checked in on Friday,
checks in the first and the third, then removes the middle one with
the same edit the backoffice's Save sends (POST /api/admin/reg/<rid>
{op: edit, input}, the people without their check-ins). Afterwards the
first and the (old) third must still be checked in, by name. A second
case removes the first person. Against a TEST ship only.
"""
import json, sys, urllib.request

BASE, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
API = BASE + '/apps/register/api'


def cookie():
    for line in open(JAR):
        f = line.removeprefix('#HttpOnly_').rstrip('\n').split('\t')
        if len(f) == 7 and f[5].startswith('urbauth-'):
            return f'{f[5]}={f[6]}'


H = {'cookie': cookie(), 'content-type': 'application/json', 'x-actor': 'edit-probe'}


def req(method, path, body=None):
    r = urllib.request.Request(API + path, data=json.dumps(body).encode() if body is not None else None,
                               headers=H, method=method)
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            return resp.status, json.loads(resp.read() or b'{}')
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'{}')


def roster(rid):
    st, d = req('GET', '/checkin/roster?day=fri')
    return next(r for r in d['rows'] if r['rid'] == rid)


fails = 0


def check(label, ok, detail=''):
    global fails
    print(('  ok   ' if ok else '  FAIL ') + label + ('' if ok else '   ' + str(detail)))
    fails += 0 if ok else 1


def case(gone):
    st, d = req('GET', '/checkin/roster?day=fri')
    used = getattr(case, 'used', set())
    row = next(r for r in d['rows'] if r['rid'] not in used and r['status'] == 'complete' and
               len(r['people']) == 3 and not any(p['checked'] for p in r['people']))
    rid = row['rid']
    used.add(rid); case.used = used
    names = [p['first'] + ' ' + p['last'] for p in row['people']]
    keep = [i for i in range(3) if i != gone]
    tapped = [0, 2]
    req('POST', '/checkin', {'day': 'fri', 'checkins': [{'rid': rid, 'i': i} for i in tapped]})
    st, reg = req('GET', '/admin/reg/' + rid)
    inp = {k: reg[k] for k in ('track', 'contact', 'org', 'why', 'assistance', 'together') if k in reg}
    inp['people'] = [{k: v for k, v in p.items() if k != 'checkins'} for i, p in enumerate(reg['people']) if i != gone]
    st, out = req('POST', '/admin/reg/' + rid, {'op': 'edit', 'input': inp})
    print(f'case: remove person {gone} ({names[gone]}) from {rid}: edit {st} {"" if st == 200 else out}')
    after = roster(rid)
    have = {p['first'] + ' ' + p['last']: p['checked'] for p in after['people']}
    for i in keep:
        want = i in tapped
        check(f'{names[i]} {"still checked in" if want else "still not checked in"}', have.get(names[i]) == want, have)
    # put it back as it was: the removed person returns at the end
    req('POST', '/checkin', {'day': 'fri', 'checkins': [{'rid': rid, 'i': i, 'undo': True} for i in range(3)]})


def stale():
    """a phone painted the party before the first person was removed, and
    taps by the indices it saw, with the names it showed"""
    st, d = req('GET', '/checkin/roster?day=fri')
    used = getattr(case, 'used', set())
    row = next(r for r in d['rows'] if r['rid'] not in used and r['status'] == 'complete' and
               len(r['people']) == 3 and not any(p['checked'] for p in r['people']))
    rid = row['rid']
    used.add(rid); case.used = used
    seen = [(p['first'], p['last']) for p in row['people']]
    st, reg = req('GET', '/admin/reg/' + rid)
    inp = {k: reg[k] for k in ('track', 'contact', 'org', 'why', 'assistance', 'together') if k in reg}
    inp['people'] = [{k: v for k, v in p.items() if k != 'checkins'} for p in reg['people'][1:]]
    st, _ = req('POST', '/admin/reg/' + rid, {'op': 'edit', 'input': inp})
    print(f'case: a phone that saw {rid} before {seen[0][0]} was removed taps by its old indices')
    tap = lambda i: {'rid': rid, 'i': i, 'first': seen[i][0], 'last': seen[i][1]}
    st, out = req('POST', '/checkin', {'day': 'fri', 'checkins': [tap(2), tap(0)]})
    bad = {(b['rid'], b['i']): b['why'] for b in out.get('rejected', [])}
    check(f'the tap for the removed {seen[0][0]} is refused, not given to someone else',
          bad.get((rid, 0)) == 'no such person', out)
    after = roster(rid)
    have = {(p['first'], p['last']): p['checked'] for p in after['people']}
    check(f'{seen[2][0]}, tapped at the old index 2, is checked in', have.get(seen[2]) is True, have)
    check(f'{seen[1][0]}, now standing at index 0, is not', have.get(seen[1]) is False, have)
    req('POST', '/checkin', {'day': 'fri', 'checkins': [{'rid': rid, 'i': i, 'undo': True} for i in range(2)]})


case(1)
case(0)
stale()
print('FAIL (%d)' % fails if fails else 'ALL OK')
sys.exit(1 if fails else 0)
