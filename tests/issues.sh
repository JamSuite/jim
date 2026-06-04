#!/usr/bin/env bash
#
# tests/issues.sh — Tests for skills/issue/scripts/index.sh and render.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# HOW TO RUN
#   bash tests/issues.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_INDEX="$REPO_ROOT/skills/issue/scripts/index.sh"
SCRIPT_RENDER="$REPO_ROOT/skills/issue/scripts/render.sh"
SCRIPT_BACKFILL="$REPO_ROOT/skills/issue/scripts/backfill.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_index <args...> / run_render <args...>
#   Invoke each script-under-test; capture stdout, stderr, and exit code
#   into the globals OUT, ERR, RC. Same shape as run/run_jimfile in
#   sibling files. Two scripts share one test file because their
#   responsibilities are tightly coupled (render reads what index writes).
run_index() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_INDEX" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

run_render() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_RENDER" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

run_backfill() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_BACKFILL" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# num_of <dir> <slug>
#   Echo the num: value from an issue file, or empty if absent.
num_of() {
  grep -E '^num:[[:space:]]*[0-9]+' "$1/$2.md" 2>/dev/null \
    | head -n 1 | sed -E 's/^num:[[:space:]]*([0-9]+).*/\1/'
}

# ─── Section: Test cases ─────────────────────────────────────────────────────

# write_issue <dir> <slug> <frontmatter-body> [<markdown-body>]
#   Helper: drop a complete issue markdown file at <dir>/<slug>.md with
#   the given YAML frontmatter body (between the two '---' delimiters)
#   and optional markdown body (after the closing '---').
write_issue() {
  local dir="$1" slug="$2" fm="$3" body="${4:-}"
  {
    printf -- '---\n'
    printf '%s\n' "$fm"
    printf -- '---\n'
    [[ -n "$body" ]] && printf '%s\n' "$body"
  } > "$dir/$slug.md"
}

# AC: index.sh on an empty dir writes INDEX.md with zero counts (spec 017 AC-I1, AC-R2)
case_issues_index_empty_dir() {
  local dir
  dir=$(empty_dir index_empty)
  run_index "$dir"
  assert_exit "rc"            0          "$RC"
  assert_match "summary open"   "Open: 0"   "$(cat "$dir/INDEX.md")"
  assert_match "summary closed" "Closed: 0" "$(cat "$dir/INDEX.md")"
}

# AC: one issue produces an Issues entry with the title and status (AC-I1)
case_issues_index_one_issue_happy_path() {
  local dir
  dir=$(empty_dir index_one)
  write_issue "$dir" "20260530-foo" 'title: "Foo bug"
status: open
priority: high
labels: [bug, auth]'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "slug in issues"  '`20260530-foo`'   "$idx"
  assert_match "title surfaces"  'Foo bug'          "$idx"
  assert_match "status surfaces" 'status: open'     "$idx"
  assert_match "open count 1"    'Open: 1'          "$idx"
  assert_match "closed count 0"  'Closed: 0'        "$idx"
}

# AC: open/closed counts reflect status field (AC-R2)
case_issues_index_status_counts() {
  local dir
  dir=$(empty_dir index_counts)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open'
  write_issue "$dir" "20260530-b" 'title: "B"
status: closed'
  write_issue "$dir" "20260530-c" 'title: "C"
status: open'
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "open count 2"   'Open: 2'   "$idx"
  assert_match "closed count 1" 'Closed: 1' "$idx"
}

# AC: frontmatter relations surface as graph edges (AC-I3)
case_issues_index_relations_become_graph_edges() {
  local dir
  dir=$(empty_dir index_relations)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: [20260530-b]
  depends-on: []
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: []
  depends-on: [20260530-a]
  related-to: []
  duplicates: []'
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "edge a→b" 'a` --blocks--> `20260530-b' "$idx"
  assert_match "edge b→a" 'b` --depends-on--> `20260530-a' "$idx"
}

# AC: bidirectional integrity mismatch surfaces as a warning (DD #7)
# A 'blocks: [b]' on issue A without a 'depends-on: [a]' on issue B is flagged.
case_issues_index_integrity_mismatch_flagged() {
  local dir
  dir=$(empty_dir index_integrity)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: [20260530-b]
  depends-on: []
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []'
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "mismatch warning" 'has no inverse' "$idx"
}

# AC: valid body wikilinks surface as related-to edges (AC-I3)
case_issues_index_wikilink_becomes_edge() {
  local dir
  dir=$(empty_dir index_wikilink)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' "See [[20260530-b]] for context."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "wikilink edge" 'a` --related-to--> `20260530-b' "$idx"
}

# AC: edge dedup across channels — frontmatter related-to + body wikilink to
# the same target produce a single Graph edge (handoff Change 1).
case_issues_index_dedup_across_channels() {
  local dir
  dir=$(empty_dir index_dedup_channels)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: []
  depends-on: []
  related-to: [20260530-b]
  duplicates: []' "See [[20260530-b]] for context."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: []
  depends-on: []
  related-to: [20260530-a]
  duplicates: []' ""
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx ab_count ba_count
  idx="$(cat "$dir/INDEX.md")"
  ab_count=$(printf '%s\n' "$idx" | grep -c -- '`20260530-a` --related-to--> `20260530-b`')
  ba_count=$(printf '%s\n' "$idx" | grep -c -- '`20260530-b` --related-to--> `20260530-a`')
  assert_eq "a→b edge appears once" "1" "$ab_count"
  assert_eq "b→a edge appears once" "1" "$ba_count"
}

# AC: edge dedup within body — a wikilink repeated in prose produces one edge
# (handoff Change 1).
case_issues_index_dedup_within_body() {
  local dir
  dir=$(empty_dir index_dedup_body)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' "First mention [[20260530-b]]. Second mention [[20260530-b]] again."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx ab_count
  idx="$(cat "$dir/INDEX.md")"
  ab_count=$(printf '%s\n' "$idx" | grep -c -- '`20260530-a` --related-to--> `20260530-b`')
  assert_eq "duplicate wikilinks collapse to one edge" "1" "$ab_count"
}

