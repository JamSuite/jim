---
spec: "docs/specs/jim/029-blueprint-spec/spec.md"
reviewed_phases: [spec, plan]
status: "Active"
date: "2026-06-30"
---

# Security Review: Group blueprint spec (000-blueprint)

## Summary

**Findings:** 0 Critical · 0 Notable · 0 Advisory (open) — all 5 findings resolved (F4 folded into the plan, F5 into the spec; F1–F3 earlier).

Re-run under the dual lens (spec + plan). The three spec-phase findings are
**resolved**: directive-injection and secret-scrubbing were folded into ACs
#10/#11 and plan task 6, and write-path validation is satisfied by plan DD #2.
Two **new** findings surface from the plan: the skill's tool grant should be
least-privilege to bound injection blast radius (EoP), and the spec's absolute
approval gate (AC #1) conflicts with the plan's `auto_blueprint`
override (artifact misalignment). STRIDE swept (6/6); LINDDUN active, only Data
Disclosure relevant.

## Coverage

- spec.md — reviewed 2026-06-30 (requirements-gap lens)
- plan.md — reviewed 2026-06-30 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The feature maps code structure, not personal data. |
| Credentials | Yes | Scanned code may contain hardcoded secrets/keys/tokens the generator reads and could echo into the blueprint. |
| Session data | No | — |
| Internal-only | Yes | The blueprint encodes internal project structure, invariants, and design (like ARCHITECTURE.md). |
| Public | Yes | The artifact is repo-committed; jim's repo is slated to go public (ROADMAP), so persisted content has public-exposure potential — raising the stakes of secret leakage. |

## Findings

### 1. Untrusted ingestion / directive injection

- **Severity:** Notable
- **Status:** Resolved — folded into AC #10 (judgment over evidence) and plan task 6 / DD #7 (untrusted-ingestion guardrail in the skill prompt).
- **Description:** Generation reads a group's code and specs, which can carry attacker-influenced text crafted as instructions. Without a rule that scanned content is data-not-instruction, the generator could be steered or could transcribe misleading content as authoritative.
- **Route:** Spec
- **Relates to:** AC #10.

### 2. Secret scrubbing of scanned content

- **Severity:** Notable
- **Status:** Resolved — folded into AC #11 and plan task 6 / DD #7 (secret-scrub guardrail; task-6 verify greps for it).
- **Description:** Scanned code may contain hardcoded secrets the generator could echo into the repo-committed (soon-public) artifact. The blueprint must scrub secret-looking values to a placeholder.
- **Route:** Spec
- **Relates to:** AC #11.

### 3. Validate the blueprint write-path through the single id boundary

- **Severity:** Advisory
- **Status:** Resolved — plan DD #2 / task 1: `jimfile.sh path blueprint <group>` validates `<group>` via `is_valid_slug` before composing. Refinement for build: the rejection should emit a fixed reason code, not the raw group value (per the `jimfile.sh`/`new.sh` stderr discipline).
- **Description:** The blueprint write target is group-derived; composing it from unvalidated input risks traversal. Group is developer-supplied (trusted), so risk is low, but validation is defensive consistency with the issue emitter.
- **Route:** Plan
- **Relates to:** AC #1, #2.

### 4. The blueprint skill's tool grant should be least-privilege

- **Severity:** Notable
- **Status:** Resolved — folded into plan DD #8 (least-privilege `allowed-tools`) + task 6.
- **Description:** The skill ingests untrusted code/specs and writes a repo-committed artifact. The plan authors `SKILL.md` via `/jim:meta-skill` (task 6 / DD #5) but does not pin its `allowed-tools`. Without an explicit least-privilege grant, a successful directive injection (Finding 1) could escalate beyond writing the human-approved blueprint if the skill holds broad `Bash` or `Agent` capability.
- **Suggestion:** Pin the skill's `allowed-tools` to exactly what it needs — `Read`, `Glob`, `Grep`, `Write`, `Edit`, and a scoped `Bash` for `jimfile.sh`/`jimconf.sh` — with no broad `Bash` and no `Agent`. This is the capability-backed analog of Finding 1's prompt guardrail, mirroring `agents/investigator.md`'s "capability absent, not merely forbidden" boundary.
- **Route:** Plan
- **Relates to:** AC #10; plan task 6, DD #5.

### 5. Spec's approval gate (AC #1) conflicts with the plan's auto-write override

- **Severity:** Notable
- **Status:** Resolved — folded into spec AC #1 (auto-override made explicit).
- **Description:** AC #1 states the blueprint is "written only after the developer approves (no write without approval)". The plan (DD #3/#4) introduces `auto_blueprint`, which auto-writes **without** approval when enabled. The two artifacts disagree on whether a write always requires approval.
- **Suggestion:** Align AC #1 with jim's `auto_*` convention — the approval gate is the default, and `auto_blueprint` (default off) is a documented, user-owned opt-in override (as with `auto_security` / `auto_arch_feedback`). Amend AC #1 to make the override explicit so the gate's semantics are unambiguous.
- **Route:** Spec
- **Relates to:** AC #1; plan DD #3, #4.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity/authentication surface; the sole actor is the developer in their own Claude Code session. |
| Tampering | Yes | Untrusted ingested code/specs → Finding 1 (resolved: AC #10 + plan DD #7). |
| Repudiation | No | Blueprint writes are human-approved and git-tracked; git history plus the ledger stage record is the audit trail. No issues found. |
| Information Disclosure | Yes | Secret leakage into a possibly-public artifact → Finding 2 (resolved: AC #11 + plan DD #7). |
| Denial of Service | N/A | Generation is developer-initiated and bounded by group size; no external request surface. |
| Elevation of Privilege | Yes | A successful injection's blast radius is bounded by the skill's capabilities → Finding 4 (least-privilege tool grant); the write target is validated by plan DD #2. |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | N/A | No personal-data subjects. |
| Identifying | N/A | No anonymous personal data to re-identify. |
| Non-repudiation | N/A | No personal-data-subject actions in scope. |
| Detecting | N/A | No subject-presence inference. |
| Data Disclosure | Yes | Credentials embedded in scanned code → Finding 2 (resolved). |
| Unawareness & Unintervenability | N/A | The only actor is the developer, fully aware and in control via the human-approval gate. |
| Non-compliance | N/A | No personal-data processing; no applicable privacy regulation for code-structure mapping. |

## Artifact Misalignment

- **Finding 5 — Approval gate vs. auto-write:** Spec AC #1 asserts "no write without approval"; plan DD #3/#4 adds `auto_blueprint` (auto-write when enabled). Route: Spec — align AC #1 to the documented, default-off auto-override.

## Routing Recommendations

### Spec amendments
- Finding 5: amend AC #1 to acknowledge the `auto_blueprint` opt-in override (default off), per jim's `auto_*` convention.
- (Findings 1 & 2 already folded into ACs #10/#11 in the prior pass.)

### Plan amendments
- Finding 4: pin the blueprint skill's `allowed-tools` to a least-privilege set (no broad `Bash`, no `Agent`).
- (Finding 3 already addressed by plan DD #2.)
