# Choosing the model and the reasoning effort for a worker

Loaded when a wave launches a fresh worker. SKILL.md routes by **family**
(Claude, Gemini on Antigravity, Codex); this file is the tier below it — which
model inside the family, and how hard it should think.

Everything here is either measured on this machine or cited. Re-verify §1
before a wave: accounts, subscriptions and defaults change, and a routing table
that has drifted is worse than none.

---

## 1. Which agents actually exist here

Families decided by the user on 2026-10-19:

| Agent id | Role | State on this machine |
|---|---|---|
| `claude` | judgment (default pair) | 1 account, active; `worker-start` works (Orca `1.4.216`+) |
| `antigravity` | facts via Gemini 3.8 Flash; scarce tiebreaker via Gemini 4 Argon High | Google AI Pro, annual plan. `agy` 1.4.2 at `~/.local/bin/agy`. `worker-start --agent antigravity --model gemini-3.8-flash-medium` reached `ready`, and `worker_done` settled `succeeded` (2026-10-19, Orca 1.4.224) |
| `codex` | judgment (default pair) | `gpt-6.1-sol`; **subscription cancelled, usable until 2026-11-16**. From that date, report Codex as unavailable instead of launching it |
| `qwen-code` | parked (workstation upgrade in progress) | Launch only when the user names it. Restore notes: SKILL.md |
| `opencode` | OpenCode judgment voice (replaces Codex from 2026-11-16); fact fallback; second Argon pool — ids per wave, §3b | OpenCode Go Plus (user, 2026-11-06). `opencode` 2.0.25 at `/opt/homebrew/bin/opencode`. `worker-start --agent opencode --model opencode-go/kimi-k3.1-pro --worktree current` delivered `worker_done` `succeeded` (2026-11-06, Orca 1.4.249). Quota: `rateLimits.opencodeGo` |
| `gemini`, `kimi`, `minimax`, `grok` (direct CLIs) | — | present in `rateLimits`, `unavailable` — use those models through `opencode` instead |
| `cursor` | — | not in `rateLimits` at all |

Help strings and Orca group addresses (`@cursor`, `@gemini`, …) are names, not
evidence that an agent is configured. Check `orca account list --json` for the
wave. If the user asks for an unavailable family, say so and stop rather than
substituting another.

### 1.1 Launch paths

On Orca `1.4.218`+ use `worker-start` for claude, codex, antigravity and opencode.

- **OpenCode:** pass `--model opencode-go/<id>` with `--worktree current` or an
  existing worktree selector. Orca rejects OpenCode model selection on a new
  worktree, and `--effort` is unsupported.

- **Codex:** after `worker-start`, read the screen. If the "Update available"
  menu is up, pick Skip (Down, Enter) and send the brief with
  `orca terminal send --enter` (enaible/AGENTS.md). `worker-start` can return
  `ok: true` with `state: failed`. Read `result.state`; never retry in a loop.
- **Antigravity:** `turnStart` was not reported in the 2026-10-19 receipt. Prove
  startup by reading the worker's output, as `supervision.md` requires.
- Below Orca `1.4.217`, Codex needs the low-level `terminal create` +
  `dispatch --inject` path (see the Orca orchestration guide).
- **A failed `worker-start` is not free.** The process may already be calling
  the model. `worker-stop` / `worker-release` it immediately.

---

## 2. The flags, and the constraints the runtime enforces

- `--effort` requires `--model`. Neither combines with `--terminal`. Reusing an
  idle worker means accepting the model it started with.
- **Read `launch.effective` in the receipt** and name it in the topology
  announcement and the final report. A silent fallback shows up only there.
- **Antigravity encodes the effort in the model id** (`…-low|medium|high`).
  Pass `--model` only. The 2026-10-19 receipt showed `effort: null` and was
  honoured as requested. Combining `--effort` with Antigravity is untested.
- Codex coerces an unsupported effort to the nearest supported one rather than
  failing, so read the receipt.

**No prices in this file, on purpose.** All three are subscriptions. Capability
tier and the per-wave bucket headroom (`quota-and-readiness.md`) decide a route,
never a per-token figure.

---

## 3. Gemini on Antigravity

`agy models` lists the models; re-read it after an `agy update`. The research
below was done on 2026-10-19 by two independent workers (Claude Opus 5.5 and
Gemini 4 Argon High), and the sources agreed.

**Gemini 3.8 Flash.** Released 2026-09-02, GA. Google calls it "our most
intelligent workhorse model". Specs: 1M input context, 65,536-token output.

