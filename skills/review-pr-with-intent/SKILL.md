---
name: review-pr-with-intent
description: Review pull requests with mandatory author-intent, exact base-to-head verification, and post-submit GitHub identity/state/visibility auditing. Use for any PR review, re-review, approval, request-changes decision, review comment, multi-agent PR audit, or delegated review work.
---

# Review PR With Intent

Treat the PR description and its linked work as review evidence, not optional
background. Never classify a behavior from the diff alone.

## 1. Gate on live PR state

1. Read repository instructions and applicable review skills.
2. Fetch relevant remotes with pruning and obtain live PR metadata.
3. Record repository, PR number, state, draft status, base ref/SHA, head ref/SHA,
   and update time.
4. If authentication fails, inspect configured accounts and select the required
   account per command with a scoped `GH_TOKEN`. Never run `gh auth switch`,
   because it changes global state and can race with other projects or workers.
   Configure repository-local Git credentials only when the fetch itself needs
   them, then retry against the same verified target.
5. If the PR is merged or closed, do not start or post an active review unless
   the user explicitly asks for a historical/post-merge review.
6. Review the PR's actual base-SHA-to-head-SHA change. Do not substitute a
   cached branch, stale merge base, cumulative branch history, or local HEAD.

If freshness or live metadata remains unverified, stop and report that the
review cannot be presented as current.

## 2. Build the intent ledger before reading for defects

Read all of the following from live sources:

- full PR title and description, including collapsed details and test plan;
- commit subjects and bodies;
- changed-file list and exact diff;
- code comments that explain intentional incompleteness or sequencing;
- existing review threads and author replies;
- linked tickets, specifications, designs, predecessor PRs, successor PRs,
  stacked PRs, and explicit follow-up work;
- intended merge and release order when multiple PRs jointly complete a flow.

Write an intent ledger in the review artifact with these fields:

```text
declared_goal:
in_scope:
explicitly_out_of_scope:
known_gaps:
follow_up_owners:
predecessors_and_successors:
stack_or_merge_order:
ship_independently:
unverified_links_or_assumptions:
```

Open linked work instead of inferring from its title. If a private ticket or
design cannot be accessed, mark it unverified. Do not convert an inaccessible
claim into a finding or an assertion about author intent.

## 3. Classify findings against intent and delivery order

A candidate finding is actionable only when all of these are true:

1. It is introduced by the PR or made reachable by the PR.
2. It has a concrete correctness, security, data-loss, regression, operability,
   accessibility, or required-test impact.
3. It violates the current PR's declared contract or an unavoidable repository
   contract.
4. It is not explicitly assigned to a verified follow-up PR or ticket under the
   intended merge/release plan.
5. The cited path and line are in the current head, and the impact path is
   demonstrated rather than guessed.

An explicitly deferred behavior is not a blocking defect in the current PR
when a verified successor owns it and the changes are intended to ship
together. If the current PR can merge or release independently and that order
creates a real broken state, classify it as a merge/release-order risk and
verify the order before requesting changes.

Do not treat these as findings by themselves:

- intentional incompleteness declared in the PR and owned by follow-up work;
- behavior outside the declared ticket scope;
- a preference without user-visible or maintenance impact;
- a hypothetical path contradicted by the PR body, tests, or delivery plan;
- missing coverage when existing tests already lock the relevant contract.

When intent, ownership, or ordering is ambiguous, prepare a question for the
author. Do not escalate ambiguity into `REQUEST_CHANGES`.

## 4. Delegate with a complete worker contract

### Isolate GitHub CLI identity per worker

In a multi-account or parallel-worker environment, never let the coordinator
or workers run an unscoped `gh auth switch` against the shared default
`~/.config/gh`. That command changes the active account for every concurrent
process and can make live metadata, review-thread, or submission checks run as
the wrong identity.

Before parallel GitHub access, give the coordinator and every worker a unique
temporary `GH_CONFIG_DIR`, seed it from the existing GitHub CLI host config,
select the required account inside that isolated directory, and verify it with
an actual `gh api user` call. Keep the same `GH_CONFIG_DIR` on every subsequent
`gh` command for that actor. Include this requirement in every delegated
review task. If the isolated configuration cannot authenticate, report the
failure rather than falling back to a shared global account switch.

