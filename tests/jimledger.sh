#!/usr/bin/env bash
#
# tests/jimledger.sh — Tests for skills/ledger/scripts/jimledger.sh
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

SCRIPT_JIMLEDGER="$REPO_ROOT/skills/ledger/scripts/jimledger.sh"

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

# AC: metrics with no ledger.md at all exits 2 so the reviewer degrades. The
# no-baseline-but-ledger-present case instead exits 0 (028 DD #6) — see
# case_jimledger_metrics_review_no_baseline. git_fixture creates the repo + spec
# dir but no ledger.md, so this exercises the absent-ledger path specifically.
case_jimledger_metrics_absent_ledger_exits_2() {
  local sd; sd="$(git_fixture t4c)"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 2 "$RC"
  assert_match "stderr names the missing ledger" 'no ledger' "$ERR"
}

# ─── spec 028: review as a ledger stage + verdict history ────────────────────

# AC1/AC6/DD6: review's own per-stage metrics emit even with no build baseline
# (an un-instrumented build), so review stays self-measurable. Ledger-only
# metrics are decoupled from the git build range.
case_jimledger_metrics_review_no_baseline() {
  local sd; sd="$(empty_dir t28a/spec)"
  {
    printf '1000\t2026-01-01T00:00:00Z\treview\tstarted\t\n'
    printf '1060\t2026-01-01T00:01:00Z\treview\tfinished\talignment=aligned;findings=0\n'
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "review_runs"     '^review_runs=1$'              "$OUT"
  assert_match "review_duration" '^review_duration_seconds=60$' "$OUT"
}

# AC4/AC9: the latest review verdict surfaces under fixed, code-literal keys.
case_jimledger_metrics_review_verdict() {
  local sd root sha; sd="$(git_fixture t28v)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\treview\tstarted\t\n'
    printf '1060\t2026-01-01T00:01:00Z\treview\tfinished\talignment=minor-drift;findings=2\n'
    printf '2000\t2026-01-01T00:10:00Z\tbuild\tstarted\tbase_sha=%s\n' "$sha"
    printf '2600\t2026-01-01T00:20:00Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "review_alignment" '^review_alignment=minor-drift$' "$OUT"
  assert_match "review_findings"  '^review_findings=2$'            "$OUT"
}

# AC9: a tampered verdict value is bounded — a non-enum alignment or non-integer
# findings is omitted, never surfaced verbatim (sec 028 Finding 1).
case_jimledger_metrics_review_verdict_tampered() {
  local sd root sha; sd="$(git_fixture t28vt)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\treview\tfinished\talignment=pwned;findings=x\n'
    printf '2000\t2026-01-01T00:10:00Z\tbuild\tstarted\tbase_sha=%s\n' "$sha"
    printf '2600\t2026-01-01T00:20:00Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit "rc" 0 "$RC"
  assert_eq "no alignment key" "0" "$(echo "$OUT" | grep -c '^review_alignment=')"
  assert_eq "no findings key"  "0" "$(echo "$OUT" | grep -c '^review_findings=')"
}

# AC8/AC10: commit-review commits review.md + ledger.md in one path-scoped commit
# and leaves an unrelated working-tree change untouched (never git add -A).
case_jimledger_commit_review_scoped() {
  local sd root; sd="$(git_fixture t28c)"; root="${sd%/spec}"
  printf 'review body\n'                                       > "$sd/review.md"
  printf '1\t2026-01-01T00:00:00Z\treview\tfinished\tx\n'      > "$sd/ledger.md"
  printf 'unrelated change\n'                                  > "$root/seed.txt"
  run_jimledger commit-review "$sd" aligned
  assert_exit "rc" 0 "$RC"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "review.md committed" 'spec/review\.md'  "$committed"
  assert_match "ledger.md committed" 'spec/ledger\.md'  "$committed"
  assert_eq    "seed.txt not swept" "0" "$(echo "$committed" | grep -c '^seed\.txt$')"
  assert_eq    "seed.txt still dirty" "1" "$(git -C "$root" status --porcelain seed.txt | grep -c '^ M')"
}

# AC8/DD4: the commit message carries only the trusted-origin verdict enum.
case_jimledger_commit_review_message() {
  local sd root; sd="$(git_fixture t28cm)"; root="${sd%/spec}"
  printf 'r\n' > "$sd/review.md"; printf 'l\n' > "$sd/ledger.md"
  run_jimledger commit-review "$sd" major-drift
  assert_exit "rc" 0 "$RC"
  assert_match "verdict message" '^chore\(review\): record review \(major-drift\)$' "$(git -C "$root" log -1 --format=%s)"
}

# DD4: a non-enum verdict argument falls back to the generic message (no
# untrusted text reaches the commit subject).
case_jimledger_commit_review_tampered_verdict() {
  local sd root; sd="$(git_fixture t28ct)"; root="${sd%/spec}"
  printf 'r\n' > "$sd/review.md"; printf 'l\n' > "$sd/ledger.md"
  run_jimledger commit-review "$sd" 'pwned $(touch hacked)'
  assert_exit "rc" 0 "$RC"
  assert_match "generic message" '^chore\(review\): record review$' "$(git -C "$root" log -1 --format=%s)"
  assert_eq "no side effect" "0" "$([[ -e "$root/hacked" ]] && echo 1 || echo 0)"
}

# AC8/DD4: commit-review degrades gracefully outside a git repo (non-zero, no crash).
case_jimledger_commit_review_non_repo() {
  local sd; sd="$(empty_dir t28cn/spec)"
  printf 'r\n' > "$sd/review.md"; printf 'l\n' > "$sd/ledger.md"
  run_jimledger commit-review "$sd" aligned
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

# AC: diff emits the changed content over the build range (spec 027 Task 1)
case_jimledger_diff_lists_changes() {
  local sd root; sd="$(git_fixture t1da)"; root="${sd%/spec}"
  run_jimledger start "$sd"
  gledger_commit "$root" feat "foo.txt" "hello-diff-marker"
  run_jimledger finish "$sd"
  run_jimledger diff "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "added line"  '^\+hello-diff-marker$' "$OUT"
  assert_match "diff header" '^diff --git' "$OUT"
}

# AC: diff passes --function-context so the enclosing function travels with the
# hunk. The change is at fn.sh line 6; with plain -U3 the function header (line 1)
# surfaces ONLY in the @@ hunk-header line (which begins with '@'), whereas
# --function-context emits it as a CONTEXT line (leading space). Anchoring on the
# context line (`^ ctx_fn`) makes the test fail if the flag were dropped — a bare
# `ctx_fn() {` match would also hit the @@ header and pass vacuously (spec 027 Task 1).
case_jimledger_diff_function_context() {
  local sd root; sd="$(git_fixture t1db)"; root="${sd%/spec}"
  printf 'ctx_fn() {\n  a=1\n  b=2\n  c=3\n  d=4\n  target=old\n}\n' > "$root/fn.sh"
  git -C "$root" add -A
  git -C "$root" commit -q -m "feat: fn"
  run_jimledger start "$sd"
  printf 'ctx_fn() {\n  a=1\n  b=2\n  c=3\n  d=4\n  target=new\n}\n' > "$root/fn.sh"
  git -C "$root" add -A
  git -C "$root" commit -q -m "feat: change target"
  run_jimledger finish "$sd"
  run_jimledger diff "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "func header travels as a context line" '^ ctx_fn\(\) \{' "$OUT"
}

# AC: diff with no recorded baseline exits 2 so the reviewer degrades (spec 027 Task 1)
# The stderr assertion distinguishes the resolve_range degradation path from a bare
# usage fallthrough (an unknown subcommand also exits 2).
case_jimledger_diff_no_baseline_exits_2() {
  local sd; sd="$(git_fixture t1dc)"
  run_jimledger diff "$sd"
  assert_exit  "rc" 2 "$RC"
  assert_match "stderr names the ledger gap" 'no ledger' "$ERR"
}

# AC: diff is scoped to the build range — pre-baseline changes are excluded (spec 027 Task 1)
case_jimledger_diff_range_scoped() {
  local sd root; sd="$(git_fixture t1dd)"; root="${sd%/spec}"
  gledger_commit "$root" feat "pre.txt" "pre-only-marker"
  run_jimledger start "$sd"
  gledger_commit "$root" feat "post.txt" "post-only-marker"
  run_jimledger finish "$sd"
  run_jimledger diff "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "post in range"    'post-only-marker' "$OUT"
  assert_eq    "pre excluded" "0" "$(echo "$OUT" | grep -c 'pre-only-marker')"
}

# AC: diff refuses a malformed SHA in the ledger and exits 2 (spec 027 Task 1, sec F4)
# Exercises resolve_range's validate_sha reject branch through the diff path.
case_jimledger_diff_malformed_sha_exits_2() {
  local sd root sha; sd="$(git_fixture t1de)"; root="${sd%/spec}"
  sha="$(git -C "$root" rev-parse HEAD)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tbuild\tstarted\tbase_sha=bad!sha\n'
    printf '1005\t2026-01-01T00:00:05Z\tbuild\tfinished\thead_sha=%s\n' "$sha"
  } > "$sd/ledger.md"
  run_jimledger diff "$sd"
  assert_exit  "rc" 2 "$RC"
  assert_match "refuses malformed sha" 'malformed sha' "$ERR"
}

# ─── spec 030: blueprint stage + commit-blueprint + diff-range ───────────────

# AC: metrics emits per-stage runs + duration for the blueprint stage, so a
# blueprint update is self-measurable and auditable (spec 030 Task 2, sec F4).
case_jimledger_metrics_blueprint_stage() {
  local sd; sd="$(empty_dir t30bp/spec)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tblueprint\tstarted\t\n'
    printf '1012\t2026-01-01T00:00:12Z\tblueprint\tfinished\t\n'
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "blueprint_runs"     '^blueprint_runs=1$'              "$OUT"
  assert_match "blueprint_duration" '^blueprint_duration_seconds=12$' "$OUT"
}

# AC: commit-blueprint commits spec.md + ledger.md in one path-scoped commit,
# leaving an unrelated working-tree change untouched — never git add -A
# (spec 030 Task 3, AC #9, security Finding 2).
case_jimledger_commit_blueprint_scoped() {
  local sd root; sd="$(git_fixture t30cb)"; root="${sd%/spec}"
  printf '# blueprint\n'                                    > "$sd/spec.md"
  printf '1\t2026-01-01T00:00:00Z\tblueprint\tfinished\t\n' > "$sd/ledger.md"
  printf 'unrelated change\n'                               > "$root/seed.txt"
  run_jimledger commit-blueprint "$sd"
  assert_exit "rc" 0 "$RC"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "spec.md committed"    'spec/spec\.md'   "$committed"
  assert_match "ledger.md committed"  'spec/ledger\.md' "$committed"
  assert_eq    "seed.txt not swept"   "0" "$(echo "$committed" | grep -c '^seed\.txt$')"
  assert_eq    "seed.txt still dirty" "1" "$(git -C "$root" status --porcelain seed.txt | grep -c '^ M')"
}

# AC: commit-blueprint's fix-only edge — every proposed blueprint edit was
# withheld at the violation fork, so spec.md is unchanged and only ledger.md
# is dirty. The path-scoped commit must carry ledger.md alone and still succeed
# (spec 031 AC #8, review Finding 4).
case_jimledger_commit_blueprint_ledger_only() {
  local sd root; sd="$(git_fixture t31cbl)"; root="${sd%/spec}"
  # Seed a committed, clean blueprint: both spec.md and ledger.md tracked.
  printf '# blueprint\n'                                    > "$sd/spec.md"
  printf '1\t2026-01-01T00:00:00Z\tblueprint\tfinished\t\n' > "$sd/ledger.md"
  git -C "$root" add -A
  git -C "$root" commit -q -m "chore: seed blueprint"
  # Fix-only run: a new guard-outcome line lands, spec.md untouched.
  printf '2\t2026-01-02T00:00:00Z\tblueprint\tfinished\tviolations=1;folded=0;fixed=1\n' >> "$sd/ledger.md"
  run_jimledger commit-blueprint "$sd"
  assert_exit "rc" 0 "$RC"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "ledger.md committed"   'spec/ledger\.md' "$committed"
  assert_eq    "spec.md not in commit" "0" "$(echo "$committed" | grep -c 'spec\.md')"
  assert_eq    "tree clean after"      "0" "$(git -C "$root" status --porcelain | grep -c '.')"
}

# AC: commit-blueprint's create mode labels the commit as a create, so a
# first-time blueprint (the U2 fallthrough) is no longer mislabeled an update
# (spec 032 AC #6, DD5).
case_jimledger_commit_blueprint_create_subject() {
  local sd root; sd="$(git_fixture t32cbc)"; root="${sd%/spec}"
  printf '# blueprint\n'                                    > "$sd/spec.md"
  printf '1\t2026-01-01T00:00:00Z\tblueprint\tfinished\t\n' > "$sd/ledger.md"
  run_jimledger commit-blueprint "$sd" create
  assert_exit "rc" 0 "$RC"
  assert_eq "create subject" "docs(blueprint): create 000-blueprint" "$(git -C "$root" log -1 --format=%s)"
}

# AC: mode defaults to update (back-compat), and any non-create value maps to
# update — the whitelist keeps the subject well-formed (spec 032 DD5, sec F2).
case_jimledger_commit_blueprint_update_default_subject() {
  local sd root; sd="$(git_fixture t32cbu)"; root="${sd%/spec}"
  printf '# blueprint\n'                                    > "$sd/spec.md"
  printf '1\t2026-01-01T00:00:00Z\tblueprint\tfinished\t\n' > "$sd/ledger.md"
  run_jimledger commit-blueprint "$sd"
  assert_exit "rc" 0 "$RC"
  assert_eq "update subject (default)" "docs(blueprint): update 000-blueprint" "$(git -C "$root" log -1 --format=%s)"
}

# AC: an unrecognized mode maps to update, never injecting into the subject.
case_jimledger_commit_blueprint_bad_mode_maps_update() {
  local sd root; sd="$(git_fixture t32cbm)"; root="${sd%/spec}"
  printf '# blueprint\n'                                    > "$sd/spec.md"
  printf '1\t2026-01-01T00:00:00Z\tblueprint\tfinished\t\n' > "$sd/ledger.md"
  run_jimledger commit-blueprint "$sd" 'x`touch /tmp/nope`'
  assert_exit "rc" 0 "$RC"
  assert_eq "bad mode → update" "docs(blueprint): update 000-blueprint" "$(git -C "$root" log -1 --format=%s)"
}

# AC: commit-blueprint degrades gracefully outside a git repo (spec 030 Task 3).
case_jimledger_commit_blueprint_non_repo() {
  local sd; sd="$(empty_dir t30cbn/spec)"
  printf 's\n' > "$sd/spec.md"; printf 'l\n' > "$sd/ledger.md"
  run_jimledger commit-blueprint "$sd"
  assert_exit "rc" 2 "$RC"
}

# AC: diff-range emits a --function-context diff over a validated commit range
# (spec 030 Task 4). Operates on the repo at CWD (the ad-hoc adapter runs at root).
case_jimledger_diff_range_emits() {
  local sd root base; sd="$(git_fixture t30dr)"; root="${sd%/spec}"
  base="$(git -C "$root" rev-parse HEAD)"
  gledger_commit "$root" feat "dr.txt" "range-diff-marker"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" diff-range "$base" HEAD 2>/dev/null)"; RC=$?
  assert_exit  "rc" 0 "$RC"
  assert_match "diff header"  '^diff --git'          "$OUT"
  assert_match "added marker" '^\+range-diff-marker$' "$OUT"
}

# AC: diff-range accepts a /-bearing ref (branch) — which is_valid_id would
# wrongly reject. This is the crux of security Finding 5 (spec 030 Task 4).
case_jimledger_diff_range_accepts_slash_ref() {
  local sd root; sd="$(git_fixture t30drs)"; root="${sd%/spec}"
  git -C "$root" branch feat/x HEAD
  gledger_commit "$root" feat "d2.txt" "slash-ref-marker"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" diff-range feat/x HEAD 2>/dev/null)"; RC=$?
  assert_exit "rc" 0 "$RC"
  assert_match "slash ref resolved" 'slash-ref-marker' "$OUT"
}

# AC: diff-range head defaults to HEAD when omitted (spec 030 Task 4).
case_jimledger_diff_range_head_defaults_to_head() {
  local sd root base; sd="$(git_fixture t30drh)"; root="${sd%/spec}"
  base="$(git -C "$root" rev-parse HEAD)"
  gledger_commit "$root" feat "d3.txt" "default-head-marker"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" diff-range "$base" 2>/dev/null)"; RC=$?
  assert_exit "rc" 0 "$RC"
  assert_match "default head marker" 'default-head-marker' "$OUT"
}

# AC: diff-range rejects option-injection / metacharacter / rev-expression refs
# rc 1 with no git diff run (spec 030 Task 4, security Finding 5).
case_jimledger_diff_range_rejects_bad_refs() {
  local sd root badref out rc; sd="$(git_fixture t30drb)"; root="${sd%/spec}"
  for badref in '--output=x' 'a;b' 'a b' 'HEAD~3' 'a^b' 'a:b' '..' '/leading' \
                'trailing/' 'a*b' 'a?b' 'a[b]c' $'a\nb'; do
    out="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" diff-range "$badref" HEAD 2>/dev/null)"; rc=$?
    assert_eq "rejects '$badref' rc1"        "1" "$rc"
    assert_eq "no diff output for '$badref'" ""  "$out"
  done
}

