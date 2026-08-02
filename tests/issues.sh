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
SCRIPT_MIGRATE="$REPO_ROOT/skills/issue/scripts/migrate.sh"
SCRIPT_NEW="$REPO_ROOT/skills/issue/scripts/new.sh"
SCRIPT_RECONCILE="$REPO_ROOT/skills/issue/scripts/reconcile.sh"

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

run_migrate() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_MIGRATE" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

run_new() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_NEW" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# run_new_in <repo> <args...>
#   Invoke new.sh with CWD inside <repo> — new.sh's identity fallback shells
#   out to jimalloc.sh, which requires a git repo (allocate issue's local-tier
#   CAS) to run at all.
run_new_in() {
  local repo="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && bash "$SCRIPT_NEW" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# run_issue_reconcile_in <repo> <args...>
#   Invoke reconcile.sh with CWD inside <repo> — reconcile.sh shells out to
#   jimalloc.sh reconcile issue, which requires a git repo to run at all.
run_issue_reconcile_in() {
  local repo="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && bash "$SCRIPT_RECONCILE" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# new_repo <name> — a fresh git repo with a committer identity set, for tests
# that exercise new.sh's allocator-backed identity fallback.
new_repo() {
  local repo; repo="$(empty_dir "$1")"
  git -C "$repo" init -q
  git -C "$repo" config user.name  "Test User"
  git -C "$repo" config user.email "test@example.com"
  printf '%s' "$repo"
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

# AC: a failed atomic rename cleans up after itself and reports only the real
# cause. The EXIT trap names a `local`, so returning before the trap is cleared
# runs its body with the variable out of scope — fatal under the script's `set -u`
# preamble, which both aborts the cleanup it exists for and prints a shell-internal
# error over the accurate one the line above already gave.
case_issues_index_failed_rename_leaves_no_temp_file() {
  local dir leftover
  dir=$(empty_dir index_renamefail)
  write_issue "$dir" "20260101-x" 'title: "X"
status: open
priority: medium'
  # An unwritable directory where INDEX.md belongs: the rename cannot land.
  mkdir -p "$dir/INDEX.md"
  chmod 500 "$dir/INDEX.md"
  run_index "$dir"
  chmod 700 "$dir/INDEX.md"
  leftover="$(find "$dir" -maxdepth 1 -name '.INDEX.md.tmp.*' | grep -c .)"
  assert_exit "rc"                     1   "$RC"
  assert_eq   "no temp file left"      "0" "$leftover"
  assert_eq   "no shell error printed" "0" \
    "$(printf '%s\n' "$ERR" | grep -c 'unbound variable')"
  assert_match "names the real cause" 'atomic rename failed' "$ERR"
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
case_issues_index_invalid_filename_skipped() {
  local dir
  dir=$(empty_dir index_bad_slug)
  # '@' is outside the is_valid_id allowlist ([A-Za-z0-9._-]); uppercase and
  # underscores are now valid id characters (spec 021), so this uses a char
  # that is genuinely rejected.
  printf -- '---\ntitle: "X"\nstatus: open\n---\n' > "$dir/bad@slug.md"
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "filename warning" 'not a valid id' "$idx"
  # The bad-id file does not appear in the Issues section as a valid entry
  if echo "$idx" | grep -q '`bad@slug` —'; then
    CURRENT_FAILED=1
    echo "    [bad-id filename should not appear as an Issues entry]"
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

# issues_unwritable_mktemp_shim <name>
#   A directory holding an `mktemp` that, for the INDEX tmpfile template ONLY,
#   returns a path it has already created read-only; every other call execs the
#   real mktemp. Opening that path for write fails, which is how a compose that
#   cannot be written is staged without needing a full disk.
issues_unwritable_mktemp_shim() {
  local dir real
  dir=$(empty_dir "$1")
  real="$(command -v mktemp)"
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -uo pipefail' 'for a in "$@"; do'
    printf '%s\n' '  case "$a" in'
    printf '%s\n' '    *INDEX.md.tmp.*)'
    printf '%s\n' '      p="${a%.XXXXXX}.locked"'
    printf '%s\n' '      : > "$p"; chmod 0444 "$p"; printf "%s\\n" "$p"; exit 0 ;;'
    printf '%s\n' '  esac' 'done'
    printf 'exec %s "$@"\n' "$real"
  } > "$dir/mktemp"
  chmod +x "$dir/mktemp"
  printf '%s' "$dir"
}

# AC: a compose that cannot be written never reaches the atomic rename. The
# rename is what makes this dangerous rather than merely unguarded — a short
# write would publish a TRUNCATED index over a good one and still return 0, and
# both reconcilers key their "index failed to regenerate" error off that code.
case_issues_index_failed_compose_preserves_prior_index() {
  local dir shim oldpath
  dir=$(empty_dir index_compose_fail)
  write_issue "$dir" "20260530-z" 'title: "Z"
status: open'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  local good; good="$(cat "$dir/INDEX.md")"
  shim=$(issues_unwritable_mktemp_shim index_compose_shim)
  oldpath="$PATH"; PATH="$shim:$PATH"
  run_index "$dir"
  PATH="$oldpath"
  assert_exit  "rc" 1 "$RC"
  assert_match "names the compose failure" 'compose' "$ERR"
  assert_eq    "prior INDEX.md byte-unchanged" "$good" "$(cat "$dir/INDEX.md")"
  chmod 0644 "$dir"/.INDEX.md.tmp.locked 2>/dev/null
  rm -f "$dir"/.INDEX.md.tmp.locked
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
  run_backfill num "$dir"
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
  run_backfill num "$dir"
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
  run_backfill num "$dir"
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
  run_backfill num "$dir"
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
  run_backfill num "$dir"
  assert_match "announces 2" 'Assigned display numbers to 2' "$OUT"
}

# CLI: no subcommand prints help/usage that lists the subcommands.
case_issues_backfill_no_arg_shows_help() {
  run_backfill
  assert_exit  "rc" 0 "$RC"
  assert_match "lists num"       'num'       "$OUT"
  assert_match "lists timestamp" 'timestamp' "$OUT"
}

# CLI: an unknown subcommand errors (rc 2) and names it on stderr.
case_issues_backfill_unknown_subcommand() {
  run_backfill bogus
  assert_exit  "rc" 2 "$RC"
  assert_match "names the bad subcommand" 'bogus' "$ERR"
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
  write_issue "$dir" "20260101-a" 'title: "Alpha"
status: open
priority: high
num: 7
created: 2026-01-01'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "ordinal shown" '#?7\b' "$OUT"
  assert_match "title shown"   'Alpha' "$OUT"
}

# AC: `render.sh list` groups by status (spec 019). Closed issues are hidden by
# default (issue-list-closed toggle), so this exercises the toggle-on path to
# assert both status groups render.
case_issues_render_list_grouped_by_status() {
  local dir cwd
  dir=$(empty_dir render_list_group)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-b" 'title: "B"
status: closed
num: 2
created: 2026-01-02'
  cwd=$(empty_dir render_list_group_cwd)
  printf 'issue_list_closed = "true"\n' > "$cwd/jimconf.toml"
  OUT="$(cd "$cwd" && bash "$SCRIPT_RENDER" list "$dir" 2>/dev/null)"
  RC=$?
  assert_exit "rc" 0 "$RC"
  assert_match "open group header"   'open'   "$OUT"
  assert_match "closed group header" 'closed' "$OUT"
}

# AC: `render.sh list` (no filter) hides closed issues by default.
case_issues_render_list_hides_closed_by_default() {
  local dir
  dir=$(empty_dir render_list_hide_closed)
  write_issue "$dir" "20260101-alpha" 'title: "Alpha"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-bravo" 'title: "Bravo"
status: closed
num: 2
created: 2026-01-02'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "open issue present"  'Alpha' "$OUT"
  assert_eq    "closed issue hidden" "" "$(printf '%s' "$OUT" | grep -c 'Bravo' | sed 's/^0$//')"
}

# AC: issue_list_closed = "true" opts closed issues back into the default view.
case_issues_render_list_closed_config_shows_closed() {
  local dir cwd
  dir=$(empty_dir render_list_show_closed)
  write_issue "$dir" "20260101-alpha" 'title: "Alpha"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-bravo" 'title: "Bravo"
status: closed
num: 2
created: 2026-01-02'
  cwd=$(empty_dir render_list_show_closed_cwd)
  printf 'issue_list_closed = "true"\n' > "$cwd/jimconf.toml"
  OUT="$(cd "$cwd" && bash "$SCRIPT_RENDER" list "$dir" 2>/dev/null)"
  RC=$?
  assert_exit "rc" 0 "$RC"
  assert_match "open issue present"   'Alpha' "$OUT"
  assert_match "closed issue present" 'Bravo' "$OUT"
}

# AC: `list closed` is the ad-hoc closed view — it overrides the hide-by-default
# toggle and shows closed issues regardless of config.
case_issues_render_list_closed_filter_overrides_default() {
  local dir
  dir=$(empty_dir render_list_closed_adhoc)
  write_issue "$dir" "20260101-alpha" 'title: "Alpha"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-bravo" 'title: "Bravo"
status: closed
num: 2
created: 2026-01-02'
  run_render list closed "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "closed issue present" 'Bravo' "$OUT"
  assert_eq    "open issue absent" "" "$(printf '%s' "$OUT" | grep -c 'Alpha' | sed 's/^0$//')"
}

# AC: priority filters also hide closed by default — `list high` shows only open
# issues of that priority unless issue_list_closed is enabled.
case_issues_render_list_priority_filter_hides_closed() {
  local dir
  dir=$(empty_dir render_list_prio_hide_closed)
  write_issue "$dir" "20260101-alpha" 'title: "Alpha"
status: open
priority: high
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-bravo" 'title: "Bravo"
status: closed
priority: high
num: 2
created: 2026-01-02'
  run_render list high "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "open high present"  'Alpha' "$OUT"
  assert_eq    "closed high hidden" "" "$(printf '%s' "$OUT" | grep -c 'Bravo' | sed 's/^0$//')"
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
  assert_match "open issue present"  'Alpha' "$OUT"
  assert_eq    "closed issue absent" "" "$(printf '%s' "$OUT" | grep -c 'Bravo' | sed 's/^0$//')"
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
  assert_match "still lists the issue" '#1' "$OUT"
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
  l_mango=$(printf '%s\n' "$OUT" | grep -n '#3' | head -1 | cut -d: -f1)
  l_alpha=$(printf '%s\n' "$OUT" | grep -n '#2' | head -1 | cut -d: -f1)
  l_zebra=$(printf '%s\n' "$OUT" | grep -n '#1' | head -1 | cut -d: -f1)
  if [[ -n "$l_mango" && -n "$l_alpha" && -n "$l_zebra" ]] \
     && (( l_mango < l_alpha && l_alpha < l_zebra )); then order_ok="yes"; fi
  assert_eq "num-desc tiebreak (#3 < #2 < #1)" "yes" "$order_ok"
}

# AC #8: a non-conforming created value degrades to its day-start date prefix
# and never leaks garbage (or a TSV-breaking tab) into the rendered row.
case_issues_render_list_malformed_created_degrades() {
  local dir
  dir=$(empty_dir render_list_malformed)
  write_issue "$dir" "20260613-okay" 'title: "OK"
status: open
num: 1
created: 2026-06-13'
  write_issue "$dir" "20260613-bad" 'title: "BAD"
status: open
num: 2
created: 2026-06-13Xinjected'
  run_render list "$dir"
  assert_exit  "rc" 0 "$RC"
  assert_match "bad row present" 'BAD' "$OUT"
  local leaked="no"
  printf '%s\n' "$OUT" | grep -q 'injected' && leaked="yes"
  assert_eq "garbage stripped (degraded to day-start)" "no" "$leaked"
}

# AC #4: same-day issues order by timestamp even when num is equal (collision);
# AC #3: a legacy date-only issue orders as that day's start. Characterizes the
# existing sort key (-k5 created, -k2 num) over mixed-resolution values.
case_issues_render_list_mixed_timestamp_sort() {
  local dir
  dir=$(empty_dir render_list_ts_sort)
  write_issue "$dir" "20260613-wire-a" 'title: "Wire-A"
status: open
num: 8
created: 2026-06-13T14:45:30Z'
  write_issue "$dir" "20260613-wire-b" 'title: "Wire-B"
status: open
num: 8
created: 2026-06-13T14:45:33Z'
  write_issue "$dir" "20260612-legacy" 'title: "Legacy"
status: open
num: 4
created: 2026-06-12'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  # default order is desc: later timestamp first, older date-only last
  local l_a l_b l_legacy order_ok="no"
  l_b=$(printf '%s\n' "$OUT" | grep -n 'Wire-B' | head -1 | cut -d: -f1)
  l_a=$(printf '%s\n' "$OUT" | grep -n 'Wire-A' | head -1 | cut -d: -f1)
  l_legacy=$(printf '%s\n' "$OUT" | grep -n 'Legacy' | head -1 | cut -d: -f1)
  if [[ -n "$l_b" && -n "$l_a" && -n "$l_legacy" ]] \
     && (( l_b < l_a && l_a < l_legacy )); then order_ok="yes"; fi
  assert_eq "ts-desc with equal num; legacy day-start last" "yes" "$order_ok"
}

# Spec 022 follow-up: the list `date` column is a terse scan view — it renders
# the date portion only (YYYY-MM-DD), even for a full-resolution timestamp.
# Sub-day precision still drives the sort key and stays visible in `show`.
case_issues_render_list_date_column_is_date_only() {
  local dir
  dir=$(empty_dir render_list_date_only)
  write_issue "$dir" "20260613-timed" 'title: "T"
status: open
num: 1
created: 2026-06-13T14:45:30Z'
  run_render list "$dir"
  assert_exit  "rc" 0 "$RC"
  assert_match "date portion shown" '2026-06-13' "$OUT"
  local timeshown="no"
  printf '%s\n' "$OUT" | grep -q '2026-06-13T' && timeshown="yes"
  assert_eq "time/Z trimmed from list date column" "no" "$timeshown"
}

# AC #8: a non-conforming created is degraded in the INDEX row (day-start, or
# stripped) and surfaces an Integrity Warning rather than landing raw.
case_issues_index_malformed_created_warns() {
  local dir idx
  dir=$(empty_dir index_malformed_created)
  write_issue "$dir" "20260613-bad" 'title: "BAD"
status: open
num: 1
created: 2026-06-13Xinjected'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  idx="$(cat "$dir/INDEX.md")"
  local leaked="no"
  printf '%s\n' "$idx" | grep -q 'injected' && leaked="yes"
  assert_eq   "garbage not in INDEX row" "no" "$leaked"
  assert_match "integrity warning present" 'created is not a valid date or timestamp' "$idx"
}

# read_fm_field <file> <field> — top-level scalar value (test helper).
read_fm_field() {
  grep -E "^$2:" "$1" | head -1 | sed -E "s/^$2:[[:space:]]*//"
}

# AC #5: normalize rewrites date-only created/updated to a day-start UTC
# timestamp and announces with the placeholder caveat.
case_issues_backfill_normalize_date_only() {
  local dir
  dir=$(empty_dir backfill_normalize)
  write_issue "$dir" "20260613-x" 'title: "X"
status: open
num: 1
created: 2026-06-13
updated: 2026-06-13' "Body stays."
  run_backfill timestamp "$dir"
  assert_exit  "rc" 0 "$RC"
  assert_eq    "created -> day-start" "2026-06-13T00:00:00Z" "$(read_fm_field "$dir/20260613-x.md" created)"
  assert_eq    "updated -> day-start" "2026-06-13T00:00:00Z" "$(read_fm_field "$dir/20260613-x.md" updated)"
  assert_match "announces count"      'Normalized 1 issue'   "$OUT"
  assert_match "day-start caveat"     'day-start'            "$OUT"
}

# AC #5 (idempotent): a second normalize run changes nothing and is silent.
case_issues_backfill_normalize_idempotent() {
  local dir
  dir=$(empty_dir backfill_normalize_idem)
  write_issue "$dir" "20260613-x" 'title: "X"
status: open
num: 1
created: 2026-06-13
updated: 2026-06-13'
  run_backfill timestamp "$dir"
  run_backfill timestamp "$dir"
  assert_exit "rc" 0 "$RC"
  assert_eq   "second run silent"  ""                      "$OUT"
  assert_eq   "created stable"     "2026-06-13T00:00:00Z"  "$(read_fm_field "$dir/20260613-x.md" created)"
}

# F3 (preserves content): only created/updated change; other fields + body stay.
case_issues_backfill_normalize_preserves_content() {
  local dir f
  dir=$(empty_dir backfill_normalize_preserve)
  write_issue "$dir" "20260613-x" 'title: "Keep Me"
status: open
priority: high
num: 7
created: 2026-06-13
updated: 2026-06-13
labels: [a, b]' "Body line one.
Body line two."
  run_backfill timestamp "$dir"
  assert_exit  "rc" 0 "$RC"
  f="$dir/20260613-x.md"
  assert_eq    "title kept"    '"Keep Me"'      "$(read_fm_field "$f" title)"
  assert_eq    "priority kept" "high"           "$(read_fm_field "$f" priority)"
  assert_eq    "num kept"      "7"              "$(read_fm_field "$f" num)"
  assert_match "body kept"     'Body line two.' "$(cat "$f")"
}

# AC #8 (skip malformed): a malformed created is left unchanged with a warning;
# a date-only updated in the same file is still normalized.
case_issues_backfill_normalize_skips_malformed() {
  local dir
  dir=$(empty_dir backfill_normalize_malformed)
  write_issue "$dir" "20260613-x" 'title: "X"
status: open
num: 1
created: not-a-date
updated: 2026-06-13'
  run_backfill timestamp "$dir"
  assert_exit  "rc" 0 "$RC"
  assert_eq    "malformed created untouched" "not-a-date"            "$(read_fm_field "$dir/20260613-x.md" created)"
  assert_eq    "updated normalized"          "2026-06-13T00:00:00Z"  "$(read_fm_field "$dir/20260613-x.md" updated)"
  assert_match "warns on malformed"          'not a valid date or timestamp' "$ERR"
}

# extract_ts_shape <script> — the canonical timestamp-shape pattern marked with
# `# SYNC(ts-shape): <pattern>`, indentation-independent (Finding F6).
extract_ts_shape() {
  grep -o 'SYNC(ts-shape): .*' "$1" | head -1 | sed 's/^SYNC(ts-shape): //'
}

# AC #8 / Finding F6: the timestamp-shape pattern is byte-identical across the
# three guard sites (render.sh, index.sh, backfill.sh) — guard against drift,
# mirroring case_jimfile_is_valid_id_triplicate_identical.
case_issues_timestamp_shape_triplicate_identical() {
  local a b c
  a="$(extract_ts_shape "$REPO_ROOT/skills/issue/scripts/render.sh")"
  b="$(extract_ts_shape "$REPO_ROOT/skills/issue/scripts/index.sh")"
  c="$(extract_ts_shape "$REPO_ROOT/skills/issue/scripts/backfill.sh")"
  assert_eq "render marker present" "1" "$([[ -n "$a" ]] && echo 1 || echo 0)"
  assert_eq "render == index"       "$a" "$b"
  assert_eq "render == backfill"    "$a" "$c"
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
  l1=$(printf '%s\n' "$OUT" | grep -n '#1' | head -1 | cut -d: -f1)
  l3=$(printf '%s\n' "$OUT" | grep -n '#3' | head -1 | cut -d: -f1)
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
  l1=$(printf '%s\n' "$OUT" | grep -n '#1' | head -1 | cut -d: -f1)
  l3=$(printf '%s\n' "$OUT" | grep -n '#3' | head -1 | cut -d: -f1)
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
  assert_match "issue still listed" '#1' "$OUT"
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
  assert_match "added issue surfaces" 'Brand New' "$OUT"
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

# spec 020: insights-graph degrades cleanly on an empty collection — no
# ISOLATED/BLOCKING lines, exit 0. Characterizes the edge of the task-1 helper.
case_issues_render_insights_graph_empty_dir() {
  local dir
  dir=$(empty_dir insights_graph_empty)
  run_render insights-graph "$dir"
  assert_exit "rc" 0 "$RC"
  if [[ -n "$OUT" ]]; then
    CURRENT_FAILED=1; echo "    [empty collection should produce no graph facts, got: $OUT]"
  fi
}

# AC-T10 (spec 020): the help view lists the insights verb.
case_issues_render_help_lists_insights() {
  run_render help
  assert_exit "rc" 0 "$RC"
  assert_match "help lists insights" 'insights' "$OUT"
}

# AC: index accepts a new-scheme (uppercase-prefix) filename stem (spec 021 AC #5)
case_issues_index_accepts_new_scheme_stem() {
  local dir
  dir=$(empty_dir index_new_scheme_stem)
  write_issue "$dir" "JIM-wire-consumers" 'title: "Wire consumers"
status: open'
  run_index "$dir"
  assert_exit  "rc" 0 "$RC"
  local idx; idx="$(cat "$dir/INDEX.md")"
  assert_match "new-scheme slug indexed" '`JIM-wire-consumers`' "$idx"
  assert_match "open count 1" 'Open: 1' "$idx"
}

# AC: a relation target with a new-scheme id becomes a graph edge (spec 021 AC #5)
case_issues_index_new_scheme_relation_edge() {
  local dir
  dir=$(empty_dir index_new_scheme_rel)
  write_issue "$dir" "0001-a" 'title: "A"
status: open
relations:
  blocks: [JIM-b]
  depends-on: []
  related-to: []
  duplicates: []'
  write_issue "$dir" "JIM-b" 'title: "B"
status: open'
  run_index "$dir"
  local idx; idx="$(cat "$dir/INDEX.md")"
  assert_match "edge to new-scheme target" 'a` --blocks--> `JIM-b' "$idx"
}

# AC: a body wikilink to a new-scheme id becomes a related-to edge (spec 021 AC #5)
case_issues_index_new_scheme_wikilink_edge() {
  local dir
  dir=$(empty_dir index_new_scheme_wl)
  write_issue "$dir" "0001-a" 'title: "A"
status: open' "See [[JIM-b]] for context."
  write_issue "$dir" "JIM-b" 'title: "B"
status: open'
  run_index "$dir"
  local idx; idx="$(cat "$dir/INDEX.md")"
  assert_match "wikilink edge to new-scheme" 'a` --related-to--> `JIM-b' "$idx"
}

# AC: show renders a new-scheme (uppercase prefix) issue (spec 021 AC #5)
case_issues_render_show_new_scheme_id() {
  local dir
  dir=$(empty_dir show_new_scheme)
  write_issue "$dir" "JIM-wire-consumers" 'num: 5
title: "Wire consumers"
status: open'
  run_render show JIM-wire-consumers "$dir"
  assert_exit  "rc" 0 "$RC"
  assert_match "renders title" 'Wire consumers' "$OUT"
  assert_match "renders slug"  'JIM-wire-consumers' "$OUT"
}

# spec 023 Task 3: migrate.sh no-arg prints help; `prefix` classifies each
# issue (rename / skip-conforming / skip-unmigratable) and resolves collisions
# with the -2/-3 discriminator over the re-derived map.
case_issues_migrate_prefix_classifies() {
  local dir cfg
  dir=$(empty_dir migrate_classify)
  write_issue "$dir" "20260613-alpha" 'title: "A"
status: open
num: 1
created: 2026-06-13T09:00:00Z'
  write_issue "$dir" "20260613T090000-beta" 'title: "B"
status: open
num: 2
created: 2026-06-13T09:00:00Z'
  write_issue "$dir" "20260613-bad" 'title: "C"
status: open
num: 3
created: notadate'
  write_issue "$dir" "0007-dup" 'title: "D"
status: open
num: 4
created: 2026-06-13T12:00:00Z'
  write_issue "$dir" "20260613-dup" 'title: "E"
status: open
num: 5
created: 2026-06-13T12:00:00Z'
  cfg=$(fixture migrate-classify.toml "issues_path = \"$dir\"
issue_id_prefix = \"timestamp\"")

  run_migrate
  assert_exit  "help rc 0"  0 "$RC"
  assert_match "help lists prefix" 'prefix' "$OUT"

  run_migrate -c "$cfg" prefix
  assert_exit  "prefix rc 0" 0 "$RC"
  assert_match "renames alpha"     '20260613T090000-alpha' "$OUT"
  assert_match "skips conforming"  '20260613T090000-beta'  "$OUT"
  assert_match "skips bad"         '20260613-bad'          "$OUT"
  assert_match "collision suffix"  '20260613T120000-dup-2' "$OUT"
  assert_match "rename count"      '3 to rename'           "$OUT"
  assert_match "skip count"        '2 to skip'             "$OUT"
  assert_match "collision count"   '1 collision'           "$OUT"
}

# spec 023 Task 4: the preview adds a stable PLAN-HASH and a read-only VCS note,
# and mutates nothing.
case_issues_migrate_prefix_preview() {
  local dir cfg before after h1 h2
  dir=$(empty_dir migrate_preview)
  write_issue "$dir" "20260613-alpha" 'title: "A"
status: open
num: 1
created: 2026-06-13T09:00:00Z'
  cfg=$(fixture migrate-preview.toml "issues_path = \"$dir\"
issue_id_prefix = \"timestamp\"")

  before="$(ls "$dir")"
  run_migrate -c "$cfg" prefix
  assert_exit  "rc" 0 "$RC"
  assert_match "VCS note"  'version control' "$OUT"
  assert_match "plan hash" 'PLAN-HASH:'      "$OUT"
  after="$(ls "$dir")"
  assert_eq "preview mutates nothing" "$before" "$after"

  h1="$(printf '%s\n' "$OUT" | grep '^PLAN-HASH:')"
  run_migrate -c "$cfg" prefix
  h2="$(printf '%s\n' "$OUT" | grep '^PLAN-HASH:')"
  assert_eq "plan hash stable across runs" "$h1" "$h2"
}

# spec 023 Task 5: the rewrite engine rewrites the four relations buckets + body
# [[wikilinks]] by EXACT id (mirroring index.sh), never touching origin: paths,
# prose mentions, prefix-overlapping ids, or fenced-code links (security F2).
case_issues_migrate_rewrite() {
  local dir
  dir=$(empty_dir migrate_rewrite)
  printf '%s\t%s\n' "20260613-foo" "20260613T090000-foo" > "$dir/map.tsv"
  cat > "$dir/issue.md" <<'MD'
---
title: "Ref"
status: open
num: 1
relations:
  blocks: []
  depends-on: [20260613-foo]
  related-to: []
  duplicates: []
created: 2026-06-13T10:00:00Z
origin: docs/specs/jim/20260613-foo/spec.md
---
See [[20260613-foo]] and [[20260613-foo-variant]] and bare 20260613-foo here.

```
code [[20260613-foo]] stays
```
MD
  run_migrate rewrite "$dir/map.tsv" "$dir/issue.md"
  assert_exit  "rc" 0 "$RC"
  assert_match "relation target rewritten" 'depends-on: \[20260613T090000-foo\]' "$OUT"
  assert_match "body wikilink rewritten"   '\[\[20260613T090000-foo\]\]'         "$OUT"
  assert_match "origin path untouched"     'origin: docs/specs/jim/20260613-foo/spec.md' "$OUT"
  assert_match "prose mention untouched"   'bare 20260613-foo here'              "$OUT"
  assert_match "prefix-overlap untouched"  '\[\[20260613-foo-variant\]\]'        "$OUT"
  assert_match "fenced link untouched"     'code \[\[20260613-foo\]\] stays'     "$OUT"
}

# spec 023 Task 6: --apply renames files, rewrites cross-file refs, and
# regenerates INDEX with no new integrity warnings.
case_issues_migrate_apply_core() {
  local dir cfg
  dir=$(empty_dir migrate_apply)
  write_issue "$dir" "20260613-aaa" 'title: "A"
status: open
num: 1
relations:
  blocks: []
  depends-on: [20260613-bbb]
  related-to: []
  duplicates: []
created: 2026-06-13T09:00:00Z'
  write_issue "$dir" "20260613-bbb" 'title: "B"
status: open
num: 2
relations:
  blocks: [20260613-aaa]
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-13T10:00:00Z'
  cfg=$(fixture migrate-apply.toml "issues_path = \"$dir\"
issue_id_prefix = \"timestamp\"")

  run_migrate -c "$cfg" prefix --apply
  assert_exit "rc" 0 "$RC"
  local aexists=no bexists=no aold=present
  [[ -f "$dir/20260613T090000-aaa.md" ]] && aexists=yes
  [[ -f "$dir/20260613T100000-bbb.md" ]] && bexists=yes
  [[ -f "$dir/20260613-aaa.md" ]] || aold=gone
  assert_eq "A renamed"  "yes"  "$aexists"
  assert_eq "B renamed"  "yes"  "$bexists"
  assert_eq "A old gone" "gone" "$aold"
  assert_match "A ref rewritten" 'depends-on: \[20260613T100000-bbb\]' "$(cat "$dir/20260613T090000-aaa.md")"
  assert_match "B ref rewritten" 'blocks: \[20260613T090000-aaa\]'     "$(cat "$dir/20260613T100000-bbb.md")"
  assert_match "INDEX has new id"      '20260613T090000-aaa' "$(cat "$dir/INDEX.md")"
  assert_match "no integrity warnings" '_None' "$(cat "$dir/INDEX.md")"
}

# spec 023 Task 7: --apply is idempotent (a fully-migrated collection is a
# silent no-op) and honors the --expect drift guard (mismatch -> exit 3).
case_issues_migrate_apply_guards() {
  local dir cfg
  dir=$(empty_dir migrate_guards)
  write_issue "$dir" "20260613-alpha" 'title: "A"
status: open
num: 1
created: 2026-06-13T09:00:00Z'
  cfg=$(fixture migrate-guards.toml "issues_path = \"$dir\"
issue_id_prefix = \"timestamp\"")

  run_migrate -c "$cfg" prefix --apply
  assert_exit "first apply rc" 0 "$RC"

  run_migrate -c "$cfg" prefix --apply
  assert_exit  "second apply rc"  0 "$RC"
  assert_match "no-op message" 'Nothing to migrate' "$OUT"

  run_migrate -c "$cfg" prefix --apply --expect WRONGHASH
  assert_exit "drift exits 3" 3 "$RC"
}

# spec 023 Task 8: a mid-staging failure leaves the collection untouched (staging
# is non-destructive), and a retry converges with INDEX integrity clean (AC #10).
case_issues_migrate_apply_retry_completes() {
  local dir cfg
  dir=$(empty_dir migrate_retry)
  write_issue "$dir" "20260613-aaa" 'title: "A"
status: open
num: 1
relations:
  blocks: []
  depends-on: [20260613-bbb]
  related-to: []
  duplicates: []
created: 2026-06-13T09:00:00Z'
  write_issue "$dir" "20260613-bbb" 'title: "B"
status: open
num: 2
relations:
  blocks: [20260613-aaa]
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-13T10:00:00Z'
  cfg=$(fixture migrate-retry.toml "issues_path = \"$dir\"
issue_id_prefix = \"timestamp\"")

  export MIGRATE_FAIL_STAGING=1
  run_migrate -c "$cfg" prefix --apply
  unset MIGRATE_FAIL_STAGING
  assert_exit  "injected apply fails" 1 "$RC"
  assert_match "reports no changes"   'no changes made' "$ERR"
  local intact=no leaked=no
  [[ -f "$dir/20260613-aaa.md" && -f "$dir/20260613-bbb.md" ]] && intact=yes
  [[ -f "$dir/20260613T090000-aaa.md" ]] && leaked=yes
  assert_eq "collection intact after failure" "yes" "$intact"
  assert_eq "no partial rename"               "no"  "$leaked"

  run_migrate -c "$cfg" prefix --apply
  assert_exit "retry rc 0" 0 "$RC"
  local a=no b=no
  [[ -f "$dir/20260613T090000-aaa.md" ]] && a=yes
  [[ -f "$dir/20260613T100000-bbb.md" ]] && b=yes
  assert_eq "A migrated on retry" "yes" "$a"
  assert_eq "B migrated on retry" "yes" "$b"
  assert_match "ref rewritten on retry" 'depends-on: \[20260613T100000-bbb\]' "$(cat "$dir/20260613T090000-aaa.md")"
  assert_match "INDEX clean" '_None' "$(cat "$dir/INDEX.md")"
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
# ─── Section: new.sh (issue-file emitter, spec 025) ──────────────────────────

# AC: new.sh emits the spec-017 template shape from fields (spec 025 AC1)
case_new_happy_path() {
  local dir b f
  dir=$(empty_dir new_happy)
  b=$(fixture new_happy_body.md 'A normal body.')
  run_new --dir "$dir" --slug "20260101-sample" --num 7 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "Sample title" --priority high --labels "auth, refactor" \
    --origin "docs/specs/jim/025/plan.md" --body-file "$b"
  assert_exit "rc" 0 "$RC"
  assert_match "stdout slug" 'sample' "$OUT"
  assert_match "stdout path" "$dir/20260101-sample.md" "$OUT"
  f="$dir/20260101-sample.md"
  assert_match "id"       '^id: 20260101-sample$'                 "$(cat "$f")"
  assert_match "num"      '^num: 7$'                              "$(cat "$f")"
  assert_match "title"    '^title: "Sample title"$'              "$(cat "$f")"
  assert_match "priority" '^priority: high$'                      "$(cat "$f")"
  assert_match "labels"   '^labels: \[auth, refactor\]$'         "$(cat "$f")"
  assert_match "origin"   '^origin: docs/specs/jim/025/plan.md$'  "$(cat "$f")"
  assert_match "body"     'A normal body\.'                       "$(cat "$f")"
}

# AC: untrusted --title cannot inject or break frontmatter (spec 025 AC4, Finding 1)
case_new_title_injection_contained() {
  local dir b f
  dir=$(empty_dir new_title_inj)
  b=$(fixture new_title_inj_body.md 'body')
  run_new --dir "$dir" --slug "20260101-inj" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title 'evil"
status: closed
priority: critical
---
hi' --priority medium --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 0 "$RC"
  f="$dir/20260101-inj.md"
  # Exactly two frontmatter delimiters — the title did not open/close frontmatter.
  assert_eq "delimiter count" "2" "$(grep -c '^---$' "$f")"
  # Our real fields survive, unaltered by the injected text.
  assert_match "priority intact" '^priority: medium$' "$(cat "$f")"
  assert_eq "single status line" "1" "$(grep -c '^status:' "$f")"
  # index.sh parses the result without error.
  run_index "$dir"
  assert_exit "index parses" 0 "$RC"
}

# AC: untrusted --labels cannot break the inline YAML array (spec 025 AC4, Finding 6)
case_new_labels_injection_contained() {
  local dir b f
  dir=$(empty_dir new_lbl_inj)
  b=$(fixture new_lbl_inj_body.md 'body')
  run_new --dir "$dir" --slug "20260101-lbl" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "T" --priority low --labels 'ok, ], [[bad, a"b]' --origin conversation --body-file "$b"
  assert_exit "rc" 0 "$RC"
  f="$dir/20260101-lbl.md"
  assert_match "labels well-formed" '^labels: \[ok, bad, a-b\]$' "$(cat "$f")"
  run_index "$dir"
  assert_exit "index parses" 0 "$RC"
}

# AC: --body-file copied verbatim, never executed (spec 025 AC4, Finding 5)
case_new_body_verbatim_no_exec() {
  local dir b f marker
  dir=$(empty_dir new_body_exec)
  marker="$TMP_BASE/PWNED_new_body"
  rm -f "$marker"
  b=$(fixture new_body_exec_body.md 'line one
BODY
"quoted" and $(touch '"$marker"')
--- not frontmatter
done')
  run_new --dir "$dir" --slug "20260101-body" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "T" --priority low --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 0 "$RC"
  assert_eq "no command executed" "no" "$([[ -e "$marker" ]] && echo yes || echo no)"
  f="$dir/20260101-body.md"
  assert_match "body literal present" 'touch ' "$(cat "$f")"
  assert_match "body last line" '^done$' "$(cat "$f")"
  assert_match "frontmatter priority intact" '^priority: low$' "$(cat "$f")"
}

# AC: invalid --priority exits 1 without writing (spec 025 AC4)
case_new_invalid_priority() {
  local dir b
  dir=$(empty_dir new_bad_prio)
  b=$(fixture new_bad_prio_body.md 'body')
  run_new --dir "$dir" --slug "20260101-bp" --num 1 \
    --title "T" --priority urgent --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 1 "$RC"
  assert_eq "no file written" "no" "$([[ -e "$dir/20260101-bp.md" ]] && echo yes || echo no)"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: invalid --slug rejected via valid-id before any write (spec 025 AC5, Finding 2)
case_new_invalid_slug_rejected() {
  local dir b
  dir=$(empty_dir new_bad_slug)
  b=$(fixture new_bad_slug_body.md 'body')
  run_new --dir "$dir" --slug "../escape" --num 1 \
    --title "T" --priority low --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 1 "$RC"
  assert_eq "no traversal write" "no" "$([[ -e "$dir/../escape.md" ]] && echo yes || echo no)"
}

# AC: emitted frontmatter field set matches the template asset (spec 025 AC1 drift guard)
case_new_field_set_matches_asset() {
  local dir b asset gen
  dir=$(empty_dir new_drift)
  b=$(fixture new_drift_body.md 'body')
  run_new --dir "$dir" --slug "20260101-drift" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "T" --priority low --labels "x" --origin conversation --body-file "$b"
  asset="$(sed -n '/^---$/,/^---$/p' "$REPO_ROOT/skills/issue/assets/issue-template.md" | grep -E '^[a-z][a-z-]*:' | sed -E 's/:.*//' | sort)"
  gen="$(sed -n '/^---$/,/^---$/p' "$dir/20260101-drift.md" | grep -E '^[a-z][a-z-]*:' | sed -E 's/:.*//' | sort)"
  assert_eq "frontmatter field set" "$asset" "$gen"
}

# AC: emitted file shape matches spec-017 exactly (spec 025 AC10 parity)
case_new_output_parity() {
  local dir b expected actual
  dir=$(empty_dir new_parity)
  b=$(fixture new_parity_body.md 'Parity body line.')
  run_new --dir "$dir" --slug "20260101-parity" --num 3 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "Parity" --priority medium --labels "a, b" --origin conversation --body-file "$b"
  expected='---
id: 20260101-parity
num: 3
title: "Parity"
status: open
priority: medium
labels: [a, b]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: conversation
---

## Description

Parity body line.'
  actual="$(cat "$dir/20260101-parity.md")"
  assert_eq "full file parity" "$expected" "$actual"
}

# ─── Section: new.sh identity — coordinated ordinals (spec 010) ──────────────

# AC: --num accepts a provisional P-<id> ordinal shape as well as a real
# numeric ordinal — the strict two-grammar union (spec 010 DD3)
case_new_num_grammar_accepts_provisional() {
  local dir b
  dir=$(empty_dir new_num_grammar_prov)
  b=$(fixture new_num_grammar_prov_body.md 'body')
  run_new --dir "$dir" --slug "20260101-prov" --num "P-20260101-widget" \
    --title "T" --priority low --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 0 "$RC"
  assert_match "num stored verbatim" '^num: P-20260101-widget$' "$(cat "$dir/20260101-prov.md")"
}

# AC: --num rejects anything outside the two-grammar union — free text can
# never reach stored frontmatter or a rendered display surface (spec 010 DD3)
case_new_num_grammar_rejects_free_text() {
  local dir b
  dir=$(empty_dir new_num_grammar_bad)
  b=$(fixture new_num_grammar_bad_body.md 'body')
  run_new --dir "$dir" --slug "20260101-bad" --num "not-a-num" \
    --title "T" --priority low --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 1 "$RC"
  assert_eq "no file written" "no" "$([[ -e "$dir/20260101-bad.md" ]] && echo yes || echo no)"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: new.sh's identity fallback resolves through jimalloc.sh allocate issue
# — the single coordination point both /jim:issue add and the no-override
# candidate-batch path go through (spec 010 DD1)
case_new_allocate_issue_coordinated_via_temp_repo() {
  local repo b today expected_slug slug log
  repo=$(new_repo new_allocate_coordinated)
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  expected_slug="${today}-alpha-bug"
  b=$(fixture new_allocate_coordinated_body.md 'body')
  run_new_in "$repo" --dir "$repo/docs/issues" \
    --title "Alpha bug" --priority medium --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_eq "slug from allocator" "$expected_slug" "$slug"
  assert_match "num from allocator" '^num: 1$' "$(cat "$repo/docs/issues/$expected_slug.md")"
  log="$(git -C "$repo" cat-file -p refs/heads/jim/registry:issues.log 2>/dev/null)"
  assert_match "registry recorded" "^issue allocate 1 ${expected_slug} " "$log"
}

# AC: when the allocator returns a provisional ordinal, new.sh disambiguates
# the durable id against the local issues collection (mirroring next-id's
# tree-scan suffixing) and mirrors the same suffix into the stored provisional
# ordinal — a caller-pinned --slug is never touched, only the id this call
# resolved itself (spec 010 DD4)
case_new_provisional_disambiguates_local_collision() {
  local repo issues_dir b today expected_second slug
  repo=$(new_repo new_provisional_disambig)
  issues_dir="$repo/docs/issues"
  mkdir -p "$issues_dir"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-provisional-new.git"
  printf 'id_coordination_unreachable = "provisional"\n' > "$repo/jimconf.toml"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  expected_second="${today}-widget-2"
  write_issue "$issues_dir" "${today}-widget" "id: ${today}-widget"
  b=$(fixture new_provisional_disambig_body.md 'body')
  run_new_in "$repo" --dir "$issues_dir" \
    --title "Widget" --priority medium --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_eq "slug suffixed" "$expected_second" "$slug"
  assert_match "num mirrors suffix" "^num: P-${expected_second}\$" "$(cat "$issues_dir/$expected_second.md")"
}

# AC: in real (non-provisional) mode, new.sh trusts the allocator's
# registry-disambiguated id and refuses to overwrite a local filename
# collision — a platform/007 G2 drift anomaly — rather than diverging from the
# registry (spec 010 DD4)
case_new_provisional_disambig_real_mode_collision_errors() {
  local repo issues_dir b today fid
  repo=$(new_repo new_real_mode_collision)
  issues_dir="$repo/docs/issues"
  mkdir -p "$issues_dir"
  today=$(bash "$REPO_ROOT/skills/file/scripts/jimfile.sh" date)
  fid="${today}-gadget"
  write_issue "$issues_dir" "$fid" "id: $fid"
  b=$(fixture new_real_mode_collision_body.md 'body')
  run_new_in "$repo" --dir "$issues_dir" \
    --title "Gadget" --priority medium --labels "x" --origin conversation --body-file "$b"
  assert_exit "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
  assert_match "original file untouched" "^id: ${fid}\$" "$(cat "$issues_dir/$fid.md")"
}

# AC: render.sh list renders a provisional ordinal distinctly — never as a
# settled #N — and render.sh show does the same (spec 010 DD6, AC 9)
case_issues_render_list_marks_provisional_ordinal() {
  local dir
  dir=$(empty_dir render_list_provisional)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-p" 'title: "P"
status: open
num: P-20260102-p
created: 2026-01-02'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "real ordinal settled" '#1' "$OUT"
  assert_match "provisional marker present" 'P-20260102-p \(provisional\)' "$OUT"
  local settled_prov
  settled_prov="$(printf '%s\n' "$OUT" | grep -c '#P-20260102-p')"
  assert_eq "provisional never rendered as settled #N" "0" "$settled_prov"
}

# AC: render.sh show renders a provisional ordinal distinctly (spec 010 DD6, AC 9)
case_issues_render_show_provisional_marker() {
  local dir
  dir=$(empty_dir render_show_provisional)
  write_issue "$dir" "20260102-p" 'title: "P"
status: open
num: P-20260102-p
created: 2026-01-02'
  run_render show "20260102-p" "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "provisional marker present" 'P-20260102-p \(provisional\)' "$OUT"
  local settled_prov
  settled_prov="$(printf '%s\n' "$OUT" | grep -c '#P-20260102-p')"
  assert_eq "provisional never rendered as settled #N" "0" "$settled_prov"
}

# AC: list --sort num tolerates a mix of real and provisional ordinals without
# erroring — both rows still render (spec 010 DD6)
case_issues_render_list_sort_num_tolerates_provisional() {
  local dir cwd
  dir=$(empty_dir render_list_sort_prov)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
created: 2026-01-01'
  write_issue "$dir" "20260102-p" 'title: "P"
status: open
num: P-20260102-p
created: 2026-01-02'
  cwd=$(empty_dir render_list_sort_prov_cwd)
  printf 'issue_list_sort = "num"\n' > "$cwd/jimconf.toml"
  OUT="$(cd "$cwd" && bash "$SCRIPT_RENDER" list "$dir" 2>/dev/null)"
  RC=$?
  assert_exit "rc" 0 "$RC"
  assert_match "real row present" '#1' "$OUT"
  assert_match "provisional row present" 'provisional' "$OUT"
}

# ─── Section: reconcile.sh (realize provisional issue ordinals, spec 010) ────

# AC: reconcile.sh --apply realizes a pending provisional issue's num: into a
# real ordinal via jimalloc.sh reconcile issue, and regenerates the index
# (spec 010 DD5)
case_issues_reconcile_apply_realizes_pending_provisional() {
  local repo dir fid
  repo=$(new_repo reconcile_realize)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  fid="20260101-widget"
  write_issue "$dir" "$fid" "id: $fid
title: \"Widget\"
status: open
num: P-$fid
priority: medium
created: 2026-01-01T00:00:00Z"
  run_issue_reconcile_in "$repo" --apply "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "num realized"      '^num: 1$'  "$(cat "$dir/$fid.md")"
  assert_match "index regenerated" '· num: 1'  "$(cat "$dir/INDEX.md")"
}

# issues_craft_registry <repo> <issues.log line>...
#   Plant an issues.log on the coordination branch through plumbing — the branch
#   is push-writable, so a contradicted registry is exactly what a crafted one
#   looks like from the realizer's side.
issues_craft_registry() {
  local repo="$1"; shift
  local blob tree commit
  blob="$(printf '%s\n' "$@" | git -C "$repo" hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tissues.log\n' "$blob" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" -m crafted)"
  git -C "$repo" update-ref refs/heads/jim/registry "$commit"
}

# AC: a pending marker whose durable id is claimed twice in the registry is
# blocked — its num: stays provisional and the failure is loud — while the rest
# of the batch realizes and the index regenerates. One contradicted identity
# must not strand neighbours whose ordinals are safe.
case_issues_reconcile_blocked_identity_keeps_batch() {
  local repo dir
  repo=$(new_repo reconcile_blocked)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  write_issue "$dir" "20260101-dup" 'id: 20260101-dup
title: "Dup"
status: open
num: P-20260101-dup
priority: medium
created: 2026-01-01T00:00:00Z'
  write_issue "$dir" "20260101-clean" 'id: 20260101-clean
title: "Clean"
status: open
num: P-20260101-clean
priority: medium
created: 2026-01-01T00:00:00Z'
  issues_craft_registry "$repo" \
    'issue allocate 5 20260101-dup 20260101 jane' \
    'issue allocate 9 20260101-dup 20260102 mallory'
  run_issue_reconcile_in "$repo" --apply "$dir"
  assert_exit  "one blocked file fails the run" 1 "$RC"
  assert_match "names the blocked identity" '20260101-dup' "$ERR"
  assert_match "blocked num stays provisional" '^num: P-20260101-dup$' \
    "$(cat "$dir/20260101-dup.md")"
  assert_match "neighbour realized past the high-water" '^num: 10$' \
    "$(cat "$dir/20260101-clean.md")"
  assert_match "index regenerated over the realized neighbour" '· num: 10' \
    "$(cat "$dir/INDEX.md")"
}

# AC: reconcile.sh --apply is idempotent — re-running against a file whose
# frontmatter still cites the provisional marker (e.g. a resumed run after an
# interruption before the rewrite landed) maps it to its already-realized
# ordinal, never allocates a second one (spec 010 DD5, AC 7)
case_issues_reconcile_apply_idempotent_rerun() {
  local repo dir fid
  repo=$(new_repo reconcile_idempotent)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  fid="20260101-gizmo"
  write_issue "$dir" "$fid" "id: $fid
title: \"Gizmo\"
status: open
num: P-$fid
priority: medium
created: 2026-01-01T00:00:00Z"
  run_issue_reconcile_in "$repo" --apply "$dir"
  assert_exit "first rc" 0 "$RC"
  assert_eq "first realized" "1" "$(num_of "$dir" "$fid")"
  # Simulate a resumed run: the file still cites the provisional marker even
  # though the registry already realized it.
  write_issue "$dir" "$fid" "id: $fid
title: \"Gizmo\"
status: open
num: P-$fid
priority: medium
created: 2026-01-01T00:00:00Z"
  run_issue_reconcile_in "$repo" --apply "$dir"
  assert_exit "second rc" 0 "$RC"
  assert_eq "second realized same ordinal" "1" "$(num_of "$dir" "$fid")"
}

# AC: reconcile.sh --apply rewrites ONLY the leading frontmatter block's num:
# field — a body line that happens to read "num:" is left byte-for-byte
# untouched (spec 010 security Finding 5)
case_issues_reconcile_apply_anchors_frontmatter_num_only() {
  local repo dir fid
  repo=$(new_repo reconcile_anchor)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  fid="20260101-anchor"
  write_issue "$dir" "$fid" "id: $fid
title: \"Anchor\"
status: open
num: P-$fid
priority: medium
created: 2026-01-01T00:00:00Z" 'See the log line below.

num: totally-fake-body-line
More prose after it.'
  run_issue_reconcile_in "$repo" --apply "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "frontmatter num realized" '^num: 1$'                      "$(cat "$dir/$fid.md")"
  assert_match "body num line untouched"  '^num: totally-fake-body-line$' "$(cat "$dir/$fid.md")"
}

# AC: a failed index regeneration is reported, never swallowed — the ordinals
# are in the files but INDEX.md no longer describes them, and a run that exits 0
# tells the developer the opposite.
case_issues_reconcile_surfaces_failed_regen() {
  local repo dir fid
  repo=$(new_repo reconcile_regenfail)
  dir="$repo/docs/issues"
  # An unwritable directory where INDEX.md belongs: the atomic write's rename
  # cannot land, so index.sh fails while every other step still succeeds.
  mkdir -p "$dir/INDEX.md"
  fid="20260101-regen"
  write_issue "$dir" "$fid" "id: $fid
title: \"Regen\"
status: open
num: P-$fid
priority: medium
created: 2026-01-01T00:00:00Z"
  chmod 500 "$dir/INDEX.md"
  run_issue_reconcile_in "$repo" --apply "$dir"
  chmod 700 "$dir/INDEX.md"
  assert_exit     "rc"                      1 "$RC"
  assert_nonempty "names the regen failure" "$ERR"
  assert_match "the realization itself landed" '^num: 1$' "$(cat "$dir/$fid.md")"
}

# AC: a rewrite that changed nothing fails loudly, and does not strand the rest
# of a batch whose ordinals are already published. Unreachable through the CLI —
# the scan and the rewrite match the same set of inputs, so a scan that finds the
# field cannot precede a rewrite that misses it — so the realizer is driven
# directly, the way pure functions are tested elsewhere in this suite.
case_issues_reconcile_no_op_rewrite_fails_and_continues() {
  local dir out rc rows mapping
  dir=$(empty_dir reconcile_noop_rewrite)
  # The first file carries no num: field, forcing the no-op. The second is
  # ordinary, and is what proves the batch was not abandoned at the first.
  printf -- '---\nid: 20260101-a\ntitle: "A"\n---\nbody\n' > "$dir/a.md"
  printf -- '---\nid: 20260101-b\nnum: P-20260101-b\ntitle: "B"\n---\nbody\n' > "$dir/b.md"
  rows="$(printf 'P-20260101-a\t%s/a.md\nP-20260101-b\t%s/b.md' "$dir" "$dir")"
  mapping="$(printf 'P-20260101-a\t7\nP-20260101-b\t8')"
  out="$( source "$SCRIPT_RECONCILE" >/dev/null 2>&1
          apply_pending "$dir" "$rows" "$mapping" 2>/dev/null )"
  rc=$?
  assert_exit "rc"                            1        "$rc"
  assert_eq   "the healthy file still realized" "num: 8" "$(grep '^num:' "$dir/b.md")"
  assert_eq   "count reports only the realized one" "1" "$out"
}

# AC: a batch that lost one file to a failed rewrite still regenerates the index.
# The other files' ordinals are already published, so an abort leaves INDEX.md
# describing a state that no longer exists — the exact failure the regeneration
# check exists to prevent, reached through the door the verified rewrite opened.
case_issues_reconcile_failed_rewrite_still_regenerates_index() {
  local repo dir rc
  repo=$(new_repo reconcile_partial_regen)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  write_issue "$dir" "20260101-good" 'id: 20260101-good
title: "Good"
status: open
num: P-20260101-good
priority: medium
created: 2026-01-01T00:00:00Z'
  printf 'stale\n' > "$dir/INDEX.md"
  # A per-file rewrite failure cannot be staged through the command surface, so
  # the realizer is shadowed with one reporting a realized file AND a failure —
  # the state the verified rewrite made reachable. What is asserted is the
  # CALLER's handling of it: regenerate the index, carry the failure, and do not
  # return before the regeneration.
  ( cd "$repo" && source "$SCRIPT_RECONCILE" >/dev/null 2>&1
    apply_pending() { printf '1\n'; return 1; }
    cmd_reconcile --apply "$dir" ) >/dev/null 2>&1
  rc=$?
  assert_exit "rc"                1   "$rc"
  assert_eq   "index regenerated" "0" "$(grep -c '^stale$' "$dir/INDEX.md")"
}

# AC: detection anchors to the leading frontmatter block, the same region the
# rewrite touches — a body line that happens to read "num: P-…" never makes a
# file pending, so no realization runs behind a rewrite that cannot change it.
case_issues_reconcile_body_num_is_not_pending() {
  local repo dir fid before
  repo=$(new_repo reconcile_bodynum)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  fid="20260101-bodynum"
  write_issue "$dir" "$fid" "id: $fid
title: \"Body num\"
status: open
priority: medium
created: 2026-01-01T00:00:00Z" 'Quoted from another file:

num: P-20260101-bodynum
End of quote.'
  before="$(cat "$dir/$fid.md")"
  run_issue_reconcile_in "$repo" --apply "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "nothing to realize" 'nothing to realize' "$OUT"
  assert_eq "file byte-identical" "$before" "$(cat "$dir/$fid.md")"
}

# AC: a frontmatter opened with a CRLF marker is not a frontmatter open, so the
# file is not pending — the fail-safe direction rather than a realization the
# rewrite would then no-op behind.
case_issues_reconcile_crlf_frontmatter_is_not_pending() {
  local repo dir fid before
  repo=$(new_repo reconcile_crlf)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  fid="20260101-crlf"
  printf -- '---\r\nid: %s\r\nnum: P-%s\r\nstatus: open\r\n---\r\n' "$fid" "$fid" \
    > "$dir/$fid.md"
  before="$(cat "$dir/$fid.md")"
  run_issue_reconcile_in "$repo" --apply "$dir"
  assert_exit  "rc"                 0                    "$RC"
  assert_match "nothing to realize" 'nothing to realize' "$OUT"
  assert_eq "file byte-identical" "$before" "$(cat "$dir/$fid.md")"
}

# AC: reconcile.sh skips a pending file whose frontmatter id fails the
# jimfile.sh id boundary — a crafted durable id never reaches jimalloc.sh
# reconcile issue or a composed path, and the file is left untouched
# (spec 010 security Finding 5)
case_issues_reconcile_rejects_crafted_frontmatter_id() {
  local repo dir fid
  repo=$(new_repo reconcile_crafted)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  fid="20260101-crafted"
  write_issue "$dir" "$fid" "id: ../evil
title: \"Crafted\"
status: open
num: P-$fid
priority: medium
created: 2026-01-01T00:00:00Z"
  run_issue_reconcile_in "$repo" --apply "$dir"
  assert_exit "rc" 0 "$RC"
  assert_nonempty "warns on malformed id" "$ERR"
  assert_match "num left untouched" "^num: P-${fid}\$" "$(cat "$dir/$fid.md")"
}

# AC: bare reconcile.sh is a read-only preview — it reports the provisional ->
# real mapping without writing anything (spec 010 DD5)
case_issues_reconcile_preview_reports_mapping_without_writing() {
  local repo dir fid before after
  repo=$(new_repo reconcile_preview)
  dir="$repo/docs/issues"
  mkdir -p "$dir"
  fid="20260101-preview"
  write_issue "$dir" "$fid" "id: $fid
title: \"Preview\"
status: open
num: P-$fid
priority: medium
created: 2026-01-01T00:00:00Z"
  before="$(cat "$dir/$fid.md")"
  run_issue_reconcile_in "$repo" "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "preview shows mapping" "${fid}"$'\t'"1" "$OUT"
  after="$(cat "$dir/$fid.md")"
  assert_eq "preview mutates nothing" "$before" "$after"
}

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
