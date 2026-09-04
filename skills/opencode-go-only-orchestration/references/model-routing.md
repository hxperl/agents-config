# OpenCode Go model routing

Refresh this routing against the live catalog and
<https://opencode.ai/docs/go/> before every new run. The baseline below was
verified on 2026-08-26 and is deliberately task-oriented rather than a static
leaderboard.

## Quota baseline

OpenCode Go was $10/month with dollar-valued limits of $12 per 5 hours, $30 per
week, and $60 per month. Those limits are shared across concurrent work. Model
request estimates differ by orders of magnitude, and premium models may receive
a lower effective multiplier.

Treat Go as burst capacity. Five fully saturated $12 windows exhaust the
baseline monthly allowance. Cache-stable, long-lived sessions are usually more
efficient than repeatedly spawning cold workers with reordered context.

## Routing table

Catalog presence is not an availability check. Probe each required model with a
small non-mutating task before depending on it. In particular,
`deepseek-v4-flash` may require an explicit China-hosting opt-in; never change
that account setting automatically. Use the listed alternative when the probe
fails, or stop if the user fixed the model selection.

| Task class | Default | Alternatives | Guardrail |
| --- | --- | --- | --- |
| Wide read-only scouting and classification | `hy3` | `mimo-v2.5`, `longcat-2.0` | Candidates only; consequential claims need stronger review. |
| Bulk code search, tests, bounded low-risk edits | `minimax-m3` | `qwen3.7-plus`, readiness-probed `deepseek-v4-flash` | Use DeepSeek only after its regional opt-in/readiness check passes. |
| Latency-sensitive independent bulk worker | `minimax-m3` | `qwen3.7-plus`, readiness-probed `deepseek-v4-flash` | Useful vendor and API-surface diversity. |
| Long-horizon implementation or MCP-heavy coding | `kimi-k2.7-code` | `deepseek-v4-pro` | Keep the task within its live context limit. |
| Architecture, difficult review, security, release gate | `glm-5.2` | `qwen3.7-max`, `kimi-k2.7-code` | Use one or two workers, not wide fan-out. |
| Final premium adjudication | `kimi-k3` | `glm-5.3`, `qwen3.8-max` | Hand-triggered, one worker only. |
| Very fast OpenAI-family routine work | `gpt-5.6-luna` | `minimax-m3` | Current Go quota tier may erase its cheap list price. |

At the baseline, DeepSeek peak hours converted to 10:00-13:00 and 15:00-19:00
KST on weekdays. Verify this before scheduling; provider economics can change.

## Default topologies

### Two-worker independent evaluation

- `minimax-m3`: primary analysis or implementation proposal.
- `hy3` or `qwen3.7-plus`: independent counter-analysis and missing-case search.
- A readiness-probed `deepseek-v4-flash` may replace either bulk role.
- For a high-risk decision, replace the second worker with `glm-5.2`.

### Three-role implementation

- `hy3` or `minimax-m3`: read-only repository map and test inventory.
- `kimi-k2.7-code`: sole writer for the assigned files.
- `glm-5.2`: read-only reviewer against intent and validation evidence.

### Wide research

- Several `hy3` or `mimo-v2.5` scouts on mutually exclusive sources.
- One `minimax-m3` integrator to normalize evidence.
- One `glm-5.2` adjudicator only when disagreements materially affect the
  answer.

## Selection rules

1. Choose by cost of error first, latency second, quota cost third.
2. Use different vendors for independent confirmation; multiple copies of one
   model are throughput, not strong epistemic diversity.
3. Cheap scouts may omit or hallucinate edge cases. Their output is a candidate
   set, never the final security, production, legal, financial, or medical
   decision.
4. Avoid `grok-4.6`, `glm-5.3`, `qwen3.8-max`, and `kimi-k3` for broad fan-out
   unless the refreshed Go table materially changes their economics.
5. Do not depend on limited-time free models for required verification.
6. Do not use `muse-spark-1.2-contributor` with private content without explicit
   acceptance of its current data-use terms.
7. Measure actual Go latency and rate limits before choosing more than a small
   concurrent wave; the official docs may not publish a concurrency ceiling.
