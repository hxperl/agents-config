# Running Qwen Code workers

Loaded when a wave includes a Qwen Code worker. How to launch one through Orca, what counts as a supervised dispatch, and how to write a brief small enough for it.

### Launch Qwen Code workers

Launch Qwen Code through the Orca agent id `qwen-code`, for example
`orca worktree create --repo <selector> --name <name> --agent qwen-code --json`.
Read the handle from `result.agentTerminalHandle`. Do not launch it by shelling
out to the `qwen` binary directly; an untracked terminal cannot be supervised.
Do not pass `--model` or `--effort`; those launch overrides are for Claude and
Codex, while Qwen Code uses the model configured by its endpoint.

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

**Read liveness from the terminal's last line.** A stale spinner in scrollback
does not prove the process is live. A live worker shows the Qwen prompt bar; an
exited worker shows a shell prompt and may print
`To continue this session, run qwen --resume <session-id>`.

**Recover a crashed Qwen session when its context is still useful.** Send the
exact printed `qwen --resume <session-id>` command with `--enter`, wait for the
prompt, then send one short instruction describing the remaining work.

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

### Turn thinking off — it buys nothing on the work Qwen is given

The `qwen3.8-27b` checkpoint reads its thinking controls **inside**
`chat_template_kwargs`; a top-level key is ignored by its chat template
(documented at `base_agent/app/services/openrouter_agent.py:118-127`). Two
mutually exclusive knobs, and the checkpoint's default is `xhigh`:

```json
"generationConfig": {
  "extra_body": { "chat_template_kwargs": { "enable_thinking": false } }
}
```

Measured 2026-09-16, one prompt with a known-correct answer, three runs per
arm, order reversed between passes:

| `extra_body` | completion tokens | reasoning block | accuracy |
|---|---|---|---|
| `{"enable_thinking": true}` (top level) | 320–322 | 1284–1290 chars | 8/8 |
| omitted entirely | 320 | 1284 chars | 8/8 |
| `chat_template_kwargs.enable_thinking: false` | **30** | **0** | 8/8 |
| `chat_template_kwargs.reasoning_effort: "low"` | 349 | 1265–1280 chars | 8/8 |

Three conclusions, and the first two are the ones that change behaviour:

- **A top-level `enable_thinking` is a no-op.** The first two rows are
  token-identical, so a config that looks like it disables thinking leaves the
  checkpoint at `xhigh`. Check the key path, not just the key.
- **`reasoning_effort: "low"` is not "off".** It still emits a full reasoning
  block. Only `enable_thinking: false` removes it.
- **Thinking bought no accuracy** on mechanical transcription — every arm
  scored 8/8 — while costing about 10x the completion tokens.

End to end this is the difference between unusable and usable. With thinking at
the default, three workers on three-file-read tasks produced **nothing in 73
minutes**, each killed by the 15-minute stream cap
(`QWEN_STREAM_MAX_LIFETIME_MS`, default `900000`) mid-thinking. With it off, the
same shape of task finished in **9 minutes** with a correct report and a clean
`worker_done`.

Latency is not the signal to judge this by: the same arm measured 177s, 12s and
58s across three runs. Compare **completion tokens**, which are stable.

### Measured 2026-09-17 — after the endpoint speedup, against a metered baseline

Same single-file transcription brief (verbatim, no line numbers) given to Qwen
Code and to Codex `gpt-5.6-luna` at `low` effort, graded against source:

| | Codex luna · low | Qwen Code (thinking off) |
|---|---|---|
| wall time to `worker_done` | 63 s | 88 s |
| enum values, incl. a decoy literal from another table | 5/5, decoy avoided | 5/5, decoy avoided |
| "not in this file" answer | correct | correct |
| signatures verbatim | correct | correct |
| SQL statements verbatim | 4/4 | 3/4 — read "UPDATE" as the intent table only |
| fabrication · line numbers | 0 · 0 | 0 · 0 |

A second Qwen task over a 2,200-line file finished in about 2.5 minutes, 7/7
correct with no false positives — and it **rejected a false premise in the
brief** (the brief said the functions were module-level; they were class
methods) instead of inventing matches. It also caught a method a coordinator
grep had missed, because the R2 call went through a helper with a different
name.

Against 2026-09-16 on comparable single-file work: 9 minutes → 88 seconds, and
from 17 fabricated citations to none. The citation fix came from the brief,
not the model — Qwen was simply not asked for line numbers.

What this changes: Qwen Code is now within a factor of about 1.4 of the cheapest
metered arm on this shape of work, while costing nothing. The earlier rule
"time-boxed mechanical work goes to Haiku or Luna" (model-and-effort.md §6)
applies only when the endpoint is back at its old speed — measure with one small
task before assuming either. Scope words in the brief still need to be exact:
Qwen's one miss was a reasonable but narrower reading of "UPDATE".

n=1 per arm. Treat as a data point, not a benchmark.

### Never ask Qwen Code for line numbers

Ask for the **verbatim text** and derive the line numbers in the coordinator.

Measured on the 9-minute run above: the content was perfect — 12 of 12 named
CHECK constraints, every condition transcribed correctly, 5 of 5 indexes, the
"no unique index" answer right, nothing fabricated — and **all 17 `file:line`
citations were wrong**, off by +17, +17, +10 and +8. A non-constant offset means
they were estimated rather than read.

That combination is the dangerous one: the content survives review, so the
citations are trusted, and a wrong line then propagates into whatever cites the
report. Verbatim text does not have this failure mode — `grep` confirms or
refutes it in one command, which is exactly why the brief should demand it.

### Write a bounded Qwen Code brief

- Keep the brief compact: use commands and acceptance criteria instead of long
  explanations or examples.
- Give it one vetted target, one repository or subsystem, and a bounded file
  set. Do the selection and decomposition in the coordinator.
- State what counts as done, allow `not found`, and enforce a wall-clock budget.
  At the deadline, ask it once to finish with the strongest evidence already
  collected. If that Dispatch message stays unread because one long TUI turn is
  still running, send the same one-line stop instruction once through
  `orca terminal send --enter`; do not resend the task brief.
- Always name the absolute working directory and prohibit writes outside the
  authorized path.
