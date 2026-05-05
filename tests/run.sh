#!/usr/bin/env bash
#
# tests/run.sh — Plain-bash test runner for skills/conf/scripts/jimconf.sh
#
# WHAT THIS FILE TESTS
#   The jimconf.sh path resolver: every CLI subcommand (get / list / path /
#   keys), the -c <path> flag, default-fallback behavior, and parse
#   robustness against malformed input.
#
# HOW TO RUN
#   bash tests/run.sh                 # run every test case
#   bash tests/run.sh defaults        # run only cases whose name contains "defaults"
#
# EXPECTED OUTPUT SHAPE
#   One line per executed case:
#       PASS - case_<name>
#       FAIL - case_<name>
#         <indented assertion failure detail, one line per failed assert>
#   Followed by a single summary line:
#       Ran N tests: P passed, F failed
#
# EXIT CODE SEMANTICS
#   0   every selected test passed
#   1   at least one test failed (or the script under test is missing)
#   2   runner setup error (mkdir/mktemp failure)
#
# HOW TO ADD A NEW TEST CASE  (3-step recipe)
#   1. Pick a unique snake_case name and define `case_<name>()` in the
#      "Test cases" section. Begin its body with a single comment of the
#      form `# AC: <spec acceptance criterion this case verifies>`.
#   2. Inside the case, write fixtures with `fixture <name> <content>`,
#      run the script with `run <args>`, and assert via `assert_eq`,
#      `assert_match`, `assert_exit`, or `assert_nonempty`.
#   3. Append `case_<name>` to the TESTS array in the "Reporter" section.
#

set -uo pipefail

# ─── Section: Globals ────────────────────────────────────────────────────────

# REPO_ROOT: this file's parent directory. Lets the runner work regardless of
# where it's invoked from (`bash tests/run.sh` from repo root, or absolute
# path from anywhere else).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/conf/scripts/jimconf.sh"

# Per-runner sandbox. Every fixture and scratch dir lives under TMP_BASE.
TMP_BASE="$(mktemp -d -t jimconf-tests.XXXXXX)" || exit 2
trap 'rm -rf "$TMP_BASE"' EXIT

# Filter: `bash tests/run.sh <pat>` only runs cases whose function name
# contains <pat>. Empty string = run all.
FILTER="${1:-}"

# Captured by `run`. Pre-initialized so `set -u` doesn't trip when a case
# inspects them before its first `run` call.
OUT=""
ERR=""
RC=0

PASS_COUNT=0
FAIL_COUNT=0
CURRENT_FAILED=0

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

# run <args...>
#   Invoke the script under test; capture stdout, stderr, exit code into
#   the globals OUT, ERR, RC. Stdout's trailing newline is stripped by
#   bash command substitution as usual — assertions compare the trimmed
#   value.
#   Example: run get architecture
run() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Test cases ─────────────────────────────────────────────────────

# AC: zero-config baseline preserved (spec AC #2)
# When PWD has no jimconf.toml, every key resolves to its documented default.
case_no_config_returns_defaults() {
  local dir
  dir=$(empty_dir empty_baseline)
  local pair key expected actual
  for pair in "specs:docs/specs" \
              "architecture:ARCHITECTURE.md" \
              "vision:VISION.md" \
              "roadmap:ROADMAP.md" \
              "brainstorms:docs/brainstorms" \
              "debug:docs/debug"; do
    key="${pair%%:*}"
    expected="${pair#*:}"
    actual=$(cd "$dir" && bash "$SCRIPT" get "$key")
    assert_eq "default for $key" "$expected" "$actual"
  done
}

