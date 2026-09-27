---
name: simplify-pr-logic
description: Create or reuse a pull request, sync its branch with the latest origin/main, then apply and commit verified PR-anchored logic simplifications, bug fixes, and cleanup of obsolete implementation artifacts. Use only when explicitly invoked; not for generic code review, correctness, style, lint, security, test coverage, or repository-wide cleanup.
---

# Simplify PR Logic

Prepare and synchronize the PR before analysis. Invocation authorizes routine Git and GitHub
operations for that PR: fetch, a non-rewriting merge from the latest `origin/main`, creation of a
missing PR, implementation of accepted simplifications and proven bug fixes, removal or trimming of
obsolete PR-related implementation artifacts, commits of those changes, and normal push. Carry the
work through verification and commit without a separate implementation approval. Honor an explicit
analysis-only or no-push request. Invocation does not authorize merging the PR, force-pushing, or
discarding user work. Ask before making a product-sensitive choice; continue independent accepted
work while that choice remains unresolved.

Optimize for the reasoning burden of the complete logic thread, not line count. Prefer fewer concepts,
states, branches, ownership crossings, temporal constraints, and facts held in mind. Generalize only
when doing so collapses genuinely identical policy. Split logic only when the resulting responsibilities
are cohesive and the end-to-end flow becomes easier to reconstruct.

## Guardrails

- Anchor every investigation and hypothesis to a concept introduced, changed, or newly exposed by
  `origin/main...HEAD`.
- Follow an anchored thread as far as its behavior requires. Inspect configuration, feature flags,
  callers, callees, propagation, state transitions, interfaces, tests, and cleanup even when they are
  several dependency edges from the diff.
- Do not turn a thread into an unrestricted architecture or repository review.
- Preserve intended observable behavior and external contracts. Freely challenge private interfaces,
  abstractions, module ownership, and control flow.
- Treat a behavior change as a product decision unless the investigation proves a bug.
- Consider a stronger interface only when it reduces caller reasoning and prevents a demonstrated
  misuse, invalid state, or ordering hazard on an anchored thread.
- Treat existing abstractions as evidence, not requirements. Preserve earned boundaries, validation,
  security, persistence, and test seams when they still carry real responsibilities.
- Exclude formatting, naming nits, lint, generic correctness review, test-coverage commentary,
  security review, and unrelated cleanup.
- Preserve pre-existing staged, unstaged, and untracked user work throughout the workflow. Never
  stash, discard, reset, rewrite history, or include that work in a skill-generated commit without
  explicit authorization. Never create a duplicate PR.

## 1. Prepare The PR And Establish The Baseline

1. Read repository instructions and the smallest set of authoritative design, product, and testing
   docs needed to interpret the changed code. Inspect branch, worktree, remote, and local changes.
2. Resolve the target PR from a user-supplied URL or number, then from the current non-default
   branch. Reuse an open PR for that head; if several PRs or branches are plausible, ask which one.
   Confirm its base is `main`. Do not retarget a stacked or exceptional PR by assumption.
3. Fetch `origin/main` and the existing PR head, if any. Record their commit IDs. If the fetch
   fails, stop: the requested latest-main synchronization cannot be verified.
4. Inventory staged, unstaged, and untracked files separately and retain this baseline for final
   staging checks. Keep pre-existing local work out of synchronization and implementation commits.
   Use a clean worktree for the target branch when one exists. If local work prevents a safe merge
   or cannot be separated from required edits, report the exact blocker; do not absorb it.
5. Compare the target branch with the fetched `origin/main` using merge-base semantics. If behind,
   merge `origin/main` into the branch without rebasing or rewriting history. Resolve only conflicts
   whose intended result is clear from current code and contracts; stop on ambiguous or
   product-sensitive conflicts. For an existing PR, push the synchronized branch normally. If its
   remote head advanced, fetch and integrate it before retrying the push.
6. If no PR exists, require a non-default branch with a committed diff against `origin/main`.
   Push that branch normally, then create one non-draft PR targeting `main` with a title and body
   grounded in the existing change. Do not create an empty or placeholder PR. Confirm the PR URL,
   base, and remote head commit. If the branch cannot be pushed or the PR cannot be created, report
   the exact blocker and do not substitute another branch or PR. Attach a newly created PR to
   the task when the harness supports PR artifacts.