- Strengths: fast, about 86–160 output tok/s (OpenRouter, Artificial Analysis).
- Weaknesses: very verbose. Terminal-Bench 4.0 is only about 19–20%
  ([Vals](https://www.vals.ai/benchmarks/terminal-bench-4)), against about 65%
  for Opus 5.5.
- Use it for **narrow, checkable** tasks only: grep, count, transcribe, cite.
  Never open-ended agentic work or judgment.

**Gemini 4 Argon.** API GA 2026-10-13. Google calls it a "frontier model for
real-world coding … and cyber defense". Specs: 1M unified input+output window.

- Strengths:
  - DeepSWE v1.1 77.9% and CWE-bench 68% (Google).
  - Lowest reported hallucination rate: 15% on AA-Omniscience.
- Weaknesses:
  - Terminal-Bench 4.0 about 57%, behind Opus and Sonnet 5.5.
  - Slow: about 37–46 tok/s, and the model card lists "occasional slowness or
    timeout". The 2026-10-19 research task took about 20 minutes, against
    about 4 for Opus.
- One third-party trial used it as an adversarial reviewer
  ([tkakkie/ribbitto#1041](https://github.com/tkakkie/ribbitto/issues/1041)):
  it made complementary finds, had zero false positives, and missed some
  defects. That is a small sample.

**Suffixes are thinking levels** (Antigravity models docs):
- `LOW`: high-throughput, low complexity.
- `MEDIUM`: the default; balanced.
- `HIGH`: deep multi-step reasoning, verification.
- No token budget per level is published. `MINIMAL` is unsupported.
- Always pin the suffix. Argon's agy default is reported inconsistently.

**Quota (Google AI Pro)** — no numbers are published:
- "Gemini Models": 5-hour refresh up to a weekly cap. Flash uses it.
- "Gemini 4 Argon": **weekly-only**, separate. One research task used **14%**.
- "Claude and GPT models": a separate bucket.

| Model id | Slot |
|---|---|
| `gemini-3.8-flash-low` | bulk fact collection: one grep, one transcription, counting |
| `gemini-3.8-flash-medium` | fact collection across several files; citation sweeps; reconciling counts |
| `gemini-3.8-flash-high` | careful fact tracing (call chains, data flow). Escalate to Sonnet 5.5 if it stalls |
| `gemini-4-argon-high` | tiebreaker between Claude and Codex. After 2026-11-16, the second judgment voice on high-stakes reviews |
| `gemini-4-argon-low`/`-medium` | not used — they spend the scarce Argon bucket without the judgment depth |

Antigravity also serves `claude-opus-5-5-*`, `claude-sonnet-5-5-*` and
`gpt-oss-120b-medium`. **Do not pick them.**
- The Claude models duplicate our Claude family.
- `gpt-oss-120b` is an open-weight model. It is **not** GPT-6.1 Sol, so it does
  not replace Codex after the subscription ends.

---

## 3b. OpenCode Go — choose the model per wave

The Go catalog changes often, so this file fixes the **selection rule**, not
the ids. Run it at the start of each wave that has an OpenCode slot:

1. `opencode models` — list the current ids. Use `opencode-go/*` (the paid Go
   plan). `opencode/*` is Zen; on company projects use none of it.
2. Drop what the project forbids:
   - free and data-sharing ids (see **Free models** below) on company projects;
   - Global-region models on company projects. They fail with "hosted outside
     Europe and the United States" until the workspace selects Global.
   - families that duplicate the pool: `claude-*` (our Claude family). Drop
     `gpt-*` too while Codex is live; after 2026-11-16 a `gpt-*` id may
     fill a non-Claude slot.
3. Pick by role:
   - **Judgment voice:** a flagship id (`pro`/`max`/an unsuffixed top
     version, never `flash`/`lite`/`mini`) from a family other than the
     coordinator's. Prefer the family that answered best in earlier waves of
     this session. Otherwise prefer Kimi, then GLM, then Qwen, then MiniMax.
     Within a family take the highest version.
   - **Fact worker:** a `flash`/`lite` id. Prefer the GLM or Qwen line.
   - **Argon pool:** the `gemini-*-argon*` id.
4. If the id has not answered in this session, smoke it with
   `opencode run -m <id> "Reply with exactly: OK"`. On an error, take the next
   candidate. Never treat a listed id as available on the strength of the
   listing alone.
5. Name the chosen id in the topology announcement and the final report.

Snapshot only, not a contract (2026-11-06): `worker-start` with
`opencode-go/kimi-k3.1-pro` delivered `worker_done`. `kimi-k3.1-pro`, `kimi-k3`,
`gemini-4-argon`, `qwen3.8-max`, `glm-5.3`, `minimax-m3`, `qwen3.8-flash` and
`glm-5.3-flash` answered `opencode run`. `deepseek-*` needed the Global region.

**Quota.** Go meters each model in dollars: 5-hour = 20%, weekly = 50%,
monthly = 100% of the monthly limit (opencode.ai/docs/go). Read
`rateLimits.opencodeGo` `session`/`weekly`/`monthly` before each OpenCode
slot. A dozen one-line smoke calls used 2% of the 5-hour window.

**Free models.** Every `*-free` id, `big-pickle`, the `opencode/*` Zen free
models and `*-contributor*` models are free for a limited time, and several
of them retain prompts or use them for training (opencode.ai/docs/zen). They
are **banned on company projects**: a repository whose `origin` is under the
GitHub org `themoin`, or a path under `~/Documents/development/moin` or an
Orca workspace of those repositories. When unsure, treat it as company. On
personal projects they are allowed (user, 2026-11-06).

---

## 4. Claude

| Model id | Reach for it when |
|---|---|
| `claude-haiku-4-5-20251001` | Fact work that must finish on a clock when Flash is unavailable |
| `claude-sonnet-5-5` | Ordinary implementation, writing tests, single-dimension review |
| `claude-opus-5-5` | **Judgment pair slot**: adjudication, adversarial review, coordination |
| `claude-fable-5-1` | Long-form prose a person will read end to end. **Not** code review |

`claude-opus-5-5` was confirmed through `launch.effective` on 2026-09-29.
`claude-sonnet-5-5` has not been confirmed on this install yet. Read
`launch.effective` on its first use.

**Local default:** `~/.claude/settings.json` holds `model` and `effortLevel`.
They read `opus` / `high` on 2026-10-19, but re-read them rather than trusting
this line. Pass `--model` and `--effort` deliberately; a bare `--agent claude`
says nothing about what a wave cost.

**Effort ladder:** `low | medium | high | xhigh | max`
([Claude Code docs](https://code.claude.com/docs/en/model-config)).

---

## 5. Codex — until 2026-11-16

Authoritative model list: `~/.codex/models_cache.json`.

- `gpt-6.1-sol` — **the Codex model.** Use it for every Codex slot. The user
  decided on 2026-10-01 that it spends far fewer tokens than Astra for the
  result.
- `gpt-6-astra` — only when the user asks.
- `gpt-6-luna` — fallback fact slot when neither Flash nor Haiku is usable.
- `gpt-6-sol` and the GPT-5.x line — superseded; do not pick.

Effort ladder: `low | medium | high | xhigh | max | ultra`. Luna stops at `max`.
In the tiebreaker role, run Sol at `xhigh`. Re-run once at `max` before calling
a disagreement settled.

---

## 6. Routing — match the model and effort to the kind of answer

The axis is the one SKILL.md uses: is the output a **fact** or a **decision**?
Task size is a poor guide.

| Kind of work | Default | Fallback |
|---|---|---|
| Enumerate, count, transcribe, grep a claim, collect `file:line` citations | `gemini-3.8-flash-low`/`-medium` | OpenCode fact worker (§3b), then Haiku 4.5 `low` |
| Careful fact tracing (call chains, data flow) | `gemini-3.8-flash-high` | `claude-sonnet-5-5` `medium` |
| Implement against a stated contract; write tests | `claude-sonnet-5-5` / `gpt-6.1-sol` `medium` | — |
| Single-dimension review (one checklist over one diff) | `claude-sonnet-5-5` / `gpt-6.1-sol` `medium` | — |
| Adversarial review; hunt the defect nobody has named | `claude-opus-5-5` `high` **and** `gpt-6.1-sol` `high` | after 2026-11-16: Opus + OpenCode judgment voice (§3b); add `gemini-4-argon-high` on high-stakes reviews |
| Adjudicate a disagreement; failure semantics, concurrency | `claude-opus-5-5` / `gpt-6.1-sol` `xhigh` (after 2026-11-16 the OpenCode judgment voice) | tiebreaker `gemini-4-argon-high`, then the OpenCode Argon pool |
| Long-form prose a person will read | `claude-fable-5-1` `high` | — |

The judgment pair is Opus 5.5 ↔ `gpt-6.1-sol`, and from 2026-11-16 Opus 5.5 ↔
the OpenCode judgment voice (§3b). When they split on a point that
matters, check the Argon bucket and add `gemini-4-argon-high` as tiebreaker. If
the bucket is low, re-run the weaker side once at a higher effort, then put the
remaining split to the user.

---

## 7. Misrouting traps

- **"Most capable" is not one ordering.** Fable 5.1 is a narrative specialist.
  Opus 5.5 and Argon High are the reviewers.
- **Do not raise effort to compensate for a vague brief.** Tighten scope,
  evidence requirements and acceptance criteria first.
- **Do not lower effort on the wave's most important slot.** Save capacity by
  sending mechanical work to Flash, not by asking the adjudicator to think less.
- **Flash is fast, not free.** It is metered on the Gemini buckets. Shape briefs
  to finish in few turns, and never let an uncited Flash claim into a
  conclusion.
- **Do not pick Claude or GPT models inside Antigravity** (§3).
- **No free models on company projects** (§3b), whatever the quota looks like.
- **Argon is weekly-only and slow.** Never use it for fact work or ordinary
  review. Check its bucket before each slot.
- **A smaller model at high effort is not a bigger model.**
- **Reusing a terminal silently reuses its model.** Start a fresh worker when a
  follow-up needs a different tier.

---

## 8. Record it

Name the model and the effort per worker in the topology announcement and again
in the final report, taken from `launch.effective`. When a family or model the
user asked for is unavailable, report that instead of substituting.