# AC: full override (spec AC #1, #4)
# When every key is set in the config, every key resolves to the configured value.
case_full_config_returns_overrides() {
  local cfg
  cfg=$(fixture full.toml 'specs_path = "my/specs"
architecture_path = "docs/arch.md"
vision_path = "docs/vision.md"
roadmap_path = "docs/roadmap.md"
brainstorms_path = "docs/brainstorms-dir"
debug_path = "docs/debug-dir"')
  run -c "$cfg" get specs;        assert_eq "specs"        "my/specs"             "$OUT"
  run -c "$cfg" get architecture; assert_eq "architecture" "docs/arch.md"         "$OUT"
  run -c "$cfg" get vision;       assert_eq "vision"       "docs/vision.md"       "$OUT"
  run -c "$cfg" get roadmap;      assert_eq "roadmap"      "docs/roadmap.md"      "$OUT"
  run -c "$cfg" get brainstorms;  assert_eq "brainstorms"  "docs/brainstorms-dir" "$OUT"
  run -c "$cfg" get debug;        assert_eq "debug"        "docs/debug-dir"       "$OUT"
}

# AC: partial override layered over defaults (spec AC #3)
# Setting only architecture_path overrides that key; the others keep defaults.
case_partial_config_layered_over_defaults() {
  local cfg
  cfg=$(fixture partial.toml 'architecture_path = "custom/ARCH.md"')
  run -c "$cfg" get architecture; assert_eq "architecture overridden" "custom/ARCH.md" "$OUT"
  run -c "$cfg" get specs;        assert_eq "specs default kept"      "docs/specs"     "$OUT"
  run -c "$cfg" get vision;       assert_eq "vision default kept"     "VISION.md"      "$OUT"
  run -c "$cfg" get roadmap;      assert_eq "roadmap default kept"    "ROADMAP.md"     "$OUT"
}

# AC: unknown CLI key exits 1 with a stderr message (Interface Contracts)
case_unknown_key_exits_with_error() {
  run get bogus_key
  assert_exit     "rc"               1  "$RC"
  assert_eq       "stdout empty"     "" "$OUT"
  assert_nonempty "stderr explains"  "$ERR"
}

# AC: list emits all 6 keys as KEY=VALUE pairs (one line each)
case_list_outputs_all_six_keys() {
  local cfg
  cfg=$(fixture list-defaults.toml '')
  run -c "$cfg" list
  assert_exit "rc" 0 "$RC"
  local line_count
  line_count=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq    "list line count"  "6" "$line_count"
  assert_match "specs line"        '^specs=docs/specs$'              "$OUT"
  assert_match "architecture line" '^architecture=ARCHITECTURE\.md$' "$OUT"
  assert_match "vision line"       '^vision=VISION\.md$'             "$OUT"
  assert_match "roadmap line"      '^roadmap=ROADMAP\.md$'           "$OUT"
  assert_match "brainstorms line"  '^brainstorms=docs/brainstorms$'  "$OUT"
  assert_match "debug line"        '^debug=docs/debug$'              "$OUT"
}

# AC: keys emits the valid CLI key list, no I/O
case_keys_outputs_valid_keys() {
  run keys
  assert_exit "rc" 0 "$RC"
  local expected
  expected=$(printf 'specs\narchitecture\nvision\nroadmap\nbrainstorms\ndebug')
  assert_eq "keys output" "$expected" "$OUT"
}

# AC: path returns the absolute path of the active config when present
case_path_returns_absolute_when_config_exists() {
  local dir actual
  dir=$(empty_dir path_present)
  printf '%s\n' 'specs_path = "x"' > "$dir/jimconf.toml"
  actual=$(cd "$dir" && bash "$SCRIPT" path)
  assert_match "absolute path" '^/.*jimconf\.toml$' "$actual"
}

# AC: path returns empty when no config file is present
case_path_returns_empty_when_no_config() {
  local dir actual
  dir=$(empty_dir path_absent)
  actual=$(cd "$dir" && bash "$SCRIPT" path)
  assert_eq "empty path" "" "$actual"
}

# AC: malformed lines (comments, blanks, nested tables, garbage) are ignored
# Parse keeps going; unrecognized lines silently fall through to defaults.
case_malformed_lines_are_ignored() {
  local cfg
  cfg=$(fixture malformed.toml '# leading comment
specs_path = "kept"

   # indented comment
not a real key
[nested.table]
inner = "ignored"
trailing garbage at end')
  run -c "$cfg" get specs;        assert_eq "specs kept"           "kept"            "$OUT"
  run -c "$cfg" get architecture; assert_eq "architecture default" "ARCHITECTURE.md" "$OUT"
  run -c "$cfg" list
  local line_count
  line_count=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq "list still 6 lines" "6" "$line_count"
}

# AC: values with internal whitespace are preserved verbatim
case_values_with_spaces_are_preserved() {
  local cfg
  cfg=$(fixture spaced.toml 'specs_path = "docs with spaces/specs"')
  run -c "$cfg" get specs
  assert_eq "value with spaces" "docs with spaces/specs" "$OUT"
}

# AC: -c <path> reads the specified file instead of the default
case_dash_c_reads_specified_file() {
  local cfg
  cfg=$(fixture custom.toml 'vision_path = "from-c.md"')
  run -c "$cfg" get vision
  assert_eq "vision from -c" "from-c.md" "$OUT"
}

# AC: -c <missing-path> silently falls through to defaults
case_dash_c_missing_path_falls_through_to_defaults() {
  run -c "$TMP_BASE/no-such-file.toml" get specs
  assert_exit "rc"             0           "$RC"
  assert_eq   "default specs"  "docs/specs" "$OUT"
  run -c "$TMP_BASE/no-such-file.toml" path
  assert_eq   "missing path empty" "" "$OUT"
}

# ─── Section: Reporter ───────────────────────────────────────────────────────

TESTS=(
  case_no_config_returns_defaults
  case_full_config_returns_overrides
  case_partial_config_layered_over_defaults
  case_unknown_key_exits_with_error
  case_list_outputs_all_six_keys
  case_keys_outputs_valid_keys
  case_path_returns_absolute_when_config_exists
  case_path_returns_empty_when_no_config
  case_malformed_lines_are_ignored
  case_values_with_spaces_are_preserved
  case_dash_c_reads_specified_file
  case_dash_c_missing_path_falls_through_to_defaults
)

if [[ ! -e "$SCRIPT" ]]; then
  echo "NOTE: script under test not found at $SCRIPT — every test will fail."
fi

for case_fn in "${TESTS[@]}"; do
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

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Ran $TOTAL tests: $PASS_COUNT passed, $FAIL_COUNT failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0

# ─── Section: Maintenance notes ──────────────────────────────────────────────
#
# ## Maintenance notes
#
# 1. Temp dir cleanup. `trap 'rm -rf "$TMP_BASE"' EXIT` runs on every exit
#    path including bash errors, so a failed assertion never leaks files.
#
# 2. set -u + capture. `OUT="$(...)"` does not trip on unset vars, but
#    `[[ -z "$OUT" ]]` would if OUT had never been assigned. OUT, ERR, RC
#    are pre-initialized in the Globals section so cases can inspect them
#    safely before the first `run` call.
#
# 3. set -e is intentionally OFF. Assertions append failure detail and let
#    the case continue, so a single failing case still surfaces every
#    broken assertion in one report. If a helper command itself errors,
#    the case-level wrapper (`"$case_fn" || CURRENT_FAILED=1`) still
#    records the failure.
#
# 4. Subshell cd. Tests that exercise the default-PWD jimconf.toml lookup
#    branch use `(cd "$dir" && bash "$SCRIPT" ...)` so PWD changes are
#    contained to the subshell. Adding a bare `cd` in a case would leak
#    into later cases — don't.
#
# 5. Fixture growth policy. v1 inlines fixtures via heredoc per case so
#    each test reads top-to-bottom. If a fixture grows past ~10 lines,
#    that's the trigger to introduce tests/fixtures/ in a follow-up spec.
