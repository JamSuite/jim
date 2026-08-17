---
spec: "spec.md"
status: Active
date: "2026-06-17"
---

# Research: Re-derive existing issue ids to the active prefix scheme

Phase 0 (local archaeology) only — this is internal bash/POSIX tooling with no
external APIs, libraries, or prior art to consult, so Phase 1 was skipped. All
machinery the feature needs already exists; the work is parameterizing and
composing it behind a preview-then-confirm gate.

## Anchors

**Prefix re-derivation (the core to parameterize — AC #2/#3):**
- `skills/file/scripts/jimfile.sh:384-411` `resolve_issue_prefix` — renders the active scheme's prefix from config **+ the current clock + `issue_next_num`**. Re-derivation must feed it an issue's own `created:` / `num:` instead of "now"; this is the single generalization point.
- `jimfile.sh:333-373` `render_template` — expands `{date:FMT}` / `{seq:W}` tokens deterministically (quoted `date` arg, never eval'd). Feed it the issue's stored date/ordinal.
- `jimfile.sh:168-187` `is_valid_id` — the allowlist (`^[A-Za-z0-9][A-Za-z0-9._-]*$`, ≤128 chars, no `..`); **byte-identical across jimfile/index/render under a SYNC guard**. The full re-derived id passes this (AC #11).
- `jimfile.sh:480-501` collision discriminator — the `-2`/`-3` suffix loop AC #7 reuses; resolve while building the map so the preview shows final paths.
- `jimfile.sh:292-308` `issue_next_num` (the "now" ordinal to bypass) · `jimfile.sh:240-261` `cmd_next_id issue` (current prefix-slug composition to parallel) · `jimfile.sh:645-650` "slug pipeline is the security boundary — never delegate to the LLM."

**Reference recognition (the rewrite must mirror these exactly — security F2):**
- `skills/issue/scripts/index.sh:160-189` `parse_relations` — declarative awk reader of the four typed buckets (2-space indent). Defines what counts as a relation edge.
- `index.sh:208-255` `parse_wikilinks_from_body` — extracts `[[…]]` **after** stripping fenced code + inline backticks, validating slugs via `is_valid_id`. Defines what counts as a body wikilink — and already implements the fenced-code skipping.
- `index.sh:107-153` `extract_frontmatter` / `parse_scalar_fields` (id/created/num readers) · `index.sh:450-473` bidirectional integrity check (`RELATION_INVERSE`) — the post-run verification surface (AC #13).

**Apply mechanics (rename + rewrite, atomic):**
- `skills/issue/scripts/backfill.sh:90-150` `cmd_assign_numbers` & `:152-197` `cmd_normalize` — the canonical per-file `mktemp + awk + mv` rewrite with failure rollback; the **direct template** for "rename file + rewrite fields," and a one-shot migration deliberately NOT wired to the verb flow (exactly 023's shape). Helpers `field_value`/`num_of` at `:58-68`.
- `index.sh:497-540` atomic INDEX write (`mktemp + mv + touch`, trap cleanup) — the post-apply regen + atomicity precedent.

**Tests (coder template):**
- `tests/issues.sh` invokers `run_index`/`run_render`/`run_backfill` (L28-47), `write_issue` (L62-70); `skills/meta-test/scripts/testlib.sh` `empty_dir` (L171-176), `assert_eq`/`assert_match`/`assert_exit` (L101-149), `run_discovered_cases`.
- Cases to mirror: `case_issues_index_wikilink_in_backtick_fence_ignored` (~L393, fence discipline), `case_jimfile_path_debug_collision_appends_2` (~L222, discriminator), `case_issues_index_failure_preserves_prior_index` (~L628, atomic rollback), `case_jimfile_next_id_issue_preset_sequential` (~L687), `case_jimfile_is_valid_id_triplicate_identical` (~L798, SYNC guard).

**New files (architect):** a re-derivation script (a `backfill.sh` sibling subcommand, or a new `rederive.sh`) + a thin `/jim:issue` verb (or standalone invocation) owning the confirm gate; new `tests/issues.sh` cases.

## Local Patterns

- **One-shot migration precedent = `backfill.sh`**: idempotent, announced, per-file atomic `tmp + mv`, NOT wired into the `/jim:issue` verb flow. 023 should mirror this shape exactly.
- **Bash-vs-Prompt rule** (`ARCHITECTURE.md:313-324`): deterministic re-derive/rewrite/rename in bash; the preview-then-confirm gate is the conversational layer — the doc explicitly names "the `/jim:issue` confirm-or-edit moment" as prompt-resident.
- **Script conventions**: `set -uo pipefail; export LC_ALL=C`; resolve dir from `jimconf.sh get issues`; `BASH_SOURCE`-relative inter-script paths; no `jq`/`yq`/`bats`; never `source`/`eval` an issue file.
- **`is_valid_id` SYNC discipline**: byte-identical across three files, guarded by a triplicate test. If re-derivation adds a fourth copy, extend the SYNC guard rather than diverging.
- **Test framework**: hand-rolled bash, run from repo root (`skills/meta-test/scripts/run.sh`), case-name-substring filter. Template above.

## Security & Performance

- **Full-id validation (AC #11, folded F1):** validate prefix + carried slug + `-2`/`-3` discriminator as one unit through `is_valid_id` (≤128, no `..`, allowlist). The carried slug is re-validated, never trusted.
- **Rewrite exactness (carried security F2):** the existing parsers are **read-only extractors** — the rewriter needs *new* in-place awk that edits the same structured sites the parsers recognize (frontmatter relation buckets + body `[[…]]` outside code fences), matching ids on exact boundaries. Never a global/substring find-replace: an old id can legitimately appear in `origin:` paths, prose ("see 20260530-foo"), and code fences, and is a prefix of longer ids. The single definition of "a reference" must be shared with (or test-verified against) `index.sh`, so the rewrite-set equals the index's edge-set.
- **Atomicity & drift (AC #10, carried security F5):** build the complete old→new map before any mutation; apply per-file via `mktemp + mv`; **re-validate inputs haven't drifted between preview and apply** (the confirm gate opens a TOCTOU window); report partial state on failure.
- **Untrusted content (AC #12):** issue files parsed as data; preview surfaces only derived tokens (ids, counts, skip reasons).
- **Performance:** bounded local operation; regenerate INDEX once at the end. No concern at realistic collection sizes.

## Recommendations

1. **Resolver generalization (AC #2/#3):** prefer parameterizing `resolve_issue_prefix` to accept an explicit date/ordinal (single-resolver — keeps the security boundary in one place, per spec Insight 2) over a parallel re-derivation path. Both must route through the same `is_valid_id` guard.
2. **Reference rewrite (F2):** factor the recognition rules (relation-bucket awk + wikilink-with-fence-stripping) so `index.sh` and the rewriter share one definition, or mirror them and add a test asserting the rewrite touches exactly the edges `index.sh` reports. Match `index.sh:208-255`'s fenced-code handling.
3. **Command surface (Insight 1):** a `backfill.sh rederive` subcommand (or sibling `rederive.sh`) computing + printing the plan and applying on a confirmation token, with the confirm driven by a thin verb/prompt — mirrors how read verbs delegate to `render.sh`.
4. **Apply safety (AC #10/F5):** two-phase plan → confirm → apply with an apply-time drift re-check and per-file atomic `mv`.
5. **Collisions (AC #7):** resolve `-2`/`-3` while building the map (reuse `jimfile.sh:480-501`) so the preview shows final paths.

**Alignment:** This fits jim's deterministic Scripting Layer and Bash-vs-Prompt rule (`ARCHITECTURE.md:300-324`) — deterministic work in bash, the confirm gate in the prompt — reuses the established issue machinery (`is_valid_id`, `index.sh` parsers + atomic write, `backfill.sh`'s migration pattern), and preserves the trust boundary (`ARCHITECTURE.md:255`; the id pipeline is never delegated to the LLM). No divergence from a locked constraint.