Never send a worker a bare request such as “review this diff.” Every worker task
must contain:

- a mandatory prerequisite to read this `SKILL.md` completely before reviewing;
- repository and PR URL/number;
- verified base ref/SHA and head ref/SHA;
- live PR state;
- an instruction to read the full PR body, commits, comments, reviews, linked
  work, and relevant code comments before inspecting defects;
- an instruction to create the intent ledger first;
- exact diff scope and generated-file exclusions;
- the actionable-finding test from section 3;
- a prohibition on treating verified follow-up scope as a current blocker;
- evidence requirements: current-head path/line, trigger, impact, severity, and
  confidence;
- read-only authority unless the user separately authorized changes;
- a hard prohibition on mutating the user's current worktree or index: no
  `git checkout`, `git switch`, `git reset`, `git restore`, or `git stash` in
  that worktree; exact-head inspection and tests must run from a unique
  isolated worktree or a `/tmp` tree created with `git archive`;
- a unique report path outside the repository;
- the required lifecycle completion protocol from the active orchestration
  system.

Do not rely on implicit skill discovery in a fresh worker. Resolve the absolute
path of this skill and put it in every initial-review and cross-review task.
Also embed the core rules below in the task so the contract survives a missing
skill catalog, a different agent family, or a fresh terminal.

Use this core task text for every independent reviewer:

```text
Mandatory prerequisite: read and follow the complete user-level
review-pr-with-intent/SKILL.md at <absolute-skill-path> before taking review
actions. This is required even if the skill is absent from your skill catalog.

Review PR <url> read-only at exact base <base-ref>@<base-sha> to head
<head-ref>@<head-sha>. Before finding defects, read the entire live PR body,
commit bodies, comments/reviews, relevant code comments, and every accessible
linked ticket or predecessor/successor/stacked PR. Produce the intent ledger:
goal, in-scope work, explicit exclusions, known gaps, follow-up owners,
dependency/merge order, independent-ship expectation, and unverified claims.

Only report an actionable finding if it is introduced or exposed by this PR,
has concrete impact, violates the current PR contract, and is not intentionally
owned by verified follow-up work under the intended delivery order. Treat an
unclear intent/order as a question, not a defect. Cite current-head path and
line, trigger, impact, severity, and confidence. Record rejected candidate
findings and why they are intentional/out-of-scope. Do not modify the repo or
write to GitHub. Never run `git checkout`, `git switch`, `git reset`,
`git restore`, or `git stash` in the user's current worktree. Inspect and test
the exact head only in a unique isolated worktree or a `/tmp` tree produced by
`git archive`. Save the full report outside the worktree and complete the
active dispatch exactly once.
```

Give independent reviewers the same core task without leaking another
reviewer's conclusions.

Reject a worker completion as incomplete when its report omits the intent
ledger, leaves a required field blank without an explicit `N/A` plus evidence,
or classifies a deferred item without verifying the follow-up and delivery
order. Re-dispatch a bounded correction to that same worker before consensus.

Before dispatch, capture the user's current `git status --porcelain=v1` as the
immutable baseline. Audit it again after every worker completes. If a worker
changes the current worktree or index, stop that worker, discard its report,
restore only worker-created changes, and rerun the assignment in isolation.
Never accept useful-looking findings from a worker that violated this gate.

## 5. Require cross-family consensus

For each PR, use one Claude reviewer and two Qwen Code reviewers by default when
they are available. Launch Qwen Code with `--agent qwen-code` only; do not pass
`--model` or `--effort`. All three reviewers independently apply the complete
intent-aware contract. Qwen findings, severity, and review-state recommendations
are provisional until a metered reviewer and the coordinator verify them.
When the coordinator is Codex, the coordinator remains the final technical
lead: independently verify every material worker claim against the live PR,
source, and tests, then adjudicate the consensus round. Do not add a Codex
worker by default. Use one only when the user explicitly asks for it or a Qwen
slot fails a measured readiness/startup check and an independent replacement is
still required; report that fallback instead of silently changing the pool.
After independent reports complete, run one tracked consensus round: Claude
critiques both Qwen reports, and each Qwen worker fact-checks at least one other
report's cited evidence and intent ledger. If Claude is unavailable, keep the
two Qwen reports and require the Codex coordinator to perform a full independent
review before adjudication; report the degraded topology.

