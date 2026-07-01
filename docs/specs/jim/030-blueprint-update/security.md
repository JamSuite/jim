---
spec: "docs/specs/jim/030-blueprint-update/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-01"
---

# Security Review: Blueprint update from review

## Summary

**Findings:** 0 Critical · 3 Notable · 2 Advisory — all resolved by the spec + plan.

Dual-lens review (spec requirements-gap + plan design-flaw). STRIDE applied;
LINDDUN N/A (no PII / Credentials / Session data). Third pass, after the spec was
expanded to add the **ad-hoc (out-of-pipeline) update trigger**. The new ad-hoc
surface raised one Notable design flaw — git-ref validation in the `diff-range`
verb (Finding 5) — now folded into plan DD6 / Task 4. Findings 1–4 remain resolved.

**Re-run delta (3rd pass — ad-hoc surface):** New — Finding 5 (Notable), now applied
to the plan. Resolved / unchanged — Findings 1–4 (still resolved).

## Coverage

- spec.md — reviewed 2026-07-01 (requirements-gap lens)
- plan.md — reviewed 2026-07-01 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | jim's own development artifacts; commit-author identity is incidental, not processed by the update. |
| Credentials | No | Not handled as credentials — but the ingested build diff may *incidentally* contain secret-looking values a developer committed (see Finding 1). |
| Session data | No | None. |
| Internal-only | Yes | Review verdict, ledger metrics, git diff of the project's own code. |
| Public | Yes | `000-blueprint/spec.md` is a committed, shareable repo artifact — the output sink. |

## Findings

### 1. Secret-looking values from the build diff may be persisted into the committed blueprint

