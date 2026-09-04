---
name: parallel-worker-orchestration
description: >-
  Coordinate a user request through a dynamically sized pool of supervised Orca
  workers, including any requested mix such as three Codex workers and two
  Claude workers, then collect and synthesize their results. Use when the user
  asks to run work in parallel, delegate to multiple workers or agents, have
  Claude, Codex, and Qwen Code independently investigate or implement
  something, make agents review or debate each other's results, or use a
  master/coordinator to reach a consensus. Trigger on requests such as "병렬로
  시켜", "워커들에게 맡겨", "Claude와 Codex에게 시켜", "코덱스 3개와 클로드
  2개", "qwen한테 시켜", "큐원 워커", "서브 워커로 진행", "마스터가
  종합해", or "서로 검토시켜". Do not trigger for
  an ordinary single-agent task merely because it could theoretically be
  parallelized.
---

# Parallel Worker Orchestration

Act as the master coordinator by default. Convert the user's request into a
task graph, provision the required number and mix of Orca workers, supervise
their dispatches, and return one evidence-backed result. Do not make the user
manually create terminals, tasks, or dispatches.

## Mandatory startup

1. Read and follow the available `orchestration` skill before taking any Orca
   action. Load the installed CLI's version-matched guide as that skill directs.
2. Check that the Orca runtime is ready.
3. Use real Orca terminals and orchestration state. Never substitute an
   in-process subagent, generic collaboration tool, or untracked terminal
   prompt.
4. If Orca cannot run, report the exact error and stop. Do not silently switch
   coordination systems or guess unsupported commands.
5. Announce the selected topology and worker assignments briefly, then start.
   Do not ask for confirmation when the user's request already authorizes
   parallel workers.

CLI flags change between Orca versions. Do not copy commands from this skill or
memory. Derive every command from the version-matched orchestration guide.

## Preserve the user's authority

Parallel execution changes how work is performed, not what is authorized.

- A request to inspect, review, diagnose, compare, or recommend is read-only.
- A request to change or build may modify only the requested scope.
- Do not create Jira tickets, branches, commits, pushes, PRs, comments, or
  external writes unless the request authorizes them.
- Do not resolve review conversations unless the user explicitly requests it;
  resolution normally belongs to the reviewer.
- Apply all repository rules and relevant project skills to every worker task.

## Verify repository freshness before dispatch

For every repository-backed task, establish the evidence baseline before
workers investigate or edit:

1. Refresh remotes non-destructively with pruning and record the exact remote
   refs and SHAs relevant to the request. Do not pull into or rewrite a user's
   dirty worktree.
2. For PR work, retrieve current PR base/head metadata after the refresh and
   require workers to compare those exact refs.
3. Do not equate `origin/main`, a merge-base, a cached worktree, a backup
   snapshot, or previously collected environment data with the current target.
   For stacked PRs, snapshot repositories, generated data, and environment
   comparisons, verify the actual current source environment and collection
   time independently.
4. Put the verified refs, SHAs, source environment, and any collection timestamp
   in every worker task. If these cannot be verified, mark freshness as blocked
   and prohibit workers from presenting conclusions as current.
5. During synthesis, audit each report's baseline. Multiple workers using the
   same stale or unverified baseline are correlated duplicates, not independent
   confirmation; rerun the comparison with current evidence before answering.

## Choose the topology

Honor an explicit worker count, agent choice, topology, or worktree request.
Do not normalize a requested mix into one Claude and one Codex. For example,
`Codex 3 + Claude 2` means five worker terminals and five initial assignments,
unless the user explicitly assigns some of them as reviewers or masters.

### Summoning rules

These decide which families to spawn when the user leaves the mix flexible.
They are independent of which agent is coordinating; determine the coordinator's
own family first, then apply them in order. Rule 1 outranks every other rule
here, and none of them may reduce an explicit worker count.

1. **An explicit request wins outright.** A named family or count is preserved
   exactly. If a requested family is unavailable, say so and stop; never
   substitute a different one.
2. **Never spawn the coordinator's own family for diversity alone.** Diversity
   means a family the coordinator is not. Add a same-family worker only when
   the user asks for it or same-family replication is itself the point (for
   example, two independent runs of one model to measure variance).
3. **The default flexible pair is one Claude worker plus one Qwen Code worker**
   (`--agent qwen-code`). If the coordinator is Claude, substitute Codex for the
   Claude slot, keeping the pair cross-family. Codex is added as a third worker
   only under rule 2's exceptions or when Qwen Code fails its readiness check.