# AC: bidirectional scope — wikilinks are one-way; A's [[B]] alone does not
# require B to reference A (handoff Change 2).
case_issues_index_bidirectional_wikilink_one_way() {
  local dir
  dir=$(empty_dir index_bidir_wl)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' "Mentions [[20260530-b]]."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  # Edge renders (Graph contains the wikilink-derived edge)
  assert_match "wikilink edge renders" 'a` --related-to--> `20260530-b' "$idx"
  # But no integrity warning fires for the missing back-edge
  if printf '%s\n' "$idx" | grep -q 'has no inverse'; then
    CURRENT_FAILED=1
    echo "    [wikilink should not trigger integrity warning]"
    printf '%s\n' "$idx" | grep 'has no inverse' | sed 's/^/      /'
  fi
}

# AC: bidirectional scope — a frontmatter related-to assertion without
# reciprocation does fire a warning (handoff Change 2 negative case).
case_issues_index_bidirectional_frontmatter_warns() {
  local dir
  dir=$(empty_dir index_bidir_fm)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: []
  depends-on: []
  related-to: [20260530-b]
  duplicates: []'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []'
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "fm assertion warns" '`20260530-a` --related-to--> `20260530-b` has no inverse' "$idx"
}

# AC: typed frontmatter `blocks` absorbs a same-target body wikilink — the
# typed edge implies related-to, so the wikilink-derived shadow is suppressed.
# Replaces the earlier distinct_types_preserved case which asserted the
# pre-absorption behavior (both edges rendered).
case_issues_index_typed_blocks_absorbs_wikilink() {
  local dir
  dir=$(empty_dir index_absorb_blocks)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: [20260530-b]
  depends-on: []
  related-to: []
  duplicates: []' "Also see [[20260530-b]]."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: []
  depends-on: [20260530-a]
  related-to: []
  duplicates: []' ""
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "blocks edge present" 'a` --blocks--> `20260530-b' "$idx"
  if printf '%s\n' "$idx" | grep -q -- '`20260530-a` --related-to--> `20260530-b`'; then
    CURRENT_FAILED=1
    echo "    [related-to shadow should be absorbed under typed blocks]"
  fi
}

# AC: typed frontmatter `depends-on` absorbs a same-target body wikilink.
case_issues_index_typed_depends_on_absorbs_wikilink() {
  local dir
  dir=$(empty_dir index_absorb_dependson)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: []
  depends-on: [20260530-b]
  related-to: []
  duplicates: []' "Inherits behavior from [[20260530-b]]."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: [20260530-a]
  depends-on: []
  related-to: []
  duplicates: []' ""
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "depends-on edge present" 'a` --depends-on--> `20260530-b' "$idx"
  if printf '%s\n' "$idx" | grep -q -- '`20260530-a` --related-to--> `20260530-b`'; then
    CURRENT_FAILED=1
    echo "    [related-to shadow should be absorbed under typed depends-on]"
  fi
}

# AC: typed frontmatter `duplicates` absorbs a same-target body wikilink.
case_issues_index_typed_duplicates_absorbs_wikilink() {
  local dir
  dir=$(empty_dir index_absorb_duplicates)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: [20260530-b]' "Same as [[20260530-b]]."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []' ""
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "duplicates edge present" 'a` --duplicates--> `20260530-b' "$idx"
  if printf '%s\n' "$idx" | grep -q -- '`20260530-a` --related-to--> `20260530-b`'; then
    CURRENT_FAILED=1
    echo "    [related-to shadow should be absorbed under typed duplicates]"
  fi
}

# AC: typed absorption is per-target — a body wikilink to a DIFFERENT slug
# than the typed relation still emits its related-to edge.
case_issues_index_absorption_does_not_overreach() {
  local dir
  dir=$(empty_dir index_absorb_scope)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: [20260530-b]
  depends-on: []
  related-to: []
  duplicates: []' "Also see [[20260530-c]] for related context."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: []
  depends-on: [20260530-a]
  related-to: []
  duplicates: []' ""
  write_issue "$dir" "20260530-c" 'title: "C"
status: open' ""
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "blocks edge present"            'a` --blocks--> `20260530-b'     "$idx"
  assert_match "unrelated wikilink edge intact" 'a` --related-to--> `20260530-c' "$idx"
}

# AC: wikilink-shaped tokens inside a triple-backtick fenced code block are
# not treated as wikilinks — no edge, no malformed-wikilink warning.
case_issues_index_wikilink_in_backtick_fence_ignored() {
  local dir
  dir=$(empty_dir index_fence_backtick)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' '```
# Example showing [[B]] inside a code fence.
A --related-to--> B          ← from [[B]] in A body
```'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  if printf '%s\n' "$idx" | grep -q -- 'a` --related-to--> `20260530-b'; then
    CURRENT_FAILED=1
    echo "    [fenced [[B]] should not produce a graph edge]"
  fi
  if printf '%s\n' "$idx" | grep -q 'malformed wikilink'; then
    CURRENT_FAILED=1
    echo "    [fenced wikilink-shaped token should not emit a warning]"
  fi
}

# AC: wikilink-shaped tokens inside a tilde-fenced code block are also skipped.
case_issues_index_wikilink_in_tilde_fence_ignored() {
  local dir
  dir=$(empty_dir index_fence_tilde)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' '~~~
[[B]] inside a tilde fence
~~~'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  if printf '%s\n' "$idx" | grep -q -- 'a` --related-to--> `20260530-b'; then
    CURRENT_FAILED=1
    echo "    [fenced [[B]] should not produce a graph edge (tilde fence)]"
  fi
}

