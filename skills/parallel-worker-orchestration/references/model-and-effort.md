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
| `claude` | 1 account, active |
| `codex` | authenticated as `systemDefault`, quota reporting `ok` |
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

## 3. Codex — the GPT-5.6 line

Three tiers of one model, differing in capability, speed and price
([OpenAI](https://openai.com/index/gpt-5-6/),
[Vellum](https://www.vellum.ai/blog/gpt-5-6-benchmarks-explained)):

| Model id | Positioning | Price / 1M (in/out) | Reach for it when |
|---|---|---|---|
| `gpt-5.6-sol` | Flagship | $5 / $30 | The task is genuinely hard: long reasoning chains, whole-subsystem analysis, intricate generation |
| `gpt-5.6-terra` | Balanced mid-tier, ~GPT-5.5 quality at half the cost | $2.50 / $15 | Ordinary implementation and single-dimension review |
| `gpt-5.6-luna` | Lightweight, fast | $1 / $6 | Mechanical, checkable work — when Qwen Code is not usable (§6) |

**Local default here:** `~/.codex/config.toml` sets `model = "gpt-5.6-sol"` and
`model_reasoning_effort = "high"`. So a bare `worker-start --agent codex`
launches **the flagship at high effort** — confirmed in the worker banner on
2026-09-16 (`gpt-5.6-sol high`). Omitting the flags is not the cheap path.

**Effort ladder:** `minimal | low | medium | high | xhigh`
([Codex Insider](https://codexinsider.com/config/model-reasoning-effort/),
[Codex KB](https://codex.danielvaughan.com/2026/03/27/reasoning-effort-tuning/)).
Medium is the recommended starting point for interactive work; `xhigh` is for
work where correctness outranks turnaround — security audits, complex
migrations, architectural decisions.

---

## 4. Claude — the Claude 5 family

| Model id | Positioning | Price / 1M (in/out) | Context | Reach for it when |
|---|---|---|---|---|
| `claude-haiku-4-5-20251001` | Classification, extraction, high volume | $0.80 / $4 | 200K | Mechanical, checkable work that must finish on a clock |
| `claude-sonnet-5` | The safe default for production work | $3 / $15 | 1M | Ordinary implementation, writing tests, single-dimension review |
| `claude-opus-5` | Complex reasoning, long documents, orchestration | $15 / $75 | 1M | Adjudication, adversarial review, coordination |
| `claude-fable-5-1` | Mythos-class specialist: creative writing, roleplay, narrative | higher tier | 1M | Long-form prose the reader will actually read — **not** code review (§5) |

Sources:
[Toloka](https://toloka.ai/blog/claude-models-explained/),
[Lorka](https://www.lorka.ai/knowledge-hub/which-claude-model-should-you-use),
[Datrick](https://datrick.com/claude-models-comparison).

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
| Same, but time-boxed or Qwen is unavailable | Claude / Codex | `claude-haiku-4-5-20251001` / `gpt-5.6-luna` | `low` |
| Implement against a stated contract; write tests; find where a behaviour lives | Claude / Codex | `claude-sonnet-5` / `gpt-5.6-terra` | `medium` |
| Single-dimension review (one checklist over one diff) | Claude / Codex | `claude-sonnet-5` / `gpt-5.6-terra` | `medium` |
| Adversarial review; hunt the defect nobody has named | Claude / Codex | `claude-opus-5` / `gpt-5.6-sol` | `high` |
| Adjudicate a disagreement; reverse an earlier judgment; choose failure semantics or concurrency guarantees | Claude / Codex | `claude-opus-5` / `gpt-5.6-sol` | `xhigh` |
| Long-form prose a person will read end to end | Claude | `claude-fable-5-1` | `high` |

Cross-family review keeps the **tier** comparable on both sides — Opus 5 against
Sol, Sonnet 5 against Terra. Two reviewers who differ in tier as well as family
tell you about the tiers, not about the question.

---

## 6. Misrouting traps

- **"Most capable" is not one ordering.** Fable 5.1 is the top of the Claude
  line and a *narrative* specialist. Sending it a diff to review spends the
  most expensive model on the thing it is least aimed at; Opus 5 is the
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
  time-boxed goes to Haiku or Luna at `low` instead, and Qwen briefs are shaped
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
