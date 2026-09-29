#!/usr/bin/env python3
"""Serve the pilgrim's page with a canned /api/status, so the look of it
can be judged without a ship running.

    python3 scripts/preview-page.py [port]      # default 8099
    then open http://127.0.0.1:8099/apps/register/

The copy comes out of +starter-copy in the library, so the page shows the
real words. Nothing here talks to a ship and nothing can be submitted:
this is for looking at the styling, not for testing the flow."""
import http.server, json, os, re, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = REPO + '/code/nex/register'
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8099

# the starter copy, read out of the library so the page shows the real words
hoon = open(REPO + '/code/lib/register.hoon').read()
start = hoon.index('++  starter-copy')
end = hoon.index('++  with-starter')
copy = {}
for line in hoon[start:end].splitlines():
    line = line.strip()
    if "['" not in line or "s+'" not in line:
        continue
    try:
        key = line.split("['", 1)[1].split("'", 1)[0]
        val = line.split("s+'", 1)[1].rsplit("']", 1)[0]
    except IndexError:
        continue
    copy[key] = val.replace("\\'", "'")

# +starter-waiver is built from paragraphs rather than typed as one cord,
# so the line parser above cannot see it. Read the arm and join its parts.
m = re.search(r"\+\+  starter-waiver\b(.*?)\n  ==", hoon, re.S)
if m:
    parts = re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(1))
    copy['waiver.text'] = '\n\n'.join(x.replace("\\'", "'") for x in parts if len(x) > 40)

STATUS = {
    'open': True, 'changes_open': True, 'owner': True, 'mode': 'stub',
    'now': '2026-09-29T15:00:00Z',
    'event': {'name': 'Baby Steps Camino 2026', 'days': ['2026-12-04', '2026-12-05', '2026-12-06']},
    'fees': {'full': 7500, 'bambino': 2500, 'suggested_full': 15000},
    'counts': {'full': 212, 'bambino': 4, 'social_fri': 60, 'social_sat': 40, 'late': 0, 'waitlist': 0},
    'caps': {'full': 325, 'bambino': 25, 'social_fri': 300, 'social_sat': 200, 'late_adds': 50, 'party': 12},
    'window': {'open': '2026-10-01T04:00:00Z', 'close': '2026-11-25T05:00:00Z',
               'change_cutoff': '2026-12-04T05:00:00Z'},
    'orgs': ['Order of Malta', "St. Paul's, Jacksonville Beach"],
    'copy': copy,
    'waiver_hash': '0xdead.beef',
}

class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        p = self.path.split('?')[0]
        if p.endswith('/api/status'):
            body = json.dumps(STATUS).encode()
            self.send_response(200)
            self.send_header('content-type', 'application/json')
            self.send_header('content-length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        name = p.rsplit('/', 1)[-1] or 'public.html'
        if name == 'register' or name == '':
            name = 'public.html'
        path = os.path.join(WEB, name)
        if not os.path.isfile(path):
            self.send_error(404)
            return
        kind = {'html': 'text/html', 'css': 'text/css', 'js': 'text/javascript',
                'png': 'image/png', 'svg': 'image/svg+xml', 'json': 'application/json'}
        data = open(path, 'rb').read()
        self.send_response(200)
        self.send_header('content-type', kind.get(name.rsplit('.', 1)[-1], 'text/plain'))
        self.send_header('content-length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass

print('copy keys: %d, serving on %d' % (len(copy), PORT))
http.server.HTTPServer(('127.0.0.1', PORT), H).serve_forever()
