#!/usr/bin/env bash
#
# tests/metatest.sh — Tests for skills/meta-test/scripts/metatest.sh
#
# WHAT THIS FILE TESTS
#   The metatest.sh dispatcher: scaffold/add/run subcommands, name validation,
#   conflict refusals, exit-code semantics. Cases that exercise scaffold or
#   add use a per-case sandbox under $TMP_BASE with an empty tests/ subdir
#   and a symlinked skills/ pointing at the real $REPO_ROOT/skills (so the
#   asset template and runner resolve correctly from inside the sandbox).
#
# HOW TO RUN
#   bash tests/metatest.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_METATEST="$REPO_ROOT/skills/meta-test/scripts/metatest.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_metatest <args...>
#   Invoke metatest.sh from PWD; capture stdout/stderr/rc into OUT/ERR/RC.
#   Same shape as `run` / `run_jimfile` in sibling test files.
run_metatest() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_METATEST" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# run_metatest_in <sandbox-dir> <args...>
#   Like run_metatest but with cwd = sandbox (subshell `cd` per testlib
#   maintenance note 4). Used by scaffold/add cases that write into the
#   sandbox's tests/ rather than the real one.
run_metatest_in() {
  local sandbox=$1; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$sandbox" && bash "$SCRIPT_METATEST" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# metatest_sandbox <name>
#   Create a sandbox dir under TMP_BASE with empty tests/ and a skills/
#   symlink pointing at the real $REPO_ROOT/skills (so scaffold template
#   and runner resolve correctly from inside the sandbox). Returns the
#   absolute path on stdout.
metatest_sandbox() {
  local name=$1
  local d
  d=$(empty_dir "metatest-sandbox-$name")
  mkdir -p "$d/tests"
  ln -s "$REPO_ROOT/skills" "$d/skills"
  printf '%s' "$d"
}

# ─── Section: Test cases ─────────────────────────────────────────────────────

# AC: scaffold creates tests/<name>.sh from the asset template.
case_metatest_scaffold_creates_file_from_template() {
  local sb; sb=$(metatest_sandbox "create-from-template")
  run_metatest_in "$sb" scaffold widget
  assert_exit "rc" 0 "$RC"
  if [[ ! -f "$sb/tests/widget.sh" ]]; then
    CURRENT_FAILED=1
    echo "    [scaffolded file] expected $sb/tests/widget.sh to exist"
  fi
}

# AC: scaffold substitutes __NAME__ with the script-under-test name.
case_metatest_scaffold_substitutes_name_placeholder() {
  local sb; sb=$(metatest_sandbox "name-placeholder")
  run_metatest_in "$sb" scaffold widget
  assert_exit "rc" 0 "$RC"
  local content
  content=$(cat "$sb/tests/widget.sh" 2>/dev/null || true)
  assert_match "case prefix" '^case_widget_' "$content"
  assert_match "invoker name" '^run_widget' "$content"
  if echo "$content" | grep -q '__NAME__'; then
    CURRENT_FAILED=1
    echo "    [name placeholder] __NAME__ remained unsubstituted"
  fi
}

# AC: scaffold substitutes __SCRIPT_PATH__ with skills/CHANGEME/scripts/<name>.sh.
case_metatest_scaffold_substitutes_script_path_placeholder() {
  local sb; sb=$(metatest_sandbox "script-path-placeholder")
  run_metatest_in "$sb" scaffold widget
  assert_exit "rc" 0 "$RC"
  local content
  content=$(cat "$sb/tests/widget.sh" 2>/dev/null || true)
  assert_match "script path" 'skills/CHANGEME/scripts/widget.sh' "$content"
  if echo "$content" | grep -q '__SCRIPT_PATH__'; then
    CURRENT_FAILED=1
    echo "    [script path placeholder] __SCRIPT_PATH__ remained unsubstituted"
  fi
}

# AC: scaffold refuses to overwrite an existing file (exit 1, stderr names file).
case_metatest_scaffold_refuses_on_existing_file_exit_1() {
  local sb; sb=$(metatest_sandbox "refuse-existing")
  : > "$sb/tests/widget.sh"
  run_metatest_in "$sb" scaffold widget
  assert_exit "rc" 1 "$RC"
  assert_match "stderr names file" 'tests/widget\.sh' "$ERR"
  assert_match "stderr says exists" 'already exists' "$ERR"
}

# AC: scaffold rejects names with hyphens (not a valid bash identifier).
case_metatest_scaffold_rejects_bad_name_with_hyphen() {
  local sb; sb=$(metatest_sandbox "reject-hyphen")
  run_metatest_in "$sb" scaffold "bad-name"
  assert_exit "rc" 1 "$RC"
  assert_nonempty "stderr non-empty" "$ERR"
  if [[ -f "$sb/tests/bad-name.sh" ]]; then
    CURRENT_FAILED=1
    echo "    [no file written] tests/bad-name.sh should not exist"
  fi
}

# AC: scaffold rejects path-traversal names.
case_metatest_scaffold_rejects_bad_name_path_traversal() {
  local sb; sb=$(metatest_sandbox "reject-traversal")
  run_metatest_in "$sb" scaffold "../etc/passwd"
  assert_exit "rc" 1 "$RC"
  assert_nonempty "stderr non-empty" "$ERR"
}

# AC: scaffolded file is executable (chmod +x applied).
case_metatest_scaffold_makes_file_executable() {
  local sb; sb=$(metatest_sandbox "executable")
  run_metatest_in "$sb" scaffold widget
  assert_exit "rc" 0 "$RC"
  if [[ ! -x "$sb/tests/widget.sh" ]]; then
    CURRENT_FAILED=1
    echo "    [executable] tests/widget.sh missing +x"
  fi
}

# AC: add appends a case_<name>_<case>() stub to the existing file.
case_metatest_add_appends_case_function() {
  local sb; sb=$(metatest_sandbox "add-appends")
  run_metatest_in "$sb" scaffold widget
  assert_exit "rc-scaffold" 0 "$RC"
  run_metatest_in "$sb" add widget handles_empty_input
  assert_exit "rc-add" 0 "$RC"
  local content
  content=$(cat "$sb/tests/widget.sh" 2>/dev/null || true)
  assert_match "appended case" '^case_widget_handles_empty_input' "$content"
}

# AC: add refuses if the case already exists (exit 2, stderr names conflict).
case_metatest_add_refuses_duplicate_case_exit_2() {
  local sb; sb=$(metatest_sandbox "add-duplicate")
  run_metatest_in "$sb" scaffold widget
  run_metatest_in "$sb" add widget handles_empty_input
  run_metatest_in "$sb" add widget handles_empty_input
  assert_exit "rc-second-add" 2 "$RC"
  assert_match "stderr names conflict" 'case_widget_handles_empty_input' "$ERR"
  assert_match "stderr says exists" 'already exists' "$ERR"
}

# AC: add refuses if the test file does not exist (exit 1, stderr).
case_metatest_add_refuses_missing_file_exit_1() {
  local sb; sb=$(metatest_sandbox "add-missing")
  run_metatest_in "$sb" add nofile some_case
  assert_exit "rc" 1 "$RC"
  assert_match "stderr names file" 'tests/nofile\.sh' "$ERR"
  assert_match "stderr says missing" 'does not exist' "$ERR"
}

# AC: run with no args invokes the aggregate runner. Sandbox tests/ is empty
# so the runner reports zero cases and exits 0 — proves dispatch worked
# without running the real suite (which would recurse via tests/metatest.sh).
case_metatest_run_no_args_invokes_aggregate_runner() {
  local sb; sb=$(metatest_sandbox "run-no-args")
  run_metatest_in "$sb" run
  assert_exit "rc" 0 "$RC"
  assert_match "ran header" 'Ran [0-9]+ tests' "$OUT"
}

# AC: run with a name dispatches to the standalone path when the file exists.
# Sandbox: scaffold widget, run widget. The scaffolded smoke case is a
# placeholder assertion that passes — proves the standalone path executed.
case_metatest_run_with_name_invokes_standalone_path() {
  local sb; sb=$(metatest_sandbox "run-with-name")
  run_metatest_in "$sb" scaffold widget
  assert_exit "rc-scaffold" 0 "$RC"
  run_metatest_in "$sb" run widget
  assert_exit "rc-run" 0 "$RC"
  assert_match "smoke case ran" 'PASS - case_widget_smoke' "$OUT"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# This file works two ways:
#   1. bash tests/metatest.sh        → runs only this file's cases (standalone).
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
  if [[ ! -e "$SCRIPT_METATEST" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_METATEST — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
