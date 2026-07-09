---
spec: "docs/specs/jim/042-plan-blast-radius/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-09"
---

<!-- Budget: findings are actionable and specific. No vague "consider security" entries. -->

# Security Review: Plan-time blast-radius advisory

## Summary

**Findings:** 0 Critical · 1 Notable · 2 Advisory — all resolved this cycle

Dual-lens re-run — `plan.md` now present. The plan resolves both spec-phase
Advisory findings (verb-scoped grant → Finding 1; minimal-surface rendering →
Finding 2). The dual lens surfaced one **Notable** artifact misalignment
(Finding 3: inline advisory rendering vs. AC #6's delimiter wording), resolved
this cycle by clarifying AC #6 — the delimiter requirement is scoped to
subagent / persisted contexts; the conversational advisory uses the
data-not-instruction + minimal-surface boundary. STRIDE re-swept in full;
LINDDUN N/A (no PII / Credentials / Session data).

## Coverage

- spec.md — reviewed 2026-07-09 (requirements-gap lens)
- plan.md — reviewed 2026-07-09 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Feature handles no individual/personal data. |
| Credentials | No | No credential management. A provides-face guarantee string *could* incidentally contain a secret-looking token — addressed by Finding 2, not a credential-handling category. |
| Session data | No | No sessions/tokens. |
| Internal-only | Yes | Reads contract-graph edges, group names, and provides/requires face guarantees — internal architectural-structure data. |
| Public | No | Output is developer-facing conversation only. |

## Findings

### 1. Scope the graph-read tool grant to least privilege

- **Severity:** Advisory
- **Description:** The leading design option (research Recommendation A) reads
  the contract graph by reusing `jimverify.sh edges`, which requires adding a
  new `Bash` clause to `/jim:plan`'s `allowed-tools`. A broad
  `Bash(bash …/jimverify.sh *)` grant would expose *all* of `jimverify.sh`'s
  verbs (parse / territory / check / faces / edges / contracts-check / health /
  scope-census) to `/jim:plan` — wider than the single read-only `edges` verb
  the advisory needs. All verbs are read-only, so this is least-privilege
  hygiene, not a live vulnerability.
- **Suggestion:** If the plan adopts the `jimverify.sh` read path, scope the
  new `allowed-tools` clause as tightly as the Claude Code permission syntax
  allows (prefer restricting to the `edges` verb), honoring spec 012's
  allowed-tools narrowing doctrine and the exactness concern tracked in issue
  #52. If the alternative `Read`-tool path (research Recommendation B) is
  chosen instead, no new grant is added and this finding is moot.
- **Route:** Plan
- **Relates to:** research Recommendation 1 / Handoff Insight 2
- **Status: Resolved (this run).** Plan DD #2 adopts the `jimverify.sh` read
  path under a verb-scoped grant — `Bash(bash …/jimverify.sh edges *)` —
  exposing only the read-only `edges` verb. Least-privilege as recommended.
  (The plan's Open Question flags a build-time confirmation that the
  verb-scoped prefix matches; the fallback is the script-level grant.)

### 2. Decide secret-redaction for echoed graph/face text

- **Severity:** Advisory
- **Description:** The advisory persists nothing (AC #2), so 034 AC #12's
  persist-time secret redaction does not directly apply. But if the advisory
  echoes a `Relies on` cell or a provides-face guarantee string as evidence,
  a secret-looking token embedded in that content would be surfaced verbatim in
  the developer's terminal. Applicability is lower than 034's (no git
  persistence; the audience is the repo owner who can already read
  `BLUEPRINT.md`), but the rendering choice should be a conscious one rather
  than incidental.
- **Suggestion:** When the plan designs the advisory's output, prefer naming
  the dependent groups plus a short entry label over echoing full guarantee
  prose (minimize the surfaced surface); if fuller evidence is quoted, run it
  through the same secret-redaction placeholder 029/034 use. Reinforces the
  AC #6 evidence-quoting boundary.
- **Route:** Plan
- **Relates to:** AC #6
- **Status: Resolved (this run).** Plan DD #4 takes the minimal-surface path —
  it renders only the short relied-on entry (not broader guarantee prose) and
  treats it as untrusted display text; nothing is persisted, so no redaction
  placeholder is needed.

### 3. AC #6 delimiter requirement vs. the plan's inline advisory rendering

- **Severity:** Notable
- **Description:** Spec AC #6 (carried from 034 AC #11) requires that graph or
  face content quoted as evidence appear *only inside a delimited
  untrusted-content block*. The plan renders the relied-on entry inline in the
  human-facing advisory (`· <consumer> — relies on: <relies-on entry>`) with a
  "treat as data, never instruction, minimal surface" discipline (DD #4) but no
  delimiter, and does not extend that untrusted-content handling to the
  `Last reconciled` freshness stamp it also echoes. Actual risk is low —
  firing/naming is mechanical (immune to embedded directives), the `edges`
  parser slug-gates group cells and sanitizes all fields, and the output is
  terminal display with no downstream LLM consumer — but the plan and spec
  contradict each other on the trust-boundary AC, which the coder should not
  have to reconcile by guessing.
- **Suggestion:** Resolve the contradiction before build, either by (a)
  clarifying AC #6 that its delimiter requirement governs untrusted content
  crossing into a subagent or a persisted artifact, while a human-facing
  conversational advisory satisfies the boundary via mechanical firing +
  data-not-instruction handling + minimal surface (Route: Spec — recommended,
  since literal delimiters in terminal output are awkward and purposeless
  here); or (b) wrapping the echoed entry in a lightweight untrusted-content
  delimiter in the advisory output (Route: Plan). Either way, extend the chosen
  treatment to the `Last reconciled` stamp, not just the relied-on cell.
- **Route:** Spec
- **Relates to:** AC #6; plan DD #4 / Task 3
- **Status: Resolved (this run).** AC #6 clarified — its delimiter requirement
  is scoped to untrusted content crossing into a subagent or a persisted
  artifact; the human-facing conversational advisory satisfies the trust
  boundary via mechanical firing + data-not-instruction handling + minimal
  surface, which the plan's DD #4 already implements. Plan unchanged; the
  data-not-instruction default extends to the echoed freshness stamp.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity/authentication surface; the advisory asserts no identity and grants none. |
| Tampering | Yes | A tampered or stale contract graph could mislead the advisory (name wrong groups, suppress blast radius). Bounded by design — the advisory is non-authoritative (never veto, writes nothing; AC #2), so a false/suppressed result costs at most a missed heads-up, never a harmful action; the presentation carries a `graph as of <Last reconciled>` freshness stamp (plan Task 3) as a staleness signal. Untrusted handling of the echoed graph content is Finding 3. |
| Repudiation | N/A | Read-only, no state change to audit — consistent with the no-durable-record design. |
| Information Disclosure | Yes | See Finding 3 — the advisory echoes the relied-on entry + freshness stamp (developer-facing, `edges`-sanitized, no persistence). Finding 2's minimal-surface path (plan DD #4) bounds what is surfaced. |
| Denial of Service | N/A | Single-user, developer-controlled input (the developer's own `BLUEPRINT.md`); one bounded graph read per plan run with cheap short-circuits (`edges` rc 2, <2 groups). No external trust boundary. |
| Elevation of Privilege | No issues found | The advisory grants no authority and is read-only; the plan's verb-scoped `edges` grant (DD #2, Finding 1 resolved) keeps the added capability minimal. It runs in `/jim:plan`'s Write-capable main thread, so its non-mutation guarantee is prompt-enforced (AC #2/#6), not capability-isolated — consistent with the 034 reconcile precedent. |

## Artifact Misalignment

- **Finding 3 — AC #6 delimiter vs. inline rendering — RESOLVED.** Spec AC #6
  required quoted graph/face content inside a delimited untrusted-content block;
  the plan (DD #4 / Task 3) renders the relied-on entry inline in the
  conversational advisory. Resolved by clarifying AC #6 (delimiter scoped to
  subagent / persisted contexts; conversational advisory uses
  data-not-instruction + minimal surface). Plan unchanged; spec and plan now
  aligned. See Finding 3.

## Routing Recommendations

### Spec amendments
- Finding 3 (Notable): **applied this cycle** — AC #6 clarified so its delimiter
  requirement is scoped to untrusted content crossing into a subagent or a
  persisted artifact; the human-facing conversational advisory satisfies the
  boundary via mechanical firing + data-not-instruction + minimal surface.

### Plan amendments
- Findings 1 & 2: **resolved this run** by plan DD #2 (verb-scoped grant) and
  DD #4 (minimal-surface rendering) — no further action.
- Finding 3 (if resolved plan-side instead): wrap the echoed relied-on entry +
  freshness stamp in a lightweight untrusted-content delimiter in the advisory
  output.

### Candidate issues
No findings route to `Issue` — Finding 3 is directly actionable in this
spec/plan, not an out-of-scope follow-on.
