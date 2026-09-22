# Quota balancing and provider readiness

Loaded by `parallel-worker-orchestration` before a flexible dispatch wave. The routing decision itself lives in SKILL.md; this file holds the arithmetic, the thresholds, and the Qwen Code readiness check.

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
model id present means healthy. Never print the API key.

Because Qwen Code carries no quota cost, it is the **default** for mechanical
work, not a fallback for when a metered provider is constrained. Metered
capacity is itself the scarce resource, so route work by its kind first and
only then by headroom — see "Route by the kind of work" in SKILL.md. Reserve the
metered providers for judgment and synthesis.

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
4b. Mechanical work goes to Qwen Code regardless of how healthy the metered
   providers look. Headroom decides how to split work that needs judgment; it
   does not promote fact-collection back onto a metered provider.
5. Never reduce required verification, silently change model family, or claim
   a quota value that was not returned by Orca. If all suitable providers are
   critical, queue the remaining wave and tell the user the reset timing.

Record the quota snapshot used for the decision in coordinator notes, but keep
user updates concise and do not expose account identifiers or credentials.
