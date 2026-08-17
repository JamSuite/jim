---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-06-03"
---

# Security Review: Issue Command Consolidation — subcommand surface

## Summary

**Findings:** 0 Critical · 0 Notable · 2 Advisory (open) · 4 resolved since the spec-phase review.

Re-run with the plan now present (dual spec + plan lens). All four spec-phase
findings are resolved: Findings 1–3 became spec acceptance criteria, and
Finding 4 (backfill file-integrity) is resolved by plan DD #6's per-file atomic
`tmp + mv`. Two new Advisory findings surface at plan review — both hardening
under the trusted-developer model. No Critical or Notable findings remain;
status is Active.

## Coverage

- spec.md — reviewed 2026-06-03 (requirements-gap lens)
- plan.md — reviewed 2026-06-03 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Issue files may contain arbitrary developer-pasted text, but the feature handles no PII as a category. |
| Credentials | No | No credential handling introduced. Inherits 017's "issue body may contain pasted secrets" property, mitigated by the `add` confirm-or-edit scrub reminder (unchanged). |
| Session data | No | None. |
| Internal-only | Yes | Issue files, `INDEX.md`, and the `num:` ordinal are internal development artifacts. |
| Public | No | Issues are committed to the repo and become public if the repo does — the existing 017/018 publication property, not amplified by this spec. |

## Findings

### 1. `show` argument resolution must not compose a filesystem path from raw input

- **Severity:** Notable
- **Description:** `show <id>` accepts an ordinal, bare slug, slug prefix, or full date-prefixed id. The "full id" and "slug" branches invite an implementation that composes a path from the argument (`<issues_dir>/<arg>.md`). Raw input such as `show ../../../../etc/passwd` or an absolute path could then traverse out of the issues directory and disclose arbitrary files via the cleaned-up render. The spec's `show` ACs define resolution behavior but state no constraint that the argument is validated or matched against the known issue set before any path use.
- **Suggestion:** Add an AC requiring `show` to resolve **only against the indexed set of existing issues** (match the argument to known ordinals / slugs / ids), and/or to validate any path-shaped component against the 017 AC-C7 slug rule (reject path separators, `..`, leading dots, control chars) before composing a path. The resolver must never `test`/read a path derived directly from unvalidated input.
- **Route:** Spec
- **Relates to:** Acceptance Criteria → View — `show` (resolution-precedence AC); spec 017 AC-C7.
- **Status (re-run 2026-06-03):** ✅ Resolved — spec AC added ("`show` resolves only against the set of existing issues … never reads or renders a file outside the issues directory"); plan DD #7 implements resolution against the INDEX known set, never composing a path from raw input.

### 2. `show` rendering should be deterministic — or apply the 017 AC-S2 untrusted-content wrapping

- **Severity:** Notable
- **Description:** The spec asserts (Out of Scope, and implicitly via the Data Flow diagram) that 019 adds no new prompt-injection surface because the new read verbs are deterministic. That claim is load-bearing but only "likely" enforced — Handoff Insight 5 says rendering is *likely* deterministic. If `show`'s "cleaned-up render" is instead implemented by feeding the issue body through the LLM to reformat it, it reintroduces exactly the agent-reads-untrusted-body surface that 017 AC-S2 governs and that 019 claims to avoid.
- **Suggestion:** Add an AC pinning `show` (and `list`/`stats`) rendering as deterministic (no LLM interpretation of issue-body content). If any view verb must render via the LLM, require it to wrap issue content in the 017 `<untrusted-issue-content>` marker and instruct the model to ignore embedded directives.
- **Route:** Spec
- **Relates to:** Out of Scope (no new injection surface); Read-only guarantee AC; spec 017 AC-S2.
- **Status (re-run 2026-06-03):** ✅ Resolved — spec AC added ("views render deterministically and never interpret instructions embedded in issue content"); plan DD #1/#2 route `list`/`stats`/`show` through `render.sh` with stdout presented verbatim (no LLM body interpretation).

### 3. `list` filter argument should be validated against the closed status/priority enum

- **Severity:** Advisory
- **Description:** `list <status|priority>` takes a positional filter that flows into a deterministic matcher. If passed unsanitized into `grep`/`awk`/a pattern, a crafted value (regex metacharacters, a leading `-` parsed as a flag, an empty value) could cause argument injection, a mis-scoped match, or a confusing result. The value space is a small closed enum (`open`/`closed`, `critical`/`high`/`medium`/`low`).
- **Suggestion:** Add an AC that the `list` filter is validated against the known closed set of status and priority values; an unrecognized filter yields a clear "unknown filter" message rather than being passed into a pattern matcher. Apply the same closed-set validation to the configurable `cols` value.
- **Route:** Spec
- **Relates to:** Acceptance Criteria → View — `list` (filter AC); Handoff Insight 4 (config keys).
- **Status (re-run 2026-06-03):** ✅ Resolved — spec AC added ("`list` validates its filter argument against the known status and priority value sets … rather than being passed into a pattern matcher"); plan DD #8 implements closed-set filter/column validation. See Finding 5 for the residual group/sort validation gap.

