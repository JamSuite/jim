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
              "pre_commit:./pre-commit.sh" \
              "pre_completion:./pre-completion.sh" \
              "require_pre_commit:false" \
              "require_pre_completion:false" \
              "auto_arch_feedback:false" \
              "require_security:false" \
              "auto_security:false" \
              "require_security_loop:false" \
              "require_security_loop_sev:critical" \
              "auto_security_loop_limit:5" \
              "security_adhoc:docs/security" \
              "issue_capture:true" \
              "auto_issue_file:false" \
              "issue_list_group:status" \
              "issue_list_sort:date" \
              "issue_list_cols:num,date,priority,slug" \
              "issue_list_order:desc" \
              "issue_list_closed:false" \
              "issue_id_prefix:date" \
              "issue_id_project:"; do
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
pre_commit_path = "scripts/pre-commit"
pre_completion_path = "scripts/pre-completion"
require_pre_commit = "true"
require_pre_completion = "true"
auto_arch_feedback = "true"
require_security = "true"
auto_security = "true"
require_security_loop = "true"
require_security_loop_sev = "notable"
auto_security_loop_limit = "10"
security_adhoc_path = "docs/sec-out"
issue_capture = "false"
auto_issue_file = "true"
issue_list_group = "priority"
issue_list_sort = "num"
issue_list_cols = "num,slug"
issue_list_order = "asc"
issue_list_closed = "true"
issue_id_prefix = "sequential"
issue_id_project = "PROJ"')
  run -c "$cfg" get specs;                     assert_eq "specs"                     "my/specs"               "$OUT"
  run -c "$cfg" get architecture;              assert_eq "architecture"              "docs/arch.md"           "$OUT"
  run -c "$cfg" get vision;                    assert_eq "vision"                    "docs/vision.md"         "$OUT"
  run -c "$cfg" get roadmap;                   assert_eq "roadmap"                   "docs/roadmap.md"        "$OUT"
  run -c "$cfg" get brainstorms;               assert_eq "brainstorms"               "docs/brainstorms-dir"   "$OUT"
  run -c "$cfg" get debug;                     assert_eq "debug"                     "docs/debug-dir"         "$OUT"
  run -c "$cfg" get pre_commit;                assert_eq "pre_commit"                "scripts/pre-commit"     "$OUT"
  run -c "$cfg" get pre_completion;            assert_eq "pre_completion"            "scripts/pre-completion" "$OUT"
  run -c "$cfg" get require_pre_commit;        assert_eq "require_pre_commit"        "true"                   "$OUT"
  run -c "$cfg" get require_pre_completion;    assert_eq "require_pre_completion"    "true"                   "$OUT"
  run -c "$cfg" get auto_arch_feedback;        assert_eq "auto_arch_feedback"        "true"                   "$OUT"
  run -c "$cfg" get require_security;          assert_eq "require_security"          "true"                   "$OUT"
  run -c "$cfg" get auto_security;             assert_eq "auto_security"             "true"                   "$OUT"
  run -c "$cfg" get require_security_loop;     assert_eq "require_security_loop"     "true"                   "$OUT"
  run -c "$cfg" get require_security_loop_sev; assert_eq "require_security_loop_sev" "notable"                "$OUT"
  run -c "$cfg" get auto_security_loop_limit;  assert_eq "auto_security_loop_limit"  "10"                     "$OUT"
  run -c "$cfg" get security_adhoc;            assert_eq "security_adhoc"            "docs/sec-out"           "$OUT"
  run -c "$cfg" get issue_capture;             assert_eq "issue_capture"             "false"                  "$OUT"
  run -c "$cfg" get auto_issue_file;           assert_eq "auto_issue_file"           "true"                   "$OUT"
  run -c "$cfg" get issue_list_group;          assert_eq "issue_list_group"          "priority"               "$OUT"
  run -c "$cfg" get issue_list_sort;           assert_eq "issue_list_sort"           "num"                    "$OUT"
  run -c "$cfg" get issue_list_cols;           assert_eq "issue_list_cols"           "num,slug"               "$OUT"
  run -c "$cfg" get issue_list_order;          assert_eq "issue_list_order"          "asc"                    "$OUT"
  run -c "$cfg" get issue_list_closed;         assert_eq "issue_list_closed"         "true"                   "$OUT"
  run -c "$cfg" get issue_id_prefix;           assert_eq "issue_id_prefix"           "sequential"             "$OUT"
  run -c "$cfg" get issue_id_project;          assert_eq "issue_id_project"          "PROJ"                   "$OUT"
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
  assert_eq    "list line count"                  "27" "$line_count"
  assert_match "specs line"                        '^specs=docs/specs$'                     "$OUT"
  assert_match "architecture line"                 '^architecture=ARCHITECTURE\.md$'        "$OUT"
  assert_match "vision line"                       '^vision=VISION\.md$'                    "$OUT"
  assert_match "roadmap line"                      '^roadmap=ROADMAP\.md$'                  "$OUT"
  assert_match "brainstorms line"                  '^brainstorms=docs/brainstorms$'         "$OUT"
  assert_match "debug line"                        '^debug=docs/debug$'                     "$OUT"
  assert_match "pre_commit line"                   '^pre_commit=\./pre-commit\.sh$'         "$OUT"
  assert_match "pre_completion line"               '^pre_completion=\./pre-completion\.sh$' "$OUT"
  assert_match "require_pre_commit line"           '^require_pre_commit=false$'             "$OUT"
  assert_match "require_pre_completion line"       '^require_pre_completion=false$'         "$OUT"
  assert_match "auto_arch_feedback line"           '^auto_arch_feedback=false$'             "$OUT"
  assert_match "require_security line"             '^require_security=false$'               "$OUT"
  assert_match "auto_security line"                '^auto_security=false$'                  "$OUT"
  assert_match "require_security_loop line"        '^require_security_loop=false$'          "$OUT"
  assert_match "require_security_loop_sev line"    '^require_security_loop_sev=critical$'   "$OUT"
  assert_match "auto_security_loop_limit line"     '^auto_security_loop_limit=5$'           "$OUT"
  assert_match "security_adhoc line"               '^security_adhoc=docs/security$'         "$OUT"
  assert_match "issues line"                       '^issues=\./docs/issues/$'               "$OUT"
  assert_match "issue_capture line"                '^issue_capture=true$'                   "$OUT"
  assert_match "auto_issue_file line"              '^auto_issue_file=false$'                "$OUT"
  assert_match "issue_list_group line"             '^issue_list_group=status$'              "$OUT"
  assert_match "issue_list_sort line"              '^issue_list_sort=date$'                 "$OUT"
  assert_match "issue_list_cols line"              '^issue_list_cols=num,date,priority,slug$' "$OUT"
  assert_match "issue_list_order line"             '^issue_list_order=desc$'                "$OUT"
  assert_match "issue_list_closed line"            '^issue_list_closed=false$'              "$OUT"
  assert_match "issue_id_prefix line"              '^issue_id_prefix=date$'                 "$OUT"
  assert_match "issue_id_project line"             '^issue_id_project=$'                    "$OUT"
}

