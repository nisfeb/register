#!/usr/bin/env python3
"""set-copy.py HOST JAR [key ...]
Push copy defaults from the library onto a running ship.

A ship keeps every string an organizer edited, for ever: copy.json is
laid %fall and +with-starter unions the library's defaults UNDER what is
stored. So changing a default in +starter-copy reaches a NEW ship and no
other. When the wording of a string that ships already hold has to
change, it goes out through here.

With no keys it lists every string whose stored value differs from the
library's, and changes nothing. With keys it sets those, and only those.

  scripts/set-copy.py https://host /path/to/jar               # what differs
  scripts/set-copy.py https://host /path/to/jar form.weekend  # set one

It never touches a key you did not name, so an organizer's own wording
is safe unless you ask for it by name.
"""
import json, os, re, subprocess, sys

HOST, JAR = sys.argv[1:3]
WANT = sys.argv[3:]
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = HOST + '/apps/register/api'
ACTOR = 'set-copy'


CORD = r"'((?:[^'\\]|\\.)*)'"
CORD_PAIR = re.compile(r"\['([a-z0-9_.]+)' s\+" + CORD + r"\]")


def unescape(v):
    return v.replace("\\'", "'").replace('\\\\', '\\')


def arm_of(lib, name):
    """the source of one ++ arm, up to the next one"""
    start = lib.index('++  ' + name)
    return lib[start:lib.index('\n++  ', start)]


def rebuild(block):
    """a run of cord literals and `nl` tokens, joined the way +rap does.
    A Hoon cord cannot hold a newline, so a string with paragraphs in it
    is written as cords with `nl` between them; this reads it back."""
    out = []
    for tok in re.finditer(r"::[^\n]*|" + CORD + r"|\bnl\b", block):
        t = tok.group(0)
        if t.startswith('::'):
            continue                      # a comment, not part of the string
        out.append('\n' if t == 'nl' else unescape(t[1:-1]))
    return ''.join(out)


BUILT = re.compile(
    r"^      :-  '([a-z0-9_.]+)'\n"       # the key
    r"      :-  %s\n"
    r"      %\+  rap  3\n"
    r"      :~\n"
    r"(.*?)"                              # the cords and the nls
    r"^      ==$",
    re.M | re.S)


def starter():
    """every string the library ships, by key: the one-line ones, the
    ones assembled out of cords, and the agreement in its own arm"""
    lib = open(os.path.join(REPO, 'code/lib/register.hoon')).read()
    copy = arm_of(lib, 'starter-copy')
    out = {}
    for k, v in CORD_PAIR.findall(copy):
        out[k] = unescape(v)
    for k, block in BUILT.findall(copy):
        out[k] = rebuild(block)
    out['waiver.text'] = rebuild(arm_of(lib, 'starter-waiver').split(':~', 1)[1])
    return out


def curl(method, path, body=None):
    cmd = ['curl', '-s', '-m', '60', '-X', method, API + path,
           '-b', JAR, '-H', 'x-actor: ' + ACTOR, '-w', '\n%{http_code}']
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '--data', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    return int(code or 0), text


def main():
    code, text = curl('GET', '/status')
    if code != 200:
        sys.exit('the ship would not answer /status: ' + str(code))
    live = json.loads(text)['copy']
    base = starter()
    differs = [k for k in sorted(base) if k in live and live[k] != base[k]]
    if not WANT:
        print('%d strings differ from the library:' % len(differs))
        for k in differs:
            print('\n  ' + k)
            print('    ship: ' + live[k][:140])
            print('    code: ' + base[k][:140])
        if differs:
            print('\nName the ones to push, e.g.\n  %s %s %s' % (sys.argv[0], HOST, JAR) +
                  ' ' + ' '.join(differs[:3]))
        return 0
    bad = 0
    for k in WANT:
        if k not in base:
            print('  SKIP  %s is not a string the library has' % k)
            bad += 1
            continue
        if live.get(k) == base[k]:
            print('  same  %s' % k)
            continue
        code, text = curl('POST', '/admin/copy/set', {'key': k, 'value': base[k]})
        ok = code == 200
        bad += 0 if ok else 1
        print('  %s  %s -> %s' % ('set ' if ok else 'FAIL', k, base[k][:90]))
        if not ok:
            print('        %s %s' % (code, text[:120]))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
