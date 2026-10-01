# Choosing the model and the reasoning effort for a worker

Loaded when a wave launches a fresh metered worker. SKILL.md routes by
**family** (Qwen Code vs Claude vs Codex); this file is the tier below it for
Claude and Codex — which model inside the family, and how hard it should think.
Qwen Code always launches without `--model` or `--effort`; its endpoint owns
the model selection.

Everything here is either measured on this machine or cited. Re-verify the
availability section before a wave: accounts and defaults change, and a routing
table that has drifted is worse than none.

---

## 1. Which agents actually exist here

Measured 2026-09-16 with `orca account list --json`:

| Agent id | State on this machine |
|---|---|
| `claude` | 1 account, active — launches through `worker-start` (Orca `1.4.216`+) |
| `codex` | authenticated and `ok`; `worker-start` works on Orca `1.4.218` (measured 2026-10-01), low-level dispatch only on builds below `1.4.217` — see §1.1 |
| `qwen-code` | self-hosted endpoint; no account entry by design — see `quota-and-readiness.md` |
| `gemini`, `opencode-go`, `kimi`, `antigravity`, `minimax`, `grok` | present in `rateLimits`, all `unavailable` |
| `cursor` | **not in `rateLimits` at all** |

`worker-start --help` says `--model` "supports Claude, Codex, and Cursor opaque
provider model ids". That describes the **flag**, not this install: there is no
Cursor provider here. Orca's group addresses (`@cursor`, `@gemini`, `@droid`,
`@grok`, `@opencode`) are likewise addressable names, not evidence that an
agent is configured. Never route work to a family on the strength of a help
string — check `orca account list --json` for the wave, and if the user asks
for an unavailable family, say so and stop rather than substituting one.

### 1.1 Which launch path works for which agent

`worker-start` fails at stage `agent_readiness` with `timeout` for **codex and
qwen-code** even though their TUIs come up and sit at the composer. The same
Orca build delivers to those TUIs fine through `dispatch --inject`, so launch
them on the low-level path. Measured 2026-09-29:

| Agent | `worker-start` on `1.4.215` | `worker-start` on `1.4.216` | Low-level dispatch on `1.4.216` |
|---|---|---|---|
| `claude` | `turn_start_unobserved`, brief never landed | **ready → `worker_done` → `completed`** | not needed |
| `codex` | `agent_readiness` timeout | `agent_readiness` timeout | **`worker_done` → `completed`** |
| `qwen-code` | `agent_readiness` timeout | `agent_readiness` timeout | **`worker_done` → `completed`** |

A longer `--timeout-ms` does not help (180 s failed the same way), and neither
does reusing an already-live codex terminal with `--terminal` — the readiness
gate itself never passes. Downgrading does not help either: `1.4.215` fails
codex and qwen identically and also breaks claude.

**Low-level dispatch** — the "custom topology" path in the Orca orchestration
docs, verified end to end for codex and qwen-code:

```bash
orca terminal create --worktree <selector> --title "<role>" \
  --command "codex --dangerously-bypass-approvals-and-sandbox" --json   # or: --command "qwen --yolo"
# handle = result.terminal.handle; read the screen until the composer shows
#   codex: "› Ask Codex to do anything"   qwen: "Type your message or @path/to/file"
orca orchestration task-create --spec "<brief>" --task-title "<title>" --json   # --task-title, not --title
orca orchestration dispatch --task <taskId> --to <handle> --inject --json
```

The injected preamble carries the dispatch capability, so the worker's
`worker_done` is accepted and the Dispatch settles `completed`; `worker-show`,
`worker-release`, and mail all work as usual.

- **Do not gate on `terminal wait --for tui-idle`.** The docs list it as the
  step before `dispatch`, but for codex it timed out at 90 s on a TUI that was
  already at its composer. Read the screen with `orca terminal read` instead.
- `--model` / `--effort` are `worker-start` flags. On this path the model comes
  from the command line you pass (`codex -m <id>`) or the agent's own config.