# AC: keys emits the valid CLI key list, no I/O
case_keys_outputs_valid_keys() {
  run keys
  assert_exit "rc" 0 "$RC"
  local expected
  expected=$(printf 'specs\narchitecture\nvision\nroadmap\nbrainstorms\ndebug\npre_commit\npre_completion\nrequire_pre_commit\nrequire_pre_completion\nauto_arch_feedback\nrequire_security\nauto_security\nrequire_security_loop\nrequire_security_loop_sev\nauto_security_loop_limit\nsecurity_adhoc\nissues\nissue_capture\nauto_issue_file\nissue_list_group\nissue_list_sort\nissue_list_cols\nissue_list_order\nissue_list_closed\nissue_id_prefix\nissue_id_project')
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
  assert_eq "list still emits all keys" "27" "$line_count"
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

# AC: pre_completion key resolves to ./pre-completion.sh by default
# Project-script default for the completion-gate hook — every consumer wraps
# this in an exists gate at the skill layer, so the resolver returns the
# path unconditionally.
case_pre_completion_default() {
  local dir actual
  dir=$(empty_dir pre_completion_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get pre_completion)
  assert_eq "pre_completion default" "./pre-completion.sh" "$actual"
}

# AC: pre_completion override via jimconf.toml
case_pre_completion_overridden() {
  local cfg
  cfg=$(fixture pre_completion-override.toml 'pre_completion_path = "ci/full-suite.bash"')
  run -c "$cfg" get pre_completion
  assert_eq "pre_completion overridden" "ci/full-suite.bash" "$OUT"
}

# AC: require_pre_commit defaults to "false"
# Flag key — TOML name equals CLI name (no _path suffix); resolved via
# the require_* prefix dispatch in resolve().
case_require_pre_commit_default() {
  local dir actual
  dir=$(empty_dir require_pre_commit_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get require_pre_commit)
  assert_eq "require_pre_commit default" "false" "$actual"
}

# AC: require_pre_commit override via jimconf.toml ("true" enables enforcement)
case_require_pre_commit_overridden() {
  local cfg
  cfg=$(fixture require_pre_commit-override.toml 'require_pre_commit = "true"')
  run -c "$cfg" get require_pre_commit
  assert_eq "require_pre_commit overridden" "true" "$OUT"
}

# AC: require_pre_completion defaults to "false"
case_require_pre_completion_default() {
  local dir actual
  dir=$(empty_dir require_pre_completion_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get require_pre_completion)
  assert_eq "require_pre_completion default" "false" "$actual"
}

# AC: require_pre_completion override via jimconf.toml
case_require_pre_completion_overridden() {
  local cfg
  cfg=$(fixture require_pre_completion-override.toml 'require_pre_completion = "true"')
  run -c "$cfg" get require_pre_completion
  assert_eq "require_pre_completion overridden" "true" "$OUT"
}

# AC: auto_arch_feedback defaults to "false"
# Flag key — TOML name equals CLI name (no _path suffix); resolved via
# the auto_* prefix dispatch in resolve().
case_auto_arch_feedback_default() {
  local dir actual
  dir=$(empty_dir auto_arch_feedback_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get auto_arch_feedback)
  assert_eq "auto_arch_feedback default" "false" "$actual"
}

# AC: auto_arch_feedback override via jimconf.toml ("true" enables auto-write)
case_auto_arch_feedback_overridden() {
  local cfg
  cfg=$(fixture auto_arch_feedback-override.toml 'auto_arch_feedback = "true"')
  run -c "$cfg" get auto_arch_feedback
  assert_eq "auto_arch_feedback overridden" "true" "$OUT"
}

# AC: require_security defaults to "false"
# Workflow gate flag — TOML name equals CLI name (no _path suffix); resolved
# via the require_* prefix dispatch in resolve(). When "true", /jim:plan and
# /jim:build halt the workflow at their start until phase-level security
# review is on file (spec 016).
case_require_security_default() {
  local dir actual
  dir=$(empty_dir require_security_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get require_security)
  assert_eq "require_security default" "false" "$actual"
}

# AC: require_security override via jimconf.toml
case_require_security_overridden() {
  local cfg
  cfg=$(fixture require_security-override.toml 'require_security = "true"')
  run -c "$cfg" get require_security
  assert_eq "require_security overridden" "true" "$OUT"
}

# AC: auto_security defaults to "false"
# Same gate as require_security but routes findings automatically without
# per-finding prompts. Resolved via auto_* prefix dispatch.
case_auto_security_default() {
  local dir actual
  dir=$(empty_dir auto_security_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get auto_security)
  assert_eq "auto_security default" "false" "$actual"
}

# AC: auto_security override via jimconf.toml
case_auto_security_overridden() {
  local cfg
  cfg=$(fixture auto_security-override.toml 'auto_security = "true"')
  run -c "$cfg" get auto_security
  assert_eq "auto_security overridden" "true" "$OUT"
}

# AC: require_security_loop defaults to "false"
# Enables repeated review-and-routing cycles inside the gated workflow.
case_require_security_loop_default() {
  local dir actual
  dir=$(empty_dir require_security_loop_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get require_security_loop)
  assert_eq "require_security_loop default" "false" "$actual"
}

# AC: require_security_loop override via jimconf.toml
case_require_security_loop_overridden() {
  local cfg
  cfg=$(fixture require_security_loop-override.toml 'require_security_loop = "true"')
  run -c "$cfg" get require_security_loop
  assert_eq "require_security_loop overridden" "true" "$OUT"
}

# AC: require_security_loop_sev defaults to "critical"
# Severity threshold for the loop's exit condition. Conservative default per
# plan Decision 12 — loop exits when no Critical-severity findings remain.
case_require_security_loop_sev_default() {
  local dir actual
  dir=$(empty_dir require_security_loop_sev_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get require_security_loop_sev)
  assert_eq "require_security_loop_sev default" "critical" "$actual"
}

# AC: require_security_loop_sev override via jimconf.toml
case_require_security_loop_sev_overridden() {
  local cfg
  cfg=$(fixture require_security_loop_sev-override.toml 'require_security_loop_sev = "notable"')
  run -c "$cfg" get require_security_loop_sev
  assert_eq "require_security_loop_sev overridden" "notable" "$OUT"
}

# AC: auto_security_loop_limit defaults to "5"
# Maximum iterations of the gated review-and-routing loop. Integer-as-string;
# conservative default per plan Decision 12 prevents runaway loops.
case_auto_security_loop_limit_default() {
  local dir actual
  dir=$(empty_dir auto_security_loop_limit_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get auto_security_loop_limit)
  assert_eq "auto_security_loop_limit default" "5" "$actual"
}

# AC: auto_security_loop_limit override via jimconf.toml
case_auto_security_loop_limit_overridden() {
  local cfg
  cfg=$(fixture auto_security_loop_limit-override.toml 'auto_security_loop_limit = "10"')
  run -c "$cfg" get auto_security_loop_limit
  assert_eq "auto_security_loop_limit overridden" "10" "$OUT"
}

# AC: security_adhoc defaults to "docs/security"
# Path-typed key — CLI key `security_adhoc` resolves to TOML key
# `security_adhoc_path` (via the default `${cli_key}_path` rule in resolve()).
# Default base directory for ad-hoc /jim:sec opt-in file output.
case_security_adhoc_default() {
  local dir actual
  dir=$(empty_dir security_adhoc_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get security_adhoc)
  assert_eq "security_adhoc default" "docs/security" "$actual"
}

# AC: security_adhoc override via jimconf.toml
case_security_adhoc_overridden() {
  local cfg
  cfg=$(fixture security_adhoc-override.toml 'security_adhoc_path = "docs/sec-out"')
  run -c "$cfg" get security_adhoc
  assert_eq "security_adhoc overridden" "docs/sec-out" "$OUT"
}

# AC: issues defaults to "./docs/issues/" (spec 017 AC-P2)
# Path-typed key — CLI key `issues` resolves to TOML key `issues_path` via the
# default `${cli_key}_path` rule in resolve(). Default storage location for
# discovery-artifact issue files captured via /jim:issue.
case_issues_default() {
  local dir actual
  dir=$(empty_dir issues_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get issues)
  assert_eq "issues default" "./docs/issues/" "$actual"
}

# AC: issues override via jimconf.toml (spec 017 AC-P2)
case_issues_overridden() {
  local cfg
  cfg=$(fixture issues-override.toml 'issues_path = "docs/findings"')
  run -c "$cfg" get issues
  assert_eq "issues overridden" "docs/findings" "$OUT"
}

# AC: issues with empty-string configured value falls through to default
# (spec 017 security.md Finding 13 — defense against silent empty-path writes).
case_issues_empty_string_falls_through_to_default() {
  local cfg
  cfg=$(fixture issues-empty.toml 'issues_path = ""')
  run -c "$cfg" get issues
  assert_eq "empty → default" "./docs/issues/" "$OUT"
}

# AC: issues with whitespace-only configured value falls through to default
# (spec 017 security.md Finding 13 — whitespace counts as empty after trim).
case_issues_whitespace_only_falls_through_to_default() {
  local cfg
  cfg=$(fixture issues-whitespace.toml 'issues_path = "   "')
  run -c "$cfg" get issues
  assert_eq "whitespace → default" "./docs/issues/" "$OUT"
}

# AC: issues with no config file at all falls through to default
case_issues_no_config_file() {
  run -c "$TMP_BASE/never-existed.toml" get issues
  assert_exit "rc" 0 "$RC"
  assert_eq "missing config → default" "./docs/issues/" "$OUT"
}

# AC: issues survives commented config (parse-robustness regression guard)
case_issues_tolerates_comments() {
  local cfg
  cfg=$(fixture issues-comments.toml '# default storage location
issues_path = "docs/my-issues"
# trailing comment')
  run -c "$cfg" get issues
  assert_eq "value past comments" "docs/my-issues" "$OUT"
}

# AC: issue_capture defaults to "true" (spec 018 CFG-1)
# Bare-name boolean flag — TOML key is `issue_capture` (no _path suffix and
# no auto_/require_ prefix). The bare-name reflects that the default
# behavior keeps the human in the loop: surfacing presents a choice, not an
# automated action. Resolved via a special-case in resolve() per spec 018
# DD #1. Default `"true"` enables end-of-phase candidate batches across the
# 7 surfacing skills out-of-the-box.
case_issue_capture_default() {
  local dir actual
  dir=$(empty_dir issue_capture_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get issue_capture)
  assert_eq "issue_capture default" "true" "$actual"
}

# AC: issue_capture override via jimconf.toml (spec 018 CFG-1)
# Captures the silent-no-op failure mode the researcher's Peer Feedback
# flagged: without the resolve() bare-name special-case, the dispatch
# would look up `issue_capture_path` and silently return the default.
case_issue_capture_overridden() {
  local cfg
  cfg=$(fixture issue_capture-override.toml 'issue_capture = "false"')
  run -c "$cfg" get issue_capture
  assert_eq "issue_capture overridden" "false" "$OUT"
}

# AC: auto_issue_file defaults to "false" (spec 018 CFG-2)
# Flag key — TOML name equals CLI name (no _path suffix); resolved via the
# auto_* prefix dispatch in resolve(). Default "false" preserves the
# default-interactive batch UX; flipping to "true" enables quiet auto-file
# mode (no prompt; per-row write at workflow speed).
case_auto_issue_file_default() {
  local dir actual
  dir=$(empty_dir auto_issue_file_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get auto_issue_file)
  assert_eq "auto_issue_file default" "false" "$actual"
}

# AC: auto_issue_file override via jimconf.toml (spec 018 CFG-2)
case_auto_issue_file_overridden() {
  local cfg
  cfg=$(fixture auto_issue_file-override.toml 'auto_issue_file = "true"')
  run -c "$cfg" get auto_issue_file
  assert_eq "auto_issue_file overridden" "true" "$OUT"
}

# AC: issue_list_group defaults to "status" (spec 019)
# Bare-name view-config key — TOML name equals CLI name (no _path suffix),
# resolved via the issue_list_* prefix dispatch in resolve(). Controls the
# default grouping of `/jim:issue list`.
case_issue_list_group_default() {
  local dir actual
  dir=$(empty_dir issue_list_group_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get issue_list_group)
  assert_eq "issue_list_group default" "status" "$actual"
}

# AC: issue_list_group override via jimconf.toml (spec 019)
case_issue_list_group_overridden() {
  local cfg
  cfg=$(fixture issue_list_group-override.toml 'issue_list_group = "priority"')
  run -c "$cfg" get issue_list_group
  assert_eq "issue_list_group overridden" "priority" "$OUT"
}

# AC: issue_list_sort defaults to "date" (spec 019)
case_issue_list_sort_default() {
  local dir actual
  dir=$(empty_dir issue_list_sort_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get issue_list_sort)
  assert_eq "issue_list_sort default" "date" "$actual"
}

# AC: issue_list_sort override via jimconf.toml (spec 019)
case_issue_list_sort_overridden() {
  local cfg
  cfg=$(fixture issue_list_sort-override.toml 'issue_list_sort = "num"')
  run -c "$cfg" get issue_list_sort
  assert_eq "issue_list_sort overridden" "num" "$OUT"
}

# AC: issue_list_cols defaults to "num,date,priority,slug" (spec 019)
case_issue_list_cols_default() {
  local dir actual
  dir=$(empty_dir issue_list_cols_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get issue_list_cols)
  assert_eq "issue_list_cols default" "num,date,priority,slug" "$actual"
}

# AC: issue_list_cols override via jimconf.toml (spec 019)
case_issue_list_cols_overridden() {
  local cfg
  cfg=$(fixture issue_list_cols-override.toml 'issue_list_cols = "num,slug"')
  run -c "$cfg" get issue_list_cols
  assert_eq "issue_list_cols overridden" "num,slug" "$OUT"
}

# AC: issue_list_order defaults to "desc" (spec 019 follow-up)
case_issue_list_order_default() {
  local dir actual
  dir=$(empty_dir issue_list_order_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get issue_list_order)
  assert_eq "issue_list_order default" "desc" "$actual"
}

# AC: issue_list_order override via jimconf.toml (spec 019 follow-up)
case_issue_list_order_overridden() {
  local cfg
  cfg=$(fixture issue_list_order-override.toml 'issue_list_order = "asc"')
  run -c "$cfg" get issue_list_order
  assert_eq "issue_list_order overridden" "asc" "$OUT"
}

# AC: issue_id_prefix defaults to "date" (spec 021 AC #1/#9)
# Bare-name view-config key — TOML name equals CLI name (no _path suffix),
# resolved via the issue_id_* dispatch in resolve(). Default "date" preserves
# the zero-config YYYYMMDD- scheme.
case_issue_id_prefix_default() {
  local dir actual
  dir=$(empty_dir issue_id_prefix_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get issue_id_prefix)
  assert_eq "issue_id_prefix default" "date" "$actual"
}

# AC: issue_id_prefix override via jimconf.toml (spec 021 AC #2)
case_issue_id_prefix_overridden() {
  local cfg
  cfg=$(fixture issue_id_prefix-override.toml 'issue_id_prefix = "sequential"')
  run -c "$cfg" get issue_id_prefix
  assert_eq "issue_id_prefix overridden" "sequential" "$OUT"
}

# AC: issue_id_project defaults to "" (spec 021 — only used by the project preset)
case_issue_id_project_default() {
  local dir actual
  dir=$(empty_dir issue_id_project_baseline)
  actual=$(cd "$dir" && bash "$SCRIPT" get issue_id_project)
  assert_eq "issue_id_project default" "" "$actual"
}

# AC: issue_id_project override via jimconf.toml (spec 021)
case_issue_id_project_overridden() {
  local cfg
  cfg=$(fixture issue_id_project-override.toml 'issue_id_project = "JIM"')
  run -c "$cfg" get issue_id_project
  assert_eq "issue_id_project overridden" "JIM" "$OUT"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT" ]]; then
    echo "NOTE: script under test not found at $SCRIPT — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
