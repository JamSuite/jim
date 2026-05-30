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
