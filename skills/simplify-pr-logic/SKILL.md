---
name: simplify-pr-logic
description: Analyze a pull request against origin/main for high-leverage logic simplifications, deeper PR-anchored refactors, clearer module ownership, and interfaces that prevent misuse. Use only when explicitly invoked to generate and adversarially test refactoring hypotheses; do not use for generic code review, correctness, style, lint, security, test coverage, or repository-wide cleanup.
---

# Simplify PR Logic

Analyze first. Do not edit code unless the user explicitly authorizes implementation.

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
- Preserve user changes. Never stash, discard, reset, or rewrite work to prepare the analysis.

## 1. Establish The Baseline

1. Read the repository instructions and the smallest set of authoritative design, product, and testing
   docs needed to interpret the changed code.
2. Inspect branch and worktree state.
3. Fetch `origin/main`. If fetching is unavailable, continue only when `origin/main` exists and report
   that its freshness is unverified.
4. Measure ahead/behind state with merge-base semantics. If `HEAD` is behind `origin/main`, stop and
   report the exact state. Ask permission before merging `origin/main`; never merge with a dirty
   worktree or resolve conflicts by assumption. After an authorized successful merge, restart the
   analysis from the new diff.
5. Use `origin/main...HEAD` as the PR comparison. Inventory commits, changed paths, renames,
   deletions, and the complete diff.
6. Inventory staged, unstaged, and untracked files separately. Label them local-only and do not
   misrepresent them as part of the PR.
7. If there is no PR diff and no relevant local-only work, report that and stop.

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

## 3. Generate Independent Hypotheses

Use at least three subagents. Keep their contexts independent until critique:

1. Start two hypothesis generators concurrently from raw repository evidence:
   - **Flow generator:** simplify control flow, data flow, state, policy propagation, and branching.
   - **Interface generator:** challenge responsibility placement, module boundaries, abstractions,
     feature-flag design, invalid states, and misuse-prone interfaces.
2. Start one critic concurrently. Give the critic the raw change, relevant repository constraints,
   and target threads, but no generated hypotheses. Ask it to independently map invariants, hidden
   consumers, boundary responsibilities, and reasons tempting refactors may fail.
3. Do not tell any agent the expected answer or another agent's conclusions.
4. Require read-only work. Subagents must not edit files.

Require each generator to return only material candidates using this schema:

- title and PR anchor
- current logic thread and reasoning burden
- proposed responsibility, flow, or interface
- concepts, states, branches, or misuse paths removed
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
  total conceptual complexity or demonstrated misuse risk; and has bounded, understood costs.
- **Rejected:** tempting but contradicted by evidence, dependent on speculative generalization, or
  likely to move or increase complexity.
- **Unresolved:** potentially high-leverage but blocked by ambiguous intent or missing evidence.
  State exactly what evidence would resolve it.

Rank accepted hypotheses by net leverage: reasoning and misuse reduction relative to implementation
cost and behavioral risk. Omit low-value cleanup.

Classify a discovered bug separately only when there is a concrete failing scenario, violated
invariant, or authoritative contract mismatch. Keep it anchored to the investigated logic thread.
Do not use a bug as permission for a broader sweep.

## 6. Report

Produce a synthesized report, not raw subagent transcripts.

### Scope and evidence

State the base, synchronization and freshness status, commits and files reviewed, local-only work,
anchored threads followed, authoritative evidence used, and focused checks run.

### Accepted hypotheses

For each accepted hypothesis, provide:

1. **Current model:** the end-to-end thread and why it is hard to reason about.
2. **Proposed model:** the new responsibility, flow, or interface shape.
3. **Simplification:** the concepts, states, branches, ownership crossings, or misuse paths removed.
4. **Evidence:** support, strongest counterargument, and adjudicated verdict.
5. **Safety:** preserved invariants and contracts, affected neighborhood, risks, and confidence.
6. **Execution:** a small implementation sequence with focused verification points.

### Bugs

Report proven bugs separately with the failing scenario or violated invariant. Do not edit unless
authorized.

### Unresolved hypotheses

Include only material opportunities and the evidence needed to decide them.

### Strongest rejected hypotheses

Briefly explain the most plausible rejected alternatives and the evidence that ruled them out.

If no hypothesis survives critique, say so directly. A well-supported no-change result is preferable
to manufacturing a refactor.

## Authorized Follow-Up

If the user explicitly authorizes implementation, change only accepted hypotheses within the agreed
scope. Preserve repository architecture and migration rules, verify each coherent step, and re-read
the final diff for displaced rather than removed complexity. Do not silently implement unresolved or
rejected ideas.
