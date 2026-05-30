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

# AC: index.sh on an empty dir writes INDEX.md with zero counts (spec 017 AC-I1, AC-R2)
case_issues_index_empty_dir() {
  local dir
  dir=$(empty_dir index_empty)
  run_index "$dir"
  assert_exit "rc"            0          "$RC"
  assert_match "summary open"   "Open: 0"   "$(cat "$dir/INDEX.md")"
  assert_match "summary closed" "Closed: 0" "$(cat "$dir/INDEX.md")"
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
