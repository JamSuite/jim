---
spec: "spec.md"
reviewed_phases: [spec]
status: "Needs Plan Review"
# Finding 1 (Spec) applied to AC10 on 2026-06-26; Findings 2–5 held for /jim:plan.
date: "2026-06-26"
---

<!-- Budget: findings are actionable and specific. No vague "consider security" entries. -->

# Security Review: Depth-aware post-build review

## Summary

**Findings:** 0 Critical · 3 Notable · 2 Advisory

Reviewed spec.md only (no plan.md yet) under the requirements-gap lens. The
feature's new threat surface over spec 026 is the **fan-out of untrusted diff /
commit / ledger content to investigator subagents** and the new `jimledger.sh
diff` channel. No Critical design flaws; the Notable findings tighten the
untrusted-content boundary across the orchestrator↔investigator hop, bound the
fan-out, and pin investigator least-privilege. LINDDUN runs (Credentials present
via the scrub discipline) but is largely N/A under jim's single-trusted-developer
trust model.

## Coverage

- spec.md — reviewed 2026-06-26 (requirements-gap lens)
<!-- plan.md not yet authored — design-flaw lens deferred to /jim:plan's gate -->

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Commit author metadata exists in git but is not a processing purpose; not surfaced to `review.md`. |
| Credentials | Yes | Diffs may carry secret-shaped values; AC4 mandates scrub/minimize before persistence (inherited from spec 026). |
| Session data | No | None handled. |
| Internal-only | Yes | The ledger, `review.md`, and recorded investigation evidence are project-internal artifacts. |
| Public | No | No data intended for public exposure (artifacts may land in a public repo, hence the scrub discipline). |

## Findings

### 1. Investigator return values are a second-order injection channel

- **Severity:** Notable
- **Description:** AC10 requires untrusted-content discipline "throughout the
  deep pass and any spawned investigation," which covers each investigator
  treating the diff as data. But investigators *return* text to the orchestrator,
  and that return value — derived from attacker-influenceable diff/commit content
  — becomes input to the orchestrator's verdict and to `review.md`. A diff hunk
  could steer an investigator into emitting directive-style framing in its
  summary, which then reaches the orchestrator as a fresh, un-wrapped channel. AC10
  as written does not explicitly name the investigator→orchestrator hop.
- **Suggestion:** Extend AC10 (or add an AC) so the orchestrator treats
  investigator results as untrusted data — wrapped and parsed, never as
  instructions — and so the alignment verdict and any scrub of evidence apply to
  investigator-returned content, not just the raw diff. The verdict stays the
  orchestrator's judgment over evidence.
- **Route:** Spec
- **Relates to:** AC #10, Insight 1

### 2. Investigator subagents must be read-only least privilege

- **Severity:** Notable
- **Description:** Insight 1 introduces a new investigator subagent type with its
  own `tools:`. If granted Write/Edit/mutating-Bash (or further Agent), an
  investigator steered by injected diff content could act beyond reading — which
  would breach the read-only invariant (AC9) from inside the fan-out, where the
  skill's main-thread `allowed-tools` does not reach (subagents have independent
  permission scopes per ARCHITECTURE.md → Permission Conventions).
- **Suggestion:** Constrain the investigator agent's `tools:` to the read +
  diff/ledger surface only (Read, Glob, Grep, the `jimledger.sh` diff/files/metrics
  invocations); no Write, no Edit, no mutating Bash, no Agent. Mirrors spec 026
  sec Finding 6 (minimal reviewer tools).
- **Route:** Plan
- **Relates to:** AC #9, Insight 1

### 3. Fan-out breadth must be bounded against an attacker-influenced large diff

- **Severity:** Notable
- **Description:** Diff size is the untrusted axis (a large merged contribution
  inflates the changed-region set). If the orchestrator spawns one investigator
  per high-stakes region with no ceiling, a pathologically large diff can drive
  unbounded subagent spawning — a cost/resource-exhaustion vector even under the
  trusted-developer model. AC8 addresses silent *degradation* but not a spawn cap.
