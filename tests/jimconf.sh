#!/usr/bin/env bash
#
# tests/jimconf.sh — Tests for skills/conf/scripts/jimconf.sh
#
# WHAT THIS FILE TESTS
#   The jimconf.sh path resolver: every CLI subcommand (get / list / path /
#   keys), the -c <path> flag, default-fallback behavior, and parse
#   robustness against malformed input.
#
# HOW TO RUN
#   bash tests/jimconf.sh             # run every case in this file
#   bash tests/jimconf.sh defaults    # run only cases whose name contains "defaults"
#   bash tests/run.sh                 # run this file alongside every other tests/*.sh
#

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT="$REPO_ROOT/skills/conf/scripts/jimconf.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run <args...>
#   Invoke jimconf.sh; capture stdout, stderr, exit code into the globals
#   OUT, ERR, RC. Stdout's trailing newline is stripped by bash command
#   substitution as usual — assertions compare the trimmed value.
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
              "debug:docs/debug" \
              "pre_commit:./pre-commit.sh"; do
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
debug_path = "docs/debug-dir"
pre_commit_path = "scripts/pre-commit"')
  run -c "$cfg" get specs;        assert_eq "specs"        "my/specs"             "$OUT"
  run -c "$cfg" get architecture; assert_eq "architecture" "docs/arch.md"         "$OUT"
  run -c "$cfg" get vision;       assert_eq "vision"       "docs/vision.md"       "$OUT"
  run -c "$cfg" get roadmap;      assert_eq "roadmap"      "docs/roadmap.md"      "$OUT"
  run -c "$cfg" get brainstorms;  assert_eq "brainstorms"  "docs/brainstorms-dir" "$OUT"
  run -c "$cfg" get debug;        assert_eq "debug"        "docs/debug-dir"       "$OUT"
  run -c "$cfg" get pre_commit;   assert_eq "pre_commit"   "scripts/pre-commit"   "$OUT"
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

# AC: list emits every configured key as KEY=VALUE pairs (one line each)
case_list_outputs_all_keys() {
  local cfg
  cfg=$(fixture list-defaults.toml '')
  run -c "$cfg" list
  assert_exit "rc" 0 "$RC"
  local line_count
  line_count=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq    "list line count"  "7" "$line_count"
  assert_match "specs line"        '^specs=docs/specs$'              "$OUT"
  assert_match "architecture line" '^architecture=ARCHITECTURE\.md$' "$OUT"
  assert_match "vision line"       '^vision=VISION\.md$'             "$OUT"
  assert_match "roadmap line"      '^roadmap=ROADMAP\.md$'           "$OUT"
  assert_match "brainstorms line"  '^brainstorms=docs/brainstorms$'  "$OUT"
  assert_match "debug line"        '^debug=docs/debug$'              "$OUT"
  assert_match "pre_commit line"   '^pre_commit=\./pre-commit\.sh$'  "$OUT"
}

# AC: keys emits the valid CLI key list, no I/O
case_keys_outputs_valid_keys() {
  run keys
  assert_exit "rc" 0 "$RC"
  local expected
  expected=$(printf 'specs\narchitecture\nvision\nroadmap\nbrainstorms\ndebug\npre_commit')
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
  assert_eq "list still emits all keys" "7" "$line_count"
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

# AC: pre_commit key resolves to ./pre-commit.sh by default
# Project-script default — every consumer wraps this in an exists gate at the
# skill layer, so the resolver returns the path unconditionally.
case_pre_commit_default() {
  local dir actual
  dir=$(empty_dir pre_commit_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get pre_commit)
  assert_eq "pre_commit default" "./pre-commit.sh" "$actual"
}

# AC: pre_commit override via jimconf.toml
case_pre_commit_overridden() {
  local cfg
  cfg=$(fixture pre_commit-override.toml 'pre_commit_path = "ci/pre-commit.bash"')
  run -c "$cfg" get pre_commit
  assert_eq "pre_commit overridden" "ci/pre-commit.bash" "$OUT"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT" ]]; then
    echo "NOTE: script under test not found at $SCRIPT — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