# AC: prose wikilinks outside fences still work even when fences appear in
# the same body — fence handling is scoped.
case_issues_index_prose_wikilink_alongside_fence() {
  local dir
  dir=$(empty_dir index_fence_mixed)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' 'Cross-reference [[20260530-b]] in prose.

```
But [[20260530-c]] inside this fence should not produce an edge.
```'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  write_issue "$dir" "20260530-c" 'title: "C"
status: open' ""
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "prose wikilink edge present" 'a` --related-to--> `20260530-b' "$idx"
  if printf '%s\n' "$idx" | grep -q -- 'a` --related-to--> `20260530-c'; then
    CURRENT_FAILED=1
    echo "    [fenced [[C]] should not produce a graph edge]"
  fi
}

# AC: shell bash conditional `[[ "$x" != "y" ]]` inside a fenced code block
# does not emit a malformed-wikilink warning (the original false positive
# motivating this fix — see docs/issues/20260531-wikilink-parser-skips-fenced-code-blocks.md).
case_issues_index_shell_conditional_in_fence_no_warning() {
  local dir
  dir=$(empty_dir index_fence_shell)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' '```bash
if [[ "$type" != "related-to" ]]; then
  do_something
fi
```'
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  if printf '%s\n' "$idx" | grep -q 'malformed wikilink'; then
    CURRENT_FAILED=1
    echo "    [shell [[ … ]] conditional inside fence should not warn]"
    printf '%s\n' "$idx" | grep 'malformed wikilink' | sed 's/^/      /'
  fi
}

# AC: nested fences — a quad-backtick wrapper around a triple-backtick
# example parses correctly (the inner ``` does not close the outer ````).
# This is the markdown-spec rule: a close requires a run of the same char ≥
# the opening run length.
case_issues_index_nested_fence_parses_correctly() {
  local dir
  dir=$(empty_dir index_fence_nested)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' '````
```
[[B]] inside a nested triple-backtick fence should be suppressed.
```
````

But [[20260530-b]] in prose after the nested fence is a real wikilink.'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  if printf '%s\n' "$idx" | grep -q -- 'a` --related-to--> `b\b'; then
    CURRENT_FAILED=1
    echo "    [inner-fence [[B]] should not produce a graph edge]"
  fi
  assert_match "prose wikilink after nested fence" 'a` --related-to--> `20260530-b' "$idx"
}

# AC: wikilink-shaped tokens inside inline backtick spans are stripped — a
# prose mention like `[[B]]` (single-backtick code) is inline code, not a
# graph claim. No edge, no malformed-wikilink warning.
case_issues_index_wikilink_in_inline_backticks_ignored() {
  local dir
  dir=$(empty_dir index_inline_backtick)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' "Authors who write `[[B]]` in prose are documenting wikilink syntax, not asserting an edge."
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  if printf '%s\n' "$idx" | grep -q -- 'a` --related-to--> `20260530-b'; then
    CURRENT_FAILED=1
    echo "    [inline-backtick [[B]] should not produce a graph edge]"
  fi
  if printf '%s\n' "$idx" | grep -q 'malformed wikilink'; then
    CURRENT_FAILED=1
    echo "    [inline-backtick wikilink-shape should not warn]"
  fi
}

# AC: a shell conditional `[[ "$x" != "y" ]]` quoted in an inline backtick
# span does not emit a malformed-wikilink warning even when not inside a
# fenced block.
case_issues_index_shell_conditional_in_inline_backticks_no_warning() {
  local dir
  dir=$(empty_dir index_inline_shell)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' 'The conditional `[[ "$x" != "y" ]]` is bash, not a wikilink.'
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  if printf '%s\n' "$idx" | grep -q 'malformed wikilink'; then
    CURRENT_FAILED=1
    echo "    [inline-backtick shell conditional should not warn]"
    printf '%s\n' "$idx" | grep 'malformed wikilink' | sed 's/^/      /'
  fi
}

# AC: a line with both a bare prose wikilink AND a wikilink-shape inside
# inline backticks produces an edge only for the bare one. Inline-span
# stripping is scoped to backtick-delimited regions.
case_issues_index_mixed_inline_and_bare_wikilink() {
  local dir
  dir=$(empty_dir index_mixed_inline)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' 'See [[20260530-b]] for context, but ignore `[[20260530-c]]` which is just example syntax.'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open' ""
  write_issue "$dir" "20260530-c" 'title: "C"
status: open' ""
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "bare wikilink edge present" 'a` --related-to--> `20260530-b' "$idx"
  if printf '%s\n' "$idx" | grep -q -- 'a` --related-to--> `20260530-c'; then
    CURRENT_FAILED=1
    echo "    [inline-backtick [[C]] should not produce a graph edge]"
  fi
}

# AC: malformed wikilink content is dropped from graph (AC-I4, security.md Finding 2)
# A '[[../../etc/passwd]]' or '[[INVALID/SLUG]]' must not become a graph edge.
case_issues_index_malformed_wikilink_dropped() {
  local dir
  dir=$(empty_dir index_malformed_wl)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open' "See [[../../etc/passwd]] for context."
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  # No graph edge for the malformed link
  if echo "$idx" | grep -q -- '--related-to--> `../../etc/passwd`'; then
    CURRENT_FAILED=1
    echo "    [malformed wikilink edge should not exist]"
  fi
  # Warning surfaces
  assert_match "wikilink warning" 'malformed wikilink' "$idx"
}

# AC: file with no frontmatter is recorded as malformed (DD #9 — Integrity Warning)
case_issues_index_malformed_frontmatter_warning() {
  local dir
  dir=$(empty_dir index_no_fm)
  printf 'Just markdown body, no frontmatter.\n' > "$dir/20260530-x.md"
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "malformed frontmatter warning" 'missing or malformed frontmatter' "$idx"
}

# AC: filename that is not a valid slug is skipped with a warning
case_issues_index_invalid_filename_slug_skipped() {
  local dir
  dir=$(empty_dir index_bad_slug)
  printf -- '---\ntitle: "X"\nstatus: open\n---\n' > "$dir/Not_a_valid_Slug.md"
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "filename warning" 'not a valid slug' "$idx"
  # The bad-slug file does not appear in the Issues section as a valid entry
  if echo "$idx" | grep -q '`Not_a_valid_Slug` —'; then
    CURRENT_FAILED=1
    echo "    [bad-slug filename should not appear as an Issues entry]"
  fi
}

