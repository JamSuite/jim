---
spec: "spec.md"
status: Active
date: "2026-06-17"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Second-resolution timestamps for issue created/updated

## Anchors

**`skills/file/scripts/jimfile.sh` — stamping helper home**

- `today_yyyymmdd()` L127–129: single-source date helper emitting `date +%Y%m%d`; a sibling `now_utc_iso8601()` (or `cmd_now`) emitting `date -u +%Y-%m-%dT%H:%M:%SZ` is the natural peer. Both use `LC_ALL=C` from the preamble (L58).
- `cmd_date` L223–225: the `date` subcommand dispatches to `today_yyyymmdd()`; a new `now` subcommand wired to the new helper follows the same shape.
- `resolve_issue_prefix()` L371–398: already calls `date +"$fmt"` inside `render_template` — the new helper must NOT share this path; its format is a hardcoded constant with no argument (F2 constraint).
- `is_valid_id()` L159–178: the allowlist validator mirrored into index.sh and render.sh — the SYNC comment at L156 is the maintenance contract. Relevant to the malformed-value AC because timestamp characters (`T`, `:`, `Z`) need to pass validation at parsing sites, not at the id-validation layer.
- CLI dispatch L607–622: `main()` already dispatches `date` → `cmd_date`; a `now` case follows identically.

**`skills/issue/assets/issue-template.md` — field declaration**

- L13–14: `created: {YYYY-MM-DD}` / `updated: {YYYY-MM-DD}` are the two fields that change to `{YYYY-MM-DDThh:mm:ssZ}` placeholders.
- `skills/issue/SKILL.md` L86: "created / updated — today's date (YYYY-MM-DD)" — this prose in step 3 is the exact change point: replace with "current second-resolution UTC timestamp from the bash helper".
- Step 4 (SKILL.md L92–106): the `!`-injected `jimfile.sh next-id` / `next-num` / `path` calls show how the LLM consumes bash helper output; the timestamp helper is consumed the same way (fenced bash block, output substituted into the draft).

**`skills/issue/scripts/render.sh` — sort and display**

- `read_issue_rows()` L126–151: the awk TSV parse reads `created` verbatim into field 5 of the tab-separated output. No transformation is applied; ISO 8601 `Z` strings pass through unchanged. Malformed-value guard would live here (before appending to the TSV row) or in the consumer.
- `sort_rows()` L401–413 (inside `cmd_list`): `sort -t$'\t' -k5,5${rflag} -k2,2n${rflag}` — field 5 is `created`. ISO 8601 strings sort lexicographically in chronological order; `2026-06-13` (date-only) is a prefix of `2026-06-13T…` so it sorts before any same-day timestamp without any code change. The existing sort structure needs no modification for AC3/AC4.
- `format_row()` L296–313: the `date` column uses `%-12s` printf width — a full timestamp `2026-06-13T14:45:30Z` is 20 characters and overruns the 12-char column. The plan must decide whether to widen the column or accept truncation in the default cols set.
- `render_issue_file()` L479–498: shows `created` from frontmatter directly in `show` output (L495). Already verbatim — no code change needed here for display.

**`skills/issue/scripts/index.sh` — parsing and atomic write**

- `parse_scalar_fields()` L132–153: single awk pass extracts `created` (and six other fields) from frontmatter; output is one value per line, `created` on line 6. The value flows into `meta_created[$slug]` at L352 and is emitted verbatim into the INDEX row at L468. Malformed-value guard (AC8) would live inside or after this awk pass — validate the shape before storing.
- Atomic write L484–526: `mktemp` + `trap` + `mv` + `touch`. This is the established pattern that F3 requires the normalization to reuse exactly.
- SYNC comment L79: is_valid_id copies in index.sh (L81–100) and render.sh (L458–477) and jimfile.sh (L159–178) must remain byte-identical.

**`skills/issue/scripts/backfill.sh` — normalization model**

