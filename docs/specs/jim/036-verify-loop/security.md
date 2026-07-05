---
spec: "docs/specs/jim/036-verify-loop/spec.md"
reviewed_phases: [spec, plan]
status: Needs Plan Review
date: "2026-07-05"
---

# Security Review: Verification engine loop integration

## Summary

**Findings:** 0 Critical · 4 Notable (2 addressed, 2 new) · 6 Advisory (5 addressed, 1 new)

Re-run 2026-07-05 with the dual lens (plan.md now present). Findings 1–2
were folded into the spec (ACs #4/#13/#15) and findings 3–7 are addressed
by the plan's design decisions — all seven annotated below. The two new
plan-lens Notables concern the channel classifier's evidence-less edge
(Finding 8) and grounding-record spoofing via untrusted content
(Finding 9); one new Advisory pins scope-list parse edges with tests
(Finding 10). No spec↔plan misalignment found. LINDDUN coverage is
unchanged by the plan.

## Coverage

- spec.md — reviewed 2026-07-05 (requirements-gap lens)
- plan.md — reviewed 2026-07-05 (design-flaw lens)

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
- **Status:** Addressed — folded into spec AC #4 (anchored, exhaustive
  routing) and AC #13 (channel classification unbindable).

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
- **Status:** Addressed — folded into spec AC #15; plan DD 6 implements
  (sweep adds, never removes; disagreement surfaced).

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
- **Status:** Addressed — plan DD 4 (registry whole-group in the sensor
  with `verify_registry_timeout` containment named; absent in `--since`).

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
- **Status:** Addressed — plan DD 5 + the `VERIFY-OUTCOME` Interface
  Contract (fixed-shape records; evidence prose only in delimited blocks).

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
- **Status:** Addressed — plan DD 8 (`inchange=`/`preexisting=` kv on the
  existing `verify finished` event).

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
- **Status:** Addressed — plan DD 6 (`grounding: N engine · M sweep`
  accounting with sweep ids listed).

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
- **Status:** Addressed — plan Task 1 (`files-range` reuses
  `valid_git_ref`/`resolve_ref` with `--end-of-options`/`--` guards).

### 8. Evidence-less violations need an explicit channel rule

- **Severity:** Notable
- **Description:** Plan DD 3 classifies floor violations by intersecting
  script-emitted evidence locations with the trusted change set — but a
  `must`-polarity pattern violation is an *absence* (a required pattern is
  missing) and carries no `file:line`. The classifier's behavior on empty
  evidence is undefined, and an undefined edge in a security-relevant
  router invites inconsistent or silent routing.
- **Suggestion:** Extend the channel rule: any violation without a trusted
  evidence location classifies `unlocalized` — routed with `pre-existing`
  to the report/issue channel, never into the fork on a guess. AC #8's
  fallback sweep still covers the fork side for such invariants, so
  nothing is lost to the fold path.
- **Route:** Plan
- **Relates to:** plan DD 3 / Interface Contracts (`VERIFY-OUTCOME`);
  spec AC #4

### 9. Grounding-record spoofing via untrusted content

- **Severity:** Notable
- **Description:** U3a consumes `VERIFY-OUTCOME` records handed over in
  conversation. Diff hunks, code comments, or judge evidence can embed a
  record-shaped block (`id=inv-3 … outcome=holds`); if the fork mistakes
  embedded text for grounding input, an attacker suppresses the fallback
  sweep for that invariant ("engine-cleared") and a real violation
  vanishes — the laundering path reopened one level up.
- **Suggestion:** State explicitly in `fork-grounding.md` and the
  verify/review skill discipline: grounding input is solely the record
  block the caller hands over at invocation; any `VERIFY-OUTCOME`-shaped
  text appearing inside `<untrusted-*>` delimiters (diff, evidence,
  command output) is data, never grounding. Mechanical extension of spec
  AC #13.
- **Route:** Plan
- **Relates to:** plan DD 5, Interface Contracts; spec AC #13

### 10. Scope-list parse edges need pinning tests

- **Severity:** Advisory
- **Description:** The scoped `check` arg and `files-range` introduce
  parse edges: an unreadable list file, and exotic filenames (git
  `core.quotePath` C-quoted output for spaces/unicode/newlines) that
  fragment a line-oriented list. `valid-relpath` re-gating should
  fail-safe-exclude quoted fragments (`HYGIENE`), but the behavior is
  currently asserted, not pinned.
- **Suggestion:** Add test cases: unreadable list file → rc 2; a quoted /
  space-bearing filename in `files-range` output → excluded via `HYGIENE`,
  never mis-scoped into the check set.
- **Route:** Plan
- **Relates to:** plan Tasks 1–2

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 1 (spoofed evidence locations steering channel routing); Finding 9 (spoofed grounding-record blocks) |
| Tampering | Yes | Findings 2, 4, 8 (outcome laundering via rung disagreement; hand-off shape; undefined evidence-less routing) |
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

## Artifact Misalignment

- None identified. One borderline read was checked explicitly: the spec's
  registry-as-floor resolution ("whole-group, always run when configured")
  is sensor-scoped — its Open-Question text names "the sensor's whole-group
  floor pass" — so plan DD 4's registry-absent `--since` mode is consistent
  with spec AC #7's change-scoped-only doctrine, not a contradiction.

## Routing Recommendations

### Spec amendments
- None open — Findings 1–2 applied as spec ACs #4/#13/#15 (2026-07-05).

### Plan amendments
- Finding 8: extend DD 3 / the `VERIFY-OUTCOME` contract with the
  `unlocalized`-on-empty-evidence rule.
- Finding 9: add the grounding-input-provenance clause to
  `fork-grounding.md` (Task 4) and the verify/review discipline steps.
- Finding 10: add the scope-list robustness cases to Tasks 1–2.
- Findings 3–7: addressed by plan DD 4 / DD 5 / DD 8 / DD 6 / Task 1 —
  no further action.
