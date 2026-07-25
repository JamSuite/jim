---
spec: "docs/specs/blueprint/020-partition-merge/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-23"
---

# Security Review: Partition merge

## Summary

**Findings:** 0 outstanding — 8 total: 5 resolved from the spec phase, 3
plan-phase findings routed and applied to the plan 2026-07-23

Second run, dual lens. The spec-phase findings all resolved — three folded
into spec ACs, two landed as plan tasks. The plan-phase review of the drafted
design surfaced two Notable seams — model arithmetic on the append seed, and
a missing validated channel for AC 6's re-key commit-body record — plus one
Advisory on prose-compression discipline. STRIDE re-ran in full; LINDDUN
remains omitted (no PII / credentials / session data).

## Coverage

- spec.md — reviewed 2026-07-22 (requirements-gap lens); amendments
  re-checked 2026-07-23
- plan.md — reviewed 2026-07-23 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Group slugs, spec ids, territory paths — no individual-identifying data |
| Credentials | No | Not handled as data; scanned artifact content may *contain* secret-looking values — covered by the inherited scrub discipline (AC 8's secret-scrubbed diffs) |
| Session data | No | — |
| Internal-only | Yes | Spec archive bodies, blueprints, map content, ledger counter events, config keys |
| Public | No | Nothing intended for external exposure |

## Findings

### 1. Close-event value provenance is unconstrained

- **Severity:** Notable
- **Description:** AC 14 fixes the `op=merge` event's *shape* but not where its
  values come from. `jimledger.sh cmd_event` writes key=value pairs verbatim
  (no shape validation — research.md, Security), so the event's integrity rests
  entirely on the orchestrator composing `old=` / `new=` / `moved=` from
  trustworthy inputs. A well-formed but wrong event (e.g. values influenced by
  adversarial artifact content the model read during the run) would corrupt the
  durable bridge and the `next-id` floors while passing every consumer's
  charset gate.
- **Suggestion:** Add to AC 14: the close event's values derive only from the
  preflight-validated argument set and the renumber verb's emitted remap —
  never from scanned content. This applies the 045 script-emitted doctrine to
  the new event explicitly.
- **Route:** Spec
- **Relates to:** AC #14
- **Resolution:** Resolved 2026-07-23 — folded into AC 14 (value-provenance
  clause); plan DD 8 and the Interface Contracts carry it.

### 2. Interview presentation lacks the untrusted-content discipline

- **Severity:** Notable
- **Description:** The interview (AC 5/6) is a new conversational surface that
  quotes untrusted blueprint content — invariant texts for collision
  comparison, surface names, guarantee prose, gatherer evidence. A directive
  embedded in that content (an invariant whose text reads as an instruction)
  has a fresh chance to bind a resolution before the gate. Spec 044's health
  run set the precedent for conversational surfaces that quote map/blueprint
  content: delimited untrusted blocks, content as data never instruction.
- **Suggestion:** Add to AC 5 (or 6): quoted blueprint/spec content presented
  during the interview and gate rides inside untrusted-content delimiters; an
  embedded directive binds nothing — collision resolutions and dispositions
  bind only from developer responses.
- **Route:** Spec
- **Relates to:** AC #5, AC #6
- **Resolution:** Resolved 2026-07-23 — folded into AC 5; plan DD 9 names the
  `<untrusted-merge-evidence>` token, carried into methodology by task 9.

### 3. Machine-consumption widening — posture holds; prove it with tamper tests

- **Severity:** Advisory
- **Description:** 047's security review flagged the `moved=` / `vacated-max`
  machine-consumption for re-examination when extended. Re-examined here: AC 15
  widens acceptance filters only (`;op=merge;` alongside `;op=split;`), reusing
  the fail-closed element parse byte-for-byte — no new value shapes, no new
  consumers. Residual risks are bounded and pre-existing: a repo-writer can
  raise a group's id floor (nuisance, up to the 999 refusal) or make
  `identity-check` name a live slug retired (advisory sensor noise, never a
  veto) — both require repo write access, which is already the trusted zone.
- **Suggestion:** The plan's test tasks extend 047's tamper cases to `op=merge`
  events: malformed `moved=` elements inert, floor monotonic under crafted
  events, a multi-chunk `moved=` case, and an `old=`-names-a-live-slug case
  showing bounded sensor impact.
- **Route:** Plan
- **Relates to:** AC #15, AC #21
- **Resolution:** Resolved 2026-07-23 — landed as plan tasks 1 and 8 with the
  tamper cases enumerated (malformed-element inert, floor monotonic,
  multi-chunk, live-slug-in-old bounded).

### 4. Invariant-id re-keys leave no durable lineage

- **Severity:** Advisory
- **Description:** AC 6 presents a homonym re-key at the gate as a knowing
  ratchet break, but after materialization the old id exists nowhere — unlike
  spec-id moves, which get a durable `moved=` remap. A future maintainer
  auditing the merged blueprint (or an issue referencing the old invariant id
  in prose) has no record connecting old and new ids.
- **Suggestion:** Add to AC 6: each ratchet break is recorded durably — at
  minimum as old→new id pairs in the merge docs commit's body — so invariant
  lineage survives the merge. (A ledger key is overkill for a rare event; the
  commit body is the cheap, greppable record.)
- **Route:** Spec
- **Relates to:** AC #6, User Story #6
- **Resolution:** Resolved 2026-07-23 — folded into AC 6 (commit-body
  record). The landing *mechanism* gap it exposed in the plan is now finding
  7.

### 5. New tool grants must stay verb-scoped

- **Severity:** Advisory
- **Description:** The feature adds script verbs (`merge-preflight`, the
  renumber verb, `commit-merge`, the `edges-diff` merge form) that the
  partition skill's `allowed-tools` must cover. The 042/044 precedent is
  verb-scoped Bash clauses — the tightest prefix per verb — never a broadened
  wildcard.
- **Suggestion:** The plan enumerates each new `allowed-tools` clause
  verb-scoped, and confirms the blueprint skill needs no new grant (the
  `--merge` arm runs under the existing `Skill(jim:blueprint)` invocation).
- **Route:** Plan
- **Relates to:** AC #3, AC #9, AC #16, AC #17
- **Resolution:** Resolved 2026-07-23 with zero delta — the plan's
  Constitution Check documents that partition's existing script-level clauses
  cover the new verbs (the multi-verb-consumer convention) and the blueprint
  arm runs under the existing `Skill(jim:blueprint)` grant.

### 6. Model arithmetic guards the id floor

- **Severity:** Notable
- **Description:** Plan DD 2 has the orchestrator derive `merge-map`'s seed as
  "`next-id` − 1" — an LLM subtraction on the exact value that prevents
  vacated-id re-minting, the precise class the 045 script-emitted doctrine
  exists to remove (and DD 2's own prose wobbles while describing it). An
  off-by-one-low seed re-mints a vacated id; the gate would display the wrong
  remap, but the defense should be structural, not review-dependent.
- **Suggestion:** Redefine the argument as `<start>` — the first id to assign
  — passed **verbatim** from `jimfile.sh next-id <target>` stdout (`001` for a
  fresh target). `merge-map` assigns start, start+1, …; the model copies a
  script value and never computes. Update DD 2, the Interface Contracts, and
  task 6's tests (pin: the first absorbed spec receives exactly `next-id`'s
  output).
- **Route:** Plan
- **Relates to:** plan DD 2, Interface Contracts, task 6; spec AC #9
- **Resolution:** Resolved 2026-07-23 — DD 2, the `merge-map` contract, and
  task 6 redefined around a verbatim `<start>` argument; the model copies
  `next-id` output, never computes.

### 7. AC 6's re-key record has no landing channel

- **Severity:** Notable
- **Description:** Spec AC 6 requires each invariant-id re-key recorded "as
  old→new id pairs in the merge docs commit's body," but the plan's
  `commit-merge` contract composes a subject only — no body input exists.
  Improvised at build time, the record either gets dropped (spec violation) or
  free text enters a security-audited commit arm whose discipline is
  slug-composed values only.
- **Suggestion:** Extend `commit-merge` with an optional final `[rekey-csv]`
  argument (`old-id:new-id[,…]`, each token gated to the invariant-id charset
  `[a-z0-9-]`), rendered into the commit body in-script; absent → subject-only
  behavior unchanged. Add the gated-composition case to task 3's tests.
- **Route:** Plan
- **Relates to:** spec AC #6; plan task 3, Interface Contracts
- **Resolution:** Resolved 2026-07-23 — `commit-merge` gains the optional
  charset-gated `--rekey` body channel; task 3's tests cover composition and
  malformed-token reject.

### 8. Prose compression has no content test

- **Severity:** Advisory
- **Description:** Task 12 compresses `## Split runs` under a `wc -l` +
  gate-count verify — neither detects a silently dropped load-bearing
  directive (event recording, the `RETIRES` row, commit ordering); prose has
  no regression tests.
- **Suggestion:** Task 12 enumerates the section's load-bearing directives
  before compressing and confirms each survives as a line or an explicit
  methodology pointer; the task's commit message records the checklist.
- **Route:** Plan
- **Relates to:** plan task 12
- **Resolution:** Resolved 2026-07-23 — the mandatory compression task was
  dropped entirely under the developer's authorized 500-cap overage (plan DD 6
  revised); the residual light dedup rides task 12 with the
  directive-preservation checklist as a prerequisite step.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No external trust boundary — a developer-local, gate-confirmed operation |
