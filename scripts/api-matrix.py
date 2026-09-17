#!/usr/bin/env python3
"""api-matrix.py HOST JAR
The HTTP gate for register, phase 1: the pilgrim's flow in stub mode
against a fake ship. HOST like http://localhost:8080; JAR a curl cookie
jar with the owner cookie. Exits 1 on any failure. Safe to rerun: it
cancels what an earlier run left and restores the settings it changed."""
import json, subprocess, sys, time

HOST, JAR = sys.argv[1:3]
API = HOST + '/apps/register/api'
INSTANCE = HOST + '/grubbery/ball/apps/shell.shell/desks/register.desk/desk/data/register.register_app'
ACTOR = 'matrix'
fails = []


def curl(method, url, body=None, jar=None, actor=None, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    if jar:
        cmd += ['-b', jar]
    if actor:
        cmd += ['-H', 'x-actor: ' + actor]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


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


def status():
    code, d = curl('GET', API + '/status')
    check('GET /status answers 200', code == 200, (code, d))
    return d


# ---- settings: open the window, remember the original ----
code, original = admin('GET', '/settings')
check('GET /admin/settings answers 200 with the cookie', code == 200 and isinstance(original, dict), (code, original))
code, _ = curl('GET', API + '/settings')
check('GET /admin/settings without the cookie is 404 (no such public route)', code == 404, code)
code, _ = curl('GET', API + '/admin/regs')
check('GET /admin/regs without the cookie is 403', code == 403, code)
code, _ = curl('PUT', API + '/admin/settings', original, jar=JAR)
check('PUT /admin/settings without x-actor is 400', code == 400, code)
check('secrets come back masked or empty', original.get('mail', {}).get('resend_key', '') in ('', '****'), original.get('mail'))

settings = json.loads(json.dumps(original))
settings['window'] = {'open': '2026-01-01T00:00:00Z', 'close': '2036-01-01T00:00:00Z', 'change_cutoff': '2036-01-01T00:00:00Z'}
settings['caps'] = {'full': 325, 'bambino': 25, 'social_fri': 300, 'social_sat': 200, 'late_adds': 50}
settings['providers'] = {'mode': 'stub'}
code, _ = admin('PUT', '/settings', settings)
check('PUT /admin/settings opens the window', code == 200, code)
settle()

# ---- clean what an earlier run left ----
code, d = admin('GET', '/regs')
check('GET /admin/regs answers 200', code == 200, (code, d))
for r in (d or {}).get('regs', []):
    if r['contact']['email'].lower().startswith('matrix-') and r['status'] not in ('draft', 'cancelled'):
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
code, d = curl('POST', API + '/submit', party('full', 'matrix-non@example.com', [person('Fay', 'Shrine', days={'fri': False, 'sat': False, 'sun': False})]))
check('a non-walker pays the track fee and gets a spot without counting', code == 200 and d['fees'] == 7500 and d['status'] == 'waiver', (code, d))
non_rid, non_tok = d['rid'], d['token']

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

# ---- the cap and the wait list ----
s3 = status()
settings['caps']['full'] = s3['counts']['full'] + 1
admin('PUT', '/settings', settings); settle()
code, d = curl('POST', API + '/submit', party('full', 'matrix-wait1@example.com', [person('Hal', 'Wait'), person('Ivy', 'Wait')]))
check('a party of two over the cap is wait listed at position 1', code == 200 and d['status'] == 'waitlist' and d['position'] == 1, (code, d))
w1_rid, w1_tok = d['rid'], d['token']
settle()
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

# ---- the window ----
settings['window']['close'] = '2020-01-01T00:00:00Z'
admin('PUT', '/settings', settings); settle()
code, d = curl('POST', API + '/submit', party('full', 'matrix-late@example.com', [person('Ned', 'Late')]))
check('a submit after close is 403', code == 403, (code, d))
s8 = status()
check('status says closed', s8['open'] is False, s8['open'])

# ---- restore, then cancel every matrix registration ----
code, _ = admin('PUT', '/settings', original)
check('the original settings are restored', code == 200, code)
settle()
code, d = admin('GET', '/regs')
for r in (d or {}).get('regs', []):
    if r['contact']['email'].lower().startswith('matrix-') and r['status'] not in ('draft', 'cancelled'):
        admin('POST', '/reg/' + r['id'], {'op': 'cancel', 'note': 'matrix cleanup'})
settle()
code, d = curl('GET', INSTANCE + '/tr/log?raw=1', jar=JAR)
check('the audit ring has rows with a by', code == 200 and isinstance(d, list) and any(e.get('by') == 'admin:matrix' for e in d), (code, str(d)[:200]))
check('no secret in the audit ring', code == 200 and 'resend_key' not in json.dumps(d), '')

print()
print('ALL OK' if not fails else f'{len(fails)} FAILED: ' + '; '.join(fails))
sys.exit(1 if fails else 0)