### 4. One-shot `num` backfill must not corrupt issue files on partial failure

- **Severity:** Advisory
- **Description:** The backfill writes a new `num:` field into every existing issue file's frontmatter. A crash, signal, or IO error mid-backfill (or a non-atomic per-file edit) could leave a file with corrupted frontmatter — damaging the relations graph and the collection the rest of the system depends on. The spec requires the backfill be idempotent and content-preserving, but does not state a per-file write-safety property.
- **Suggestion:** Add an AC (or defer to plan) that an interrupted backfill never leaves an issue file in a corrupted state — e.g., per-file atomic write (tmp + `mv`, mirroring 017 DD #12 for `INDEX.md`) so a partial run is safe and resumable via the existing idempotency.
- **Route:** Plan
- **Relates to:** Acceptance Criteria → Display ordinal (backfill AC); spec 017 DD #12 (atomic write pattern).
- **Status (re-run 2026-06-03):** ✅ Resolved — plan DD #6 specifies a dedicated one-shot `backfill.sh` with per-file atomic `tmp + mv` and `trap` cleanup, idempotent so a partial run resumes without corruption. (DD #6 also de-hooks backfill from the verb flow — it is a one-time migration, not a per-invocation step.)

### 5. `list` grouping/sort config values should be validated like the filter

- **Severity:** Advisory
- **Description:** Plan DD #8 validates the `list` *filter* argument and *column* tokens against closed sets, but the `issue_list_group` and `issue_list_sort` config values are only enumerated in the Interface Contract, not explicitly validated. An unrecognized `group`/`sort` value (typo in `jimconf.toml`) could produce a broken render or, if passed into an `awk`/`sort` key expression unchecked, mis-sort silently. Config is developer-authored (trusted), so this is hardening, not a vulnerability.
- **Suggestion:** Validate all three `issue_list_*` values against their allowed sets (Interface Contract); on an unrecognized value, fall back to the documented default rather than passing it into a sort/group expression. Add a test case.
- **Route:** Plan
- **Relates to:** plan DD #8, DD #9; Interface Contract (`issue_list_*` allowed values).

### 6. Spec read-only AC still attributes backfill to read verbs (spec↔plan drift)

- **Severity:** Advisory
- **Description:** The spec's Read-only guarantee AC says the one-shot backfill is among "the only writes any read verb performs." The plan's DD #6 (per your direction) makes backfill a standalone one-shot migration that the verb flow never calls — so read verbs now perform *only* defensive `INDEX.md` regeneration, never backfill. The spec wording over-attributes a write to the read verbs and is now inconsistent with the design.
- **Suggestion:** Update the spec's Read-only guarantee AC to drop backfill from the read-verb write list (read verbs perform only defensive `INDEX.md` regeneration; backfill is an out-of-band migration). A one-line accuracy edit.
- **Route:** Spec
- **Relates to:** spec Read-only guarantee AC; plan DD #6.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No authentication/identity model; all input from the local developer (single trust principal per `ARCHITECTURE.md` § Security Considerations). |
| Tampering | Yes | Finding 4 (backfill file-integrity) — ✅ resolved by plan DD #6 (per-file atomic write). |
| Repudiation | N/A | Git history is the audit trail per spec 017; no new auditable actions introduced. |
| Information Disclosure | Yes | Finding 1 (path traversal via `show`) ✅ resolved; Finding 2 (untrusted-body rendering) ✅ resolved. Repo-publication property unchanged from 017/018. |
| Denial of Service | No | Views are deterministic and bounded over the local collection; single-user, no external request surface. The scaling concern (large-collection analysis) lives in the deferred `trends`/cache spec, not here. |
| Elevation of Privilege | N/A | No privilege model; runs with the developer's own permissions. |

## Artifact Misalignment

- **Finding 6 — Read-only AC vs. out-of-band backfill:** Spec states the one-shot backfill is a write performed by the read verbs; the plan (DD #6) makes backfill a standalone migration the verb flow never calls. The spec wording is now stale. Route: Spec (one-line accuracy edit).

## Routing Recommendations

### Spec amendments
- Finding 6 — ✅ applied: Read-only guarantee AC corrected (read verbs perform only defensive `INDEX.md` regeneration; backfill is an out-of-band one-shot migration).
- Findings 1–3 — ✅ applied as spec acceptance criteria in the prior routing pass.

### Plan amendments
- Finding 5 — ✅ applied: plan DD #8 + tasks 9/10 now validate `issue_list_group`/`issue_list_sort`/`cols` against their allowed sets, falling back to default on unknown.
- Finding 4 — ✅ resolved by plan DD #6 (per-file atomic backfill write).

### Candidate issues
- No findings routed to `Issue` — all are actionable against the current spec/plan.
