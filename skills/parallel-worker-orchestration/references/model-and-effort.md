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
| `claude` | 1 account, active — **the only family that launches here** |
| `codex` | authenticated and `ok`, but **workers do not start** — see §1.1 |
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

### 1.1 Codex workers do not start on this install

Measured 2026-09-29 against Orca `1.4.215`. Four `worker-start --agent codex`
attempts — `gpt-6-astra` and `gpt-6-sol`, `high` and `low`, and one launched
with no `--model` at all — every one failed at stage `agent_readiness` with
`timeout`, or sat at `start_unknown` and never settled. Every worker that
succeeded that day was `agent=claude`.

It is not the model, the effort, or the quota: `codex exec` answers normally
from the same shell, so auth and the model are healthy. Only Orca's TUI launch
path is broken.

**The failure is not free.** The process does start and call the model, so the
token meter climbs; Orca simply never observes the turn begin, reclaims the
worker, and nothing is produced. One such worker was found still holding a
terminal seven hours after it was dispatched. So when a Codex launch fails,
`worker-stop` it rather than leaving it for later.

Until this is fixed: say the family is unavailable and run the wave on Claude,
or drive Codex through `codex exec` with the brief on stdin — which works, but
gives up heartbeats and `worker_done`, so the coordinator collects the result
itself. Do not wait on a Codex dispatch id that never reported a start.

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

Measured 2026-09-29 from `~/.codex/models_cache.json` (served by OpenAI,
`fetched_at 2026-09-29T04:23Z`, codex-cli 0.158.0). That file is the
authoritative list on this machine; read it again rather than trusting this
table after a CLI update.

| Model id | Served description | Reach for it when |
|---|---|---|
| `gpt-6-astra` | "Frontier intelligence for the most demanding work." | Adjudication, adversarial review, whole-subsystem analysis |
| `gpt-6-sol` | "Workhorse model for coding and everyday work." | Ordinary implementation, single-dimension review |
| `gpt-6-luna` | "Fast and affordable model for easier tasks." | Mechanical, checkable work — when Qwen Code is not usable (§6) |

The GPT-5.6 line is still served (`gpt-5.6-sol`, `-terra`, `-luna`) but labelled
"Older", and `gpt-5.5` as "Legacy". There is no reason to pick one deliberately.
`gpt-reserve` and `codex-auto-review` are `visibility: hide` — not wave material.

**The tier names do not mean what they meant.** In GPT-5.6, Sol was the
flagship and Terra the mid-tier. In GPT-6 the frontier tier is **Astra**, Sol
has moved down to workhorse, and there is no Terra. Any routing rule, prompt,
or habit that reads "Sol = the best one" now silently downgrades the slot it
was protecting.

**Local default here:** `~/.codex/config.toml` sets `model = "gpt-6-sol"` and
`model_reasoning_effort = "high"`. So a bare `worker-start --agent codex`
launches **the workhorse at high effort** — not the frontier model. Omitting
the flags is neither the cheap path nor the strongest one.

**Effort ladder:** `low | medium | high | xhigh | max | ultra`, taken from each
model's `supported_reasoning_levels`. Two things changed from the old note:
there is no `minimal` level, and `ultra` ("maximum reasoning with automatic
task delegation") sits above `max` — on Astra and Sol only. **Luna stops at
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
| Implement against a stated contract; write tests; find where a behaviour lives | Claude / Codex | `claude-sonnet-5` / `gpt-6-sol` | `medium` |
| Single-dimension review (one checklist over one diff) | Claude / Codex | `claude-sonnet-5` / `gpt-6-sol` | `medium` |
| Adversarial review; hunt the defect nobody has named | Claude / Codex | `claude-opus-5-5` / `gpt-6-astra` | `high` |
| Adjudicate a disagreement; reverse an earlier judgment; choose failure semantics or concurrency guarantees | Claude / Codex | `claude-opus-5-5` / `gpt-6-astra` | `xhigh` |
| Long-form prose a person will read end to end | Claude | `claude-fable-5-1` | `high` |

Cross-family review keeps the **tier** comparable on both sides — Opus 5.5
against Astra, Sonnet 5 against Sol, Haiku 4.5 against Luna. Two reviewers who
differ in tier as well as family tell you about the tiers, not about the
question. This is the pairing the GPT-6 rename broke: Opus against Sol used to
be tier-matched and now is not.

---

## 6. Misrouting traps

- **"Most capable" is not one ordering.** Fable 5.1 is the top of the Claude
  line and a *narrative* specialist. Sending it a diff to review spends the
  most expensive model on the thing it is least aimed at; Opus 5.5 is the
  reviewer. The same trap now has a Codex half: Sol is the name people
  remember, Astra is the frontier tier.
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