- L64–124: `main()` iterates `$dir/*.md`, collects un-numbered issues as `"$created\t$file"`, sorts by created-ascending, assigns `num:` ordinals, rewrites each file via per-file `mktemp` + awk + `mv` (L96–115). This is the exact pattern F3 wants the normalization to follow.
- `field_value()` L52–56: reads any scalar frontmatter field via `grep | head | sed` — used to read `created:`. The normalization pass would use the same helper to read `created`/`updated`.
- Idempotency L87: `[[ -n "$(num_of "$f")" ]] && continue` — the normalization analogously skips already-timestamped values.
- Announcement L120–122: `printf 'Assigned display numbers to %d issue(s).\n'` — the normalization announcement follows this style but must additionally state the day-start-placeholder caveat.
- CLI shape: `bash backfill.sh [<issues_dir>]`. The normalization adds a subcommand or flag on this same script rather than a separate file (per spec Insight 2).

**`tests/issues.sh` — test conventions**

- L1–70: testlib sourcing, `run_index`/`run_render`/`run_backfill` invokers, `write_issue` helper. These are the patterns for new timestamp test cases.
- L876–955: backfill test block — `case_issues_backfill_assigns_by_created_order`, `_continues_from_max`, `_idempotent`, `_preserves_content`, `_announces_count`. These five cases are the model for the normalization test cases (same structure, different assertions).
- L1253–1278: `case_issues_render_list_date_tiebreak_by_num` — confirms that same-date values tiebreak by num; the mixed-value sort test (date-only vs. timestamp) needs an analogous structure with two issues that differ only in sub-day time.
- No existing test covers a `created:` value containing `T` or `Z` — new coverage required.

**`tests/jimfile.sh` — helper test conventions**

- L124–128: `case_jimfile_date_yyyymmdd` — tests `jimfile.sh date` emits 8 digits. The new `case_jimfile_now_utc_iso8601` follows this shape: assert output matches `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$`.
- L789–799: `case_jimfile_is_valid_id_triplicate_identical` — guards the SYNC copies. No new copies are added by this spec; the guard is unaffected.

## Local Patterns

**Bash helper pattern** (`jimfile.sh`): zero-argument helper function, aliased as a CLI subcommand with a `cmd_` dispatcher, dispatched from `main()`'s `case` block, `LC_ALL=C` already in the preamble. The format string is a hardcoded literal in the function body — no argument accepted (F2).

**Atomic rewrite pattern** (`backfill.sh` L96–115 / `index.sh` L484–526): `mktemp "$dir/.<name>.tmp.XXXXXX"`, awk rewrite to tmp, `mv tmp target`, `trap 'rm -f "$tmpfile"' EXIT INT TERM`. Both scripts use identical structure; normalization must reuse it byte-for-byte.

**Idempotent migration pattern** (`backfill.sh` L87): skip a file if the target field already has the desired value before processing.

**Frontmatter field-edit pattern** (`backfill.sh` L101–105): awk rewrites the first `---` block, inserting or replacing one field, passing all other lines through unchanged. The normalization does the same but replaces the value of `created:`/`updated:` lines rather than inserting a new line.

**Test case pattern** (`tests/issues.sh`): `write_issue` helper writes a complete fixture file; `run_backfill`/`run_index`/`run_render` captures stdout/stderr/rc; assertions use `assert_match`, `assert_eq`, `assert_exit`.

**Test template for new cases** (`tests/issues.sh` L876–955 for backfill, L1253–1278 for sort). These are the directly applicable models.

## Security & Performance

**F2 (plan-routed):** The new helper's format is a literal constant — `date -u +%Y-%m-%dT%H:%M:%SZ` — never a variable, never config-driven, never derived from `render_template`. The plan must specify this explicitly.

**F3 (plan-routed):** Normalization changes only `created:` and `updated:` in each file. The awk rewriter must be anchored to those exact keys and must pass all other bytes through unmodified. Round-trip test: normalize a file with an already-timestamped `created`, confirm it is unchanged; normalize a file with a date-only value, confirm only those two lines change.

