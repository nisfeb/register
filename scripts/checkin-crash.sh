#!/usr/bin/env bash
# One crash run for the check-in durability test (plan phase 3): a burst
# of volunteer taps and self check-ins at the fleet ship ~tev, a kill -9
# of its vere (king and serf) AT seconds in, a restart from its event
# log, and checkin-durability.py verify over every write the ship acked.
#
# usage: scripts/checkin-crash.sh AT [SECONDS] [LOG]
#
# Only ever ~tev, the register fleet set's ship: it matches the king by
# its pier and port, so a clone of ~tev elsewhere is never touched.
set -u
AT=${1:?seconds into the burst to kill the ship}
SECS=${2:-90}
LOG=${3:-/tmp/crash-$AT-$(date +%s).jsonl}
HERE=$(cd "$(dirname "$0")" && pwd)
F=${FLEET:-$HOME/software/personal/hoon-development/fleet/fleet}
B=http://localhost:8126
J=${JAR:-/tmp/tev.jar}
PIER=$HOME/fleet/piers/tev

python3 "$HERE/checkin-durability.py" $B "$J" burst "$LOG" --seconds "$SECS" --day fri --parties 30 &
BURST=$!
sleep "$AT"
KING=$(pgrep -f "vere-v4.6-linux-x86_64 tev --http-port 8126" | head -1)
SERF=$(pgrep -f "work --snap-dir $PIER " | head -1)
[ -n "$KING" ] || { echo "crash: no ~tev king on 8126"; kill $BURST; exit 2; }
kill -9 $KING ${SERF:-}
echo "crash: killed ~tev (king $KING serf ${SERF:-none}) at ${AT}s"
sleep 3
T0=$(date +%s)
"$F" --as "${REGISTER_FLEET_WHO:-register-checkin}" up register >/dev/null 2>&1
until curl -s -m 5 -o /dev/null -w '%{http_code}' $B/apps/register/api/status | grep -q 200; do sleep 2; done
echo "crash: ~tev answering again after $(( $(date +%s) - T0 ))s"
wait $BURST
python3 "$HERE/checkin-durability.py" $B "$J" verify "$LOG"
