---
spec: "docs/specs/jim/036-verify-loop/spec.md"
reviewed_phases: [spec]
status: Needs Spec Review
date: "2026-07-05"
---

# Security Review: Verification engine loop integration

## Summary

**Findings:** 0 Critical · 2 Notable · 5 Advisory

Reviewed spec.md only (no plan.md exists yet) with the requirements-gap
lens. The spec carries the 026/029/030/031/035 trust disciplines forward
well (ACs #13–#14); the gaps found concern two integrity properties the new
cross-skill outcome flows introduce: what anchors the two-channel routing
decision, and what happens when verification rungs disagree. LINDDUN ran
(incidental credentials in scanned content) and surfaced nothing beyond the
existing redaction discipline.

## Coverage

- spec.md — reviewed 2026-07-05 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | No personal data handled |
| Credentials | Yes | Incidental only: scanned code, blueprint content, and registry command output may contain secret-looking values; redaction discipline applies (AC #14, spec 029/030 lineage) |
| Session data | No | — |
| Internal-only | Yes | Ledger events, blueprint invariants, engine outcomes/evidence, review.md content, issue bodies |
| Public | No | Artifacts are repo-committed, not published |

## Findings

### 1. Two-channel routing must anchor to the trusted change record

- **Severity:** Notable
- **Description:** AC #4 routes violations by whether they "intersect the
  build's change" — the fork channel versus the report/issue channel. The
  classification inputs include evidence locations from judge subagents and
  registry command output, which are untrusted (AC #13). AC #13 enumerates
  what embedded directives cannot bind (outcomes, verdict, fork framing,
  issue decisions) but does not name the **channel classification** itself.
  A spoofed evidence path in adversarial content could re-route a
  build-caused violation away from the fork (or a pre-existing one into
  it), and nothing in the ACs guarantees a violation cannot fall between
  the channels.
- **Suggestion:** Extend AC #13 (or AC #4) with two properties: (a) channel
  classification derives from the intersection of outcome evidence with the
  **trusted recorded change set** (the ledger's validated range / file
  list, the spec 026 lineage) — locations claimed inside untrusted content
  never re-route a violation on their own; (b) every sensed violation lands
  in exactly one channel — the routing is exhaustive, with no drop path.
- **Route:** Spec
- **Relates to:** AC #4, AC #13

### 2. Conflicting rung outcomes need a fail-closed precedence rule

- **Severity:** Notable
- **Description:** One invariant can now receive outcomes from more than
  one rung in a single run — the whole-group mechanical floor and a
  diff-scoped judge (AC #2), plus the fork's non-regression fallback
  (AC #8). No AC says which outcome prevails on disagreement. If an
  optimistic merge lets a judge's *holds* supersede a deterministic floor
  *violated*, a prompt-injected judge becomes a laundering path: the
  violation vanishes, the fork never fires, and the change can fold into
  the blueprint as a routine edit (a `medium`/`low` weakening writes
  unattended under `auto_blueprint`).
- **Suggestion:** Add an AC fixing outcome precedence fail-closed: when
  rungs disagree on one invariant, the non-holding outcome prevails —
  deterministic floor evidence is never overridden by LLM judgment — and
  the disagreement itself is surfaced in the report/evidence, never
  silently resolved to the optimistic outcome.
- **Route:** Spec
- **Relates to:** AC #2, AC #8; spec 031's laundering-path closure

### 3. Registry rung amplification in the per-review sensor

- **Severity:** Advisory
- **Description:** Operator-registered commands (arbitrary project tooling,
  `verify_registry_timeout` default 120s) currently run on explicit
  `/jim:verify` invocations. The sensor auto-runs them on every review —
  an invocation-frequency amplification the operator tuned their registry
  for on-demand use never priced in. No new execution surface (the 035
  registry boundary is unchanged), but a slow command now taxes every
  review, and under `require_review` a hung command delays a gated
  completion.
- **Suggestion:** ~Resolve the spec's open question toward diff-scoping
  the registry rung in the sensor.~ **Overridden by developer decision
  (2026-07-05):** registry commands are floor — whole-group, every review;
  enabling a registry entry means accepting its per-review cost (the
  operator owns the spend). Accepted risk, recorded. The remaining
  actionable mitigation: carry `verify_registry_timeout` containment into
  the sensor path explicitly at plan time, so a hung command bounds — not
  blocks — a `require_review`-gated completion.
- **Route:** Plan
- **Relates to:** AC #2; Open Questions (registry scoping — resolved)

### 4. Sensor→update hand-off should carry fixed-shape outcome records

- **Severity:** Advisory
- **Description:** AC #5's no-double-run means engine outcomes cross a
  skill boundary (review → blueprint update) as conversation context. Free
  prose hand-off invites drift in what the fork treats as authoritative and
  widens the injection surface AC #13 defends.
- **Suggestion:** At plan time, define the hand-off as a minimal
  fixed-shape record per outcome (invariant id, outcome from the closed
  vocabulary, evidence location) — the fixed-key discipline of the ledger
  metrics channel (spec 026 Finding 7 lineage) — with evidence prose only
  inside delimited untrusted blocks.
- **Route:** Plan
- **Relates to:** AC #5; Handoff Insight 2

### 5. Per-channel attributability in the durable record

- **Severity:** Advisory
- **Description:** AC #12 records outcome counts durably. The new routing
  decision (fork vs pre-existing) is itself a guard outcome: a violation
  routed to the pre-existing channel whose issue offer was declined should
  remain attributable, including *which channel* handled it.
- **Suggestion:** Include per-channel counters in the recorded stage event
  (e.g. change-intersecting vs pre-existing counts), extending the spec
  031 `violations=`/`folded=`/`fixed=` convention rather than inventing a
  new record.
- **Route:** Plan
- **Relates to:** AC #12

### 6. Coverage accounting at the non-regression seam

- **Severity:** Advisory
- **Description:** AC #8 guarantees no invariant is silently dropped
  between the engine's outcomes and the fork's fallback detection. Two
  overlapping mechanisms create a seam where each can assume the other
  covered an invariant (skipped / unconfigured / failed / no check data),
  quietly reopening the gap the AC closes.
- **Suggestion:** At plan time, require a deterministic accounting: every
  invariant in the fork's scope is tagged with which mechanism judged it
  (engine rung vs fallback sweep), so seam gaps are structurally
  impossible rather than reviewed for.
- **Route:** Plan
- **Relates to:** AC #8; Handoff Insight 3

### 7. New scope parameters reuse the single range-validation boundary

- **Severity:** Advisory
- **Description:** Diff-scoped invocation adds new consumers of
  user-supplied and ledger-recorded git ranges (the sensor's build range;
  the `--since` engine call). ARCHITECTURE.md → Security Considerations
  already fixes the discipline (validated SHAs/refs before git
  interpolation, `--` guards); this finding reinforces rather than
  restates it.
- **Suggestion:** Route every new range/scope parameter through the
  existing `resolve_range`/ref-validation boundary in `jimledger.sh` —
  no second validation path, no direct interpolation in new code.
- **Route:** Plan
- **Relates to:** AC #2, AC #7

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 1 (spoofed evidence locations steering channel routing) |
| Tampering | Yes | Findings 2, 4 (outcome laundering via rung disagreement; hand-off shape) |
| Repudiation | Yes | Finding 5 (per-channel attributability; AC #12 baseline is sound) |
| Information Disclosure | No | No issues found — AC #14 redaction and the delimited-evidence convention (AC #13) carry the 029/030/031 discipline forward; no new leak surface identified |
| Denial of Service | Yes | Finding 3 (registry amplification per review; timeout containment) |
| Elevation of Privilege | No | No issues found — no new executable surface: the 035 registry boundary is unchanged (blueprints still cannot mint commands), and AC #9 keeps 031's graded autonomy and always-fork guarantees intact |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | N/A | No data subjects — content is project code and dev artifacts |
| Identifying | N/A | No anonymous-subject data to re-identify |
| Non-repudiation | N/A | No data subjects; developer attributability is a deliberate audit property here, not a privacy threat |
| Detecting | N/A | No subject-presence inference surface |
| Data Disclosure | No | No issues found — incidental secret-looking values in scanned content are covered by AC #14's redaction placeholder |
| Unawareness & Unintervenability | N/A | Developer-invoked tooling; all processing is visible in conversation and gated artifacts |
| Non-compliance | N/A | No personal data; no applicable privacy regime for internal dev tooling |

## Routing Recommendations

### Spec amendments
- Finding 1: extend AC #13/AC #4 — channel classification anchored to the
  trusted recorded change set; exhaustive two-channel routing (no drop
  path).
- Finding 2: new AC — fail-closed outcome precedence on rung disagreement;
  floor evidence never overridden by LLM judgment; disagreement surfaced.

### Plan amendments
- Finding 3: registry-as-floor accepted by developer decision; carry
  `verify_registry_timeout` containment into the sensor path.
- Finding 4: fixed-shape outcome records for the sensor→update hand-off.
- Finding 5: per-channel counters on the recorded stage event.
- Finding 6: deterministic which-mechanism-covered-it accounting at the
  AC #8 seam.
- Finding 7: route new range/scope parameters through the existing
  `resolve_range` validation boundary.
