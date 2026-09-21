#!/usr/bin/env python3
"""The event weekend, end to end, against a test ship.

Four parties are made through the API and completed in stub mode: a
family of three on every day, a solo walker on Friday and Saturday only,
a Bambino pair (Sunday only) and a party that never paid. The event's
dates are then moved so that today is Thursday, Friday, Saturday, Sunday
and Monday in turn, and at each day the pilgrims' links, the morning
mail and the volunteers' roster are checked for what that day should
show: a check-in belongs to its day and to no other, the morning press
reaches only the parties expected that day and not yet in, the roster's
expected and done move with the day, and the link says "over" on Monday.

Run: python3 scripts/weekend-sim.py http://localhost:8080 /tmp/wex.cookies

It moves event.days in settings for the run and puts them back, and
cancels the parties it made. Run it against a test ship only.
"""
import json, subprocess, sys, time
from datetime import datetime, timedelta

HOST = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:8080'
JAR = sys.argv[2] if len(sys.argv) > 2 else '/tmp/wex.cookies'
API = HOST + '/apps/register/api'
INSTANCE = HOST + '/grubbery/ball/apps/shell.shell/desks/register.desk/desk/data/register.register_app'
ACTOR = 'weekend'
fails = []


def check(name, ok, detail=None):
    print(('  ok   ' if ok else '  FAIL ') + name + ('' if ok or detail is None else '   ' + str(detail)[:300]))
    if not ok:
        fails.append(name)


def curl(method, url, body=None, jar=None, actor=None, timeout=90):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    if jar:
        cmd += ['-b', jar]
    if actor:
        cmd += ['-H', 'x-actor: ' + actor]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '--data-binary', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    body_txt, _, code = out.rpartition('\n')
    try:
        return int(code or 0), json.loads(body_txt) if body_txt else None
    except ValueError:
        return int(code or 0), body_txt


def admin(method, path, body=None):
    return curl(method, API + '/admin' + path, body, jar=JAR, actor=ACTOR)


def settle():
    time.sleep(2)


def person(first, last, fri=True, sat=True, sun=True, social_fri=False, social_sat=False):
    return {'first': first, 'last': last, 'child': False, 'days': {'fri': fri, 'sat': sat, 'sun': sun}, 'sun_ten': True,
            'social_fri': social_fri, 'social_sat': social_sat, 'mass_fri': False, 'holy_hour': False, 'bus': False,
            'first_bsc': True, 'knight_dame': False, 'volunteer': False}


def party(track, mail, people):
    return {'track': track, 'contact': {'email': mail, 'phone': '904-555-0100', 'street': '1 Beach Rd',
                                        'city': 'Jacksonville Beach', 'state': 'FL', 'zip': '32250'},
            'org': '', 'why': 'the weekend', 'assistance': False, 'together': False, 'people': people}


def make(track, mail, people, pay=True):
    code, d = curl('POST', API + '/submit', party(track, mail, people))
    if code != 200 or not d.get('rid'):
        raise RuntimeError('submit failed: %s %s' % (code, d))
    rid, tok = d['rid'], d['token']
    curl('POST', API + f'/reg/{rid}/sign?t={tok}', {})
    settle()
    if pay:
        curl('POST', API + f'/reg/{rid}/pay?t={tok}', {})
        settle()
    return rid, tok


def page(rid, tok):
    return curl('GET', API + f'/reg/{rid}/checkin?t={tok}')


def here(rid, tok, idx):
    return curl('POST', API + f'/reg/{rid}/checkin?t={tok}', {'people': idx})


def roster(day):
    return curl('GET', API + f'/checkin/roster?day={day}', jar=JAR)


def row_of(rows, rid):
    return next((r for r in rows if r['rid'] == rid), None)


def mail(day, again=False):
    return admin('POST', '/checkin-mail', {'day': day, 'again': again})


def history(rid):
    code, d = admin('GET', '/reg/' + rid)
    return [h['what'] for h in (d or {}).get('history', [])]


