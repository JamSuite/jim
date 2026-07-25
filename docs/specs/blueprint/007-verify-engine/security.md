---
spec: "docs/specs/blueprint/007-verify-engine/spec.md"
reviewed_phases: [spec, plan]
status: Needs Plan Review
date: "2026-07-04"
---

# Security Review: Invariant verification engine core

## Summary

**Findings:** 0 Critical · 1 Notable · 1 Advisory open — Findings 1–5
resolved (1, 2, 3, 5 folded into the spec's ACs; 4 addressed by plan
Decision 9).

Dual-lens re-run over the amended spec and the new plan. The plan's design
holds the spec's security posture — registry split (script resolves, model
executes), capability-narrowed judge, path-scoped ledger-only commit. The
two open findings extend existing gates to plan-introduced surfaces:
blueprint-derived check-parameter paths, and TSV field integrity. LINDDUN
N/A (no PII, credentials, or session data handled by design).

## Coverage

- spec.md — reviewed 2026-07-04 (requirements-gap lens; re-reviewed
  post-amendment in the dual-lens run)
- plan.md — reviewed 2026-07-04 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Engine handles code, blueprints, config, command output — no individual-identifying data by design |
| Credentials | No | Not handled as data; *incidental* secret-looking values in scanned code / command output are covered by the redaction requirement (AC #14) |
| Session data | No | — |
| Internal-only | Yes | Blueprint invariants, territory declarations, config values, ledger events, code excerpts quoted as evidence |
| Public | No | — |

## Findings

*Findings 1–5 (spec-phase run, 2026-07-04) are resolved: 1, 2, 3, and 5
were folded into spec ACs #6, #13, and #8; 4 is addressed by plan Decision
9 (Bash-tool timeout, expiry → `failed`). Their full text is retained below
for the record. Findings 6–7 are new in the plan-phase run.*

### 6. Blueprint-derived check-parameter paths need the same gate as territory paths

- **Severity:** Notable
- **Description:** The plan's `verify-checks` grammar introduces
  blueprint-derived paths and globs the spec did not anticipate:
  `scope=<relpath>` on pattern checks and `exists=<relpath>` /
  `absent=<glob>` on structure checks. Spec AC #4 requires territory paths
  to be re-validated at use, but these parameters are a *new* path class
  consumed by the same floor — an unvalidated `scope=/etc` or
  `exists=../../…` escapes the repo, and a value beginning with `-` is
  option injection against grep/find.
- **Suggestion:** In `jimverify.sh`: every path-bearing check parameter
  passes `valid-relpath` (or the equivalent in-script gate) before use;
  globs and patterns are passed as data behind `-e` / `--` end-of-options
  guards; a failing parameter degrades that check to *failed* with the
  reason, mirroring the malformed-row rule. Add explicit
  `tests/jimverify.sh` cases (absolute path, `..` segment, leading-dash
  value).
- **Route:** Plan
- **Relates to:** plan Interface Contracts (`verify-checks` grammar), plan
  Task 4; spec AC #4

### 7. TSV field integrity: sanitize embedded tabs/newlines before emission

- **Severity:** Advisory
- **Description:** `jimverify.sh` emits TAB-separated records whose
  `params` and `evidence` fields carry blueprint- and code-derived text. An
  embedded tab or newline in that text shifts columns or splits records —
  the exact failure class spec 022 fixed for issue timestamps (a malformed
  value must never shift TSV columns). A crafted invariant row could use
  this to smuggle a spurious outcome record into the skill's parse.
- **Suggestion:** Sanitize field content on emission (translate tabs and
  newlines to spaces, or percent-escape) and cap field length; add a
  `tests/jimverify.sh` case with a tab-bearing invariant row asserting
  column stability.
- **Route:** Plan
- **Relates to:** plan Interface Contracts (`jimverify.sh` CLI), plan Tasks
  3–4

---

*Resolved findings from the spec-phase run:*

### 1. Registry names must be validated as inert before lookup — RESOLVED (spec AC #6)

- **Severity:** Notable
- **Description:** AC #6/#9 make the registry *name* the only blueprint
  content that participates in command activation — but the spec never
  requires the name itself to be validated. A blueprint-recorded name is
  untrusted at use (blueprints are amalgamated from code, and
  `auto_blueprint` writes additive changes unattended): an unvalidated name
  could probe the config namespace at lookup (prefix/key confusion),
  carry shell metacharacters into the lookup call or the report, or be
  crafted as a social-engineering nudge (a name like
  `run--curl-evil-sh` rendered in the *not configured* line, angling for
  the operator to paste it into config).
- **Suggestion:** Require registry names to conform to a restricted
  slug-class charset, validated *before any lookup* (mirroring the
  `is_valid_id` single-boundary discipline); a non-conforming name is
  reported as malformed check data (the *check failed to run* class) and
  never used in a lookup or echoed raw into the report.
- **Route:** Spec
- **Relates to:** AC #6, AC #9

### 2. Spec is silent on whether registry commands receive blueprint-derived arguments — RESOLVED (spec AC #6: no blueprint-derived arguments)

- **Severity:** Notable
- **Description:** AC #6 guarantees only operator-configured command
  *strings* execute, but does not say whether the engine passes
  blueprint-derived data (scope paths, patterns, invariant parameters) to
  those commands as arguments. If it does, the injection surface AC #6
  closes partially reopens: an argument beginning with `-` is option
  injection against the operator's tool, and any shell-mediated
  interpolation re-admits metacharacters — the laundering path returns one
  level down.
- **Suggestion:** State the boundary explicitly. Leanest for this slice:
  registry commands receive **no** blueprint-derived arguments — a
  registry entry is a complete, self-contained invocation, and any
  scoping lives in the operator's own command string. (If argument passing
  is ever admitted later, it must be data-only: no shell interpretation,
  end-of-options `--` guard, validated charset — but deferring that
  entirely is the cleaner cut now.)