4. **Bulk goes to Qwen Code.** For three or more flexible slots, give the
   additional slots beyond the default pair to Qwen Code — it is unmetered, so
   extra workers there cost nothing but endpoint concurrency. Broad exploration,
   file sweeps, repeated independent evaluations of one question, and any
   fan-out whose width is a judgment call all belong here.
5. **Decompose before Qwen fan-out.** Do not hand one Qwen worker a large,
   cross-repository, or context-heavy assignment merely because its usage is
   unmetered. In the default mixed-provider workflow, give Claude the planning
   pass first: establish interfaces and dependencies, then split the work into
   small independent Qwen tasks. Each Qwen task should normally cover one
   concrete question, one repository or subsystem, and a bounded file set with
   only the verified evidence it needs. Dispatch those microtasks in waves up
   to healthy endpoint concurrency, and have Claude or the coordinator review
   their outputs before integration. Unmetered usage permits width and retries;
   it does not justify oversized prompts or duplicated work.
6. **Reserve the metered families for judgment.** Claude and Codex slots go to
   the highest-value role in the wave — independent review of another worker's
   output, adjudicating a disagreement, or the synthesis input the coordinator
   will lean on hardest. Do not spend a metered slot on work rule 4 covers.
7. **Escalate rather than widen on a tie.** When two workers disagree and the
   answer matters, add one metered worker as an independent tiebreaker instead
   of adding more Qwen Code workers. Unmetered width does not settle a
   disagreement that is about judgment.
8. **Degrade explicitly, never silently.** If Qwen Code fails readiness, report
   it and fall back to a metered family for that slot. If a metered family is
   critical, queue its slots and tell the user the reset timing. Never quietly
   swap one family for another or drop a slot.

### Balance provider quotas before flexible dispatch

Before choosing agent families for a new wave, run `orca account list --json`
and inspect `result.rateLimits`. Use the live provider `status`, short-window
usage (`session`), long-window usage (`weekly` or `monthly`), reset time, and
reset credits when present. Recheck before a later wave if the run is long or a
provider has crossed a threshold; do not poll usage while workers are already
running.

Qwen Code runs against a self-hosted endpoint and has no entry in
`result.rateLimits`. Do not treat that absence as `unknown` and do not apply the
constrained/critical thresholds to it — those thresholds describe metered
provider quotas that do not exist here. Qwen Code is capacity-bound, not
quota-bound: its limit is the concurrency of the serving endpoint, so treat it
as healthy whenever a readiness check succeeds and as unavailable when the check
fails. Verify readiness before a wave with a single `GET <baseUrl>/models`
against the endpoint in `~/.qwen/settings.json`; a `200` with the configured
model id present means healthy. Never print the API key. Because Qwen Code
carries no quota cost, prefer it for bulk exploration when a metered provider is
constrained, and reserve the metered providers for the highest-value independent
review or synthesis role.

For each available usage window, calculate:

- `remaining_usage = 100 - usedPercent`
- `remaining_time = clamp((resetsAt - now) / windowMinutes, 0, 1) * 100`
- `headroom = remaining_usage / max(remaining_time, 1)`

Use the lowest headroom across the provider's reported windows as its limiting
headroom. Treat missing windows as unknown, not as unlimited. Treat a provider
as constrained when `usedPercent >= 75`, limiting headroom is below `0.8`, or
the provider reports an error. Treat it as critical when `usedPercent >= 90`,
limiting headroom is below `0.5`, or `status` is unavailable.

Apply quota information only after task requirements:

1. Preserve any user-specified family and count exactly. Report a critical or
   unavailable requested provider instead of silently substituting it.
2. Preserve a required cross-family comparison when independent model-family
   diversity materially affects confidence, unless one family is unavailable.
3. For interchangeable or additional workers, prefer the healthy provider with
   the larger limiting headroom. For three or more flexible slots, distribute
   the extra slots approximately in proportion to limiting headroom, using
   largest-remainder rounding and at least one slot for each non-critical family
   selected for diversity.
4. If one provider is constrained and the other is healthy, reserve the
   constrained provider for the highest-value independent review or synthesis
   role and send bulk exploration to the healthier provider.
5. Never reduce required verification, silently change model family, or claim
   a quota value that was not returned by Orca. If all suitable providers are
   critical, queue the remaining wave and tell the user the reset timing.

Record the quota snapshot used for the decision in coordinator notes, but keep
user updates concise and do not expose account identifiers or credentials.

### Size the worker pool

When the user specifies the worker pool:

- preserve the exact count and agent family for Claude, Codex, or any other
  agent supported by the installed Orca runtime;
