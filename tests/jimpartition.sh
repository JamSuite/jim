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

# git_init <name> — create an empty git work tree under TMP_BASE/<name>; print
#   the absolute repo dir. Companion to repo_add for scan fixtures that need
#   real file content.
git_init() {
  local dir="$TMP_BASE/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s' "$dir"
}

# repo_add <dir> <relpath> <content> — write <content> to <dir>/<relpath> and
#   stage it (git ls-files then lists it — no commit needed).
repo_add() {
  local dir="$1" rel="$2" content="$3"
  mkdir -p "$dir/$(dirname "$rel")"
  printf '%s\n' "$content" > "$dir/$rel"
  git -C "$dir" add "$rel"
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

# ─── Section: ingest cases (Task 3) ──────────────────────────────────────────

# AC #2/#17: valid tracked edges pass the gate and are emitted with the channel
# arg; a directory endpoint (a Go package dir containing tracked files) is
# accepted. Output is sorted; no HYGIENE on clean input.
case_jimpartition_ingest_valid_edges() {
  local dir raw
  dir=$(git_repo ing_valid pkg/a/f1.go pkg/a/f2.go pkg/b/g.go main.go)
  raw=$(fixture ing_valid_raw.txt "$(printf 'pkg/a/f1.go\tpkg/b/g.go\nmain.go\tpkg/a')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tmain.go\tpkg/a\timports\nEDGE\tpkg/a/f1.go\tpkg/b/g.go\timports')"
  assert_eq "sorted edges, no hygiene" "$expected" "$OUT"
}

# AC #2: duplicate raw lines collapse to a single EDGE.
case_jimpartition_ingest_dedup() {
  local dir raw
  dir=$(git_repo ing_dedup pkg/a.go pkg/b.go)
  raw=$(fixture ing_dedup_raw.txt "$(printf 'pkg/a.go\tpkg/b.go\npkg/a.go\tpkg/b.go\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  assert_eq "deduped" "$(printf 'EDGE\tpkg/a.go\tpkg/b.go\timports')" "$OUT"
}

# AC #2: a per-edge 3rd field overrides the CLI channel for that edge (the
# deps_command output contract's optional channel), leaving 2-field lines on
# the CLI channel.
case_jimpartition_ingest_per_edge_channel() {
  local dir raw
  dir=$(git_repo ing_chan pkg/a.go pkg/b.go)
  raw=$(fixture ing_chan_raw.txt "$(printf 'pkg/a.go\tpkg/b.go\tevents\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tpkg/a.go\tpkg/b.go\tevents\nEDGE\tpkg/a.go\tpkg/b.go\timports')"
  assert_eq "per-edge + cli channel" "$expected" "$OUT"
}

# AC #17 / sec Finding 3: absolute and '..'-segment endpoints are rejected by
# the valid-relpath boundary, counted as unsafe-path, and never emitted.
case_jimpartition_ingest_unsafe_path() {
  local dir raw
  dir=$(git_repo ing_unsafe pkg/a.go pkg/b.go)
  raw=$(fixture ing_unsafe_raw.txt "$(printf '/etc/passwd\tpkg/b.go\npkg/a.go\t../escape\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tpkg/a.go\tpkg/b.go\timports\nHYGIENE\tunsafe-path\t2')"
  assert_eq "unsafe dropped + counted" "$expected" "$OUT"
}

# AC #17 / sec Finding 3: an endpoint outside the tracked set is dropped and
# counted as untracked — scanning can't be scoped to a path that isn't real.
case_jimpartition_ingest_untracked() {
  local dir raw
  dir=$(git_repo ing_untracked pkg/a.go pkg/b.go)
  raw=$(fixture ing_untracked_raw.txt "$(printf 'pkg/a.go\tnope/missing.go\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tpkg/a.go\tpkg/b.go\timports\nHYGIENE\tuntracked\t1')"
  assert_eq "untracked dropped + counted" "$expected" "$OUT"
}

# sec Finding 3: single-field / empty-endpoint lines are malformed; blank lines
# are benign and skipped (not counted).
case_jimpartition_ingest_malformed_and_blank() {
  local dir raw
  dir=$(git_repo ing_malformed pkg/a.go pkg/b.go)
  raw=$(fixture ing_malformed_raw.txt "$(printf 'onlyonefield\n\npkg/a.go\tpkg/b.go\n\t')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\tpkg/a.go\tpkg/b.go\timports\nHYGIENE\tmalformed-line\t2')"
  assert_eq "malformed counted, blanks skipped" "$expected" "$OUT"
}

# sec Finding 3: a control byte in an endpoint is not a tracked path, so the
# edge is dropped (counted, never emitted). The run does not crash.
case_jimpartition_ingest_control_bytes() {
  local dir raw
  dir=$(git_repo ing_ctrl pkg/a.go pkg/b.go)
  raw=$(fixture ing_ctrl_raw.txt "$(printf 'pkg/a.go\tpkg/\x01b.go\npkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" imports
  assert_exit "rc" 0 "$RC"
  assert_match "clean edge emitted" '^EDGE'"$(printf '\t')"'pkg/a\.go'"$(printf '\t')"'pkg/b\.go'"$(printf '\t')"'imports$' "$OUT"
  assert_match "control-byte edge dropped as hygiene" '^HYGIENE' "$OUT"
}

# rc 2 on a non-slug channel argument (the whole invocation is rejected — a
# blueprint/map-recorded name can never inject via the channel arg).
case_jimpartition_ingest_invalid_channel() {
  local dir raw
  dir=$(git_repo ing_badchan pkg/a.go pkg/b.go)
  raw=$(fixture ing_badchan_raw.txt "$(printf 'pkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw" 'BAD.CHAN'
  assert_exit "rc" 2 "$RC"
}

# rc 2 when the raw file is unreadable / missing.
case_jimpartition_ingest_unreadable_file() {
  local dir
  dir=$(git_repo ing_noraw pkg/a.go)
  run_jimpartition_in "$dir" ingest "$dir/does-not-exist.txt" imports
  assert_exit "rc" 2 "$RC"
}

# rc 2 when the channel argument is missing.
case_jimpartition_ingest_missing_channel_arg() {
  local dir raw
  dir=$(git_repo ing_noarg pkg/a.go)
  raw=$(fixture ing_noarg_raw.txt "$(printf 'pkg/a.go\tpkg/b.go')")
  run_jimpartition_in "$dir" ingest "$raw"
  assert_exit "rc" 2 "$RC"
}

# ─── Section: scan cases (Task 4) ────────────────────────────────────────────

# rc 2 when scan runs outside a git work tree.
case_jimpartition_scan_no_git() {
  local dir
  dir=$(empty_dir scan_nogit)
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 2 "$RC"
}

# AC #3: a repo of only unmodeled source is labeled UNMODELED (by language),
# emits no edges, and no CHANNEL — the honest degraded graph. Non-source files
# (manifests, docs) are not counted.
case_jimpartition_scan_unmodeled_only() {
  local dir
  dir=$(git_init scan_unmodeled)
  repo_add "$dir" Foo.java 'class Foo {}'
  repo_add "$dir" Bar.java 'class Bar {}'
  repo_add "$dir" README.md '# docs'
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  assert_match "java unmodeled x2" '^UNMODELED'"$(printf '\t')"'java'"$(printf '\t')"'2$' "$OUT"
  assert_eq "no edges" "0" "$(printf '%s\n' "$OUT" | grep -c '^EDGE' || true)"
  assert_eq "no channel" "0" "$(printf '%s\n' "$OUT" | grep -c '^CHANNEL' || true)"
  assert_eq "md not counted" "0" "$(printf '%s\n' "$OUT" | grep -c 'md' || true)"
}

# AC #2/#3: a mixed repo emits a CHANNEL for the modeled language and an
# UNMODELED fact for the unmodeled source — both coverage signals present.
case_jimpartition_scan_mixed() {
  local dir
  dir=$(git_init scan_mixed)
  repo_add "$dir" go.mod "$(printf 'module example.com/m\n\ngo 1.21')"
  repo_add "$dir" main.go "$(printf 'package main')"
  repo_add "$dir" Extra.java 'class Extra {}'
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  assert_match "go channel scanned 1" '^CHANNEL'"$(printf '\t')"'imports'"$(printf '\t')"'go'"$(printf '\t')"'1$' "$OUT"
  assert_match "java unmodeled 1" '^UNMODELED'"$(printf '\t')"'java'"$(printf '\t')"'1$' "$OUT"
}

# AC #2: Go internal imports (single and block form) resolve to package dirs;
# external imports (fmt) are ignored. CHANNEL counts every scanned .go file.
case_jimpartition_scan_go() {
  local dir
  dir=$(git_init scan_go)
  repo_add "$dir" go.mod "$(printf 'module example.com/proj\n\ngo 1.21')"
  repo_add "$dir" a/main.go "$(printf 'package main\nimport "example.com/proj/lib/foo"')"
  repo_add "$dir" b/x.go "$(printf 'package b\n\nimport (\n\t"example.com/proj/lib/foo"\n\t"fmt"\n)')"
  repo_add "$dir" lib/foo/foo.go 'package foo'
  repo_add "$dir" lib/foo/bar.go 'package foo'
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  local expected
  expected="$(printf 'EDGE\ta/main.go\tlib/foo\timports\nEDGE\tb/x.go\tlib/foo\timports\nCHANNEL\timports\tgo\t4')"
  assert_eq "go edges + channel" "$expected" "$OUT"
}

# sec Finding 7: a go.mod module carrying regex metacharacters fails the charset
# gate, so Go degrades to UNMODELED (no crash, no injected match, no edges).
case_jimpartition_scan_go_metachar_module() {
  local dir
  dir=$(git_init scan_go_meta)
  repo_add "$dir" go.mod "$(printf 'module example.com/pro*j\n\ngo 1.21')"
  repo_add "$dir" main.go "$(printf 'package main\nimport "example.com/pro*j/lib/foo"')"
  repo_add "$dir" lib/foo/foo.go 'package foo'
  run_jimpartition_in "$dir" scan
  assert_exit "rc" 0 "$RC"
  assert_eq "no edges" "0" "$(printf '%s\n' "$OUT" | grep -c '^EDGE' || true)"
  assert_match "go degraded to unmodeled" '^UNMODELED'"$(printf '\t')"'go'"$(printf '\t')" "$OUT"
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