Every cross-reviewer must:

- read this skill from the absolute path supplied in its task;
- compare the other report against the live PR body and intent ledger;
- verify claimed predecessor/successor and merge-order relationships;
- challenge missing evidence and unsupported claims.

In that round, each Qwen reviewer fact-checks cited evidence and intent-ledger
claims and may return provisional candidate changes. The Claude reviewer applies
the actionable-finding and severity rules to both Qwen reports and returns a
proposed agreed finding set, author questions, and rejected candidates. The
Codex coordinator independently verifies that proposal and owns the final set.

Do not pool evidence across different PRs. In a multi-PR request, finish and
account for every PR separately.

## 6. Supervise workers continuously

- Confirm task-specific startup within about 60 seconds.
- Recheck active workers every 2–5 minutes or after orchestration timeouts.
- Recover unsubmitted prompts once; do not leave idle workers described as
  “reviewing.”
- Require valid lifecycle completion and inspect every report artifact.
- Dispatch the consensus round immediately after all three reports for a PR
  arrive. In the documented no-Claude degraded topology, dispatch it after both
  Qwen reports and the coordinator's independent review are complete.
- Keep the user updated during ongoing work without waiting for a status query.

## 7. Decide and submit the GitHub review

Before submitting, fetch again and verify that PR state and head SHA are
unchanged. If the head changed, review the new delta and refresh consensus.

Before every GitHub write, select and verify the intended reviewer account in
the coordinator's isolated `GH_CONFIG_DIR`; do not mutate the shared global
account. Use the account required by the user or repository rules. A review
submitted by a hub bot, GitHub App, worker account, or PR author is not
interchangeable with a review expected from the intended human account.

Match the user's or repository's language; do not switch to English without a
reason. Unless repository rules say otherwise:

- no in-scope actionable finding: submit `APPROVE`;
- verified blocking finding in the current PR: submit `REQUEST_CHANGES`;
- unresolved intent, dependency, or delivery-order question: submit a
  non-blocking question/comment;
- reporting-only request: do not write to GitHub.

When a re-review clears the last blocker, submit a fresh `APPROVE` on the
current head. Do not leave the final state as `COMMENTED` merely because the
review body says "no blockers", "looks good", or equivalent. If GitHub rejects
approval because the selected reviewer is the PR author or lacks permission,
report that exact blocker; never claim the PR was approved.

Explain findings naturally without internal tracking IDs. For approvals,
briefly state the verified head and that declared scope, known gaps, and linked
follow-up work were considered.

## 8. Audit the submitted GitHub artifact

Submission is not complete when the write call returns success. Immediately
read the live PR back and verify all of the following:

- the current PR head SHA still equals the reviewed SHA;
- the review object exists under the intended reviewer login;
- its state is exactly the intended state: `APPROVED`, `CHANGES_REQUESTED`, or
  `COMMENTED`;
- the review is attached to the reviewed commit;
- required inline comments exist at the intended current-head locations;
- review threads that were answered or fixed have the intended resolved/open
  state;
- the review artifact has a visible GitHub URL that can be handed to the user.

Use live GitHub data that distinguishes these different artifact types:

- pull-request reviews (`pulls/<number>/reviews`);
- inline review comments (`pulls/<number>/comments`);
- ordinary issue/PR comments (`issues/<number>/comments`);
- GraphQL review threads and `reviewDecision`.

Do not treat one artifact type as another. In particular:

- a bot/App `COMMENTED` review is not a personal-account review;
- an inline comment or resolved thread is not an `APPROVE`;
- an ordinary PR comment is not a submitted review;
- prose saying there are no blockers is not approval;
- a historical review on an old head does not finish the current-head review.

Before reporting completion, state the verified reviewer login, review state,
reviewed head SHA, and artifact URL. If any of those cannot be verified, report
the review as not submitted or not approved. Never summarize ambiguous API
history as "review submitted" without identifying whose review and which
state it represents.

## 9. Correct mistakes immediately

If a submitted review ignored author intent, follow-up ownership, or current
head state:

1. Dismiss the incorrect review immediately when permissions allow.
2. Submit the corrected review in the repository's language.
3. Verify the final GitHub decision and latest review state.
4. Tell the user exactly what was withdrawn and what replaced it.

Do not stop at an apology while the incorrect blocking review remains active.
