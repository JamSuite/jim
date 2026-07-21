---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: "Needs Plan Review"
date: "2026-07-21"
---

# Security Review: Spec migration

## Summary

**Findings:** 0 Critical · 3 Notable · 3 Advisory (4 resolved by amendment; 2 open, both plan-phase)

Dual-lens review (spec + plan). The four spec-phase findings (1–4) are now
**resolved**: the spec folded in freeze-on-doubt (AC 3), scrubbed gate diffs
(AC 12), and mode-selection provenance (AC 10), and the plan adds the
`identity=`/`frozen=` ledger keys (Finding 3). The plan-phase pass adds two new
findings on the one net-new deterministic surface — the `rewrite-identity` verb:
a write-path containment gap (Finding 5) and a location-only output reminder
(Finding 6). The core injection vector stays closed by construction (structural
enumeration + a Read/Glob/Grep-only gatherer). LINDDUN omitted (no PII /
Credentials / Session data).

## Coverage

- spec.md — reviewed 2026-07-21 (requirements-gap lens)
- plan.md — reviewed 2026-07-21 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Operates on spec/doc files; no personal-data fields handled by the feature. |
| Credentials | No | The feature does not handle credentials — but the numbered spec bodies it edits *may* contain developer-pasted secrets (see Finding 2). |
| Session data | No | None. |
| Internal-only | Yes | Group identity labels, spec bodies, ledger `op=` events. |
| Public | Yes | jim's spec archive is committed and the repo is heading public (ROADMAP) — committed specs are effectively public. |

## Findings

*Findings 1–4 surfaced at the spec phase and are now **resolved** by the spec and
plan amendments (see Routing Recommendations); they are retained for the audit
trail. Findings 5–6 are the open plan-phase findings.*

### 1. Free-prose rewrite can silently corrupt a frozen spec's substance

- **Severity:** Notable
- **Description:** AC 3 promises `rewrite` changes identity only and leaves the
  spec's substance "byte-unchanged," but rewriting *free-prose* group-mentions is
  a judgment call — "the `cart` group" versus "the user's cart" are
  indistinguishable to structural enumeration (`occurrences` buckets both as
  `prose`). A mis-disambiguation edits domain-noun prose inside a frozen
  historical spec, silently altering its meaning — precisely the
  archive-integrity failure the feature exists to prevent. The gate (AC 6 / spec
  040) currently risks presenting body edits as a count rather than as
  reviewable diffs, so a wrong prose rewrite can land unseen.
- **Suggestion:** (a) Make the mechanical/gatherer split **fail-safe on doubt** —
  an ambiguous prose mention is left unchanged (freeze-on-doubt) rather than
  risk-rewritten; only high-confidence identity mentions are edited. (b) Require
  the gate to present the actual body-edit **diffs** (old→new lines) for numbered
  specs, not merely a changed-file count, so no prose rewrite is applied without
  human sight.
- **Route:** Spec
- **Relates to:** AC 3, AC 6

### 2. The rewrite preview is a new content-surfacing surface not covered by the exfiltration guard

