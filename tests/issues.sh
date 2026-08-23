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
SCRIPT_IDENTITY="$REPO_ROOT/skills/issue/scripts/identity.sh"
SCRIPT_TRANSITION="$REPO_ROOT/skills/issue/scripts/transition.sh"

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

# The emitter records a filer resolved from the environment. Pin it for every
# invocation so cases assert against a fixed value rather than whatever identity
# the machine running the suite happens to carry. These variables outrank any
# config file, so no repo setup is needed to make the value deterministic.
TEST_IDENTITY="tester@example.test"
identity_env=(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.email
              GIT_CONFIG_VALUE_0="$TEST_IDENTITY")

run_new() {
  local err_file="$TMP_BASE/.err"
  OUT="$(env "${identity_env[@]}" bash "$SCRIPT_NEW" "$@" 2> "$err_file")"
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
  OUT="$(cd "$repo" && env "${identity_env[@]}" bash "$SCRIPT_NEW" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# run_new_unidentified <repo> <args...>
#   Invoke new.sh from inside <repo> with no identity reachable at all — the
#   repo carries none and the machine's own config is neutralized, so this is
#   the genuine absent case rather than a repo that merely overrides one.
run_new_unidentified() {
  local repo="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    bash "$SCRIPT_NEW" "$@" 2> "$err_file")"
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
  # The row set and the Summary counts derive from one population. A file that
  # fails the frontmatter gate contributes to neither, so an index can never
  # assert a row its own Summary denies.
  if echo "$idx" | grep -q '`20260530-x` —'; then
    CURRENT_FAILED=1
    echo "    [a file failing the frontmatter gate should render no row]"
  fi
  assert_match "open count excludes it" '^- Open: 0$' "$idx"
  assert_match "closed count excludes it" '^- Closed: 0$' "$idx"
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

# AC: an entry name carrying a control character is one word, whatever bytes it
# holds — the enumeration never splits it into fragments that re-glob against
# the run's own working directory.
case_issues_index_control_char_name_does_not_reglob() {
  local dir cwd
  dir=$(empty_dir index_ctrl_name)
  cwd=$(empty_dir index_ctrl_cwd)
  # Stands in for the developer's own checkout: markdown whose basename is a
  # valid id, so it would clear the per-slug validator if it were ever reached.
  printf -- '---\ntitle: "LEAKED"\nstatus: open\nnum: 999\n---\n' \
    > "$cwd/20260101-leaked.md"
  # An ordinarily-committed collection entry whose name carries a newline
  # followed by a glob. Under a branch placement any teammate can create one.
  printf -- '---\ntitle: "Real"\nstatus: open\n---\n' \
    > "$dir/$(printf '20260101-a.md\n*.md')"
  local idx
  idx="$( cd "$cwd" && bash "$SCRIPT_INDEX" "$dir" >/dev/null 2>&1; cat "$dir/INDEX.md" )"
  # The checkout never reaches the collection's index, by row or by content.
  if echo "$idx" | grep -q '20260101-leaked'; then
    CURRENT_FAILED=1
    echo "    [a path outside the collection was rendered as an issue row]"
  fi
  if echo "$idx" | grep -q 'LEAKED'; then
    CURRENT_FAILED=1
    echo "    [frontmatter from outside the collection reached the index]"
  fi
  # The unusable name is refused by the id gate rather than silently dropped.
  assert_match "control-char name refused" 'not a valid id' "$idx"
}

# AC: a refusal message quoting an untrusted entry name cannot inject a line
# into the index — the warnings block is as sanitized as a row.
case_issues_index_control_char_name_cannot_forge_a_section() {
  local dir
  dir=$(empty_dir index_ctrl_forge)
  # The name closes its own warning line and opens a second Issues section.
  # Readers assign by the LAST such section, so an injected one is what serves.
  printf -- '---\ntitle: "Real"\nstatus: open\n---\n' \
    > "$dir/$(printf 'bad\n## Issues\n\n- `20260101-forged` — FORGED · status: open\n.md')"
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  # The name is quoted back in the refusal, so its bytes appear — sanitized,
  # inert, inside a code span on one line. What must not appear is anything a
  # reader resolves: a second section to take rows from, or a row of its own.
  assert_eq "exactly one Issues section" 1 "$(grep -c '^## Issues$' <<<"$idx")"
  if echo "$idx" | grep -q '^- `20260101-forged`'; then
    CURRENT_FAILED=1
    echo "    [an entry name forged a row through the warnings block]"
  fi
  assert_eq "warning occupies one line" 1 "$(grep -c 'not a valid id' <<<"$idx")"
}

# AC: every untrusted value concatenated into the warnings block clears the
# same display sanitizer a row value clears — control characters out, capped.
case_issues_index_warning_values_clear_the_sanitizer() {
  local dir long
  dir=$(empty_dir index_warn_sanitize)
  long="$(printf 'A%.0s' $(seq 1 600))"
  # Path-shaped so the origin lint checks it; non-existent so it warns.
  printf -- '---\ntitle: "X"\nstatus: open\norigin: "docs/%s%sTAILMARK"\n---\n' \
    "$(printf '\033[31m\r')" "$long" > "$dir/20260101-o.md"
  run_index "$dir"
  local idx
  idx="$(cat "$dir/INDEX.md")"
  assert_match "origin warning present" 'origin path does not resolve' "$idx"
  if grep -q $'\033' "$dir/INDEX.md"; then
    CURRENT_FAILED=1
    echo "    [an escape byte reached the committed index]"
  fi
  if grep -q $'\r' "$dir/INDEX.md"; then
    CURRENT_FAILED=1
    echo "    [a carriage return reached the committed index]"
  fi
  if echo "$idx" | grep -q 'TAILMARK'; then
    CURRENT_FAILED=1
    echo "    [an unbounded origin value landed whole in the index]"
  fi
}

# AC: stripping control characters cannot reconstitute the row separator — the
# sanitizer's stages run in the one order that closes this, and this case is
# what says so when someone reorders them.
case_issues_index_sanitizer_cannot_reconstitute_a_separator() {
  local dir
  dir=$(empty_dir index_sep_reconstitute)
  # The separator is two bytes, C2 B7. Splitting them with a control byte hides
  # it from a separator strip that runs before the control-character strip, and
  # the strip then rejoins them. Spaces either side so a survivor is the exact
  # ` · ` sequence readers split rows on.
  printf -- '---\ntitle: "A %s status: closed"\nstatus: open\n---\n' \
    "$(printf '\xc2\x01\xb7')" > "$dir/20260101-s.md"
  run_index "$dir"
  local row seps
  row="$(grep '^- `20260101-s`' "$dir/INDEX.md")"
  assert_nonempty "row rendered" "$row"
  # This fixture carries title and status only, so the writer emits exactly one
  # separator. Any second one came from the title.
  seps="$(grep -o ' · ' <<<"$row" | wc -l)"
  assert_eq "no separator reconstituted" 1 "$seps"
  assert_match "the writer's own status is what resolves" 'status: open' "$row"
}

# AC: a malformed wikilink is sanitized on its way into the warning that names
# it — body text is untrusted on the same footing as frontmatter.
case_issues_index_malformed_wikilink_is_sanitized() {
  local dir
  dir=$(empty_dir index_wl_sanitize)
  # Bracket-free control bytes: the wikilink grammar is `[[^][]+]]`, so a value
  # carrying `[` never matches as a wikilink in the first place.
  printf -- '---\ntitle: "X"\nstatus: open\n---\n\nSee [[not a valid id%s]].\n' \
    "$(printf '\033\r')" > "$dir/20260101-w.md"
  run_index "$dir"
  assert_match "wikilink warning present" 'malformed wikilink' "$(cat "$dir/INDEX.md")"
  if grep -q $'\033' "$dir/INDEX.md"; then
    CURRENT_FAILED=1
    echo "    [an escape byte reached the index via a wikilink]"
  fi
}

# AC: an invalid relation target is sanitized on its way into the warning that
# names it, like every other untrusted value the block quotes.
case_issues_index_invalid_relation_target_is_sanitized() {
  local dir
  dir=$(empty_dir index_rel_sanitize)
  printf -- '---\ntitle: "X"\nstatus: open\nrelations:\n  blocks: ["%s"]\n---\n' \
    "$(printf 'not a valid id\033[31m')" > "$dir/20260101-r.md"
  run_index "$dir"
  assert_match "relation warning present" 'invalid relation target' "$(cat "$dir/INDEX.md")"
  if grep -q $'\033' "$dir/INDEX.md"; then
    CURRENT_FAILED=1
    echo "    [an escape byte reached the index via a relation target]"
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

# stale_locked_collection <name> — a collection whose INDEX.md is stale and
#   whose directory cannot be written, so index.sh's regeneration fails while a
#   prior, serviceable index is still on disk. The printed directory is left
#   unwritable: restore it with `chmod u+w` before the case returns, or the
#   runner's cleanup cannot remove it.
stale_locked_collection() {
  local dir
  dir=$(empty_dir "$1")
  write_issue "$dir" "20260530-a" 'title: "A"
num: 1
status: open
priority: high
created: 2026-05-30'
  bash "$SCRIPT_INDEX" "$dir" >/dev/null 2>&1
  touch "$dir/20260530-a.md"
  chmod a-w "$dir"
  printf '%s\n' "$dir"
}

# AC: a read whose index cannot be refreshed still serves the prior view, says
# so on stderr, and carries a non-zero status — the group serves a stale view
# rather than failing, but never reports success over one.
case_issues_render_list_serves_and_flags_an_unrefreshable_index() {
  local dir
  dir=$(stale_locked_collection render_stale_list)
  run_render list "$dir"
  chmod u+w "$dir"
  assert_exit "carries the failure"      1        "$RC"
  assert_match "still serves the view"   '#1'     "$OUT"
  assert_match "discloses the staleness" 'stale'  "$ERR"
}

# AC: the same posture on `stats` — the summary is served and the status carries.
case_issues_render_stats_serves_and_flags_an_unrefreshable_index() {
  local dir
  dir=$(stale_locked_collection render_stale_stats)
  run_render stats "$dir"
  chmod u+w "$dir"
  assert_exit "carries the failure"      1          "$RC"
  assert_match "still serves the view"   'Open: 1'  "$OUT"
  assert_match "discloses the staleness" 'stale'    "$ERR"
}

# AC: the same posture on `show` — the issue is served and the status carries.
case_issues_render_show_serves_and_flags_an_unrefreshable_index() {
  local dir
  dir=$(stale_locked_collection render_stale_show)
  run_render show 1 "$dir"
  chmod u+w "$dir"
  assert_exit "carries the failure"      1               "$RC"
  assert_match "still serves the view"   '20260530-a'    "$OUT"
  assert_match "discloses the staleness" 'stale'         "$ERR"
}

# AC: the same posture on `insights-graph`. It is the analyst's input, so a
# stale graph is exactly the case the analyst cannot detect for itself — the
# facts are still emitted, and the status is what says they may be behind.
case_issues_render_insights_graph_serves_and_flags_an_unrefreshable_index() {
  local dir
  dir=$(stale_locked_collection render_stale_graph)
  run_render insights-graph "$dir"
  chmod u+w "$dir"
  assert_exit "carries the failure"      1                        "$RC"
  assert_match "still serves the facts"  'ISOLATED 20260530-a'    "$OUT"
  assert_match "discloses the staleness" 'stale'                  "$ERR"
}

# AC: the flag fires only on an actual failure — a collection whose index
# regenerates cleanly still returns 0 and says nothing. Without this the four
# cases above pass against a render that fails every read.
case_issues_render_refreshable_index_stays_silent_and_zero() {
  local dir
  dir=$(empty_dir render_fresh_index)
  write_issue "$dir" "20260530-a" 'title: "A"
num: 1
status: open
priority: high
created: 2026-05-30'
  bash "$SCRIPT_INDEX" "$dir" >/dev/null 2>&1
  touch "$dir/20260530-a.md"
  run_render list "$dir"
  assert_exit "clean read succeeds"  0    "$RC"
  assert_match "view served"         '#1' "$OUT"
  if printf '%s\n' "$ERR" | grep -q 'stale'; then
    CURRENT_FAILED=1
    echo "    [a refreshable index must not be reported stale] [$ERR]"
  fi
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

# A malformed created carrying a literal backslash-n must stay one field's text.
# `awk -v` would expand it into a real newline and the value's own trailing text
# would open a second frontmatter pair — so `status:` is placed AFTER `created:`
# here, where an injected pair becomes the first match every reader resolves.
# The assertion is on what a reader resolves, not on whether the text survives:
# the text is the issue's own field value and not this script's to censor.
case_issues_backfill_normalize_no_escape_expansion() {
  local dir f
  dir=$(empty_dir backfill_normalize_escape)
  # A date-only `updated` is what makes the file eligible for rewrite at all —
  # the skip fires only when neither field changed.
  write_issue "$dir" "20260613-x" 'title: "X"
num: 1
created: not-a-date\nstatus: closed
updated: 2026-06-13
status: open'
  run_backfill timestamp "$dir"
  f="$dir/20260613-x.md"
  assert_exit "rc" 0 "$RC"
  assert_eq   "updated still normalized"  "2026-06-13T00:00:00Z" "$(read_fm_field "$f" updated)"
  assert_eq   "status a reader resolves"  "open"                 "$(read_fm_field "$f" status)"
  assert_eq   "no second status pair"     "1"                    "$(grep -c '^status:' "$f")"
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

# AC: a skipped issue says why it was skipped. The preview is the gate an
# operator approves a destructive migration on, and every skip row carries an
# empty new-id field — which `IFS=$'\t' read` collapses, since tab is IFS
# whitespace, shifting the reason into the new-id slot and dropping it.
case_issues_migrate_preview_states_the_skip_reason() {
  local dir cfg
  dir=$(empty_dir migrate_skip_reason)
  write_issue "$dir" "noprefix" 'title: "X"
status: open
num: 1
created: 2026-01-01T00:00:00Z'
  cfg=$(fixture migrate-skip-reason.toml "issues_path = \"$dir\"")
  run_migrate -c "$cfg" prefix
  assert_exit  "rc" 0 "$RC"
  assert_match "the skip names its reason" \
    'un-migratable: id has no prefix delimiter' "$OUT"
}

# AC: the collision discriminator is an id in its own right, and it becomes a
# filename. Its source cleared the id boundary, but clearance does not transfer:
# the suffix can carry a slug already at the 128-character cap past it. The
# header claimed "the new id and any -2/-3 discriminator pass jimfile's
# valid-id" while only the former did (`id-gate-before-path`, critical).
case_issues_migrate_discriminator_clears_the_id_boundary() {
  local dir cfg slug
  dir=$(empty_dir migrate_disc_cap)
  # 119 characters, so the re-derived `20260101-<slug>` is exactly 128 and its
  # discriminated form is 130.
  slug="$(printf 'a%.0s' $(seq 1 119))"
  write_issue "$dir" "20250101-$slug" 'title: "A"
status: open
num: 1
created: 2026-01-01T00:00:00Z'
  write_issue "$dir" "20250102-$slug" 'title: "B"
status: open
num: 2
created: 2026-01-01T00:00:00Z'
  cfg=$(fixture migrate-disc-cap.toml "issues_path = \"$dir\"")
  run_migrate -c "$cfg" prefix
  assert_exit  "rc" 0 "$RC"
  assert_match "the over-long discriminated id is refused" \
    'discriminated id failed validation' "$OUT"
  assert_eq "and no 130-character name is proposed" "no" \
    "$(grep -q -- "-$slug-2" <<< "$OUT" && echo yes || echo no)"
}

# AC: a row downgraded inside the assignment loop keeps its file, so it must
# keep its name too. The reservation loop deliberately leaves a rename's old id
# free — a licence that holds only while the file actually moves away. A
# downgrade revokes that, and without re-reserving, a later row is assigned the
# name of a file that is still sitting there: both mv into one path, the retire
# loop removes the survivor's old name, and the run exits 0 reporting success.
case_issues_migrate_downgraded_row_keeps_its_name_reserved() {
  local dir cfg slug titles
  dir=$(empty_dir migrate_downgrade_reserve)
  # 119 characters, so a re-derived `<8-digit>-<slug>` is exactly 128 and any
  # discriminated form is 130 — over the cap, which is what forces a downgrade.
  slug="$(printf 'a%.0s' $(seq 1 119))"
  # Re-derives onto C-below's conforming id, so it discriminates past the cap
  # and is downgraded. Its own file stays at this name.
  write_issue "$dir" "20250101-$slug" 'title: "B"
status: open
num: 2
created: 2026-01-01T00:00:00Z'
  # Already conforming, so the reservation loop holds this id.
  write_issue "$dir" "20260101-$slug" 'title: "A"
status: open
num: 1
created: 2026-01-01T00:00:00Z'
  # Sorts last, and re-derives onto the downgraded row's still-occupied name.
  write_issue "$dir" "20270101-$slug" 'title: "C"
status: open
num: 3
created: 2025-01-01T00:00:00Z'
  cfg=$(fixture migrate-downgrade-reserve.toml "issues_path = \"$dir\"")
  run_migrate -c "$cfg" prefix --apply
  assert_exit "rc" 0 "$RC"
  # Every issue that existed before the run still exists after it. Asserted on
  # titles rather than filenames: the defect renames one file over another, so
  # a filename count alone stays at three while one issue's content is gone.
  titles="$(grep -h '^title:' "$dir"/*.md 2>/dev/null | sort | tr -d '"' | sed 's/title: //' | tr '\n' ' ')"
  assert_eq "all three issues survive" "A B C " "$titles"
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

# AC: a failure part-way through the commit loses no issue. Every staged file is
# put in place before any old name is retired, so the worst a mid-commit failure
# can leave is an issue present under both names — never one present under
# neither, with its only copy a tmp nothing removes.
case_issues_migrate_commit_failure_loses_no_issue() {
  local dir cfg f content
  dir=$(empty_dir migrate_commit_fail)
  write_issue "$dir" "20260613-aaa" 'title: "A"
status: open
num: 1
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-13T09:00:00Z'
  write_issue "$dir" "20260613-bbb" 'title: "B"
status: open
num: 2
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-13T10:00:00Z'
  cfg=$(fixture migrate-commitfail.toml "issues_path = \"$dir\"
issue_id_prefix = \"timestamp\"")

  export MIGRATE_FAIL_COMMIT=1
  run_migrate -c "$cfg" prefix --apply
  unset MIGRATE_FAIL_COMMIT
  assert_exit  "injected commit fails" 1 "$RC"
  assert_match "says nothing was lost" 'none has been lost' "$ERR"

  # Both issues are still readable under some name.
  local a_found=no b_found=no
  for f in "$dir"/*.md; do
    content="$(cat "$f")"
    [[ "$content" == *'title: "A"'* ]] && a_found=yes
    [[ "$content" == *'title: "B"'* ]] && b_found=yes
  done
  assert_eq "A survived the failed commit" "yes" "$a_found"
  assert_eq "B survived the failed commit" "yes" "$b_found"
  # And no staged tmp is left behind for a later run to pick up.
  assert_eq "no tmp stranded in the collection" "" \
    "$(find "$dir" -name '.migrate.tmp.*' -print 2>/dev/null)"

  # A re-run converges: both end up at their migrated names.
  run_migrate -c "$cfg" prefix --apply
  assert_exit "retry rc 0" 0 "$RC"
  assert_eq "A at its migrated name" "yes" \
    "$([[ -f "$dir/20260613T090000-aaa.md" ]] && echo yes || echo no)"
  assert_eq "B at its migrated name" "yes" \
    "$([[ -f "$dir/20260613T100000-bbb.md" ]] && echo yes || echo no)"
}

# AC: a mid-commit failure on a rename CHAIN loses no issue either. Where one
# file's new name is another's old name, the earlier rename writes over the
# later issue's only on-disk copy — so discarding that issue's staged file, as
# the disjoint case correctly does, is what would leave it nowhere. The staged
# file is held instead, and the message stops claiming a guarantee it cannot
# make. `aaa`'s target IS `bbb`'s current name, and the seam fails at `bbb`.
case_issues_migrate_commit_failure_on_a_chain_holds_the_last_copy() {
  local dir cfg f content
  dir=$(empty_dir migrate_commit_fail_chain)
  write_issue "$dir" "20260613T090000-foo" 'title: "A"
status: open
num: 1
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-13T10:00:00Z'
  write_issue "$dir" "20260613T100000-foo" 'title: "B"
status: open
num: 2
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-13T11:00:00Z'
  cfg=$(fixture migrate-chainfail.toml "issues_path = \"$dir\"
issue_id_prefix = \"timestamp\"")

  export MIGRATE_FAIL_COMMIT=1
  run_migrate -c "$cfg" prefix --apply
  unset MIGRATE_FAIL_COMMIT
  assert_exit "injected commit fails" 1 "$RC"

  # B's content is what the clobber puts at risk. Search the whole directory,
  # dotfiles included — a held staged file is exactly where it should be found.
  local b_found=no
  for f in "$dir"/* "$dir"/.[!.]*; do
    [[ -f "$f" ]] || continue
    content="$(cat "$f")"
    [[ "$content" == *'title: "B"'* ]] && b_found=yes
  done
  assert_eq    "B still exists on disk"        "yes"          "$b_found"
  assert_eq    "no false all-clear"            ""             "$(grep -o 'none has been lost' <<<"$ERR")"
  assert_match "names the staged copy it kept" 'is staged at' "$ERR"
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
  assert_match "origin"   '^origin: "docs/specs/jim/025/plan.md"$' "$(cat "$f")"
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

# AC: the index refuses when it cannot resolve the placement, rather than
# reading an empty result as `branch`. That default *runs* the origin lint, so a
# failed resolve made the published index claim a check it never performed —
# while place.sh takes the explicitly opposite stance on the same key.
case_index_refuses_when_the_placement_resolve_fails() {
  local dir before
  dir=$(empty_dir index_resolve_fail)
  write_issue "$dir" "20260101-r" 'title: "T"
status: open
num: 1
priority: low
created: 2026-01-01T00:00:00Z'
  bash "$SCRIPT_INDEX" "$dir" >/dev/null 2>&1
  before="$(cat "$dir/INDEX.md")"
  # A config that exists but cannot be read: the resolver reports a failure
  # rather than an unset key, and this caller honours it. The directory is
  # passed explicitly so `resolve_dir` does not consult the config first — the
  # placement resolve is the failure under test, not the issues-root one.
  printf 'issue_placement = "jim/issues"\n' > "$dir/jimconf.toml"
  chmod 000 "$dir/jimconf.toml"
  OUT="$(cd "$dir" && bash "$SCRIPT_INDEX" "$dir" 2>"$TMP_BASE/.err")"
  RC=$?
  ERR="$(cat "$TMP_BASE/.err")"
  chmod 644 "$dir/jimconf.toml"
  assert_eq    "refuses"          "no" "$([[ "$RC" == 0 ]] && echo yes || echo no)"
  assert_match "names the key"    'issue_placement' "$ERR"
  assert_eq "and the previous index is untouched" "$before" "$(cat "$dir/INDEX.md")"
}

# AC: the placement name lands in a committed artifact, so it clears the corpus
# display sanitizer — control characters out and a length cap — rather than a
# local one that had neither.
case_index_caps_the_displayed_placement_name() {
  local dir long line
  dir=$(empty_dir index_place_cap)
  write_issue "$dir" "20260101-c" 'title: "T"
status: open
num: 1
priority: low
created: 2026-01-01T00:00:00Z'
  long="$(printf 'b%.0s' $(seq 1 900))"
  # index.sh reads config from its CWD, and an explicit directory argument opts
  # out of placement routing — so this drives the lint's skip branch directly.
  printf 'issue_placement = "%s"\n' "$long" > "$dir/jimconf.toml"
  OUT="$(cd "$dir" && bash "$SCRIPT_INDEX" "$dir" 2>&1)"; RC=$?
  assert_exit "rc" 0 "$RC"
  line="$(grep -m1 'origin paths not checked' "$dir/INDEX.md")"
  assert_nonempty "the skip is stated" "$line"
  assert_eq "and the name is capped" "yes" \
    "$([[ "${#line}" -lt 700 ]] && echo yes || echo no)"
}

# AC: an INDEX.md row's shape is a property of the writer, not of its inputs. A
# row is ` · `-separated `key: value` pairs and every reader assigns by key in
# the order it meets them, so a value able to reproduce the separator appends a
# pair that overrides one the writer already emitted — forging the status `list`
# serves, or the `num` that `show <N>` resolves against.
case_index_row_values_cannot_forge_a_later_key() {
  local dir
  dir=$(empty_dir index_row_forge)
  write_issue "$dir" "20260101-forge" 'title: "T"
status: open
num: 5
priority: low
created: 2026-01-01T00:00:00Z
origin: " · status: closed · num: 1"'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  # The forged text may still be *present* — it is the issue's own origin value
  # and is not the writer's to censor. What must not survive is its ability to
  # form a pair, so the assertions are on the separator-qualified form a reader
  # splits on, never on the bare substring.
  assert_eq "exactly one status pair" "1" \
    "$(grep -c ' · status: open' "$dir/INDEX.md")"
  assert_eq "no forged status pair" "no" \
    "$(grep -q ' · status: closed' "$dir/INDEX.md" && echo yes || echo no)"
  assert_eq "no forged ordinal pair" "no" \
    "$(grep -q ' · num: 1' "$dir/INDEX.md" && echo yes || echo no)"
  # And every read verb agrees, since they parse the row the writer wrote.
  run_render list "$dir"
  assert_exit "list rc" 0 "$RC"
  assert_eq "the issue is still open to a reader" "no" \
    "$(grep -q 'closed' <<< "$OUT" && echo yes || echo no)"
}

# AC: the integrity-warnings section is concatenated from untrusted values — a
# body wikilink, a relation target, an origin path, a filename-derived slug —
# and was emitted with `printf '%b'`, which expands backslash escapes in them.
# A value carrying a literal \n could inject lines, and every reader re-opens
# the issues section on a later `## Issues`, so injected lines become rows.
case_index_warnings_do_not_expand_escapes() {
  local dir before_rows after_rows
  dir=$(empty_dir index_warn_escape)
  write_issue "$dir" "20260101-esc" 'title: "T"
status: open
num: 1
priority: low
created: 2026-01-01T00:00:00Z
relations:
  blocks: [not-a-valid-id\n## Issues\n- `20260101-ghost` — Ghost · status: open]'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  assert_eq "only one Issues heading" "1" \
    "$(grep -c '^## Issues$' "$dir/INDEX.md")"
  # The target's text may appear inside the warning that names it — that is the
  # warning doing its job. What must not exist is a *row*: a line that opens
  # like one, which is what every reader parses.
  assert_eq "no injected row" "no" \
    "$(grep -q '^- `20260101-ghost`' "$dir/INDEX.md" && echo yes || echo no)"
  assert_eq "and the warning stayed on one line" "1" \
    "$(grep -c 'invalid relation target' "$dir/INDEX.md")"
  # And no reader serves a ghost.
  run_render list "$dir"
  assert_exit "list rc" 0 "$RC"
  assert_eq "nothing fabricated reaches a reader" "no" \
    "$(grep -q 'Ghost' <<< "$OUT" && echo yes || echo no)"
}

# AC: --origin is YAML-encoded like --title. It is model-composed free text with
# a convention behind it — a source path, or the `conversation` sentinel — and
# nothing mechanical enforcing either, so it belongs to the untrusted set the
# invariant names. Emitted bare, an origin of `foo: bar`, `[a, b]` or `!!tag`
# changes the parsed type or leaves the frontmatter unparseable for a real YAML
# consumer, and lands verbatim in INDEX.md prose.
case_new_origin_is_a_quoted_scalar() {
  local dir b f
  dir=$(empty_dir new_origin_enc)
  b=$(fixture new_origin_enc_body.md 'body')
  run_new --dir "$dir" --slug "20260101-org" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "T" --priority low --labels "x" \
    --origin 'foo: bar "q" \b' --body-file "$b"
  assert_exit "rc" 0 "$RC"
  f="$dir/20260101-org.md"
  assert_match "emitted as a quoted scalar" '^origin: "' "$(cat "$f")"
  assert_match "the inner quote is escaped"     'bar \\"q\\"' "$(cat "$f")"
  assert_match "the backslash is escaped first" '\\\\b"$'     "$(cat "$f")"
  assert_eq "frontmatter is still well formed" "2" "$(grep -c '^---$' "$f")"
  run_index "$dir"
  assert_exit "index parses" 0 "$RC"
}

# AC: the id clears the validator before any path is composed from it — the
# ordering `id-gate-before-path` (criticality critical) states. It is asserted
# textually because what the gate guards here is a stat: it answers a filesystem
# question and leaves nothing behind for a behavioural case to read. Brittle to
# renaming `$slug` by design, in the same way the byte-agreement fixtures are.
case_new_validates_the_id_before_composing_a_path() {
  local src gate compose
  src="$REPO_ROOT/skills/issue/scripts/new.sh"
  gate="$(grep -n 'valid-id "\$slug"' "$src" | head -1 | cut -d: -f1)"
  compose="$(grep -n '\$issues_dir/\$slug' "$src" | head -1 | cut -d: -f1)"
  assert_nonempty "the gate is present"        "$gate"
  assert_nonempty "a composition is present"   "$compose"
  assert_eq "the gate comes first" "yes" \
    "$([[ -n "$gate" && -n "$compose" && "$gate" -lt "$compose" ]] && echo yes || echo no)"
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
type: issue
filed-by: "tester@example.test"
claimed-by: ""
outcome: ""
labels: [a, b]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"
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

# ─── issue/011: placement routing through the entry scripts ──────────────────

# placement_repo <name> <destination-branch>
#   A repo whose issue collection is configured to live on <destination-branch>
#   rather than on whatever branch the developer is standing on.
placement_repo() {
  local repo; repo="$(new_repo "$1")"
  printf 'issue_placement = "%s"\n' "$2" > "$repo/jimconf.toml"
  printf 'base\n' > "$repo/README.md"
  git -C "$repo" add README.md jimconf.toml
  git -C "$repo" commit -q -m base
  printf '%s' "$repo"
}

# dest_paths <repo> <branch> — every path on <branch>.
dest_paths() { git -C "$1" ls-tree -r --name-only "refs/heads/$2" 2>/dev/null; }

# stale_dest_index <repo> <branch> <prefix>
#   Hollow out <branch>'s INDEX.md by plumbing, leaving the issues beside it
#   alone — the shape a hand commit, a merge, or a bulk import leaves behind.
#
#   This is what gives the read-only cases below something to discriminate on. A
#   read verb writes no issue file, so a destination whose index already
#   describes it cannot move whether the run routed read-only or not. Against a
#   stale one it can: placement regenerates the index in what it materializes,
#   so a run that published would publish that correction.
stale_dest_index() {
  local repo="$1" branch="$2" prefix="$3"
  local blob tree commit idx rc=0
  [[ -n "$(git -C "$repo" ls-tree "refs/heads/$branch:$prefix" 2>/dev/null)" ]] || return 1
  blob="$(printf '# Issues Index\n' | git -C "$repo" hash-object -w --stdin)" || return 1
  # One path is replaced inside the existing tree rather than each level being
  # rebuilt from its single known child. Rebuilding drops any sibling the level
  # also holds — harmless while the destination is an orphan carrying the
  # collection alone, and a fixture that silently discards the rest of the
  # branch the moment a case points a placement at one that carries anything
  # else.
  idx="$TMP_BASE/.stale-index"
  rm -f -- "$idx"
  GIT_INDEX_FILE="$idx" git -C "$repo" read-tree "refs/heads/$branch" || rc=1
  (( rc == 0 )) && { GIT_INDEX_FILE="$idx" git -C "$repo" update-index --add \
    --cacheinfo 100644 "$blob" "$prefix/INDEX.md" || rc=1; }
  (( rc == 0 )) && { tree="$(GIT_INDEX_FILE="$idx" git -C "$repo" write-tree)" || rc=1; }
  rm -f -- "$idx"
  (( rc == 0 )) || return 1
  [[ -n "$tree" ]] || return 1
  commit="$(git -C "$repo" commit-tree "$tree" -p "refs/heads/$branch" -m stale)" || return 1
  git -C "$repo" update-ref "refs/heads/$branch" "$commit" || return 1
  return 0
}

# AC: filing under a branch placement lands the issue and its regenerated index
# on the destination as one commit, and leaves the working branch untouched.
# The emitter is the single write door, so making the door placement-aware is
# what carries every surfacing skill's candidate batch with it (spec AC #3, #4).
case_issues_placement_filing_lands_on_destination() {
  local repo body slug paths
  repo="$(placement_repo issues_place_file jim/issues)"
  body="$(fixture issues_place_file_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_nonempty "slug" "$slug"
  paths="$(dest_paths "$repo" jim/issues)"
  assert_match "issue on the destination" "docs/issues/${slug}\.md" "$paths"
  assert_match "index on the destination" 'docs/issues/INDEX\.md'   "$paths"
  assert_eq "one commit" "1" \
    "$(git -C "$repo" rev-list --count refs/heads/jim/issues)"
  assert_eq "working tree untouched" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
  assert_eq "working branch clean" "" "$(git -C "$repo" status --porcelain)"
}

# AC: the stdout contract stays useful under placement — the path a caller is
# told about is where the issue actually lives on the destination branch, not
# the temp directory it was composed in.
case_issues_placement_stdout_names_the_destination_path() {
  local repo body slug path
  repo="$(placement_repo issues_place_stdout jim/issues)"
  body="$(fixture issues_place_stdout_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  path="${OUT##*$'\t'}"
  assert_eq "repo-relative destination path" "docs/issues/${slug}.md" "$path"
}

# AC: free-form user text survives the routing re-exec verbatim. A title
# containing `{}` is ordinary in a developer tool, and the placeholder the
# re-exec uses to pass the collection directory must not rewrite it — the slug
# derived from the title is the durable id, and the registry that records it
# only ever grows (spec AC #2, #3).
case_issues_placement_preserves_braces_in_a_title() {
  local repo body slug
  repo="$(placement_repo issues_place_braces jim/issues)"
  body="$(fixture issues_place_braces_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Fix the {} placeholder in output" \
    --priority medium --labels x --origin conversation --body-file "$body"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_match "slug derives from the title alone" \
    '^[0-9]{8}-fix-the-placeholder-in-output$' "$slug"
  assert_match "title stored verbatim" 'title: "Fix the \{\} placeholder in output"' \
    "$(git -C "$repo" cat-file -p "refs/heads/jim/issues:docs/issues/${slug}.md")"
}

# AC: an origin: that names an artifact living only on the filing branch is
# still valid at the destination — the reference is informational, and its
# absence is not an error (spec AC #11).
case_issues_placement_tolerates_a_branch_only_origin() {
  local repo body slug
  repo="$(placement_repo issues_place_origin jim/issues)"
  body="$(fixture issues_place_origin_body.md 'body')"
  # Deliberately not created: the origin has to be genuinely absent at the
  # destination for this to be the dangling case the AC is about. It is also
  # path-shaped, which is what makes the lint look at it at all — a bare token
  # carries no `/` and is exempted before its existence is ever checked, so the
  # AC's case would go unexercised whether the file was there or not.
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin "docs/brainstorms/only-here.md" --body-file "$body"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_match "origin recorded verbatim" '^origin: "docs/brainstorms/only-here\.md"$' \
    "$(git -C "$repo" cat-file -p "refs/heads/jim/issues:docs/issues/${slug}.md")"
  assert_match "index still built" 'docs/issues/INDEX\.md' \
    "$(dest_paths "$repo" jim/issues)"
  # The published index says the check was not run rather than reporting a
  # result it has no ground for. Whether the origin resolves is a fact about the
  # checkout that wrote last, and this index belongs to every reader.
  local index
  index="$(git -C "$repo" cat-file -p refs/heads/jim/issues:docs/issues/INDEX.md)"
  assert_match "the skip is disclosed"      'origin paths not checked' "$index"
  assert_match "and names the destination"  'jim/issues'               "$index"
  assert_eq "no per-issue origin verdict is published" "no" \
    "$(grep -q 'origin path does not resolve' <<< "$index" && echo yes || echo no)"
}

# AC: the same origin, with no placement configured, is still linted — the check
# has ground truth when the collection is on the branch the run is standing on,
# and the dangling reference is informational rather than an error (spec AC #11).
case_issues_origin_lint_still_runs_without_a_placement() {
  local repo body index
  repo="$(new_repo issues_origin_default)"
  body="$(fixture issues_origin_default_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin "docs/brainstorms/only-here.md" --body-file "$body"
  assert_exit "rc" 0 "$RC"
  run_index "$repo/docs/issues"
  assert_exit "index rc" 0 "$RC"
  index="$(cat "$repo/docs/issues/INDEX.md")"
  assert_match "the dangling origin is reported" 'origin path does not resolve' "$index"
  assert_eq "and nothing claims the check was skipped" "no" \
    "$(grep -q 'origin paths not checked' <<< "$index" && echo yes || echo no)"
}

# AC: an explicit directory argument opts out of routing — a caller that named
# a directory means that directory, which is also what keeps the placement
# re-exec from recursing.
case_issues_placement_explicit_dir_opts_out() {
  local repo body dir
  repo="$(placement_repo issues_place_optout jim/issues)"
  body="$(fixture issues_place_optout_body.md 'body')"
  dir="$repo/elsewhere"
  mkdir -p "$dir"
  run_new_in "$repo" --dir "$dir" --title "Alpha bug" --priority medium \
    --labels x --origin conversation --body-file "$body"
  assert_exit "rc" 0 "$RC"
  assert_eq "wrote where told" "1" "$(find "$dir" -name '*.md' | wc -l | tr -d ' ')"
  assert_eq "no destination branch" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# ─── issue/011: the auto-file scrub gate ─────────────────────────────────────

# AC: an auto-filed batch does not reach a shared branch with nobody having
# looked at it. The decision lives in the emitter because the emitter is the
# only place it can be made mechanically — a rule stated in a skill is a rule an
# agent may or may not execute, and every candidate batch comes through here
# (spec AC #13).
case_issues_auto_file_refuses_an_unacknowledged_placement() {
  local repo body
  repo="$(placement_repo issues_auto_gate jim/issues)"
  body="$(fixture issues_auto_gate_body.md 'body')"
  run_new_in "$repo" --auto --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit     "refuses"  4 "$RC"
  assert_nonempty "explains" "$ERR"
  assert_eq "nothing published" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
  assert_eq "nothing in the working tree either" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
}

# AC: the acknowledgement restores the quiet path for a project that has said it
# understands the bargain (spec AC #13).
case_issues_auto_file_proceeds_when_acknowledged() {
  local repo body slug
  repo="$(placement_repo issues_auto_ack jim/issues)"
  printf 'issue_placement = "jim/issues"\nissue_placement_ack = "true"\n' \
    > "$repo/jimconf.toml"
  body="$(fixture issues_auto_ack_body.md 'body')"
  run_new_in "$repo" --auto --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_match "landed on the destination" "docs/issues/${slug}\.md" \
    "$(dest_paths "$repo" jim/issues)"
}

# AC: the gate is placement-only. Under the default placement a filed issue
# stays on the developer's own branch until it merges, which is the bargain
# auto-filing was already weighed against (spec AC #2, #13).
case_issues_auto_file_is_a_no_op_by_default() {
  local repo body slug
  repo="$(new_repo issues_auto_default)"
  body="$(fixture issues_auto_default_body.md 'body')"
  run_new_in "$repo" --auto --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_eq "written to the working tree" "yes" \
    "$([[ -e "$repo/docs/issues/$slug.md" ]] && echo yes || echo no)"
}

# AC: an explicit directory means that directory, so it opts out of routing —
# and the gate rides on routing, since it is publication to a shared branch that
# makes the auto-file bargain a different one. A caller that named a directory
# is publishing nothing, so `--auto` is inert there even under a placement the
# project has not acknowledged (spec AC #13).
case_issues_auto_file_is_inert_under_an_explicit_dir() {
  local repo body slug
  repo="$(placement_repo issues_auto_dir jim/issues)"
  body="$(fixture issues_auto_dir_body.md 'body')"
  mkdir -p "$repo/elsewhere"
  run_new_in "$repo" --auto --dir "$repo/elsewhere" \
    --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_eq "written where the caller said" "yes" \
    "$([[ -e "$repo/elsewhere/$slug.md" ]] && echo yes || echo no)"
  assert_eq "and nothing published" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# AC: the interactive path still files under an unacknowledged placement — the
# review the gate asks for is exactly what that path already did. It declares it
# with --reviewed, which is the counterpart of --auto rather than a second gate
# (spec AC #13).
case_issues_interactive_file_unaffected_by_the_gate() {
  local repo body slug
  repo="$(placement_repo issues_auto_interactive jim/issues)"
  body="$(fixture issues_auto_interactive_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "rc" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_match "landed on the destination" "docs/issues/${slug}\.md" \
    "$(dest_paths "$repo" jim/issues)"
}

# AC: under a placement the declaration is REQUIRED, not defaulted. Reading a
# missing --auto as "reviewed" is what published an unreviewed batch to a shared
# branch on a forgotten flag; the inverse would merely move the silent default,
# sending a reviewed batch to a second review. Neither absence is an answer, so
# a filing that declares nothing refuses — loudly, at the one moment it matters,
# and having written nothing (spec AC #13).
case_issues_placement_filing_without_a_declaration_refuses() {
  local repo body
  repo="$(placement_repo issues_decl_missing jim/issues)"
  body="$(fixture issues_decl_missing_body.md 'body')"
  run_new_in "$repo" --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit  "refuses as a caller defect, not a redirect" 2 "$RC"
  assert_match "names the destination it would publish to" 'jim/issues' "$ERR"
  assert_match "names both remedies"                       'reviewed'   "$ERR"
  assert_eq "nothing published" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
  assert_eq "nothing in the working tree either" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
  assert_eq "and no path on stdout" "" "$OUT"
}

# AC: declaring both is a contradiction, not a precedence puzzle — refused the
# same way rather than letting one win silently.
case_issues_placement_contradictory_declarations_refuse() {
  local repo body
  repo="$(placement_repo issues_decl_both jim/issues)"
  body="$(fixture issues_decl_both_body.md 'body')"
  run_new_in "$repo" --auto --reviewed --title "Alpha bug" --priority medium \
    --labels x --origin conversation --body-file "$body"
  assert_exit  "refuses"            2 "$RC"
  assert_match "says they conflict" 'contradict' "$ERR"
  assert_eq "nothing published" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# AC: and the requirement is scoped to routing, so it is inert for every project
# without a placement — the entire installed base, and the path the
# default-unchanged criterion protects (spec AC #2, #13).
case_issues_declaration_is_not_required_by_default() {
  local repo body slug
  repo="$(new_repo issues_decl_default)"
  body="$(fixture issues_decl_default_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "files with no declaration at all" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_eq "written to the working tree" "yes" \
    "$([[ -e "$repo/docs/issues/$slug.md" ]] && echo yes || echo no)"
}

# AC: index.sh routes too, so a standalone reindex lands at the destination
# rather than on the working branch (spec AC #3).
case_issues_placement_index_routes_to_destination() {
  local repo body
  repo="$(placement_repo issues_place_index jim/issues)"
  body="$(fixture issues_place_index_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  OUT="$(cd "$repo" && bash "$SCRIPT_INDEX" 2>&1)"
  RC=$?
  assert_exit "reindex rc" 0 "$RC"
  assert_eq "working tree still untouched" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
  # The index the filing already published is current, so a bare reindex has
  # nothing to add — no empty second commit.
  assert_eq "no redundant commit" "1" \
    "$(git -C "$repo" rev-list --count refs/heads/jim/issues)"
}

# run_render_in <repo> <args...> — render from inside <repo>, the way a
# developer runs it: config, and therefore placement, resolves from there.
run_render_in() {
  local repo="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && bash "$SCRIPT_RENDER" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# AC: the read verbs serve the destination branch's collection, from a checkout
# whose own working tree holds no issues at all (spec AC #5).
case_issues_placement_list_serves_the_destination() {
  local repo body slug
  repo="$(placement_repo issues_place_list jim/issues)"
  body="$(fixture issues_place_list_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  slug="${OUT%%$'\t'*}"
  assert_eq "nothing in the working tree" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
  run_render_in "$repo" list
  assert_exit  "list rc"          0            "$RC"
  assert_match "lists the issue"  'Alpha bug'  "$OUT"
  run_render_in "$repo" show "$slug"
  assert_exit  "show rc"          0            "$RC"
  assert_match "shows the issue"  'Alpha bug'  "$OUT"
}

# AC: a read serves the destination's collection as it actually stands and
# publishes nothing — even when serving it means regenerating an index the
# destination carries stale, which a write would have committed (spec AC #5).
case_issues_placement_read_publishes_nothing() {
  local repo body before
  repo="$(placement_repo issues_place_readonly jim/issues)"
  body="$(fixture issues_place_readonly_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  stale_dest_index "$repo" jim/issues docs/issues
  assert_exit "fixture" 0 "$?"
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  run_render_in "$repo" list
  assert_exit  "list rc"               0           "$RC"
  assert_match "serves a current view" 'Alpha bug' "$OUT"
  run_render_in "$repo" stats; assert_exit "stats rc" 0 "$RC"
  assert_eq "tip unmoved" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  assert_eq "the published index is left as it was" "# Issues Index" \
    "$(git -C "$repo" cat-file -p refs/heads/jim/issues:docs/issues/INDEX.md)"
  assert_eq "working tree still clean" "" "$(git -C "$repo" status --porcelain)"
}

# AC: when the remote is unreachable a read serves the last-seen state and says
# so on stderr, without polluting the rendered view (spec AC #6).
case_issues_placement_read_degrades_with_a_note() {
  local repo body
  repo="$(placement_repo issues_place_degrade jim/issues)"
  body="$(fixture issues_place_degrade_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-remote.git"
  run_render_in "$repo" list
  assert_exit  "rc"            0           "$RC"
  assert_match "still serves"  'Alpha bug' "$OUT"
  assert_match "notes it"      'last-seen' "$ERR"
}

# AC: insights-graph routes too, so the read-only analyst persona is handed the
# destination's collection rather than an empty working branch (spec AC #5).
case_issues_placement_insights_graph_routes() {
  local repo body
  repo="$(placement_repo issues_place_graph jim/issues)"
  body="$(fixture issues_place_graph_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  run_render_in "$repo" insights-graph
  assert_exit     "rc"     0      "$RC"
  assert_nonempty "output" "$OUT"
}

# run_in <repo> <script> <args...> — run any issue script from inside <repo>.
run_in() {
  local repo="$1" script="$2"; shift 2
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && bash "$script" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# AC: realizing a provisional ordinal under placement rewrites num: at the
# destination and reindexes there, leaving the working branch alone
# (spec AC #3).
case_issues_placement_realize_lands_at_the_destination() {
  local repo body before
  repo="$(placement_repo issues_place_realize jim/issues)"
  body="$(fixture issues_place_realize_body.md 'body')"
  run_new_in "$repo" --reviewed --slug 20260101-a --num "P-20260101-a" \
    --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  assert_match "provisional at the destination" '^num: P-20260101-a$' \
    "$(git -C "$repo" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md)"
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  run_in "$repo" "$SCRIPT_RECONCILE" --apply
  assert_exit "realize rc" 0 "$RC"
  assert_match "num realized at the destination" '^num: 1$' \
    "$(git -C "$repo" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md)"
  assert_match "index refreshed there" 'num: 1' \
    "$(git -C "$repo" cat-file -p refs/heads/jim/issues:docs/issues/INDEX.md)"
  assert_eq "one further commit" "1" \
    "$(git -C "$repo" rev-list --count "$before..refs/heads/jim/issues")"
  assert_eq "working tree untouched" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
}

# AC: a preview publishes nothing. reconcile and migrate both preview by
# default, and a preview that committed would make "read-only" a lie.
case_issues_placement_preview_publishes_nothing() {
  local repo body before
  repo="$(placement_repo issues_place_preview jim/issues)"
  body="$(fixture issues_place_preview_body.md 'body')"
  run_new_in "$repo" --reviewed --slug 20260101-a --num "P-20260101-a" \
    --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  stale_dest_index "$repo" jim/issues docs/issues
  assert_exit "fixture" 0 "$?"
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  run_in "$repo" "$SCRIPT_RECONCILE"
  assert_exit "preview rc" 0 "$RC"
  # The preview has to have *seen* the destination's collection, not merely
  # exited cleanly: run against a working tree that holds no collection at all,
  # reconcile reports nothing pending and returns 0 too.
  assert_match "the preview reports the destination's provisional" \
    '20260101-a' "$OUT"
  assert_match "and counts it" '1 pending' "$OUT"
  run_in "$repo" "$SCRIPT_MIGRATE" prefix
  assert_exit "migrate preview rc" 0 "$RC"
  assert_eq "tip unmoved" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  assert_eq "the published index is left as it was" "# Issues Index" \
    "$(git -C "$repo" cat-file -p refs/heads/jim/issues:docs/issues/INDEX.md)"
}

# AC: a flag's value is not a collection directory. Reading `-c <cfg>` as one
# declines routing, and the realization then rewrites the working tree instead
# of the destination — the opt-out is for a caller who *named* a collection
# (spec AC #3).
case_issues_placement_reconcile_routes_with_a_config_flag() {
  local repo body
  repo="$(placement_repo issues_place_reconcile_cfg jim/issues)"
  body="$(fixture issues_place_reconcile_cfg_body.md 'body')"
  run_new_in "$repo" --reviewed --slug 20260101-a --num "P-20260101-a" \
    --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  run_in "$repo" "$SCRIPT_RECONCILE" -c "$repo/jimconf.toml"
  assert_exit "preview rc" 0 "$RC"
  assert_match "the preview saw the destination's collection" '20260101-a' "$OUT"
  assert_eq "and left the working tree alone" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
}

# AC: an invocation missing a required operand is not routed. The placement
# re-exec appends the collection directory, so a `show` with no id would take
# that directory as its id and answer about the run's temp path at rc 0 instead
# of refusing (spec AC #5).
case_issues_placement_show_without_an_id_still_refuses() {
  local repo
  repo="$(placement_repo issues_place_show_noid jim/issues)"
  run_in "$repo" "$SCRIPT_RENDER" show
  assert_exit  "refuses"          2       "$RC"
  assert_match "asks for an id"   'requires an id' "$ERR"
  assert_eq "no temp path leaked into the answer" "no" \
    "$(grep -q 'collection' <<< "$OUT" && echo yes || echo no)"
  assert_eq "and nothing was created in the checkout" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
}

# AC: a lone argument is a collection directory only if it is one. Reading any
# non-filter token as a directory opts a mistyped filter out of placement and
# then has a read verb create a directory of that name in the checkout
# (spec AC #5).
case_issues_placement_list_typo_does_not_litter() {
  local repo body
  repo="$(placement_repo issues_place_list_typo jim/issues)"
  body="$(fixture issues_place_list_typo_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  run_in "$repo" "$SCRIPT_RENDER" list opne
  assert_eq "no directory was created for the typo" "no" \
    "$([[ -e "$repo/opne" ]] && echo yes || echo no)"
  # The typo is reported as what it is — a bad filter against the destination's
  # collection. Classifying it as a directory instead declines routing, and the
  # refusal then comes from the working tree having no such collection, which is
  # a different answer to a different question.
  assert_match "routed rather than read as a collection" 'unknown filter' "$ERR"
}

# AC: the two-argument shape is classified the same way. `dir_given` answered on
# argument *count* for every shape but `list`'s lone one, so
# `/jim:issue list open high` — two valid filters, which the skill substitutes
# whole into `render.sh list` — declined routing, adopted `high` as the
# collection, had a directory created for it in the checkout and served an empty
# view at rc 0 while the destination went unread (spec AC #5).
case_issues_placement_two_filters_do_not_bypass_placement() {
  local repo body
  repo="$(placement_repo issues_place_two_filters jim/issues)"
  body="$(fixture issues_place_two_filters_body.md 'body')"
  run_new_in "$repo" --reviewed --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  run_in "$repo" "$SCRIPT_RENDER" list open high
  assert_eq "no directory was created for the second filter" "no" \
    "$([[ -e "$repo/high" ]] && echo yes || echo no)"
  assert_eq "and it did not serve an empty view as success" "no" \
    "$([[ "$RC" == 0 ]] && echo yes || echo no)"
  assert_match "it says what is wrong" 'high' "$ERR"
}

# AC: a read verb never brings a collection into being. index.sh mkdir -p's
# whatever directory it is handed, and every render verb regenerates through it,
# so a mistyped or steered argument had a directory and an INDEX.md created for
# it — by a read — in the developer's checkout. That is also the capability the
# analyst's agent definition states is absent rather than forbidden.
case_render_read_verbs_create_no_directory() {
  local dir
  dir=$(empty_dir render_no_create)
  write_issue "$dir" "20260101-a" 'title: "A"
status: open
num: 1
priority: low
created: 2026-01-01T00:00:00Z'
  # A collection the caller *named* that is not there is a mistake, and is
  # refused rather than brought into being.
  run_render stats "$dir/nope-stats"
  assert_eq    "stats refuses"       "no" "$([[ "$RC" == 0 ]] && echo yes || echo no)"
  assert_eq    "and created nothing" "no" \
    "$([[ -e "$dir/nope-stats" ]] && echo yes || echo no)"
  run_render show 1 "$dir/nope-show"
  assert_eq "show refuses"        "no" "$([[ "$RC" == 0 ]] && echo yes || echo no)"
  assert_eq "and created nothing" "no" \
    "$([[ -e "$dir/nope-show" ]] && echo yes || echo no)"
  run_render insights-graph "$dir/nope-graph"
  assert_eq "insights-graph refuses" "no" "$([[ "$RC" == 0 ]] && echo yes || echo no)"
  assert_eq "and created nothing"    "no" \
    "$([[ -e "$dir/nope-graph" ]] && echo yes || echo no)"
  # And a named collection that does exist still reads normally. The header
  # names the directory served, which is what pins that *this* one was used —
  # asserting only on a row would match whatever the ambient config resolves to.
  run_render list "$dir"
  assert_exit  "list rc"                 0      "$RC"
  assert_match "serves the named collection" "$dir" "$OUT"
  assert_match "and its issue"               '#1'   "$OUT"
}

# AC: a collection resolved from config that does not exist yet is an ordinary
# empty project, not a mistake — so it reads as empty rather than refusing, and
# still nothing is created. This is the other side of the same guard: refusing
# here would break every project before its first filing.
case_render_unconfigured_collection_reads_as_empty() {
  local dir
  dir=$(empty_dir render_empty_project)
  printf 'issues_path = "%s/docs/issues"\n' "$dir" > "$dir/jimconf.toml"
  OUT="$(cd "$dir" && bash "$SCRIPT_RENDER" list 2>"$TMP_BASE/.err")"; RC=$?
  assert_exit "reads rather than refusing" 0 "$RC"
  assert_eq "and created no collection" "no" \
    "$([[ -e "$dir/docs/issues" ]] && echo yes || echo no)"
}

# AC: the same holds with no placement configured at all — the stray directory
# is what a read verb must never create, whichever branch the collection is on.
case_issues_list_typo_refuses_instead_of_creating_a_dir() {
  local repo
  repo="$(new_repo issues_list_typo_default)"
  run_in "$repo" "$SCRIPT_RENDER" list opne
  assert_exit "refuses" 1 "$RC"
  assert_match "explains the two things it could have been" 'neither a filter' "$ERR"
  assert_eq "no directory was created for the typo" "no" \
    "$([[ -e "$repo/opne" ]] && echo yes || echo no)"
}

# AC: backfill routes too — a display-ordinal backfill lands at the destination
# rather than on the working branch (spec AC #3).
case_issues_placement_backfill_lands_at_the_destination() {
  local repo body
  repo="$(placement_repo issues_place_backfill jim/issues)"
  body="$(fixture issues_place_backfill_body.md 'body')"
  run_new_in "$repo" --reviewed --slug 20260101-a --num 7 --created 2026-01-01 \
    --updated 2026-01-01 --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  assert_match "date-only to begin with" '^created: 2026-01-01$' \
    "$(git -C "$repo" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md)"
  run_in "$repo" "$SCRIPT_BACKFILL" timestamp
  assert_exit "backfill rc" 0 "$RC"
  assert_match "normalized at the destination" '^created: 2026-01-01T00:00:00Z$' \
    "$(git -C "$repo" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md)"
  assert_eq "working tree untouched" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
}

# AC: migrate's rename flow lands the renames and the regenerated index as one
# commit on the destination (spec AC #3, AC #4).
case_issues_placement_migrate_lands_renames_as_one_commit() {
  local repo body before paths
  repo="$(placement_repo issues_place_migrate jim/issues)"
  printf 'issue_placement = "jim/issues"\nissue_id_prefix = "sequential"\n' \
    > "$repo/jimconf.toml"
  git -C "$repo" commit -q -am conf
  body="$(fixture issues_place_migrate_body.md 'body')"
  run_new_in "$repo" --reviewed --slug 20260101-alpha --num 3 \
    --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  run_in "$repo" "$SCRIPT_MIGRATE" prefix --apply
  assert_exit "migrate rc" 0 "$RC"
  paths="$(dest_paths "$repo" jim/issues)"
  assert_match "renamed at the destination" 'docs/issues/0003-alpha\.md' "$paths"
  assert_eq "old name gone" "no" \
    "$(printf '%s\n' "$paths" | grep -q '20260101-alpha\.md' && echo yes || echo no)"
  assert_eq "one commit for the whole rename" "1" \
    "$(git -C "$repo" rev-list --count "$before..refs/heads/jim/issues")"
}

# AC: a rename that loses a push race grafts as a delete plus a create. Carrying
# only the create would leave one issue under two filenames and an index holding
# two entries for it — at rc 0 (security Finding 8).
case_issues_placement_rename_race_grafts_as_delete_and_create() {
  local bare mine theirs body teammate paths index
  bare="$(empty_dir issues_race_bare)"; git init -q --bare "$bare/r.git"
  mine="$(empty_dir issues_race_mine)"
  git clone -q "$bare/r.git" "$mine"
  git -C "$mine" config user.name mine && git -C "$mine" config user.email m@e
  theirs="$(empty_dir issues_race_them)"
  git clone -q "$bare/r.git" "$theirs"
  git -C "$theirs" config user.name them && git -C "$theirs" config user.email t@e
  printf 'issue_placement = "jim/issues"\nissue_id_prefix = "sequential"\n' \
    > "$mine/jimconf.toml"
  printf 'issue_placement = "jim/issues"\n' > "$theirs/jimconf.toml"
  body="$(fixture issues_race_body.md 'body')"
  run_new_in "$mine" --reviewed --slug 20260101-alpha --num 3 \
    --title "Alpha bug" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"
  teammate="$TMP_BASE/issues-race-teammate.sh"
  cat > "$teammate" <<TEAMMATE
cd "$theirs" && bash "$REPO_ROOT/skills/issue/scripts/place.sh" run --verb file -- \\
  sh -c 'printf "theirs\\n" > "\$1/20260101-other.md"' _ '{}'
TEAMMATE
  # The rename runs, then the teammate publishes, then this mutation tries to
  # land — so the graft has to replay both halves of the rename.
  OUT="$(cd "$mine" && bash "$REPO_ROOT/skills/issue/scripts/place.sh" \
    run --verb migrate -- sh -c \
    'bash "$1" prefix "$3" --apply >/dev/null; sh "$2" >/dev/null 2>&1' \
    _ "$SCRIPT_MIGRATE" "$teammate" '{}' 2>"$TMP_BASE/.err")"
  RC=$?
  ERR="$(cat "$TMP_BASE/.err")"
  assert_exit "rc" 0 "$RC"
  paths="$(git -C "$bare/r.git" ls-tree -r --name-only refs/heads/jim/issues)"
  assert_match "renamed"           'docs/issues/0003-alpha\.md'   "$paths"
  assert_match "teammate survived" 'docs/issues/20260101-other\.md' "$paths"
  assert_eq "old name did not come back" "no" \
    "$(printf '%s\n' "$paths" | grep -q '20260101-alpha\.md' && echo yes || echo no)"
  index="$(git -C "$bare/r.git" cat-file -p refs/heads/jim/issues:docs/issues/INDEX.md)"
  assert_eq "index holds one entry for the renamed issue" "1" \
    "$(printf '%s\n' "$index" | grep -c '0003-alpha')"
}

# ─── Section: transition.sh — dispatch and the shared mutation path ─────────

# run_transition <args...> — invoke transition.sh with a pinned identity.
run_transition() {
  local err_file="$TMP_BASE/.err"
  OUT="$(env "${identity_env[@]}" bash "$SCRIPT_TRANSITION" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# transition_dir <name> — a collection holding one open issue.
transition_dir() {
  local d
  d=$(empty_dir "$1")
  write_issue "$d" "20260101-target" 'num: 42
title: "Target"
status: open
priority: medium
type: issue
filed-by: "filer@example.test"
claimed-by: ""
outcome: ""
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  printf '%s' "$d"
}

# transition_issue <dir> <slug> <num> <status> <claimed-by> <outcome>
#   The outcome is rendered bare when set and as an empty quoted scalar when
#   not, which is how the emitter and the close verb actually write it — a
#   fixture that quoted a set value would be testing a shape nothing produces.
transition_issue() {
  local outcome_field='""'
  [[ -n "$6" ]] && outcome_field="$6"
  write_issue "$1" "$2" "num: $3
title: \"T\"
status: $4
priority: medium
type: issue
filed-by: \"filer@example.test\"
claimed-by: \"$5\"
outcome: $outcome_field
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: \"conversation\""
}

# AC: starting an unheld issue also claims it for the developer starting it.
case_transition_start_claims_an_unheld_issue() {
  local dir out
  dir=$(empty_dir transition_start)
  transition_issue "$dir" 20260101-a 1 open "" ""
  run_transition start 20260101-a --dir "$dir"
  assert_exit "rc" 0 "$RC"
  out="$(cat "$dir/20260101-a.md")"
  assert_match "claimed by the starter" "^claimed-by: \"$TEST_IDENTITY\"\$" "$out"
  assert_match "and underway"           '^status: active$'                 "$out"
}

# AC: claiming an issue another developer holds is refused, and the refusal
# names the current holder.
case_transition_claim_refuses_an_issue_another_holds() {
  local dir
  dir=$(empty_dir transition_held)
  transition_issue "$dir" 20260101-b 2 open "someone@example.test" ""
  run_transition claim 20260101-b --dir "$dir"
  assert_exit "rc" 5 "$RC"
  assert_match "names the holder" 'someone@example\.test' "$ERR"
  assert_match "holder unchanged" '^claimed-by: "someone@example.test"$' \
    "$(cat "$dir/20260101-b.md")"
}

# AC: the developer can override the refusal to take it over.
case_transition_claim_force_takes_over() {
  local dir
  dir=$(empty_dir transition_force)
  transition_issue "$dir" 20260101-c 3 open "someone@example.test" ""
  run_transition claim 20260101-c --force --dir "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "taken over" "^claimed-by: \"$TEST_IDENTITY\"\$" "$(cat "$dir/20260101-c.md")"
}

# AC: an issue's holder is distinct from its lifecycle state — re-claiming what
# you already hold changes nothing and is not a refusal.
case_transition_claim_is_idempotent_for_the_holder() {
  local dir
  dir=$(empty_dir transition_reclaim)
  transition_issue "$dir" 20260101-d 4 open "$TEST_IDENTITY" ""
  run_transition claim 20260101-d --dir "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "still held by the same developer" "^claimed-by: \"$TEST_IDENTITY\"\$" \
    "$(cat "$dir/20260101-d.md")"
}

# AC: any developer can close any issue, whether or not they hold it, and
# closing preserves the record of who held it.
case_transition_close_by_a_non_holder_preserves_the_holder() {
  local dir out
  dir=$(empty_dir transition_close_other)
  transition_issue "$dir" 20260101-e 5 active "someone@example.test" ""
  run_transition close 20260101-e --dir "$dir"
  assert_exit "rc" 0 "$RC"
  out="$(cat "$dir/20260101-e.md")"
  assert_match "finished"        '^status: closed$'                     "$out"
  assert_match "holder kept"     '^claimed-by: "someone@example.test"$' "$out"
}

# AC: closing accepts an outcome; when none is given, the issue is recorded as
# completed.
case_transition_close_defaults_the_outcome_to_done() {
  local dir
  dir=$(empty_dir transition_close_default)
  transition_issue "$dir" 20260101-f 6 open "" ""
  run_transition close 20260101-f --dir "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "recorded as completed" '^outcome: done$' "$(cat "$dir/20260101-f.md")"
}

# AC: the outcome distinguishes completed work from work that was declined.
case_transition_close_records_the_given_outcome() {
  local dir
  dir=$(empty_dir transition_close_as)
  transition_issue "$dir" 20260101-g 7 open "" ""
  run_transition close 20260101-g --as wontfix --dir "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "declined" '^outcome: wontfix$' "$(cat "$dir/20260101-g.md")"
}

# AC: the outcome distinguishes completed work from work that was declined,
# superseded, or that ceased to apply — a value outside those is refused before
# anything is written, rather than written and reported by the index afterwards.
case_transition_close_refuses_an_unrecognized_outcome() {
  local dir before
  dir=$(empty_dir transition_bad_outcome)
  transition_issue "$dir" 20260101-l 12 open "" ""
  before="$(cat "$dir/20260101-l.md")"
  run_transition close 20260101-l --as donw --dir "$dir"
  assert_exit "rc" 2 "$RC"
  assert_nonempty "explains" "$ERR"
  assert_eq "nothing written" "$before" "$(cat "$dir/20260101-l.md")"
}

# AC: work that was declined and work that ceased to apply are both recordable.
case_transition_close_accepts_the_other_outcomes() {
  local dir o n=20
  for o in wontfix obsolete; do
    dir=$(empty_dir "transition_outcome_$o")
    transition_issue "$dir" 20260101-m "$n" open "" ""
    run_transition close 20260101-m --as "$o" --dir "$dir"
    assert_exit "rc for --as $o" 0 "$RC"
    assert_match "recorded" "^outcome: $o\$" "$(cat "$dir/20260101-m.md")"
    n=$((n+1))
  done
}

# AC: an issue whose outcome is superseded identifies the issue that supersedes
# it. The spec states that as a property of the record, so the record is not
# permitted to contradict it and be reported afterwards.
case_transition_close_as_duplicate_requires_a_superseding_issue() {
  local dir before
  dir=$(empty_dir transition_dup_missing)
  transition_issue "$dir" 20260101-n 30 open "" ""
  before="$(cat "$dir/20260101-n.md")"
  run_transition close 20260101-n --as duplicate --dir "$dir"
  assert_exit "rc" 1 "$RC"
  assert_nonempty "explains" "$ERR"
  assert_eq "nothing written" "$before" "$(cat "$dir/20260101-n.md")"
}

# AC: the same close is accepted once the record names its superseding issue.
case_transition_close_as_duplicate_accepts_a_named_supersession() {
  local dir
  dir=$(empty_dir transition_dup_named)
  write_issue "$dir" "20260101-o" 'num: 31
title: "T"
status: open
priority: medium
type: issue
filed-by: "filer@example.test"
claimed-by: ""
outcome: ""
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: [20260101-p]
  part-of: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  run_transition close 20260101-o --as duplicate --dir "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "superseded" '^outcome: duplicate$' "$(cat "$dir/20260101-o.md")"
}

# AC: reopening a finished issue returns it to not-started and preserves its
# outcome, so the reason it was previously finished survives the reopen.
case_transition_reopen_preserves_the_outcome() {
  local dir out
  dir=$(empty_dir transition_reopen)
  transition_issue "$dir" 20260101-h 8 closed "someone@example.test" "wontfix"
  run_transition reopen 20260101-h --dir "$dir"
  assert_exit "rc" 0 "$RC"
  out="$(cat "$dir/20260101-h.md")"
  assert_match "back to not-started" '^status: open$'    "$out"
  assert_match "the reason survives" '^outcome: wontfix$' "$out"
}

# AC: finishing an issue that was previously finished and reopened replaces the
# earlier outcome with the current one.
case_transition_reclosing_replaces_the_earlier_outcome() {
  local dir
  dir=$(empty_dir transition_reclose)
  transition_issue "$dir" 20260101-i 9 open "" "wontfix"
  run_transition close 20260101-i --dir "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "replaced" '^outcome: done$' "$(cat "$dir/20260101-i.md")"
}

# AC: a developer can release an issue they are not going to get to.
case_transition_release_empties_the_holder() {
  local dir
  dir=$(empty_dir transition_release)
  transition_issue "$dir" 20260101-j 10 open "$TEST_IDENTITY" ""
  run_transition release 20260101-j --dir "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "unheld" '^claimed-by: ""$' "$(cat "$dir/20260101-j.md")"
}

# AC: claiming an issue another developer holds is refused unless overridden.
# Releasing one is the same act reached another way — without the same gate,
# release-then-claim would take an issue over with no override at all.
case_transition_release_refuses_an_issue_another_holds() {
  local dir
  dir=$(empty_dir transition_release_other)
  transition_issue "$dir" 20260101-k 11 open "someone@example.test" ""
  run_transition release 20260101-k --dir "$dir"
  assert_exit "rc" 5 "$RC"
  assert_match "names the holder" 'someone@example\.test' "$ERR"
  run_transition release 20260101-k --force --dir "$dir"
  assert_exit "rc with --force" 0 "$RC"
  assert_match "released" '^claimed-by: ""$' "$(cat "$dir/20260101-k.md")"
}

# AC: every transition works identically whether the collection lives on the
# working branch or on a designated shared branch.
#
#   Without this the placement criterion is met by construction rather than by
#   evidence: under the default placement the door is inert, so every other
#   transition case above would pass whether the door worked or not. Here the
#   edit has to reach a branch the working tree is not on, and the commit that
#   carries it has to name the verb.
case_transition_lands_at_a_configured_destination() {
  local repo body dest_file subject
  repo="$(placement_repo transition_placement jim/issues)"
  body="$(fixture transition_placement_body.md 'body')"
  run_new_in "$repo" --reviewed --slug 20260101-remote --num 77 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "Remote" --priority medium --labels x \
    --origin conversation --body-file "$body"
  assert_exit "filing landed" 0 "$RC"

  OUT="$(cd "$repo" && env "${identity_env[@]}" \
    bash "$SCRIPT_TRANSITION" claim 20260101-remote 2>"$TMP_BASE/.err")"
  RC=$?
  ERR="$(cat "$TMP_BASE/.err")"
  assert_exit "transition rc" 0 "$RC"

  assert_eq "nothing landed on the working branch" "no" \
    "$([[ -e "$repo/docs/issues/20260101-remote.md" ]] && echo yes || echo no)"

  dest_file="$(git -C "$repo" cat-file -p \
    refs/heads/jim/issues:docs/issues/20260101-remote.md 2>/dev/null)"
  assert_match "the holder reached the destination" \
    "^claimed-by: \"$TEST_IDENTITY\"\$" "$dest_file"

  subject="$(git -C "$repo" log -1 --format='%s' refs/heads/jim/issues)"
  assert_match "the commit names the verb" 'claim' "$subject"
}

# AC: a developer can claim, release, start, close and reopen an issue through
# a single command each — a verb outside that set is a usage error.
case_transition_refuses_an_unknown_verb() {
  local dir
  dir="$(transition_dir transition_bad_verb)"
  run_transition frobnicate 42 --dir "$dir"
  assert_exit "rc" 2 "$RC"
  assert_nonempty "explains" "$ERR"
}

# AC: each verb acts on one named issue, so a verb with no issue named is a
# usage error rather than a transition of something unspecified.
case_transition_refuses_a_missing_id() {
  local dir
  dir="$(transition_dir transition_no_id)"
  run_transition claim --dir "$dir"
  assert_exit "rc" 2 "$RC"
}

# AC: ids resolve only against the collection, never composed into a path from
# raw input.
case_transition_refuses_an_invalid_id() {
  local dir
  dir="$(transition_dir transition_bad_id)"
  run_transition claim '../escape' --dir "$dir"
  assert_exit "rc" 1 "$RC"
  assert_nonempty "explains" "$ERR"
}

# AC: an id naming no issue in the collection is refused rather than created.
case_transition_refuses_an_unknown_issue() {
  local dir
  dir="$(transition_dir transition_absent)"
  run_transition claim 20260101-nosuch --dir "$dir"
  assert_exit "rc" 1 "$RC"
}

# AC: a developer names an issue the way the rest of the surface does — by its
# display ordinal as well as its slug.
case_transition_resolves_an_issue_by_ordinal() {
  local dir
  dir="$(transition_dir transition_by_num)"
  run_transition claim 42 --dir "$dir"
  assert_exit "rc" 0 "$RC"
}

# AC: every transition updates the issue's last-modified stamp and refreshes
# the collection index.
case_transition_stamps_and_reindexes() {
  local dir before after
  dir="$(transition_dir transition_stamp)"
  before="$(grep '^updated:' "$dir/20260101-target.md")"
  run_transition claim 20260101-target --dir "$dir"
  assert_exit "rc" 0 "$RC"
  after="$(grep '^updated:' "$dir/20260101-target.md")"
  assert_eq "the stamp moved" "no" "$([[ "$before" == "$after" ]] && echo yes || echo no)"
  assert_eq "the index was regenerated" "yes" \
    "$([[ -f "$dir/INDEX.md" ]] && echo yes || echo no)"
}

# AC: when the developer's identity cannot be determined from the environment,
# a transition is refused — every transition records or acts under one.
case_transition_refuses_without_an_identity() {
  local repo
  repo="$(identity_repo transition_no_identity)"
  write_issue "$repo" "20260101-target" 'num: 42
title: "Target"
status: open
priority: medium'
  OUT="$(cd "$repo" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    bash "$SCRIPT_TRANSITION" claim 20260101-target --dir "$repo" 2>"$TMP_BASE/.err")"
  RC=$?
  ERR="$(cat "$TMP_BASE/.err")"
  assert_exit "rc" 1 "$RC"
  assert_nonempty "explains" "$ERR"
}

# ─── Section: migrate.sh schema — the collection conversion (preview) ───────

# schema_repo <name> — a git repo holding a committed issue collection, every
# file created by a known author so the filer derivation has a commit to find.
schema_repo() {
  local d
  d="$(empty_dir "$1")"
  git init -q "$d"
  git -C "$d" config user.name "Test Filer"
  git -C "$d" config user.email "filer@example.test"
  mkdir -p "$d/docs/issues"
  printf '%s' "$d"
}

# schema_commit <repo> <slug> <frontmatter> — add one issue and commit it, so
# the file has a creating commit.
schema_commit() {
  local repo="$1" slug="$2" fm="$3"
  write_issue "$repo/docs/issues" "$slug" "$fm"
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" commit -q -m "file $slug" >/dev/null 2>&1
}

# AC: the filer of an existing issue is recovered from the collection's own
# history rather than assigned by default.
case_migrate_schema_recovers_the_filer_from_history() {
  local repo
  repo="$(schema_repo migrate_schema_filer)"
  schema_commit "$repo" "20260101-one" 'title: "One"
status: open
priority: low'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues
  assert_exit "rc" 0 "$RC"
  assert_match "filer recovered" 'filer@example\.test' "$OUT"
}

# AC: recovering historical filers records them in the project's current form,
# so a converted issue and a newly filed one agree about who someone is. The
# conversion is one-shot over the whole collection, so a form applied to only
# one of the two write paths would be baked in permanently.
case_migrate_schema_records_the_configured_form() {
  local repo
  repo="$(schema_repo migrate_schema_form)"
  git -C "$repo" config user.email '1234+Dev@users.noreply.github.com'
  schema_commit "$repo" "20260101-one" 'title: "One"
status: open
priority: low'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues
  assert_exit "rc" 0 "$RC"
  assert_match "recorded as the account name" '(^|[^.@])dev([^a-z]|$)' "$OUT"
  assert_eq "not the raw relay address" "no" \
    "$(printf '%s' "$OUT" | grep -q 'users\.noreply' && echo yes || echo no)"
}

# AC: a conversion running under an explicit config reads that config's form,
# not the ambient project's — the recovered filer is a recorded identity like
# any other and resolves through the same configuration.
case_migrate_schema_honors_an_explicit_config_for_the_form() {
  local repo cfg
  repo="$(schema_repo migrate_schema_form_cfg)"
  git -C "$repo" config user.email '1234+dev@users.noreply.github.com'
  schema_commit "$repo" "20260101-one" 'title: "One"
status: open
priority: low'
  cfg=$(fixture migrate-identity-email.toml 'identity_scheme = "email"')
  run_in "$repo" "$SCRIPT_MIGRATE" -c "$cfg" schema docs/issues
  assert_exit "rc" 0 "$RC"
  assert_match "the whole address is recorded" 'users\.noreply\.github\.com' "$OUT"
}

# AC: existing finished issues are recorded as completed.
case_migrate_schema_records_closed_issues_as_done() {
  local repo
  repo="$(schema_repo migrate_schema_done)"
  schema_commit "$repo" "20260101-shut" 'title: "Shut"
status: closed
priority: low'
  schema_commit "$repo" "20260101-live" 'title: "Live"
status: open
priority: low'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues
  assert_exit "rc" 0 "$RC"
  assert_match "the finished issue gains an outcome" '20260101-shut.*done' "$OUT"
  assert_eq "the unfinished one does not" "no" \
    "$(printf '%s' "$OUT" | grep -E '20260101-live.*done' >/dev/null && echo yes || echo no)"
}

# AC: the conversion previews what it will change before changing anything.
case_migrate_schema_preview_writes_nothing() {
  local repo before after
  repo="$(schema_repo migrate_schema_readonly)"
  schema_commit "$repo" "20260101-untouched" 'title: "Untouched"
status: open
priority: low'
  before="$(cat "$repo/docs/issues/20260101-untouched.md")"
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues
  assert_exit "rc" 0 "$RC"
  after="$(cat "$repo/docs/issues/20260101-untouched.md")"
  assert_eq "the issue file is byte-identical" "$before" "$after"
  assert_match "a plan hash is offered" 'PLAN-HASH:' "$OUT"
}

# AC: every issue in the existing collection carries the new fields after a
# one-time conversion — one already carrying them is not converted twice.
case_migrate_schema_skips_an_already_converted_issue() {
  local repo
  repo="$(schema_repo migrate_schema_idempotent)"
  schema_commit "$repo" "20260101-ready" 'title: "Ready"
status: open
priority: low
type: issue
filed-by: "someone@example.test"
claimed-by: ""
outcome: ""'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues
  assert_exit "rc" 0 "$RC"
  assert_match "reported as already converted" 'skip' "$OUT"
}

# AC: if the filer of any issue cannot be recovered, the conversion reports
# every such issue. An uncommitted file has no creating commit to read.
case_migrate_schema_reports_an_unrecoverable_filer() {
  local repo
  repo="$(schema_repo migrate_schema_unresolved)"
  schema_commit "$repo" "20260101-committed" 'title: "Committed"
status: open
priority: low'
  write_issue "$repo/docs/issues" "20260101-uncommitted" 'title: "Uncommitted"
status: open
priority: low'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues
  assert_match "the unrecoverable one is named" '20260101-uncommitted' "$OUT"
  assert_match "and marked as such" 'unresolved' "$OUT"
}

# AC: a recorded identity can never introduce additional fields into the issue
# record, whatever the environment supplied. A filer read out of history is a
# recorded identity too, so it clears the same gate the emitter's does.
case_migrate_schema_refuses_an_unrecordable_derived_filer() {
  local repo
  repo="$(schema_repo migrate_schema_bad_filer)"
  git -C "$repo" config user.email "dev${LINE_SEP}@example.test"
  schema_commit "$repo" "20260101-tainted" 'title: "Tainted"
status: open
priority: low'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues
  assert_match "not treated as recoverable" 'unresolved' "$OUT"
  assert_eq "the unrecordable value is not echoed back" "no" \
    "$(printf '%s' "$OUT" | grep -q "$LINE_SEP" && echo yes || echo no)"
}

# AC: every issue in the existing collection carries the new fields after a
# one-time conversion.
case_migrate_schema_apply_writes_the_fields() {
  local repo out
  repo="$(schema_repo migrate_schema_apply)"
  schema_commit "$repo" "20260101-conv" 'title: "Conv"
status: closed
priority: low
labels: [x]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues --apply
  assert_exit "rc" 0 "$RC"
  out="$(cat "$repo/docs/issues/20260101-conv.md")"
  assert_match "kind"        '^type: issue$'                  "$out"
  assert_match "filer"       '^filed-by: "filer@example.test"$' "$out"
  assert_match "unheld"      '^claimed-by: ""$'               "$out"
  assert_match "finished"    '^outcome: done$'                "$out"
  assert_match "no umbrella" '^  part-of: \[\]$'              "$out"
  assert_eq "the index was regenerated" "yes" \
    "$([[ -f "$repo/docs/issues/INDEX.md" ]] && echo yes || echo no)"
}

# AC: an issue that never has been finished carries no outcome.
case_migrate_schema_apply_leaves_an_open_issue_without_an_outcome() {
  local repo
  repo="$(schema_repo migrate_schema_apply_open)"
  schema_commit "$repo" "20260101-live2" 'title: "Live"
status: open
priority: low
labels: [x]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues --apply
  assert_exit "rc" 0 "$RC"
  assert_match "no outcome" '^outcome: ""$' "$(cat "$repo/docs/issues/20260101-live2.md")"
}

# AC: the conversion previews what it will change before changing anything —
# an apply whose preview has gone stale is refused rather than applied.
case_migrate_schema_apply_refuses_a_stale_plan() {
  local repo before
  repo="$(schema_repo migrate_schema_drift)"
  schema_commit "$repo" "20260101-drifted" 'title: "Drifted"
status: open
priority: low
labels: [x]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  before="$(cat "$repo/docs/issues/20260101-drifted.md")"
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues --apply --expect WRONGHASH
  assert_exit "rc" 3 "$RC"
  assert_eq "nothing written" "$before" "$(cat "$repo/docs/issues/20260101-drifted.md")"
}

# AC: the conversion is one-time — running it twice converts nothing the second
# time rather than layering a second copy of the fields.
case_migrate_schema_apply_is_idempotent() {
  local repo first second
  repo="$(schema_repo migrate_schema_twice)"
  schema_commit "$repo" "20260101-once" 'title: "Once"
status: open
priority: low
labels: [x]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues --apply
  first="$(cat "$repo/docs/issues/20260101-once.md")"
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues --apply
  assert_exit "rc" 0 "$RC"
  second="$(cat "$repo/docs/issues/20260101-once.md")"
  assert_eq "the second run changed nothing" "$first" "$second"
  assert_eq "exactly one kind field" "1" \
    "$(printf '%s\n' "$second" | grep -c '^type:')"
}

# AC: if the filer of any issue cannot be recovered, the conversion reports
# every such issue and refuses to run rather than substituting a placeholder.
# The refusal is whole-run: an issue whose filer WAS recoverable is left
# untouched too, so the collection is never half-attributed.
case_migrate_schema_apply_refuses_when_any_filer_is_unrecoverable() {
  local repo before
  repo="$(schema_repo migrate_schema_refuse)"
  schema_commit "$repo" "20260101-known" 'title: "Known"
status: open
priority: low
labels: [x]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  write_issue "$repo/docs/issues" "20260101-ghostly" 'title: "Ghostly"
status: open
priority: low
labels: [x]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  before="$(cat "$repo/docs/issues/20260101-known.md")"
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues --apply
  assert_exit "rc" 1 "$RC"
  assert_match "names the unrecoverable issue" '20260101-ghostly' "$ERR"
  assert_eq "the recoverable one is untouched too" "$before" \
    "$(cat "$repo/docs/issues/20260101-known.md")"
}

# AC: the conversion reports EVERY such issue, not the first one it meets — a
# run fixed one at a time would take as many passes as there are problems.
case_migrate_schema_refusal_names_every_unrecoverable_issue() {
  local repo
  repo="$(schema_repo migrate_schema_refuse_all)"
  schema_commit "$repo" "20260101-anchor" 'title: "Anchor"
status: open
priority: low
labels: [x]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
origin: "conversation"'
  write_issue "$repo/docs/issues" "20260101-ghost1" 'title: "G1"
status: open
priority: low
labels: [x]'
  write_issue "$repo/docs/issues" "20260101-ghost2" 'title: "G2"
status: open
priority: low
labels: [x]'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues --apply
  assert_exit "rc" 1 "$RC"
  assert_match "first named"  '20260101-ghost1' "$ERR"
  assert_match "second named" '20260101-ghost2' "$ERR"
}

# AC: the preview reports what it would change — including what it cannot —
# without refusing, since a preview runs no conversion to refuse.
case_migrate_schema_preview_reports_without_refusing() {
  local repo
  repo="$(schema_repo migrate_schema_preview_unresolved)"
  write_issue "$repo/docs/issues" "20260101-ghost3" 'title: "G3"
status: open
priority: low
labels: [x]'
  run_in "$repo" "$SCRIPT_MIGRATE" schema docs/issues
  assert_exit "rc" 0 "$RC"
  assert_match "reported" '20260101-ghost3' "$OUT"
}

# AC: the filer is recovered from the collection's own history — where there is
# no history to read, the conversion says so rather than reporting every issue
# as individually unrecoverable.
case_migrate_schema_refuses_outside_a_work_tree() {
  local dir
  dir=$(empty_dir migrate_schema_no_repo)
  write_issue "$dir" "20260101-orphan" 'title: "Orphan"
status: open
priority: low'
  run_migrate schema "$dir"
  assert_exit "rc" 1 "$RC"
  assert_nonempty "explains why" "$ERR"
}

# ─── Section: render.sh — the new fields and the third lifecycle state ──────

# AC: a developer can see who filed an issue, and an issue's holder is
# distinct from its lifecycle state.
case_render_show_displays_the_new_fields() {
  local dir
  dir=$(empty_dir render_show_fields)
  write_issue "$dir" "20260101-shown" 'num: 7
title: "Shown"
status: active
priority: high
type: issue
filed-by: "filer@example.test"
claimed-by: "holder@example.test"
outcome: ""'
  run_render show 20260101-shown "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "kind"   'type: issue'                 "$OUT"
  assert_match "filer"  'filed-by: filer@example.test' "$OUT"
  assert_match "holder" 'claimed-by: holder@example.test' "$OUT"
}

# AC: an issue that has ever been finished carries an outcome — show surfaces
# it, so a reopened issue reads as one rather than as untouched work.
case_render_show_displays_the_outcome_of_a_reopened_issue() {
  local dir
  dir=$(empty_dir render_show_reopened)
  write_issue "$dir" "20260101-again" 'num: 8
title: "Again"
status: open
priority: low
type: issue
filed-by: "filer@example.test"
claimed-by: ""
outcome: wontfix'
  run_render show 20260101-again "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "outcome shown" 'outcome: wontfix' "$OUT"
}

# AC: an issue can be in one of three states: not started, underway, or
# finished. The underway state is selectable like the other two.
case_render_list_accepts_active_as_a_filter() {
  local dir
  dir=$(empty_dir render_list_active)
  write_issue "$dir" "20260101-underway" 'num: 1
title: "Underway"
status: active
priority: high'
  write_issue "$dir" "20260101-idle" 'num: 2
title: "Idle"
status: open
priority: low'
  run_render list active "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "the underway issue is listed" 'Underway' "$OUT"
  assert_eq "the not-started issue is not" "no" \
    "$(printf '%s' "$OUT" | grep -q 'Idle' && echo yes || echo no)"
}

# AC: an underway issue is unfinished work, so the default view — which hides
# only finished issues — shows it.
case_render_default_list_shows_an_underway_issue() {
  local dir
  dir=$(empty_dir render_list_default_active)
  write_issue "$dir" "20260101-underway2" 'num: 1
title: "Underway"
status: active
priority: high'
  run_render list "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "listed by default" 'Underway' "$OUT"
}

# ─── Section: index.sh — schema integrity warnings ──────────────────────────

# AC: the collection index reports any finished issue carrying no outcome.
case_index_warns_a_closed_issue_with_no_outcome() {
  local dir
  dir=$(empty_dir index_no_outcome)
  write_issue "$dir" "20260101-done" 'title: "Done"
status: closed
type: issue
outcome: ""'
  run_index "$dir"
  assert_exit "rc" 0 "$RC"
  assert_match "warned" 'closed.*no outcome' "$(cat "$dir/INDEX.md")"
}

# AC: an issue that has ever been finished carries an outcome; one that never
# has carries none. An open issue without an outcome is the ordinary case and
# must not be warned about.
case_index_stays_quiet_on_an_open_issue_with_no_outcome() {
  local dir
  dir=$(empty_dir index_open_no_outcome)
  write_issue "$dir" "20260101-open" 'title: "Open"
status: open
type: issue
outcome: ""'
  run_index "$dir"
  assert_eq "no outcome warning" "no" \
    "$(grep -q 'no outcome' "$dir/INDEX.md" && echo yes || echo no)"
}

# AC: an open issue carrying an outcome has been finished and reopened — a
# representable state, not a defect, so it draws no warning.
case_index_stays_quiet_on_a_reopened_issue() {
  local dir
  dir=$(empty_dir index_reopened)
  write_issue "$dir" "20260101-reopened" 'title: "Reopened"
status: open
type: issue
outcome: wontfix'
  run_index "$dir"
  assert_eq "no warning" "no" \
    "$(grep -qE 'no outcome|unrecognized outcome' "$dir/INDEX.md" && echo yes || echo no)"
}

# AC: the collection index reports any issue whose outcome is not a recognized
# value.
case_index_warns_an_unrecognized_outcome() {
  local dir
  dir=$(empty_dir index_bad_outcome)
  write_issue "$dir" "20260101-typo" 'title: "Typo"
status: closed
type: issue
outcome: donw'
  run_index "$dir"
  assert_match "warned" 'unrecognized outcome' "$(cat "$dir/INDEX.md")"
}

# AC: the collection index reports any issue whose kind is not a recognized
# value.
case_index_warns_an_unrecognized_kind() {
  local dir
  dir=$(empty_dir index_bad_type)
  write_issue "$dir" "20260101-epik" 'title: "Epik"
status: open
type: epik
outcome: ""'
  run_index "$dir"
  assert_match "warned" 'unrecognized type' "$(cat "$dir/INDEX.md")"
}

# AC: an umbrella is a recognized kind and draws no warning.
case_index_accepts_an_epic_as_a_kind() {
  local dir
  dir=$(empty_dir index_epic_ok)
  write_issue "$dir" "20260101-umbrella" 'title: "Umbrella"
status: open
type: epic
outcome: ""'
  run_index "$dir"
  assert_eq "no kind warning" "no" \
    "$(grep -q 'unrecognized type' "$dir/INDEX.md" && echo yes || echo no)"
}

# AC: the collection index reports any issue whose umbrella reference is not a
# recognized value — here, one naming an umbrella the collection does not hold.
case_index_warns_an_umbrella_that_does_not_exist() {
  local dir
  dir=$(empty_dir index_dangling_umbrella)
  write_issue "$dir" "20260101-member" 'title: "Member"
status: open
type: issue
outcome: ""
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: [20260101-ghost]'
  run_index "$dir"
  assert_match "warned" 'names an umbrella not in the collection' "$(cat "$dir/INDEX.md")"
}

# AC: umbrella membership is stored on the member only — an umbrella that
# exists needs no reciprocal entry, so a resolvable membership is silent.
case_index_stays_quiet_on_a_single_sided_membership() {
  local dir
  dir=$(empty_dir index_single_sided)
  write_issue "$dir" "20260101-umbrella2" 'title: "Umbrella"
status: open
type: epic
outcome: ""'
  write_issue "$dir" "20260101-member2" 'title: "Member"
status: open
type: issue
outcome: ""
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: [20260101-umbrella2]'
  run_index "$dir"
  assert_eq "no membership warning" "no" \
    "$(grep -qE 'names an umbrella not in the collection|no inverse' "$dir/INDEX.md" \
       && echo yes || echo no)"
}

# AC: integrity reports identify offending issues without reproducing their
# body content — the value a schema warning names goes through the same row
# sanitizer its sibling warnings use, so a control byte or an unbounded value
# cannot ride into the committed index.
case_index_schema_warnings_clear_the_sanitizer() {
  local dir long idx
  dir=$(empty_dir index_schema_warn_sanitize)
  long="$(printf 'A%.0s' $(seq 1 600))"
  printf -- '---\ntitle: "X"\nstatus: closed\ntype: issue\noutcome: "donw%s%sTAILMARK"\n---\n' \
    "$(printf '\033[31m\r')" "$long" > "$dir/20260101-nasty.md"
  run_index "$dir"
  idx="$(cat "$dir/INDEX.md")"
  assert_match "warned" 'unrecognized outcome' "$idx"
  if grep -q $'\033' "$dir/INDEX.md"; then
    CURRENT_FAILED=1
    echo "    [an escape byte reached the committed index]"
  fi
  if grep -q $'\r' "$dir/INDEX.md"; then
    CURRENT_FAILED=1
    echo "    [a carriage return reached the committed index]"
  fi
  if echo "$idx" | grep -q 'TAILMARK'; then
    CURRENT_FAILED=1
    echo "    [an unbounded outcome value landed whole in the index]"
  fi
}

# ─── Section: new.sh — filer identity and the new schema fields ─────────────

# AC: a newly filed issue has its filer recorded automatically, without the
# developer supplying it.
case_new_records_the_filer_from_the_environment() {
  local dir b
  dir=$(empty_dir new_filer)
  b=$(fixture new_filer_body.md 'body')
  run_new --dir "$dir" --slug "20260101-filer" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "T" --priority low --labels x --origin conversation --body-file "$b"
  assert_exit "rc" 0 "$RC"
  assert_match "filer recorded" "filed-by: \"$TEST_IDENTITY\"" "$(cat "$dir/20260101-filer.md")"
}

# AC: an issue records what kind of record it is, who currently holds it, and —
# once finished at least once — the outcome. A new issue is unheld, has never
# been finished, and belongs to no umbrella.
case_new_defaults_kind_and_leaves_holder_and_outcome_empty() {
  local dir b out
  dir=$(empty_dir new_defaults)
  b=$(fixture new_defaults_body.md 'body')
  run_new --dir "$dir" --slug "20260101-defaults" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "T" --priority low --labels x --origin conversation --body-file "$b"
  assert_exit "rc" 0 "$RC"
  out="$(cat "$dir/20260101-defaults.md")"
  assert_match "kind defaults to issue" '^type: issue$'   "$out"
  assert_match "unheld"                  '^claimed-by: ""$' "$out"
  assert_match "never finished"          '^outcome: ""$'    "$out"
  assert_match "no umbrella"             '^  part-of: \[\]$' "$out"
}

# AC: when the developer's identity cannot be determined from the environment,
# filing an issue is refused and nothing is written.
case_new_refuses_a_filing_with_no_identity() {
  local repo b
  repo="$(identity_repo new_no_identity)"
  b=$(fixture new_no_identity_body.md 'body')
  run_new_unidentified "$repo" --dir "$repo/issues" --slug "20260101-none" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "T" --priority low --labels x --origin conversation --body-file "$b"
  assert_exit "rc" 1 "$RC"
  assert_eq "nothing written" "no" \
    "$([[ -e "$repo/issues/20260101-none.md" ]] && echo yes || echo no)"
}

# AC: the refusal is reported as a fixed reason that names the missing identity
# and carries no issue content.
case_new_identity_refusal_carries_no_issue_content() {
  local repo b
  repo="$(identity_repo new_no_identity_quiet)"
  b=$(fixture new_no_identity_quiet_body.md 'body')
  run_new_unidentified "$repo" --dir "$repo/issues" --slug "20260101-quiet" --num 1 \
    --created "2026-01-01T00:00:00Z" --updated "2026-01-01T00:00:00Z" \
    --title "Confidential customer escalation" --priority low --labels x \
    --origin conversation --body-file "$b"
  assert_exit "rc" 1 "$RC"
  assert_nonempty "a reason was given" "$ERR"
  assert_eq "the title is not echoed back" "no" \
    "$(printf '%s' "$ERR" | grep -q 'Confidential' && echo yes || echo no)"
}

# ─── Section: migrate.sh identity — argument surface ────────────────────────

# AC: the two rewrite operations differ only in where the new value comes from,
# so one verb carries both. Neither mode named is a usage error, not a default:
# guessing which rewrite an operator meant is the one thing a destructive
# whole-collection operation must never do.
case_migrate_identity_usage_requires_a_mode() {
  local repo
  repo="$(schema_repo migrate_identity_nomode)"
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues
  assert_exit "rc" 2 "$RC"
  assert_match "names the modes it accepts" 'renormalize' "$ERR"
}

# AC: both modes named is a usage error too — a remap and a re-normalization
# compute the new value differently, so a run asking for both has no answer.
case_migrate_identity_usage_refuses_both_modes() {
  local repo
  repo="$(schema_repo migrate_identity_bothmodes)"
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize \
    --from 'old@example.test' --to 'new@example.test'
  assert_exit "rc" 2 "$RC"
  assert_match "names the conflict" 'renormalize' "$ERR"
}

# AC: an explicit replacement supplies the old and new values together. Half a
# mapping cannot be applied, and applying it as though the missing half were
# empty would rewrite every identity in the collection.
case_migrate_identity_usage_requires_both_halves_of_a_remap() {
  local repo
  repo="$(schema_repo migrate_identity_halfremap)"
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --from 'old@example.test'
  assert_exit "from-only rc" 2 "$RC"
  assert_match "names the missing half" '\-\-to' "$ERR"
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --to 'new@example.test'
  assert_exit "to-only rc" 2 "$RC"
  assert_match "names the missing half" '\-\-from' "$ERR"
}

# AC: a usage error writes nothing.
case_migrate_identity_usage_error_writes_nothing() {
  local repo before after
  repo="$(schema_repo migrate_identity_nowrite)"
  schema_commit "$repo" "20260101-one" 'title: "One"
status: open
priority: low'
  before="$(find "$repo/docs/issues" -type f | sort | xargs cksum 2>/dev/null)"
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues
  after="$(find "$repo/docs/issues" -type f | sort | xargs cksum 2>/dev/null)"
  assert_exit "rc" 2 "$RC"
  assert_eq "collection untouched" "$before" "$after"
}

# AC: the verb is discoverable from the script's own help.
case_migrate_identity_usage_is_documented_in_help() {
  run_migrate help
  assert_exit "rc" 0 "$RC"
  assert_match "identity verb documented" 'migrate\.sh identity' "$OUT"
  assert_match "renormalize mode documented" 'renormalize' "$OUT"
  assert_match "remap mode documented" 'from' "$OUT"
}

# ─── Section: migrate.sh identity — re-normalization ────────────────────────

# identity_collection <name> — a git repo holding a converted collection, so
# every issue already records the two identity fields the rewrites operate on.
identity_collection() {
  local d
  d="$(schema_repo "$1")"
  printf '%s' "$d"
}

# recorded_issue <repo> <slug> <filed-by> <claimed-by> — one converted issue.
recorded_issue() {
  local repo="$1" slug="$2" filer="$3" holder="${4:-}"
  write_issue "$repo/docs/issues" "$slug" "title: \"$slug\"
status: open
priority: low
type: issue
filed-by: \"$filer\"
claimed-by: \"$holder\"
outcome: \"\"
labels: []"
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" commit -q -m "file $slug" >/dev/null 2>&1
}

# AC: an operator can re-apply the project's current form to identities
# recorded under a previous one, without supplying any mapping.
case_migrate_identity_renormalize_plans_the_current_form() {
  local repo
  repo="$(identity_collection migrate_identity_renorm)"
  recorded_issue "$repo" "20260101-one" '1234+Dev@users.noreply.github.com'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "rc" 0 "$RC"
  assert_match "the record is planned" '20260101-one' "$OUT"
  assert_match "the field is named"    'filed-by' "$OUT"
  assert_match "the new value is shown" '> dev' "$OUT"
  assert_match "counted as a rewrite"  '1 to rewrite' "$OUT"
}

# AC: a record the current form already agrees with is left alone.
case_migrate_identity_renormalize_leaves_a_conforming_record_alone() {
  local repo
  repo="$(identity_collection migrate_identity_renorm_noop)"
  recorded_issue "$repo" "20260101-two" 'dev'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "rc" 0 "$RC"
  assert_match "reported unchanged" 'unchanged  20260101-two' "$OUT"
  assert_match "counted as unchanged" '0 to rewrite · 1 unchanged' "$OUT"
}

# AC: the rewrite covers every field that records an identity, including the
# holder — which no derivation can recover.
case_migrate_identity_renormalize_covers_the_holder_field() {
  local repo
  repo="$(identity_collection migrate_identity_renorm_holder)"
  recorded_issue "$repo" "20260101-held" 'dev' '5678+Alice@users.noreply.github.com'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "rc" 0 "$RC"
  assert_match "the holder field is named" 'claimed-by' "$OUT"
  assert_match "the holder's new value" '> alice' "$OUT"
}

# AC: the operation shows what it would change and writes nothing until the
# operator explicitly applies it.
case_migrate_identity_renormalize_preview_writes_nothing() {
  local repo before after
  repo="$(identity_collection migrate_identity_renorm_readonly)"
  recorded_issue "$repo" "20260101-one" '1234+Dev@users.noreply.github.com'
  before="$(find "$repo/docs/issues" -type f | sort | xargs cksum 2>/dev/null)"
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  after="$(find "$repo/docs/issues" -type f | sort | xargs cksum 2>/dev/null)"
  assert_exit "rc" 0 "$RC"
  assert_eq "collection untouched" "$before" "$after"
  assert_match "a plan hash is offered" 'PLAN-HASH: [0-9]+' "$OUT"
}

# AC: a preview that resolves identities through the alias mapping discloses
# that it did so, whether a mapping was found at all, and how many records it
# altered — so an operator sees the transform before approving it rather than
# inferring it from the result afterwards.
case_migrate_identity_renormalize_discloses_the_alias_mapping() {
  local repo
  repo="$(identity_collection migrate_identity_renorm_disclose)"
  recorded_issue "$repo" "20260101-one" 'old@personal.example'
  recorded_issue "$repo" "20260101-two" 'someone@example.test'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "no-mapping rc" 0 "$RC"
  assert_match "says a mapping resolves identities" '[Aa]lias mapping' "$OUT"
  assert_match "says none was found" 'none found' "$OUT"

  printf 'Dev <1234+dev@users.noreply.github.com> <old@personal.example>\n' \
    > "$repo/.mailmap"
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" commit -q -m "map" >/dev/null 2>&1
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "mapping rc" 0 "$RC"
  assert_match "names the mapping in play" 'Alias mapping \(\.mailmap\)' "$OUT"
  assert_match "counts the records it altered" '1 record' "$OUT"
  assert_match "the mapped record takes the mapped form" '> dev' "$OUT"
}

# ─── Section: migrate.sh identity — explicit remap ──────────────────────────

# AC: an operator can replace one recorded identity with another across the
# whole collection, supplying the old and new values explicitly.
case_migrate_identity_remap_plans_the_supplied_replacement() {
  local repo
  repo="$(identity_collection migrate_identity_remap)"
  recorded_issue "$repo" "20260101-one" 'old@example.test'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues \
    --from 'old@example.test' --to 'new@example.test'
  assert_exit "rc" 0 "$RC"
  assert_match "the supplied mapping is shown" 'from  old@example\.test' "$OUT"
  assert_match "the record is planned" '20260101-one' "$OUT"
  assert_match "the new value is shown" '> new@example\.test' "$OUT"
  assert_match "counted as a rewrite" '1 to rewrite' "$OUT"
}

# AC: the replacement covers every field that records an identity, including
# the holder — which no derivation can recover, and which is therefore the
# reason an explicit mapping is required rather than a re-derivation.
case_migrate_identity_remap_covers_the_holder_field() {
  local repo
  repo="$(identity_collection migrate_identity_remap_holder)"
  recorded_issue "$repo" "20260101-held" 'old@example.test' 'old@example.test'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues \
    --from 'old@example.test' --to 'new@example.test'
  assert_exit "rc" 0 "$RC"
  assert_match "the filer field is named"  'filed-by' "$OUT"
  assert_match "the holder field is named" 'claimed-by' "$OUT"
  assert_match "both fields counted" '2 to rewrite' "$OUT"
}

# AC: only the named identity is replaced — a remap is a mapping the operator
# supplied, not a rewrite of everyone.
case_migrate_identity_remap_leaves_other_identities_alone() {
  local repo
  repo="$(identity_collection migrate_identity_remap_others)"
  recorded_issue "$repo" "20260101-one"   'old@example.test'
  recorded_issue "$repo" "20260101-other" 'someone@example.test'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues \
    --from 'old@example.test' --to 'new@example.test'
  assert_exit "rc" 0 "$RC"
  assert_match "the other record is untouched" 'unchanged  20260101-other' "$OUT"
  assert_match "one rewrite, one unchanged" '1 to rewrite · 1 unchanged' "$OUT"
}

# AC: two addresses differing only in case are one address, so an operator is
# not asked to guess how a value was typed when it was recorded.
case_migrate_identity_remap_matches_without_case() {
  local repo
  repo="$(identity_collection migrate_identity_remap_case)"
  recorded_issue "$repo" "20260101-one" 'Old@Example.Test'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues \
    --from 'old@example.test' --to 'new@example.test'
  assert_exit "rc" 0 "$RC"
  assert_match "the record is planned" '1 to rewrite' "$OUT"
}

# AC: a value that cannot be recorded is refused before anything is planned,
# and the refusal names neither the value nor any issue content.
case_migrate_identity_remap_refuses_an_unrecordable_replacement() {
  local repo
  repo="$(identity_collection migrate_identity_remap_bad)"
  recorded_issue "$repo" "20260101-one" 'old@example.test'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues \
    --from 'old@example.test' --to "new${LINE_SEP}@secret-corp.example"
  assert_exit "rc" 2 "$RC"
  assert_nonempty "a reason was given" "$ERR"
  assert_eq "the rejected value is not echoed back" "no" \
    "$(printf '%s' "$ERR" | grep -q 'secret-corp' && echo yes || echo no)"
}

# AC: every recorded identity is lower case, whichever path wrote it — an
# explicit replacement is still a recorded identity.
case_migrate_identity_remap_records_the_replacement_lower_cased() {
  local repo
  repo="$(identity_collection migrate_identity_remap_lower)"
  recorded_issue "$repo" "20260101-one" 'old@example.test'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues \
    --from 'old@example.test' --to 'New@Example.Test'
  assert_exit "rc" 0 "$RC"
  assert_match "lower-cased" '> new@example\.test' "$OUT"
}

# ─── Section: migrate.sh identity — ambiguity ───────────────────────────────

# AC: an operation that plans a change across the whole collection refuses the
# entire run when two distinct source addresses within it would record as the
# same identity. Discovering the merge months later in a by-person view that
# looks perfectly plausible is the alternative.
case_migrate_identity_ambiguous_refuses_the_whole_run() {
  local repo
  repo="$(identity_collection migrate_identity_ambig)"
  printf 'identity_scheme = "local"\nidentity_domain = "company.example"\n' \
    > "$repo/jimconf.toml"
  recorded_issue "$repo" "20260101-one" 'alice@company.example'
  recorded_issue "$repo" "20260101-two" 'alice+ops@company.example'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "rc" 2 "$RC"
  assert_match "names the first record"  '20260101-one' "$ERR"
  assert_match "names the second record" '20260101-two' "$ERR"
  assert_match "names the value they would share" 'alice' "$ERR"
}

# AC: an ambiguity refusal names the colliding records and the single value
# they would both produce, rather than the two source addresses. It stays
# actionable, because each named record carries its own address — without
# copying contributor addresses into a channel whose audience may be wider than
# the collection's.
case_migrate_identity_ambiguous_refusal_withholds_the_source_addresses() {
  local repo
  repo="$(identity_collection migrate_identity_ambig_quiet)"
  printf 'identity_scheme = "local"\nidentity_domain = "company.example"\n' \
    > "$repo/jimconf.toml"
  recorded_issue "$repo" "20260101-one" 'alice@company.example'
  recorded_issue "$repo" "20260101-two" 'alice+ops@company.example'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "rc" 2 "$RC"
  assert_eq "the source addresses are not echoed back" "no" \
    "$(printf '%s' "$ERR" | grep -q 'company\.example' && echo yes || echo no)"
}

# AC: the refusal is of the entire run — nothing is written.
case_migrate_identity_ambiguous_writes_nothing() {
  local repo before after
  repo="$(identity_collection migrate_identity_ambig_nowrite)"
  printf 'identity_scheme = "local"\nidentity_domain = "company.example"\n' \
    > "$repo/jimconf.toml"
  recorded_issue "$repo" "20260101-one" 'alice@company.example'
  recorded_issue "$repo" "20260101-two" 'alice+ops@company.example'
  before="$(find "$repo/docs/issues" -type f | sort | xargs cksum 2>/dev/null)"
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize --apply
  after="$(find "$repo/docs/issues" -type f | sort | xargs cksum 2>/dev/null)"
  assert_exit "rc" 2 "$RC"
  assert_eq "collection untouched" "$before" "$after"
}

# AC: two source addresses differing only in case are one address, not a
# collision — a contributor is never refused for having typed their own address
# two ways.
case_migrate_identity_ambiguous_case_only_difference_is_not_a_collision() {
  local repo
  repo="$(identity_collection migrate_identity_ambig_case)"
  recorded_issue "$repo" "20260101-one" 'Dev@Example.Test'
  recorded_issue "$repo" "20260101-two" 'DEV@EXAMPLE.TEST'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "rc" 0 "$RC"
  assert_match "both are planned" '2 to rewrite' "$OUT"
  assert_match "none is ambiguous" '0 ambiguous' "$OUT"
}

# AC: a record already recorded in the current form is not a second person
# colliding with the record that is about to reach it. A collection part-way
# through a form change holds exactly that pair, and refusing it would make
# re-normalization impossible in the one situation it exists for.
case_migrate_identity_ambiguous_an_already_recorded_form_is_not_a_collision() {
  local repo
  repo="$(identity_collection migrate_identity_ambig_partial)"
  recorded_issue "$repo" "20260101-one" '1234+dev@users.noreply.github.com'
  recorded_issue "$repo" "20260101-two" 'dev'
  run_in "$repo" "$SCRIPT_MIGRATE" identity docs/issues --renormalize
  assert_exit "rc" 0 "$RC"
  assert_match "one rewrite, one unchanged" '1 to rewrite · 1 unchanged' "$OUT"
  assert_match "none is ambiguous" '0 ambiguous' "$OUT"
}

# ─── Section: identity.sh — ambient identity resolution ─────────────────────

# identity_repo <name> [email] — a git repo with user.email set only when one
# is supplied, so the absent case is genuinely absent.
identity_repo() {
  local d
  d="$(empty_dir "$1")"
  git init -q "$d"
  git -C "$d" config user.name tester
  [[ $# -ge 2 ]] && git -C "$d" config user.email "$2"
  printf '%s' "$d"
}

# U+2028 line separator — a character that disturbs a record while carrying
# none of the bytes an obvious list of known-bad input would name.
LINE_SEP="$(printf '\xe2\x80\xa8')"

# run_identity <repo> <args...> — invoke identity.sh from inside <repo> with
# global and system git config neutralized, so only the repo's own setting is
# in play and an unset user.email cannot be answered by the machine's.
run_identity() {
  local repo="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    bash "$SCRIPT_IDENTITY" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# AC: a newly filed issue has its filer recorded automatically, without the
# developer supplying it.
case_identity_resolve_reports_the_configured_address() {
  local repo
  repo="$(identity_repo identity_ok 'dev@example.com')"
  run_identity "$repo" resolve
  assert_exit "rc" 0 "$RC"
  assert_eq "address on stdout" "dev@example.com" "$OUT"
}

# AC: only addresses actually issued by the relay service are extracted. This
# address wears the shape of one — a numeric id, a separator, a noreply
# host — without being issued by the service the project recognizes, so it is
# recorded whole. Recognition is a statement about the service, not about the
# shape of an address.
case_identity_resolve_records_a_relay_lookalike_whole() {
  local repo
  repo="$(identity_repo identity_noreply '1234+dev@users.noreply.example.com')"
  run_identity "$repo" resolve
  assert_exit "rc" 0 "$RC"
  assert_eq "address on stdout" "1234+dev@users.noreply.example.com" "$OUT"
}

# AC: when the developer's identity cannot be determined from the environment,
# filing is refused and nothing is written.
case_identity_resolve_refuses_an_absent_identity() {
  local repo
  repo="$(identity_repo identity_absent)"
  run_identity "$repo" resolve
  assert_exit "rc" 1 "$RC"
  assert_eq "no identity on stdout" "" "$OUT"
}

# AC: an empty configured value is absent, not malformed — there is no identity
# to record either way.
case_identity_resolve_treats_an_empty_value_as_absent() {
  local repo
  repo="$(identity_repo identity_empty '')"
  run_identity "$repo" resolve
  assert_exit "rc" 1 "$RC"
  assert_eq "no identity on stdout" "" "$OUT"
}

# AC: a recorded identity can never introduce additional fields into the issue
# record, whatever the environment supplied. A configured address accepts
# embedded newlines, so this is the demonstrated injection, not a hypothetical.
case_identity_resolve_refuses_a_newline_bearing_value() {
  local repo
  repo="$(identity_repo identity_newline "$(printf 'dev@example.com\nstatus: closed')")"
  run_identity "$repo" resolve
  assert_exit "rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
}

# AC: an identity value that cannot be recorded safely is refused exactly as a
# missing one is. A Unicode line separator carries no byte any obvious list of
# known-bad characters would name, so accepting only a bounded set is what
# makes unanticipated input fail closed rather than pass through.
case_identity_resolve_fails_closed_on_unlisted_input() {
  local repo
  repo="$(identity_repo identity_failclosed "dev${LINE_SEP}@example.com")"
  run_identity "$repo" resolve
  assert_exit "rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
}

# AC: the refusal is reported as a fixed reason that names the missing identity
# and carries no issue content — in particular not the rejected value.
case_identity_resolve_refusal_withholds_the_rejected_value() {
  local repo
  repo="$(identity_repo identity_quiet "dev${LINE_SEP}@secret-corp.example")"
  run_identity "$repo" resolve
  assert_exit "rc" 2 "$RC"
  assert_nonempty "a reason was given" "$ERR"
  assert_eq "the rejected value is not echoed back" "no" \
    "$(printf '%s' "$ERR" | grep -q 'secret-corp' && echo yes || echo no)"
}

# AC: alias resolution applies everywhere an identity is recorded. The
# environment's identity is read through the same definition as an
# already-obtained one, so the path that files an issue and the path that
# recovers a historical filer cannot disagree about who someone is.
case_identity_resolve_applies_the_configured_form() {
  local repo
  repo="$(identity_repo identity_resolve_form '1234+Dev@users.noreply.github.com')"
  printf 'identity_scheme = "github"\n' > "$repo/jimconf.toml"
  run_identity "$repo" resolve
  assert_exit "rc" 0 "$RC"
  assert_eq "account name" "dev" "$OUT"
}

# AC: an address the mapping names resolves through it when read from the
# environment, not only when supplied.
case_identity_resolve_reads_through_the_mapping() {
  local repo
  repo="$(identity_repo identity_resolve_mapped 'old@personal.example')"
  printf 'identity_scheme = "github"\n' > "$repo/jimconf.toml"
  printf 'Dev <1234+dev@users.noreply.github.com> <old@personal.example>\n' \
    > "$repo/.mailmap"
  run_identity "$repo" resolve
  assert_exit "rc" 0 "$RC"
  assert_eq "recorded as the mapped form" "dev" "$OUT"
}

# AC: every recorded identity is lower case, whatever the environment supplied.
case_identity_resolve_lower_cases_the_environment_value() {
  local repo
  repo="$(identity_repo identity_resolve_case 'Dev@Example.COM')"
  run_identity "$repo" resolve
  assert_exit "rc" 0 "$RC"
  assert_eq "lower-cased" "dev@example.com" "$OUT"
}

# AC: a form that cannot be applied refuses every operation that would record
# an identity — filing included, not only a supplied value.
case_identity_resolve_refuses_a_form_it_cannot_apply() {
  local repo
  repo="$(identity_repo identity_resolve_nodomain 'alice@company.example')"
  printf 'identity_scheme = "local"\n' > "$repo/jimconf.toml"
  run_identity "$repo" resolve
  assert_exit "rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
  assert_match "names the setting to supply" 'identity_domain' "$ERR"
}

# ─── Section: identity.sh — the configured form ─────────────────────────────

# AC: a project selects one of three forms, and the selection belongs to the
# project. An absent setting takes the documented default, which is what keeps
# every zero-config project working without configuring anything.
case_identity_scheme_absent_takes_the_default() {
  local repo
  repo="$(identity_repo identity_scheme_absent 'dev@example.com')"
  run_identity "$repo" resolve
  assert_exit "rc" 0 "$RC"
  assert_eq "address on stdout" "dev@example.com" "$OUT"
}

# AC: each form in the closed set is selectable.
case_identity_scheme_recognized_values_are_accepted() {
  local repo
  repo="$(identity_repo identity_scheme_ok 'dev@example.com')"
  printf 'identity_scheme = "email"\n' > "$repo/jimconf.toml"
  run_identity "$repo" resolve
  assert_exit "email rc" 0 "$RC"
  printf 'identity_scheme = "github"\n' > "$repo/jimconf.toml"
  run_identity "$repo" resolve
  assert_exit "github rc" 0 "$RC"
}

# AC: an unrecognized form is refused rather than quietly treated as the
# default. A mistyped setting would otherwise record every identity in the
# collection under a form the project did not choose, on the strength of a
# message nobody has to read.
case_identity_scheme_unrecognized_value_refuses() {
  local repo
  repo="$(identity_repo identity_scheme_bad 'dev@example.com')"
  printf 'identity_scheme = "gitlab"\n' > "$repo/jimconf.toml"
  run_identity "$repo" resolve
  assert_exit "rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
  assert_match "names the setting" 'identity_scheme' "$ERR"
}

# AC: the refusal names the setting to supply, so it is actionable without
# reading the source. It carries no identity value.
case_identity_scheme_refusal_names_the_accepted_forms() {
  local repo
  repo="$(identity_repo identity_scheme_quiet 'dev@secret-corp.example')"
  printf 'identity_scheme = "gitlab"\n' > "$repo/jimconf.toml"
  run_identity "$repo" resolve
  assert_exit "rc" 2 "$RC"
  assert_match "names the accepted forms" 'email' "$ERR"
  assert_eq "no identity in the refusal" "no" \
    "$(printf '%s' "$ERR" | grep -q 'secret-corp' && echo yes || echo no)"
}

# AC: the form is read through the project's own resolver, so a run under an
# explicit config reads that config's form rather than the ambient project's.
case_identity_scheme_honors_an_explicit_config() {
  local repo cfg
  repo="$(identity_repo identity_scheme_cfg 'dev@example.com')"
  cfg=$(fixture identity-scheme.toml 'identity_scheme = "gitlab"')
  run_identity "$repo" -c "$cfg" resolve
  assert_exit "rc" 2 "$RC"
  assert_match "names the setting" 'identity_scheme' "$ERR"
}

# ─── Section: identity.sh — normalize ───────────────────────────────────────

# AC: every recorded identity is lower case, under every form — including the
# form that extracts nothing. A form is defined by what it extracts, not by
# whether it transforms, and leaving one path where case survives re-opens the
# identity split the whole family exists to close.
case_identity_normalize_case_folds_under_every_form() {
  local repo
  repo="$(identity_repo identity_norm_case 'dev@example.com')"
  printf 'identity_scheme = "email"\n' > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'Dev@Example.COM'
  assert_exit "email rc" 0 "$RC"
  assert_eq "email lower-cased" "dev@example.com" "$OUT"
  printf 'identity_scheme = "github"\n' > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'Dev@Example.COM'
  assert_exit "github rc" 0 "$RC"
  assert_eq "github lower-cased" "dev@example.com" "$OUT"
}

# AC: an already-lower-case value is carried through unchanged.
case_identity_normalize_case_leaves_a_lower_value_alone() {
  local repo
  repo="$(identity_repo identity_norm_case_noop 'dev@example.com')"
  run_identity "$repo" normalize 'dev@example.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "unchanged" "dev@example.com" "$OUT"
}

# AC: an empty value is absent, not malformed — there is no identity to record
# either way, matching what resolve reports for the same condition.
case_identity_normalize_case_treats_empty_as_absent() {
  local repo
  repo="$(identity_repo identity_norm_case_empty 'dev@example.com')"
  run_identity "$repo" normalize ''
  assert_exit "rc" 1 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
}

# AC: an identity that cannot be recorded safely is refused here exactly as it
# is when read from the environment — normalization is a transformation on a
# recordable value, never a way around the gate.
case_identity_normalize_case_refuses_an_unrecordable_value() {
  local repo
  repo="$(identity_repo identity_norm_case_bad 'dev@example.com')"
  run_identity "$repo" normalize "$(printf 'dev@example.com\nstatus: closed')"
  assert_exit "rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
}

# AC: the form governs normalization too, so a configuration that cannot select
# one refuses rather than transforming under a form nobody chose.
case_identity_normalize_case_refuses_an_unrecognized_form() {
  local repo
  repo="$(identity_repo identity_norm_case_form 'dev@example.com')"
  printf 'identity_scheme = "gitlab"\n' > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'Dev@Example.COM'
  assert_exit "rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
  assert_match "names the setting" 'identity_scheme' "$ERR"
}

# ─── Section: identity.sh — forge relay extraction ──────────────────────────

# github_repo <name> — an identity fixture whose project selects the default
# forge-relay form explicitly, so a case reads as a statement about that form
# rather than about whichever default happens to be current.
github_repo() {
  local d
  d="$(identity_repo "$1" 'dev@example.com')"
  printf 'identity_scheme = "github"\n' > "$d/jimconf.toml"
  printf '%s' "$d"
}

# AC: an address issued by a forge's private-relay service is recorded as the
# account name it carries, not as the full address.
case_identity_normalize_relay_extracts_the_account_name() {
  local repo
  repo="$(github_repo identity_relay_modern)"
  run_identity "$repo" normalize '1234+dev@users.noreply.github.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "account name" "dev" "$OUT"
}

# AC: every relay form the forge issues records as the same account name. The
# older form carries the account name alone with no numeric id and no separator
# at all, so a contributor whose account predates the id-bearing form is not
# recorded differently from anyone else.
case_identity_normalize_relay_extracts_both_forge_forms_alike() {
  local repo modern legacy
  repo="$(github_repo identity_relay_both)"
  run_identity "$repo" normalize '1234+dev@users.noreply.github.com'
  modern="$OUT"
  run_identity "$repo" normalize 'dev@users.noreply.github.com'
  legacy="$OUT"
  assert_exit "legacy rc" 0 "$RC"
  assert_eq "legacy account name" "dev" "$legacy"
  assert_eq "both forms agree"    "$modern" "$legacy"
}

# AC: a relay address is recognized however it was typed — the same address in
# mixed case is the same address, and recording it as a full address while the
# lower-case spelling records as a handle is the split this form exists to close.
case_identity_normalize_relay_recognizes_a_mixed_case_address() {
  local repo
  repo="$(github_repo identity_relay_mixedcase)"
  run_identity "$repo" normalize '1234+Dev@Users.NoReply.GitHub.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "account name" "dev" "$OUT"
}

# AC: ordinary mail that merely resembles a relay address — an address carrying
# a tag on its mailbox — is recorded unchanged. Keying on the separator rather
# than the service would rewrite an unrelated address into whatever followed it.
case_identity_normalize_relay_leaves_ordinary_tagged_mail_alone() {
  local repo
  repo="$(github_repo identity_relay_tagged)"
  run_identity "$repo" normalize '1234+dev@example.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "unchanged" "1234+dev@example.com" "$OUT"
}

# AC: only addresses actually issued by the relay service are extracted. The
# service suffix is matched exactly, so an address that merely contains it —
# as a subdomain, or with the real domain appended after it — is not a relay
# address and is recorded whole.
case_identity_normalize_relay_matches_the_service_suffix_exactly() {
  local repo
  repo="$(github_repo identity_relay_suffix)"
  run_identity "$repo" normalize 'dev@users.noreply.github.com.example.com'
  assert_exit "trailing-domain rc" 0 "$RC"
  assert_eq "trailing domain unchanged" \
    "dev@users.noreply.github.com.example.com" "$OUT"
  run_identity "$repo" normalize 'dev@sub.users.noreply.github.com'
  assert_eq "subdomain unchanged" "dev@sub.users.noreply.github.com" "$OUT"
}

# AC: a relay address that yields no account name is recorded unchanged, never
# as an empty identity.
case_identity_normalize_relay_keeps_an_address_yielding_no_account() {
  local repo
  repo="$(github_repo identity_relay_empty)"
  run_identity "$repo" normalize '1234+@users.noreply.github.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "address kept whole" "1234+@users.noreply.github.com" "$OUT"
}

# AC: one form applies no extraction at all, recording the whole address rather
# than a part of it — a relay address included.
case_identity_normalize_relay_is_inert_under_the_no_extraction_form() {
  local repo
  repo="$(identity_repo identity_relay_email 'dev@example.com')"
  printf 'identity_scheme = "email"\n' > "$repo/jimconf.toml"
  run_identity "$repo" normalize '1234+Dev@users.noreply.github.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "whole address, lower-cased" \
    "1234+dev@users.noreply.github.com" "$OUT"
}

# ─── Section: identity.sh — organization-local extraction ───────────────────

# local_repo <name> <domain> — an identity fixture whose project selects the
# organization-local form over <domain>.
local_repo() {
  local d
  d="$(identity_repo "$1" 'dev@example.com')"
  printf 'identity_scheme = "local"\nidentity_domain = "%s"\n' "$2" \
    > "$d/jimconf.toml"
  printf '%s' "$d"
}

# AC: under the organization-local form, an address inside the project's
# configured domain is recorded as the account part preceding that domain.
case_identity_normalize_local_extracts_the_account_part() {
  local repo
  repo="$(local_repo identity_local_inside company.example)"
  run_identity "$repo" normalize 'alice@company.example'
  assert_exit "rc" 0 "$RC"
  assert_eq "account part" "alice" "$OUT"
}

# AC: a tag appended to a mailbox is not part of the recorded account, so one
# mailbox is one identity. This is the opposite half of the address from the
# one the relay rule discards — same character, two meanings.
case_identity_normalize_local_drops_a_mailbox_tag() {
  local repo
  repo="$(local_repo identity_local_tag company.example)"
  run_identity "$repo" normalize 'alice+deploys@company.example'
  assert_exit "rc" 0 "$RC"
  assert_eq "tag dropped" "alice" "$OUT"
}

# AC: domain comparison ignores case, so an address is inside the configured
# domain regardless of how either was typed.
case_identity_normalize_local_compares_the_domain_without_case() {
  local repo
  repo="$(local_repo identity_local_case COMPANY.Example)"
  run_identity "$repo" normalize 'Alice@Company.EXAMPLE'
  assert_exit "rc" 0 "$RC"
  assert_eq "account part" "alice" "$OUT"
}

# AC: an address outside the configured domain is recorded as the form below
# would record it — so an organization member who also commits through a forge's
# web interface does not split into two identities.
case_identity_normalize_local_falls_through_to_the_relay_rule() {
  local repo
  repo="$(local_repo identity_local_outside company.example)"
  run_identity "$repo" normalize '1234+alice@users.noreply.github.com'
  assert_exit "relay rc" 0 "$RC"
  assert_eq "relay account name" "alice" "$OUT"
  run_identity "$repo" normalize 'alice@other.example'
  assert_exit "unrelated rc" 0 "$RC"
  assert_eq "unrelated address kept whole" "alice@other.example" "$OUT"
}

# AC: the configured domain names exactly one domain, so an address in a
# subdomain of it is outside it and records as the form below would.
case_identity_normalize_local_treats_a_subdomain_as_outside() {
  local repo
  repo="$(local_repo identity_local_subdomain company.example)"
  run_identity "$repo" normalize 'alice@eu.company.example'
  assert_exit "rc" 0 "$RC"
  assert_eq "kept whole" "alice@eu.company.example" "$OUT"
}

# AC: an address that yields no account part is recorded unchanged, never as an
# empty identity — the same rule the relay form applies.
case_identity_normalize_local_keeps_an_address_yielding_no_account() {
  local repo
  repo="$(local_repo identity_local_empty company.example)"
  run_identity "$repo" normalize '+deploys@company.example'
  assert_exit "rc" 0 "$RC"
  assert_eq "address kept whole" "+deploys@company.example" "$OUT"
}

# AC: the form below extracts nothing from an internal address — organization-
# local extraction is what this form adds, and the forms below it do not.
case_identity_normalize_local_extraction_is_absent_from_lower_forms() {
  local repo
  repo="$(github_repo identity_local_not_in_github)"
  run_identity "$repo" normalize 'alice@company.example'
  assert_exit "rc" 0 "$RC"
  assert_eq "kept whole" "alice@company.example" "$OUT"
}

# ─── Section: identity.sh — the domain setting ──────────────────────────────

# AC: selecting the organization-local form without configuring a domain
# refuses every operation that would record an identity, and the refusal names
# the setting to supply. A warning would be the weaker choice — a project would
# go on recording under a form it cannot apply.
case_identity_domain_absent_under_local_refuses() {
  local repo
  repo="$(identity_repo identity_domain_absent 'dev@example.com')"
  printf 'identity_scheme = "local"\n' > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'alice@company.example'
  assert_exit "rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
  assert_match "names the setting to supply" 'identity_domain' "$ERR"
}

# AC: the domain setting names exactly one domain. A value naming several is
# refused rather than partially honored — extracting across a union nobody has
# checked for uniqueness is where one person's account silently becomes
# another's.
case_identity_domain_naming_several_refuses() {
  local repo
  repo="$(identity_repo identity_domain_several 'dev@example.com')"
  printf 'identity_scheme = "local"\nidentity_domain = "a.example,b.example"\n' \
    > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'alice@a.example'
  assert_exit "comma-separated rc" 2 "$RC"
  assert_match "names the setting" 'identity_domain' "$ERR"
  printf 'identity_scheme = "local"\nidentity_domain = "a.example b.example"\n' \
    > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'alice@a.example'
  assert_exit "space-separated rc" 2 "$RC"
}

# AC: the configured domain clears a positively enumerated character set before
# it is used for anything. A setting carrying pattern characters must never
# widen what the form extracts — the domain reaches a shell match, so a glob
# would otherwise make every address inside it.
case_identity_domain_outside_the_charset_refuses() {
  local repo
  repo="$(identity_repo identity_domain_charset 'dev@example.com')"
  printf 'identity_scheme = "local"\nidentity_domain = "*.example"\n' \
    > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'alice@anything.example'
  assert_exit "glob rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
  printf 'identity_scheme = "local"\nidentity_domain = "company.example/../x"\n' \
    > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'alice@company.example'
  assert_exit "slash rc" 2 "$RC"
}

# AC: a refusal caused by a setting names the setting, never the value it
# carried.
case_identity_domain_refusal_withholds_the_value() {
  local repo
  repo="$(identity_repo identity_domain_quiet 'dev@example.com')"
  printf 'identity_scheme = "local"\nidentity_domain = "secret-corp.example*"\n' \
    > "$repo/jimconf.toml"
  run_identity "$repo" normalize 'alice@company.example'
  assert_exit "rc" 2 "$RC"
  assert_nonempty "a reason was given" "$ERR"
  assert_eq "the rejected value is not echoed back" "no" \
    "$(printf '%s' "$ERR" | grep -q 'secret-corp' && echo yes || echo no)"
}

# AC: the domain clears its gate before it is used for anything — and the forms
# below organization-local never use it, so a project that has not selected
# that form is not refused over a setting that has no effect on it.
case_identity_domain_is_unused_by_the_lower_forms() {
  local repo
  repo="$(identity_repo identity_domain_unused 'dev@example.com')"
  printf 'identity_scheme = "github"\nidentity_domain = "*.example"\n' \
    > "$repo/jimconf.toml"
  run_identity "$repo" normalize '1234+dev@users.noreply.github.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "account name" "dev" "$OUT"
}

# ─── Section: identity.sh — alias resolution ────────────────────────────────

# AC: an address the project's version control maps to another is recorded as
# the form of the address it maps to, not the form of the address that was
# written — so a mapping reaches every form, including those that extract.
case_identity_mailmap_records_the_form_of_the_mapped_address() {
  local repo
  repo="$(github_repo identity_mailmap_mapped)"
  printf 'Dev <1234+dev@users.noreply.github.com> <old@personal.example>\n' \
    > "$repo/.mailmap"
  run_identity "$repo" normalize 'old@personal.example'
  assert_exit "rc" 0 "$RC"
  assert_eq "recorded as the mapped form" "dev" "$OUT"
}

# AC: alias resolution runs before extraction. A mapping is keyed on addresses,
# so extracting first leaves nothing for it to match — a mapping keyed on a
# relay address would never fire, and the contributor it exists to merge would
# stay split.
case_identity_mailmap_resolves_before_extraction() {
  local repo
  repo="$(github_repo identity_mailmap_ordering)"
  printf 'Alice <alice@company.example> <1234+olduser@users.noreply.github.com>\n' \
    > "$repo/.mailmap"
  run_identity "$repo" normalize '1234+olduser@users.noreply.github.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "mapped, not extracted" "alice@company.example" "$OUT"
}

# AC: an address the mapping does not name is carried through unchanged.
case_identity_mailmap_carries_an_unmapped_address_through() {
  local repo
  repo="$(github_repo identity_mailmap_unmapped)"
  printf 'Dev <1234+dev@users.noreply.github.com> <old@personal.example>\n' \
    > "$repo/.mailmap"
  run_identity "$repo" normalize 'someone@example.com'
  assert_exit "rc" 0 "$RC"
  assert_eq "unchanged" "someone@example.com" "$OUT"
}

# AC: a contributor is never refused, or split, for having typed their own
# address two ways — the mapping lookup ignores case.
case_identity_mailmap_matches_without_case() {
  local repo
  repo="$(github_repo identity_mailmap_case)"
  printf 'Dev <1234+dev@users.noreply.github.com> <old@personal.example>\n' \
    > "$repo/.mailmap"
  run_identity "$repo" normalize 'OLD@Personal.Example'
  assert_exit "rc" 0 "$RC"
  assert_eq "recorded as the mapped form" "dev" "$OUT"
}

# AC: a project that carries no mapping is unaffected — resolution composes as
# an unconditional filter rather than a present/absent branch.
case_identity_mailmap_absent_mapping_changes_nothing() {
  local repo
  repo="$(github_repo identity_mailmap_none)"
  run_identity "$repo" normalize 'Dev@Example.COM'
  assert_exit "rc" 0 "$RC"
  assert_eq "lower-cased only" "dev@example.com" "$OUT"
}

# AC: a mapped address is judged as a recordable identity in its own right —
# the mapping is a source of identities, not a way around the gate.
case_identity_mailmap_result_clears_the_charset_gate() {
  local repo
  repo="$(github_repo identity_mailmap_gate)"
  printf 'Dev <dev%s@example.com> <old@personal.example>\n' "$LINE_SEP" \
    > "$repo/.mailmap"
  run_identity "$repo" normalize 'old@personal.example'
  assert_exit "rc" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
}

# ─── Section: identity.sh — option-shaped identities ────────────────────────

# AC: an identity that looks like a command-line option is a value. The
# accepted character set admits a leading hyphen deliberately, because real
# addresses carry one, so the gate is not what keeps such a value from being
# read as an option — nothing downstream can be assumed to do it either. This
# is a permanent property of the alias-resolution call rather than a defect
# fixed once: the door reopens every time that call is touched.
case_identity_option_shaped_values_are_read_as_data() {
  local repo v
  repo="$(github_repo identity_option_shaped)"
  for v in '--help' '-x' '--stdin' '-'; do
    run_identity "$repo" normalize "$v"
    assert_exit "rc for $v" 0 "$RC"
    assert_eq "value carried through: $v" "$v" "$OUT"
  done
  # An option-shaped value carrying a character the set does not admit is
  # refused by the gate, as any other unrecordable value is. The two mechanisms
  # are complementary: the gate refuses what it can, and carrying the value as
  # data covers what the gate must admit.
  run_identity "$repo" normalize '--exec=id'
  assert_exit "rc for --exec=id" 2 "$RC"
  assert_eq "nothing on stdout" "" "$OUT"
}

# AC: an option-shaped identity resolves through the mapping like any other
# value — carried as data means reaching the lookup, not bypassing it.
case_identity_option_shaped_value_still_resolves_through_the_mapping() {
  local repo
  repo="$(github_repo identity_option_shaped_mapped)"
  printf 'Dev <1234+dev@users.noreply.github.com> <-x>\n' > "$repo/.mailmap"
  run_identity "$repo" normalize '-x'
  assert_exit "rc" 0 "$RC"
  assert_eq "recorded as the mapped form" "dev" "$OUT"
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
