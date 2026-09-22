# Supervision, result transport, and completion

Loaded once workers are dispatched. Startup proof, rolling checks, stall detection, recovery, the completion audit, and the message-size protocol that keeps long reports out of the user's conversation.

### Supervision and proactive progress reporting

Supervision is active work, not a single blocking wait. Apply these rules to
every live Dispatch:

1. **Startup proof:** within about 60 seconds of `worker-start`, inspect the
   Task/Dispatch and a bounded worker transcript. Confirm task-specific
   reasoning, tool use, or an explicit current phase. Startup banners, MCP
   warnings, an idle prompt, or the injected task merely appearing on screen do
   not count. Save the first `worker-read` cursor; only output after that cursor
   counts as fresh startup or progress evidence.
   - For interactive agent TUIs, explicitly check whether the injected task is
     only sitting in the input editor without being submitted. If so, send one
     Enter with `orca terminal send --terminal <handle> --enter --json`, then
     re-read the transcript. A successful byte write still is not startup proof;
     require task-specific reasoning or tool output after the saved cursor.
2. **Rolling checks:** keep a per-Dispatch checkpoint and recheck long-running
   workers at useful intervals, normally every 2-5 minutes or after each wait
   timeout. Use `task-list`, `worker-show`, and bounded `worker-read`; do not
   flood the transcript or repeatedly inject the task.
3. **Stall detection:** distinguish slow work from a stalled worker. A worker is
   not stalled merely because it is quiet. Investigate when two consecutive
   checkpoints show no task-specific progress or cursor advance, the terminal
   remains at startup or an idle prompt, the process exited, or output repeats
   the same failure. Call this `unconfirmed inactivity`, not failure. Check the
   terminal and Dispatch state before deciding on recovery.
4. **Recovery:** if input was not consumed or two checkpoints show unconfirmed
   inactivity, send one concise structured follow-up to that Dispatch when the
   worker can still receive messages. Retry only after `worker-show` proves
   `failed`/`stopped`, or after explicitly stopping an outcome-unknown worker as
   the installed guide permits. Never create a duplicate writer or re-dispatch
   the same task blindly.
   - Before stopping a healthy interactive TUI whose task text is visibly
     unsubmitted, try the explicit Enter recovery above once. If empty Enter is
     ignored, append one short instruction such as `Begin the assigned task
     now.` and submit it once. Do not repeatedly type the full task spec.
   - **Stop the worker before settling the task, never after.** For a dispatch
     that died without `worker_done`, run `worker-stop --dispatch <id>` first
     and only then `task-update --status failed`. Settling first strips the
     dispatch of cleanup ownership: the later `worker-stop` returns
     `dispatch_inactive` and takes no action, so the agent process and its
     terminal stay alive holding memory. Measured on 2026-09-16 — three Qwen
     workers killed by the stream cap were marked `failed`, and all three
     terminals were still live afterwards until closed by hand with
     `terminal close`.
   - After any wave, account for the terminals as well as the tasks. A settled
     or failed task says nothing about whether its process exited. Use the
     lifecycle-specific action: accepted completion is transferred, retained,
     or released; a worker that died without completion is stopped before task
     settlement; ambiguous ownership follows the stop, abandon, or release
     receipt from the installed guide. Never replace this accounting with a raw
     terminal close. The 2026-09-16 incident above records why ordering matters;
     it is not a terminal-close recipe.
5. **Completion audit:** heartbeat, status, TUI idle, a report file, or a final
   sentence in terminal output is not completion. Require valid `worker_done`.
   If useful work appears complete but the lifecycle message is missing, prompt
   that exact worker once to send `worker_done`; recover task state explicitly
   only when the guide permits it.
6. **User updates:** report startup verification, material progress, stalls or
   recovery, and completions proactively. During continuous work, do not leave
   the user without a concise update for more than about 60 seconds. Do not make
   the user ask whether workers are still working.
7. **Truthful wording:** say “dispatched” until startup proof exists, “working”
   only with task-specific evidence, and “complete” only after accepted
   `worker_done` plus report inspection.

Before each coordinator wait and before the final answer, account for every
expected Dispatch: working with recent evidence, waiting on a known dependency,
settled and released/reused, explicitly retained at the user's request, or
blocked and fenced through the installed guide's recovery path.

