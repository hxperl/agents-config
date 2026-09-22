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

For read-only repository work, the user's current worktree and index are an
immutable evidence source. Workers must never run `git checkout`, `git switch`,
`git reset`, `git restore`, or `git stash` there. Put exact-head inspection and
tests in a unique isolated Orca worktree or a `/tmp` tree created with
`git archive`. Capture `git status --porcelain=v1` before dispatch and audit it
after every worker. If a worker mutates the current worktree, stop it, discard
its result, restore only worker-created changes, and rerun the task in
isolation.

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

### Route by the kind of work

Decide what kind of answer the task needs before choosing a provider. The
distinction is whether the output is a **fact** or a **decision**.

**Qwen Code — facts, by default.** Work whose result can be checked by looking:

- enumerating or counting call sites, and reconciling two workers' differing counts
- grepping a specific claim to confirm or refute it
- reading a model, migration, or config and transcribing its columns, constraints,
  or keys verbatim
- checking whether a function has production callers, as opposed to definitions
  and tests only
- collecting `file:line` citations for a list that someone else will judge
- inventorying what exists: routes, indexes, fixtures, feature flags

Ask for citations and an explicit "not found" when it cannot find something.
Never ask it to choose between options, and never let an uncited claim from it
into a conclusion.

**Claude and Codex — decisions.** Work whose result is a judgment:

- adjudicating a design trade-off, or two safe-but-different architectures
- deciding whether to reverse an earlier judgment
- choosing transaction boundaries, failure semantics, or concurrency guarantees
- reviewing whether a change is correct in intent rather than in form
- weighing evidence that two workers disagreed about

When a Qwen Code result will be the basis for one of these, let Qwen Code supply
the evidence and make the call in the coordinator or on a metered worker. Do not
delegate the call itself.

**Accept the slower wall clock.** A mechanical task finishing later on Qwen Code
is the preferred trade against spending metered capacity on it. Say so in the
progress report rather than silently upgrading the task to a metered provider.

**Then pick the model and the effort, on the same axis.** Family is only half
the routing decision. A fresh Claude or Codex worker takes `--model` and `--effort`,
and omitting them is a choice rather than a neutral default: the local defaults
are `gpt-5.6-sol` at **high** for Codex and Opus 5 at **medium** for Claude, so
a bare launch is the flagship in one family and mid-effort in the other. Send
fact-collection to Haiku 4.5 or Luna at `low`, ordinary implementation and
single-dimension review to Sonnet 5 or Terra at `medium`, and adversarial
review or adjudication to Opus 5 or Sol at `high`/`xhigh`. Fable 5.1 is a
narrative specialist, not the reviewer, however capable it is.

Qwen Code is the exception: launch it with `--agent qwen-code` only. Never pass
`--model` or `--effort` to a Qwen Code worker; its endpoint owns the model
selection.

**Availability is measured, never inferred from a help string.** Only `claude`,
`codex` and `qwen-code` are usable on this machine; `gemini`, `opencode-go`,
`kimi`, `antigravity`, `minimax` and `grok` report `unavailable`, and there is
no Cursor provider at all even though `--model`'s help text names one. Confirm
with `orca account list --json` per wave, and report an unavailable family
rather than substituting another.

`references/model-and-effort.md` has the per-model tiers and prices, both
effort ladders, the routing table, and the misrouting traps — including why
raising effort does not fix a vague brief.

**Prefer Qwen Code when output shape is strict.** It is a good fit for bounded
templates, fixed section order, and hard length limits. State every format
constraint explicitly and validate the result before using it.

**Allow negative results.** Tell the worker that finding nothing is valid and
require it to report `not found` instead of widening the search or inventing a
weak finding.

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

For a Qwen Code writer, start with one normal implementation attempt. If the
coordinator then verifies that the authorized change fails a deterministic
project test, lint, build, or other acceptance command, read and apply
`references/qwen-verifier-loop.md`. This repair loop is Qwen-only and
sequential within one worktree; it does not apply to Claude or Codex, to
read-only fact collection, or to judgment and review tasks. Do not start the
loop for infrastructure failures or failures unrelated to the worker's diff.

Do not let multiple workers concurrently edit the same files in one worktree.
For genuinely independent implementations, use isolated Orca worktrees and
explicit file or module ownership, then let the master select and integrate the
result. Never auto-merge competing implementations.

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
- the result-delivery protocol from `references/supervision.md`, including its
  strict message-size limits;
- instruction to send `worker_done` exactly once with the active task and
  dispatch identifiers.

Do not allow workers to spawn more workers unless the task explicitly requires
nested decomposition.

For comparison tasks, use the same core prompt and scoring rubric. Do not leak
the other worker's findings before the cross-review phase.

## Dispatch and supervise

1. Create or select the exact number of dedicated fresh worker terminals for
   the requested or derived agent pool.
2. Wait until each terminal is ready before injection.
3. Dispatch all dependency-free tasks as one parallel wave.
4. Verify that every worker actually started the assigned task; a created
   terminal, accepted dispatch, `ready`, `running`, heartbeat, or copied task
   text alone is not proof of useful work.
5. Wait on orchestration deliveries using the rolling coordinator loop from the
   installed guide while also checking worker progress as described in
   `references/supervision.md`.
6. Treat a wait timeout as "no new message", not as worker failure.
7. Accept completion only through a valid `worker_done` from the worker that
   owns the active dispatch.
8. Handle questions and escalations promptly. Create a decision gate only when
   a user choice would materially change scope, risk, or outcome.
9. Dispatch dependent review or integration tasks only after their prerequisites
   are complete.
10. After every accepted `worker_done`, immediately choose the terminal's next
    owner. Transfer it to an immediate follow-up Dispatch, explicitly retain it
    only when the user asked to keep it live, or release it before acknowledging
    the Delivery or waiting again. A completed Task does not prove its terminal
    was reclaimed.
11. Before the final answer, inspect the Run's worker resource accounting. Every
    Dispatch must be active for a stated reason, transferred, explicitly
    retained by user request, or released. Do not finish with an unexplained
    reclaimable, release-pending, or release-unknown worker.

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

## References

Read the file that matches what you are about to do. Do not skip one because its
rules sound familiar — each holds requirements this file only names.

| Before you | Read |
|---|---|
| choose agent families for a wave, or check whether a provider has room | `references/quota-and-readiness.md` |
| launch a Qwen Code worker, or write its brief | `references/qwen-execution.md` |
| retry a Qwen Code writer after coordinator-verified validation failure | `references/qwen-verifier-loop.md` |
| launch a fresh metered worker, pick its model or effort, or check which agents exist here | `references/model-and-effort.md` |
| dispatch, and for as long as any worker is live | `references/supervision.md` |
| set up cross-review, or review a pull request | `references/review-topologies.md` |

`references/supervision.md` is not optional for a run that dispatches anything: it
carries the startup-proof, stall-detection, completion-audit, and message-size rules,
and a run that skips it reports workers as working or complete without evidence.
