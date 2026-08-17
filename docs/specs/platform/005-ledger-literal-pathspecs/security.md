---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-26"
---

# Security Review: Neutralize pathspec magic in the ledger git-mv primitives

## Summary

**Findings:** 0 Critical · 0 Notable · 2 Advisory (both resolved in plan)

Dual-lens review of spec.md (requirements-gap lens) and plan.md (design-flaw
lens). This is a security-hardening spec that closes a pathspec-injection
exposure; the plan correctly and completely implements the mitigation and folds
in both spec-phase Advisories — so this run adds no new findings and marks
Findings 1 and 2 resolved. No spec↔plan misalignment. LINDDUN N/A (no PII /
Credentials / Session data). The sibling exposure in the partition group is an
accepted, tracked residual outside this spec's platform scope (issue #107).

**Re-run delta:** Findings 1 (test breadth) and 2 (per-call scoping) — now
**resolved** by plan Design Decisions 1/3/4 and Task 2. No new or unchanged-open
findings.

## Coverage

- spec.md — reviewed 2026-07-26 (requirements-gap lens)
- plan.md — reviewed 2026-07-26 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | — |
| Credentials | No | — |
| Session data | No | — |
| Internal-only | Yes | Repo-relative paths, git-tracked file/dir paths, spec/blueprint content — all project-internal |
| Public | No | — |

## Findings

### 1. Regression test must span both primitives and multiple magic families

- **Severity:** Advisory
- **Description:** AC #1 enumerates several distinct pathspec-magic forms
  (`:(glob)…`, `:/…`, `:(exclude)…`, `:!…`) and AC #5 requires a regression
  test that "covers the reported scenario." A single test exercising one
  primitive with one magic syntax would leave neutralization unproven for the
  other primitive and other magic families — a silent-regression risk if a
  later refactor re-neutralizes only one call, or if only the long `:(…)` form
  is covered while a leading-`:` short form slips through.
- **Suggestion:** In the plan's test design, exercise both `cmd_rename_tracked`
  and `cmd_move_spec_dir`, covering at least a leading-`:` short form
  (e.g. `:!…` / `:/…`) and a `:(…)` long form (e.g. `:(glob)…`), asserting
  rc 1 + the "not tracked" refusal. Reuse `rename_git_fixture` /
  `move_git_fixture` + `run_jimledger_in` (see research.md Anchors).
- **Route:** Plan
- **Relates to:** AC #1, AC #5
- **Resolution (plan reviewed):** Addressed — plan Design Decision 4 mandates a
  long-form `:(glob)…` case for `cmd_rename_tracked` and a short-form `:/…` case
  for `cmd_move_spec_dir`, and Task 2 adds both with rc-1 + `not tracked`
  assertions across both primitives.

### 2. Scope the neutralizer per-call, never process-wide

- **Severity:** Advisory
- **Description:** AC #2 requires literal treatment of untrusted paths at the
  git calls. If the implementation reaches for a process-wide mechanism
  (an exported `GIT_LITERAL_PATHSPECS=1` covering the whole script, or a repo
  `git config`), it risks unintended interaction: an intentional-glob pathspec
  that later enters the script would silently stop matching. Research flagged
  `scripts/jim-deps-refs.sh`'s intentional literal-glob pathspecs
  (`git ls-files -- 'skills/*/SKILL.md'`) as the concrete instance of a pattern
  that global neutralization breaks — an availability/correctness regression,
  not a confidentiality one, but worth pinning at design time.
- **Suggestion:** Apply `--literal-pathspecs` / `GIT_LITERAL_PATHSPECS`
  narrowly to the four specific git invocations in the two primitives (per-call
  flag, or a tightly-scoped env prefix on each command) — never a script-wide
  export or repo `git config`. Record the per-call scoping as a plan design
  decision.
- **Route:** Plan
- **Relates to:** AC #2
- **Resolution (plan reviewed):** Addressed — plan Design Decision 1 selects the
  per-call `git --literal-pathspecs <subcmd>` flag form precisely because it
  cannot be hoisted to a process-wide export; Rejected-alternative text names the
  `jim-deps-refs.sh` global-neutralization footgun this avoids.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No principal/identity boundary; the primitives operate on local repo paths at the invoking user's privilege. |
| Tampering | Yes | The core threat — an untrusted path carrying pathspec magic could alter which tracked entries the `git ls-files` check and `git mv` act on (proven: `:(glob)…/*` spuriously matches). Plan Task 3 implements the mitigation across all four calls via `git --literal-pathspecs`; remaining guards (sibling/slug/containment/git-mv-failure) bound residual reach; Task 2 pins it with a per-primitive regression. Fully specified and implemented — no residual. |
| Repudiation | N/A | Git history is the audit trail for the move; the primitives add no auditable claim requiring non-repudiation. |
| Information Disclosure | No | `git ls-files` output is consumed only in an emptiness test (`[[ -z … ]]`), never surfaced; error messages echo the caller's own input path, not git's file enumeration. The fix incidentally reduces raw-git-error echo: a magic path now fails the tracked-check before reaching `git mv`, so git's `fatal: bad source` line no longer surfaces for magic inputs (dev-time stderr, trusted terminal regardless). |
| Denial of Service | No | Single dev-time invocation; a broad glob's cost is negligible and moot post-fix (literal paths do not expand). |
| Elevation of Privilege | N/A | Scripts run at the invoking user's privilege; no privilege boundary is crossed. Filesystem-scope over-reach via magic is bounded by realpath containment + neutralization (covered under Tampering). |

## Artifact Misalignment

No misalignment. The plan faithfully implements every spec AC, including the
security-relevant ones: AC #1/#2 (literal treatment across all four calls) →
plan Tasks 2–3; AC #4 (invariant restoration, project-wide) → plan Task 4 and
the Interface Contract's reworded invariant text. The plan also gets the
fail-closed→fail-open sequencing right (Design Decision 5): the invariant is
restored to the blueprint only after the code conforms (Task 4 depends on Task 3
green), so the blueprint never asserts a rule the code does not yet honor.

## Routing Recommendations

### Plan amendments
- None outstanding. Findings 1 and 2 were routed to Plan and are now resolved in
  plan.md (Design Decisions 1/3/4, Task 2) — no further amendment required.

### Candidate issues
- None. No finding routes to `Issue`; the sibling partition-group exposure is already tracked as issue #107 (filed during `/jim:research`), not re-filed here.
