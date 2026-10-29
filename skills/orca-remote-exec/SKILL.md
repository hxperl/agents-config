---
name: orca-remote-exec
description: >-
  Keep judgment on this machine and spend a paired remote Orca machine's
  resources on execution: package installs, builds, format/analyze gates, test
  suites, uv/pytest. The remote host has the toolchain but no agents. Use when
  a coordinator or worker needs to build or test for a review or verification
  and a remote compute host (for example "mac mini") is paired, when local
  memory is tight, or when the user says to use the remote machine —
  "맥미니에서 돌려", "원격에서 테스트", "리소스는 맥미니 걸로". Do not use it to
  launch agents remotely or to edit the remote machine's own checkouts.
---

# Orca Remote Exec

**The one invariant: judgment stays here, execution goes there.** Agents,
reading, deciding, writing reports and posting to GitHub run on this machine.
Only commands travel to the remote host, and only their output tail and exit
code come back. Everything below exists to keep that boundary safe.

Read `references/hosts.md` for the paired hosts, their paths and toolchains
before the first command in a session.

## Tools

Call the scripts by absolute path: `~/.agents/skills/orca-remote-exec/scripts/`.

| Command | Does |
|---|---|
| `remote-prep.sh <name> <ref> <sha> [--pub-get]` | Base tree: fetches `<ref>` into `refs/mm/<name>` of the remote checkout, exits 3 unless it is `<sha>`, unpacks `git archive <sha>` into `/tmp/mm-trees/<name>`, optionally runs `fvm flutter pub get` there. |
| `remote-prep.sh <name> --clone-from <base>` | Private copy of a base tree (APFS clone, resolved dependencies included) for a worker that edits files. |
| `remote-prep.sh <name> --remove` | Deletes the tree and `refs/mm/<name>`. |
| `remote-run.sh [-C dir] [-n lines] [-t sec] -- '<command>'` | Runs the command in the remote login shell, waits, prints the last `-n` lines, exits with the remote exit code. Full log: `~/mm-logs/<id>.log` on the remote host. Opens and closes its own Orca terminal. |

`<ref>` is `pull/<N>/head` or `heads/<branch>`. Environment: `MM_ENV` (default
`mac mini`), `MM_REPO` (remote checkout; default per host), `MM_SLOTS` (local
concurrency cap, default 4).

## Tree layout for a multi-agent review

One base tree per PR, shared by every reviewer; one clone per reviewer that
modifies files.

1. **The coordinator** prepares the base tree once, after verifying the live
   head: `remote-prep.sh <PR> pull/<PR>/head <sha> --pub-get`.
2. **Read-only work runs in the base tree concurrently**: `git diff`/`show`,
   analyze, `dart format -o none`, ordinary `flutter test`, `uv run` checks.
   Measured: three concurrent test runs (two in the same tree) passed without
   interference.
3. **Anything that writes files runs in a clone**: reverse-patch (mutation)
   checks, golden regeneration, build_runner, gen-l10n regeneration diffs,
   `dart format` without `-o none`. The worker makes it with
   `remote-prep.sh <PR>-<agent> --clone-from <PR>` and removes it itself.
4. Sharing a tree shares evidence, not conclusions — independence is kept by
   the briefs, not by separate trees.

## Rules

1. **Never mutate the remote checkout.** No checkout, switch, reset, stash,
   pub get, build or file writes in `MM_REPO`. Only `refs/mm/*` are written
   there; everything executable runs under `/tmp/mm-trees/`.
2. **Never write in a shared base tree.** Edits go to a clone (layout §3).
3. **Freshness is the caller's job.** Pass the SHA you verified against the
   live PR. On exit 3, re-verify; never silently retry with the new SHA.
4. **The exit code is the verdict.** Do not end a remote command with
   `| tail`, `| head` or `|| true`; shorten output with `-n`. 125 means the
   host was unreachable or timed out, 126 a missing `-C` directory — neither is
   a test result.
5. **zsh quoting.** Write `"${VAR}:path"`, never `"$VAR:path"`: zsh reads `:r`,
   `:a`, `:h` after a variable as modifiers and mangles refspecs and paths.
6. **Cleanup is mandatory.** Workers remove their clones; the coordinator
   removes base trees when the review is done, then audits (below). A Run is
   not finished while a tree, a `refs/mm/*` ref or an `mm-*` terminal it
   created remains.
7. **Fall back explicitly.** If the host is unreachable or lacks a tool, run
   locally in an isolated `/tmp` tree under the local concurrency limit and say
   so in the report. Never present a local run as a remote one.
8. **Installing or upgrading tools on the remote host changes that machine.**
   Do it only when the user asked; record the versions in `references/hosts.md`
   and verify with a version command afterwards.

## Cleanup audit

```bash
R=~/.agents/skills/orca-remote-exec/scripts/remote-run.sh
$R -n 20 -- 'ls /tmp/mm-trees 2>/dev/null; git for-each-ref refs/mm --format="%(refname)"; git status --porcelain=v1 | wc -l'
orca terminal list --environment "mac mini" --json   # no terminal titled mm-* may remain
```

Expected: no trees or refs you created, `0` checkout changes, no `mm-*`
terminals. Terminals with other titles belong to someone else — leave them.

## Briefing workers

Paste this into each worker brief that needs execution (fill the names):

```text
- 판단은 여기서, 실행은 원격 호스트(mac mini)에서 한다. 기준 트리는 코디네이터가 만들어 두었다: /tmp/mm-trees/<PR> (head <SHA>, pub get 완료).
- 읽기·analyze·format(-o none)·일반 test 는 기준 트리에서:
  ~/.agents/skills/orca-remote-exec/scripts/remote-run.sh -C /tmp/mm-trees/<PR> -n 80 -- '<명령>'
- 파일을 바꾸는 작업(역패치·골든·build_runner·gen-l10n 비교)은 내 사본에서만:
  ~/.agents/skills/orca-remote-exec/scripts/remote-prep.sh <PR>-<agent> --clone-from <PR>
  끝나면 remote-prep.sh <PR>-<agent> --remove
- 종료 코드가 판정이다. 원격 명령 끝에 | tail 을 붙이지 말고 -n 으로 줄여라. 125 는 연결 실패, 126 은 디렉터리 없음.
- 원격 체크아웃(/Users/geonseok.lee/Workspace/ma/ma-client)과 기준 트리에는 쓰지 않는다.
- 연결이 안 되면 로컬 /tmp 트리에서 돌리고 보고서에 그렇게 적는다.
```

## Checking a host

```bash
orca host list --json
~/.agents/skills/orca-remote-exec/scripts/remote-run.sh -n 20 -- \
  'hostname; fvm --version; fvm flutter --version | head -1; uv --version; gh auth status 2>&1 | head -2'
```

The version pipe here is display only; a non-zero exit or 125 means the host is
not usable right now — report it.