def checked_by(rid, i, day):
    code, d = admin('GET', '/reg/' + rid)
    c = ((d or {}).get('people') or [{}] * (i + 1))[i].get('checkins', {}).get(day)
    return c and c.get('by')


# ---- the ship's clock, shifted to where the event is ----
code, original = admin('GET', '/settings')
if code != 200 or not isinstance(original, dict):
    print('cannot read settings: is the cookie good?', code)
    sys.exit(2)
settings = json.loads(json.dumps(original))
settings['window'] = {'open': '2026-01-01T00:00:00Z', 'close': '2036-01-01T00:00:00Z', 'change_cutoff': '2036-01-01T00:00:00Z'}
settings['providers'] = {'mode': 'stub'}
settings.setdefault('event', {})
offset = int(settings['event'].get('utc_offset_hours', -5) or -5)
code, st = curl('GET', API + '/status')
local = datetime.strptime(st['now'], '%Y-%m-%dT%H:%M:%SZ') + timedelta(hours=offset)


def days_with_today_as(n):
    """the three event dates such that today is day n (0 Friday, 1 Saturday, 2 Sunday), or before or after"""
    first = local - timedelta(days=n)
    return [(first + timedelta(days=i)).strftime('%Y-%m-%d') for i in range(3)]


def set_days(days):
    settings['event']['days'] = days
    code, _ = admin('PUT', '/settings', settings)
    settle()
    return code


