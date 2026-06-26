---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: "Active"
# spec-phase 2026-06-26: F1 applied to AC10; F2–F5 routed to plan.
# plan-phase 2026-06-26: F2–F5 addressed in the plan; F6+F7 applied to the plan.
date: "2026-06-26"
---

<!-- Budget: findings are actionable and specific. No vague "consider security" entries. -->

# Security Review: Depth-aware post-build review

## Summary

**Findings:** 0 Critical · 4 Notable · 3 Advisory

Dual-lens review of spec.md (requirements-gap) and plan.md (design-flaw). The
feature's new threat surface over spec 026 is the **fan-out of untrusted diff /
commit / ledger content to investigator subagents** and the new `jimledger.sh
diff` channel. Spec-phase findings F1–F5 are now addressed (F1 in AC10; F2–F5 by
the plan's DD1/DD4/DD5 + task 7). The plan-phase pass adds **F6** (the
investigator's `jimledger.sh *` grant still includes the write subcommands — a
residual on F2) and **F7** (validate `review_model`). No Critical design flaws.
LINDDUN runs (Credentials present via the scrub discipline) but is largely N/A
under jim's single-trusted-developer trust model.

## Coverage

- spec.md — reviewed 2026-06-26 (requirements-gap lens)
- plan.md — reviewed 2026-06-26 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Commit author metadata exists in git but is not a processing purpose; not surfaced to `review.md`. |
| Credentials | Yes | Diffs may carry secret-shaped values; AC4 mandates scrub/minimize before persistence (inherited from spec 026). |
| Session data | No | None handled. |
| Internal-only | Yes | The ledger, `review.md`, and recorded investigation evidence are project-internal artifacts. |
| Public | No | No data intended for public exposure (artifacts may land in a public repo, hence the scrub discipline). |

## Findings

**Plan-phase disposition (2026-06-26):** F1 resolved in the spec (AC10); F2–F5
addressed by the plan (DD4 read-only investigator, DD5 bounded fan-out, DD1 diff
guards, task 7 settings grant). F6–F7 below are new this pass.

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

### 6. Investigator's `jimledger.sh *` tool grant includes the write subcommands

- **Severity:** Notable
- **Description:** Plan DD4 / task 3 grants the investigator `Bash(bash
  ${CLAUDE_PLUGIN_ROOT}/skills/review/scripts/jimledger.sh *)`. The `*` is not
  read-scoped — it also authorizes `event` / `start` / `finish`, which append to
  `ledger.md`. So the "read-only" investigator can in fact mutate the ledger, a
  residual leak on F2 (a script-level `*` grant cannot select only `diff`/`files`,
  unlike `issue-analyst`'s read-only `render.sh`).
- **Suggestion:** Drop `jimledger.sh` from the investigator's `tools:` entirely.
  Per the Interface Contract the orchestrator passes the diff hunks in the spawn
  prompt, so `Read, Glob, Grep` suffice — leaving the investigator genuinely
  capability-absent for writes/exec.
- **Route:** Plan
- **Relates to:** AC #9, Finding 2, plan DD4 / task 3

### 7. Validate `review_model` before using it as a spawn parameter

- **Severity:** Advisory
- **Description:** `review_model` (trusted config) flows into the Agent tool's
  `model` parameter, which accepts only `sonnet`/`opus`/`haiku`. A typo or
  unsupported value would error or silently no-op the spawn. Not an injection
  (config is data, never sourced), but a robustness gap.
- **Suggestion:** Have the orchestrator validate `review_model` against
  `{inherit, sonnet, opus, haiku}` and fall back to `inherit` (omit the param) on
  anything else.
- **Route:** Plan
- **Relates to:** AC #7, plan DD2

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity/authentication boundary — single trusted developer, no external principals. |
| Tampering | Yes | Findings 1, 4 — injected diff/investigator content steering the verdict; git range/option injection. |
| Repudiation | No issues found | Ledger is an append-only honesty aid; tamper-evidence is explicitly out of scope (spec 026). |
| Information Disclosure | Yes | Findings 4, 5 — diff output handling and broad read grants; AC4 scrub mitigates secret leakage into `review.md`. |
| Denial of Service | Yes | Finding 3 — unbounded investigator fan-out driven by diff size. |
| Elevation of Privilege | Yes | Findings 2, 6 — investigator privilege; the plan's `jimledger.sh *` grant still admits the write subcommands (F6). |

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

## Artifact Misalignment

None — the plan honors the boundaries the spec asserts (AC7 via DD2, AC9 via DD4,
AC10 via DD7). The one gap (F6) is a plan-side design flaw in realizing AC9, not a
spec↔plan contradiction.

## Routing Recommendations

### Spec amendments
- Finding 1 (applied 2026-06-26): extended AC10 to make investigator return
  values an explicit untrusted channel the orchestrator parses as data, with
  scrub/verdict discipline applying to investigator-returned content.

### Plan amendments
- Findings 2–5: addressed by the plan (DD4 read-only investigator; DD5 bounded
  fan-out; DD1 diff guards; task 7 settings grant) — no further change needed
  beyond F6.
- Finding 6 (applied 2026-06-26): dropped `Bash(bash …/jimledger.sh *)` from the
  investigator's `tools:` (it admits the write subcommands) — now `Read, Glob,
  Grep` only; the orchestrator-supplied hunks suffice. (DD4, task 3)
- Finding 7 (applied 2026-06-26): orchestrator validates `review_model` against
  `{inherit, sonnet, opus, haiku}`, falling back to `inherit`. (DD2, task 4)

### Candidate issues
No findings route to Issue — all are Spec/Plan amendments for the current work.
