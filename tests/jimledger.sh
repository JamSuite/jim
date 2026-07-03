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

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_JIMLEDGER" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_JIMLEDGER — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