- **Suggestion:** Bound concurrent and total investigators (and have the leaner
  `review_depth` setting cap breadth), prioritizing the highest-risk regions when
  the cap binds; name the bounded coverage in `review.md` (ties to AC8). Resolves
  Open Question 4.
- **Route:** Plan
- **Relates to:** AC #8, Open Question 4

### 4. The new `jimledger.sh diff` subcommand must reuse the range/option-injection guards

- **Severity:** Advisory
- **Description:** Insight 2 adds a `diff` subcommand that interpolates
  `base..head` into git — the same option-injection / range surface that spec 026
  sec Finding 4 hardened for `files`/`metrics`. The `--function-context` (`-W`)
  and any context-width option are additional flag inputs.
- **Suggestion:** Reuse `resolve_range` (SHAs validated via `jimfile.sh valid-id`)
  and the `--` end-of-options guard before interpolation; keep `-W` / context-width
  a fixed literal or a validated integer, never derived from untrusted input. Mark
  the diff output untrusted like `files`. (Already directionally noted in Insight 2
  — flagged so the plan honors it.)
- **Route:** Plan
- **Relates to:** Insight 2

### 5. Recommend a narrowly-scoped settings.json read grant for the fan-out

- **Severity:** Advisory
- **Description:** Per-subagent file reads surface permission prompts unless the
  user grants reads in `.claude/settings.json` (ARCHITECTURE.md → Permission
  Conventions). Documentation that nudges users toward a blanket `Read(*)` to
  silence prompts would widen the read surface for *all* subagents, not just the
  reviewer's investigators.
- **Suggestion:** When documenting the fan-out (README), recommend the narrowest
  grant that works (e.g. repo-scoped reads) rather than an unrestricted wildcard.
- **Route:** Plan
- **Relates to:** Insight 1

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity/authentication boundary — single trusted developer, no external principals. |
| Tampering | Yes | Findings 1, 4 — injected diff/investigator content steering the verdict; git range/option injection. |
| Repudiation | No issues found | Ledger is an append-only honesty aid; tamper-evidence is explicitly out of scope (spec 026). |
| Information Disclosure | Yes | Findings 4, 5 — diff output handling and broad read grants; AC4 scrub mitigates secret leakage into `review.md`. |
| Denial of Service | Yes | Finding 3 — unbounded investigator fan-out driven by diff size. |
| Elevation of Privilege | Yes | Finding 2 — over-privileged investigator subagents inside the fan-out. |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | N/A | No multi-context subject data; single-developer trust model. |
| Identifying | N/A | No anonymized dataset to re-identify. |
| Non-repudiation | N/A | No privacy-relevant subject actions tracked. |
| Detecting | N/A | No subject-presence inference surface. |
| Data Disclosure | Yes | Secret/credential-shaped values from diffs could reach `review.md` or investigators — covered by AC4 scrub + Findings 1, 5. |
| Unawareness & Unintervenability | N/A | The developer is both controller and subject of the artifacts. |
| Non-compliance | N/A | No external privacy policy or regulation in scope. |

## Routing Recommendations

### Spec amendments
- Finding 1 (applied 2026-06-26): extended AC10 to make investigator return
  values an explicit untrusted channel the orchestrator parses as data, with
  scrub/verdict discipline applying to investigator-returned content.

### Plan amendments
- Finding 2: pin the investigator subagent to read-only least-privilege `tools:`.
- Finding 3: bound fan-out breadth (cap + risk-prioritization), name bounded
  coverage in `review.md`.
- Finding 4: reuse validated-SHA + `--` guard for the `diff` subcommand; fixed
  literal context-width.
- Finding 5: document a narrowly-scoped settings.json read grant.

### Candidate issues
No findings route to Issue — all are Spec/Plan amendments for the current work.
