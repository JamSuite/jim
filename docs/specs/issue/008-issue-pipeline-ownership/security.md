---
spec: "docs/specs/issue/008-issue-pipeline-ownership/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-06-20"
---

# Security Review: Pipeline-ownership filter for candidate batches

## Summary

**Findings:** 0 Critical · 1 Notable · 2 Advisory

Reviewed `spec.md` (requirements-gap lens) and `plan.md` (design-flaw lens, added this run). The change *removes* candidates from the batch rather than adding data handling, so the sensitive-data surface shrinks; LINDDUN is N/A (no PII / Credentials / Session data). The notable spec-phase issue was that the new filter introduces a *drop* decision the existing untrusted-content rule did not cover (now fixed by a new AC). **The plan-phase pass surfaced no new findings:** `plan.md` faithfully implements every AC — contract C1 carries the AC4 untrusted-content clause verbatim, no new dependencies or privileges are introduced, and no STRIDE category gains a new issue.

**Dispositions:** Finding 1 folded into the spec (new AC). Finding 2 not routed — surfacing exclusions would re-introduce recurring noise, defeating the filter's purpose. Finding 3 withdrawn on review — re-running the security gate is itself pipeline-owned (AC #1), so the premise was incorrect. No unresolved findings remain → `status: Active`.

**Re-run delta (spec → spec + plan):** no new findings this pass; Findings 1–3 unchanged (applied / declined / withdrawn).

## Coverage

- spec.md — reviewed 2026-06-20 (requirements-gap lens)
- plan.md — reviewed 2026-06-20 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | No personal data handled. |
| Credentials | No | The filter neither reads nor stores credentials. Candidate/issue bodies *can* carry pasted secrets, but that is a pre-existing spec 017/018 surface (mitigated by the confirm-or-edit scrub) and is unchanged here — this change only drops candidates pre-filing. |
| Session data | No | None. |
| Internal-only | Yes | Operates on candidate text and issue metadata — project-internal developer data. |
| Public | Yes | Filed issues become public when the repository is published (pre-existing property per spec 018; this change reduces what is filed). |

## Findings

### 1. Pipeline-ownership *drop* decision is an injection-to-suppress surface the untrusted-content rule does not cover

- **Severity:** Notable
- **Description:** The new filter decides to *drop* a candidate based on whether "a jim phase performs this action automatically." That judgment can be swayed by candidate text, which spec 018 § Security and Safety classifies as potentially untrusted (tool results, file reads, web fetches, prior-issue bodies). The existing rule (`018/spec.md:60-62`; `ARCHITECTURE.md:203`) forbids embedded directives from binding *file / prioritize / label* decisions — but says nothing about a *drop/suppress* decision. An adversarial candidate body asserting e.g. *"ARCHITECTURE.md is regenerated automatically by /jim:arch"* could induce a false drop, silently suppressing a legitimate follow-on.
- **Suggestion:** Require, in the spec, that the pipeline-ownership determination is made from the agent's own model of jim's workflow (which phases auto-perform which maintenance) and never from claims embedded in candidate text; and extend the 018 untrusted-content discipline to cover suppression/drop decisions, not just file/prioritize/label. A short AC clause (or an addition to AC #1) suffices.
- **Route:** Spec
- **Relates to:** AC #1
- **Disposition:** Routed — folded into a new AC extending the spec-018 untrusted-content discipline to drop/suppression decisions.

### 2. Pre-render exclusions are invisible to the developer (transparency-over-automation tension)

- **Severity:** Advisory
- **Description:** All three filters (Resolution, Actionability, Pipeline-ownership) run *before* the batch is rendered, so a pipeline-ownership exclusion never reaches the developer — unlike a confirm-time skip, which the batch summary reports by row index with a reason. Because pipeline-ownership is a *predictive* judgment (more error-prone than the factual resolution/actionability checks) and a wrong exclusion loses a real human-owned follow-on, a false-drop is currently uncatchable. This tensions with VISION's "Not a black box … transparency over automation" non-goal.
- **Suggestion:** Surface pipeline-ownership exclusions to the developer — e.g. a one-line *"N candidate(s) excluded as pipeline-owned: <reason>"* note alongside the batch — so a mis-drop is visible and recoverable. Specify the visibility expectation in the spec.
- **Route:** Spec
- **Relates to:** AC #1, AC #3
- **Disposition:** Not routed (developer decision). A pipeline-owned item recurs every run, so reporting exclusions would surface the same noise indefinitely — defeating the filter's noise-reduction purpose.

### 3. ~The new "handled by a later gate" category must not absorb security/compliance follow-ons~ (withdrawn)

- **Severity:** Advisory
- **Description:** AC #5 introduces a "handled by a later gate → not trackable" category for `/jim:plan`'s Out of Scope. If applied beyond strict workflow-automated maintenance, a deferred security or compliance follow-on could be miscategorized as gate-handled and silently dropped from candidates.
- **Suggestion:** Keep the category strictly limited to jim-automated maintenance (as currently scoped to the arch refresh); add an explicit note that security/compliance follow-ons are never "handled by a later gate" and remain trackable.
- **Route:** Spec
- **Relates to:** AC #5
- **Disposition:** Withdrawn on review. Re-running the security *gate* is itself pipeline-owned — AC #1 already names it as a canonical drop case — so "security follow-ons are never gate-handled" is incorrect, and the proposed carve-out would force the gate-handled review re-run to be tracked (re-introducing noise). A security *remediation* task is not auto-performed by any gate, so it is not at risk of a false pipeline-owned drop. No carve-out warranted.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or authentication surface in a prose drop-filter. |
| Tampering | Yes | Finding 1 — untrusted candidate text can bias the drop decision, tampering with the filing outcome. |
| Repudiation | Yes | Finding 2 — pre-render exclusions leave no developer-visible trail; a false-drop cannot be audited or overridden. |
| Information Disclosure | No | The change reduces what is written; no new disclosure path. Issue-publication property is pre-existing and unchanged. |
| Denial of Service | N/A | Design-time prose change; no runtime resource surface to exhaust. |
| Elevation of Privilege | N/A | No privilege or permission model involved. |

## Artifact Misalignment

None. The plan faithfully implements every spec AC without weakening an asserted boundary:

- **AC4** (judge from workflow knowledge; embedded text cannot force a drop) → plan contracts **C1** / **C2** carry the clause verbatim.
- **AC5** (all seven surfacing skills) → tasks 2 (six standard) + 3 (sec variant) cover exactly seven.
- **AC1–AC3** (principle + cross-phase + false-positive guard) → C1's clauses mirror the spec.

## Routing Recommendations

### Spec amendments
- **Finding 1 (applied):** New AC requires pipeline-ownership to be judged from the agent's workflow knowledge, not candidate text — extending the spec-018 untrusted-content discipline to drop/suppression decisions.

### Not routed
- **Finding 2:** Surfacing pipeline-owned exclusions re-introduces recurring noise; declined.
- **Finding 3:** Withdrawn — security gate re-runs are themselves pipeline-owned (AC #1); no carve-out warranted.

### Plan amendments
- None — the plan introduces no new findings; nothing to route.

### Candidate issues
- None — no findings route to `Issue`.
