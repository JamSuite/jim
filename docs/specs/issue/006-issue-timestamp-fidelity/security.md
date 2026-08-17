---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-06-17"
---

# Security Review: Second-resolution timestamps for issue created/updated

## Summary

**Findings:** 0 Critical · 1 Notable · 5 Advisory

Spec-phase review of a feature that adds second-resolution UTC timestamps to
issue `created`/`updated`, a deterministic bash stamping helper, a skill/agent
`updated`-on-edit convention, and an opt-in backfill normalization. Freeform
expert review plus a full STRIDE sweep; LINDDUN is N/A (no PII / Credentials /
Session data). Within jim's trust boundary (all input is from the trusted local
developer) there are no Critical flaws; the substantive item is input-validation
robustness on timestamp values parsed from semi-structured frontmatter.

**Resolution — spec phase (2026-06-17):** F1 (Notable) and the Spec-routed
advisories F4/F5 were folded into spec 022 (AC #8 plus two Out-of-Scope notes).
**Resolution — plan phase (2026-06-17, dual lens):** F2 and F3 are resolved by
the plan's design (Decisions 2/4, Tasks 1/6); one new Advisory (F6) surfaced and
was folded into the plan (Decision 5 + new Task 7: a SYNC-guarded shape check).
No open Critical or Notable findings remain; status `Active`.

## Coverage

- spec.md — reviewed 2026-06-17 (requirements-gap lens)
- plan.md — reviewed 2026-06-17 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Timestamps are not identifying data. Issue bodies may hold arbitrary author text, but this spec changes only the `created`/`updated` metadata fields. |
| Credentials | No | No secrets, tokens, or keys are handled. |
| Session data | No | No session state. |
| Internal-only | Yes | Issue metadata — including developer activity timestamps — is project-internal data. |
| Public | Yes (conditional) | Issue files are committed to the repo; when the repo is public (jim's own repo is public), the timestamps are published with it. |

## Findings

### 1. Timestamp values parsed from frontmatter are untrusted input to the sort / index / normalize pipeline

- **Severity:** Notable
- **Description:** `created`/`updated` are author-editable frontmatter strings, and this spec both broadens their accepted shape (date → ISO-8601 timestamp) and adds a normalizer that *reads and rewrites* them. `render.sh` parses these values into TSV (`IFS=$'\t'`) and `index.sh` emits them into `INDEX.md`. A malformed value — an embedded tab or newline, non-conforming/garbage text, a non-zero-padded date — could shift TSV columns or inject a spurious row into the rendered `list` view and `INDEX.md`, or feed the normalizer a value it rewrites into something invalid. Values are never `eval`'d (no RCE), so the blast radius is integrity/corruption of generated views, not code execution — but it is a real robustness gap that the richer format and the new write-back path widen.
- **Suggestion:** Validate `created`/`updated` against an explicit date-or-ISO-8601-`Z` shape (mirroring the `is_valid_id` allowlist discipline already used for ids) before sorting, indexing, or normalizing. On a non-conforming value, degrade deterministically — treat as day-start for ordering and skip-with-warning for normalization — rather than passing it through into TSV/`INDEX.md`. Add an AC making "malformed timestamp values never corrupt the views or index" a user-observable requirement.
- **Route:** Spec
- **Relates to:** AC #3, AC #5
- **Resolution (2026-06-17):** Folded into spec 022 as AC #8 — malformed values never corrupt the views or index; they degrade deterministically.

### 2. Keep the stamping helper's format string a hardcoded constant

- **Severity:** Advisory
- **Description:** Spec 021 deliberately bounded the one place where user config reaches `date +"$fmt"` (the `{date:FMT}` template), single-quoting the format and never `eval`ing it. The new stamping helper (Insight 1, `date -u +%Y-%m-%dT%H:%M:%SZ`) must not reintroduce a user- or config-controllable format path — that would re-open a data-to-command surface that 021 worked to contain.
- **Suggestion:** Specify in the plan that the helper takes no format argument and its format is a literal constant; `jimconf.toml` never influences it. The `updated`-refresh convention and the `add` path both call the zero-argument helper.
- **Route:** Plan
- **Relates to:** AC #1, AC #2, Handoff Insight 1
- **Resolution (2026-06-17, plan):** Resolved in plan — Decision 2 + Task 1 specify a zero-argument helper whose format is a hardcoded literal, never via `render_template` / config.

### 3. Normalization must change only the two target fields, atomically and idempotently

- **Severity:** Advisory
- **Description:** The opt-in backfill normalization rewrites existing issue files — the developer's own data. A bug, a greedy match, or an interrupted run could mangle unrelated frontmatter/body content or leave a half-written file.
- **Suggestion:** Reuse `backfill.sh`'s established per-file atomic `tmp + mv`; rewrite only the `created`/`updated` values and preserve every other byte; keep the run idempotent (already specified — already-timestamped values untouched). Add a round-trip test that normalizing a mixed / already-normalized file touches only the intended fields.
- **Route:** Plan
- **Relates to:** AC #5, AC #6, Handoff Insight 2
- **Resolution (2026-06-17, plan):** Resolved in plan — Decision 4 + Task 6 reuse `backfill.sh`'s per-file atomic `mktemp + awk + mv`, rewrite only `created`/`updated`, stay idempotent, and add an F3 round-trip test.

### 4. Timestamps are self-reported and editable — an ordering hint, not a tamper-evident audit trail

- **Severity:** Advisory
- **Description:** Values come from the local machine clock and live in plaintext frontmatter anyone with repo write access can edit or backdate. This is fully acceptable under jim's trust boundary (the developer is trusted; "all input comes from the human developer" per `ARCHITECTURE.md` → Security Considerations), but it should be stated so a future feature does not mistake these timestamps for authoritative provenance.
- **Suggestion:** Add a one-line scope/non-goal note that `created`/`updated` are advisory ordering metadata, not an audit trail — consistent with VISION's "not a project management tool."
- **Route:** Spec
- **Relates to:** Problem Statement, Out of Scope
- **Resolution (2026-06-17):** Folded into spec 022 Out of Scope — timestamps are advisory ordering metadata, not an audit trail.

### 5. Second-resolution timestamps modestly increase activity-metadata exposure in a public repo

- **Severity:** Advisory
- **Description:** Moving from date to per-second timestamps publishes a finer working-pattern signal (burst timing, active hours) whenever the repo is public. The deliberate **UTC** choice is privacy-positive — it avoids leaking the developer's local timezone that a local-offset format would expose — so the net change is a small, intentional tradeoff in service of accurate ordering.
- **Suggestion:** Acknowledge the tradeoff in scope; no further action needed beyond awareness. The UTC decision already mitigates the larger timezone-leak concern, and per-view localization is already Out of Scope.
- **Route:** Spec
- **Relates to:** AC #1, Out of Scope (per-view timezone rendering)
- **Resolution (2026-06-17):** Folded into spec 022 Out of Scope — deliberate metadata tradeoff; UTC already mitigates timezone leak.

### 6. Keep the inlined timestamp-shape regex identical across its three sites

- **Severity:** Advisory
- **Description:** The plan (Decision 5) validates the `created`/`updated` shape with a regex inlined at three sites — `render.sh::read_issue_rows`, `index.sh::parse_scalar_fields`, and `backfill.sh normalize` — deliberately not extending the SYNC-tracked `is_valid_id`. Three independent copies can drift: if one site accepts a shape another rejects, a value could be displayed but warned-on (or, worse, let a tab through at one site), reopening the AC #8 corruption gap the guard exists to close.
- **Suggestion:** Treat the shape regex as a single canonical definition — define it once and reference it, or, matching the existing `is_valid_id` discipline, add a triplicate-identical guard test (mirroring `tests/jimfile.sh::case_jimfile_is_valid_id_triplicate_identical`) asserting the three copies are byte-identical.
- **Route:** Plan
- **Relates to:** plan Decision 5, Tasks 4/5/6, AC #8
- **Resolution (2026-06-17, plan):** Folded into the plan — Decision 5 now requires the copied shape check under a `# SYNC:` comment, and new Task 7 adds the triplicate-identical guard test.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or auth boundary — the plugin runs as the local developer (`ARCHITECTURE.md` → Security Considerations). |
| Tampering | Yes | F1 (malformed values corrupt views/index — folded to spec AC #8), F2 (format surface — resolved in plan), F3 (file-rewrite integrity — resolved in plan), F6 (shape-regex consistency across the three guard sites). The `normalize` awk rewrite injects nothing — only shape-validated values are rewritten, and the replacement is built from validated date components. |
| Repudiation | Yes | F4 (timestamps are editable, not an audit trail). |
| Information Disclosure | Yes | F5 (activity-metadata granularity; UTC mitigates timezone leak). |
| Denial of Service | N/A | No external trust boundary; the collection is local, bounded, and developer-controlled. |
| Elevation of Privilege | N/A | No privilege model; the stamping helper takes no user input (F2 keeps that path closed). |

## Artifact Misalignment

Dual-lens review (spec + plan). No misalignment found — every spec AC has a
corresponding plan task (see the plan's Requirements Coverage Summary), and the
plan's Decision 7 deliberately preserves AC #6 (the `list` column width is left
unchanged so all-legacy collections render byte-identically). One property worth
recording, not a misalignment: AC #2's determinism guarantee relies on the `add`
flow faithfully transcribing `jimfile.sh now`'s output into the frontmatter — the
same trust already placed in the existing `num` / `id` transcription, acceptable
within jim's trust model.

## Routing Recommendations

### Spec amendments
- F1 (Notable): add an AC that malformed/non-conforming `created`/`updated` values never corrupt the `list`/`stats` views or `INDEX.md` — validate the shape and degrade deterministically.
- F4 (Advisory): one-line non-goal note that timestamps are advisory ordering metadata, not a tamper-evident audit trail.
- F5 (Advisory): acknowledge the activity-metadata tradeoff in scope; note UTC already mitigates timezone leakage.

### Plan amendments
- F2, F3 (Advisory): **resolved in plan** — the design now specifies the hardcoded zero-arg helper format (Decision 2 / Task 1) and atomic, target-fields-only, idempotent normalization with a round-trip test (Decision 4 / Task 6).
- F6 (Advisory, new this run): **resolved in plan** — Decision 5 + new Task 7 copy the shape check under a `# SYNC:` comment and add a triplicate-identical guard test.
