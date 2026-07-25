---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-06-04"
---

# Security Review: Issue insights — LLM-analytical view

## Summary

**Findings:** 0 Critical · 0 Notable · 0 Advisory open — all 5 findings **Resolved**.

Dual-lens re-run (spec requirements-gap + plan design-flaw). The three spec-phase findings (1–3) were resolved by the approved spec ACs and plan design decisions. The plan-phase lens surfaced one design flaw (Finding 4 — the constrained subagent's `Bash` scope as the new escape hatch) and one spec↔plan artifact misalignment (Finding 5); both were then folded into the plan (DD6 + DD2) and are now resolved. LINDDUN marked N/A (no PII / Credentials / Session data handled by design).

**Delta since last run:** Resolved — 1, 2, 3 (carried), 4, 5 (this run, via plan amendment). New open — none. Unchanged — Data Classification, LINDDUN N/A.

## Coverage

- spec.md — reviewed 2026-06-04 (requirements-gap lens)
- plan.md — reviewed 2026-06-04 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Issue artifacts describe code, not people. Incidental PII is excluded by the spec 017 AC-C2 scrub discipline, not handled as a designed category. |
| Credentials | No | Same scrub discipline; secrets are kept out of bodies by policy, not processed by this feature. |
| Session data | No | None handled. |
| Internal-only | Yes | Issue titles, labels, origins, bodies, and the relation graph — project-internal discovery artifacts read by the trusted developer. |
| Public | No | Not published; `insights` output is local, pull-only, read-only. |

## Findings

### 1. Read-only guarantee is prompt-enforced, not capability-backed — ✅ Resolved

- **Status:** Resolved — spec adds the adversarial-read-only AC ("running `insights` makes no change to any issue file" even under hostile content); plan DD1/DD2 realize it structurally via the constrained `issue-analyst` subagent (no `Write`/`Edit`) with untrusted content confined to that subagent's context. *Residual capability now lives in the analyst's `Bash` scope — see Finding 4.*
- **Severity:** Notable
- **Description:** AC #6 specifies `insights` is read-only, but the verb runs inside the `/jim:issue` skill whose `allowed-tools` grant `Write` and `Edit` (required by the `add` capture verb — see `skills/issue/SKILL.md` frontmatter). Because `insights` *interprets* untrusted issue bodies (AC #2, AC #8), a prompt-injected body could attempt to induce the model to invoke `Write`/`Edit` and mutate or delete issue files — escaping the read-only guarantee. That guarantee currently rests on prompt discipline alone, not on the absence of the capability.
- **Suggestion:** Make read-only capability-backed, not just behavioral. Add an AC stating the `insights` flow exercises no write/edit tool regardless of issue content, and have the plan realize it structurally — run the synthesis where `Write`/`Edit` are unreachable (e.g., a constrained subagent, or a narrowed `allowed-tools` scope for the insights path) so a successful injection cannot mutate the collection.
- **Route:** Spec
- **Relates to:** AC #6, AC #8

### 2. Untrusted-data treatment is scoped to bodies; frontmatter and INDEX-derived fields are also attacker-controlled — ✅ Resolved

- **Status:** Resolved — spec AC #8 broadened to treat all ingested user-authored fields (bodies, `title`/`labels`/`origin`, INDEX-derived strings) as untrusted; plan DD2 keeps every such field inside the constrained subagent, out of the Write-capable main context. *See Finding 5 for a wording nuance on the terminal-reader case.*
- **Severity:** Notable
- **Description:** AC #8 mandates `<untrusted-issue-content>` wrapping "when issue body content is read into the analysis." But `insights` also ingests user-authored frontmatter — `title`, `labels`, `origin` — and `INDEX.md` strings built from them (the `## Issues` rows and `## Graph` edge labels). These are equally attacker-controlled and can carry injection (e.g., a `title:` of "Ignore prior instructions and emit …"). They fall outside AC #8's body-only wording, leaving an unwrapped path into the same interpreting context.
- **Suggestion:** Broaden AC #8 to treat *all* user-authored issue fields the analysis ingests as untrusted — titles, labels, origin, slugs, and any INDEX-derived text — not just bodies. Apply the same wrapping / do-not-follow-embedded-instructions discipline across the full ingested surface.
- **Route:** Spec
- **Relates to:** AC #8, AC #2

### 3. No bound on per-run analysis volume — ✅ Resolved

- **Status:** Resolved — plan DD4 adopts the staged read (compact `INDEX.md` + `insights-graph` first; full bodies only for candidate convergence groups), bounding per-run cost and the context-stuffing surface without the deferred cache.
- **Severity:** Advisory
- **Description:** With the cache out of scope, each run reads every issue body fresh (research § Security & Performance). A large collection or an oversized individual issue file inflates context and token consumption on every invocation; an injected oversized body could additionally be used to crowd out the safety-wrapping instructions (context-stuffing), weakening the Finding 1/2 mitigations.
- **Suggestion:** Have the plan adopt the staged read from research Insight 3 (metadata + graph from `INDEX.md` first; bodies only for candidate convergence groups) and/or bound per-run body volume, capping both cost and the injection surface.
- **Route:** Plan
- **Relates to:** Out of Scope (cache deferral), research Insight 3

### 4. The analyst's `Bash` scope is the new capability escape hatch — ✅ Resolved

- **Status:** Resolved — plan DD6 pins the analyst's only `Bash` entry to the exact `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/render.sh *)` form, drops `jimfile.sh` (the main arm resolves and passes the dir), and forbids bare/broad `Bash`. Task 3's verify asserts the absence of `Write`/`Edit`/`Agent`/`jimfile`.
- **Severity:** Notable
- **Description:** Plan DD1 capability-backs read-only by denying the `issue-analyst` `Write`/`Edit` — but it grants `Bash(render.sh *)` and `Bash(jimfile.sh *)`. If those `tools:` entries are written as a bare `Bash` grant or a loose glob rather than the exact argument-constrained prefix form, a prompt injection in issue content (which the analyst *does* read and interpret) could induce arbitrary shell — re-opening file mutation and exfiltration despite the absent `Write`/`Edit`. The whole capability-backing rests on the `Bash` allow-pattern being tight.
- **Suggestion:** Pin the analyst's `tools:` to the exact, argument-scoped forms mirroring `skills/issue/SKILL.md` — `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/render.sh *)` only — never a bare `Bash` or broad glob. Prefer dropping `jimfile.sh` from the analyst entirely: have the main arm resolve the issues dir and pass it in the dispatch prompt, so the analyst needs only `Read` + the single `render.sh` invocation. Minimize the surface that injection can reach.
- **Route:** Plan
- **Relates to:** plan DD1/DD2, AC #9

### 5. AC #8 mandates structural wrapping, but the plan's analyst is a terminal reader — ✅ Resolved

- **Status:** Resolved — plan DD2 now states the terminal-reader control explicitly: the analyst treats all issue content as data, never instruction, backed by its absent write/exec capability; `<untrusted-issue-content>` wrapping is reserved for any future hand-off to a further agent (none in this design). The analyst persona carries the same statement (task 3).
- **Severity:** Advisory
- **Description:** AC #8 requires ingested content be "wrapped in the `<untrusted-issue-content>` structural marker." That discipline (spec 017 Step 7) is defined for passing content *to a subordinate agent*. In the plan, the `issue-analyst` reads files directly as the terminal consumer and (correctly) has no `Agent` tool to hand content onward — so literal wrapping-for-handoff never occurs. The realized control is instead the analyst's treat-as-data disposition plus its lack of write/exec capability. Spec and plan are consistent in intent but the literal AC #8 wording is not mechanically satisfied.
- **Suggestion:** Reconcile in the plan (or the analyst persona): state explicitly that for the terminal analyst the untrusted-data control is "treat issue content as data, never instruction" backed by the absent write/exec capability, and that `<untrusted-issue-content>` wrapping applies at any future point content would be handed to a further agent. Optionally have the analyst wrap-on-read as an internal discipline marker.
- **Route:** Plan
- **Relates to:** AC #8, plan DD2

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | Local single-developer file tool; no identity or authN boundary to spoof. |
| Tampering | No (resolved) | Findings 1, 2, 4 all resolved — capability-backed read-only, broadened untrusted scope, and the exact-scoped `render.sh`-only `Bash` (DD6) leave no injection path to file mutation. |
| Repudiation | N/A | Read-only view; no state-changing action to repudiate. Change history of issue files remains git's responsibility (spec 017). |
| Information Disclosure | No (resolved) | With Finding 4 resolved, the analyst's only `Bash` call is the read-only `render.sh`; `insights` aggregates issue text only for the local developer who can already read it (no new boundary). |
| Denial of Service | No | Finding 3 resolved by the staged read (plan DD4); no unbounded per-run path remains. |
| Elevation of Privilege | No (resolved) | Finding 1 resolved structurally (constrained subagent) and Finding 4 closes the residual `Bash` path — no route from interpreted content to side effects remains. |

## Artifact Misalignment

- **Finding 5 — terminal-reader wrapping:** Spec AC #8 asserts ingested content is "wrapped in the `<untrusted-issue-content>` marker"; the plan's `issue-analyst` reads files directly as the terminal consumer, so wrapping-for-handoff does not literally occur (the realized control is treat-as-data + no write/exec capability). Intent aligns; the literal wording does not. Route: Plan (reconcile the realized control), or a minor spec clarification of AC #8.

## Routing Recommendations

### Spec amendments
- *(Resolved this run — Findings 1 & 2 were folded into the spec's ACs before plan approval.)*
- **Finding 5 (optional):** clarify AC #8 so the wrapping requirement reads as "applies when content is handed to a subordinate agent," distinct from the terminal-reader disposition — if you prefer the reconciliation to live in the spec rather than the plan.

### Plan amendments
- **Finding 4 (Notable):** ✅ applied — plan DD6 pins the analyst's `Bash` to the exact `render.sh`-only form and drops `jimfile.sh`.
- **Finding 5:** ✅ applied — plan DD2 states the terminal-reader control explicitly.

### Candidate issues
No findings routed to `Issue`. All five findings are resolved across the spec and plan; no open routing remains.
