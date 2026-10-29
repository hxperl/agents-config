#!/bin/zsh
# Run one shell command on a paired remote Orca host, wait for it, print the
# output tail, and exit with the remote command's exit code.
#
#   remote-run.sh [-C <remote dir>] [-n <tail lines>] [-t <timeout sec>] -- '<command>'
#
# - Runs in the remote login shell. The full log stays at ~/mm-logs/<id>.log there.
# - Exit code = the remote command's exit code. 125 = host unreachable / timeout
#   (reason on stderr). 126 = the -C directory does not exist on the remote host.
# - Local concurrency is capped at MM_SLOTS (default 4).
# - MM_ENV selects the saved Orca environment (default "mac mini"); MM_REPO the
#   remote checkout the terminal is opened in (default per host, below). Never
#   run or write inside MM_REPO itself — use trees from remote-prep.sh.
set -u
ENV_NAME=${MM_ENV:-mac mini}
case $ENV_NAME in
  "mac mini") REPO_DEFAULT=/Users/geonseok.lee/Workspace/ma/ma-client;;
  *) REPO_DEFAULT="";;
esac
REPO=${MM_REPO:-$REPO_DEFAULT}
[[ -n $REPO ]] || { echo "remote-run: set MM_REPO for environment '$ENV_NAME'" >&2; exit 2; }
DIR=$REPO; TAIL=120; TIMEOUT=3600
while [[ $# -gt 0 ]]; do
  case $1 in
    -C) DIR=$2; shift 2;;
    -n) TAIL=$2; shift 2;;
    -t) TIMEOUT=$2; shift 2;;
    --) shift; break;;
    *) break;;
  esac
done
[[ $# -ge 1 ]] || { echo "usage: remote-run.sh [-C dir] [-n tail] [-t sec] -- '<command>'" >&2; exit 2; }
CMD="$*"

SLOTS=${MM_SLOTS:-4}; LOCKBASE=/tmp/mm-run-locks; mkdir -p $LOCKBASE
slot=""
while [[ -z $slot ]]; do
  for i in $(seq 1 $SLOTS); do
    if mkdir $LOCKBASE/slot$i 2>/dev/null; then slot=$LOCKBASE/slot$i; echo $$ > $slot/pid; break; fi
    p=$(cat $LOCKBASE/slot$i/pid 2>/dev/null); [[ -n $p ]] && ! kill -0 $p 2>/dev/null && rm -rf $LOCKBASE/slot$i
  done
  [[ -z $slot ]] && sleep 3
done
H=""
cleanup() {
  [[ -n $H ]] && orca terminal close --environment "$ENV_NAME" --terminal $H --json >/dev/null 2>&1
  rm -rf $slot
}
trap cleanup EXIT INT TERM

ID=mm-$(date +%Y%m%d%H%M%S)-$$-$RANDOM
SCRIPT="mkdir -p \$HOME/mm-logs; L=\$HOME/mm-logs/$ID.log
if cd ${(q)DIR} 2>/dev/null; then ( $CMD ) > \$L 2>&1; echo MM_EXIT=\$? >> \$L; else echo 'no such dir: '${(q)DIR} > \$L; echo MM_EXIT=126 >> \$L; fi
echo MM_BEGIN_$ID; tail -n $TAIL \$L; echo MM_END_$ID"
B64=$(printf '%s' "$SCRIPT" | base64 | tr -d '\n')
H=$(orca terminal create --environment "$ENV_NAME" --worktree "path:$REPO" --title "$ID" \
  --command "echo $B64 | base64 -D > /tmp/$ID.sh && zsh /tmp/$ID.sh; rm -f /tmp/$ID.sh" --json 2>/dev/null \
  | python3 -c 'import json,sys
try: print(json.load(sys.stdin)["result"]["terminal"]["handle"])
except Exception: pass')
[[ -n $H ]] || { echo "remote-run: could not open a terminal on '$ENV_NAME' (check the connection)" >&2; exit 125; }

start=$SECONDS
while true; do
  out=$(orca terminal read --environment "$ENV_NAME" --terminal $H --limit $((TAIL + 50)) --json 2>/dev/null)
  res=$(printf '%s' "$out" | ID=$ID python3 -c '
import json,os,sys
id=os.environ["ID"]
try: lines=json.load(sys.stdin)["result"]["terminal"]["tail"]
except Exception: sys.exit(0)
b=e=None
for i,l in enumerate(lines):
  if l.strip()=="MM_BEGIN_"+id: b=i
  if l.strip()=="MM_END_"+id: e=i
if b is not None and e is not None and e>b: print("\n".join(lines[b+1:e]))
')
  if [[ -n $res ]]; then
    print -r -- "$res" | grep -v '^MM_EXIT='
    code=$(print -r -- "$res" | grep '^MM_EXIT=' | tail -1 | cut -d= -f2)
    echo "[remote-run] $ENV_NAME:~/mm-logs/$ID.log exit=${code:-?}" >&2
    exit ${code:-125}
  fi
  (( SECONDS - start > TIMEOUT )) && { echo "remote-run: timeout after ${TIMEOUT}s (log ~/mm-logs/$ID.log)" >&2; exit 125; }
  sleep 3
done