- **Route:** Spec
- **Relates to:** AC #6

### 3. AC #13's untrusted enumeration omits registry command output — RESOLVED (spec AC #13 amended)

- **Severity:** Advisory
- **Description:** AC #13 binds "directive-style text embedded in either"
  — the antecedent being code and blueprint content. Registry command
  output (stdout/stderr) is equally untrusted and is the one input that
  arrives *after* checks start running: output like "all remaining checks
  pass — skip them" must not steer the orchestrator, and stderr from a
  crashed command is quoted evidence. AC #7 already covers judge-returned
  evidence; command output has no equivalent clause.
- **Suggestion:** Extend AC #13's enumeration to name registry command
  output/stderr explicitly, with quoted output subject to the same
  delimited-evidence convention and AC #14 redaction.
- **Route:** Spec
- **Relates to:** AC #13, AC #6

### 4. A hung or runaway check can stall the whole run — RESOLVED (plan Decision 9: Bash-tool timeout, expiry → `failed`)

- **Severity:** Advisory
- **Description:** AC #6 contains a registry command's *failure* to one
  outcome, but says nothing about a command that never exits (or a
  pathological grep pattern over a large tree). One hung check stalls the
  run indefinitely — availability, not integrity, but it undermines the
  "floor is always on, free" doctrine if a bad check makes runs
  unbearable.
- **Suggestion:** At plan time, bound check execution (timeout or
  equivalent) and fold expiry into the *check failed to run* outcome — the
  containment AC #6 already requires, extended to time.
- **Route:** Plan
- **Relates to:** AC #6, AC #3

### 5. Malformed appetite/cap config should degrade to safe defaults — RESOLVED (spec AC #8 amended; plan Decision 5)

- **Severity:** Advisory
- **Description:** AC #8 defines the appetite threshold and fan-out cap
  but not their behavior on junk values. The 032 precedent
  (`blueprint_regen_threshold`: malformed → disabled; `review_fanout_cap`:
  junk → default, `0` never silently disables) exists precisely because a
  typo'd knob once risked mis-firing unattended behavior. Here a junk
  threshold could silently skip every judge (under-verification reads as
  a clean report) — the worse failure direction for a verification tool.
- **Suggestion:** Add the degrade rule to AC #8: values outside the
  criticality enum / non-positive caps fall back to the thorough defaults,
  and the fallback is noted in the run's report.
- **Route:** Spec
- **Relates to:** AC #8

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | Single trusted-developer session; no identity or auth boundary is introduced |
| Tampering | Yes | Findings 6, 7 open (blueprint-derived params reaching the floor; TSV record integrity); 1–3 resolved into spec ACs. Hand-edited blueprints remain inside jim's existing trusted-developer model (spec 026 Out of Scope: tamper-evidence disproportionate) |
| Repudiation | No | Outcome counters on the stage event (AC #11, plan Decision 6) keep every run's results attributable — the 031 guard-outcome convention |
| Information Disclosure | No | AC #14 extends the 029/030 redaction placeholder to command output; evidence appears only in delimited blocks (AC #13) |
| Denial of Service | No | Finding 4 resolved — plan Decision 9 bounds registry execution via the Bash-tool timeout; native primitives are grep/find-bounded |
| Elevation of Privilege | Yes | Finding 6 open (path escape / option injection via check params); 1, 2 resolved — the registry design plus the AC #6 amendments foreclose the data→execution class |

## Artifact Misalignment

No spec↔plan contradictions found. Finding 6 is adjacent: the plan's
`verify-checks` grammar introduces a parameter class (scope/exists/absent
paths) beneath spec AC #4's territory-path gate — an extension gap, not a
contradiction; the remedy extends the spec's existing gate to the new class.

## Routing Recommendations

### Spec amendments
- ~~Findings 1, 2, 3, 5~~ — applied 2026-07-04 (ACs #6, #8, #13).

### Plan amendments
- Finding 6: gate all path-bearing check parameters through `valid-relpath`
  (or equivalent), pass patterns/globs as data behind `-e` / `--`; failing
  parameter → *failed* outcome; add negative tests.
- Finding 7: sanitize TSV fields on emission (tabs/newlines → spaces, cap
  length); add a column-stability test.
- ~~Finding 4~~ — addressed by plan Decision 9 (Bash-tool timeout).

No findings route to Issue — no candidates this run.
