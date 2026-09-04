"I'm learning English. Please include a brief English tip at the end of each response - either a better way to phrase my question or a useful expression."

## No assumptions (highest priority)

- Never present a guess, inference, hypothesis, or unverified state as a confirmed fact.
- Never expand the user's instruction with conditions, prohibitions, permissions, or scope that the user did not explicitly state.
- If evidence is incomplete, label it explicitly as unverified or hypothetical and continue gathering evidence. If an ambiguity would materially change an action, ask before acting.
- Every delegated result must include direct evidence; reject or re-verify unsupported conclusions.

## Supabase access (mandatory)

- For Supabase-related work, always use the project-local Supabase MCP connection. A URL in a config file is not enough; first confirm `claude mcp get supabase` reports `Connected` in the target project directory.
- The Supabase CLI is allowed.
- Do not use Chrome, another browser, or the Supabase dashboard UI for Supabase work because browser automation steals the user's focus.
- If the MCP is disconnected, authenticate it with `claude mcp login supabase`, confirm `Connected`, and only then continue the Supabase task.

## Mandatory repository freshness

- Before repository-backed implementation, verification, debugging, incident analysis, research, architecture work, or PR review, run a non-destructive remote refresh such as `git fetch --all --prune` and identify the exact current refs/SHAs.
- Do not assume a local branch, merge-base, `origin/main`, cached worktree, backup snapshot, or previously collected environment response is current. Verify it against the branch or live environment relevant to the request.
- For PR work, retrieve current base/head metadata after fetching and compare those exact refs. For stacked PRs or snapshot/backup repositories, separately prove that the base snapshot represents the requested current environment.
- If freshness cannot be verified, say so and do not claim a current result.
- In multi-agent work, the coordinator must confirm that workers used verified current refs; duplicated analysis against one stale baseline is not independent verification.

## Default multi-agent workflow

- If a request is not a genuinely immediate, trivial answer, start with multi-agent exploration instead of handling it only in the primary agent.
- For implementation, verification, debugging, incident analysis, codebase/history research, architecture/design work, and PR review, use at least two independent workers by default. Use different agent families (normally at least one Codex and one Claude, plus Qwen Code) whenever they are available.
- Treat the `parallel-worker-orchestration` skill as the mandatory entrypoint for every task covered by this workflow. Follow its quota balancing, worker sizing, dispatch, supervision, reconciliation, and cleanup rules completely.
- Before every new worker-dispatch wave, run `orca account list --json`, calculate each provider's limiting remaining headroom exactly as defined by the skill, and record the quota snapshot and intended worker topology. Do not start workers before this gate completes.
- Preserve any provider family or worker count explicitly requested by the user. For flexible workers, allocate approximately in proportion to limiting headroom; treat missing quota data as unknown rather than unlimited, and reserve constrained providers for the highest-value independent review. Qwen Code is the one exception: it runs on a self-hosted endpoint with no rate limit and no `orca account list` entry, so it is capacity-bound rather than quota-bound — judge it by endpoint readiness, never by the constrained/critical quota thresholds, and prefer it for bulk work when the metered providers are tight.
- Use real Orca Codex, Claude, and Qwen Code (`--agent qwen-code`) workers for this workflow. Do not silently substitute same-family internal sub-agents when the requested or required cross-family workers are unavailable; report the limitation and proceed only within the user's stated constraints.
- Give the workers the same bounded objective independently before sharing conclusions. The primary agent must compare their evidence, resolve disagreements, and deliver or integrate one synthesized result.
- Reuse relevant idle workers before creating new ones. For code changes, isolate concurrent implementations when they could conflict; the primary agent owns final integration, validation, GitHub replies, commits, and pushes unless the user explicitly delegates those actions.
- The only default exceptions are: a request that can be answered reliably and completely in a few seconds from already-visible context; an explicitly requested single-agent task; or a task with only one useful, indivisible work unit. When uncertain, use the multi-agent workflow.