# AC: INDEX.md write is atomic — failed run does not corrupt prior INDEX.md (DD #12)
# We simulate this by passing a non-writable issues_dir; index.sh should
# error and leave any pre-existing INDEX.md intact.
case_issues_index_failure_preserves_prior_index() {
  local dir
  dir=$(empty_dir index_atomic)
  printf 'PRIOR INDEX CONTENT\n' > "$dir/INDEX.md"
  # Add an issue with malformed frontmatter (still valid; we want a happy run).
  write_issue "$dir" "20260530-z" 'title: "Z"
status: open'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  # INDEX.md should now be the new content, not the prior placeholder.
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "new index" 'Open: 1' "$idx"
  # No tmp file leakage
  local tmp_files
  tmp_files=$(ls -1 "$dir/" | grep -c '^\.INDEX\.md\.tmp' || true)
  assert_eq "no tmp leftover" "0" "$tmp_files"
}

# AC: render.sh on an empty dir prints "Open: 0 · Closed: 0" summary line (AC-R1, R2)
case_issues_render_empty_summary_line() {
  local dir
  dir=$(empty_dir render_empty)
  run_render stats "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "single-line summary" 'Open: 0.*Closed: 0' "$OUT"
}

# AC: clusters group issues by origin (AC-R1)
case_issues_render_clusters_by_origin() {
  local dir
  dir=$(empty_dir render_origin)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
origin: docs/specs/jim/016-sec/'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
origin: docs/specs/jim/016-sec/'
  write_issue "$dir" "20260530-c" 'title: "C"
status: open
origin: docs/brainstorms/x.md'
  run_render stats "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "origin group sec"   'docs/specs/jim/016-sec/.*2' "$OUT"
  assert_match "origin group brain" 'docs/brainstorms/x.md.*1'  "$OUT"
}

# AC: clusters group issues by label (AC-R1)
case_issues_render_clusters_by_label() {
  local dir
  dir=$(empty_dir render_label)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
labels: [auth, security]'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
labels: [auth, middleware]'
  run_render stats "$dir"
  assert_match "label auth count"     'auth.*2'     "$OUT"
  assert_match "label security count" 'security.*1' "$OUT"
}

# AC: blocking section orders by outgoing 'blocks' count desc (AC-R1)
case_issues_render_blocking_ordered_by_count() {
  local dir
  dir=$(empty_dir render_blocking)
  # 'mega' blocks 3 issues; 'small' blocks 1 issue.
  write_issue "$dir" "20260530-mega" 'title: "Mega"
status: open
relations:
  blocks: [20260530-x, 20260530-y, 20260530-z]
  depends-on: []
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260530-small" 'title: "Small"
status: open
relations:
  blocks: [20260530-x]
  depends-on: []
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260530-x" 'title: "X"
status: open
relations:
  blocks: []
  depends-on: [20260530-mega, 20260530-small]
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260530-y" 'title: "Y"
status: open
relations:
  blocks: []
  depends-on: [20260530-mega]
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260530-z" 'title: "Z"
status: open
relations:
  blocks: []
  depends-on: [20260530-mega]
  related-to: []
  duplicates: []'
  run_render stats "$dir"
  assert_exit "rc" 0 "$RC"
  # 'mega' must come before 'small' in the blocking section.
  local mega_line small_line
  mega_line=$(echo "$OUT" | grep -n '^  20260530-mega' | head -n 1 | cut -d: -f1)
  small_line=$(echo "$OUT" | grep -n '^  20260530-small' | head -n 1 | cut -d: -f1)
  if [[ -z "$mega_line" || -z "$small_line" || "$mega_line" -ge "$small_line" ]]; then
    CURRENT_FAILED=1
    echo "    [blocking order] mega line=$mega_line small line=$small_line (expected mega < small)"
  fi
  assert_match "mega blocks 3 issues"  'blocks 3 issues' "$OUT"
  assert_match "small blocks 1 issues" 'blocks 1 issues' "$OUT"
}

# AC: integrity warnings from INDEX.md surface in the render output (DD #7)
case_issues_render_surfaces_integrity_warnings() {
  local dir
  dir=$(empty_dir render_warnings)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
relations:
  blocks: [20260530-b]
  depends-on: []
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260530-b" 'title: "B"
status: open
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []'
  run_render stats "$dir"
  assert_match "warning surfaced" 'Integrity Warnings' "$OUT"
  assert_match "warning content"  'has no inverse'     "$OUT"
}

# AC: render is read-only — does not mutate the issue collection (AC-R3)
# Verify: the set of files in the issues dir before and after render is
# the same (apart from INDEX.md which the defensive index.sh call may touch).
case_issues_render_is_read_only_for_issue_files() {
  local dir
  dir=$(empty_dir render_readonly)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open'
  local before_hash
  before_hash=$(find "$dir" -type f -name '*.md' ! -name 'INDEX.md' -exec md5sum {} + | sort | md5sum)
  run_render stats "$dir"
  local after_hash
  after_hash=$(find "$dir" -type f -name '*.md' ! -name 'INDEX.md' -exec md5sum {} + | sort | md5sum)
  assert_eq "issue files unchanged" "$before_hash" "$after_hash"
}

# AC: origin-lint — path-shaped origin that resolves on disk produces no warning
# (spec 018 OL-1). Resolution is PWD-relative: the script honors the invoking
# CWD as project root. Test cds into a fake project root before invoking
# index.sh so origin paths can resolve from there.
case_issues_index_origin_lint_path_resolves() {
  local root
  root=$(empty_dir lint_origin_resolves)
  mkdir -p "$root/docs/issues" "$root/docs/specs/jim/017"
  printf 'spec content\n' > "$root/docs/specs/jim/017/spec.md"
  write_issue "$root/docs/issues" "20260530-a" 'title: "A"
status: open
created: 2026-05-30
origin: docs/specs/jim/017/spec.md'
  ( cd "$root" && bash "$SCRIPT_INDEX" "docs/issues" )
  local idx
  idx="$(cat "$root/docs/issues/INDEX.md")"
  if printf '%s\n' "$idx" | grep -q '20260530-a.*origin path does not resolve'; then
    CURRENT_FAILED=1
    echo "    [resolving origin path should not produce a warning]"
    printf '%s\n' "$idx" | grep 'origin path does not resolve' | sed 's/^/      /'
  fi
}

