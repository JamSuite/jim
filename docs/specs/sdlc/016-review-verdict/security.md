---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-06-26"
---

# Security Review: Instrument /jim:review as a ledger stage and preserve verdict history

## Summary

**Findings:** 0 Critical · 2 Notable · 1 Advisory — all addressed in the plan;
the plan-phase (design-flaw) lens added no new findings.

Dual-lens review (spec requirements-gap + plan design-flaw) with a STRIDE
completeness sweep. The spec's two security-relevant moves (AC #4's
content-free→fixed-key reframe; AC #8's new commit capability) drove the original
findings; the plan implements all three — verdict validation (DD #1),
least-privilege `commit-review` (DD #3), commit hardening (DD #4) — with no
design flaws surfaced. LINDDUN is N/A — no PII, credentials, or session data.

## Coverage

- spec.md — reviewed 2026-06-26 (requirements-gap lens)
- plan.md — reviewed 2026-06-26 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Ledger holds stage events, durations, SHAs, and a verdict enum — no personal data. |
| Credentials | No | None handled. |
| Session data | No | None handled. |
| Internal-only | Yes | The ledger is project-internal dev telemetry (stage boundaries, durations, alignment verdict), committed to the project repo. |
| Public | No | Not intended for external exposure. |

## Findings

### 1. Verdict in the ledger is a forgeable trust signal — bound its value and keep `review.md` authoritative

- **Severity:** Notable
- **Description:** AC #4 preserves the no-key-*injection* property (the
  extraction key set stays code-literal) but says nothing about the verdict
  *value*. The ledger is explicitly untrusted, attacker-influenceable data
  (spec 026 `security.md` Finding 2: merged contributions can edit `ledger.md`).
  A tampered ledger could set `review_alignment=<arbitrary string>`, or append a
  forged `review finished alignment=aligned` line, and the metrics channel would
  surface it verbatim. Today every metrics value is a count or a SHA — and SHAs
  are validated (`jimfile.sh valid-id`) before use. The verdict would be the
  first metrics value with no validation and the first that encodes a *semantic
  trust claim* a future miner would act on ("this build ended aligned").
- **Suggestion:** Add an AC fixing the trust model: (a) the surfaced verdict is
  validated against the known vocabulary (`aligned` / `minor-drift` /
  `major-drift`), and `findings` against a non-negative integer, so a tampered
  ledger can express at most a bounded, well-formed value — never arbitrary
  text; and (b) `review.md` (itself committed per AC #8) is the authoritative
  verdict for any single review — the ledger trajectory is an advisory
  convenience, never the trust anchor. This extends Finding 7's "values are
  trusted-*origin*" to "values are also shape-validated on the way out."
- **Route:** Spec
- **Relates to:** AC #4, AC #3
- **Plan status:** Implemented — `cmd_metrics` validates the verdict against the
  enum and `findings` against `^[0-9]+$` (plan DD #1); `review.md` stays
  authoritative (plan Task 5). The exact enum match also forecloses
  metrics-output-line injection from a crafted ledger value.

### 2. `/jim:review` gains a commit capability — least-privilege it rather than broadening git access

- **Severity:** Notable
- **Description:** AC #8 requires `/jim:review` to create commits, but the
  review skill's `allowed-tools` grants no git access today (only scoped
  `jimledger.sh` / `jimfile.sh` / `jimconf.sh` / `index.sh` calls, `mkdir`,
  `Read`/`Write`/`Glob`/`Grep`, plus `Agent(investigator)`). `/jim:build`
  commits the ledger only because the **coder agent** legitimately carries broad
  Bash. The review surface is different: it runs inline and reasons over
  untrusted diff, commit, and ledger content (spec 026 Finding 2) and fans out
  investigators over the same. Granting that surface a broad `Bash(git *)` to
  satisfy AC #8 is excessive privilege on exactly the surface most exposed to
  attacker-influenced input.
- **Suggestion:** Capture a least-privilege constraint in the spec: the review
  commit is performed through a single audited, fixed-path entry point — not a
  broad git grant to the review skill. Concretely (plan's call), add a
  committing subcommand to `jimledger.sh` (which review already invokes under a
  scoped `Bash(... jimledger.sh *)` permission) that runs `git add -- <review.md>
  <ledger.md>` + `git commit` with an end-of-options `--` guard, literal paths
  inside the validated spec dir, and never `git add -A`. Note the trade-off: this
  overturns `jimledger.sh`'s documented "never commits" property — but confining
  the commit to one audited function with fixed paths is a far smaller blast
  radius than broad git in an LLM-driven review context.
- **Route:** Spec
- **Relates to:** AC #8, Insight 6
- **Plan status:** Implemented — `jimledger.sh commit-review` is the single
  audited, fixed-path entry point; review invokes it under its existing
  `jimledger.sh *` permission (no `allowed-tools` change, no broad git) — plan
  DD #3.

### 3. Harden the auto-commit: graceful failure and commit-message hygiene

- **Severity:** Advisory
- **Description:** AC #8 commits unconditionally at completion. Two
  implementation-level hardening points: (a) the commit can fail or behave
  unexpectedly (dirty/partial index, detached HEAD, mid-rebase, a pre-commit
  hook, no staged change on a no-op re-run) — it must degrade gracefully, since
  `review.md` is already written and its verdict must not be lost or left in a
  half-committed state; and (b) if the verdict or findings flow into the commit
  *message*, only the trusted-origin enum/counts belong there — never
  interpolated untrusted findings or diff text (spec 026 Finding 2). The
  auto-commit should also be transparent (report the created SHA), consistent
  with the VISION "not a black box" non-goal.
- **Suggestion:** Specify in the plan that a failed commit reports the failure
  and leaves `review.md` intact rather than aborting the review; that the commit
  message is built from trusted-origin values only; and that the resulting commit
  is surfaced to the developer.
- **Route:** Plan
- **Relates to:** AC #8
- **Plan status:** Implemented — plan DD #4: graceful failure (review.md left
  intact, failure reported), trusted-origin-only commit message, never
  `git add -A`; the path-scoped `git commit -- review.md ledger.md` also can't
  sweep an unrelated staged secret into the commit.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity/authentication boundary introduced; commits use the developer's existing git identity. |
| Tampering | Yes | Finding 1 (forgeable ledger verdict) — resolved in plan DD #1: enum/integer validation bounds the forged value *and* forecloses metrics-output-line injection. AC #8's commit makes the trajectory tamper-evident in git history. |
| Repudiation | No | No issues found — auto-committing the verdict trajectory strengthens the audit trail (drift→fix→re-review becomes a git-history record); residual pre-commit working-tree window is the standard git trust model. |
| Information Disclosure | No | No net-new disclosure — `review.md` is already developer-committed today; AC #8 only automates it. The plan's path-scoped commit (never `git add -A`) also can't sweep an unrelated staged secret in. |
| Denial of Service | No | No issues found — bounded ledger growth (~2 lines per run) and one commit per run. |
| Elevation of Privilege | Yes | Finding 2 (review acquires commit capability) — resolved in plan DD #3: a single audited `commit-review` subcommand, no broad git grant. |

## Artifact Misalignment

No misalignment. The plan faithfully implements the spec's security-relevant ACs:
AC #4/#9 → DD #1 (literal metric keys + value validation), AC #8 → DD #3 (one
pathspec-limited `git commit`, satisfying "single atomic commit"), AC #10 → DD #3
(least-privilege entry point, no `allowed-tools` change). No requirement is
weakened or contradicted by the design.

## Routing Recommendations

### Spec amendments
- Finding 1: ✓ applied — AC #9 bounds the surfaced verdict value (enum/integer
  validation) and declares `review.md` authoritative over the ledger verdict.
- Finding 2: ✓ applied — AC #10 constrains the review commit to a single
  audited, fixed-path entry point, not a broad git grant.

### Plan amendments
- Finding 3: ✓ applied — plan DD #4 specifies graceful commit-failure handling
  (review.md intact, failure reported), trusted-origin-only commit messages, and
  transparent reporting of the created commit.

### Candidate issues
No findings routed to `Issue` — all three are in-scope spec/plan amendments.
