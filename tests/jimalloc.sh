#!/usr/bin/env bash
#
# tests/jimalloc.sh — Tests for skills/file/scripts/jimalloc.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# WHAT THIS FILE TESTS
#   The jimalloc.sh ID-coordination allocator: subcommand dispatch/usage, the
#   pure record layer (grammar parse, emit-encode, forward-replay resolution),
#   next-id/next-num + durable-id guard, the two-tier compare-and-swap (local
#   update-ref, origin push non-fast-forward), the erosion growth guard,
#   config wiring + failure semantics, write-containment, and peek.
#
# HOW TO RUN
#   bash tests/jimalloc.sh                  # every case in this file
#   bash tests/jimalloc.sh usage            # only cases whose name contains "usage"
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_jimalloc="$REPO_ROOT/skills/file/scripts/jimalloc.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_jimalloc <args...>
#   Invoke the allocator; capture stdout, stderr, and exit code into the
#   globals OUT, ERR, RC. Same shape as run/run_jimfile in sibling files.
run_jimalloc() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_jimalloc" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Usage / dispatch ───────────────────────────────────────────────

# AC: no subcommand → usage error on stderr, rc 2, clean stdout.
case_jimalloc_no_args_usage() {
  run_jimalloc
  assert_exit     "no-arg rc"       2  "$RC"
  assert_eq       "stdout empty"    "" "$OUT"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: unknown subcommand → usage error on stderr, rc 2, clean stdout.
case_jimalloc_unknown_verb_usage() {
  run_jimalloc bogus-verb
  assert_exit     "unknown rc"      2  "$RC"
  assert_eq       "stdout empty"    "" "$OUT"
  assert_nonempty "stderr explains" "$ERR"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# Dual-mode: direct invocation runs this file's cases; the aggregate runner
# sources it alongside every other tests/*.sh. See the testlib.sh header and
# the meta-test scaffold template for why the BASH_SOURCE guard is shaped this
# way — do not "tidy" it.
#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_jimalloc" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_jimalloc — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