# AC: a --output=<file> injection ref never reaches git, so no file is written
# (spec 030 Task 4, security Finding 5 — the concrete injection foreclosure).
case_jimledger_diff_range_option_injection_no_write() {
  local sd root marker rc; sd="$(git_fixture t30dri)"; root="${sd%/spec}"
  marker="$TMP_BASE/dr-injected"
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" diff-range "--output=$marker" HEAD >/dev/null 2>&1); rc=$?
  assert_eq "rejected rc1"    "1" "$rc"
  assert_eq "no file written" "0" "$([[ -e "$marker" ]] && echo 1 || echo 0)"
}

# AC: a command-substitution-shaped ref is foreclosed by valid_git_ref — the sole
# boundary for the ad-hoc ref path — and never reaches a shell that would run it
# (spec 030 security Finding 5; the strongest belt, mirroring the no-write case).
case_jimledger_diff_range_command_sub_no_exec() {
  local sd root marker rc badref; sd="$(git_fixture t30drc)"; root="${sd%/spec}"
  marker="$TMP_BASE/dr-cmdsub"
  badref='x`touch '"$marker"'`'
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" diff-range "$badref" HEAD >/dev/null 2>&1); rc=$?
  assert_eq "rejected rc1"        "1" "$rc"
  assert_eq "no command executed" "0" "$([[ -e "$marker" ]] && echo 1 || echo 0)"
}

# AC: diff-range with no base arg exits 2 (usage; spec 030 Task 4).
case_jimledger_diff_range_missing_base_exits_2() {
  local sd root; sd="$(git_fixture t30drm)"; root="${sd%/spec}"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" diff-range 2>/dev/null)"; RC=$?
  assert_exit "rc" 2 "$RC"
}

# ─── spec 036: files-range (changed paths over an ad-hoc range) ──────────────

# AC: files-range lists changed paths over a validated CWD-repo range (Task 1).
# Mirrors diff-range's ref-safety machinery but emits --name-only, one path/line.
case_jimledger_files_range_lists() {
  local sd root base; sd="$(git_fixture t36fr)"; root="${sd%/spec}"
  base="$(git -C "$root" rev-parse HEAD)"
  gledger_commit "$root" feat "fr.txt" "x"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" files-range "$base" HEAD 2>/dev/null)"; RC=$?
  assert_exit  "rc" 0 "$RC"
  assert_match "path listed" '^fr\.txt$' "$OUT"
}

