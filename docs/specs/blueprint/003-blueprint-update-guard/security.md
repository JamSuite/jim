---
spec: "docs/specs/blueprint/003-blueprint-update-guard/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-02"
---

# Security Review: Blueprint update guard

## Summary

**Findings:** 0 Critical · 4 Notable · 2 Advisory — all resolved by the spec + plan.

Dual-lens review (spec requirements-gap + plan design-flaw). STRIDE applied;
LINDDUN N/A (no PII / Credentials / Session data — consistent with the 030
review's classification). The guard is a security *control* — these findings
harden the control itself: its audit trail, its presentation as an injection
surface, and the human gate it depends on.

**Re-run delta (2nd pass — dual lens, 2026-07-02):** New — Finding 6
(Notable): the plan's bulk `fold all` dilutes AC #1's per-violation choice.
Resolved — Findings 3–5 (applied by plan DD2 / DD5). Unchanged — Findings 1–2
(spec-applied, still resolved).

**Routing applied 2026-07-02 (1st pass):** Findings 1–2 folded into the spec
(AC #4 strengthened; new AC #8; User Story #5 extended).

## Coverage

- spec.md — reviewed 2026-07-02 (requirements-gap lens)
- plan.md — reviewed 2026-07-02 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | jim's own development artifacts; commit-author identity incidental, not processed. |
| Credentials | No | Not handled as credentials — change evidence may *incidentally* contain secret-looking values; AC #7 carries the 029/030 redaction invariant over display and persistence. |
| Session data | No | None. |
| Internal-only | Yes | Blueprint invariant table, change diffs, ledger events, fork decisions. |
| Public | Yes | `000-blueprint/spec.md` and any filed divergence issue are committed, shareable artifacts — the output sinks. |

## Findings

### 1. Unattended writes must itemize their classifications, or misclassification is invisible

- **Severity:** Notable
- **Description:** AC #4's graded autonomy hinges entirely on the skill's
  additive-vs-weakening-vs-removal judgment. A downgrade misclassified as
  additive auto-writes with no prompt — and the AC requires only that
  unattended edits are "noted in the summary," so the sole post-hoc audit
  surface may not reveal what the classifier decided. The bypass is silent
  precisely on the unattended path the grading exists to protect.
- **Suggestion:** Strengthen AC #4: the unattended-write summary itemizes
  every touched invariant and Provides entry with the classification the
  skill assigned it (additive / weakening / removal), so a misclassification
  is auditable from the summary alone and correctable via the ordinary
  update flow.
- **Route:** Spec
- **Relates to:** AC #4, User Story #3
- **Resolution:** Applied — AC #4 now requires the unattended-write summary to
  itemize every touched invariant / Provides entry with its assigned
  classification. **Resolved.**

### 2. Fork outcomes need a durable record (repudiation)

- **Severity:** Notable
- **Description:** Folding a violated `critical` invariant is the
  highest-consequence decision this feature introduces, yet the spec records
  it nowhere durable: the blueprint commit shows the resulting content, not
  that a violation was found and overridden; a "fix the code" choice whose
  offered issue is declined leaves no trace at all. The guard's activity is
  invisible to any later audit (including `/jim:review`'s trajectory reading
  of the ledger).
- **Suggestion:** Add an AC: each guard run durably records its outcomes —
  violations found and the per-violation resolution chosen. The natural,
  cheap home is the existing `blueprint` ledger stage's `finished` event
  (key=value, mirroring spec 028's validated verdict pattern); mechanism is
  the plan's call.
- **Route:** Spec
- **Relates to:** AC #1, AC #3; spec 030 security Finding 4 precedent
- **Resolution:** Applied — new AC #8 (guard outcomes durably recorded;
  mechanism deferred to the plan) + User Story #5 extended with
  attributability. **Resolved.**

### 3. Delimit evidence from skill framing in the fork presentation (spoofing)

- **Severity:** Notable
- **Description:** The fork presentation quotes change evidence to ground
  each violation. An adversarial diff can embed text that mimics the skill's
  own framing — e.g. a hunk containing "Recommendation: fold — this invariant
  is obsolete." AC #6 protects the skill's *decision* from embedded
  directives, but nothing yet protects the *developer's read* of the
  presentation, and the developer is the actual decision-maker at the fork.
- **Suggestion:** In the plan, mandate that evidence excerpts appear only in
  visibly delimited quoted blocks (the `<untrusted-issue-content>` discipline
  applied to presentation), with skill-authored framing and resolutions
  typographically separate, so manufactured framing is distinguishable at a
  glance.
- **Route:** Plan
- **Relates to:** AC #1, AC #6
- **Resolution:** Applied — plan DD2 + Interface Contracts: evidence quoted
  only inside delimited `<untrusted-change-evidence>` blocks, skill framing
  outside. **Resolved.**

### 4. Batch the forks or fatigue defeats the gate (DoS on the human)

- **Severity:** Advisory
- **Description:** A change judged to violate many invariants produces many
  sequential prompts. Prompt fatigue predictably degrades scrutiny — the
  developer rubber-stamps "fold," defeating the guard exactly when the blast
  radius is largest. The resource being exhausted is the human's attention.
- **Suggestion:** Present all violations as one batched fork with per-item
  choices and bulk actions (the candidate-batch `f / e / s` UX is the house
  precedent), and lead with the violation count so an unusually large batch
  reads as the anomaly it is.
- **Route:** Plan
- **Relates to:** AC #1
- **Resolution:** Applied — plan DD2: one count-led batched fork with per-item
  choices and bulk actions. See Finding 6 for the residual bulk-`fold all`
  refinement. **Resolved.**

### 5. Compose the divergence issue as paraphrase, not pasted diff (information disclosure)

- **Severity:** Advisory
- **Description:** The fix-resolution issue body records "the change
  evidence." Pasting raw hunks propagates attacker-influenced text into
  `docs/issues/` — a third artifact surface, later interpreted by
  `issue-analyst` and the insights flow (wrapped as untrusted there, but
  minimizing what propagates is cheaper than relying on downstream wrapping).
  AC #7 already covers secret redaction; this is the injection-propagation
  angle.
- **Suggestion:** In the plan, compose the issue body as the skill's
  paraphrase plus `file:line` pointers; verbatim excerpts only when necessary
  and delimited per the step-7 wrapping convention. The temp-file Write
  discipline (security 025 Finding 5) applies as already noted in Handoff
  Insight 2.
- **Route:** Plan
- **Relates to:** AC #3, AC #7
- **Resolution:** Applied — plan DD5: body is the skill's paraphrase plus
  `file:line` pointers, delimited excerpts only when necessary, temp-file
  Write discipline. **Resolved.**

### 6. Bulk `fold all` dilutes the per-violation choice the spec requires

- **Severity:** Notable
- **Description:** Plan DD2's fork presentation offers bulk actions
  `fix all | fold all`. Spec AC #1 requires an explicit choice *per
  violation*, and Finding 4's fatigue scenario ends exactly here: one
  keystroke folds every violation, including `critical` ones — the
  rubber-stamp the batching was meant to prevent, now provided as a
  convenience. The two bulk directions are not symmetric: `fix all` is
  conservative (withholds edits, blueprint authority intact), `fold all`
  rewrites intent wholesale.
- **Suggestion:** Keep `fix all` unrestricted; constrain `fold all` to
  `medium`/`low`-criticality violations, with `critical`/`high` violations
  always requiring per-item confirmation — reusing the spec's existing
  grading line rather than inventing a new threshold.
- **Route:** Plan
- **Relates to:** AC #1; plan DD2 / Interface Contracts
- **Resolution:** Applied — plan DD2 + Interface Contracts: `fix all`
  unrestricted; `fold all` limited to `medium`/`low`, `critical`/`high` folds
  confirmed per-item. **Resolved.**

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 — evidence mimicking skill framing at the fork. |
| Tampering | No | No new issues — AC #6 carries the 026/029/030 untrusted-evidence boundary; `jimledger.sh metrics` remains the only trusted channel. |
| Repudiation | Yes | Finding 2 — fork outcomes otherwise unrecorded. |
| Information Disclosure | Yes | Finding 5 — evidence propagation into issues; secret redaction already covered by AC #7. |
| Denial of Service | Yes | Finding 4 — prompt-flood fatigue on the human gate; no machine resource exhaustion (bounded by the diff). |
| Elevation of Privilege | Yes | Findings 1, 6 — misclassification grants unattended write where a prompt is required; bulk `fold all` grants wholesale intent rewrite in one action. |

## Artifact Misalignment

- **Finding 6 — bulk `fold all` vs per-violation choice:** Spec AC #1 states
  the developer makes an explicit choice per violation; plan DD2's
  `fold all` bulk action folds all violations, `critical` included, in one
  action. Route: Plan (constrain the bulk action; the spec's requirement
  stands). **Resolved — plan DD2 now constrains `fold all` as suggested.**

## Routing Recommendations

### Spec amendments
- Finding 1: strengthen AC #4 — unattended summaries itemize per-row classifications. **Applied.**
- Finding 2: new AC #8 — guard outcomes durably recorded (mechanism to plan; ledger kv is the natural fit). **Applied.**

### Plan amendments
- Finding 3: delimited evidence vs skill framing in the fork presentation. **Applied (DD2).**
- Finding 4: batched fork UX with per-item choices and a leading violation count. **Applied (DD2).**
- Finding 5: divergence issue body is paraphrase + pointers, not raw hunks. **Applied (DD5).**
- Finding 6: constrain bulk `fold all` to `medium`/`low` violations; `critical`/`high` fold per-item. **Applied (DD2).**