- **A failed `worker-start` is not free.** The process starts and can call the
  model while Orca never observes the turn. `worker-stop` / `worker-release` it
  immediately rather than leaving the terminal behind — one was found still
  holding a terminal seven hours after dispatch.
- Re-measure after an Orca upgrade: if `worker-start --agent codex` returns
  `ready`, prefer it again and update this table.

**Orca `1.4.217` fixes the Codex side (release notes, 2026-09-29).** The cause
was Orca waiting for a welcome-screen label that Codex `0.158` removed; Orca
now treats Codex's empty composer as ready, and starting with `--model` or
`--effort` no longer hangs (stablyai/orca#23475, #23765). `1.4.218` adds a wait
for Codex `0.157`'s startup screen before the brief is typed (#23745) and a
readiness lane for agents with no other rest signal (#23598).

**Measured on `1.4.218` (2026-10-01), so this is now the default path:**

| Agent | `worker-start` result |
|---|---|
| `codex` (`--model gpt-6.1-sol --effort xhigh`) | `state: ready`, `turnStart: observed`; worked through the brief |
| `claude` (`--model claude-opus-5-5 --effort xhigh`) | `state: ready`, `turnStart: observed` |
| `qwen-code` (no model/effort) | `state: ready`, `turnStart: unsupported` — Orca cannot observe Qwen's turn start, so read the screen for the startup proof; it was working within 40 s |

- Still do the startup proof (`supervision.md`) for every worker.
- The low-level path above remains the fallback for Orca below `1.4.217`, or
  if a `worker-start` ever fails readiness again.
- Each Codex tab now runs its own server by default (#23900, #23929), so
  closing one worker's tab no longer drops the others; many tabs use more
  memory. `ORCA_CODEX_ISOLATE=0` or the Settings → Agents switch restores the
  shared server.

---

## 2. The flags, and the constraints the runtime enforces

```text
--model <id>     Provider model id for a new agent launch
--effort <level> Reasoning effort for the selected model
```

- `--effort` **requires** `--model`. Effort alone is rejected.
- Neither combines with `--terminal`. Reusing an idle agent means accepting the
  model it started with; changing the model means a fresh worker.
- The receipt echoes `launch.requested` and `launch.effective`. **Read
  `launch.effective`**, and name it in the topology announcement and the final
  report. A launch that silently fell back is a different experiment than the
  one the coordinator described, and these two fields are the only place that
  shows up.
- Codex coerces an unsupported effort level to the nearest supported one rather
  than failing, so a typo degrades quietly — one more reason to read the
  receipt.

There is no command that lists valid model ids, so the ids below are recorded
with their source and should be confirmed against `launch.effective` on first
use in a session.

---

## 3. Codex — the GPT-6 line

**No prices anywhere in this file, on purpose.** Both accounts here are
subscriptions with resets the user controls, so a per-1M figure never decides a
route — capability tier and endpoint headroom do (`quota-and-readiness.md`).
Price tables also drift silently and then read as fact. The one real cost axis
is metered vs unmetered: Qwen Code is free of both, which is why SKILL.md sends
mechanical work there.

Measured 2026-10-01 from `~/.codex/models_cache.json` (codex-cli 0.159.2). That file is the
authoritative list on this machine; read it again rather than trusting this
table after a CLI update.

| Model id | Served description | Reach for it when |
|---|---|---|
| `gpt-6.1-sol` | "Latest workhorse model for coding and everyday work." | **Default Codex model** — implementation, review, and adjudication |
| `gpt-6-astra` | "Frontier intelligence for the most demanding work." | Only when the user asks for it |
| `gpt-6-luna` | "Fast and affordable model for easier tasks." | Mechanical, checkable work — when Qwen Code is not usable (§6) |
| `gpt-6-sol` | "Previous generation workhorse model." | Do not pick — superseded by 6.1 Sol |

**Why 6.1 Sol and not Astra for judgment:** the user's call on 2026-10-01 —
where Astra would be chosen, 6.1 Sol spends far fewer tokens for the work it
returns. Escalate within Sol first (`xhigh`, then `max`); name Astra only on
request.

The GPT-5.6 line is still served (`gpt-5.6-sol`, `-terra`, `-luna`) but labelled
"Older", and `gpt-5.5` as "Legacy". There is no reason to pick one deliberately.
`gpt-reserve` and `codex-auto-review` are `visibility: hide` — not wave material.

**The tier names do not mean what they meant.** In GPT-5.6, Sol was the
flagship and Terra the mid-tier. In GPT-6 the frontier tier is **Astra**, Sol
has moved down to workhorse, and there is no Terra. Choosing 6.1 Sol for a
judgment slot is fine when it is the deliberate choice above; it is a mistake
only when someone picks Sol believing it is still the frontier tier.

**Local default here:** `~/.codex/config.toml` sets `model = "gpt-6.1-sol"`
and `model_reasoning_effort = "high"`. So a bare `worker-start --agent codex`
launches 6.1 Sol at high effort. Pass `--effort` deliberately: `medium` for
implementation, `xhigh` for adjudication.

**Effort ladder:** `low | medium | high | xhigh | max | ultra`, taken from each
model's `supported_reasoning_levels`. Two things changed from the old note:
there is no `minimal` level, and `ultra` ("maximum reasoning with automatic
task delegation") sits above `max` — on Astra and the Sol models only. **Luna stops at
`max`**, so an `ultra` brief sent to Luna is coerced down, silently, as §2
describes. The served default for all three is `medium`.

---

## 4. Claude — the Claude 5 family

| Model id | Positioning | Context | Reach for it when |
|---|---|---|---|
| `claude-haiku-4-5-20251001` | Classification, extraction, high volume | 200K | Mechanical, checkable work that must finish on a clock |
| `claude-sonnet-5` | The safe default for production work | 1M | Ordinary implementation, writing tests, single-dimension review |
| `claude-opus-5` | Complex reasoning, long documents, orchestration | 1M | Adjudication and adversarial review, where 5.5 is unconfirmed |
| `claude-opus-5-5` | Current top of the Opus line | 1M | Adjudication, adversarial review, coordination — **see the caveat below** |
| `claude-fable-5-1` | Mythos-class specialist: creative writing, roleplay, narrative | 1M | Long-form prose the reader will actually read — **not** code review (§5) |

Sources:
[Toloka](https://toloka.ai/blog/claude-models-explained/),
[Lorka](https://www.lorka.ai/knowledge-hub/which-claude-model-should-you-use),
[Datrick](https://datrick.com/claude-models-comparison).

**Opus 5.5 is confirmed on this install.** A `worker-start --agent claude
--model claude-opus-5-5 --effort high` on 2026-09-29 came back with
`launch.effective` equal to the request, so the id is real here and the effort
was honoured. Keep reading `launch.effective` anyway — that field is the only
place a silent fallback would show.

**And the effort setting will not follow it.** `modelSettings` is keyed by
model id, and the local entry is `{"claude-opus-5": {"effortLevel": "medium"}}`
— there is no `claude-opus-5-5` key, so an Opus 5.5 launch does not inherit
that medium. Pass `--effort` explicitly for 5.5 rather than assuming the saved
setting applies.

Haiku 4.5 needs extended thinking enabled manually; Sonnet 5 and Opus 5 use
adaptive thinking; Fable 5.1 keeps adaptive thinking on by default.

**Local default here:** `~/.claude/settings.json` sets `model: "opus[1m]"` with
`modelSettings: {"claude-opus-5": {"effortLevel": "medium"}}`. So a bare
`--agent claude` launches Opus 5 at **medium** — which is why the two families'
defaults differ, and why "I passed no flags" says nothing about what a wave
cost.

**Effort ladder:** `low | medium | high | xhigh | max`, saved per model under
`modelSettings`
([Claude Code docs](https://code.claude.com/docs/en/model-config),
[Anthropic effort docs](https://platform.claude.com/docs/en/build-with-claude/effort)).
Low and medium give strong quality for a fraction of the tokens and latency;
high is the best overall balance; `max` is the deepest tier.

---

## 5. Routing — match the model and effort to the kind of answer

The axis is the one SKILL.md already uses: is the output a **fact** or a
**decision**? Task size is a poor guide. Transcribing one file's columns is
small and needs no thinking; "are these two transaction boundaries equivalent"
is two paragraphs and needs all of it.

| Kind of work | Family | Model | Effort |
|---|---|---|---|
| Enumerate, count, transcribe, grep a claim, collect `file:line` citations | Qwen Code (unmetered) | endpoint-selected; no CLI override | n/a |
| Same, but time-boxed or Qwen is unavailable | Claude / Codex | `claude-haiku-4-5-20251001` / `gpt-6-luna` | `low` |
| Implement against a stated contract; write tests; find where a behaviour lives | Claude / Codex | `claude-sonnet-5` / `gpt-6.1-sol` | `medium` |
| Single-dimension review (one checklist over one diff) | Claude / Codex | `claude-sonnet-5` / `gpt-6.1-sol` | `medium` |
| Adversarial review; hunt the defect nobody has named | Claude / Codex | `claude-opus-5-5` / `gpt-6.1-sol` | `high` |
| Adjudicate a disagreement; reverse an earlier judgment; choose failure semantics or concurrency guarantees | Claude / Codex | `claude-opus-5-5` / `gpt-6.1-sol` | `xhigh` |
| Long-form prose a person will read end to end | Claude | `claude-fable-5-1` | `high` |

Cross-family review pairs Opus 5.5 with `gpt-6.1-sol` at `xhigh` in the
judgment slots. That is a deliberate trade of a tier-matched pair (Opus ↔ Astra)
for token use, chosen by the user. When a disagreement between the two looks
like a capability gap rather than a real difference of judgment, re-run the
Codex side once at `max` before treating it as settled; offer Astra to the user
only if that still leaves it open.

---

## 6. Misrouting traps

- **"Most capable" is not one ordering.** Fable 5.1 is the top of the Claude
  line and a *narrative* specialist. Sending it a diff to review spends the
  most expensive model on the thing it is least aimed at; Opus 5.5 is the
  reviewer.
- **Do not raise effort to compensate for a vague brief.** A worker thinking
  harder about an underspecified task returns a more confident wrong answer.
  Tighten scope, evidence requirements and acceptance criteria first; raise
  effort only once the brief is precise.
- **Do not lower effort on the wave's most important slot.** The independent
  review the coordinator will lean on hardest is where the cost is worth
  paying. Save capacity by sending mechanical work to Qwen Code — not by asking
  the adjudicator to think less.
- **Qwen Code is unmetered, not unconditional.** It has a 15-minute stream
  lifetime cap (`QWEN_STREAM_MAX_LIFETIME_MS`, default `900000`), and on
  2026-09-16 three workers were each killed by it after 13–14 minute thinking
  blocks — 73 minutes, zero output, on tasks that were three file reads. So it
  is the default for mechanical work **without** a deadline. Anything
  time-boxed goes to Haiku 4.5 or `gpt-6-luna` at `low` instead, and Qwen briefs are shaped
  to finish in few turns (one grep, one transcription).
- **A smaller model at high effort is not a bigger model.** Effort buys more
  deliberation on the same capability.
- **Reusing a terminal silently reuses its model.** `--terminal` rejects both
  flags, so a follow-up task inherits whatever the first launch chose. When the
  follow-up needs a different tier, start a fresh worker.

---

## 7. Record it

Name the model and the effort per worker in the topology announcement and again
in the final report, taken from `launch.effective`. When a family or model the
user asked for is unavailable, report that instead of substituting — §1 is the
check, not an estimate.
