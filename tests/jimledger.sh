#!/usr/bin/env bash
#
# tests/jimledger.sh — Tests for skills/review/scripts/jimledger.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# WHAT THIS FILE TESTS
#   The jimledger.sh build-ledger surface: start / finish / event (append),
#   metrics (git + ledger derived key=value), and files (changed paths).
#   Cases that need a real repo build a throwaway git repo under TMP_BASE via
#   the git_fixture helper — jimledger.sh is the first jim script to read git.
#
# HOW TO RUN
#   bash tests/jimledger.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh     # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_JIMLEDGER="$REPO_ROOT/skills/review/scripts/jimledger.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_jimledger <args...>
#   Invoke jimledger.sh; capture stdout, stderr, exit code into OUT, ERR, RC.
run_jimledger() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_JIMLEDGER" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# git_fixture <relative-name>
#   Create a throwaway git repo under TMP_BASE with a deterministic identity
#   and one initial commit, plus a spec subdir. Print the spec-dir path.
git_fixture() {
  local name="$1"
  local root="$TMP_BASE/$name"
  mkdir -p "$root/spec"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false
  printf 'seed\n' > "$root/seed.txt"
  git -C "$root" add -A
  git -C "$root" commit -q -m "chore: seed"
  printf '%s' "$root/spec"
}

# gledger_commit <repo-root> <prefix> <file> <content>
#   Make a commit in the fixture repo with a conventional-prefix subject.
gledger_commit() {
  local root="$1" prefix="$2" file="$3" content="$4"
  printf '%s\n' "$content" > "$root/$file"
  git -C "$root" add -A
  git -C "$root" commit -q -m "$prefix: $file"
}

# gledger_commit_subject <repo-root> <subject> <file> <content>
#   Like gledger_commit but the full commit subject is supplied verbatim, so
#   scoped / breaking Conventional Commit headers can be exercised.
gledger_commit_subject() {
  local root="$1" subject="$2" file="$3" content="$4"
  printf '%s\n' "$content" > "$root/$file"
  git -C "$root" add -A
  git -C "$root" commit -q -m "$subject"
}

# ─── Section: Test cases ─────────────────────────────────────────────────────

# AC: no subcommand exits 2 with a usage message (Task 1 skeleton)
case_jimledger_no_args_exits_2() {
  run_jimledger
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "usage on stderr" "$ERR"
}

