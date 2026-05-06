#!/usr/bin/env bash
#
# skills/meta-test/scripts/testlib.sh — Shared test framework for jim's plain-bash
#   test suite. THIS FILE IS THE CANONICAL CONVENTIONS REFERENCE for jim bash
#   tests. The /jim:meta-test scaffold template cites this header rather than
#   restating the rules. Keep this header accurate.
#
# WHAT THIS FILE PROVIDES
#   - Globals (REPO_ROOT, TMP_BASE, OUT/ERR/RC, pass/fail counters, FILTER)
#   - Assert helpers (assert_eq, assert_match, assert_exit, assert_nonempty)
#   - Setup helpers (fixture, empty_dir)
#   - Reporter (`run_discovered_cases`) that finds every `case_*` function
#     defined since this file was sourced, applies the FILTER substring
#     match, runs each case, and prints a summary.
#
# DESIGN CONTRACT
#   - Sourced — never invoked directly. Per-script test files (e.g.
#     tests/jimconf.sh, tests/jimfile.sh, tests/metatest.sh) source this and
#     add `case_*` functions. The aggregate runner
#     (skills/meta-test/scripts/run.sh) sources this once, then sources
#     every `tests/*.sh` from the project root.
#   - Discovery is by function-name convention: any function whose name
#     starts with `case_` is a test. No TESTS=() registration array.
#   - Each per-script file owns its `run` invoker (e.g. `run`, `run_jimfile`)
#     because it is per-script bash-fu — which script to invoke and how to
#     capture its output. Keeping it out of the lib keeps the lib generic.
#   - Zero third-party dependencies. Bash + POSIX tools only.
#   - No source/eval of user-supplied content (security boundary).
#   - `set -uo pipefail` (NOT `set -e` — interacts badly with the
#     `OUT=$(...)` capture pattern the per-script invokers use).
#
# HOW TO ADD A NEW TEST FILE
#   Preferred: use /jim:meta-test scaffold <name>. The skill writes the file
#   in the conventional shape (header, source, invoker stub, smoke case,
#   standalone-runnable tail) using the asset template at
#   skills/meta-test/assets/test-file.sh.tmpl.
#
#   By hand (if needed):
#   1. Create `tests/<name>.sh`. First content lines:
#        #!/usr/bin/env bash
#        set -uo pipefail
#        HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#        source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"
#   2. Define a per-script invoker (`run_<name>() { ... }`) that captures
#      stdout/stderr/rc into OUT/ERR/RC, plus your `case_<name>_*`
#      functions. Each case begins with a `# AC: <spec acceptance
#      criterion>` comment.
#   3. Add a standalone-runnable tail (see existing test files for the
#      exact form — uses `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` to detect
#      direct invocation vs aggregate-runner sourcing):
#        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#          FILTER="${1:-}"
#          run_discovered_cases
#        fi
#      Then `chmod +x tests/<name>.sh`. The aggregate runner picks it up
#      automatically; standalone invocation works the same way.
#
# EXIT CODE SEMANTICS  (set by `run_discovered_cases`)
#   0   every selected test passed
#   1   at least one test failed
#   2   reserved for setup error (mkdir/mktemp failure during sourcing)
#

set -uo pipefail

# ─── Section: Globals ────────────────────────────────────────────────────────

# REPO_ROOT: project root, computed BASH_SOURCE-relative so the lib works
# whether invoked from the repo root, from a per-script test file, or from
# the aggregate runner. This file lives at skills/meta-test/scripts/ —
# three levels up to reach the repo root. Per-script test files use this
# to locate their script-under-test (e.g. $REPO_ROOT/skills/conf/scripts/jimconf.sh).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Per-runner sandbox. Every fixture and scratch dir lives under TMP_BASE.
# Single TMP_BASE shared across all sourced test files — they don't conflict
# because each test uses unique relative names via `fixture` / `empty_dir`.
TMP_BASE="$(mktemp -d -t jim-tests.XXXXXX)" || exit 2
trap 'rm -rf "$TMP_BASE"' EXIT

# Captured by per-script `run_*` invokers. Pre-initialized so `set -u` doesn't
# trip when a case inspects them before its first `run_*` call.
OUT=""
ERR=""
RC=0

PASS_COUNT=0
FAIL_COUNT=0
CURRENT_FAILED=0

# Filter applied by `run_discovered_cases`: only cases whose function name
# contains FILTER are run. Empty string = run all. Each entry point sets
# FILTER from its own $1 before calling run_discovered_cases.
FILTER="${FILTER:-}"

# ─── Section: Assert helpers ─────────────────────────────────────────────────

# assert_eq <label> <expected> <actual>
#   Mark the current case as failed if expected != actual.
#   Example: assert_eq "specs default" "docs/specs" "$OUT"
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    return 0
  fi
  CURRENT_FAILED=1
  echo "    [$label] expected [$expected], got [$actual]"
  return 1
}

