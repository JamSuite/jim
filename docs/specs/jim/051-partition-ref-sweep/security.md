---
spec: "docs/specs/jim/051-partition-ref-sweep/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-23"
---

# Security Review: Partition ref sweep mis-rewrites typed refs on renumbering moves

## Summary

**Findings:** 0 Critical · 0 Notable · 2 Advisory

Dual-lens review: the bug spec (requirements-gap lens) and the plan (design-flaw lens). Both Advisory findings from the spec-phase run are addressed by the plan's design decisions; no new findings and no artifact misalignment surfaced. STRIDE swept; LINDDUN N/A (no PII, credentials, or session data in scope).

## Coverage

- spec.md — reviewed 2026-07-23 (requirements-gap lens)
- plan.md — reviewed 2026-07-23 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Spec archive refs and remap rows only |
| Credentials | No | — |
| Session data | No | — |
| Internal-only | Yes | Spec/issue/doc archive content, script-emitted remap files, ledger events |
| Public | Yes | Repo content is publishable plugin documentation; gate diffs are secret-scrubbed by existing 047/048 discipline |

## Findings

### 1. Fix must preserve the documented rewrite-guard doctrine

- **Severity:** Advisory
- **Description:** The candidate mechanisms (a greenfield flag on `rewrite-identity`, or a remap-aware skip) touch jim's only two in-place mutating verbs, whose safety properties are load-bearing and documented (ARCHITECTURE.md → partition extraction core): remap-as-whitelist (only a `group/NNN` present in the script-emitted remap is ever touched — spec 047 security Finding 8), guards-before-any-edit containment (valid-relpath, symlink-escape, tracked-only — spec 046 Findings 5/6), location-only output, and slug-gating of every `awk -v` input. The spec's ACs pin ref-correctness outcomes but not these preserved properties; a plan could satisfy the ACs while quietly widening a guard.
- **Suggestion:** The plan should name each preserved property as an explicit design constraint on whichever mechanism it selects — in particular, any new option surface must keep the whitelist semantics (a flag must only *narrow* what identity rewrites, never widen what refs may touch) and route all new inputs through the existing slug/format gates.
- **Route:** Plan
- **Relates to:** AC #1, Research & Architecture Handoff Insight 2
- **Plan disposition (2026-07-23):** Addressed — the plan's Constitution Check names each preserved property as an honored constraint; the interface contract keeps the guard pass, rc contract, and location-only output unchanged, and the flag is a fixed literal that only narrows the identity rewrite (never interpolated into the awk match). A typo'd or unknown `--*` token falls into the `<old>` position and fails the slug gate rc 2 — flag parsing is fail-closed by construction.

### 2. Conditional typed-ref skipping needs a misuse-resistant default

- **Severity:** Advisory
- **Description:** If typed-ref skipping lands as an opt-in flag passed by the split/merge prose flows, the failure mode inverts rather than disappears: a future flow edit (or a new ripple verb) that *forgets* the flag on a renumbering move silently reintroduces the corruption this spec fixes — same silent-integrity failure, new trigger. The prose flows are the fragile channel (the current bug shipped through exactly that channel).
- **Suggestion:** Prefer a shape where the safe behavior is structural rather than remembered — e.g. default the skip on whenever a remap governs the run, or pin each flow's documented invocation (flag included) with a composed-sweep regression test per arm so a prose drift fails the suite, not the archive.
- **Route:** Plan
- **Relates to:** AC #3, AC #4
- **Plan disposition (2026-07-23):** Addressed — the structural default was ruled out by AC 3 (rename tests unmodified), so the plan pins the composition three ways: composed-sweep regression tests per arm, the flag in all four canonical invocation lines, and a prose-pin test case that fails the suite if a future flow edit drops the flag. Narrow residual: the prose-pin greps the four existing lines only, so a *new* invocation site added without the flag is unwatched — generalizing the pattern is tracked as issue `20260723-skills-prose-invocation-lint`.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No external trust boundary — local developer tooling in a single trust domain |
| Tampering | Yes | The defect itself is an undetected-integrity failure of tracked content; the fix restores it. Findings 1–2 guard the fix's mechanism. Residual: no runtime detector for this corruption class — an accepted risk the spec documents in Out of Scope (the declined ref-integrity tell) |
| Repudiation | No | No issues found — `REWROTE` records, secret-scrubbed gate diffs, and ledger events already provide the audit trail |
| Information Disclosure | No | No issues found — location-only output doctrine covers both verbs; Finding 1 requires new code paths to keep it |
| Denial of Service | N/A | Local bounded execution — one awk pass per tracked file, spec ids capped at 999 |
| Elevation of Privilege | N/A | No privilege model — scripts run as the invoking developer |

## Artifact Misalignment

No spec↔plan inconsistencies found. Spot-checked: AC 3 (rename unchanged) against the plan's additions-only diff verification; AC 4 (prose/mechanism agreement) against Decision 3's retained order — with typed refs out of the identity pass, the documented order is one the engine genuinely guarantees; AC 1/2/5 map to tasks 2–4 without gaps.

## Routing Recommendations

No routing required — both findings are addressed in the plan as written (Decision 1 + Constitution Check for Finding 1; Decision 2 for Finding 2). The narrow prose-pin residual is tracked as issue `20260723-skills-prose-invocation-lint`.