7. Restart the analysis from the synchronized `origin/main...HEAD` diff. Inventory commits,
   changed paths, renames, deletions, and the complete diff. Do not rely on a pre-sync file list or
   hypothesis. If there is no PR diff, report that and stop; describe any local-only work
   separately.

When available, inspect the PR description, linked issue or spec, commit messages, tests, contracts,
and repository guidance. Prefer executable contracts and current authoritative docs over stale PR
narrative. Mark intent-dependent hypotheses unresolved when intent remains ambiguous.

## 2. Map Anchored Logic Threads

For each meaningful changed concept:

1. State the apparent intent and observable invariants.
2. Trace where input enters, policy is chosen, state changes, data propagates, and output or side
   effects leave.
3. Identify the modules and interfaces that own each decision.
4. Note complexity signals:
   - duplicated policy or state
   - branching spread across layers
   - feature flags or configuration leaking through unrelated modules
   - invalid states or call ordering permitted by an interface
   - callers assembling knowledge the callee should own
   - pass-through layers or abstractions without a meaningful seam
   - mixed responsibilities or temporal coupling
   - generalized machinery serving only speculative cases
5. Record the concrete PR anchor for every location included in the thread.

Do not equate unfamiliarity with complexity. Understand the full thread before proposing a shape.

Also inventory implementation artifacts introduced, changed, or made obsolete by the PR, including
plans, task checklists, experiment notes, scratch reports, temporary scripts, and one-off fixtures.
Inspect their contents, references, consumers, and repository retention rules. Include artifacts
outside the diff only when there is a concrete link to this PR; do not sweep unrelated old docs.

For each artifact, determine whether it still helps someone operate, maintain, debug, reproduce,
extend, or understand the shipped system:

- Remove completed plans, abandoned approaches, duplicated explanations, transient logs, and other
  artifacts with no remaining use. A filename or age alone is not evidence that a file is disposable.
- If a temporary document contains durable decisions, constraints, or reproducible evidence, move
  only that useful information into the appropriate maintained documentation before deleting or
  trimming the rest. Update references so cleanup leaves no broken links or consumers.
- Preserve active plans, useful experiment methods/results, architectural rationale, runbooks,
  migration guidance, required records, and still-used scripts or fixtures. If future value or
  ownership is uncertain, retain the material and classify the cleanup as unresolved.

Treat supported artifact cleanup as an actionable finding even when no code simplification survives.
Do not add a new checked-in plan or report merely to document this workflow.

## 3. Generate Independent Hypotheses

Use at least three subagents. Keep their contexts independent until critique:

1. Start two hypothesis generators concurrently from raw repository evidence:
   - **Flow generator:** simplify control flow, data flow, state, policy propagation, and branching.
   - **Interface generator:** challenge responsibility placement, module boundaries, abstractions,
     feature-flag design, invalid states, and misuse-prone interfaces. Also assess the artifact
     inventory for obsolete implementation leftovers and useful information that must survive.
2. Start one critic concurrently. Give the critic the raw change, relevant repository constraints,
   and target threads, but no generated hypotheses. Ask it to independently map invariants, hidden
   consumers, boundary responsibilities, documentation retention needs, and reasons tempting
   refactors or deletions may fail.
3. Do not tell any agent the expected answer or another agent's conclusions.
4. Keep these discovery and critique passes read-only. The parent applies verified findings later.

Require each generator to return only material candidates using this schema:

- title and PR anchor
- current logic thread and reasoning burden
- proposed responsibility, flow, or interface
- concepts, states, branches, misuse paths, or obsolete artifacts removed
- supporting evidence
- strongest disconfirming evidence
- observable invariants and contracts to preserve
- affected neighborhood and likely implementation cost
- confidence

Keep bugs separate from simplification hypotheses.

## 4. Challenge The Candidates

The parent agent must inspect the evidence directly. Do not accept a hypothesis by vote or copy a
subagent report without verification.

1. Deduplicate the generators' candidates and discard style-only or unanchored suggestions.
2. Trace callers, implementations, tests, registrations, persistence, configuration, and external
   boundaries needed to test each material claim.