# AC: files-range head defaults to HEAD when omitted (Task 1; mirrors diff-range).
case_jimledger_files_range_head_defaults() {
  local sd root base; sd="$(git_fixture t36frh)"; root="${sd%/spec}"
  base="$(git -C "$root" rev-parse HEAD)"
  gledger_commit "$root" feat "frh.txt" "x"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" files-range "$base" 2>/dev/null)"; RC=$?
  assert_exit  "rc" 0 "$RC"
  assert_match "default-head path" '^frh\.txt$' "$OUT"
}

# AC: files-range on an empty range (base == head) exits 0 with no output (Task 1).
case_jimledger_files_range_empty_range() {
  local sd root base; sd="$(git_fixture t36fre)"; root="${sd%/spec}"
  base="$(git -C "$root" rev-parse HEAD)"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" files-range "$base" HEAD 2>/dev/null)"; RC=$?
  assert_exit "rc" 0 "$RC"
  assert_eq   "empty output" "" "$OUT"
}

# AC: files-range rejects option-injection / metacharacter / rev-expression refs
# with rc 2 and no output — the files-family degrade code (Task 1, security F10 /
# 030 F5 ref-safety lineage). rc 2 (not diff-range's rc 1) aligns with the
# files/diff/metrics degrade-on-2 family that the sensor & --since callers key on.
case_jimledger_files_range_bad_ref_exits_2() {
  local sd root out rc; sd="$(git_fixture t36frb)"; root="${sd%/spec}"
  for badref in '--output=x' 'a;b' 'a b' 'HEAD~3' 'a^b' 'a:b' '..' '/leading' \
                'trailing/' 'a*b' 'a?b' $'a\nb'; do
    out="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" files-range "$badref" HEAD 2>/dev/null)"; rc=$?
    assert_eq "rejects '$badref' rc2"       "2" "$rc"
    assert_eq "no output for '$badref'" ""  "$out"
  done
}

# AC: a --output=<file> injection ref never reaches git, so no file is written
# (Task 1, security ref-safety lineage — the concrete injection foreclosure).
case_jimledger_files_range_option_injection_no_write() {
  local sd root marker rc; sd="$(git_fixture t36fri)"; root="${sd%/spec}"
  marker="$TMP_BASE/fr-injected"
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" files-range "--output=$marker" HEAD >/dev/null 2>&1); rc=$?
  assert_eq "rejected rc2"    "2" "$rc"
  assert_eq "no file written" "0" "$([[ -e "$marker" ]] && echo 1 || echo 0)"
}

# AC: files-range with no base arg exits 2 (usage; Task 1).
case_jimledger_files_range_missing_base_exits_2() {
  local sd root; sd="$(git_fixture t36frm)"; root="${sd%/spec}"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" files-range 2>/dev/null)"; RC=$?
  assert_exit "rc" 2 "$RC"
}

# AC: outside a git repo, files-range fails contained (rc 2, no crash) — the
# --since caller degrades rather than aborting (Task 1).
case_jimledger_files_range_non_repo_exits_2() {
  local nonrepo; nonrepo="$TMP_BASE/t36frn"; mkdir -p "$nonrepo"
  OUT="$(cd "$nonrepo" && bash "$SCRIPT_JIMLEDGER" files-range HEAD HEAD 2>/dev/null)"; RC=$?
  assert_exit "rc" 2 "$RC"
}

# AC: the emitted-path form is pinned so the scoped-check consumer knows the
# untrusted shape (Task 1, security.md Finding 10). git's default core.quotePath
# emits a plain-space path VERBATIM (unquoted) but C-quotes a non-ASCII path
# (double-quote-wrapped, octal-escaped) — both forms pinned here.
case_jimledger_files_range_quotepath_emitted_form() {
  local sd root base; sd="$(git_fixture t36frq)"; root="${sd%/spec}"
  base="$(git -C "$root" rev-parse HEAD)"
  printf 'x\n' > "$root/has space.txt"
  printf 'y\n' > "$root/uni-café.txt"
  git -C "$root" add -A
  git -C "$root" commit -q -m "feat: odd names"
  OUT="$(cd "$root" && bash "$SCRIPT_JIMLEDGER" files-range "$base" HEAD 2>/dev/null)"; RC=$?
  assert_exit  "rc" 0 "$RC"
  assert_match "space path emitted verbatim (unquoted)" '^has space\.txt$' "$OUT"
  assert_match "non-ascii path C-quoted"                '^"uni-caf\\303\\251\.txt"$' "$OUT"
}

# ─── spec 032: updates-since (regen-cadence count) ───────────────────────────

# AC: updates-since counts blueprint finished events strictly after the
# watermark, ignoring started/other-phase lines (spec 032 AC #1, DD2).
case_jimledger_updates_since_counts_after_watermark() {
  local sd; sd="$(empty_dir t32us/spec)"
  {
    printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\t\n'
    printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\t\n'
    printf '300\t2026-03-01T00:00:00Z\tblueprint\tfinished\tviolations=0\n'
    printf '400\t2026-02-15T00:00:00Z\tblueprint\tstarted\t\n'
    printf '500\t2026-02-20T00:00:00Z\tplan\tfinished\t\n'
  } > "$sd/ledger.md"
  run_jimledger updates-since "$sd" 2026-01-01T00:00:00Z
  assert_exit "rc" 0 "$RC"
  assert_eq "count strictly after watermark" "2" "$OUT"
}

# AC: the count is 0 when no finished event postdates the watermark — a freshly
# generated blueprint reads 0 (spec 032 AC #2).
case_jimledger_updates_since_zero_when_none_after() {
  local sd; sd="$(empty_dir t32usz/spec)"
  printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\t\n' > "$sd/ledger.md"
  run_jimledger updates-since "$sd" 2026-06-01T00:00:00Z
  assert_exit "rc" 0 "$RC"
  assert_eq "zero after a later watermark" "0" "$OUT"
}

# AC: future-dated events (iso > now) are excluded, so a planted future event
# cannot inflate the count and force repeat regens (spec 032 sec F1(b), DD7).
case_jimledger_updates_since_excludes_future() {
  local sd; sd="$(empty_dir t32usf/spec)"
  {
    printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\t\n'
    printf '999\t2099-01-01T00:00:00Z\tblueprint\tfinished\t\n'
  } > "$sd/ledger.md"
  run_jimledger updates-since "$sd" 2026-01-01T00:00:00Z
  assert_exit "rc" 0 "$RC"
  assert_eq "future event excluded" "1" "$OUT"
}

# AC: a malformed or empty watermark returns rc 2, so the caller degrades to "no
# baseline" instead of counting against garbage (spec 032 AC #8, DD3).
case_jimledger_updates_since_malformed_watermark_rc2() {
  local sd; sd="$(empty_dir t32usm/spec)"
  printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\t\n' > "$sd/ledger.md"
  run_jimledger updates-since "$sd" 'not-a-timestamp'
  assert_exit "malformed rc" 2 "$RC"
  run_jimledger updates-since "$sd" ''
  assert_exit "empty rc" 2 "$RC"
}

# AC: a missing ledger returns rc 2 (spec 032 DD3; mirrors metrics/no-ledger).
case_jimledger_updates_since_missing_ledger_rc2() {
  local sd; sd="$(empty_dir t32usn/spec)"
  run_jimledger updates-since "$sd" 2026-01-01T00:00:00Z
  assert_exit "missing-ledger rc" 2 "$RC"
}

# ─── spec 039: last-reconcile (prior-event delta source) ─────────────────────

# AC: last-reconcile returns rc 1 when the ledger carries no reconcile finished
# event — a started reconcile or a plan finish does not count; the caller
# renders baseline (spec 039 AC #2, DD 3).
case_jimledger_last_reconcile_none_rc1() {
  local sd; sd="$(empty_dir t39lrn/spec)"
  {
    printf '100\t2026-01-01T00:00:00Z\tblueprint\tstarted\ttier=project;op=reconcile\n'
    printf '200\t2026-02-01T00:00:00Z\tplan\tfinished\t\n'
  } > "$sd/ledger.md"
  run_jimledger last-reconcile "$sd"
  assert_exit "rc" 1 "$RC"
}

# AC: a missing ledger is "no prior event" (rc 1), not an error (DD 3).
case_jimledger_last_reconcile_missing_ledger_rc1() {
  local sd; sd="$(empty_dir t39lrm/spec)"
  run_jimledger last-reconcile "$sd"
  assert_exit "rc" 1 "$RC"
}

# AC: the latest reconcile finished event wins; its iso heads the output and its
# documented counters follow (spec 039 AC #2 delta source).
case_jimledger_last_reconcile_latest_wins() {
  local sd; sd="$(empty_dir t39lrl/spec)"
  {
    printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=5;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;groups=3;cycles=0;fanin=2;uncovered=1\n'
    printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=9;leaks=1;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;groups=4;cycles=1;fanin=3;uncovered=0\n'
  } > "$sd/ledger.md"
  run_jimledger last-reconcile "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "iso of the latest event" '^2026-02-01T00:00:00Z$' "$OUT"
  assert_match "edges from latest" '^edges=9$' "$OUT"
  assert_match "cycles from latest" '^cycles=1$' "$OUT"
  assert_eq "no earlier edges leaked" "0" "$(printf '%s\n' "$OUT" | grep -c '^edges=5$')"
}