- treat the coordinator as separate from the requested worker count unless the
  user says otherwise;
- if available concurrency is lower than the requested count, create the full
  task graph and dispatch it in waves as slots become available; do not silently
  reduce the pool;
- report an unsupported agent type or hard runtime limit instead of replacing
  it with another model.

When the user does not specify the worker pool:

1. Identify independent work units and dependency edges.
2. Use one worker per useful independent unit, bounded by the runtime's
   available concurrency.
3. Use at least two workers when parallel execution was explicitly requested.
4. For one indivisible question, use multiple independent evaluations rather
   than inventing fake subtopics.
5. Choose the families with the summoning rules above. Do not require a 1:1
   ratio between families.
6. Do not create workers with no distinct assignment or evaluation role.

### Launch Qwen Code workers

Launch Qwen Code through the Orca agent id `qwen-code`, for example
`orca worktree create --repo <selector> --name <name> --agent qwen-code --json`.
Read the handle from `result.agentTerminalHandle`. Do not launch it by shelling
out to the `qwen` binary directly; an untracked terminal cannot be supervised.

Qwen Code has no `--auto` equivalent on the command line. Non-interactive
permission approval is a persisted setting, so confirm before the wave that
`~/.qwen/settings.json` contains `"tools": { "approvalMode": "yolo" }`, or that
the launched TUI reports YOLO mode. The user has explicitly chosen
non-interactive approval for these workers. YOLO removes approval prompts; it
does not expand the task's authorization, repository scope, destructive-action
rules, or external-write permissions.

`orca terminal send` does not submit on its own — always pass `--enter`, or the
prompt sits unsent in the input box and the worker looks idle while having
received nothing. `orca terminal wait --for` accepts only `exit` and `tui-idle`;
use `tui-idle` to wait out a Qwen Code turn.

Accept a Qwen Code worker as supervised only when Orca returns a live Dispatch
in `ready` state and later accepts its lifecycle messages. If Orca returns
`agent_prompt_stalled` while the TUI nevertheless starts working, the terminal
is advisory and untracked: do not count it toward the required supervised pool
or claim its `worker_done` was accepted. For read-only evaluation, its artifact
may be used if independently inspected and labeled as untracked. For any writer,
stop and release the failed Dispatch before replacement so two editors cannot
race.

The current session is the master unless the user requests a separate master.
When a separate master is requested, create a dedicated synthesis task whose
dependencies include all required worker and review tasks. The current session
still supervises the run and verifies the dedicated master's final artifact.

### Decompose

Use for a task with clearly independent parts. Give each worker exclusive
ownership of a bounded subtask, then have the coordinator integrate the
results.

When Qwen Code participates in a large task, make decomposition a dependency,
not an informal suggestion. In the default mixed-provider topology, a Claude
planning task should produce the task boundaries, required evidence, dependency
edges, and acceptance criteria before Qwen tasks are dispatched. Keep each Qwen
prompt self-contained and small; do not make every worker rediscover the whole
project. If decomposition reveals a genuinely indivisible high-context problem,
keep that problem with Claude, Codex, or the coordinator and use Qwen only for
bounded supporting checks.

Examples: architecture and test audits; unrelated feature investigations;
documentation and code analysis.

### Independent comparison

Use for audits, prioritization, debugging hypotheses, design decisions, or
requests for consensus. Give the same evidence and evaluation rubric to every
independent evaluator without showing any evaluator the others' conclusions.

The current session remains the master and does not publish its own conclusion
until all required independent reports arrive.

### Implement and verify

Use when the user authorizes code changes. Partition writers by non-overlapping
module or file ownership and assign remaining workers to read-only research,
testing, or review roles. A reviewer examines the relevant diff and validation
evidence only after its writer dependencies complete.

Do not let multiple workers concurrently edit the same files in one worktree.
For genuinely independent implementations, use isolated Orca worktrees and
explicit file or module ownership, then let the master select and integrate the
result. Never auto-merge competing implementations.

### Cross-review

Add one tracked cross-review round when the user asks agents to discuss,
critique, agree, or reach consensus, or when a high-impact decision materially
benefits from adversarial review.

After all initial tasks complete, build a bounded review graph:

- With two workers, use reciprocal review.
- With three to six workers, use a ring or balanced assignment so every report
  receives at least one independent review. Prefer cross-family review when
  multiple agent families are present.
- With more than six workers, group related outputs and assign designated
  reviewers per group. Do not create an all-to-all `N²` review graph unless the
  user explicitly requests it.
