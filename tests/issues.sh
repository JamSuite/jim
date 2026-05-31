#!/usr/bin/env bash
#
# tests/issues.sh — Tests for skills/issues/scripts/index.sh and render.sh
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

SCRIPT_INDEX="$REPO_ROOT/skills/issues/scripts/index.sh"
SCRIPT_RENDER="$REPO_ROOT/skills/issues/scripts/render.sh"

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
  run_render "$dir"
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
  run_render "$dir"
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
  run_render "$dir"
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
  run_render "$dir"
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
  run_render "$dir"
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
  run_render "$dir"
  local after_hash
  after_hash=$(find "$dir" -type f -name '*.md' ! -name 'INDEX.md' -exec md5sum {} + | sort | md5sum)
  assert_eq "issue files unchanged" "$before_hash" "$after_hash"
}

# AC: render includes the issues directory in its header
case_issues_render_header_names_dir() {
  local dir
  dir=$(empty_dir render_header)
  run_render "$dir"
  assert_match "header has dir" "Issue Collection — $dir" "$OUT"
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
