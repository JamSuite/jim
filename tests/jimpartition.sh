#!/usr/bin/env bash
#
# tests/jimpartition.sh — Tests for skills/partition/scripts/jimpartition.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# HOW TO RUN
#   bash tests/jimpartition.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_jimpartition="$REPO_ROOT/skills/partition/scripts/jimpartition.sh"

# ─── Section: Per-script invokers ────────────────────────────────────────────

# run_jimpartition <args...>
#   Invoke the script-under-test in the CURRENT dir; capture stdout, stderr,
#   and exit code into OUT/ERR/RC. Same shape as run/run_jimfile in siblings.
run_jimpartition() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_jimpartition" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# run_jimpartition_in <dir> <args...>
#   Invoke with CWD set to <dir> (a git work-tree fixture). The scan / ingest /
#   coverage / aggregate verbs read the repo at CWD, so most cases need this.
run_jimpartition_in() {
  local dir="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$dir" && bash "$SCRIPT_jimpartition" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Fixture helpers ────────────────────────────────────────────────

# git_repo <name> <relpath> [<relpath> ...]
#   Create a git work tree under TMP_BASE/<name>, write each <relpath> (content
#   = a single line) and stage it so `git ls-files` lists it. No commit needed —
#   the index is enough for ls-files. Prints the absolute repo dir.
git_repo() {
  local name="$1"; shift
  local dir="$TMP_BASE/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q
  local f
  for f in "$@"; do
    mkdir -p "$dir/$(dirname "$f")"
    printf 'x\n' > "$dir/$f"
    git -C "$dir" add "$f"
  done
  printf '%s' "$dir"
}

# terr_file <dir> <name> <content>
#   Write a territories-file (TAB-separated) into <dir> and print its path.
terr_file() {
  local dir="$1" name="$2" content="$3"
  local path="$dir/$name"
  printf '%s\n' "$content" > "$path"
  printf '%s' "$path"
}

# ─── Section: coverage cases (Task 2) ────────────────────────────────────────

# AC #4: tracked files under no proposed territory are reported, dirname-
# aggregated, with a TOTAL count. Covered files (under a declared territory
# prefix) are excluded via slash-anchored prefix match.
case_jimpartition_coverage_uncovered_and_total() {
  local dir terr
  dir=$(git_repo cov_basic \
    src/foo/a.go src/foo/b.go src/bar/c.go src/uncov/d.go top.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tfoo\tsrc/foo\nGROUP\tbar\tsrc/bar')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'UNCOVERED\t./\t1\nUNCOVERED\tsrc/uncov/\t1\nTOTAL\t2')"
  assert_eq "uncovered dirs + total" "$expected" "$OUT"
}

# AC #4: when every tracked file falls under a declared territory, no UNCOVERED
# dir lines are emitted and TOTAL is 0 (never absent — 0 is an honest answer).
case_jimpartition_coverage_all_covered() {
  local dir terr
  dir=$(git_repo cov_all src/foo/a.go src/foo/b.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tfoo\tsrc/foo')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 0 "$RC"
  assert_eq "total zero" "$(printf 'TOTAL\t0')" "$OUT"
}

# AC #4: multiple uncovered files in one directory aggregate to a single
# UNCOVERED line with the per-directory count (the 039 dirname rule).
case_jimpartition_coverage_dirname_aggregation() {
  local dir terr
  dir=$(git_repo cov_agg src/a.go src/b.go src/c.go lib/keep.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tlib\tlib')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'UNCOVERED\tsrc/\t3\nTOTAL\t3')"
  assert_eq "src aggregates to 3" "$expected" "$OUT"
}

# AC #4: a territory whose path is a prefix STRING but not a slash-anchored
# ancestor does not falsely cover (src2/x is not under src).
case_jimpartition_coverage_slash_anchored() {
  local dir terr
  dir=$(git_repo cov_anchor src/a.go src2/b.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tsrc\tsrc')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'UNCOVERED\tsrc2/\t1\nTOTAL\t1')"
  assert_eq "src2 not covered by src" "$expected" "$OUT"
}

# rc 2 when invoked outside a git work tree (the substrate needs git ls-files).
case_jimpartition_coverage_no_git() {
  local dir terr
  dir=$(empty_dir cov_nogit)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tfoo\tsrc/foo')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 on a malformed territories line — the file is caller-written, so a bad
# line is a caller error (distinct from ingest's HYGIENE counting of untrusted
# extractor output).
case_jimpartition_coverage_malformed_territory_wrongtag() {
  local dir terr
  dir=$(git_repo cov_badtag src/a.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'NOTGROUP\tfoo\tsrc/foo')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 on an unsafe territory path (absolute / '..' segment) — the valid-relpath
# boundary rejects it before any set math.
case_jimpartition_coverage_malformed_territory_unsafe_path() {
  local dir terr
  dir=$(git_repo cov_badpath src/a.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tfoo\t../escape')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 on a non-slug group token.
case_jimpartition_coverage_malformed_territory_badslug() {
  local dir terr
  dir=$(git_repo cov_badslug src/a.go)
  terr=$(terr_file "$dir" territories.tsv "$(printf 'GROUP\tBad_Slug\tsrc')")
  run_jimpartition_in "$dir" coverage "$terr"
  assert_exit "rc" 2 "$RC"
}

# rc 2 when the territories-file argument is missing.
case_jimpartition_coverage_missing_arg() {
  local dir
  dir=$(git_repo cov_noarg src/a.go)
  run_jimpartition_in "$dir" coverage
  assert_exit "rc" 2 "$RC"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# This file works two ways:
#   1. bash tests/jimpartition.sh        → runs only this file's cases (standalone).
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
  if [[ ! -e "$SCRIPT_jimpartition" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_jimpartition — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
