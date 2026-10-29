---
name: parallel-worker-orchestration
description: >-
  Coordinate a user request through a dynamically sized pool of supervised Orca
  workers, including any requested mix such as three Codex workers and two
  Claude workers, then collect and synthesize their results. Use when the user
  asks to run work in parallel, delegate to multiple workers or agents, have
  Claude, Codex, and Gemini independently investigate or implement
  something, make agents review or debate each other's results, or use a
  master/coordinator to reach a consensus — in any language, and whether the
  ask names the families and counts explicitly or only says "split this up".
  Do not trigger for an ordinary single-agent task merely because it could
  theoretically be parallelized.
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

The worker families on this machine (user decision, 2026-10-19, after measuring
Argon's quota):

- **Claude** (`--agent claude`) and **Codex** (`--agent codex`, `gpt-6.1-sol`)
  are the default judgment pair. The Codex subscription ends **2026-11-16**.
  From that date Codex is unavailable: say so instead of launching it.
- **Gemini 3.8 Flash** (`--agent antigravity --model
  gemini-3.8-flash-<low|medium|high>`) does fact collection, replacing Qwen.
  It draws on Antigravity's 5-hour-refreshed Gemini bucket.
- **Gemini 4 Argon High** (`--agent antigravity --model gemini-4-argon-high`)
  is a **scarce tiebreaker**. Its Pro quota is weekly-only with no 5-hour
  refresh, and one research task consumed 14% of it (2026-10-19). Use it only:
  - when Claude and Codex disagree on a point that matters;
  - after 2026-11-16, as the second judgment voice on high-stakes reviews
    (pre-prod, design decisions). Otherwise, judgment is Claude alone plus
    Flash evidence.
- **Qwen Code is parked** (2026-10-19) while its workstation is being upgraded.
  Launch it only when the user names it. When the user brings it back, restore
  `references/qwen-execution.md` and `qwen-verifier-loop.md` from
  `~/.claude/skills-backup/qwen-parked-20261019/` (also in this repo's git history before the 2026-10-19 commit), re-measure it, and decide
  with the user how it shares fact collection with Flash.
- Antigravity also serves Claude 5.5 models and `gpt-oss-120b`. Never pick
  them: the Claude models duplicate our Claude family, and `gpt-oss-120b` is
  not GPT-6.1 Sol and does not replace Codex.

1. **An explicit request wins outright.** A named family or count is preserved
   exactly. If a requested family is unavailable, say so and stop; never
   substitute a different one.
2. **Never spawn the coordinator's own family for diversity alone.** Diversity
   means a family the coordinator is not. Add a same-family worker only when
   the user asks for it or same-family replication is itself the point. When
   the coordinator is Claude, the judgment slot is Codex (until 2026-11-16),
   and the coordinator's own synthesis is the second view.
3. **The default flexible pool is one Claude worker plus one Codex worker for
   judgment, plus Gemini 3.8 Flash workers for any separable fact
   collection.** After 2026-11-16 it is one Claude worker plus Flash. The coordinator is outside this count. Never invent duplicate
   work merely to fill a slot.
4. **Bulk goes to Gemini 3.8 Flash.** Additional flexible slots for broad
   exploration, file sweeps, and fan-out whose width is a judgment call go to
   Flash. It is fast and has high throughput, but it is still metered against
   the Antigravity Gemini bucket: check that bucket per wave.
5. **Decompose before Flash fan-out.** Give each Flash worker one concrete
   question, one repository or subsystem, a bounded file set, and only the
   verified evidence it needs. The coordinator or a judgment worker sets the
   boundaries and acceptance criteria first and reviews Flash output before it
   is integrated.
6. **Reserve the judgment families for judgment.** Claude, Codex and Argon
   slots go to the highest-value role in the wave — independent review,
   adjudication, or the synthesis input the coordinator leans on hardest. Do
   not spend one on work rule 4 covers.
7. **Escalate rather than widen on a tie.** When Claude and Codex disagree and
   the answer matters, add one Gemini 4 Argon High worker as the independent
   tiebreaker. Check the Argon bucket first; if it is low, re-run the weaker
   side once at a higher effort and put the remaining split to the user. More
   Flash workers do not settle a disagreement about judgment.
8. **Degrade explicitly, never silently.** If a family fails readiness or its
   bucket is critical, report it, then fall back to another family for that
   slot and say so. Never quietly swap a family or drop a slot.

### Route by the kind of work

Decide what kind of answer the task needs before choosing a provider. The
distinction is whether the output is a **fact** or a **decision**.

**Gemini 3.8 Flash — facts, by default.** Work whose result can be checked by
looking:

- enumerating or counting call sites, and reconciling two workers' differing counts
- grepping a specific claim to confirm or refute it
- reading a model, migration, or config and transcribing its columns, constraints,
  or keys verbatim
- checking whether a function has production callers, as opposed to definitions
  and tests only
- collecting `file:line` citations for a list that someone else will judge
- inventorying what exists: routes, indexes, fixtures, feature flags

Ask for citations and an explicit "not found" when it cannot find something.
Do not ask it to choose between options, and never let an uncited claim from it
into a conclusion.

**Claude and Codex (Argon as tiebreaker) — decisions.** Work whose result is a judgment:

- adjudicating a design trade-off, or two safe-but-different architectures
- deciding whether to reverse an earlier judgment
- choosing transaction boundaries, failure semantics, or concurrency guarantees
- reviewing whether a change is correct in intent rather than in form
- weighing evidence that two workers disagreed about

When a Flash result is the basis for one of these, Flash supplies the evidence
and the call stays with the coordinator or a judgment worker.

**Then pick the model and the effort, on the same axis.** Family is only half
the routing decision; omitting `--model`/`--effort` is a choice, not a neutral
default. Fact collection: Gemini 3.8 Flash `low`/`medium` (`high` for careful
tracing). Flash scores ~20% on Terminal-Bench 4.0, so keep it on narrow,
checkable tasks, never open-ended agentic work. Ordinary implementation and
single-dimension review: Sonnet 5.5 or `gpt-6.1-sol` at `medium`. Adversarial
review or adjudication: Opus 5.5 at `high`/`xhigh` and `gpt-6.1-sol` at
`high`/`xhigh`; tiebreak with `gemini-4-argon-high`. Fable 5.1 is a narrative
specialist, not the reviewer.

**Codex slots run on `gpt-6.1-sol`, not Astra** (user, 2026-10-01). Raise Sol's
effort before reaching for Astra; use `gpt-6-astra` only on request.

**Availability is measured, never inferred from a help string.** Usable here:
`claude`, `antigravity` (verified end to end through `worker-start` on
2026-10-19 with `gemini-3.8-flash-medium`), and `codex` until 2026-11-16. List
Antigravity's models with `agy models`. Confirm per wave with `orca account
list --json`: Antigravity reports separate buckets for Gemini models, Gemini 4
Argon, and Claude/GPT models. Read the Gemini bucket before a Flash fan-out,
and the Argon bucket before any Argon slot. Report an unavailable family
rather than substituting another.

`references/model-and-effort.md` has the Claude and Codex per-model tiers,
effort ladders, and misrouting traps. Its Qwen rows apply only while Qwen is parked-and-restored.

**State output constraints explicitly.** For bounded templates, fixed section
order, or hard length limits, spell out every constraint in the brief and
validate the result before using it.

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

When Flash workers participate in a large task, make decomposition a dependency,
not an informal suggestion: the coordinator or a judgment worker produces the
task boundaries, required evidence, dependency edges, and acceptance criteria
first. Keep each Flash prompt self-contained and small. A genuinely indivisible
high-context problem stays with a judgment worker or the coordinator.

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
   the requested or derived agent pool. **The launch path depends on the
   Orca version** (`orca --version`; `references/model-and-effort.md` §1.1):
   on `1.4.218`+ use `worker-start` for claude, codex and antigravity
   (antigravity measured 2026-10-19). Only below `1.4.217` does codex need
   the low-level `terminal create` + `dispatch --inject` path. After a Codex
   `worker-start`, read the screen for its update menu (enaible/AGENTS.md).
2. Wait until each terminal is ready before injection — by reading its screen
   for the composer, not with `terminal wait --for tui-idle`, which times out
   on a ready codex TUI.
3. Dispatch all dependency-free tasks as one parallel wave.
4. Verify that every worker actually started the assigned task; a created
   terminal, accepted dispatch, `ready`, `running`, heartbeat, or copied task
   text alone is not proof of useful work.
5. Wait on orchestration deliveries using the rolling coordinator loop from the
   installed guide while also checking worker progress as described in
   `references/supervision.md`. A watcher that only waits for `worker_done` or
   polls outcomes misses stuck workers (2026-10-23: Codex sat on `Selected
   model is at capacity` while reporting `working`/`live`). Every rolling check
   reads each live worker's transcript or screen, and the background monitor
   also emits on inactivity and on provider-error text.
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
| launch any worker (which path works per agent), pick its model or effort, or check which agents exist here | `references/model-and-effort.md` |
| dispatch, and for as long as any worker is live | `references/supervision.md` |
| set up cross-review, or review a pull request | `references/review-topologies.md` |

`references/supervision.md` is not optional for a run that dispatches anything: it
carries the startup-proof, stall-detection, completion-audit, and message-size rules,
and a run that skips it reports workers as working or complete without evidence.