# assert_match <label> <regex> <actual>
#   Mark current case as failed if actual does not match the POSIX-extended
#   regex on any line. (Multi-line OUT is matched line-by-line by grep.)
#   Example: assert_match "absolute path" '^/' "$OUT"
assert_match() {
  local label="$1" regex="$2" actual="$3"
  if echo "$actual" | grep -Eq "$regex"; then
    return 0
  fi
  CURRENT_FAILED=1
  echo "    [$label] [$actual] did not match /$regex/"
  return 1
}

# assert_exit <label> <expected_rc> <actual_rc>
#   Mark current case as failed if exit codes differ.
#   Example: assert_exit "unknown key" 1 "$RC"
assert_exit() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" -eq "$actual" ]]; then
    return 0
  fi
  CURRENT_FAILED=1
  echo "    [$label] expected exit $expected, got $actual"
  return 1
}

# assert_nonempty <label> <value>
#   Mark current case as failed if value is empty.
#   Example: assert_nonempty "stderr explains" "$ERR"
assert_nonempty() {
  local label="$1" value="$2"
  if [[ -n "$value" ]]; then
    return 0
  fi
  CURRENT_FAILED=1
  echo "    [$label] expected non-empty value"
  return 1
}

# ─── Section: Setup helpers ──────────────────────────────────────────────────

# fixture <relative-name> <content>
#   Write content to TMP_BASE/<relative-name>; print its absolute path on
#   stdout so callers can capture with $(...). Heredocs are inlined per
#   case so each test reads top-to-bottom without a separate fixtures dir.
#   Example:
#       cfg=$(fixture full.toml 'specs_path = "x"')
fixture() {
  local name="$1" content="$2"
  local path="$TMP_BASE/$name"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  printf '%s' "$path"
}

# empty_dir <relative-name>
#   Create and print absolute path to an empty subdir under TMP_BASE.
#   Used by tests that exercise default `./jimconf.toml` lookup via a
#   scoped `cd` inside a subshell.
empty_dir() {
  local name="$1"
  local path="$TMP_BASE/$name"
  mkdir -p "$path"
  printf '%s' "$path"
}

# ─── Section: Reporter ───────────────────────────────────────────────────────

# run_discovered_cases
#   Discover every `case_*` function in the current shell, apply $FILTER
#   substring match, run each in sequence, print PASS/FAIL line per case
#   plus a summary line. Exits 0 if all selected pass, 1 if any failed.
#
#   Discovery order is whatever bash's `declare -F` returns (alphabetical
#   in practice). Tests must not depend on inter-case ordering.
run_discovered_cases() {
  local case_fn
  local cases
  cases=$(declare -F | awk '$3 ~ /^case_/ {print $3}')

  for case_fn in $cases; do
    if [[ -n "$FILTER" && "$case_fn" != *"$FILTER"* ]]; then
      continue
    fi
    CURRENT_FAILED=0
    "$case_fn" || CURRENT_FAILED=1
    if [[ "$CURRENT_FAILED" -eq 0 ]]; then
      PASS_COUNT=$((PASS_COUNT + 1))
      echo "PASS - $case_fn"
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      echo "FAIL - $case_fn"
    fi
  done

  local total=$((PASS_COUNT + FAIL_COUNT))
  echo "Ran $total tests: $PASS_COUNT passed, $FAIL_COUNT failed"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    return 1
  fi
  return 0
}

# ─── Section: Maintenance notes ──────────────────────────────────────────────
#
# 1. Temp dir cleanup. `trap 'rm -rf "$TMP_BASE"' EXIT` runs on every exit
#    path including bash errors, so a failed assertion never leaks files.
#    The trap is set once when this file is sourced and applies to whatever
#    shell sourced it (standalone test file or aggregate run.sh).
#
# 2. set -u + capture. `OUT="$(...)"` does not trip on unset vars, but
#    `[[ -z "$OUT" ]]` would if OUT had never been assigned. OUT, ERR, RC
#    are pre-initialized in the Globals section so cases can inspect them
#    safely before their first `run_*` call.
#
# 3. set -e is intentionally OFF. Assertions append failure detail and let
#    the case continue, so a single failing case still surfaces every
#    broken assertion in one report. If a helper command itself errors,
#    the `"$case_fn" || CURRENT_FAILED=1` wrapper still records the failure.
#
# 4. Subshell cd. Tests that exercise default-PWD lookup branches use
#    `(cd "$dir" && bash "$SCRIPT" ...)` so PWD changes are contained to
#    the subshell. Adding a bare `cd` in a case would leak into later
#    cases — don't.
#
# 5. Discovery is name-based. Any function matching `^case_` is a test.
#    Per-script invoker functions (`run`, `run_jimfile`, etc.) intentionally
#    don't match the pattern. If a future helper does, rename it.
#
# 6. Sourcing semantics. `source` runs in the current shell. Globals,
#    helpers, and counters are shared across every sourced test file when
#    invoked via tests/run.sh. Standalone invocation (`bash tests/jimconf.sh`)
#    sources testlib once and runs only that file's cases.
#
# 7. Fixture growth policy. v1 inlines fixtures via heredoc per case so each
#    test reads top-to-bottom. If a fixture grows past ~10 lines, that's the
#    trigger to introduce tests/fixtures/ in a follow-up.
