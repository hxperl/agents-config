# Cross-review and pull-request review

Loaded when the request asks agents to critique each other, reach consensus, or review a pull request. PR review has a mandatory prerequisite skill — read this before creating any PR-review task.

### Cross-review

Add one tracked cross-review round when the user asks agents to discuss,
critique, agree, or reach consensus, or when a high-impact decision materially
benefits from adversarial review.

After all initial tasks complete, build a bounded review graph:

- With two workers, use reciprocal review.
- With three to six workers, use a ring or balanced assignment so every report
  receives at least one independent review. Prefer cross-family review when
  multiple agent families are present.
- With more than six workers, group related outputs and assign designated
  reviewers per group. Do not create an all-to-all `N²` review graph unless the
  user explicitly requests it.
- Give each reviewer only the completed reports needed for its assignment.
- Ask reviewers to identify supported agreements, weak claims, missing
  evidence, and priority changes.
- End after one review round unless a concrete unresolved question justifies
  another.

Do not use open-ended agent conversation. It obscures ownership and can loop.

### Pull-request review

Treat the user's current worktree and index as immutable. Before dispatch,
record `git status --porcelain=v1`. Every worker prompt must prohibit
`git checkout`, `git switch`, `git reset`, `git restore`, and `git stash` in
that worktree. Exact base/head inspection and tests must use a unique isolated
Orca worktree or a `/tmp` tree made with `git archive`. Audit the baseline after
each completion; stop and discard any worker result that changed it, restore
only worker-created changes, and rerun that review in isolation.

Before creating any PR-review task, read and follow the user-level
`review-pr-with-intent` skill completely. Resolve its absolute `SKILL.md` path
and include that path as a mandatory prerequisite in every Claude, Codex, or
other worker task; never assume a fresh worker will discover the skill
implicitly.

For every PR, assign one Claude worker and two Qwen Code workers by default to
independently review the verified base-to-head diff. Launch Qwen Code with
`--agent qwen-code` only, without `--model` or `--effort`. Qwen findings,
severity, and review-state recommendations are provisional. When the coordinator
is Codex, keep final adjudication with the coordinator, who must independently
verify every material claim against the live PR, source, and tests. Do not add a
Codex worker by default. Use one only when the user explicitly requests it or a
Qwen slot fails a measured readiness/startup check and an independent replacement
is still required; report that fallback. Each task must also
embed the intent-aware core contract: read the entire live PR body, commits,
comments/reviews, linked tickets and predecessor/successor/stacked PRs; produce
the complete intent ledger before findings; do not classify verified follow-up
scope as a current blocker; turn unclear intent or merge order into an author
question.

Reject reports that omit the intent ledger or fail to verify declared deferrals.
In the default topology, run one tracked consensus round after all three valid
reports arrive. The Claude worker critiques both Qwen reports; each Qwen worker
fact-checks at least one other report's cited evidence and intent ledger. The
coordinator independently adjudicates every material disagreement and may
publish only the verified in-scope finding set. If Claude is unavailable, keep
the two Qwen reviews and require the Codex coordinator to complete a full
independent review before starting adjudication; report this degraded topology.
Preserve the per-PR pool and consensus round separately in a multi-PR request.