3. Use focused existing tests or read-only checks when they can prove an invariant or reproduce a
   suspected bug. Do not run a broad full suite by default.
4. Send the surviving candidate set to the already-grounded critic in a follow-up. Ask it to
   disprove each candidate with counterexamples, hidden costs, violated boundaries, ambiguous intent,
   or evidence that total-system complexity would increase.
5. Re-check disputed evidence yourself and adjudicate from source artifacts. Agreement among agents
   is not proof.

Use history or blame only when the current source cannot explain an important constraint. Historical
presence alone does not justify complexity.

## 5. Classify Hypotheses

Classify each material candidate:

- **Accepted:** concretely PR-anchored; preserves intended behavior and external contracts; reduces
  total conceptual complexity or demonstrated misuse risk, or removes implementation artifacts
  shown to have no remaining use; and has bounded, understood costs.
- **Rejected:** tempting but contradicted by evidence, dependent on speculative generalization, or
  likely to move or increase complexity.
- **Unresolved:** potentially high-leverage but blocked by ambiguous intent or missing evidence.
  State exactly what evidence would resolve it.

Rank accepted hypotheses by net leverage: reasoning and misuse reduction relative to implementation
cost and behavioral risk. Include supported artifact cleanup; omit cosmetic churn.

Classify a discovered bug separately only when there is a concrete failing scenario, violated
invariant, or authoritative contract mismatch. Keep it anchored to the investigated logic thread.
Do not use a bug as permission for a broader sweep.

## 6. Apply, Verify, And Commit

1. Implement accepted simplifications, proven bug fixes with a clear intended result, and supported
   artifact cleanup in small coherent steps. Preserve repository architecture and migration rules.
   Do not implement rejected or unresolved ideas, and do not stop at an implementation proposal.
2. Verify each step with relevant existing checks. For a proven bug, reproduce the failing scenario
   and verify the fix; add a focused regression test when it provides lasting value. Run required
   repository checks and tests appropriate to the affected behavior. For artifact cleanup, check
   references and affected documentation builds or script consumers where applicable.
3. Re-read the complete resulting PR diff and affected threads. Confirm that complexity was removed
   rather than displaced, contracts remain intact, useful documentation survived, and no temporary
   artifacts from this workflow remain. Reassess any finding invalidated during implementation.
4. Compare the worktree and index with the initial local-work inventory. Stage only changes made by
   this workflow, using explicit paths or selected hunks. Inspect the staged diff before each commit;
   never let pre-existing staged work enter the commit. If it cannot be safely separated, report
   the blocker rather than committing a mixture.
5. Commit verified changes with descriptive messages, grouping related code, tests, and docs.
   Do not amend existing commits, create empty commits, or bypass failing hooks. If a required check
   fails or cannot run, diagnose it and report any remaining blocker; do not label unverified work
   complete. Commit independent verified changes only when they remain coherent on their own.
6. Push the new commits normally to the same PR branch unless the user requested otherwise. If the
   remote head advanced, fetch and integrate it without rewriting history, inspect the incoming
   changes, and repeat affected checks before retrying. Stop if concurrent changes leave intent or
   verification unresolved. Confirm the remote PR head matches the intended local commit; if push
   fails, preserve local commits and report the blocker and their hashes.
7. Check final repository status and confirm pre-existing local work is preserved. If no actionable
   finding survived, make no implementation commit and report the no-change result.

## 7. Report The Result

Produce a concise synthesized result, not raw subagent transcripts or a checked-in review report:

- PR URL, created/reused status, fetched `origin/main` commit, synchronization status, and reviewed
  scope. Identify any pre-existing local-only work excluded from commits.
- Applied simplifications and bug fixes: the previous reasoning burden or failing scenario, the
  resulting model, and the evidence and preserved contracts supporting the change.
- Artifacts deleted or trimmed, why they had no remaining use, and where any durable information
  was retained.
- Checks run and their outcomes, commit hashes, push status, and verified remote head. Distinguish
  completed work from uncommitted or unpushed work and explain any blockers.
- Material unresolved findings and the evidence needed to decide them; briefly include the strongest
  rejected alternatives when they help explain an important tradeoff.

If no actionable finding survives critique, say so directly. A well-supported no-change result is
preferable to manufacturing a refactor or deleting useful documentation.