**Malformed-value robustness (AC8):** `parse_scalar_fields` in `index.sh` and `read_issue_rows` in `render.sh` currently pass `created` verbatim into TSV output and the INDEX row. A value with an embedded tab would shift TSV columns. The guard needs to validate the shape — accept `YYYY-MM-DD` or `YYYY-MM-DDThh:mm:ssZ`, degrade to `"-"` (or treat as day-start for sort purposes) and emit an Integrity Warning for anything else. The normalization must skip-with-warning rather than rewrite a non-conforming value.

**`date -u` portability:** `date -u +%Y-%m-%dT%H:%M:%SZ` is identical on GNU coreutils (Linux) and BSD date (macOS). The `-u` flag (UTC) and the format string are POSIX-compatible. No portability issue. The existing `date +%Y%m%d` in `today_yyyymmdd()` uses the same invocation shape without the UTC flag.

**Column width in `list` output:** `format_row()` uses `%-12s` for the `date` column. A full ISO 8601 timestamp is 20 characters — 8 characters over the current width. This affects visual alignment in the default `list` view. The plan must address it: either widen the column or provide a cols configuration note.

## Recommendations

1. **Add `now` subcommand to `jimfile.sh`** (`cmd_now()` emitting `date -u +%Y-%m-%dT%H:%M:%SZ`, dispatched as `now` from `main()`). Zero arguments; format is a hardcoded literal (F2). This is the single source of truth for both `add`-time stamping and `updated` refresh.

2. **Update `issue-template.md`** to replace `{YYYY-MM-DD}` placeholders on `created:` / `updated:` with `{YYYY-MM-DDThh:mm:ssZ}`. Update `SKILL.md` step 3 prose (L86) to say "current second-resolution UTC timestamp from `jimfile.sh now`".

3. **Add normalization subcommand to `backfill.sh`** (e.g., `bash backfill.sh normalize [<dir>]`) following the existing migration pattern: iterate files, skip already-timestamped values (idempotent), rewrite `YYYY-MM-DD` → `YYYY-MM-DDT00:00:00Z` atomically, announce with day-start-placeholder note, warn-and-skip malformed values (F3 / AC8).

4. **Add malformed-value guard** at two sites: (a) in `parse_scalar_fields` awk output or its consumer in `index.sh` — validate `created`/`updated` shapes and emit an Integrity Warning for non-conforming values; (b) in the TSV consumer in `render.sh` — pass non-conforming values as `"-"` for display rather than raw garbage.

5. **`updated`-on-edit convention** lives in `SKILL.md` and/or `ARCHITECTURE.md` as a documented agent convention, not in a script — consistent with the Bash-vs-Prompt Decision Rule (judgment/convention → prompt layer). The convention: when editing an issue through jim's tooling, refresh `updated:` by running `jimfile.sh now` and writing the result into the frontmatter. The plan specifies where the convention is documented (SKILL.md and/or ARCHITECTURE.md Scripting Layer section).

6. **Column width decision for `format_row`**: the plan must pick a width for the `date` column that accommodates the 20-char ISO 8601 timestamp. A width of 22 or 24 would prevent truncation. Widening affects visual alignment of existing date-only collections too (they would gain trailing whitespace). Alternatively, the plan could leave the column width as-is and note that the `date` column in the default `cols` config is best replaced with a custom width for timestamp-heavy collections.

## Alignment

This spec aligns directly with ARCHITECTURE.md → Bash-vs-Prompt Decision Rule: "same input → same output, no judgment" → bash. Deterministic wall-clock stamping is explicitly named as the rationale for moving `created`/`updated` into the bash layer. The `now` helper follows the exact pattern of `today_yyyymmdd()`. The normalization follows `backfill.sh`'s migration shape. No divergence from locked architectural constraints.
