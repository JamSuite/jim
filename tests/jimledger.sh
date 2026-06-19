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

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_JIMLEDGER" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_JIMLEDGER — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
