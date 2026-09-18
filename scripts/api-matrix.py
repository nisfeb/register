#!/usr/bin/env python3
"""api-matrix.py HOST JAR
The HTTP gate for register: the pilgrim's flow and the organizers'
backoffice in stub mode against a fake ship. HOST like
http://localhost:8080; JAR a curl cookie jar with the owner cookie.
Exits 1 on any failure. Safe to rerun: it cancels what an earlier run
left and restores the settings and the counts it changed."""
import base64, csv, json, os, subprocess, sys, tempfile, time, traceback

HOST, JAR = sys.argv[1:3]
API = HOST + '/apps/register/api'
INSTANCE = HOST + '/grubbery/ball/apps/shell.shell/desks/register.desk/desk/data/register.register_app'
ACTOR = 'matrix'
TMP = tempfile.mkdtemp(prefix='register-matrix-')
fails = []


def curl(method, url, body=None, jar=None, actor=None, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    if jar:
        cmd += ['-b', jar]
    if actor:
        cmd += ['-H', 'x-actor: ' + actor]
    if body is not None:
        # a bundle is far too big for a command line, so every body rides a file
        path = os.path.join(TMP, 'body.json')
        with open(path, 'w', encoding='utf-8') as fh:
            json.dump(body, fh)
        cmd += ['-H', 'content-type: application/json', '--data-binary', '@' + path]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def head(path, jar=None):
    cmd = ['curl', '-s', '-m', '30', '-D', '-', '-o', '/dev/null', HOST + path]
    if jar:
        cmd += ['-b', jar]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout.replace('\r', '')
    lines = out.split('\n')
    code = int(lines[0].split(' ')[1]) if lines[0].startswith('HTTP/') else 0
    headers = {}
    for ln in lines[1:]:
        k, _, v = ln.partition(':')
        if k.strip():
            headers[k.strip().lower()] = v.strip()
    return code, headers


def download(path, name):
    dest = os.path.join(TMP, name)
    subprocess.run(['curl', '-s', '-m', '180', '-b', JAR, '-o', dest, API + '/admin' + path], capture_output=True)
    return dest


def csv_rows(path, name):
    with open(download(path, name), newline='', encoding='utf-8') as fh:
        return list(csv.reader(fh))


def check(label, cond, detail=''):
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


def admin(method, path, body=None):
    return curl(method, API + '/admin' + path, body, jar=JAR, actor=ACTOR)


def settle():
    # the writer applies after the answer leaves; a read right after a write races it
    time.sleep(1.5)


def person(first, last, **kw):
    p = {'first': first, 'last': last, 'child': False, 'days': {'fri': True, 'sat': True, 'sun': True}, 'sun_ten': True,
         'social_fri': False, 'social_sat': False, 'mass_fri': False, 'holy_hour': False, 'bus': False,
         'first_bsc': True, 'knight_dame': False, 'volunteer': False}
    p.update(kw)
    return p


def party(track, email, people, **kw):
    d = {'track': track, 'contact': {'email': email, 'phone': '904-555-0100', 'street': '1 Beach Rd',
                                     'city': 'Jacksonville Beach', 'state': 'FL', 'zip': '32250'},
         'org': 'Matrix', 'why': 'the gate', 'assistance': False, 'together': False, 'people': people}
    d.update(kw)
    return d


def reg(rid, tok):
    return curl('GET', API + f'/reg/{rid}?t={tok}')


def roster(day, jar=JAR):
    return curl('GET', API + f'/checkin/roster?day={day}', jar=jar)


def tap(day, items):
    return curl('POST', API + '/checkin', {'day': day, 'checkins': items}, jar=JAR, actor=ACTOR)


def row_of(rows, rid):
    for r in rows:
        if r['rid'] == rid:
            return r
    return None


def status():
    code, d = curl('GET', API + '/status')
    check('GET /status answers 200', code == 200, (code, d))
    return d


# ---- settings: open the window, remember the original ----
code, original = admin('GET', '/settings')
check('GET /admin/settings answers 200 with the cookie', code == 200 and isinstance(original, dict), (code, original))
code, _ = curl('GET', API + '/settings')
check('GET /api/settings is not a public route (404)', code == 404, code)
code, _ = curl('GET', API + '/admin/regs')
check('GET /admin/regs without the cookie is 403', code == 403, code)
code, _ = curl('PUT', API + '/admin/settings', original, jar=JAR)
check('PUT /admin/settings without x-actor is 400', code == 400, code)
check('secrets come back masked or empty', original.get('mail', {}).get('resend_key', '') in ('', '****'), original.get('mail'))

code, orig_counts = admin('GET', '/counts')
check('GET /admin/counts answers 200 with a document', code == 200 and isinstance(orig_counts, dict), (code, orig_counts))

settings = json.loads(json.dumps(original))
settings['window'] = {'open': '2026-01-01T00:00:00Z', 'close': '2036-01-01T00:00:00Z', 'change_cutoff': '2036-01-01T00:00:00Z'}
settings['caps'] = {'full': 325, 'bambino': 25, 'social_fri': 300, 'social_sat': 200, 'late_adds': 50}
settings['providers'] = {'mode': 'stub'}


def run():
    code, _ = admin('PUT', '/settings', settings)
    check('PUT /admin/settings opens the window', code == 200, code)
    settle()

    # ---- clean what an earlier run left ----
    code, d = admin('GET', '/regs')
    check('GET /admin/regs answers 200', code == 200, (code, d))
    for r in (d or {}).get('regs', []):
        if r['email'].lower().startswith('matrix-') and r['status'] not in ('draft', 'cancelled'):
            if r.get('exempt'):
                admin('POST', '/reg/' + r['id'], {'op': 'exempt', 'on': False})
            admin('POST', '/reg/' + r['id'], {'op': 'cancel', 'note': 'matrix cleanup'})
    settle()
    s0 = status()
    base_full = s0['counts']['full']
    base_sat = s0['counts']['social_sat']
    check('status carries the copy', s0['copy'].get('landing.title', '') != '', s0.get('copy', {}).keys())
    check('status is open in stub mode', s0['open'] and s0['mode'] == 'stub', (s0['open'], s0['mode']))

    # ---- drafts ----
    code, d = curl('POST', API + '/draft', {'track': 'full', 'contact': {'phone': '904'}, 'people': []})
    check('a draft with only a phone answers a rid and a token', code == 200 and len(d.get('rid', '')) == 10 and len(d.get('token', '')) == 32, (code, d))
    draft_rid, draft_tok = d['rid'], d['token']
    code, d = curl('POST', API + '/draft', {'track': 'full', 'contact': {'street': 's'}, 'people': []})
    check('a draft with no email or phone is 400 naming contact', code == 400 and d['error'].startswith('contact:'), (code, d))
    code, d = curl('POST', API + '/draft', {'track': 'full', 'contact': {'email': 'matrix-draft@example.com'}, 'people': [], 'rid': draft_rid, 'token': draft_tok})
    check('a draft updates in place', code == 200 and d['rid'] == draft_rid, (code, d))
    settle()
    code, d = reg(draft_rid, draft_tok)
    check('the draft reads back with its email', code == 200 and d['status'] == 'draft' and d['contact']['email'] == 'matrix-draft@example.com', (code, d))
    code, d = reg(draft_rid, 'wrong')
    check('a wrong token is 404', code == 404, code)

    # ---- the full flow, a party of three, together ----
    p = party('full', 'matrix-ana@example.com',
              [person('Ana', 'Silva', social_fri=True, social_sat=True), person('Bo', 'Silva', child=True), person('Cy', 'Silva')], together=True)
    code, d = curl('POST', API + '/submit', p)
    check('submit answers waiver with the fees', code == 200 and d['status'] == 'waiver' and d['fees'] == 22500, (code, d))
    ana_rid, ana_tok = d['rid'], d['token']
    settle()
    code, d = reg(ana_rid, ana_tok)
    check('the registration is at the waiver step with 3 people', code == 200 and d['status'] == 'waiver' and len(d['people']) == 3, (code, d))
    check('together copied the socials to the child', d['people'][1]['social_sat'] is True and d['people'][1]['child'] is True, d['people'][1])
    check('the pilgrim view has no history and no token', 'history' not in d and 'token' not in d, d.keys())
    code, d = curl('POST', API + f'/reg/{ana_rid}/pay?t={ana_tok}', {})
    check('paying before signing is 409', code == 409, (code, d))
    code, d = curl('POST', API + f'/reg/{ana_rid}/sign?t={ana_tok}', {})
    check('sign (stub) answers next payment', code == 200 and d['next'] == 'payment', (code, d))
    settle()
    code, d = curl('POST', API + f'/reg/{ana_rid}/pay?t={ana_tok}', {})
    check('pay (stub) answers next complete', code == 200 and d['next'] == 'complete', (code, d))
    settle()
    code, d = reg(ana_rid, ana_tok)
    check('complete, paid 22500 by stub, waiver completed', code == 200 and d['status'] == 'complete' and d['payment']['amount'] == 22500 and d['payment']['method'] == 'stub' and d['waiver']['status'] == 'completed', (code, d))
    s1 = status()
    check('the meter counts the three walkers', s1['counts']['full'] == base_full + 3, (s1['counts'], base_full))
    check('the socials count the three', s1['counts']['social_sat'] == base_sat + 3, s1['counts'])

    # ---- duplicate ----
    code, d = curl('POST', API + '/submit', party('full', 'Matrix-Ana@example.com', [person('Ana', 'Again')]))
    check('the same email again is 409 duplicate, case-insensitive', code == 409 and d.get('code') == 'duplicate', (code, d))
    code, d = curl('POST', API + '/resend-link', {'email': 'matrix-ana@example.com'})
    check('resend-link answers 200', code == 200, (code, d))
    code, d = curl('POST', API + '/resend-link', {'email': 'nobody@example.com'})
    check('resend-link answers 200 for a stranger too', code == 200, (code, d))

    # ---- the admin routes: the owner's, and each mutating one names its actor ----
    for meth, path in [('GET', '/admin/regs'), ('GET', '/admin/reg/x'), ('POST', '/admin/reg/x'),
                       ('GET', '/admin/settings'), ('PUT', '/admin/settings'),
                       ('GET', '/admin/copy'), ('PUT', '/admin/copy'),
                       ('GET', '/admin/counts'), ('PUT', '/admin/counts'),
                       ('POST', '/admin/add'), ('POST', '/admin/import'),
                       ('GET', '/admin/export/people.csv'), ('GET', '/admin/export/bundle.jam')]:
        code, _ = curl(meth, API + path, {} if meth in ('POST', 'PUT') else None)
        check(f'{meth} {path} without the cookie is 403', code == 403, code)
    for meth, path in [('POST', '/admin/reg/' + ana_rid), ('PUT', '/admin/settings'), ('PUT', '/admin/copy'),
                       ('PUT', '/admin/counts'), ('POST', '/admin/add'), ('POST', '/admin/import')]:
        code, _ = curl(meth, API + path, {}, jar=JAR)
        check(f'{meth} {path} with the cookie and no actor is 400', code == 400, code)

    # ---- bambino ----
    code, d = curl('POST', API + '/submit', party('bambino', 'matrix-bam@example.com', [person('Di', 'Bambino', days={'fri': False, 'sat': False, 'sun': True}), person('Ed', 'Bambino', days={'fri': False, 'sat': False, 'sun': True})]))
    check('a bambino party of two owes 5000', code == 200 and d['fees'] == 5000 and d['status'] == 'waiver', (code, d))
    bam_rid, bam_tok = d['rid'], d['token']
    settle()
    curl('POST', API + f'/reg/{bam_rid}/sign?t={bam_tok}', {}); settle()
    curl('POST', API + f'/reg/{bam_rid}/pay?t={bam_tok}', {}); settle()
    s2 = status()
    check('the bambino count moved by two and the full count did not', s2['counts']['bambino'] >= 2 and s2['counts']['full'] == base_full + 3, s2['counts'])

    # ---- non-walkers owe nothing and take no spot ----
    s_non_before = status()
    code, d = curl('POST', API + '/submit', party('full', 'matrix-non@example.com', [person('Fay', 'Shrine', days={'fri': False, 'sat': False, 'sun': False})]))
    check('a non-walker pays the track fee and gets a spot without counting', code == 200 and d['fees'] == 7500 and d['status'] == 'waiver', (code, d))
    non_rid, non_tok = d['rid'], d['token']
    settle()
    s_non_after = status()
    check('a non-walker takes no spot on the track',
          s_non_after['counts']['full'] == s_non_before['counts']['full']
          and s_non_after['counts']['social_fri'] == s_non_before['counts']['social_fri']
          and s_non_after['counts']['social_sat'] == s_non_before['counts']['social_sat'],
          (s_non_before['counts'], s_non_after['counts']))

    # ---- financial assistance ----
    code, d = curl('POST', API + '/submit', party('full', 'matrix-help@example.com', [person('Gus', 'Help')], assistance=True))
    check('an assistance request submits to waiver', code == 200 and d['status'] == 'waiver', (code, d))
    help_rid, help_tok = d['rid'], d['token']
    settle()
    code, d = curl('POST', API + f'/reg/{help_rid}/sign?t={help_tok}', {})
    check('after signing it waits for assistance', code == 200 and d['next'] == 'assistance', (code, d))
    settle()
    code, d = curl('POST', API + f'/reg/{help_rid}/pay?t={help_tok}', {})
    check('paying while awaiting assistance is 409', code == 409, (code, d))
    code, d = admin('POST', '/reg/' + help_rid, {'op': 'assist', 'approve': True})
    check('the organizer approves', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + help_rid)
    check('approved: complete, paid by assistance, history names admin:matrix', code == 200 and d['status'] == 'complete' and d['payment']['method'] == 'assistance' and any(h['by'] == 'admin:matrix' for h in d['history']), (code, d))
    code, d = admin('POST', '/reg/' + help_rid, {'op': 'assist', 'approve': True})
    check('approving twice is 409', code == 409, code)

    # ---- financial assistance, declined ----
    code, d = curl('POST', API + '/submit', party('full', 'matrix-help2@example.com', [person('Ria', 'Help')], assistance=True))
    check('a second assistance request submits to waiver', code == 200 and d['status'] == 'waiver', (code, d))
    h2_rid, h2_tok = d['rid'], d['token']
    settle()
    code, d = curl('POST', API + f'/reg/{h2_rid}/sign?t={h2_tok}', {})
    check('after signing it waits for assistance too', code == 200 and d['next'] == 'assistance', (code, d))
    settle()
    code, d = admin('POST', '/reg/' + h2_rid, {'op': 'assist', 'approve': False})
    check('the organizer declines', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + h2_rid)
    check('declined: at the payment step, the last history line says declined',
          code == 200 and d['status'] == 'payment' and 'declined' in d['history'][-1]['what'], (code, d))
    code, d = curl('POST', API + f'/reg/{h2_rid}/pay?t={h2_tok}', {})
    check('a declined party pays and completes', code == 200 and d['next'] == 'complete', (code, d))
    settle()

    # ---- the cap and the wait list ----
    s3 = status()
    settings['caps']['full'] = s3['counts']['full'] + 1
    admin('PUT', '/settings', settings); settle()
    code, d = curl('POST', API + '/submit', party('full', 'matrix-wait1@example.com', [person('Hal', 'Wait'), person('Ivy', 'Wait')]))
    check('a party of two over the cap is wait listed at position 1', code == 200 and d['status'] == 'waitlist' and d['position'] == 1, (code, d))
    w1_rid, w1_tok = d['rid'], d['token']
    settle()
    code, d = curl('GET', INSTANCE + '/tr/log?raw=1', jar=JAR)
    check('the wait list email stub is in the ring for that rid',
          code == 200 and isinstance(d, list) and any(e.get('op') == 'email.waitlist' and e.get('rid') == w1_rid for e in d),
          (code, str(d)[-300:]))
    code, d = curl('POST', API + '/submit', party('full', 'matrix-wait2@example.com', [person('Jo', 'Wait'), person('Kim', 'Wait')]))
    check('the next party is position 2', code == 200 and d['status'] == 'waitlist' and d['position'] == 2, (code, d))
    w2_rid, w2_tok = d['rid'], d['token']
    settle()
    code, d = curl('POST', API + '/submit', party('full', 'matrix-one@example.com', [person('Lee', 'One')]))
    check('a party of one still fits the last spot', code == 200 and d['status'] == 'waiver', (code, d))
    one_rid, one_tok = d['rid'], d['token']
    settle()
    code, d = curl('POST', API + f'/reg/{w1_rid}/sign?t={w1_tok}', {})
    check('a wait listed party cannot sign', code == 409, code)
    s4 = status()
    check('the meter shows the cap reached and two on the wait list', s4['counts']['full'] == s4['caps']['full'] and s4['counts']['waitlist'] >= 2, (s4['counts'], s4['caps']))
    code, d = admin('POST', '/reg/' + w1_rid, {'op': 'promote'})
    check('the organizer promotes the first', code == 200, (code, d))
    settle()
    code, d = reg(w1_rid, w1_tok)
    check('promoted: at the waiver step, position 0', code == 200 and d['status'] == 'waiver' and d['position'] == 0, (code, d))
    code, d = admin('POST', '/reg/' + w1_rid, {'op': 'promote'})
    check('promoting twice is 409', code == 409, code)
    code, d = reg(w2_rid, w2_tok)
    check('with the first promoted the second is position 1', code == 200 and d['status'] == 'waitlist' and d['position'] == 1, (code, d))

    # ---- a hold that lapsed cannot complete over the cap ----
    settings['hold_hours'] = 0
    settings['caps']['full'] = 325
    admin('PUT', '/settings', settings); settle()
    code, d = curl('POST', API + '/submit', party('full', 'matrix-lapse@example.com', [person('Pat', 'Lapse')]))
    check('the party whose hold lapses at once submits to waiver', code == 200 and d['status'] == 'waiver', (code, d))
    lap_rid, lap_tok = d['rid'], d['token']
    settle()
    s_lap = status()
    settings['caps']['full'] = s_lap['counts']['full']
    admin('PUT', '/settings', settings); settle()
    code, d = curl('POST', API + f'/reg/{lap_rid}/sign?t={lap_tok}', {})
    check('signing a lapsed hold on a filled track is 409 waitlist', code == 409 and d.get('code') == 'waitlist', (code, d))
    settle()
    code, d = reg(lap_rid, lap_tok)
    check('the lapsed party is wait listed with a position', code == 200 and d['status'] == 'waitlist' and d['position'] >= 1, (code, d))
    settings['hold_hours'] = 48
    settings['caps']['full'] = 325
    admin('PUT', '/settings', settings); settle()

    # ---- a sold-out social ----
    s5 = status()
    settings['caps']['social_sat'] = s5['counts']['social_sat']
    settings['caps']['full'] = 325
    admin('PUT', '/settings', settings); settle()
    code, d = curl('POST', API + '/submit', party('full', 'matrix-sat@example.com', [person('Mo', 'Social', social_sat=True)]))
    check('a sold-out social is refused naming social_sat', code == 400 and d['error'].startswith('social_sat'), (code, d))
    code, d = curl('POST', API + '/submit', party('full', 'matrix-sat@example.com', [person('Mo', 'Social', social_fri=True)]))
    check('the other social still takes', code == 200, (code, d))
    sat_rid, sat_tok = d['rid'], d['token']
    settings['caps']['social_sat'] = 200
    admin('PUT', '/settings', settings); settle()

    # ---- edit and cancel through the manage link ----
    edited = party('full', 'matrix-one@example.com', [person('Lee', 'Won', social_fri=True), person('Max', 'Won')])
    code, d = curl('POST', API + f'/reg/{one_rid}/edit?t={one_tok}', edited)
    check('an edit that adds a person answers the new fees', code == 200 and d['fees'] == 15000 and d['fees_before'] == 7500, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + one_rid)
    check('the edit landed with a history line by pilgrim', code == 200 and d['people'][0]['last'] == 'Won' and len(d['people']) == 2 and d['history'][-1]['by'] == 'pilgrim', (code, d))
    code, d = curl('POST', API + f'/reg/{one_rid}/edit?t={one_tok}', party('full', 'matrix-ana@example.com', [person('Lee', 'Won')]))
    check('an edit onto another registration email is 409 duplicate', code == 409 and d.get('code') == 'duplicate', (code, d))
    settings['window']['change_cutoff'] = '2020-01-01T00:00:00Z'
    admin('PUT', '/settings', settings); settle()
    code, d = curl('POST', API + f'/reg/{one_rid}/edit?t={one_tok}', edited)
    check('after the cutoff a pilgrim edit is 403', code == 403, (code, d))
    code, d = curl('POST', API + f'/reg/{one_rid}/cancel?t={one_tok}', {})
    check('after the cutoff a pilgrim cancel is 403', code == 403, (code, d))
    code, d = admin('POST', '/reg/' + one_rid, {'op': 'edit', 'input': edited})
    check('an organizer edits past the cutoff', code == 200, (code, d))
    settings['window']['change_cutoff'] = '2036-01-01T00:00:00Z'
    admin('PUT', '/settings', settings); settle()
    s6 = status()
    code, d = curl('POST', API + f'/reg/{one_rid}/cancel?t={one_tok}', {})
    check('the pilgrim cancels', code == 200, (code, d))
    settle()
    code, d = reg(one_rid, one_tok)
    check('cancelled, position 0', code == 200 and d['status'] == 'cancelled', (code, d))
    s7 = status()
    check('cancelling freed two spots', s7['counts']['full'] == s6['counts']['full'] - 2, (s6['counts'], s7['counts']))
    code, d = curl('POST', API + f'/reg/{one_rid}/cancel?t={one_tok}', {})
    check('cancelling twice is 409', code == 409, code)

    checkin(ana_rid, w2_rid)
    backoffice(ana_rid)

    # ---- the window ----
    settings['window']['close'] = '2020-01-01T00:00:00Z'
    admin('PUT', '/settings', settings); settle()
    code, d = curl('POST', API + '/submit', party('full', 'matrix-late@example.com', [person('Ned', 'Late')]))
    check('a submit after close is 403', code == 403, (code, d))
    code, d = curl('POST', API + '/draft', {'track': 'full', 'contact': {'email': 'matrix-late@example.com'}, 'people': []})
    check('a draft after close is 403', code == 403, (code, d))
    s8 = status()
    check('status says closed', s8['open'] is False, s8['open'])


def checkin(done_rid, waiting_rid):
    # ---- the volunteers' check-in app ----
    code, _ = curl('GET', API + '/checkin/roster?day=fri')
    check('GET /checkin/roster without the cookie is 403', code == 403, code)
    code, _ = curl('POST', API + '/checkin', {'day': 'fri', 'checkins': []}, jar=JAR)
    check('POST /checkin with the cookie and no actor is 400', code == 400, code)
    code, d = roster('nonsense')
    check('a day the event does not have is 400', code == 400, (code, d))
    code, d = roster('fri')
    check('GET /checkin/roster answers the day, the clock, the rows and the planned counts',
          code == 200 and d.get('day') == 'fri' and d.get('now')
          and isinstance(d.get('rows'), list) and isinstance(d.get('planned'), dict), (code, d))
    rows = d['rows']
    names = [(r['people'][0]['last'] or '').lower() for r in rows if r['people']]
    check('the roster is sorted by the first person\'s last name', names == sorted(names), names[:12])
    check('no draft is in the roster', all(r['status'] != 'draft' for r in rows), [r['status'] for r in rows])
    mine = row_of(rows, done_rid)
    check('a complete party wears the green band', mine and mine['wristband']['ok'] is True, mine)
    late = row_of(rows, waiting_rid)
    check('a wait listed party wears the red band with its reason',
          late and late['wristband']['ok'] is False
          and late['wristband']['why'] == 'on the wait list', late)
    check('each person carries an index, a name and the day\'s tags',
          mine and mine['people'][0]['i'] == 0 and mine['people'][0]['last']
          and mine['people'][0]['walks'] is True
          and mine['people'][0]['checked'] is False, mine)
    # the volunteer searches by email, so the row carries it. Nothing
    # else from the contact goes to the phone.
    check('the roster row carries the email the search needs',
          mine and mine.get('email', '').lower().startswith('matrix-'), mine and mine.get('email'))
    check('and no phone, street, city, state or zip',
          mine and not [k for k in ('phone', 'street', 'city', 'state', 'zip') if k in mine],
          mine and sorted(mine.keys()))

    # the planned walk figure is the counted walkers that day
    code, all_regs = admin('GET', '/regs')
    live = [r for r in all_regs['regs'] if r['status'] in ('complete', 'waiver', 'payment', 'assistance')]
    want = sum(int(r['plan']['fri']) for r in live)
    check('planned.walk is the walkers those parties planned for that day',
          d['planned']['walk'] == want, (d['planned'], want))

    # ---- two taps, then the same two again ----
    code, before = admin('GET', '/reg/' + done_rid)
    lines = len(before['history'])
    code, d = tap('fri', [{'rid': done_rid, 'i': 0}, {'rid': done_rid, 'i': 1}])
    check('two taps in one batch answer applied 2 with nothing rejected',
          code == 200 and d.get('applied') == 2 and d.get('rejected') == [], (code, d))
    settle()
    code, d = roster('fri')
    mine = row_of(d['rows'], done_rid)
    check('the roster shows both checked in, with the time and the volunteer',
          mine and mine['people'][0]['checked'] is True and mine['people'][1]['checked'] is True
          and mine['people'][0]['at'] and mine['people'][0]['by'] == 'admin:' + ACTOR, mine)
    check('the day\'s planned block counts them checked', d['planned']['checked'] >= 2, d['planned'])
    code, after = admin('GET', '/reg/' + done_rid)
    check('each check-in wrote one history line',
          len(after['history']) == lines + 2
          and after['history'][-1]['what'].startswith('checked in'), after['history'][-2:])
    code, d = tap('fri', [{'rid': done_rid, 'i': 0}, {'rid': done_rid, 'i': 1}])
    check('the same two taps again answer applied 2', code == 200 and d.get('applied') == 2, (code, d))
    settle()
    code, again = admin('GET', '/reg/' + done_rid)
    check('a check-in that is already there writes no second history line',
          len(again['history']) == lines + 2, len(again['history']))
    check('and keeps the first time it was taken',
          again['people'][0]['checkins']['fri']['at'] == after['people'][0]['checkins']['fri']['at'],
          (again['people'][0]['checkins'], after['people'][0]['checkins']))

    # ---- the undo ----
    code, d = tap('fri', [{'rid': done_rid, 'i': 1, 'undo': True}])
    check('an undo answers applied 1', code == 200 and d.get('applied') == 1, (code, d))
    settle()
    code, d = roster('fri')
    mine = row_of(d['rows'], done_rid)
    check('the undone person is no longer checked in, the other still is',
          mine and mine['people'][0]['checked'] is True and mine['people'][1]['checked'] is False, mine)
    code, undone = admin('GET', '/reg/' + done_rid)
    check('the undo wrote its own history line',
          undone['history'][-1]['what'].startswith('undid check-in'), undone['history'][-1])
    code, d = tap('fri', [{'rid': done_rid, 'i': 1, 'undo': True}])
    check('undoing again answers applied 1 and writes nothing', code == 200 and d.get('applied') == 1, (code, d))
    settle()
    code, twice = admin('GET', '/reg/' + done_rid)
    check('no second undo line', len(twice['history']) == len(undone['history']), len(twice['history']))

    # ---- what the ship refuses, by name ----
    code, d = tap('fri', [{'rid': done_rid, 'i': 9}])
    check('a person the party does not have is rejected by name',
          code == 200 and d.get('applied') == 0 and d['rejected']
          and d['rejected'][0]['i'] == 9 and d['rejected'][0]['why'] == 'no such person', (code, d))
    # an item with no index is not person 0: reading it that way would
    # check in the wrong pilgrim
    code, d = tap('fri', [{'rid': done_rid}])
    check('an item with no index is rejected by name',
          code == 200 and d.get('applied') == 0 and d['rejected']
          and d['rejected'][0]['why'] == 'bad index', (code, d))
    code, d = tap('fri', [{'rid': done_rid, 'i': 'first'}])
    check('an index that is not a number is rejected the same way',
          code == 200 and d.get('applied') == 0 and d['rejected']
          and d['rejected'][0]['why'] == 'bad index', (code, d))
    code, d = tap('fri', [{'rid': '0123456789', 'i': 0}, {'rid': done_rid, 'i': 0}])
    check('a rid that is gone is rejected and the good one still applies',
          code == 200 and d.get('applied') == 1 and len(d['rejected']) == 1
          and d['rejected'][0]['why'] == 'no such registration', (code, d))
    code, d = tap('mon', [{'rid': done_rid, 'i': 0}])
    check('a day the event does not have is 400 on the post', code == 400, (code, d))
    code, d = tap('fri', [{'rid': done_rid, 'i': 0}] * 201)
    check('a batch over 200 is refused', code == 400 and 'checkins' in str(d.get('error', '')), (code, d))
    settle()

    # ---- a red band is checked in all the same ----
    code, d = tap('fri', [{'rid': waiting_rid, 'i': 0}])
    check('a wait listed pilgrim is checked in anyway: the volunteer decided',
          code == 200 and d.get('applied') == 1, (code, d))
    settle()
    code, d = roster('fri')
    late = row_of(d['rows'], waiting_rid)
    check('the record keeps the red reason beside the check-in',
          late and late['people'][0]['checked'] is True
          and late['wristband']['why'] == 'on the wait list', late)
    code, d = admin('GET', '/regs')
    row = row_of([{'rid': r['id'], **r} for r in d['regs']], done_rid)
    check('the backoffice roster row carries the per-day check-in counts',
          row and row['checked']['fri'] == 1 and row['checked']['sat'] == 0, row and row.get('checked'))

    # ---- the check-ins the gate made are taken back ----
    tap('fri', [{'rid': done_rid, 'i': 0, 'undo': True}, {'rid': waiting_rid, 'i': 0, 'undo': True}])
    settle()


def backoffice(live_rid):
    # ---- the backoffice page and its assets ----
    code, h = head('/apps/register/admin')
    check('GET /admin without the cookie is a 302 to the login page',
          code == 302 and '/~/login' in h.get('location', ''), (code, h.get('location')))
    code, h = head('/apps/register/admin', jar=JAR)
    check('GET /admin with the cookie is 200 html',
          code == 200 and h.get('content-type', '').startswith('text/html'), (code, h))
    code, h = head('/apps/register/admin.css', jar=JAR)
    check('admin.css is text/css with nosniff',
          code == 200 and h.get('content-type', '').startswith('text/css')
          and h.get('x-content-type-options') == 'nosniff', (code, h))
    code, h = head('/apps/register/admin.js', jar=JAR)
    check('admin.js is text/javascript',
          code == 200 and h.get('content-type', '').startswith('text/javascript'), (code, h))
    code, h = head('/apps/register/admin.js')
    check('admin.js without the cookie is 403', code == 403, code)

    # ---- a manual add, paid by check with the waiver on paper ----
    s0 = status()
    code, d = admin('POST', '/add', {
        'input': party('full', 'matrix-add@example.com', [person('Wal', 'Kin'), person('Kim', 'Kin')]),
        'waiver_paper': True,
        'paid': {'method': 'check', 'amount': 15000, 'ref': '1041', 'note': 'at the table'}})
    check('a manual add with a paper waiver and a check answers complete',
          code == 200 and d.get('status') == 'complete' and len(d.get('rid', '')) == 10
          and len(d.get('token', '')) == 32, (code, d))
    add_rid = d['rid']
    settle()
    code, d = admin('GET', '/reg/' + add_rid)
    check('the manual add is complete, source admin, paper waiver, paid by check',
          code == 200 and d['status'] == 'complete' and d['source'] == 'admin'
          and d['payment']['method'] == 'check' and d['payment']['amount'] == 15000
          and d['payment']['ref'] == '1041' and d['waiver']['method'] == 'paper'
          and d['waiver']['status'] == 'completed', (code, d))
    hist = [h['what'] for h in d['history']]
    check('the history carries the three steps, all by the organizer',
          any('added by organizer' in w for w in hist) and any('paper' in w for w in hist)
          and any('payment recorded' in w for w in hist)
          and all(h['by'] == 'admin:' + ACTOR for h in d['history']), (hist, d['history']))
    s1 = status()
    check('the late-add pool took its two walkers and the full track did not',
          s1['counts']['late'] == s0['counts']['late'] + 2
          and s1['counts']['full'] == s0['counts']['full'], (s0['counts'], s1['counts']))
    code, d = admin('POST', '/add', {'input': party('full', 'matrix-add@example.com', [person('Dup', 'Kin')])})
    check('a manual add under an email that is taken is 409 duplicate',
          code == 409 and d.get('code') == 'duplicate', (code, d))
    code, d = admin('POST', '/add', {'input': party('full', 'matrix-empty@example.com', [])})
    check('a manual add with no people is 400 naming people',
          code == 400 and 'people' in str((d or {}).get('error', '')), (code, d))
    code, d = admin('POST', '/add', {
        'input': party('full', 'matrix-nopaper@example.com', [person('No', 'Paper')]),
        'paid': {'method': 'cash', 'amount': 15000, 'ref': 'no paper'}})
    check('a manual add with a payment and no paper waiver is 400, not a dropped payment',
          code == 400 and 'waiver on paper' in str((d or {}).get('error', '')), (code, d))
    settle()
    code, d = admin('GET', '/regs')
    left = [r['id'] for r in (d or {}).get('regs', []) if r['email'] == 'matrix-nopaper@example.com']
    check('the refused add wrote nothing at all', code == 200 and not left, left)

    # ---- exempt from the caps ----
    code, d = curl('POST', API + '/submit', party('full', 'matrix-exempt@example.com',
                                                  [person('Eve', 'Exempt', social_sat=True),
                                                   person('Abe', 'Exempt', social_sat=True)]))
    check('the party to exempt submits', code == 200 and d['status'] == 'waiver', (code, d))
    ex_rid, ex_tok = d['rid'], d['token']
    settle()
    curl('POST', API + f'/reg/{ex_rid}/sign?t={ex_tok}', {}); settle()
    curl('POST', API + f'/reg/{ex_rid}/pay?t={ex_tok}', {}); settle()
    s2 = status()
    code, d = admin('POST', '/reg/' + ex_rid, {'op': 'exempt', 'on': True})
    check('the organizer marks the party exempt', code == 200, (code, d))
    settle()
    s3 = status()
    check('exempt frees the two track spots and leaves the socials alone',
          s3['counts']['full'] == s2['counts']['full'] - 2
          and s3['counts']['social_sat'] == s2['counts']['social_sat'], (s2['counts'], s3['counts']))
    code, d = admin('GET', '/reg/' + ex_rid)
    check('the registration reads exempt with its history line',
          code == 200 and d['exempt'] is True and d['history'][-1]['what'] == 'marked exempt', (code, d))
    code, d = admin('POST', '/reg/' + ex_rid, {'op': 'exempt', 'on': False})
    check('exempt clears again', code == 200, (code, d))
    settle()
    s4 = status()
    check('clearing exempt takes the spots back', s4['counts']['full'] == s2['counts']['full'], (s2['counts'], s4['counts']))

    # ---- cancel and reinstate ----
    code, d = admin('POST', '/reg/' + ex_rid, {'op': 'cancel', 'note': 'testing reinstate'})
    check('the organizer cancels a complete party', code == 200, (code, d))
    settle()
    s5 = status()
    check('the cancel freed the two spots', s5['counts']['full'] == s4['counts']['full'] - 2, (s4['counts'], s5['counts']))
    code, d = admin('POST', '/reg/' + ex_rid, {'op': 'reinstate'})
    check('the organizer reinstates it', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + ex_rid)
    check('reinstated to complete with its history line',
          code == 200 and d['status'] == 'complete' and d['history'][-1]['what'] == 'reinstated', (code, d))
    s6 = status()
    check('the spots came back', s6['counts']['full'] == s4['counts']['full'], (s4['counts'], s6['counts']))
    code, d = admin('POST', '/reg/' + ex_rid, {'op': 'reinstate'})
    check('reinstating a live registration is 409', code == 409, code)

    # ---- a payment recorded by hand on an assistance party, then refunded ----
    code, d = curl('POST', API + '/submit', party('full', 'matrix-check@example.com',
                                                  [person('Cal', 'Check')], assistance=True))
    check('an assistance party submits', code == 200 and d['status'] == 'waiver', (code, d))
    ck_rid, ck_tok = d['rid'], d['token']
    settle()
    code, d = curl('POST', API + f'/reg/{ck_rid}/sign?t={ck_tok}', {})
    check('it signs and waits for the decision', code == 200 and d['next'] == 'assistance', (code, d))
    settle()
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'pay', 'method': 'venmo', 'amount': 7500})
    check('a payment method the ship does not take is 400', code == 400, (code, d))
    code, d = admin('POST', '/reg/' + ck_rid,
                    {'op': 'pay', 'method': 'check', 'amount': 7500, 'gift': 2500, 'ref': '204', 'note': 'in the mail'})
    check('the organizer records a check on an assistance party', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + ck_rid)
    check('recorded: complete, by check, with the gift and the reference',
          code == 200 and d['status'] == 'complete' and d['payment']['method'] == 'check'
          and d['payment']['amount'] == 7500 and d['payment']['gift'] == 2500
          and d['payment']['ref'] == '204', (code, d))
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'pay', 'method': 'check', 'amount': 7500})
    check('recording a payment on a complete party is 409', code == 409, code)
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'refund', 'note': 'returned by mail'})
    check('the organizer marks it refunded', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + ck_rid)
    check('refunded is true, the note is appended and the history says refunded',
          code == 200 and d['payment']['refunded'] is True and 'returned by mail' in d['payment']['note']
          and any(h['what'] == 'refunded' for h in d['history']), (code, d))
    code, d = admin('POST', '/reg/' + add_rid, {'op': 'refund', 'note': 'x'})
    check('a refund is allowed where a payment exists', code == 200, (code, d))
    settle()

    # ---- notes, the paper waiver record, the stub emails ----
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'note', 'notes': 'called about the check'})
    check('the organizer replaces the notes', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + ck_rid)
    check('the notes read back with a history line',
          code == 200 and d['notes'] == 'called about the check'
          and d['history'][-1]['what'] == 'notes changed', (code, d))
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'waiver-paper'})
    check('a paper waiver on a complete party is taken', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + ck_rid)
    check('it records the waiver and does not move the status',
          code == 200 and d['waiver']['method'] == 'paper' and d['status'] == 'complete', (code, d))
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'recheck-waiver'})
    check('recheck-waiver is 501 until phase 2', code == 501, (code, d))
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'resend', 'template': 'reminder'})
    check('resend answers the filled subject',
          code == 200 and d.get('template') == 'reminder' and d.get('subject'), (code, d))
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'resend', 'template': 'nonsense'})
    check('a template the ship does not know is 400', code == 400, code)
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'nonsense'})
    check('an op the ship does not know is 400', code == 400, code)
    settle()
    code, d = curl('GET', INSTANCE + '/tr/log?raw=1', jar=JAR)
    check('the reminder stub is in the ring for that rid',
          code == 200 and isinstance(d, list)
          and any(e.get('op') == 'email.reminder' and e.get('rid') == ck_rid for e in d),
          (code, str(d)[-300:]))

    # ---- the counts document ----
    code, d = admin('PUT', '/counts', {'fri': {'mass': {'count': 120, 'time': '08:00', 'note': 'full church'}}})
    check('PUT /admin/counts takes the document', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/counts')
    check('GET /admin/counts reads it back',
          code == 200 and d.get('fri', {}).get('mass', {}).get('count') == 120, (code, d))

    # ---- copy, one key at a time, the way the public page edits it ----
    code, copy_before = admin('GET', '/copy')
    check('GET /admin/copy answers the document', code == 200 and 'landing.title' in (copy_before or {}), code)
    was = copy_before['landing.title']
    code, d = admin('POST', '/copy/set', {'key': 'nothing.here', 'value': 'x'})
    check('setting a key the copy document does not hold is 400 naming the key',
          code == 400 and (d or {}).get('error') == 'key: not in copy', (code, d))
    code, d = curl('POST', API + '/admin/copy/set', {'key': 'landing.title', 'value': 'x'}, jar=JAR)
    check('setting a copy key without x-actor is 400', code == 400, (code, d))
    code, d = curl('POST', API + '/admin/copy/set', {'key': 'landing.title', 'value': 'x'}, actor=ACTOR)
    check('setting a copy key without the cookie is 403', code == 403, (code, d))
    code, d = admin('POST', '/copy/set', {'key': 'landing.title', 'value': 'x' * 4001})
    check('a copy value over four thousand bytes is 400', code == 400, (code, d))
    code, d = admin('POST', '/copy/set', {'key': 'landing.title', 'value': 'Matrix title'})
    check('the owner sets one copy key', code == 200 and (d or {}).get('value') == 'Matrix title', (code, d))
    settle()
    s_copy = status()
    check('the public status carries the new string', s_copy['copy']['landing.title'] == 'Matrix title', s_copy['copy'].get('landing.title'))
    code, d = admin('GET', '/copy')
    check('the rest of the copy document is untouched',
          code == 200 and len(d) == len(copy_before) and d['landing.intro'] == copy_before['landing.intro'],
          (len(d or {}), len(copy_before)))
    code, d = admin('POST', '/copy/set', {'key': 'landing.title', 'value': was})
    check('and the original string goes back', code == 200, (code, d))
    settle()
    code, d = curl('GET', INSTANCE + '/tr/last?raw=1', jar=JAR)
    check('the ring names the key that changed',
          code == 200 and (d or {}).get('op') == 'set-copy-key' and (d or {}).get('why') == 'landing.title', (code, d))

    # ---- the status says who is asking ----
    code, d = curl('GET', API + '/status', jar=JAR)
    check('status says owner with the cookie', code == 200 and (d or {}).get('owner') is True, (code, (d or {}).get('owner')))
    code, d = curl('GET', API + '/status')
    check('status says owner is false without one', code == 200 and (d or {}).get('owner') is False, (code, (d or {}).get('owner')))

    # ---- the exports ----
    code, roster = admin('GET', '/regs')
    check('the roster answers rows with the caps and the clock',
          code == 200 and 'caps' in roster and 'now' in roster and roster['regs']
          and 'names' in roster['regs'][0] and 'plan' in roster['regs'][0]
          and 'token' not in roster['regs'][0], (code, sorted((roster or {}).keys())))
    people = csv_rows('/export/people.csv', 'people.csv')
    regs = csv_rows('/export/regs.csv', 'regs.csv')
    want_people = sum(r['people'] for r in roster['regs'])
    check('people.csv parses and every row has the header count',
          len(people) > 1 and all(len(r) == len(people[0]) for r in people), (len(people), len(people[0])))
    check('people.csv has one row per person', len(people) - 1 == want_people, (len(people) - 1, want_people))
    check('regs.csv parses with one row per registration and the header count',
          len(regs) - 1 == len(roster['regs']) and all(len(r) == len(regs[0]) for r in regs),
          (len(regs) - 1, len(roster['regs'])))
    check('the csv headers name the fields the organizers asked for',
          people[0][:6] == ['rid', 'status', 'track', 'source', 'created', 'updated']
          and 'checkin_sun' in people[0] and 'exempt' in people[0]
          and 'history' in regs[0] and 'walkers' in regs[0], (people[0][:6], regs[0][-4:]))
    with open(download('/export/bundle.json', 'bundle.json'), encoding='utf-8') as fh:
        bundle = json.load(fh)
    check('bundle.json decodes with one entry per registration',
          len(bundle.get('regs', [])) == len(roster['regs']), (len(bundle.get('regs', [])), len(roster['regs'])))
    check('no secret leaves in the bundle',
          bundle['settings'].get('mail', {}).get('resend_key', '') in ('', '****')
          and bundle['settings'].get('stripe', {}).get('secret_key', '') in ('', '****'),
          bundle['settings'].get('mail'))
    check('the bundle carries the counts document it was taken with',
          bundle.get('counts', {}).get('fri', {}).get('mass', {}).get('count') == 120, bundle.get('counts'))
    with open(download('/export/bundle.jam', 'bundle.jam'), 'rb') as fh:
        jam = fh.read()
    check('bundle.jam is a non-empty run of bytes', len(jam) > 100, len(jam))
    code, _ = curl('GET', API + '/admin/export/nothing.csv', jar=JAR, actor=ACTOR)
    check('an export the ship does not have is 404', code == 404, code)

    # ---- import: the dry run, then the apply ----
    b64 = base64.b64encode(jam).decode()
    code, d = admin('POST', '/import?dry=1', {'jam': b64})
    check('the dry run counts what the jam holds and what it would overwrite',
          code == 200 and d.get('regs') == len(roster['regs'])
          and d.get('overwrite') == len(roster['regs']) and d.get('event_days')
          and d.get('earliest') and d.get('latest'), (code, d))
    code, d = admin('POST', '/import?dry=1', {'bundle': bundle})
    check('the same dry run over the JSON bundle agrees',
          code == 200 and d.get('regs') == len(roster['regs']) and d.get('overwrite') == len(roster['regs']), (code, d))
    code, d = admin('POST', '/import?dry=1', {'jam': 'not base64 at all !!!'})
    check('a jam that will not decode is 400 naming the jam',
          code == 400 and 'jam' in str(d.get('error', '')), (code, d))
    code, d = admin('POST', '/import?dry=1', {})
    check('an import with neither a jam nor a bundle is 400', code == 400, (code, d))
    code, d = admin('POST', '/import?dry=1', {'bundle': {'regs': [{'id': 'nope'}]}})
    check('a bundle with a registration that will not read is 400 naming it',
          code == 400 and 'nope' in str(d.get('error', '')), (code, d))
    out = subprocess.run(['curl', '-s', '-m', '30', '-b', JAR, '-H', 'x-actor: ' + ACTOR,
                          '-H', 'content-type: text/plain', '-X', 'POST', '-d', '{}',
                          '-w', '\n%{http_code}', API + '/admin/import?dry=1'],
                         capture_output=True, text=True).stdout
    check('an import body that does not say it is JSON is 415', out.strip().endswith('415'), out[-60:])
    code, d = admin('POST', '/import?dry=1', {'bundle': {'regs': [], 'settings': None}})
    check('a bundle whose settings is a JSON null is 400 naming settings',
          code == 400 and 'settings' in str((d or {}).get('error', '')), (code, d))
    code, d = admin('POST', '/import?dry=1', {'bundle': {'regs': [], 'copy': 7}})
    check('a bundle whose copy is a number is 400 naming copy',
          code == 400 and 'copy' in str((d or {}).get('error', '')), (code, d))
    # a bundle with no documents at all must leave the stored ones alone
    code, before_copy = admin('GET', '/copy')
    code, before_counts = admin('GET', '/counts')
    code, d = admin('POST', '/import?dry=1', {'bundle': {'regs': []}})
    check('a regs-only bundle inspects as empty and answers a confirm token',
          code == 200 and d.get('regs') == 0 and len(str(d.get('confirm', ''))) == 8, (code, d))
    code, d = admin('POST', '/import?wipe=0&confirm=' + str(d.get('confirm')), {'bundle': {'regs': []}})
    check('a regs-only bundle applies', code == 200 and d.get('applied') == 0, (code, d))
    time.sleep(8)
    code, after_copy = admin('GET', '/copy')
    check('a bundle without the documents left copy.json intact',
          code == 200 and isinstance(after_copy, dict) and len(after_copy) > 3 and after_copy == before_copy,
          (len(after_copy or {}), len(before_copy or {})))
    code, after_counts = admin('GET', '/counts')
    check('the same bundle left counts.json intact',
          code == 200 and after_counts == before_counts, (after_counts, before_counts))
    code, after_settings = admin('GET', '/settings')
    check('the same bundle left settings.json intact',
          code == 200 and isinstance(after_settings, dict) and len(after_settings) > 3,
          str(after_settings)[:160])

    # the confirm token the dry run answers is what the apply needs back
    code, dry1 = admin('POST', '/import?dry=1', {'jam': b64})
    check('the dry run over the jam answers a confirm token',
          code == 200 and len(str(dry1.get('confirm', ''))) == 8, (code, dry1))
    code, d = admin('POST', '/import?wipe=0', {'jam': b64})
    check('an apply with no confirm token is 400 naming confirm',
          code == 400 and 'confirm' in str((d or {}).get('error', '')), (code, d))
    code, d = admin('POST', '/import?wipe=0&confirm=deadbeef', {'jam': b64})
    check('an apply with a stale confirm token is 400',
          code == 400 and 'confirm' in str((d or {}).get('error', '')), (code, d))
    code, d = admin('POST', '/import?wipe=0&confirm=' + dry1['confirm'], {'jam': b64})
    check('the apply answers how many it wrote', code == 200 and d.get('applied') == len(roster['regs']), (code, d))
    time.sleep(15)
    code, after = admin('GET', '/regs')
    check('a restore over the same tree leaves the roster the same size',
          code == 200 and len(after['regs']) == len(roster['regs']),
          (len(after.get('regs', [])), len(roster['regs'])))
    code, d = admin('POST', '/reg/' + ck_rid, {'op': 'cancel', 'note': 'cancelled after the backup'})
    check('a registration is cancelled after the backup was taken', code == 200, (code, d))
    settle()
    code, d = admin('GET', '/reg/' + ck_rid)
    check('it reads as cancelled', code == 200 and d['status'] == 'cancelled', (code, d['status']))
    code, dry2 = admin('POST', '/import?dry=1', {'jam': b64})
    check('a fresh dry run answers a token for the tree as it stands now',
          code == 200 and len(str(dry2.get('confirm', ''))) == 8, (code, dry2))
    code, d = admin('POST', '/import?wipe=0&confirm=' + dry2['confirm'], {'jam': b64})
    check('the same jam applies again', code == 200, (code, d))
    time.sleep(15)
    code, d = admin('GET', '/reg/' + ck_rid)
    check('the restore put it back to its status in the bundle, with a history line',
          code == 200 and d['status'] == 'complete'
          and any(h['what'] == 'restored from backup' for h in d['history']), (code, d.get('status')))
    code, d = curl('GET', INSTANCE + '/tr/log?raw=1', jar=JAR)
    check('the restore left one ring entry naming the counts',
          code == 200 and isinstance(d, list) and any(e.get('op') == 'restore' for e in d),
          (code, str(d)[-200:]))
    check('the ring carries no secret after a restore', 'resend_key' not in json.dumps(d), '')
    # the pilgrim's own registration still answers, so the restore kept the tokens
    code, d = reg(ck_rid, ck_tok)
    check('the restored registration still answers to its own token', code == 200, (code, d))

try:
    run()
except Exception:
    traceback.print_exc()
    fails.append('CRASHED: see traceback above')
finally:
    # ---- restore the settings, then cancel every matrix registration, no matter how run() ended ----
    code, _ = admin('PUT', '/settings', original)
    check('the original settings are restored', code == 200, code)
    code, _ = admin('PUT', '/counts', orig_counts if isinstance(orig_counts, dict) else {})
    check('the original counts are restored', code == 200, code)
    settle()
    code, d = admin('GET', '/regs')
    for r in (d or {}).get('regs', []):
        if r['email'].lower().startswith('matrix-') and r['status'] not in ('draft', 'cancelled'):
            if r.get('exempt'):
                admin('POST', '/reg/' + r['id'], {'op': 'exempt', 'on': False})
            admin('POST', '/reg/' + r['id'], {'op': 'cancel', 'note': 'matrix cleanup'})
    settle()

code, d = curl('GET', INSTANCE + '/tr/log?raw=1', jar=JAR)
check('the audit ring has rows with a by', code == 200 and isinstance(d, list) and any(e.get('by') == 'admin:matrix' for e in d), (code, str(d)[:200]))
check('no secret in the audit ring', code == 200 and 'resend_key' not in json.dumps(d), '')

print()
print('ALL OK' if not fails else f'{len(fails)} FAILED: ' + '; '.join(fails))
sys.exit(1 if fails else 0)