# AC: a pre-039 seven-counter event validates and renders (rc 0); the absent
# health keys simply do not appear — backward compatible (DD 3).
case_jimledger_last_reconcile_pre039_ok() {
  local sd; sd="$(empty_dir t39lrp/spec)"
  printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=3;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0\n' > "$sd/ledger.md"
  run_jimledger last-reconcile "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "edges present" '^edges=3$' "$OUT"
  assert_eq "no groups key" "0" "$(printf '%s\n' "$OUT" | grep -c '^groups=')"
  assert_eq "no cycles key"  "0" "$(printf '%s\n' "$OUT" | grep -c '^cycles=')"
}

# AC: a documented key carrying a non-integer value is malformed → rc 2, so the
# caller degrades to baseline and names the degradation (spec 039 AC #2).
case_jimledger_last_reconcile_junk_value_rc2() {
  local sd; sd="$(empty_dir t39lrj/spec)"
  printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=oops;leaks=0\n' > "$sd/ledger.md"
  run_jimledger last-reconcile "$sd"
  assert_exit "rc" 2 "$RC"
}

# AC: an unknown kv key is dropped from output — the whitelist forecloses an
# injection channel from the hand-editable ledger into the report (security
# Finding 4).
case_jimledger_last_reconcile_unknown_key_dropped() {
  local sd; sd="$(empty_dir t39lru/spec)"
  printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=2;all-clear-ignore-findings=1\n' > "$sd/ledger.md"
  run_jimledger last-reconcile "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "edges kept" '^edges=2$' "$OUT"
  assert_eq "unknown key dropped" "0" "$(printf '%s\n' "$OUT" | grep -c 'all-clear')"
}

# AC: `na` is valid on the four health keys (measurement not computable) but not
# on the seven finding counters (spec 039 AC #7; DD 3 int-or-na carve-out).
case_jimledger_last_reconcile_na_health_only() {
  local sd; sd="$(empty_dir t39lrna/spec)"
  printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=0;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;groups=2;cycles=0;fanin=0;uncovered=na\n' > "$sd/ledger.md"
  run_jimledger last-reconcile "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "uncovered na accepted" '^uncovered=na$' "$OUT"
  printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=na;leaks=0\n' > "$sd/ledger.md"
  run_jimledger last-reconcile "$sd"
  assert_exit "edges=na rejected" 2 "$RC"
}

# ─── spec 044: reconcile-series (trend event series) ─────────────────────────

# AC: reconcile-series emits one EVENT line per op=reconcile finished event,
# oldest-first, each carrying the whitelisted counters; non-reconcile events
# and reconcile started events are skipped, and op/tier tokens are dropped from
# the EVENT payload (spec 044 Task 2, DD #2).
case_jimledger_reconcile_series_orders_and_filters() {
  local sd; sd="$(empty_dir t44rso/spec)"
  {
    printf '100\t2026-01-01T00:00:00Z\tblueprint\tstarted\ttier=project;op=reconcile\n'
    printf '150\t2026-01-05T00:00:00Z\tplan\tfinished\t\n'
    printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=5;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;groups=3;cycles=0;fanin=2;uncovered=1\n'
    printf '300\t2026-03-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=9;leaks=1;breaking=1;dead=0;unresolved=0;undeclared=0;stale=0;groups=4;cycles=1;fanin=3;uncovered=0\n'
  } > "$sd/ledger.md"
  run_jimledger reconcile-series "$sd"
  assert_exit "rc" 0 "$RC"
  assert_eq "two EVENT lines" "2" "$(printf '%s\n' "$OUT" | grep -c '^EVENT')"
  local first last
  first="$(printf '%s\n' "$OUT" | grep '^EVENT' | head -1)"
  last="$(printf '%s\n' "$OUT" | grep '^EVENT' | tail -1)"
  assert_match "oldest first iso" '2026-02-01T00:00:00Z' "$first"
  assert_match "oldest edges=5"   'edges=5'              "$first"
  assert_match "newest iso"       '2026-03-01T00:00:00Z' "$last"
  assert_match "newest cycles=1"  'cycles=1'             "$last"
  assert_eq "op/tier dropped from EVENTs" "0" "$(printf '%s\n' "$OUT" | grep '^EVENT' | grep -c 'op=reconcile\|tier=')"
}

# AC: a malformed reconcile event (a documented counter with a bad value) is
# excluded from the series and the exclusion is named, while valid events on
# either side are kept — the series-grain degradation of spec AC #13.
case_jimledger_reconcile_series_excludes_malformed() {
  local sd; sd="$(empty_dir t44rsx/spec)"
  {
    printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=5;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0\n'
    printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=oops;leaks=0\n'
    printf '300\t2026-03-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=7;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0\n'
  } > "$sd/ledger.md"
  run_jimledger reconcile-series "$sd"
  assert_exit "rc" 0 "$RC"
  assert_eq "two valid EVENTs kept" "2" "$(printf '%s\n' "$OUT" | grep -c '^EVENT')"
  assert_eq "one EXCLUDED named"    "1" "$(printf '%s\n' "$OUT" | grep -c '^EXCLUDED')"
  assert_match "exclusion names the bad key" 'bad-value:edges' "$(printf '%s\n' "$OUT" | grep '^EXCLUDED')"
}

# AC: an `na` health counter passes through the series verbatim (not-computable,
# never coerced to a number); an int-only counter carrying `na` is malformed and
# excluded (spec 044 Task 2/AC #13; the 039 int-or-na carve-out at series grain).
case_jimledger_reconcile_series_na_passthrough() {
  local sd; sd="$(empty_dir t44rsna/spec)"
  {
    printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=0;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;groups=2;cycles=0;fanin=0;uncovered=na\n'
    printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=na;leaks=0\n'
  } > "$sd/ledger.md"
  run_jimledger reconcile-series "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "uncovered=na carried" 'uncovered=na' "$(printf '%s\n' "$OUT" | grep '^EVENT')"
  assert_eq "edges=na excluded (int-only)" "1" "$(printf '%s\n' "$OUT" | grep -c '^EXCLUDED')"
}

# AC: a missing ledger yields rc 1 and no output (no series to read).
case_jimledger_reconcile_series_missing_ledger_rc1() {
  local sd; sd="$(empty_dir t44rsm/spec)"
  run_jimledger reconcile-series "$sd"
  assert_exit "rc" 1 "$RC"
  assert_eq "no output" "" "$OUT"
}

# AC: a ledger with no valid reconcile finished event yields rc 1 (zero valid
# events) even though other events exist.
case_jimledger_reconcile_series_no_events_rc1() {
  local sd; sd="$(empty_dir t44rsn/spec)"
  {
    printf '100\t2026-01-01T00:00:00Z\tplan\tfinished\t\n'
    printf '200\t2026-02-01T00:00:00Z\tblueprint\tstarted\ttier=project;op=reconcile\n'
  } > "$sd/ledger.md"
  run_jimledger reconcile-series "$sd"
  assert_exit "rc" 1 "$RC"
}

