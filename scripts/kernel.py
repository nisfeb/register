"""Where register lives on a grubbery ship.

The kernel moved the shell from /apps/shell.shell to /apps/shell. Ask
the ship which spelling it has: GET /grubbery/api/peek/apps/ lists the
dirs under /apps. A ship with no peek route (400 or 404) is an old kernel.
The same helper as calendar's scripts/kernel.py.
"""
import json, subprocess, sys, time


def shell(base, jar):
    """'/apps/shell' or '/apps/shell.shell', whichever the ship has"""
    for _ in range(5):
        r = subprocess.run(['curl', '-s', '-m', '120', '-b', jar, '-w', '\n%{http_code}',
                            base.rstrip('/') + '/grubbery/api/peek/apps/'], capture_output=True, text=True)
        body, _, code = r.stdout.rpartition('\n')
        if code == '200':
            try:
                return '/apps/shell' if 'shell' in json.loads(body).get('dirs', []) else '/apps/shell.shell'
            except (ValueError, AttributeError):
                pass
        elif code in ('400', '404'):
            return '/apps/shell.shell'  # no peek route: the old kernel
        time.sleep(5)
    sys.exit(f'kernel: {base} did not answer GET /grubbery/api/peek/apps/ (check the cookie)')


def desk(base, jar):
    return shell(base, jar) + '/desks/register.desk'


def app(base, jar):
    """the register instance"""
    return desk(base, jar) + '/desk/data/register.register_app'