Maintain the expected Dispatch ID set until synthesis. Before the final answer,
perform one non-blocking lifecycle check plus `task-list`/`dispatch-show`
reconciliation so a just-arrived completion is not missed. Process every
message and inspect required artifacts before acknowledging its Delivery.

Use coordinator waits for lifecycle types only. Do not use message injection in
the primary user-facing terminal to retrieve routine reports. After a valid
`worker_done`, read the referenced report artifact directly from the filesystem.
If a worker violates the protocol and sends a long orchestration message,
consume it privately, do not reproduce it verbatim, and reinforce the protocol
in any later dispatch to that terminal.

### Reclaim settled workers

An accepted `worker_done` ends the Dispatch's work but does not by itself close
the owned agent terminal. Before acknowledging that Delivery or waiting again,
choose exactly one lifecycle action from the version-matched orchestration
guide:

1. Transfer the same terminal to an immediate follow-up Dispatch for the same
   agent.
2. If the user explicitly asked to keep the terminal live for debugging, record
   that exception with the guide's retain operation.
3. Otherwise release the settled worker. Do this for both succeeded and failed
   `worker_done` outcomes. Release preserves inspectable output, so keeping a
   process alive merely to read its transcript is not a valid reason to retain
   it.

Do not release on a timeout, heartbeat, status, idle prompt, question,
escalation, or rejected/stale completion. Fence an outcome-unknown worker using
the guide's stop or abandon recovery first. If release reports pending or
unknown ownership, follow the receipt's recovery action; never substitute a
raw terminal close. Never close a coordinator, setup terminal, reused or
pre-existing terminal, user-owned terminal, or another Run's worker.

Before the final answer, query worker resource accounting for the Run and
reconcile every Dispatch. There must be no unexplained active, reclaimable,
release-pending, or release-unknown owned worker. A retained worker is acceptable
only when the user requested it, and the final report must name that exception.

Worker release and worktree deletion are separate decisions. A Run-created
read-only worktree is disposable after synthesis. Remove it when all of these
facts are verified: the selected path belongs to this Run, the output of
`git status --porcelain=v1` is empty, no live terminal references it, and every
needed
report, ignored file, external artifact, or test result is preserved elsewhere.
If any condition is unverified, retain the worktree and report why. Never remove
the user's current or pre-existing worktree. Retain and report any writer
worktree with dirty changes, unmerged commits, or evidence still needed for the
requested result; never force-remove it merely to make the resource list empty.

Do not reset an active orchestration Run or discard worker artifacts merely to
tidy up. Preserve evidence until it has been inspected and incorporated into
the coordinated result, while still applying the mandatory terminal release
rules above as each Dispatch settles.

## Transport results without flooding the user

Treat Orca messages as lifecycle control, not as a transport for long reports.
The coordinator's terminal can surface orchestration messages in the user
conversation, so a long `status` body is a user-visible failure.

Require every worker to follow this protocol:

1. Write investigation, review, comparison, or other long-form results to a
   unique UTF-8 Markdown file in an agent-owned system temporary directory
   outside the repository. Include the task and dispatch identifiers in the
   filename or containing directory.
2. Do not create report files inside the project worktree unless the user
   explicitly requested a repository document.
3. Use `heartbeat` only for liveness. Use `status` only for a brief progress
   checkpoint of at most 300 characters. Never put findings, evidence lists,
   final conclusions, Markdown sections, or a report in either message type.
4. Send no separate final `status` message before completion.
5. Send `worker_done` exactly once. Limit its body to three short sentences and
   at most 600 characters. Include the active task and dispatch identifiers,
   `filesModified`, and the absolute `reportPath` in its structured payload.
6. For a genuinely short result that needs no artifact, keep the entire
   `worker_done` body under the same limit and omit `reportPath`.
7. After `worker_done`, stop and return to idle as required by the installed
   orchestration guide.

For implementation tasks, the code diff and test output are primary artifacts.
Create a separate report only when the worker must communicate analysis that
does not fit the bounded completion summary.

For cross-review, pass report paths or bounded normalized extracts to reviewers.
Do not copy entire reports into task specs, `status`, `reply`, or direct terminal
messages.
