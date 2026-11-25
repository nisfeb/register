#!/usr/bin/env bash
# Every gate and every check-in test against the register fleet set
# ~tev, from its snapshots: the gates that make registrations on a fresh
# install over the golden, the check-in tests on prod-copy-v21 (a copy
# of production, stub mode). Prints one line per test and ALL GREEN or
# the failures at the end. About half an hour. Test ship only.
set -u
cd "$(dirname "$0")/.."
export FLEET_WHO=${REGISTER_FLEET_WHO:-register-checkin} REG_BASE=http://localhost:8126 REG_COOKIE=/tmp/tev.cookie
F=${FLEET:-$HOME/software/personal/hoon-development/fleet/fleet}
J=/tmp/tev.jar
fails=()
cookie() {
  scripts/hoon-test-kit/ship-cookie.sh ~/fleet/piers/tev $REG_BASE $J >/dev/null 2>&1
  grep urbauth $J | awk -F'\t' '{print $6"="$7}' > $REG_COOKIE
}
step() {  # name, command...
  local name=$1; shift
  local out; out=$("$@" 2>&1)
  if echo "$out" | grep -qE "ALL OK|verify: ALL OK"; then echo "ok    $name"
  else echo "FAIL  $name"; echo "$out" | grep -E "FAIL|LOST|GHOST|CRASH|Traceback" | head -5 | sed 's/^/        /'; fails+=("$name"); fi
}
days_today() {
  curl -s -b $J $REG_BASE/apps/register/api/admin/settings > /tmp/s.json
  python3 -c "
import json,datetime; s=json.load(open('/tmp/s.json')); d=datetime.date.today()
s['event']['days']=[str(d+datetime.timedelta(days=k)) for k in range(3)]; json.dump(s,open('/tmp/s.json','w'))"
  curl -s -b $J -X PUT -H 'content-type: application/json' -H 'x-actor: t' --data @/tmp/s.json $REG_BASE/apps/register/api/admin/settings -o /dev/null
  rm -f /tmp/s.json
}

# a reset that did not take would run every test on the wrong ship, so
# each one is checked before anything runs on it
reset_to() {  # snapshot
  if ! $F --as "$FLEET_WHO" reset register "$1" >>/tmp/fr-reset.log 2>&1; then
    sleep 20
    $F --as "$FLEET_WHO" reset register "$1" >>/tmp/fr-reset.log 2>&1 || { echo "FAIL  reset $1 (twice); see /tmp/fr-reset.log"; tail -5 /tmp/fr-reset.log | sed 's/^/        /'; exit 1; }
  fi
  until curl -s -m 5 -o /dev/null http://localhost:8126/~/login; do sleep 2; done
  local kings; kings=$(pgrep -fc "vere-v4.6-linux-x86_64 tev --http-port 8126")
  [ "$kings" = 1 ] || { echo "FAIL  reset $1: $kings kings on 8126"; exit 1; }
  cookie
}
if [ -z "${SKIP_FRESH:-}" ]; then
echo "== fresh install over the golden"
reset_to golden
st=$(curl -s -o /dev/null -w '%{http_code}' -b $J $REG_BASE/apps/register/api/status)
[ "$st" = 404 ] || { echo "FAIL  the golden already serves register ($st): the reset did not take"; exit 1; }
python3 scripts/dev-deploy.py $REG_BASE $J --add --wait --approve 2>&1 | grep -q "banged: 0" && echo "ok    deploy" || { echo "FAIL  deploy"; fails+=(deploy); }
sleep 8
step page-smoke           timeout 120 python3 scripts/page-smoke.py $REG_BASE
step public-form-click    timeout 300 node scripts/public-form-click.js
step public-edit-click    timeout 420 node scripts/public-edit-click.js
step public-checkin-click timeout 300 node scripts/public-checkin-click.js
step weekend-sim          timeout 400 python3 scripts/weekend-sim.py $REG_BASE $J
step api-matrix           timeout 1500 python3 scripts/api-matrix.py $REG_BASE $J
fi

echo "== the copy of production"
reset_to prod-copy-v21
n=$(curl -s -b $J "$REG_BASE/apps/register/api/checkin/roster?day=fri" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["rows"]), d["done"])')
# 579 registrations, of which 405 are not drafts (the roster leaves drafts out)
[ "$n" = "405 0" ] || { echo "FAIL  prod-copy-v21 is not the clean copy (rows, done: $n)"; exit 1; }
python3 scripts/dev-deploy.py $REG_BASE $J --wait 2>&1 | grep -q "banged: 0" && echo "ok    deploy" || { echo "FAIL  deploy"; fails+=(deploy); }
read RID LAST < <(curl -s -b $J "$REG_BASE/apps/register/api/checkin/roster?day=fri" | python3 -c '
import json,sys
rows=json.load(sys.stdin)["rows"]
hay=lambda r:" ".join([r["rid"]]+[p["first"]+" "+p["last"] for p in r["people"]]+[r.get("email","")]).lower()
H=[hay(r) for r in rows]
for r in rows:
  if r["status"]=="complete" and r["wristband"]["ok"] and len(r["people"])==2 and not any(p["checked"] for p in r["people"]):
    l=r["people"][1]["last"]
    if l and " " not in l and sum(l.lower() in h for h in H)==1: print(r["rid"], l); break')
step checkin-click        timeout 300 node scripts/checkin-click.js $RID "$LAST"
step admin-click          timeout 420 node scripts/admin-click.js $RID
for t in checkin-day-click checkin-hang-click checkin-login-click checkin-stale-click counts-race-click; do
  step $t timeout 300 node scripts/$t.js
done
step checkin-edit-probe   timeout 300 python3 scripts/checkin-edit-probe.py $REG_BASE $J
days_today
L=/tmp/fr-conc.jsonl; rm -f $L
timeout 200 python3 scripts/checkin-durability.py $REG_BASE $J burst $L --seconds 120 --parties 40 --volunteers 3 --editor 1 >/dev/null 2>&1
step concurrency          python3 scripts/checkin-durability.py $REG_BASE $J verify $L
step crash-at-30          timeout 300 scripts/checkin-crash.sh 30 150 /tmp/fr-crash.jsonl

echo
if [ ${#fails[@]} -eq 0 ]; then echo "ALL GREEN"; else echo "FAILED: ${fails[*]}"; fi