- **Severity:** Notable
- **Description:** The update ingests the build diff and ledger as evidence and writes the result into `<group>/000-blueprint/spec.md` — a committed, potentially public artifact. Spec 029's `/jim:blueprint` scrubs secret-looking values to a `secret-looking value at <path:line>` placeholder when it scans code, but 030's ACs assert only the *injection* boundary (AC #9: ingested content is data, not instructions). They do not carry forward 029's secret-**non-persistence** invariant for diff/ledger-sourced content. On the `auto_blueprint` path (write without human review) — especially if paired with an auto-commit — a secret present in a build diff could be written into the blueprint and committed with no scrub gate.
- **Suggestion:** Add an AC that the update carries forward spec 029's secret-scrubbing invariant: never persist raw secret-looking values drawn from the diff / ledger / commit content into the blueprint; redact to the `secret-looking value at <path:line>` placeholder. Require it to hold on the unattended `auto_blueprint` path.
- **Route:** Spec
- **Relates to:** AC #9; Handoff Insight 1
- **Resolution:** Applied — spec AC #11 (never persist secret-looking values; redact to placeholder, enforced on the `auto_blueprint` path) + plan DD5 / Task 5. **Resolved.**

### 2. A blueprint auto-commit must be path-scoped to prevent staging unintended files

- **Severity:** Notable
- **Description:** The spec's open question leaves commit ownership undecided; one resolution (Handoff Insight 1) commits the refreshed blueprint. The existing `commit-review` verb (`jimledger.sh:103-113`) is strictly path-scoped — `git add -- review.md ledger.md`, a `--` guard, never `git add -A`. A blueprint commit that used `git add -A` or a broad path could stage unrelated working-tree changes — or an attacker-planted file — into an automatic, possibly unattended (`auto_blueprint`) commit.
- **Suggestion:** If the plan resolves commit ownership by committing the blueprint, mandate path-scoping that mirrors `commit-review`: stage only the literal `<group>/000-blueprint/spec.md` (plus its `ledger.md` if instrumented), with a `--` guard, never `git add -A`. Record this as a design constraint for the plan.
- **Route:** Plan
- **Relates to:** Open Question (commit ownership); Handoff Insight 1
- **Resolution:** Applied — plan DD3: a dedicated path-scoped `commit-blueprint` verb (`git add -- spec.md ledger.md`, `--` guard, never `git add -A`). **Resolved.**

### 3. Consume the verdict and metrics through the shape-validated ledger channel

- **Severity:** Advisory
- **Description:** AC #2 has the update consume the review verdict, ledger, and diff. The ledger's `metrics` channel is shape-validated (spec 028: `review_alignment` validated against the verdict enum, counts against non-negative integers), whereas raw `review.md` / ledger prose is untrusted free text. If the update derives the verdict from raw prose rather than the validated `jimledger.sh metrics` channel, a tampered ledger or review could present an out-of-enum or misleading verdict that steers the update.
- **Suggestion:** Specify that the update reads the verdict and metrics through `jimledger.sh metrics` (the trusted, shape-validated channel), and treats any raw review / diff / ledger text purely as descriptive evidence subject to AC #9.
- **Route:** Plan
- **Relates to:** AC #2, AC #9
- **Resolution:** Applied — plan DD5: the verdict/metrics are read via the shape-validated `jimledger.sh metrics` channel; the diff is treated as untrusted data. **Resolved.**

### 4. Make the blueprint update auditable (repudiation)

- **Severity:** Advisory
- **Description:** A blueprint update mutates a committed spec with no inherent record of which review triggered it or when — most acutely under `auto_blueprint`, where no human is in the loop. Without a ledger trace, a blueprint change cannot be attributed to the review and build range that caused it.
- **Suggestion:** Record the update's run on the ledger — a `blueprint` stage event, or a sub-event of the review stage — so each blueprint change is traceable to its causing review. (Aligns with research Recommendation 4.)
- **Route:** Plan
- **Relates to:** Handoff Insight 1; research Rec 4
- **Resolution:** Applied — plan DD4: the update is its own `blueprint` ledger stage; `commit-blueprint` commits `spec.md` + `ledger.md` together. **Resolved.**

### 5. `diff-range` git-ref validation is underspecified — `is_valid_id` is the wrong validator for git refs

- **Severity:** Notable
- **Description:** Plan DD6 / Task 4 validate the ad-hoc adapter's `<base>` / `<head>` refs with `is_valid_id` before `git diff`. The instinct is right (foreclose option injection) but the validator is wrong: `is_valid_id`'s charset is `[A-Za-z0-9._-]` — **no `/`** — so it rejects legitimate git refs (`origin/main`, `feat/blueprint`, `release/1.2`), breaking `--since <branch>`. Loosening it naively to admit `/` risks re-opening injection (a leading `-` parsed as an option, `..`, whitespace / control, or git-special `~^:?*[\`).
- **Suggestion:** Give `diff-range` a git-ref-appropriate check instead of reusing `is_valid_id`: reject a leading `-` and any whitespace / control / git-special character, then resolve and verify the ref through git itself — `git rev-parse --verify --end-of-options "<ref>^{commit}"` (or a minimal safety gate + `git check-ref-format`). Guard the diff invocation with `--end-of-options` / `--` so a ref can never be parsed as an option or pathspec — consistent with `commit-review`'s existing `--` guard. Prefer resolving each ref to a SHA before the diff so the range is over validated commit ids.
- **Route:** Plan
- **Relates to:** AC #3; plan DD6, Task 4
- **Resolution:** Applied — plan DD6 rewritten (ref-safety gate + `git rev-parse --verify --end-of-options "<ref>^{commit}"` resolution to a SHA; `--end-of-options` / `--` guarded diff; no `is_valid_id` for refs) and Task 4's tests assert a `/`-ref resolves while a `-`-leading / metacharacter ref is rejected with no git run. **Resolved.**

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 (a tampered ledger/review presenting a false verdict). |
| Tampering | Yes | Findings 2, 3 (untrusted diff/ledger evidence; commit scope); Finding 5 (git-ref handling in `diff-range`). |
| Repudiation | Yes | Finding 4 (blueprint changes untraceable to their causing review). |
| Information Disclosure | Yes | Finding 1 (secret-looking values persisted into a committed artifact). |
| Denial of Service | No | No issues found — the update runs once per review (not looped); `require_blueprint`'s held completion is developer-gated and the knob is relaxable, so a persistently failing update degrades to a stuck-but-recoverable gate, not resource exhaustion. |
| Elevation of Privilege | Yes | Finding 2 (a broad commit staging unintended files); Finding 5 (a `-`-leading or crafted ref reaching `git` as an option). The update otherwise runs with the developer's own session permissions and, reusing `/jim:blueprint`, adds no new capability beyond the (path-scoped) commit. |

## Artifact Misalignment

No misalignment. The plan's design preserves every spec requirement it touches —
the targeted diff (AC #3), the commit (AC #10), the `require_blueprint` gate
(AC #5), and the secret-scrub (AC #11) each map to a design decision that honors
the spec's stated behavior. (`auto_blueprint` bypassing the approval step is the
spec's own AC #4 exception, not a design/spec conflict.)

## Routing Recommendations

### Spec amendments
- Finding 1 — **applied**: spec AC #11 (secret non-persistence; redact to placeholder; enforced on the `auto_blueprint` path).

### Plan amendments
- Finding 2 — **applied**: plan DD3 (path-scoped `commit-blueprint`; never `git add -A`).
- Finding 3 — **applied**: plan DD5 (verdict/metrics via the shape-validated `jimledger.sh metrics` channel).
- Finding 4 — **applied**: plan DD4 (blueprint ledger stage for auditability).
- Finding 5 — **applied**: plan DD6 rewritten to a git-ref-appropriate validation (ref-safety gate + `git rev-parse --verify --end-of-options` → SHA; `--end-of-options` / `--` guard; not `is_valid_id`); Task 4 tests updated (`/`-ref resolves; `-`-leading / metacharacter ref rejected).

### Candidate issues
No findings route to `Issue` — all route to Spec or Plan.
