# Machine-wide agent rules

## No assumptions (highest priority)

- Never present a guess, inference, hypothesis, or unverified state as a confirmed fact.
- Never expand the user's instruction with conditions, prohibitions, permissions, or scope that the user did not explicitly state.
- If evidence is incomplete, label the statement explicitly as unverified or hypothetical and continue gathering evidence. If an ambiguity would materially change an action, ask before acting.
- These rules apply to the primary agent and every delegated agent. The primary agent must reject or re-verify worker conclusions that are not supported by direct evidence.

## Supabase access (mandatory)

- For Supabase-related work, always use the project-local Supabase MCP connection. A URL present in a config file does not count as connected; confirm authentication with an actual harmless MCP call, not `codex mcp list` alone. A project-owned command explicitly documented as the canonical path for a specific projection or migration is an allowed exception; use that command as written instead of replacing it with ad-hoc REST calls.
- The Supabase CLI is allowed.
- Do not use Chrome, another browser, or the Supabase dashboard UI for Supabase work because browser automation steals the user's focus.
- If Supabase MCP tools are missing, immediately run `codex mcp list`. Treat `enabled` / `OAuth` as registration metadata, not proof that the token works. If an actual MCP call reports `failed to refresh OAuth tokens`, or the list explicitly reports `Not logged in`, use `codex mcp login supabase` once after the required visible-auth approval; do not repeat repository-config searches.
- After successful login, retry one actual harmless MCP call in the current session. Do not repeatedly ask the user to restart. If the current client cannot adopt the refreshed credential, report that precise client-state limitation once. Continue only through an already documented project-owned exception; otherwise the MCP-owned operation remains unavailable until a newly initialized client can make the call.

## Multi-agent orchestration (default for repository work)

- Start repository investigations, specifications, implementations, debugging,
  PR reviews, and test-validation work with supervised multi-agent
  orchestration. Do not first produce a single-agent implementation and add
  workers only at the end.
- The primary agent is the coordinator and technical lead. It must define
  non-overlapping worker roles, monitor progress, reconcile disagreements, and
  independently verify every material worker conclusion against source code,
  tests, repository state, or another direct source of truth.
- Use independent model/provider perspectives when available, following the
  installed multi-agent orchestration skill for model selection, quota checks,
  permissions, and lifecycle reporting. Keep only one writer per file or
  worktree; use other workers for read-only investigation and review unless
  write scopes are explicitly separated.
- If an intended worker or provider is unavailable, begin with the available
  workers and report the exact limitation. Do not silently fall back to an
  unreported single-agent workflow.
- Simple conversational answers and trivial read-only lookups that do not
  involve repository engineering are exempt.

## GitHub account isolation

- Never run `gh auth switch` for project work because it changes the global
  active GitHub account and races with other projects and workers.
- Select the required account per command with a scoped environment variable,
  for example `GH_TOKEN="$(gh auth token --user <login>)" gh ...` or the same
  environment on `git` commands. Do not print the token.