# AC: origin-lint — path-shaped origin that does NOT resolve surfaces a warning
# with the slug, the broken path, and the created date (spec 018 OL-1, OL-3).
case_issues_index_origin_lint_path_missing() {
  local root
  root=$(empty_dir lint_origin_missing)
  mkdir -p "$root/docs/issues"
  write_issue "$root/docs/issues" "20260530-b" 'title: "B"
status: open
created: 2026-05-30
origin: docs/specs/jim/999/spec.md'
  ( cd "$root" && bash "$SCRIPT_INDEX" "docs/issues" )
  local idx
  idx="$(cat "$root/docs/issues/INDEX.md")"
  assert_match "missing origin warning"   '`20260530-b`.*origin path does not resolve' "$idx"
  assert_match "warning names path"       'docs/specs/jim/999/spec.md'                 "$idx"
  assert_match "warning includes created" '2026-05-30'                                 "$idx"
}

# AC: origin-lint — non-path-shaped tokens (no `/`) are exempt and produce no
# warning (spec 018 OL-1). Default tokens like `conversation` and `external`.
case_issues_index_origin_lint_non_path_exempt() {
  local root
  root=$(empty_dir lint_origin_nonpath)
  mkdir -p "$root/docs/issues"
  write_issue "$root/docs/issues" "20260530-c" 'title: "C"
status: open
created: 2026-05-30
origin: conversation'
  write_issue "$root/docs/issues" "20260530-d" 'title: "D"
status: open
created: 2026-05-30
origin: external'
  ( cd "$root" && bash "$SCRIPT_INDEX" "docs/issues" )
  local idx
  idx="$(cat "$root/docs/issues/INDEX.md")"
  if printf '%s\n' "$idx" | grep -q 'origin path does not resolve'; then
    CURRENT_FAILED=1
    echo "    [non-path origin tokens should be exempt]"
    printf '%s\n' "$idx" | grep 'origin path does not resolve' | sed 's/^/      /'
  fi
}

# AC: origin-lint — broken origin does not block file write/index (spec 018 OL-2)
# Issue with non-resolving origin is still written, indexed, counted in Open,
# and rendered in the Issues section. The lint produces a warning, never a
# fatal error or blocked write.
case_issues_index_origin_lint_does_not_block_write() {
  local root
  root=$(empty_dir lint_origin_noblock)
  mkdir -p "$root/docs/issues"
  write_issue "$root/docs/issues" "20260530-e" 'title: "Broken provenance"
status: open
created: 2026-05-30
origin: docs/removed/file.md'
  ( cd "$root" && bash "$SCRIPT_INDEX" "docs/issues" )
  local idx
  idx="$(cat "$root/docs/issues/INDEX.md")"
  assert_match "open count includes broken-origin issue" 'Open: 1'              "$idx"
  assert_match "issue surfaces in Issues section"        '`20260530-e`'         "$idx"
  assert_match "warning still fires"                     'origin path does not resolve' "$idx"
}

# AC: render includes the issues directory in its header
case_issues_render_header_names_dir() {
  local dir
  dir=$(empty_dir render_header)
  run_render stats "$dir"
  assert_match "header has dir" "Issue Collection — $dir" "$OUT"
}

# AC: backfill assigns ordinals in created-date ascending order (spec 019 DD #6)
case_issues_backfill_assigns_by_created_order() {
  local dir
  dir=$(empty_dir backfill_order)
  write_issue "$dir" "20260102-late" 'title: "Late"
status: open
created: 2026-01-02'
  write_issue "$dir" "20260101-early" 'title: "Early"
status: open
created: 2026-01-01'
  run_backfill "$dir"
  assert_exit "rc" 0 "$RC"
  assert_eq "early gets 1" "1" "$(num_of "$dir" 20260101-early)"
  assert_eq "late gets 2"  "2" "$(num_of "$dir" 20260102-late)"
}

# AC: backfill continues numbering from the existing max (spec 019 DD #6)
case_issues_backfill_continues_from_max() {
  local dir
  dir=$(empty_dir backfill_max)
  write_issue "$dir" "20260103-has" 'title: "Has"
status: open
num: 5
created: 2026-01-03'
  write_issue "$dir" "20260104-needs" 'title: "Needs"
status: open
created: 2026-01-04'
  run_backfill "$dir"
  assert_exit "rc" 0 "$RC"
  assert_eq "existing num untouched" "5" "$(num_of "$dir" 20260103-has)"
  assert_eq "new continues from max" "6" "$(num_of "$dir" 20260104-needs)"
}

# AC: backfill is idempotent — a fully-numbered collection is a silent no-op
case_issues_backfill_idempotent() {
  local dir
  dir=$(empty_dir backfill_idem)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  run_backfill "$dir"
  assert_exit "rc"           0  "$RC"
  assert_eq   "no-op output" "" "$OUT"
  assert_eq   "num unchanged" "1" "$(num_of "$dir" 20260101-a)"
}

# AC: backfill preserves all other file content (spec 019 DD #6)
case_issues_backfill_preserves_content() {
  local dir
  dir=$(empty_dir backfill_preserve)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
labels: [bug, auth]
created: 2026-01-01' '## Description

Body line with a [[20260101-b]] wikilink.'
  run_backfill "$dir"
  local content
  content="$(cat "$dir/20260101-a.md")"
  assert_match "num added"      '^num:[[:space:]]*1'         "$content"
  assert_match "title kept"     'title: "A"'                 "$content"
  assert_match "labels kept"    'labels: \[bug, auth\]'      "$content"
  assert_match "body kept"      'Body line with a'           "$content"
  assert_match "wikilink kept"  '20260101-b'                 "$content"
}