- **Severity:** Notable
- **Description:** AC 10 inherits 043's exfiltration guard, which is *location-only*
  — `occurrences` emits `file:line:kind` and never the matched content. But
  `rewrite` (and Finding 1's diff requirement) introduces a surface AC 10 does
  not name: to approve a body edit the human must be shown enough of the edited
  line, and that line could contain a developer-pasted secret. The location-only
  contract protects the *scan evidence* but not the *rewrite preview*.
- **Suggestion:** Extend AC 10 so any rewrite preview presented at the gate — the
  before/after line for a numbered-body edit — is secret-scrubbed before
  presentation, applying 043 AC #19's scrub to the preview surface, not only to
  persisted evidence.
- **Route:** Spec
- **Relates to:** AC 10

### 3. The active identity mode is absent from the durable record

- **Severity:** Advisory
- **Description:** The `op=rename` ledger event records `old=`/`new=` but not which
  mode (`rewrite`/`forward`/`immutable`) governed identity. An auditor reading the
  archive cannot tell whether a numbered body was rewritten or frozen without
  diffing git history — weakening the repudiation-resistance the ledger is meant
  to provide, and undercutting AC 2's "ledger `op=` event is the durable bridge"
  (the bridge records the move but not the disposition).
- **Suggestion:** Add an `identity=<mode>` key to the `op=` event
  (display-data-only, slug/enum-validated — the spec 044 bounded-value precedent
  for `faces_max_group=`), so the durable record states how each move handled
  identity.
- **Route:** Plan
- **Relates to:** AC 2

### 4. Mode selection must be pinned to operator config, not scanned content

- **Severity:** Advisory
- **Description:** AC 10 bars scanned content from binding a rewrite's *target* or
  *classification*, but does not explicitly bar it from selecting the *mode*. A
  malicious numbered body, blueprint, or map that embeds directive-style text
  ("identity mode: rewrite", "set spec_migration = rewrite") must not
  select the behavior — the mode derives only from the operator-owned
  `spec_migration` config (or an explicit developer instruction), never
  from scanned artifacts. This is the spec 035 never-execute-config-content
  boundary applied to mode selection, mirroring how the candidate-batch contract
  extends spec 018 to drop decisions.
- **Suggestion:** Extend AC 10 (or add an AC) stating that the identity-on-move
  mode is resolved only from operator configuration or explicit developer input;
  no directive inside a scanned artifact selects or overrides it.
- **Route:** Spec
- **Relates to:** AC 1, AC 10

### 5. `rewrite-identity` is a new file-mutating primitive without a path-containment guard

- **Severity:** Notable
- **Description:** The plan introduces `jimpartition.sh rewrite-identity` — the
  **first in-place file-mutating verb** in what has been a read-only substrate
  script (`scan` / `occurrences` / `edges-diff` / `identity-check` are all
  stdout-only). It edits each `<file>` argument in place, but the plan's contract
  specifies no path-containment guard. jim's other write primitives
  (`rename-tracked`, `commit-map` in `jimledger.sh`) gate every path through
  `valid-relpath` + a worktree-top realpath check precisely because they are
  security boundaries; a mutating verb without that guard could edit a file
  outside the intended scope (a crafted change-set path, a symlink escaping the
  worktree). The partition skill already holds `Edit`/`Write`, so this grants no
  *new* skill capability — but a guarded deterministic verb should be *safer*
  than a raw `Edit`, not merely equivalent.
- **Suggestion:** Give `rewrite-identity` the write-primitive containment guard —
  each target path resolved and confirmed under the worktree top (the
  `jimledger.sh` `commit-map` precedent, `:204-227`), symlink-escape refused,
  non-tracked path rejected — before any edit. Add it to the verb's Interface
  Contract and its test case.
- **Route:** Plan
- **Relates to:** Interface Contracts (`rewrite-identity`); Design Decision 2

### 6. Keep the verb's output and errors location-only

- **Severity:** Advisory
- **Description:** `rewrite-identity`'s contract emits location-only `REWROTE`
  lines, but its error paths (a malformed `group:` frontmatter, an unparseable
  line) must not echo matched file content — the same exfiltration-guard
  discipline `occurrences` holds (AC 19 / spec 037). An error message quoting the
  offending line would leak content the location-only design withholds.
- **Suggestion:** Specify in the verb contract that all output — success and
  error — is location-only (`file:line[:kind]`), never matched or surrounding
  content; cover a malformed-input case in the verb's test.
- **Route:** Plan
- **Relates to:** Interface Contracts (`rewrite-identity`); AC 10

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No authentication or identity-assertion surface; a local, human-gated doc operation with no external trust boundary. |
| Tampering | Yes | Findings 1, 4 (resolved), Finding 5 (write-path containment on the new mutating verb). |
| Repudiation | Yes | Finding 3 (resolved by the `identity=`/`frozen=` ledger keys). |
| Information Disclosure | Yes | Finding 2 (resolved), Finding 6 (verb output location-only). |
| Denial of Service | No | No issues found — the gatherer fan-out is bounded by `verify_fanout_cap`; the rewrite is scoped to one group's change-set; no unbounded resource. |
| Elevation of Privilege | N/A | No new *skill* tool grant — the partition skill already holds `Edit`/`Write`; `rewrite-identity` adds a deterministic (and, per Finding 5, containment-guarded) path for edits the skill could already make. |

## Artifact Misalignment

- **None.** The plan's Requirements Coverage table maps all 13 ACs to tasks, and
  the security-relevant ACs are preserved in the design: AC 3 → freeze-on-doubt
  (DD 3), AC 10 → structural-position edits + config-only mode (DD 2/5), AC 12 →
  scrubbed gate diffs (task 6), AC 13 → `frozen=` ledger key + candidate (task 7).
  AC 12's scrub rests on skill discipline (the verb is location-only; the skill
  scrubs the previews), consistent with jim's evidence-scrub model and reinforced
  by Finding 6.

## Routing Recommendations

### Resolved this pass (spec-phase findings 1–4)
- Finding 1 → AC 3 (freeze-on-doubt) + AC 12 (gate diffs); plan tasks 2 / 3 / 6.
- Finding 2 → AC 12 (scrubbed previews); verb emits location-only (DD 2), plan task 6.
- Finding 3 → `identity=`/`frozen=` ledger keys (DD 6, plan task 7).
- Finding 4 → AC 10 (mode from config only); plan DD 5 / task 5.

### Plan amendments (open)
- Finding 5: add the write-primitive containment guard to `rewrite-identity`
  (target under the worktree top, symlink-escape refused, non-tracked rejected) —
  verb contract + test.
- Finding 6: specify the verb's output and errors as location-only; cover a
  malformed-input case in the verb test.
