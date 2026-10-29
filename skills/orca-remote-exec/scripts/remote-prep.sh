#!/bin/zsh
# Prepare an execution tree on the remote host without touching its checkout's
# working tree.
#
#   remote-prep.sh <name> <ref> <sha> [--pub-get]   # shared base tree for one PR
#   remote-prep.sh <name> --clone-from <base>        # private copy for a worker that edits files
#   remote-prep.sh <name> --remove                   # delete the tree (and refs/mm/<name>)
#
# Base: fetches <ref> (pull/<N>/head or heads/<branch>) into refs/mm/<name> of
#       the remote checkout, exits 3 if it is not <sha>, then unpacks
#       `git archive <sha>` into /tmp/mm-trees/<name>. --pub-get runs
#       `fvm flutter pub get` there.
# Clone: APFS clone copy (cp -c) of /tmp/mm-trees/<base>, including resolved
#       dependencies; nearly instant and nearly free on disk.
# Other repositories: set MM_GIT_DIR to a bare clone on the remote host (make
#       one with `remote-prep.sh --mirror <github owner/repo>`); fetch, rev-parse
#       and archive then use it instead of the checkout.
#   remote-prep.sh --mirror <owner/repo>   # creates/refreshes /tmp/mm-repos/<repo>.git
# Prints TREE=<path> on success.
set -u
RUN=${0:A:h}/remote-run.sh
if [[ ${1:-} == --mirror ]]; then
  [[ $# -eq 2 && $2 =~ '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$' ]] || { echo "usage: remote-prep.sh --mirror <owner/repo>" >&2; exit 2; }
  M=/tmp/mm-repos/${2:t}.git
  exec $RUN -n 10 -t 1800 -- "
set -e
mkdir -p /tmp/mm-repos
if [ -d $M ]; then git --git-dir=$M fetch -q --prune origin; else git clone -q --bare https://github.com/$2.git $M; fi
echo MIRROR=$M
"
fi
G=git; [[ -n ${MM_GIT_DIR:-} ]] && G="git --git-dir=${MM_GIT_DIR}"
[[ $# -ge 2 ]] || { echo "usage: remote-prep.sh <name> <ref> <sha> [--pub-get] | <name> --clone-from <base> | <name> --remove" >&2; exit 2; }
NAME=$1
[[ $NAME =~ '^[A-Za-z0-9._-]+$' ]] || { echo "bad name: $NAME" >&2; exit 2; }
T=/tmp/mm-trees/${NAME}

if [[ $2 == --remove ]]; then
  exec $RUN -n 5 -t 300 -- "rm -rf $T; $G update-ref -d refs/mm/${NAME} 2>/dev/null; echo REMOVED=$T"
fi

if [[ $2 == --clone-from ]]; then
  [[ $# -ge 3 ]] || { echo "usage: remote-prep.sh <name> --clone-from <base>" >&2; exit 2; }
  BASE=$3
  [[ $BASE =~ '^[A-Za-z0-9._-]+$' ]] || { echo "bad base: $BASE" >&2; exit 2; }
  B=/tmp/mm-trees/${BASE}
  exec $RUN -n 20 -t 600 -- "
set -e
[ -d $B ] || { echo 'no base tree: $B'; exit 4; }
rm -rf $T
cp -cR $B $T
echo TREE=$T
"
fi

[[ $# -ge 3 ]] || { echo "usage: remote-prep.sh <name> <ref> <sha> [--pub-get]" >&2; exit 2; }
REF=$2; SHA=$3; PUB=${4:-}
[[ $SHA =~ '^[0-9a-f]{40}$' ]] || { echo "sha must be a full 40-char SHA" >&2; exit 2; }
PUBCMD=":"; [[ $PUB == --pub-get ]] && PUBCMD="cd $T && fvm flutter pub get"
exec $RUN -n 40 -t 2400 -- "
set -e
$G fetch -q origin '+refs/${REF}:refs/mm/${NAME}'
got=\$($G rev-parse refs/mm/${NAME})
[ \"\$got\" = '${SHA}' ] || { echo \"SHA mismatch: got \$got want ${SHA}\"; exit 3; }
rm -rf $T && mkdir -p $T
$G archive ${SHA} | tar -x -C $T
$PUBCMD
echo TREE=$T
"