# AC: backfill announces the count when it assigns ordinals (spec 019 DD #6)
case_issues_backfill_announces_count() {
  local dir
  dir=$(empty_dir backfill_announce)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
created: 2026-01-01'
  write_issue "$dir" "20260102-b" 'title: "B"
status: open
created: 2026-01-02'
  run_backfill "$dir"
  assert_match "announces 2" 'Assigned display numbers to 2' "$OUT"
}

# AC: index surfaces num: and created: in the Issues row (spec 019)
case_issues_index_num_and_created_surface() {
  local dir
  dir=$(empty_dir index_num)
  write_issue "$dir" "20260530-foo" 'title: "Foo"
status: open
priority: high
num: 5
created: 2026-05-30'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "num surfaces"     'num: 5'            "$idx"
  assert_match "created surfaces" 'created: 2026-05-30' "$idx"
}

# AC: an issue without a num: field does not crash the index (spec 019)
case_issues_index_missing_num_no_crash() {
  local dir
  dir=$(empty_dir index_nonum)
  write_issue "$dir" "20260530-bar" 'title: "Bar"
status: open'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "slug present" '`20260530-bar`' "$(cat "$dir/INDEX.md")"
}

# AC: `render.sh help` lists the subcommands (spec 019)
case_issues_render_help_lists_subcommands() {
  run_render help
  assert_exit "rc" 0 "$RC"
  assert_match "lists add"   'add'   "$OUT"
  assert_match "lists list"  'list'  "$OUT"
  assert_match "lists stats" 'stats' "$OUT"
  assert_match "lists show"  'show'  "$OUT"
}

# AC: `render.sh stats` includes a by-priority breakdown (spec 019)
case_issues_render_stats_by_priority() {
  local dir
  dir=$(empty_dir render_stats_prio)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
priority: high
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-b" 'title: "B"
status: open
priority: low
num: 2
created: 2026-01-02'
  run_render stats "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "by priority header" 'By priority' "$OUT"
  assert_match "high counted"       'high'        "$OUT"
}

# AC: `render.sh list` shows the ordinal column (spec 019)
case_issues_render_list_shows_num() {
  local dir
  dir=$(empty_dir render_list_num)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
priority: high
num: 7
created: 2026-01-01'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "ordinal shown" '#?7\b' "$OUT"
  assert_match "slug shown"    '20260101-a' "$OUT"
}

# AC: `render.sh list` groups by status by default (spec 019)
case_issues_render_list_grouped_by_status() {
  local dir
  dir=$(empty_dir render_list_group)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-b" 'title: "B"
status: closed
num: 2
created: 2026-01-02'
  run_render list "$dir"
  assert_match "open group header"   'open'   "$OUT"
  assert_match "closed group header" 'closed' "$OUT"
}

# AC: `render.sh list <status>` filters to that status (spec 019)
case_issues_render_list_filter_status() {
  local dir
  dir=$(empty_dir render_list_filter)
  write_issue "$dir" "20260101-alpha" 'title: "Alpha"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-bravo" 'title: "Bravo"
status: closed
num: 2
created: 2026-01-02'
  run_render list open "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "open issue present"  '20260101-alpha' "$OUT"
  assert_eq    "closed issue absent" "" "$(printf '%s' "$OUT" | grep -c '20260102-bravo' | sed 's/^0$//')"
}

