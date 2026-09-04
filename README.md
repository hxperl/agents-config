# agents-config

Version-controlled, reusable configuration for local coding agents.

## Contents

- `machine/codex/AGENTS.md`: machine-wide Codex operating rules
- `machine/claude/CLAUDE.md`: machine-wide Claude operating rules
- `skills/parallel-worker-orchestration`: supervised mixed-provider orchestration
- `skills/opencode-go-only-orchestration`: OpenCode Go-only fallback orchestration
- `skills/review-pr-with-intent`: intent-aware pull-request review

## Local targets

| Repository path | Local target |
|---|---|
| `machine/codex/AGENTS.md` | `~/.codex/AGENTS.md` |
| `machine/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `skills/parallel-worker-orchestration` | `~/.agents/skills/parallel-worker-orchestration` |
| `skills/opencode-go-only-orchestration` | `~/.agents/skills/opencode-go-only-orchestration` |
| `skills/review-pr-with-intent` | `~/.codex/skills/review-pr-with-intent` |

Copy or symlink these paths deliberately. This repository does not include an
automatic installer because replacing machine-wide rules should remain an
explicit operation.

## Excluded state

Credentials, API keys, MCP authentication, provider settings, session history,
logs, caches, per-project approvals, and generated artifacts are intentionally
excluded. Keep provider secrets in their native credential stores.