- Give each reviewer only the completed reports needed for its assignment.
- Ask reviewers to identify supported agreements, weak claims, missing
  evidence, and priority changes.
- End after one review round unless a concrete unresolved question justifies
  another.

Do not use open-ended agent conversation. It obscures ownership and can loop.

### Pull-request review

Before creating any PR-review task, read and follow the user-level
`review-pr-with-intent` skill completely. Resolve its absolute `SKILL.md` path
and include that path as a mandatory prerequisite in every Claude, Codex, or
other worker task; never assume a fresh worker will discover the skill
implicitly.

For every PR, assign at least one Claude and one Codex worker to independently
review the verified base-to-head diff. Each task must also embed the intent-aware
core contract: read the entire live PR body, commits, comments/reviews, linked
tickets and predecessor/successor/stacked PRs; produce the complete intent
ledger before findings; do not classify verified follow-up scope as a current
blocker; turn unclear intent or merge order into an author question.

Reject reports that omit the intent ledger or fail to verify declared deferrals.
After both valid reports arrive, run a tracked reciprocal cross-review for that
same PR. The coordinator may publish only the in-scope finding set supported by
this process. Preserve the pair and consensus round separately for every PR in
a multi-PR request.

## Build worker tasks

Create a separate orchestration task and dispatch for each assignment. Every
task specification must contain:

- role and objective;
- exact scope and inputs;
- whether it is read-only or may write;
- exclusions and ownership boundaries;
- required project skills and repository rules;
- evidence requirements, including file paths and line numbers for code claims;
- acceptance criteria and validation commands;
- a compact output schema;
- instruction to ask or escalate when genuinely blocked;
- the result-delivery protocol below, including strict message-size limits;
- instruction to send `worker_done` exactly once with the active task and
  dispatch identifiers.

Do not allow workers to spawn more workers unless the task explicitly requires
nested decomposition.

For comparison tasks, use the same core prompt and scoring rubric. Do not leak
the other worker's findings before the cross-review phase.

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

## Dispatch and supervise

1. Create or select the exact number of dedicated fresh worker terminals for
   the requested or derived agent pool.
2. Wait until each terminal is ready before injection.
3. Dispatch all dependency-free tasks as one parallel wave.
4. Verify that every worker actually started the assigned task; a created
   terminal, accepted dispatch, `ready`, `running`, heartbeat, or copied task
   text alone is not proof of useful work.
5. Wait on orchestration deliveries using the rolling coordinator loop from the
   installed guide while also checking worker progress as described below.
6. Treat a wait timeout as "no new message", not as worker failure.
7. Accept completion only through a valid `worker_done` from the worker that
   owns the active dispatch.
8. Handle questions and escalations promptly. Create a decision gate only when
   a user choice would materially change scope, risk, or outcome.
9. Dispatch dependent review or integration tasks only after their prerequisites
   are complete.

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
settled and released/reused, or explicitly blocked/recovered.

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

Do not reset an active orchestration run, close worker terminals, delete
worktrees, or discard worker artifacts merely to tidy up. Preserve them until
the coordinated result has been delivered or the user requests cleanup.

## Synthesize as master

Inspect the actual worker outputs and relevant artifacts; do not summarize from
terminal status alone.

For decomposed work, integrate the non-overlapping results and resolve interface
gaps. For independent comparison or cross-review, classify findings as:

- **agreement**: independently found by multiple workers, or proposed by one and
  validated with evidence by assigned reviewers;
- **partial agreement**: the problem is accepted but priority or solution
  differs;
- **unique supported finding**: raised by one worker with sufficient evidence;
- **unresolved**: evidence is missing or a user/product decision is required.

Never manufacture consensus by majority vote. Prefer source evidence, runnable
validation, project constraints, and explicit trade-offs.

Return one concise master report containing:

1. topology and worker assignments;
2. final answer or completed changes;
3. agreements and material disagreements;
4. evidence and validation performed;
5. unresolved decisions or follow-up work.

Do not paste full worker transcripts unless the user asks for them.
Do not expose raw report artifacts or long orchestration message bodies merely
because they were delivered to the coordinator.

## Example triggers

- "이 프로젝트 개선점을 Claude와 Codex에게 병렬로 분석시키고 종합해."
- "두 워커가 독립적으로 원인을 찾고 서로 검토하게 해."
- "마스터 하나 두고 서브 워커 둘로 이 작업 진행해."
- "Codex 세 개, Claude 두 개를 띄워서 영역별로 조사하고 마스터가 종합해."
- "작업을 모듈별로 나눠서 병렬 구현하고 마지막에 검증해."