# AC: a missing spec-dir argument is a usage error (rc 2).
case_jimledger_reconcile_series_bad_args_rc2() {
  run_jimledger reconcile-series
  assert_exit "rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: commit-map commits the project map + specs-root ledger in one
# path-scoped commit in the CWD repo, leaving unrelated changes untouched —
# never git add -A (spec 033 Task 3, AC #10, plan DD 4).
case_jimledger_commit_map_scoped() {
  local sd root; sd="$(git_fixture t33cm)"; root="${sd%/spec}"
  mkdir -p "$root/docs/specs"
  printf '# map\n' > "$root/BLUEPRINT.md"
  printf '1\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project\n' > "$root/docs/specs/ledger.md"
  printf 'unrelated\n' > "$root/loose.txt"
  local out rc
  out=$(cd "$root" && bash "$SCRIPT_JIMLEDGER" commit-map BLUEPRINT.md docs/specs 2>&1); rc=$?
  assert_exit "rc" 0 "$rc"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "map committed"     '^BLUEPRINT\.md$'         "$committed"
  assert_match "ledger committed"  '^docs/specs/ledger\.md$' "$committed"
  assert_eq    "loose not swept"   "0" "$(echo "$committed" | grep -c '^loose\.txt$')"
  assert_eq    "update subject (default)" "docs(blueprint): update project map" "$(git -C "$root" log -1 --format=%s)"
}

# AC: commit-map's create mode labels the first-time map commit; an
# unrecognized mode maps to update — the whitelist keeps the subject
# well-formed and non-injectable (spec 033 Task 3, mirroring commit-blueprint).
case_jimledger_commit_map_mode_whitelist() {
  local sd root; sd="$(git_fixture t33cmw)"; root="${sd%/spec}"
  mkdir -p "$root/docs/specs"
  printf '# map v1\n' > "$root/BLUEPRINT.md"
  printf 'l1\n' > "$root/docs/specs/ledger.md"
  local rc
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" commit-map BLUEPRINT.md docs/specs create) >/dev/null 2>&1; rc=$?
  assert_exit "create rc" 0 "$rc"
  assert_eq "create subject" "docs(blueprint): create project map" "$(git -C "$root" log -1 --format=%s)"
  printf '# map v2\n' > "$root/BLUEPRINT.md"
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" commit-map BLUEPRINT.md docs/specs 'x`touch /tmp/nope`') >/dev/null 2>&1; rc=$?
  assert_exit "bad-mode rc" 0 "$rc"
  assert_eq "bad mode → update" "docs(blueprint): update project map" "$(git -C "$root" log -1 --format=%s)"
}

# AC: commit-map rejects absolute and '..'-bearing values in BOTH path
# arguments — each is config-derived (blueprint_path / specs_path) and passes
# the jimfile valid-relpath boundary before reaching git (spec 033 security
# Findings 2 and 8).
case_jimledger_commit_map_rejects_unsafe_paths() {
  local sd root; sd="$(git_fixture t33cmr)"; root="${sd%/spec}"
  mkdir -p "$root/docs/specs"
  printf 'm\n' > "$root/BLUEPRINT.md"
  printf 'l\n' > "$root/docs/specs/ledger.md"
  local rc
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" commit-map /etc/BLUEPRINT.md docs/specs) >/dev/null 2>&1; rc=$?
  assert_exit "absolute map"   2 "$rc"
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" commit-map ../BLUEPRINT.md docs/specs) >/dev/null 2>&1; rc=$?
  assert_exit "dotdot map"     2 "$rc"
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" commit-map BLUEPRINT.md /abs/specs) >/dev/null 2>&1; rc=$?
  assert_exit "absolute specs" 2 "$rc"
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" commit-map BLUEPRINT.md ../specs) >/dev/null 2>&1; rc=$?
  assert_exit "dotdot specs"   2 "$rc"
  assert_eq "no commit landed" "1" "$(git -C "$root" rev-list --count HEAD)"
}

# AC: commit-map rejects a shape-valid arg that resolves outside the worktree
# via a symlink — the DD 4 containment check (each git-add target resolves
# inside `git rev-parse --show-toplevel`) backstops valid-relpath and git's own
# symlink refusal before git runs (spec 033 Finding 8).
case_jimledger_commit_map_rejects_symlink_escape() {
  local sd root; sd="$(git_fixture t33cme)"; root="${sd%/spec}"
  mkdir -p "$root/docs/specs"
  printf 'l\n' > "$root/docs/specs/ledger.md"
  # 'escape.md' is a shape-valid arg (relative, no '..') that symlinks out of
  # the worktree, so it clears valid-relpath but must fail the containment gate.
  ln -s ../escape-target.md "$root/escape.md"
  local rc
  (cd "$root" && bash "$SCRIPT_JIMLEDGER" commit-map escape.md docs/specs) >/dev/null 2>&1; rc=$?
  assert_exit "symlink-escaping map rejected" 2 "$rc"
  assert_eq "no commit landed" "1" "$(git -C "$root" rev-list --count HEAD)"
}

# AC: commit-map degrades gracefully outside a git repo (spec 033 Task 3).
case_jimledger_commit_map_non_repo() {
  local d; d="$(empty_dir t33cmn)"
  printf 'm\n' > "$d/BLUEPRINT.md"
  mkdir -p "$d/specs"; printf 'l\n' > "$d/specs/ledger.md"
  local rc
  (cd "$d" && bash "$SCRIPT_JIMLEDGER" commit-map BLUEPRINT.md specs) >/dev/null 2>&1; rc=$?
  assert_exit "rc" 2 "$rc"
}

# ─── spec 035: verify stage + commit-verify ──────────────────────────────────

# AC: metrics emits per-stage runs + duration for the verify stage, so a
# verification run is self-measurable and auditable (spec 035 Task 2, DD #6).
case_jimledger_metrics_verify_stage() {
  local sd; sd="$(empty_dir t35v/spec)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tverify\tstarted\t\n'
    printf '1008\t2026-01-01T00:00:08Z\tverify\tfinished\tchecked=12;holds=7;violated=2;failed=1;unconfigured=1;skipped=1\n'
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_exit  "rc" 0 "$RC"
  assert_match "verify_runs"          '^verify_runs=1$'             "$OUT"
  assert_match "verify_interruptions" '^verify_interruptions=0$'    "$OUT"
  assert_match "verify_duration"      '^verify_duration_seconds=8$' "$OUT"
}

# AC: the verify counters ride the finished event as untrusted kv, but only the
# fixed per-stage keys emit — a crafted counter can never inject a metric key
# (spec 035, the sec Finding 7 content-free-channel lineage).
case_jimledger_metrics_verify_channel_clean() {
  local sd; sd="$(empty_dir t35vc/spec)"
  {
    printf '1000\t2026-01-01T00:00:00Z\tverify\tstarted\t\n'
    printf '1005\t2026-01-01T00:00:05Z\tverify\tfinished\tviolated=1;evil=pwned\n'
  } > "$sd/ledger.md"
  run_jimledger metrics "$sd"
  assert_eq "no injected key" "0" "$(echo "$OUT" | grep -c '^evil')"
  assert_eq "all lines safe"  "0" "$(echo "$OUT" | grep -cvE '^[a-z_]+=[A-Za-z0-9._-]*$')"
}

# AC: commit-verify commits ledger.md alone with the fixed subject and leaves an
# unrelated working-tree change untouched — never git add -A. The run writes no
# artifact, so the ledger event is the only tracked change (spec 035 Task 2,
# AC #11).
case_jimledger_commit_verify_ledger_only() {
  local sd root; sd="$(git_fixture t35cv)"; root="${sd%/spec}"
  printf '1\t2026-01-01T00:00:00Z\tverify\tfinished\tviolated=0\n' > "$sd/ledger.md"
  printf 'unrelated change\n' > "$root/seed.txt"
  run_jimledger commit-verify "$sd"
  assert_exit "rc" 0 "$RC"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "ledger.md committed"  'spec/ledger\.md' "$committed"
  assert_eq    "seed.txt not swept"   "0" "$(echo "$committed" | grep -c '^seed\.txt$')"
  assert_eq    "seed.txt still dirty" "1" "$(git -C "$root" status --porcelain seed.txt | grep -c '^ M')"
}

# AC: commit-verify's subject is a fixed literal — no mode, no verdict, no
# untrusted input reaches the commit message (spec 035 Task 2, DD #6).
case_jimledger_commit_verify_subject() {
  local sd root; sd="$(git_fixture t35cvm)"; root="${sd%/spec}"
  printf 'l\n' > "$sd/ledger.md"
  run_jimledger commit-verify "$sd"
  assert_exit "rc" 0 "$RC"
  assert_eq "verify subject" "chore(verify): record verification run" "$(git -C "$root" log -1 --format=%s)"
}

# AC: commit-verify degrades gracefully outside a git repo (spec 035 Task 2).
case_jimledger_commit_verify_non_repo() {
  local sd; sd="$(empty_dir t35cvn/spec)"
  printf 'l\n' > "$sd/ledger.md"
  run_jimledger commit-verify "$sd"
  assert_exit "rc" 2 "$RC"
}

# ─── spec 043: rename-tracked (guarded sibling git mv) ───────────────────────

# run_jimledger_in <dir> <args...> — invoke jimledger.sh with CWD=<dir> so the
#   CWD-repo git verbs (rename-tracked, commit-rename) act on the fixture repo.
run_jimledger_in() {
  local dir="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$dir" && bash "$SCRIPT_JIMLEDGER" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# rename_git_fixture <name> — a git repo with a tracked group spec dir and an
#   identity-bearing territory dir, one commit. Print the repo root.
rename_git_fixture() {
  local name="$1"; local root="$TMP_BASE/$name"
  mkdir -p "$root/docs/specs/cart/000-blueprint" "$root/modules/cart"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false
  printf '# cart\n' > "$root/docs/specs/cart/000-blueprint/spec.md"
  printf 'x\n'      > "$root/modules/cart/a.js"
  git -C "$root" add -A
  git -C "$root" commit -q -m "seed"
  printf '%s' "$root"
}

# AC #10: rename-tracked renames a tracked group dir with git mv, staging the
# rename (history-continuous move).
case_jimledger_rename_tracked_renames_dir() {
  local root; root="$(rename_git_fixture rt_ok)"
  run_jimledger_in "$root" rename-tracked docs/specs/cart docs/specs/checkout
  assert_exit "rc" 0 "$RC"
  assert_eq "old gone"   "0" "$([[ -e "$root/docs/specs/cart" ]] && echo 1 || echo 0)"
  assert_eq "new exists" "1" "$([[ -d "$root/docs/specs/checkout" ]] && echo 1 || echo 0)"
  assert_match "staged rename visible" 'docs/specs/checkout/000-blueprint/spec\.md' \
    "$(git -C "$root" diff --cached --name-only)"
}

# sec Finding 6: refuses an untracked source — rename-tracked only moves what git
# already tracks.
case_jimledger_rename_tracked_refuses_untracked() {
  local root; root="$(rename_git_fixture rt_unt)"
  mkdir -p "$root/docs/specs/scratch"
  run_jimledger_in "$root" rename-tracked docs/specs/scratch docs/specs/checkout
  assert_exit "rc" 1 "$RC"
  assert_nonempty "names the refusal" "$ERR"
}

# sec Finding 6: an absolute source is rejected by the valid-relpath boundary.
case_jimledger_rename_tracked_refuses_absolute() {
  local root; root="$(rename_git_fixture rt_abs)"
  run_jimledger_in "$root" rename-tracked /etc/passwd docs/specs/checkout
  assert_exit "rc" 1 "$RC"
}

# sec Finding 6: a '..'-segment path is rejected by the valid-relpath boundary.
case_jimledger_rename_tracked_refuses_dotdot() {
  local root; root="$(rename_git_fixture rt_dd)"
  run_jimledger_in "$root" rename-tracked docs/specs/../../etc docs/specs/checkout
  assert_exit "rc" 1 "$RC"
}

# sec Finding 6: refuses when the target already exists (never clobbers).
case_jimledger_rename_tracked_refuses_existing_target() {
  local root; root="$(rename_git_fixture rt_ex)"
  mkdir -p "$root/docs/specs/orders"
  run_jimledger_in "$root" rename-tracked docs/specs/cart docs/specs/orders
  assert_exit "rc" 1 "$RC"
}

# sec Finding 6: refuses a cross-parent move — the constraint that makes this a
# sibling RENAME, never a general relocation primitive.
case_jimledger_rename_tracked_refuses_cross_parent() {
  local root; root="$(rename_git_fixture rt_cp)"
  run_jimledger_in "$root" rename-tracked docs/specs/cart modules/checkout
  assert_exit "rc" 1 "$RC"
}

# sec Finding 6: refuses a non-slug new basename.
case_jimledger_rename_tracked_refuses_nonslug_basename() {
  local root; root="$(rename_git_fixture rt_ns)"
  run_jimledger_in "$root" rename-tracked docs/specs/cart docs/specs/Check_Out
  assert_exit "rc" 1 "$RC"
}

# rc 2 on a missing argument (usage, distinct from a guard refusal).
case_jimledger_rename_tracked_missing_args() {
  local root; root="$(rename_git_fixture rt_ma)"
  run_jimledger_in "$root" rename-tracked docs/specs/cart
  assert_exit "rc" 2 "$RC"
}

# ─── spec 043: commit-rename (explicit-stage rename commits) ─────────────────

# AC #12 / sec Finding 7: the docs commit stages the moved spec-dir pair (script-
# derived from specs-dir/old/new) plus exactly the touched blueprint args — an
# unedited-but-dirty sibling blueprint and an unrelated dirty file never ride it.
# The rename lands atomically (old deletion + new addition in one commit).
case_jimledger_commit_rename_docs_scoped() {
  local root; root="$(rename_git_fixture cr_docs)"
  mkdir -p "$root/docs/specs/orders/000-blueprint" "$root/docs/specs/billing/000-blueprint"
  printf 'requires cart\n' > "$root/docs/specs/orders/000-blueprint/spec.md"
  printf 'mentions cart\n'  > "$root/docs/specs/billing/000-blueprint/spec.md"
  git -C "$root" add -A && git -C "$root" commit -q -m "add siblings"
  run_jimledger_in "$root" rename-tracked docs/specs/cart docs/specs/checkout
  assert_exit "rename rc" 0 "$RC"
  printf 'requires checkout\n' > "$root/docs/specs/orders/000-blueprint/spec.md"  # arm-touched
  printf 'stray edit\n'        > "$root/docs/specs/billing/000-blueprint/spec.md" # dirty, NOT in stage set
  printf 'unrelated\n'         > "$root/loose.txt"                                 # unrelated dirt
  run_jimledger_in "$root" commit-rename docs/specs cart checkout docs \
    docs/specs/orders/000-blueprint/spec.md
  assert_exit "rc" 0 "$RC"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "moved dir committed"   'docs/specs/checkout/000-blueprint/spec\.md' "$committed"
  assert_match "orders edit committed" 'docs/specs/orders/000-blueprint/spec\.md'   "$committed"
  assert_eq "old path gone from HEAD tree" "0" "$(git -C "$root" ls-tree -r --name-only HEAD | grep -c '^docs/specs/cart/')"
  assert_eq "billing NOT committed" "0" "$(echo "$committed" | grep -c 'billing')"
  assert_eq "loose NOT committed"   "0" "$(echo "$committed" | grep -c 'loose')"
  assert_eq "billing still dirty"   "1" "$(git -C "$root" status --porcelain docs/specs/billing | grep -c '^ M')"
  assert_eq "subject" "docs(specs): rename group cart to checkout" "$(git -C "$root" log -1 --format=%s)"
}

# AC #8/#12: the code commit stages exactly the territory pair + import-fixed
# files given as explicit args; an unrelated dirty file never rides it; the
# subject names the new territory.
case_jimledger_commit_rename_code_scoped() {
  local root; root="$(rename_git_fixture cr_code)"
  printf 'import "modules/cart"\n' > "$root/app.js"
  git -C "$root" add -A && git -C "$root" commit -q -m "add app"
  run_jimledger_in "$root" rename-tracked modules/cart modules/checkout
  assert_exit "rename rc" 0 "$RC"
  printf 'import "modules/checkout"\n' > "$root/app.js"   # import fix (unstaged)
  printf 'stray\n' > "$root/loose.txt"                    # unrelated dirt
  run_jimledger_in "$root" commit-rename docs/specs cart checkout code \
    modules/cart modules/checkout app.js
  assert_exit "rc" 0 "$RC"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "territory move committed" 'modules/checkout/a\.js' "$committed"
  assert_match "import fix committed"     '^app\.js$'              "$committed"
  assert_eq "loose NOT committed" "0" "$(echo "$committed" | grep -c 'loose')"
  assert_eq "subject" "refactor(checkout): rename territory cart to checkout" "$(git -C "$root" log -1 --format=%s)"
}

# AC #12: rc 1 when nothing is staged for the given paths (a guard refusal, never
# a false-success empty commit).
case_jimledger_commit_rename_empty_stage_rc1() {
  local root; root="$(rename_git_fixture cr_empty)"
  run_jimledger_in "$root" commit-rename docs/specs cart checkout docs \
    docs/specs/cart/000-blueprint/spec.md
  assert_exit "rc" 1 "$RC"
}

# sec Finding 7: an unsafe stage path is refused before git runs (rc 1).
case_jimledger_commit_rename_unsafe_path_rc1() {
  local root; root="$(rename_git_fixture cr_unsafe)"
  run_jimledger_in "$root" commit-rename docs/specs cart checkout code ../escape
  assert_exit "rc" 1 "$RC"
}

# rc 2 on missing args (no stage token).
case_jimledger_commit_rename_missing_args() {
  local root; root="$(rename_git_fixture cr_ma)"
  run_jimledger_in "$root" commit-rename docs/specs cart checkout
  assert_exit "rc" 2 "$RC"
}

# rc 2 on an unrecognized stage token.
case_jimledger_commit_rename_bad_stage() {
  local root; root="$(rename_git_fixture cr_bs)"
  run_jimledger_in "$root" commit-rename docs/specs cart checkout sideways \
    docs/specs/cart/000-blueprint/spec.md
  assert_exit "rc" 2 "$RC"
}

# rc 2 when the code stage is given no explicit paths (the territory pair is
# never auto-derived — only the docs spec-dir pair is).
case_jimledger_commit_rename_code_needs_paths() {
  local root; root="$(rename_git_fixture cr_cnp)"
  run_jimledger_in "$root" commit-rename docs/specs cart checkout code
  assert_exit "rc" 2 "$RC"
}

# ─── spec 044: counter contract v3 (faces + attribution) + commit-verify mode ─

# AC: reconcile-series carries the four new counters — faces / faces_max
# (int-only) and the slug-validated attribution keys faces_max_group /
# fanin_group — through the EVENT payload (spec 044 Task 3, DD #4).
case_jimledger_reconcile_series_faces_attribution() {
  local sd; sd="$(empty_dir t44rsf/spec)"
  printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=5;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;groups=3;cycles=0;fanin=3;uncovered=0;faces=14;faces_max=9;faces_max_group=platform;fanin_group=platform\n' > "$sd/ledger.md"
  run_jimledger reconcile-series "$sd"
  assert_exit "rc" 0 "$RC"
  local ev; ev="$(printf '%s\n' "$OUT" | grep '^EVENT')"
  assert_match "faces carried"           'faces=14'                  "$ev"
  assert_match "faces_max carried"       'faces_max=9'               "$ev"
  assert_match "faces_max_group carried" 'faces_max_group=platform'  "$ev"
  assert_match "fanin_group carried"     'fanin_group=platform'      "$ev"
}

# AC: the attribution keys are slug-list validated — a sorted comma-joined
# multi-slug value is accepted; a non-slug element makes the event malformed
# (EXCLUDED); faces is int-only so `na` is malformed (spec 044 Task 3, DD #4).
case_jimledger_reconcile_series_attribution_validation() {
  local sd; sd="$(empty_dir t44rsav/spec)"
  printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=1;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;faces=4;faces_max=2;faces_max_group=orders,shipping\n' > "$sd/ledger.md"
  run_jimledger reconcile-series "$sd"
  assert_match "multi-slug accepted" 'faces_max_group=orders,shipping' "$(printf '%s\n' "$OUT" | grep '^EVENT')"
  printf '200\t2026-02-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=1;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;faces=4;faces_max=2;faces_max_group=Platform\n' > "$sd/ledger.md"
  run_jimledger reconcile-series "$sd"
  assert_exit "malformed slug rc" 1 "$RC"
  assert_match "names attribution key" 'bad-value:faces_max_group' "$(printf '%s\n' "$OUT" | grep '^EXCLUDED')"
  printf '300\t2026-03-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=1;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;faces=na;faces_max=0\n' > "$sd/ledger.md"
  run_jimledger reconcile-series "$sd"
  assert_match "faces na excluded (int-only)" 'bad-value:faces' "$(printf '%s\n' "$OUT" | grep '^EXCLUDED')"
}

# AC: last-reconcile also carries the four new counters — the shared 15-key
# whitelist means both verbs validate against one contract (spec 044 Task 3).
case_jimledger_last_reconcile_faces_attribution() {
  local sd; sd="$(empty_dir t44lrf/spec)"
  printf '100\t2026-01-01T00:00:00Z\tblueprint\tfinished\ttier=project;op=reconcile;edges=5;leaks=0;breaking=0;dead=0;unresolved=0;undeclared=0;stale=0;groups=3;cycles=0;fanin=3;uncovered=0;faces=14;faces_max=9;faces_max_group=platform;fanin_group=platform\n' > "$sd/ledger.md"
  run_jimledger last-reconcile "$sd"
  assert_exit "rc" 0 "$RC"
  assert_match "faces present"           '^faces=14$'                 "$OUT"
  assert_match "faces_max present"       '^faces_max=9$'              "$OUT"
  assert_match "faces_max_group present" '^faces_max_group=platform$' "$OUT"
  assert_match "fanin_group present"     '^fanin_group=platform$'     "$OUT"
}

# AC: commit-verify's health mode selects the partition-health subject; verify
# (explicit or default) keeps the verification subject; an unrecognized mode is
# rejected rc 2 with no commit (spec 044 Task 3, DD #6).
case_jimledger_commit_verify_health_mode() {
  local sd root; sd="$(git_fixture t44cvh)"; root="${sd%/spec}"
  printf 'l\n' > "$sd/ledger.md"
  run_jimledger commit-verify "$sd" health
  assert_exit "health rc" 0 "$RC"
  assert_eq "health subject" "chore(health): record partition-health run" "$(git -C "$root" log -1 --format=%s)"
}

case_jimledger_commit_verify_mode_whitelist() {
  local sd root; sd="$(git_fixture t44cvm)"; root="${sd%/spec}"
  printf 'l\n' > "$sd/ledger.md"
  run_jimledger commit-verify "$sd" verify
  assert_exit "verify rc" 0 "$RC"
  assert_eq "verify subject" "chore(verify): record verification run" "$(git -C "$root" log -1 --format=%s)"
  printf 'l2\n' > "$sd/ledger.md"
  run_jimledger commit-verify "$sd" 'x`touch /tmp/nope`'
  assert_exit "bad-mode rc" 2 "$RC"
  assert_eq "no new commit landed" "chore(verify): record verification run" "$(git -C "$root" log -1 --format=%s)"
}

# ─── spec 047: move-spec-dir (cross-parent guarded git mv) ───────────────────

# move_git_fixture <name> — a git repo with one tracked numbered spec dir under a
#   group (docs/specs/cart/006-foo), one commit. Print the repo root.
move_git_fixture() {
  local name="$1"; local root="$TMP_BASE/$name"
  mkdir -p "$root/docs/specs/cart/006-foo"
  git -C "$root" init -q
  git -C "$root" config user.email "test@example.com"
  git -C "$root" config user.name "Test"
  git -C "$root" config commit.gpgsign false
  printf '# foo\n' > "$root/docs/specs/cart/006-foo/spec.md"
  git -C "$root" add -A
  git -C "$root" commit -q -m "seed"
  printf '%s' "$root"
}

# security Finding 1: the happy cross-parent move+renumber — cart/006-foo becomes
# checkout/001-foo in one history-continuous git mv, staged (the primitive
# rename-tracked structurally refuses).
case_jimledger_move_spec_dir_moves() {
  local root; root="$(move_git_fixture msd_ok)"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo checkout 001-foo
  assert_exit "rc" 0 "$RC"
  assert_eq "old gone"   "0" "$([[ -e "$root/docs/specs/cart/006-foo" ]] && echo 1 || echo 0)"
  assert_eq "new exists" "1" "$([[ -f "$root/docs/specs/checkout/001-foo/spec.md" ]] && echo 1 || echo 0)"
  assert_match "staged move visible" 'docs/specs/checkout/001-foo/spec\.md' \
    "$(git -C "$root" diff --cached --name-only)"
}

# security Finding 1: an endpoint that resolves inside the worktree but OUTSIDE the
# specs subtree is refused — the specs-scoping bound that keeps this from
# relocating an arbitrary repo file.
case_jimledger_move_spec_dir_refuses_outside_specs() {
  local root; root="$(move_git_fixture msd_out)"
  mkdir -p "$root/modules"
  ln -s ../../modules "$root/docs/specs/sneaky"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo sneaky 001-foo
  assert_exit "rc" 1 "$RC"
  assert_nonempty "names the refusal" "$ERR"
}

# security Finding 1: refuses an untracked source — move-spec-dir only moves what
# git already tracks (history-continuous).
case_jimledger_move_spec_dir_refuses_untracked_src() {
  local root; root="$(move_git_fixture msd_unt)"
  mkdir -p "$root/docs/specs/cart/007-bar"
  printf 'x\n' > "$root/docs/specs/cart/007-bar/spec.md"   # on disk, never added
  run_jimledger_in "$root" move-spec-dir docs/specs cart 007-bar checkout 001-bar
  assert_exit "rc" 1 "$RC"
}

# security Finding 1: refuses when the destination already exists (never clobbers).
case_jimledger_move_spec_dir_refuses_existing_dst() {
  local root; root="$(move_git_fixture msd_ex)"
  mkdir -p "$root/docs/specs/checkout/001-foo"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo checkout 001-foo
  assert_exit "rc" 1 "$RC"
}

# security Finding 1: a basename that is not an NNN-slug / NNN-wip spec-dir shape
# is refused (bounds the move to spec directories).
case_jimledger_move_spec_dir_refuses_bad_basename() {
  local root; root="$(move_git_fixture msd_bb)"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo checkout foo
  assert_exit "rc" 1 "$RC"
}

# security Finding 1: a '..'-segment specs-dir is rejected by the valid-relpath
# boundary before any git.
case_jimledger_move_spec_dir_refuses_dotdot() {
  local root; root="$(move_git_fixture msd_dd)"
  run_jimledger_in "$root" move-spec-dir ../escape cart 006-foo checkout 001-foo
  assert_exit "rc" 1 "$RC"
}

# security Finding 1: a group dir symlinked OUT of the worktree is refused — the
# containment guard resolves the symlink before git runs.
case_jimledger_move_spec_dir_refuses_symlink_escape() {
  local root; root="$(move_git_fixture msd_sym)"
  mkdir -p "$TMP_BASE/msd_outside"
  ln -s "$TMP_BASE/msd_outside" "$root/docs/specs/out"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo out 001-foo
  assert_exit "rc" 1 "$RC"
}

# rc 2 on a missing argument (usage, distinct from a guard refusal).
case_jimledger_move_spec_dir_usage_rc2() {
  local root; root="$(move_git_fixture msd_ma)"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo checkout
  assert_exit "rc" 2 "$RC"
}

# ─── spec 047: vacated-max (vacated-id floor source) ─────────────────────────

# security Finding 2: the floor is the highest OLD number a split vacated FROM the
# group — here cart/006..009 left, so vacated-max cart is 009 (3-digit).
case_jimledger_vacated_max_floors_from_event() {
  local sd; sd="$(empty_dir vm_one/spec)"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=cart,checkout;identity=rewrite;frozen=0;outcome=split;moved=cart/006:checkout/001,cart/007:checkout/002,cart/008:checkout/003,cart/009:checkout/004\n' > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" cart
  assert_exit "rc" 0 "$RC"
  assert_eq "max vacated" "009" "$OUT"
}

# DD 5: the remap is chunked across repeatable moved= pairs (≤256B each) — every
# pair is iterated, so a number in a later chunk still raises the floor.
case_jimledger_vacated_max_iterates_multiple_moved_pairs() {
  local sd; sd="$(empty_dir vm_multi/spec)"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=cart,checkout;moved=cart/006:checkout/001,cart/007:checkout/002;moved=cart/011:checkout/003\n' > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" cart
  assert_exit "rc" 0 "$RC"
  assert_eq "max across chunks" "011" "$OUT"
}

# security Finding 2: a malformed element is inert — ignored — while valid
# siblings still count (fail-closed: the floor only ever raises).
case_jimledger_vacated_max_ignores_malformed_element() {
  local sd; sd="$(empty_dir vm_bad/spec)"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=cart,checkout;moved=cart/006:checkout/001,GARBAGE,cart/0099:x,cart/009:checkout/002\n' > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" cart
  assert_exit "rc" 0 "$RC"
  assert_eq "valid siblings still counted" "009" "$OUT"
}

# security Finding 2: an op=rename-only ledger carries no split remap — the
# whitelisted op=split gate yields nothing (a rename event is invisible here).
case_jimledger_vacated_max_rename_only_empty() {
  local sd; sd="$(empty_dir vm_ren/spec)"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=rename;old=cart;new=checkout\n' > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" cart
  assert_exit "rc" 0 "$RC"
  assert_eq "empty" "" "$OUT"
}

# rc 1 when there is no ledger file (next-id degrades to dir-only behavior).
case_jimledger_vacated_max_no_ledger_rc1() {
  local sd; sd="$(empty_dir vm_noledger/spec)"
  run_jimledger vacated-max "$sd" cart
  assert_exit "rc" 1 "$RC"
}

# AC 19: the remap ledger event round-trips end-to-end — an op=split event written
# through the real `event` verb (not a hand-crafted ledger line) is read back by
# vacated-max, proving the emit grammar and the parse grammar agree.
case_jimledger_vacated_max_event_roundtrip() {
  local sd; sd="$(empty_dir vm_rt/spec)"
  run_jimledger event "$sd" partition finished \
    tier=project op=split old=cart new=cart,checkout \
    moved=cart/006:checkout/001,cart/009:checkout/004
  assert_exit "event rc" 0 "$RC"
  run_jimledger vacated-max "$sd" cart
  assert_exit "vacated-max rc" 0 "$RC"
  assert_eq "floor read back from the emitted event" "009" "$OUT"
}

# rc 2 on a missing arg or an invalid group slug (usage, distinct from no-ledger).
case_jimledger_vacated_max_bad_group_rc2() {
  local sd; sd="$(empty_dir vm_badgrp/spec)"
  printf 'x\n' > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" "Cart_Group"
  assert_exit "invalid slug rc" 2 "$RC"
  run_jimledger vacated-max "$sd"
  assert_exit "missing arg rc" 2 "$RC"
}

# ─── spec 048: vacated-max accepts op=merge ──────────────────────────────────

# AC 15: vacated-max reads op=merge events under the same fail-closed element
# parse — an absorbed source's old ids are vacated, so a re-minted source slug
# later floors past its historical max (the retirement dual of split's vacated
# ids). Here wishlist/001..002 were absorbed into cart, so vacated-max wishlist
# is 002.
case_jimledger_vacated_max_floors_from_merge_event() {
  local sd; sd="$(empty_dir vm_merge/spec)"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=wishlist,cart;new=cart;identity=rewrite;frozen=0;outcome=merged;moved=wishlist/001:cart/007,wishlist/002:cart/008\n' > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" wishlist
  assert_exit "rc" 0 "$RC"
  assert_eq "max vacated from absorbed source" "002" "$OUT"
}

# AC 14 / DD 5: a many-source merge emits more moved= pairs than a split; the
# repeatable ≤256B chunk grammar covers it — a number in a later chunk still
# raises the merge floor.
case_jimledger_vacated_max_merge_multichunk() {
  local sd; sd="$(empty_dir vm_merge_mc/spec)"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=wishlist,cart;new=cart;moved=wishlist/001:cart/007,wishlist/002:cart/008;moved=wishlist/005:cart/009\n' > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" wishlist
  assert_exit "rc" 0 "$RC"
  assert_eq "max across merge chunks" "005" "$OUT"
}

# security Finding 3: the op=merge widening reuses split's fail-closed element
# parse byte for byte — a malformed element is inert while valid siblings still
# count (the floor only ever raises).
case_jimledger_vacated_max_merge_ignores_malformed() {
  local sd; sd="$(empty_dir vm_merge_bad/spec)"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=wishlist,cart;new=cart;moved=wishlist/001:cart/007,GARBAGE,wishlist/0099:x,wishlist/004:cart/008\n' > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" wishlist
  assert_exit "rc" 0 "$RC"
  assert_eq "valid siblings still counted" "004" "$OUT"
}

# security Finding 3: the floor is monotonic across events — a later op=merge
# carrying a LOWER vacated id never lowers the floor an earlier event raised
# (global max wins).
case_jimledger_vacated_max_merge_monotonic() {
  local sd; sd="$(empty_dir vm_merge_mono/spec)"
  {
    printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=wishlist,cart;new=cart;moved=wishlist/008:cart/007\n'
    printf '200\t2026-02-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=wishlist,cart;new=cart;moved=wishlist/003:cart/009\n'
  } > "$sd/ledger.md"
  run_jimledger vacated-max "$sd" wishlist
  assert_exit "rc" 0 "$RC"
  assert_eq "highest across events wins" "008" "$OUT"
}

# ─── spec 047: commit-split (the split's docs commit) ────────────────────────

# DD 9 / security Finding 7: commit-split stages EXACTLY the explicit set — the
# moved spec-dir pair (old deletion, already staged by move-spec-dir; new add) and
# an authored child blueprint — while unrelated dirt never rides it. The subject
# is composed in-script from the slug-validated old + targets.
case_jimledger_commit_split_scoped() {
  local root; root="$(move_git_fixture cs_ok)"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo checkout 001-foo
  assert_exit "move rc" 0 "$RC"
  mkdir -p "$root/docs/specs/checkout/000-blueprint"
  printf '# checkout\n' > "$root/docs/specs/checkout/000-blueprint/spec.md"   # new child blueprint
  printf 'unrelated\n'  > "$root/loose.txt"                                    # unrelated dirt
  run_jimledger_in "$root" commit-split docs/specs cart cart,checkout \
    docs/specs/cart/006-foo docs/specs/checkout/001-foo \
    docs/specs/checkout/000-blueprint/spec.md
  assert_exit "rc" 0 "$RC"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "moved dir committed"       'docs/specs/checkout/001-foo/spec\.md'        "$committed"
  assert_match "child blueprint committed" 'docs/specs/checkout/000-blueprint/spec\.md'  "$committed"
  assert_eq "old path gone from HEAD tree" "0" "$(git -C "$root" ls-tree -r --name-only HEAD | grep -c '^docs/specs/cart/006')"
  assert_eq "loose NOT committed" "0" "$(echo "$committed" | grep -c 'loose')"
  assert_eq "subject" "docs(specs): split group cart into cart, checkout" "$(git -C "$root" log -1 --format=%s)"
}

# rc 1 when nothing is staged for the given paths (a guard refusal, never a
# false-success empty commit).
case_jimledger_commit_split_empty_stage_rc1() {
  local root; root="$(move_git_fixture cs_empty)"
  run_jimledger_in "$root" commit-split docs/specs cart cart,checkout docs/specs/cart/006-foo
  assert_exit "rc" 1 "$RC"
}

# security Finding 7: an unsafe stage path is refused before git runs (rc 1).
case_jimledger_commit_split_unsafe_path_rc1() {
  local root; root="$(move_git_fixture cs_unsafe)"
  run_jimledger_in "$root" commit-split docs/specs cart cart,checkout ../escape
  assert_exit "rc" 1 "$RC"
}

# rc 2 on usage: no explicit paths, or a target set below the split arity of two.
case_jimledger_commit_split_usage_rc2() {
  local root; root="$(move_git_fixture cs_ma)"
  run_jimledger_in "$root" commit-split docs/specs cart cart,checkout
  assert_exit "no paths rc" 2 "$RC"
  run_jimledger_in "$root" commit-split docs/specs cart cart docs/specs/cart/006-foo
  assert_exit "arity<2 rc" 2 "$RC"
}

# ─── spec 048: commit-merge (the merge's docs commit) ────────────────────────

# AC 17 / DD 7: commit-merge stages EXACTLY the explicit set — the moved source
# spec-dir pair (old deletion already staged by move-spec-dir; new add) and the
# fused target blueprint — while unrelated dirt never rides it. The subject is
# composed in-script from the slug-validated target + sources.
case_jimledger_commit_merge_scoped() {
  local root; root="$(move_git_fixture cm_ok)"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo shopping 001-foo
  assert_exit "move rc" 0 "$RC"
  mkdir -p "$root/docs/specs/shopping/000-blueprint"
  printf '# shopping\n' > "$root/docs/specs/shopping/000-blueprint/spec.md"   # fused blueprint
  printf 'unrelated\n'  > "$root/loose.txt"                                    # unrelated dirt
  run_jimledger_in "$root" commit-merge docs/specs shopping cart \
    docs/specs/cart/006-foo docs/specs/shopping/001-foo \
    docs/specs/shopping/000-blueprint/spec.md
  assert_exit "rc" 0 "$RC"
  local committed; committed="$(git -C "$root" show --name-only --format= HEAD)"
  assert_match "moved dir committed"    'docs/specs/shopping/001-foo/spec\.md'       "$committed"
  assert_match "blueprint committed"    'docs/specs/shopping/000-blueprint/spec\.md' "$committed"
  assert_eq "old path gone from HEAD tree" "0" "$(git -C "$root" ls-tree -r --name-only HEAD | grep -c '^docs/specs/cart/006')"
  assert_eq "loose NOT committed" "0" "$(echo "$committed" | grep -c 'loose')"
  assert_eq "subject" "docs(specs): merge cart into shopping" "$(git -C "$root" log -1 --format=%s)"
}

# AC 8 / DD 7: the fresh-target arm names every source in the subject — sources
# joined comma-separated, composed only from the slug-validated csv.
case_jimledger_commit_merge_multisource_subject() {
  local root; root="$(move_git_fixture cm_multi)"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo shopping 001-foo
  assert_exit "move rc" 0 "$RC"
  run_jimledger_in "$root" commit-merge docs/specs shopping cart,wishlist \
    docs/specs/cart/006-foo docs/specs/shopping/001-foo
  assert_exit "rc" 0 "$RC"
  assert_eq "subject names both sources" "docs(specs): merge cart,wishlist into shopping" "$(git -C "$root" log -1 --format=%s)"
}

# AC 6 / security Finding 7: the optional --rekey channel renders invariant-id
# lineage pairs into the commit BODY in-script (the durable ratchet-break
# record), each half charset-gated; the subject is unchanged.
case_jimledger_commit_merge_rekey_body() {
  local root; root="$(move_git_fixture cm_rekey)"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo shopping 001-foo
  assert_exit "move rc" 0 "$RC"
  run_jimledger_in "$root" commit-merge docs/specs shopping cart \
    --rekey config:shopping-config,gift-flag:gift-marker \
    docs/specs/cart/006-foo docs/specs/shopping/001-foo
  assert_exit "rc" 0 "$RC"
  local body; body="$(git -C "$root" log -1 --format=%b)"
  assert_match "first rekey pair in body"  'config -> shopping-config' "$body"
  assert_match "second rekey pair in body" 'gift-flag -> gift-marker'   "$body"
  assert_eq "subject unchanged by rekey" "docs(specs): merge cart into shopping" "$(git -C "$root" log -1 --format=%s)"
}

# security Finding 7: a malformed --rekey token (uppercase half, no colon, or a
# double colon) is refused rc 2 before any commit — no free text reaches the
# audited commit body.
case_jimledger_commit_merge_rekey_malformed_rc2() {
  local root; root="$(move_git_fixture cm_rekbad)"
  run_jimledger_in "$root" move-spec-dir docs/specs cart 006-foo shopping 001-foo
  assert_exit "move rc" 0 "$RC"
  run_jimledger_in "$root" commit-merge docs/specs shopping cart --rekey 'Config:x' \
    docs/specs/cart/006-foo docs/specs/shopping/001-foo
  assert_exit "uppercase half rc" 2 "$RC"
  run_jimledger_in "$root" commit-merge docs/specs shopping cart --rekey 'nocolon' \
    docs/specs/cart/006-foo docs/specs/shopping/001-foo
  assert_exit "no colon rc" 2 "$RC"
  run_jimledger_in "$root" commit-merge docs/specs shopping cart --rekey 'a:b:c' \
    docs/specs/cart/006-foo docs/specs/shopping/001-foo
  assert_exit "double colon rc" 2 "$RC"
  assert_eq "no commit landed" "seed" "$(git -C "$root" log -1 --format=%s)"
}

# DD 7: an invalid target or source slug is refused rc 2 — the subject is only
# ever composed from slug-validated tokens.
case_jimledger_commit_merge_bad_slug_rc2() {
  local root; root="$(move_git_fixture cm_slug)"
  run_jimledger_in "$root" commit-merge docs/specs "Shopping" cart docs/specs/cart/006-foo
  assert_exit "bad target rc" 2 "$RC"
  run_jimledger_in "$root" commit-merge docs/specs shopping "Cart_X" docs/specs/cart/006-foo
  assert_exit "bad source rc" 2 "$RC"
}

# rc 2 on usage: no explicit paths after the positional trio.
case_jimledger_commit_merge_usage_rc2() {
  local root; root="$(move_git_fixture cm_usage)"
  run_jimledger_in "$root" commit-merge docs/specs shopping cart
  assert_exit "no paths rc" 2 "$RC"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_JIMLEDGER" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_JIMLEDGER — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
