---
name: opencode-go-only-orchestration
description: Coordinate parallel or multi-agent work using only OpenCode Go models when the user explicitly requests an OpenCode-only pool or Claude and Codex workers are unavailable. Select models by task risk and Go quota economics, launch every worker with auto-approval, supervise real terminals, and synthesize one result. Do not use for an ordinary mixed-provider request.
---

# OpenCode Go Only Orchestration

Use OpenCode Go for every worker and, when a separate synthesizer is needed,
for that synthesizer too. The invoking agent may remain a thin launcher and
supervisor, but must not substitute Claude or Codex work into the result.

## Mandatory startup

1. Read the installed `orca-cli` skill before Orca terminal actions. Read the
   installed `orchestration` skill as well when using Tasks or Dispatches.
2. Confirm the runtime with `orca status --json`.
3. Verify OpenCode without exposing credentials:
   `opencode --version`, `opencode auth list`, then `opencode models`.
4. Keep only live `opencode-go/*` model IDs. Catalog presence proves discovery,
   not invocation readiness. Before assigning required work, make one bounded,
   non-mutating probe or require the first worker to reach task-specific work.
   If a provider requires a regional-hosting or data-use opt-in, mark that
   model unavailable, report the recovery URL, and never opt in automatically.
5. Inspect `orca account list --json`. An unavailable OpenCode Go web-cookie
   probe does not disprove CLI API authentication; it makes quota headroom
   unknown, not unlimited.
6. Read [references/model-routing.md](references/model-routing.md), refresh the
   official Go limits, classify the tasks, and announce the selected pool.

If OpenCode Go is not authenticated or no suitable live model exists, stop and
report the exact blocker. Do not silently launch Claude, Codex, a free model, or
another paid provider.

## Authorization and privacy

Launch every OpenCode process with `--auto`:

```text
opencode --auto --model opencode-go/<model-id>
```

`--auto` auto-approves permissions that are not explicitly denied. The user has
chosen this launch behavior for OpenCode workers, but it does not expand the
requested scope, authorize destructive actions, permit external writes, or
override repository rules.

Do not route private repository content to a model whose current Go privacy
terms allow model training, including `muse-spark-1.2-contributor` at the
2026-08-26 baseline, unless the user explicitly accepts that data use after the
current terms are shown.

## Build the pool

Honor an explicit count and model selection. Otherwise:

- Use at least two different model families for an independent comparison.
- Give each worker a bounded, distinct role; do not create duplicate workers
  merely to increase the count.
- For implementation, use one writer and a different-family reviewer. Two
  writers must not edit the same files concurrently.
- Use a dedicated OpenCode synthesizer only when synthesis is substantial or
  the user requested a fully separate master. The launcher otherwise performs
  mechanical collection while preserving the OpenCode reports as the source
  of conclusions.
- Keep dependency chains to three waves when possible: explore, implement or
  evaluate, then review/synthesize.

Useful defaults:

- Read-only pair: `minimax-m3` + `hy3`; substitute
  `deepseek-v4-flash` only after a successful readiness probe.
- Implementation pair: `kimi-k2.7-code` writer + `glm-5.2` reviewer.
- Wide investigation: `hy3` scouts, `minimax-m3` analyst, `glm-5.2`
  adjudicator.
- Premium final oracle: one `kimi-k3`, never broad fan-out.

## Launch mode

### Preferred: live Orca Dispatch

Use `orca orchestration worker-start --agent opencode` only when the installed
Orca guide supports it. Supply the selected model through a supported launcher
or create the exact OpenCode terminal command with `--auto`. Accept the worker
as supervised only when the command returns `state: ready`, `worker-show`
confirms the exact terminal, and lifecycle messages are accepted.

### Compatibility: terminal-supervised OpenCode

Current Orca builds may inject the task successfully but return
`agent_prompt_stalled`, then revoke the Dispatch. A visible working TUI does not
repair that Dispatch. When exact Orca lifecycle is not a user requirement, use
this bounded compatibility mode and label it terminal-supervised:

1. Create one fresh terminal per worker with
   `orca terminal create --command "opencode --auto --model
   opencode-go/<model-id>" --json`.
2. Wait for `tui-idle` with an explicit timeout, then send the bounded task once
   with `orca terminal send --text ... --enter --json`.
3. Within about 60 seconds, read a bounded transcript and require fresh,
   task-specific reasoning or tool use. If the task is only in the input editor,
   send Enter once; do not reinject the full prompt.
4. Ask the worker to write long findings to a unique UTF-8 Markdown file under
   `/tmp`, then finish with a short summary containing the exact path.
5. Track the terminal handle, cursor, selected model, and role as coordinator
   state. Recheck useful progress every 2-5 minutes.
6. Completion requires the final response plus any promised artifact and an
   idle or exited terminal. Inspect the artifact directly; an idle prompt alone
   is not completion.
7. Close the exact worker terminal after its artifact is collected, unless the
   user explicitly asks to retain it.

Do not describe compatibility-mode workers as Orca-Dispatch-supervised, and do
not accept their attempted `worker_done` as valid if Orca rejects it. If the
user requires durable Task/Dispatch provenance, stop instead of using this
fallback.

## Task contract

Every worker prompt must include:

- role and objective;
- exact scope, inputs, and exclusions;
- read-only or write authorization;
- repository freshness and project rules when code is involved;
- evidence and validation requirements;
- owned files or modules for a writer;
- output artifact path and concise final-response format;
- instruction not to spawn more agents unless explicitly assigned that role.

For a read-only assignment, explicitly permit only non-mutating inspection and
the requested `/tmp` report write. State that repository edits, external posts,
destructive commands, and configuration or account changes are out of scope.
`--auto` removes interactive approval prompts; this task contract remains the
behavioral authorization boundary.

For repository work, fetch relevant remotes with pruning and establish current
refs before dispatch. Put the verified refs in every task. Independent workers
must use the same verified baseline or intentionally independent live sources.

## Supervise and recover

- Say `launched` until task-specific work is visible, `working` only with fresh
  evidence, and `complete` only after artifact inspection.
- A timeout means no new evidence, not failure.
- After two checkpoints with no cursor advance or task-specific progress, send
  one concise follow-up. Do not blindly duplicate the task.
- If a writer exits or stalls after edits, inspect the shared worktree before
  replacement and assign a conflict-free owner.
- Never claim provider quota values that were not returned by Orca or the live
  Go console. Missing data remains unknown.
- If all suitable models are quota-constrained, reduce fan-out or queue the next
  wave; never downgrade consequential work to an unverified free model without
  telling the user.

## Synthesize

Compare evidence rather than voting. Classify results as agreement, partial
agreement, unique supported finding, or unresolved. Resolve disagreements with
source quality, reproducible validation, and task constraints.

Return one result containing the selected topology, model-to-role assignments,
material agreements and disagreements, validation, quota caveats, and any
unresolved decision. Do not paste full transcripts.