| Tampering | Yes | Finding 6 (active); 1, 3 resolved; remap-as-whitelist and gate re-validation inherited from 047, re-confirmed at plan task 10 |
| Repudiation | Yes | Finding 7 (active); 4 resolved; otherwise strong trail — op=merge event, fixed two-commit choreography, all-or-nothing gate |
| Information Disclosure | Yes | Finding 2 resolved; secret-scrubbed gate diffs (AC 8) and location-only evidence conventions inherited |
| Denial of Service | No | No issues found — gatherer fan-out capped by `verify_fanout_cap`; floor-raise nuisance requires repo write access (trusted zone), noted in Finding 3 |
| Elevation of Privilege | Yes | Finding 5 resolved (zero grant delta); no new capability for read-only agents (gatherer unchanged, AC 20) |

## Artifact Misalignment

- **Finding 7 — Re-key record has no landing channel:** Spec AC 6 requires
  invariant-id re-keys recorded in the merge docs commit's body; the plan's
  `commit-merge` contract composes a subject only, with no body input. The
  spec is the source of truth — the plan's contract gains the validated
  channel. Route: Plan.

## Routing Recommendations

### Spec amendments
- Finding 1: constrain AC 14's event values to preflight-validated arguments
  and script-emitted remap output.
- Finding 2: require untrusted-content delimiters for interview/gate quoting;
  resolutions bind only from developer responses.
- Finding 4: record invariant-id re-keys durably (commit body minimum).

All three spec amendments applied to spec.md 2026-07-22.

### Plan amendments
- Finding 3: tamper-case tests — landed (plan tasks 1, 8). Resolved.
- Finding 5: grants — resolved with zero delta (plan Constitution Check).
- Finding 6: verbatim `<start>` argument — applied (DD 2, contracts, task 6).
- Finding 7: validated `--rekey` channel on `commit-merge` — applied
  (contracts, task 3).
- Finding 8: directive-preservation checklist — applied inside task 12; the
  compression mandate itself was dropped under the authorized cap overage
  (DD 6 revised).

All plan amendments applied to plan.md 2026-07-23.

No findings route to Issue this run.