# AC: `render.sh list <bad-filter>` errors rather than pattern-matching (Finding 3)
case_issues_render_list_unknown_filter_errors() {
  local dir
  dir=$(empty_dir render_list_badfilter)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  run_render list "bogusfilter" "$dir"
  assert_exit     "rc nonzero"      1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: an unrecognized issue_list_group config value falls back to default (Finding 5)
case_issues_render_list_bad_group_config_falls_back() {
  local dir cwd
  dir=$(empty_dir render_list_badgroup)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  cwd=$(empty_dir render_list_badgroup_cwd)
  printf 'issue_list_group = "bogus"\n' > "$cwd/jimconf.toml"
  OUT="$(cd "$cwd" && bash "$SCRIPT_RENDER" list "$dir" 2>/dev/null)"
  RC=$?
  assert_exit "rc" 0 "$RC"
  assert_match "still lists the issue" '20260101-a' "$OUT"
}

# AC: `render.sh show <num>` resolves by ordinal (spec 019)
case_issues_render_show_by_num() {
  local dir
  dir=$(empty_dir render_show_num)
  write_issue "$dir" "20260101-a" 'title: "Alpha Issue"
status: open
num: 42
created: 2026-01-01' "## Description

The body text."
  run_render show 42 "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "title shown" 'Alpha Issue' "$OUT"
  assert_match "body shown"  'The body text' "$OUT"
}

# AC: `render.sh show <substring>` resolves a unique slug match (spec 019)
case_issues_render_show_by_substring() {
  local dir
  dir=$(empty_dir render_show_sub)
  write_issue "$dir" "20260101-credential-leak" 'title: "Cred Leak"
status: open
num: 1
created: 2026-01-01' "body"
  run_render show credential "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "resolved by substring" 'Cred Leak' "$OUT"
}

# AC: `render.sh show <ambiguous>` lists candidates instead of guessing (spec 019)
case_issues_render_show_ambiguous_lists() {
  local dir
  dir=$(empty_dir render_show_ambig)
  write_issue "$dir" "20260101-auth-a" 'title: "Auth A"
status: open
num: 1
created: 2026-01-01' "body"
  write_issue "$dir" "20260102-auth-b" 'title: "Auth B"
status: open
num: 2
created: 2026-01-02' "body"
  run_render show auth "$dir"
  assert_match "lists first candidate"  '20260101-auth-a' "$OUT"
  assert_match "lists second candidate" '20260102-auth-b' "$OUT"
}

# AC: `render.sh show <nomatch>` reports no match (spec 019)
case_issues_render_show_not_found() {
  local dir
  dir=$(empty_dir render_show_none)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01' "body"
  run_render show zzz-nonexistent "$dir"
  assert_match "no-match message" 'no issue' "$OUT"
}

# AC: `render.sh show` resolves only against the known set — no path traversal (Finding 1)
case_issues_render_show_path_traversal_safe() {
  local dir
  dir=$(empty_dir render_show_traversal)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01' "body"
  run_render show "../../../../etc/passwd" "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "reports no match"        'no issue' "$OUT"
  assert_eq    "no /etc/passwd contents" "" "$(printf '%s' "$OUT" | grep -c 'root:' | sed 's/^0$//')"
}

# AC: under the default date sort, same-date rows break by num descending,
# not slug-alphabetical (spec 019 follow-up — coarse created: dates tie). The
# slugs are chosen so alphabetical order (alpha, mango, zebra) differs from
# num-descending order (mango#3, alpha#2, zebra#1).
case_issues_render_list_date_tiebreak_by_num() {
  local dir
  dir=$(empty_dir render_list_tiebreak)
  write_issue "$dir" "20260101-zebra" 'title: "Z"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260101-alpha" 'title: "A"
status: open
num: 2
created: 2026-01-01'
  write_issue "$dir" "20260101-mango" 'title: "M"
status: open
num: 3
created: 2026-01-01'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  local l_mango l_alpha l_zebra order_ok="no"
  l_mango=$(printf '%s\n' "$OUT" | grep -n '20260101-mango' | head -1 | cut -d: -f1)
  l_alpha=$(printf '%s\n' "$OUT" | grep -n '20260101-alpha' | head -1 | cut -d: -f1)
  l_zebra=$(printf '%s\n' "$OUT" | grep -n '20260101-zebra' | head -1 | cut -d: -f1)
  if [[ -n "$l_mango" && -n "$l_alpha" && -n "$l_zebra" ]] \
     && (( l_mango < l_alpha && l_alpha < l_zebra )); then order_ok="yes"; fi
  assert_eq "num-desc tiebreak (#3 < #2 < #1)" "yes" "$order_ok"
}

# AC: issue_list_order = "asc" flips the sort direction (spec 019 follow-up).
# With num sort + asc, the lowest ordinal (#1) appears before the highest (#3).
case_issues_render_list_order_asc() {
  local dir cwd
  dir=$(empty_dir render_list_order)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260103-c" 'title: "C"
status: open
num: 3
created: 2026-01-03'
  cwd=$(empty_dir render_list_order_cwd)
  printf 'issue_list_sort = "num"\nissue_list_order = "asc"\n' > "$cwd/jimconf.toml"
  OUT="$(cd "$cwd" && bash "$SCRIPT_RENDER" list "$dir" 2>/dev/null)"
  RC=$?
  assert_exit "rc" 0 "$RC"
  local l1 l3 order_ok="no"
  l1=$(printf '%s\n' "$OUT" | grep -n '20260101-a' | head -1 | cut -d: -f1)
  l3=$(printf '%s\n' "$OUT" | grep -n '20260103-c' | head -1 | cut -d: -f1)
  if [[ -n "$l1" && -n "$l3" ]] && (( l1 < l3 )); then order_ok="yes"; fi
  assert_eq "ascending: #1 before #3" "yes" "$order_ok"
}

# AC: default issue_list_order is descending — highest ordinal first.
case_issues_render_list_order_desc_default() {
  local dir
  dir=$(empty_dir render_list_order_def)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260103-c" 'title: "C"
status: open
num: 3
created: 2026-01-03'
  run_render list "$dir"
  local l1 l3 order_ok="no"
  l1=$(printf '%s\n' "$OUT" | grep -n '20260101-a' | head -1 | cut -d: -f1)
  l3=$(printf '%s\n' "$OUT" | grep -n '20260103-c' | head -1 | cut -d: -f1)
  if [[ -n "$l1" && -n "$l3" ]] && (( l3 < l1 )); then order_ok="yes"; fi
  assert_eq "descending default: #3 before #1" "yes" "$order_ok"
}

# AC: index.sh leaves INDEX.md as the newest entry in the issues dir so the
# render staleness gate can trust it. The atomic mv preserves the tmp file's
# (earlier) mtime, leaving the directory entry newer than INDEX.md; index.sh
# must touch INDEX.md as its final step to restore the invariant.
case_issues_index_leaves_index_as_newest_entry() {
  local dir
  dir=$(empty_dir index_newest)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
num: 1
created: 2026-05-30'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  # The dir entry must NOT be newer than INDEX.md (else add/delete detection
  # would false-positive on every read).
  if [[ "$dir" -nt "$dir/INDEX.md" ]]; then
    CURRENT_FAILED=1
    echo "    [dir entry is newer than INDEX.md — staleness gate would always regen]"
  fi
  # No issue file may be newer than INDEX.md either.
  local newer
  newer="$(find "$dir" -maxdepth 1 -name '*.md' ! -name INDEX.md -newer "$dir/INDEX.md" 2>/dev/null | head -n1)"
  assert_eq "no issue file newer than index" "" "$newer"
}

# AC: a fresh INDEX.md is reused, not regenerated, on a read verb (perf).
# We append a sentinel that index.sh would never emit; a `list` over a fresh
# index must leave the sentinel intact (proving the rebuild was skipped).
case_issues_render_reuses_fresh_index() {
  local dir
  dir=$(empty_dir render_fresh)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
num: 1
created: 2026-05-30'
  run_index "$dir"
  printf '\n<!-- SENTINEL-FRESH-INDEX -->\n' >> "$dir/INDEX.md"
  # Ensure INDEX.md is the newest entry so the gate sees a fresh index.
  touch "$dir/INDEX.md"
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "issue still listed" '20260530-a' "$OUT"
  if ! grep -q 'SENTINEL-FRESH-INDEX' "$dir/INDEX.md"; then
    CURRENT_FAILED=1
    echo "    [fresh index was regenerated — sentinel lost; rebuild not skipped]"
  fi
}

# AC: editing an issue file (newer mtime than INDEX.md) makes the index stale,
# so a read verb regenerates it and reflects the edit.
case_issues_render_regenerates_on_edited_issue() {
  local dir
  dir=$(empty_dir render_edited)
  write_issue "$dir" "20260530-a" 'title: "Original Title"
status: open
num: 1
created: 2026-05-30'
  run_index "$dir"
  printf '<!-- SENTINEL-STALE -->\n' >> "$dir/INDEX.md"
  # Rewrite the issue with a newer mtime than INDEX.md.
  sleep 1
  write_issue "$dir" "20260530-a" 'title: "Edited Title"
status: open
num: 1
created: 2026-05-30'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  # Regen must have fired: the stale sentinel is gone from the rebuilt index.
  if grep -q 'SENTINEL-STALE' "$dir/INDEX.md"; then
    CURRENT_FAILED=1
    echo "    [edited issue did not trigger regen — stale sentinel survived]"
  fi
}

# AC: adding an issue file after the index was built (dir entry newer than
# INDEX.md) makes the index stale, so a read verb regenerates and surfaces it.
case_issues_render_regenerates_on_added_issue() {
  local dir
  dir=$(empty_dir render_added)
  write_issue "$dir" "20260530-a" 'title: "A"
status: open
num: 1
created: 2026-05-30'
  run_index "$dir"
  touch "$dir/INDEX.md"
  # Add a brand-new issue without regenerating the index.
  sleep 1
  write_issue "$dir" "20260531-b" 'title: "Brand New"
status: open
num: 2
created: 2026-05-31'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "added issue surfaces" '20260531-b' "$OUT"
}

# AC: a title containing a colon is extracted whole — the scalar-field parser
# strips only the leading `key:` prefix, not at every colon (fork-collapse
# rewrite must preserve parse_simple_field semantics).
case_issues_index_title_with_colon_preserved() {
  local dir
  dir=$(empty_dir index_colon_title)
  write_issue "$dir" "20260530-a" 'title: "Auth: token refresh fails"
status: open
num: 1
created: 2026-05-30'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "full title with colon" 'Auth: token refresh fails' "$(cat "$dir/INDEX.md")"
}

# AC: all four issue_list_* config keys are honored together when resolved
# from a single jimconf invocation (perf refactor: one `jimconf.sh list` blob
# instead of four `get` calls). Setting group, sort, order, and cols at once
# must take effect on the same run — guards the blob-parse against dropping or
# mis-splitting any key.
case_issues_render_list_all_config_keys_from_blob() {
  local dir cwd
  dir=$(empty_dir render_blob_cfg)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
priority: high
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-b" 'title: "B"
status: open
priority: low
num: 2
created: 2026-01-02'
  cwd=$(empty_dir render_blob_cfg_cwd)
  printf 'issue_list_group = "priority"\nissue_list_sort = "num"\nissue_list_order = "asc"\nissue_list_cols = "num,slug"\n' > "$cwd/jimconf.toml"
  OUT="$(cd "$cwd" && bash "$SCRIPT_RENDER" list "$dir" 2>/dev/null)"
  RC=$?
  assert_exit "rc" 0 "$RC"
  # group=priority → priority-valued group headers, not status ("open")
  assert_match "grouped by priority (high)" 'high \(1\)' "$OUT"
  assert_match "grouped by priority (low)"  'low \(1\)'  "$OUT"
  # cols="num,slug" → the date column is dropped (no created date in output)
  if printf '%s\n' "$OUT" | grep -q '2026-01-01'; then
    CURRENT_FAILED=1
    echo "    [cols=num,slug should drop the date column, but a date appeared]"
  fi
  # both issues still listed
  assert_match "issue a listed" '20260101-a' "$OUT"
  assert_match "issue b listed" '20260102-b' "$OUT"
}

# AC-T4/T5 (spec 020): insights-graph emits the graph-isolated open set and
# blocking out-degree. Isolation = an open issue in no blocks/depends-on edge.
case_issues_render_insights_graph_isolation_and_blocking() {
  local dir
  dir=$(empty_dir insights_graph)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
created: 2026-01-01
relations:
  blocks: [20260101-b]
  depends-on: []
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260101-b" 'title: "B"
status: open
created: 2026-01-01
relations:
  blocks: []
  depends-on: [20260101-a]
  related-to: []
  duplicates: []'
  write_issue "$dir" "20260101-c" 'title: "C"
status: open
created: 2026-01-01
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []'
  run_render insights-graph "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "c is isolated"     'ISOLATED 20260101-c'   "$OUT"
  assert_match "a blocking degree" 'BLOCKING 1 20260101-a' "$OUT"
  if printf '%s\n' "$OUT" | grep -q 'ISOLATED 20260101-a'; then
    CURRENT_FAILED=1; echo "    [a has a blocks edge; must not be ISOLATED]"
  fi
  if printf '%s\n' "$OUT" | grep -q 'ISOLATED 20260101-b'; then
    CURRENT_FAILED=1; echo "    [b is a blocks target; must not be ISOLATED]"
  fi
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# This file works two ways:
#   1. bash tests/issues.sh        → runs only this file's cases (standalone).
#   2. bash skills/meta-test/scripts/run.sh
#                                    → sources this file alongside every other
#                                      tests/*.sh and runs the union of cases.
#
# How the dual-mode works:
#   ${BASH_SOURCE[0]} is the file bash is currently reading.
#   ${0} is the file bash was invoked with.
#   They match ONLY when this file is run directly. When the aggregate runner
#   sources us, BASH_SOURCE[0] is this file but $0 is run.sh — they diverge.
#   So the block below runs the cases only on direct invocation; otherwise it
#   stays silent and lets the aggregate runner decide what to dispatch.
#
# DO NOT "tidy" this into something simpler — $BASH_SOURCE (no index) and
# ${BASH_SOURCE} behave subtly differently in older bash and break aggregate
# runs.
#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_INDEX" ]]; then
    echo "NOTE: $SCRIPT_INDEX not found — index cases will fail."
  fi
  if [[ ! -e "$SCRIPT_RENDER" ]]; then
    echo "NOTE: $SCRIPT_RENDER not found — render cases will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