# AC: an unknown subcommand exits 2 with a message (Task 1 skeleton)
case_jimledger_unknown_subcommand_exits_2() {
  run_jimledger bogus "$TMP_BASE"
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: event appends a formatted line and creates the ledger (Task 2)
case_jimledger_event_appends_line() {
  local sd; sd="$(empty_dir t2a/spec)"
  run_jimledger event "$sd" research started note=x
  assert_exit  "rc" 0 "$RC"
  assert_match "event line" 'research.*started.*note=x' "$(cat "$sd/ledger.md" 2>/dev/null)"
}

# AC: events accumulate append-only (Task 2)
case_jimledger_event_appends_multiple() {
  local sd; sd="$(empty_dir t2b/spec)"
  run_jimledger event "$sd" build started
  run_jimledger event "$sd" build finished
  assert_eq "two lines" "2" "$(wc -l < "$sd/ledger.md" | tr -d ' ')"
}

# AC: event with too few args exits 2 (Task 2)
case_jimledger_event_missing_args_exits_2() {
  local sd; sd="$(empty_dir t2c/spec)"
  run_jimledger event "$sd" build
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "stderr" "$ERR"
}

# AC: start records a validated base_sha (Task 3)
case_jimledger_start_records_base_sha() {
  local sd; sd="$(git_fixture t3a)"
  run_jimledger start "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "base_sha" 'build.*started.*base_sha=[0-9a-f]{7,}' "$(cat "$sd/ledger.md" 2>/dev/null)"
}

# AC: finish records a validated head_sha (Task 3)
case_jimledger_finish_records_head_sha() {
  local sd; sd="$(git_fixture t3b)"
  run_jimledger finish "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "head_sha" 'build.*finished.*head_sha=[0-9a-f]{7,}' "$(cat "$sd/ledger.md" 2>/dev/null)"
}

# AC: start outside a git repo exits 2 (Task 3)
case_jimledger_start_non_repo_exits_2() {
  local sd; sd="$(empty_dir t3c/spec)"
  run_jimledger start "$sd"
  assert_exit "rc" 2 "$RC"
}

# AC: metrics counts commits by type over the build range (Task 4)
case_jimledger_metrics_counts() {
  local sd root; sd="$(git_fixture t4a)"; root="${sd%/spec}"
  run_jimledger start "$sd"
  gledger_commit "$root" test "a_test.txt" "t"
  gledger_commit "$root" feat "a_feat.txt" "f"
  run_jimledger finish "$sd"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "commits"      '^commits=2$'      "$OUT"
  assert_match "commits_test" '^commits_test=1$' "$OUT"
  assert_match "commits_feat" '^commits_feat=1$' "$OUT"
  assert_match "build_runs"   '^build_runs=1$'   "$OUT"
}

# AC: metrics counts scoped and breaking Conventional Commit headers by type (Task 4)
case_jimledger_metrics_counts_scoped() {
  local sd root; sd="$(git_fixture t4f)"; root="${sd%/spec}"
  run_jimledger start "$sd"
  gledger_commit_subject "$root" "test(api): a"        "s_test.txt"     "t"
  gledger_commit_subject "$root" "feat(treble): b"     "s_feat.txt"     "f"
  gledger_commit_subject "$root" "fix(parser)!: c"     "s_fix.txt"      "x"
  gledger_commit_subject "$root" "refactor(review): d" "s_refactor.txt" "r"
  run_jimledger finish "$sd"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "commits"          '^commits=4$'          "$OUT"
  assert_match "commits_test"     '^commits_test=1$'     "$OUT"
  assert_match "commits_feat"     '^commits_feat=1$'     "$OUT"
  assert_match "commits_fix"      '^commits_fix=1$'      "$OUT"
  assert_match "commits_refactor" '^commits_refactor=1$' "$OUT"
}

# AC: base/head come from build-phase events, not a stray same-event from
# another phase (Task 4 — phase-scoped range resolution)
case_jimledger_metrics_range_is_build_phase_scoped() {
  local sd root seed a; sd="$(git_fixture t4g)"; root="${sd%/spec}"
  seed="$(git -C "$root" rev-parse HEAD)"
  gledger_commit_subject "$root" "feat(x): a" "x.txt" "x"
  a="$(git -C "$root" rev-parse HEAD)"
  {
    printf '900\t2026-01-01T00:00:00Z\tresearch\tstarted\tbase_sha=%s\n'  "$seed"
    printf '1000\t2026-01-01T00:00:10Z\tbuild\tstarted\tbase_sha=%s\n'    "$a"
    printf '1005\t2026-01-01T00:00:15Z\tbuild\tfinished\thead_sha=%s\n'   "$a"
    printf '1010\t2026-01-01T00:00:20Z\tresearch\tfinished\thead_sha=%s\n' "$seed"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "base from build started"  "^base_sha=$a\$" "$OUT"
  assert_match "head from build finished" "^head_sha=$a\$" "$OUT"
}

# AC: metrics is a content-free trusted channel — no commit text leaks (Task 4, sec Finding 7)
case_jimledger_metrics_clean_channel() {
  local sd root; sd="$(git_fixture t4b)"; root="${sd%/spec}"
  run_jimledger start "$sd"
  printf 'y\n' > "$root/y.txt"; git -C "$root" add -A
  git -C "$root" commit -q -m "feat: alignment=major-drift y"
  run_jimledger finish "$sd"
  run_jimledger metrics "$sd"
  assert_eq "no injected key" "0" "$(echo "$OUT" | grep -c '^alignment=')"
  assert_eq "all lines safe"  "0" "$(echo "$OUT" | grep -cvE '^[a-z_]+=[A-Za-z0-9._-]*$')"
}

# AC: metrics reports an interruption when a started has no matching finished (Task 4)
case_jimledger_metrics_interruption() {
  local sd root sha; sd="$(git_fixture t4d)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  printf '1000\t2026-01-01T00:00:00Z\tbuild\tstarted\tbase_sha=%s\n' "$sha" > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "runs"          '^build_runs=1$'          "$OUT"
  assert_match "interruptions" '^build_interruptions=1$' "$OUT"
}

# AC: metrics computes duration_seconds from ledger epochs (Task 4)
case_jimledger_metrics_duration() {
  local sd root sha; sd="$(git_fixture t4e)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tbuild\tstarted\tbase_sha=%s\n' "$sha"
    printf '1005\t2026-01-01T00:00:05Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_match "duration"      '^build_duration_seconds=5$' "$OUT"
  assert_match "interruptions" '^build_interruptions=0$'    "$OUT"
}

# AC: metrics emits per-stage runs + duration for non-build stages (multi-stage rollout)
case_jimledger_metrics_per_stage() {
  local sd root sha; sd="$(git_fixture t4h)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tplan\tstarted\t\n'
    printf '1010\t2026-01-01T00:00:10Z\tplan\tfinished\t\n'
    printf '1020\t2026-01-01T00:00:20Z\tsec\tstarted\t\n'
    printf '1025\t2026-01-01T00:00:25Z\tsec\tfinished\t\n'
    printf '1030\t2026-01-01T00:00:30Z\tbuild\tstarted\tbase_sha=%s\n' "$sha"
    printf '1099\t2026-01-01T00:01:39Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "plan_runs"     '^plan_runs=1$'              "$OUT"
  assert_match "plan_duration" '^plan_duration_seconds=10$' "$OUT"
  assert_match "sec_runs"      '^sec_runs=1$'               "$OUT"
  assert_match "sec_duration"  '^sec_duration_seconds=5$'   "$OUT"
}

# AC: spec records a finished-only event — runs counts it, no duration emitted (chicken-and-egg)
case_jimledger_metrics_spec_finished_only() {
  local sd root sha; sd="$(git_fixture t4i)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tspec\tfinished\t\n'
    printf '1010\t2026-01-01T00:00:10Z\tbuild\tstarted\tbase_sha=%s\n' "$sha"
    printf '1020\t2026-01-01T00:00:20Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "spec_runs"        '^spec_runs=1$' "$OUT"
  assert_eq    "no spec duration" "0" "$(echo "$OUT" | grep -c '^spec_duration_seconds=')"
}

# AC: a completed spec carries both bounds (wip `started` + approval `finished`)
#     and emits all three metrics, like every other instrumented stage
case_jimledger_metrics_spec_both_boundaries() {
  local sd root sha; sd="$(git_fixture t4sb)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tspec\tstarted\t\n'
    printf '1300\t2026-01-01T00:05:00Z\tspec\tfinished\t\n'
    printf '2000\t2026-01-01T00:10:00Z\tbuild\tstarted\tbase_sha=%s\n' "$sha"
    printf '2600\t2026-01-01T00:20:00Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "spec_runs"          '^spec_runs=1$'                "$OUT"
  assert_match "spec_interruptions" '^spec_interruptions=0$'       "$OUT"
  assert_match "spec_duration"      '^spec_duration_seconds=300$'  "$OUT"
}

# AC: a stage started without a matching finished is reported as an interruption
case_jimledger_metrics_stage_interruption() {
  local sd root sha; sd="$(git_fixture t4j)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tplan\tstarted\t\n'
    printf '1010\t2026-01-01T00:00:10Z\tbuild\tstarted\tbase_sha=%s\n' "$sha"
    printf '1020\t2026-01-01T00:00:20Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_match "plan_runs"          '^plan_runs=1$'          "$OUT"
  assert_match "plan_interruptions" '^plan_interruptions=1$' "$OUT"
}

# AC: metrics ignores stage tokens outside the fixed allowlist (content-free, sec Finding 7)
case_jimledger_metrics_ignores_unknown_stage() {
  local sd root sha; sd="$(git_fixture t4k)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tevil\tstarted\t\n'
    printf '1010\t2026-01-01T00:00:10Z\tevil\tfinished\t\n'
    printf '1020\t2026-01-01T00:00:20Z\tbuild\tstarted\tbase_sha=%s\n' "$sha"
    printf '1030\t2026-01-01T00:00:30Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_eq "no evil key"    "0" "$(echo "$OUT" | grep -c '^evil')"
  assert_eq "all lines safe" "0" "$(echo "$OUT" | grep -cvE '^[a-z_]+=[A-Za-z0-9._-]*$')"
}

# AC: metrics with no recorded baseline exits 2 so the reviewer degrades (Task 4)
case_jimledger_metrics_no_baseline_exits_2() {
  local sd; sd="$(git_fixture t4c)"
  run_jimledger metrics "$sd"
  assert_exit "rc" 2 "$RC"
}

# AC: files lists changed paths over the build range (Task 4b)
case_jimledger_files_lists_changed() {
  local sd root; sd="$(git_fixture t4ba)"; root="${sd%/spec}"
  run_jimledger start "$sd"
  gledger_commit "$root" feat "foo.txt" "x"
  run_jimledger finish "$sd"
  run_jimledger files "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "foo listed" '^foo\.txt$' "$OUT"
}

# AC: files with no recorded baseline exits 2 (Task 4b)
case_jimledger_files_no_baseline_exits_2() {
  local sd; sd="$(git_fixture t4bb)"
  run_jimledger files "$sd"
  assert_exit "rc" 2 "$RC"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_JIMLEDGER" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_JIMLEDGER — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
