# Qwen verifier-driven repair loop

Use this loop only after a Qwen Code writer has made an authorized code change
and the coordinator has verified that the change fails a deterministic project
test, lint, build, or other acceptance command. The purpose is to recover from
a failed Qwen implementation without slowing down successful first attempts.

Do not use this loop for:

- read-only investigation, fact collection, review, or product and architecture
  judgment;
- Claude or Codex workers;
- an infrastructure, authentication, flaky-service, or unavailable-dependency
  failure;
- a pre-existing failure that direct evidence shows is unrelated to the
  worker's diff; or
- work that has no deterministic validation signal.

## Ownership and state

The coordinator owns the loop. A Qwen worker must not spawn its successor.
Before starting a repair worker, settle and release or fence the previous writer
so only one writer can touch the worktree. Keep the same isolated worktree when
the repair must build on the existing diff, and record its current base SHA,
changed files, and diff state before dispatch.

Preserve the original task scope, acceptance criteria, project rules, and
external-write authority across every attempt. A retry does not authorize a
new dependency, migration, ticket, branch, commit, push, PR, comment, or other
external mutation. Never reset, discard, or overwrite unrelated user changes.

Track attempt summaries in Orca task results or coordinator-owned temporary
artifacts rather than adding ledger files to the product repository, unless
that repository explicitly requires such files.

## Trigger and retry packet

Run the initial Qwen implementation once through the ordinary supervised
workflow. After its result arrives, the coordinator must inspect the actual
diff and directly verify the required validation command. A worker's statement
that tests passed or failed is not sufficient by itself.

When a repair is warranted, give a fresh Qwen Code context a compact packet
containing:

- the unchanged objective, scope, exclusions, and acceptance criteria;
- the attempt number, verified base SHA, current changed-file list, and the
  existing diff or exact path where it can inspect that diff;
- the exact failing command, exit status, and the smallest relevant error
  excerpt;
- which focused or required checks already passed;
- a concise summary of the previous approach and evidence that should prevent
  repeating it; and
- instructions to diagnose first, make the smallest in-scope repair, run the
  focused check, then run the required validation.

Do not include secrets or dump an unbounded log into the prompt. Point to a
bounded artifact when more detail is needed.

## Retry budget and stopping conditions

Allow at most **two fresh Qwen repair attempts after the initial attempt** by
default. The repairs are sequential, not parallel competing writers. Stop
earlier and escalate to the coordinator when any of these occurs:

- all required validation passes;
- the same material failure recurs twice;
- a repair produces no meaningful diff or repeats the prior approach;
- the evidence points to infrastructure or an unrelated pre-existing failure;
- the next repair would expand scope or require new authority; or
- the worktree cannot be kept under single-writer ownership.

Do not silently add a third repair attempt. A further attempt requires an
explicit coordinator decision backed by new evidence that materially changes
the approach; never exceed three repair attempts after the initial run without
an explicit user request.

## Completion

After a repair reports success, the coordinator must inspect the resulting diff
and directly re-run or otherwise independently verify the stated acceptance
commands. Preserve the original review topology: a Qwen repair is not a
substitute for an assigned Claude, Codex, or repository-required reviewer.

Report the number of attempts, the final validation evidence, and whether the
loop stopped because it succeeded, hit a stopping condition, or exhausted its
budget. Do not describe an exhausted loop as completed work.