made = []
try:
    admin('PUT', '/settings', settings)
    settle()
    stamp = str(int(time.time()))
    family, fam_tok = make('full', f'weekend-family-{stamp}@example.com',
                           [person('Ana', 'Silva'), person('Bo', 'Silva'), person('Cy', 'Silva')])
    solo, solo_tok = make('full', f'weekend-solo-{stamp}@example.com', [person('Dee', 'Solo', sun=False)])
    bambi, bambi_tok = make('bambino', f'weekend-bambino-{stamp}@example.com',
                            [person('Eve', 'Bambino', fri=False, sat=False), person('Fay', 'Bambino', fri=False, sat=False)])
    owing, owing_tok = make('full', f'weekend-owing-{stamp}@example.com', [person('Gus', 'Owing')], pay=False)
    made = [(family, fam_tok), (solo, solo_tok), (bambi, bambi_tok), (owing, owing_tok)]
    for rid, tok in made[:3]:
        code, d = admin('GET', '/reg/' + rid)
        check(f'{rid} is complete before the weekend', code == 200 and d['status'] == 'complete', (code, (d or {}).get('status')))
    code, d = admin('GET', '/reg/' + owing)
    check('the unpaid party waits at payment', d['status'] == 'payment', d['status'])

    # ---- Thursday ----
    print('-- Thursday')
    set_days(days_with_today_as(-1))
    code, d = page(family, fam_tok)
    check('Thursday: the family link names Friday and lets nobody in',
          code == 200 and d['day'] == '' and d['over'] is False and d['opens'] == settings['event']['days'][0], (code, d))
    code, d = here(family, fam_tok, [0])
    check('Thursday: a check-in is 409 early', code == 409 and d.get('code') == 'early', (code, d))
    code, d = mail('fri')
    check('Thursday: the morning button still works, the organizer chose to press it',
          code == 200 and d['sent'] >= 2, (code, d))
    check('Thursday: the Friday links went to the family and the solo, not the Bambino pair, not the unpaid',
          'email.checkin.fri' in history(family) and 'email.checkin.fri' in history(solo)
          and 'email.checkin.fri' not in history(bambi) and 'email.checkin.fri' not in history(owing))

    # ---- Friday ----
    print('-- Friday')
    set_days(days_with_today_as(0))
    code, r0 = roster('fri')
    code, d = mail('fri')
    check('Friday: a second press sends to nobody, the Thursday press counted', code == 200 and d['sent'] == 0, (code, d))
    code, d = page(family, fam_tok)
    check('Friday: the family link says Friday, three unchecked', d['day'] == 'fri' and not any(p['checked'] for p in d['people']), d)
    code, d = here(family, fam_tok, [0, 1])
    check('Friday: two of the family check in', code == 200 and [p['checked'] for p in d['people']] == [True, True, False], (code, d))
    code, d = here(solo, solo_tok, [0])
    check('Friday: the solo checks in', code == 200 and d['people'][0]['checked'], (code, d))
    code, d = page(bambi, bambi_tok)
    check('Friday: the Bambino link works on a day they do not walk, and shows them unchecked',
          code == 200 and d['day'] == 'fri' and not any(p['checked'] for p in d['people']), (code, d))
    code, d = page(owing, owing_tok)
    check('Friday: the unpaid link says payment', d['status'] == 'payment', d)
    code, d = here(owing, owing_tok, [0])
    check('Friday: the unpaid check-in is 409 gone', code == 409 and d.get('code') == 'gone', (code, d))
    # the volunteers' fallback for the third of the family
    code, d = curl('POST', API + '/checkin', {'day': 'fri', 'checkins': [{'rid': family, 'i': 2}]}, jar=JAR, actor=ACTOR)
    check('Friday: a volunteer taps the third', code == 200 and d['applied'] == 1, (code, d))
    settle()
    code, r1 = roster('fri')
    fam = row_of(r1['rows'], family)
    check('Friday: the roster shows the family all in, two by themselves and one by the volunteer',
          fam and [p['checked'] for p in fam['people']] == [True, True, True]
          and [p['by'] for p in fam['people']] == ['pilgrim', 'pilgrim', 'admin:' + ACTOR], fam and fam['people'])
    check('Friday: done rose by four', r1['done'] - r0['done'] == 4, (r0['done'], r1['done']))
    check('Friday: expected counts the family and the solo, not the Bambino pair',
          row_of(r1['rows'], solo)['people'][0]['walks'] is True
          and not any(p['walks'] or p['social'] for p in row_of(r1['rows'], bambi)['people']))
    code, d = mail('fri')
    check('Friday afternoon: everyone expected is in, the press sends nothing', d['sent'] == 0, d)

    # ---- Saturday ----
    print('-- Saturday')
    set_days(days_with_today_as(1))
    code, d = page(family, fam_tok)
    check('Saturday: the family link says Saturday and nobody is checked in yet',
          d['day'] == 'sat' and not any(p['checked'] for p in d['people']), d)
    code, s0 = roster('sat')
    check('Saturday: the roster carries no Friday check-in',
          not any(p['checked'] for p in row_of(s0['rows'], family)['people'])
          and not row_of(s0['rows'], solo)['people'][0]['checked'])
    code, d = mail('sat')
    check('Saturday: the morning press reaches the family and the solo again, Friday did not count',
          code == 200 and d['sent'] >= 2 and 'email.checkin.sat' in history(family) and 'email.checkin.sat' in history(solo)
          and 'email.checkin.sat' not in history(bambi), (code, d))
    code, d = here(family, fam_tok, [0])
    check('Saturday: one of the family checks in', code == 200 and [p['checked'] for p in d['people']] == [True, False, False], (code, d))
    code, d = here(solo, solo_tok, [0])
    check('Saturday: the solo checks in', code == 200 and d['people'][0]['checked'], (code, d))
    settle()
    code, s1 = roster('sat')
    check('Saturday: done rose by two', s1['done'] - s0['done'] == 2, (s0['done'], s1['done']))
    check('Saturday: Friday is untouched', checked_by(family, 2, 'fri') == 'admin:' + ACTOR and checked_by(family, 1, 'sat') is None)
    code, d = mail('sat')
    check('Saturday: a second press sends nothing, the two unchecked family members had their link', d['sent'] == 0, d)
    code, d = mail('sat', again=True)
    check('Saturday: send again skips a party with anyone already in, so the half-in family gets no second link',
          code == 200 and history(family).count('email.checkin.sat') == 1 and history(solo).count('email.checkin.sat') == 1, (code, d))
    code, f1 = roster('fri')
    check('Saturday: Friday\'s roster still shows Friday\'s check-ins', all(p['checked'] for p in row_of(f1['rows'], family)['people']))

    # ---- Sunday ----
    print('-- Sunday')
    set_days(days_with_today_as(2))
    code, d = page(bambi, bambi_tok)
    check('Sunday: the Bambino link says Sunday, both unchecked', d['day'] == 'sun' and len(d['people']) == 2 and not any(p['checked'] for p in d['people']), d)
    code, u0 = roster('sun')
    code, d = mail('sun')
    check('Sunday: the morning press reaches the family and the Bambino pair, not the solo who walks Friday and Saturday only',
          code == 200 and 'email.checkin.sun' in history(family) and 'email.checkin.sun' in history(bambi)
          and 'email.checkin.sun' not in history(solo), (code, d))
    code, d = here(bambi, bambi_tok, [0, 1])
    check('Sunday: the Bambino pair check in', code == 200 and all(p['checked'] for p in d['people']), (code, d))
    code, d = here(family, fam_tok, [0, 1, 2])
    check('Sunday: the whole family checks in', code == 200 and all(p['checked'] for p in d['people']), (code, d))
    code, d = here(solo, solo_tok, [0])
    check('Sunday: the solo can still check in on a day they did not plan', code == 200 and d['people'][0]['checked'], (code, d))
    settle()
    code, u1 = roster('sun')
    check('Sunday: done rose by six', u1['done'] - u0['done'] == 6, (u0['done'], u1['done']))
    check('Sunday: the roster expects the Bambino pair today and not the solo',
          all(p['walks'] for p in row_of(u1['rows'], bambi)['people'])
          and not (row_of(u1['rows'], solo)['people'][0]['walks'] or row_of(u1['rows'], solo)['people'][0]['social']))
    hist = history(family)
    check('Sunday: the family\'s history holds a check-in line for each day',
          any(h.startswith('checked in') and h.endswith(' fri') for h in hist)
          and any(h.startswith('checked in') and h.endswith(' sat') for h in hist)
          and any(h.startswith('checked in') and h.endswith(' sun') for h in hist), hist[-8:])
    code, d = admin('GET', '/regs')
    fam_row = next(r for r in d['regs'] if r['id'] == family)
    check('Sunday: the backoffice row counts the weekend, and who did it themselves',
          fam_row['checked'] == {'fri': 3, 'sat': 1, 'sun': 3} and fam_row['self'] == {'fri': 2, 'sat': 1, 'sun': 3},
          (fam_row['checked'], fam_row.get('self')))

    # ---- Monday ----
    print('-- Monday')
    set_days(days_with_today_as(3))
    code, d = page(family, fam_tok)
    check('Monday: the link says the event is over', code == 200 and d['over'] is True and d['day'] == '', d)
    code, d = here(family, fam_tok, [0])
    check('Monday: a check-in is 409 over', code == 409 and d.get('code') == 'over', (code, d))
    code, d = mail('sun')
    check('Monday: the button still answers, sends to nobody who is in', code == 200 and d['sent'] == 0, (code, d))
    code, d = curl('GET', INSTANCE + '/tr/log?raw=1', jar=JAR)
    check('the ring holds every stub email the weekend sent, one per party per day',
          len([e for e in d if e.get('rid') == family and e.get('op', '').startswith('email.checkin.')]) == 3
          and len([e for e in d if e.get('rid') == bambi and e.get('op', '').startswith('email.checkin.')]) == 1
          and len([e for e in d if e.get('rid') == owing and e.get('op', '').startswith('email.checkin.')]) == 0)
finally:
    admin('PUT', '/settings', original)
    for rid, tok in made:
        curl('POST', API + f'/reg/{rid}/cancel?t={tok}', {})
    settle()
    print(('%d FAILED: ' % len(fails)) + '; '.join(fails) if fails else 'ALL OK')
    sys.exit(1 if fails else 0)
