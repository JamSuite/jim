#!/usr/bin/env bash
#
# tests/jimfile.sh — Tests for skills/file/scripts/jimfile.sh
#
# WHAT THIS FILE TESTS
#   The jimfile.sh file/path operation surface: exists, slug, date, next-id,
#   path (spec/plan/research/debug/brainstorm), glob, kinds. Cases that need
#   /jim:conf overrides write a small jimconf.toml fixture and pass it via
#   the -c flag (jimfile.sh forwards -c to its internal jimconf.sh call).
#
# HOW TO RUN
#   bash tests/jimfile.sh             # run every case in this file
#   bash tests/jimfile.sh slug        # run only cases whose name contains "slug"
#   bash tests/run.sh                 # run this file alongside every other tests/*.sh
#

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_JIMFILE="$REPO_ROOT/skills/file/scripts/jimfile.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_jimfile <args...>
#   Invoke jimfile.sh; capture stdout, stderr, exit code into the globals
#   OUT, ERR, RC. Same shape as the `run` helper in tests/jimconf.sh.
run_jimfile() {
  local err_file="$TMP_BASE/.err"
  OUT="$(bash "$SCRIPT_JIMFILE" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Test cases ─────────────────────────────────────────────────────

# AC: exists yes for an existing file (Decision 6)
case_jimfile_exists_yes_for_existing_file() {
  local f
  f=$(fixture present.txt 'hello')
  run_jimfile exists "$f"
  assert_exit "rc" 0 "$RC"
  assert_eq   "exists yes" "yes" "$OUT"
}

# AC: exists no for a missing file (Decision 6)
case_jimfile_exists_no_for_missing_file() {
  run_jimfile exists "$TMP_BASE/no-such-file.txt"
  assert_exit "rc" 0 "$RC"
  assert_eq   "exists no" "no" "$OUT"
}

# AC: exists with no path argument exits 2 (malformed invocation)
case_jimfile_exists_missing_arg_exits_2() {
  run_jimfile exists
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: slug normalizes basic free-form to kebab-case (Decision 4)
case_jimfile_slug_basic() {
  run_jimfile slug "Auth Token Expiry"
  assert_exit "rc" 0 "$RC"
  assert_eq   "basic slug" "auth-token-expiry" "$OUT"
}

# AC: slug collapses runs of non-alnum to a single dash (Decision 4)
case_jimfile_slug_collapses_runs() {
  run_jimfile slug "foo!!!bar??baz"
  assert_eq "collapsed runs" "foo-bar-baz" "$OUT"
}

# AC: slug strips leading and trailing dashes (Decision 4)
case_jimfile_slug_strips_leading_trailing() {
  run_jimfile slug "---hello---"
  assert_eq "stripped" "hello" "$OUT"
}

# AC: slug is path-traversal safe — slashes/dots collapse, leading dashes strip
case_jimfile_slug_path_traversal_safe() {
  run_jimfile slug "../../etc/passwd"
  assert_eq "no traversal" "etc-passwd" "$OUT"
}

# AC: slug rejects an empty result (only non-alnum input collapses to nothing)
case_jimfile_slug_rejects_empty() {
  run_jimfile slug "!!!"
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: slug rejects literal "." (Decision 4 explicit reject)
case_jimfile_slug_rejects_dot() {
  run_jimfile slug "."
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: slug rejects literal ".." (Decision 4 explicit reject)
case_jimfile_slug_rejects_dotdot() {
  run_jimfile slug ".."
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: slug result is capped at 64 characters (Decision 4)
case_jimfile_slug_length_cap() {
  # 74 alnum chars in; 64 expected out.
  local input="aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeeeffffffffffgggggggggghhhh"
  run_jimfile slug "$input"
  assert_exit "rc" 0 "$RC"
  local len=${#OUT}
  assert_eq "len 64" "64" "$len"
}

# AC: date prints today's date as YYYYMMDD
case_jimfile_date_yyyymmdd() {
  run_jimfile date
  assert_exit  "rc" 0 "$RC"
  assert_match "8 digits" '^[0-9]{8}$' "$OUT"
}

# AC: next-id for an empty group returns 001 (Spec AC: start at 001 if empty)
case_jimfile_next_id_empty_group_returns_001() {
  local specs cfg
  specs=$(empty_dir specs_empty_group)
  mkdir -p "$specs/jim"
  cfg=$(fixture next-empty.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id jim
  assert_exit "rc" 0 "$RC"
  assert_eq   "001" "001" "$OUT"
}

# AC: next-id increments max id by 1 (Spec OoS: max+1 rule)
case_jimfile_next_id_increments_max() {
  local specs cfg
  specs=$(empty_dir specs_existing)
  mkdir -p "$specs/jim/001-foo" "$specs/jim/002-bar"
  cfg=$(fixture next-existing.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id jim
  assert_eq "003" "003" "$OUT"
}

# AC: next-id with gaps still returns max+1 (Spec OoS: no gap reclamation)
case_jimfile_next_id_with_gaps() {
  local specs cfg
  specs=$(empty_dir specs_with_gaps)
  mkdir -p "$specs/jim/001-a" "$specs/jim/003-b" "$specs/jim/005-c"
  cfg=$(fixture next-gaps.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id jim
  assert_eq "006 not 002" "006" "$OUT"
}

# AC: next-id zero-pads to 3 digits even at boundary
case_jimfile_next_id_zero_pads() {
  local specs cfg
  specs=$(empty_dir specs_padding)
  mkdir -p "$specs/jim/099-x"
  cfg=$(fixture next-pad.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id jim
  assert_eq "100 zero-padded" "100" "$OUT"
}

# AC: path spec returns canonical {specs}/{group}/{id}-{name}/spec.md
case_jimfile_path_spec_canonical() {
  local cfg
  cfg=$(fixture path-spec.toml 'specs_path = "docs/specs"')
  run_jimfile -c "$cfg" path spec jim 008 jimfile
  assert_exit "rc" 0 "$RC"
  assert_eq   "spec path" "docs/specs/jim/008-jimfile/spec.md" "$OUT"
}

# AC: path plan returns canonical {specs}/{group}/{id}-{name}/plan.md
case_jimfile_path_plan_canonical() {
  local cfg
  cfg=$(fixture path-plan.toml 'specs_path = "docs/specs"')
  run_jimfile -c "$cfg" path plan jim 008 jimfile
  assert_eq "plan path" "docs/specs/jim/008-jimfile/plan.md" "$OUT"
}

# AC: path research returns canonical {specs}/{group}/{id}-{name}/research.md
case_jimfile_path_research_canonical() {
  local cfg
  cfg=$(fixture path-research.toml 'specs_path = "docs/specs"')
  run_jimfile -c "$cfg" path research jim 008 jimfile
  assert_eq "research path" "docs/specs/jim/008-jimfile/research.md" "$OUT"
}

# AC: path debug returns date-prefixed canonical debug path
case_jimfile_path_debug_basic() {
  local cfg today
  cfg=$(fixture path-debug.toml 'debug_path = "docs/debug"')
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" path debug "Auth Bug"
  assert_eq "debug path" "docs/debug/${today}-auth-bug.md" "$OUT"
}

# AC: path brainstorm returns date-prefixed canonical brainstorm path
case_jimfile_path_brainstorm_basic() {
  local cfg today
  cfg=$(fixture path-brain.toml 'brainstorms_path = "docs/brainstorms"')
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" path brainstorm "Topic Idea"
  assert_eq "brainstorm path" "docs/brainstorms/${today}-topic-idea.md" "$OUT"
}

# AC: path debug appends -2 when target file already exists (Decision 5)
case_jimfile_path_debug_collision_appends_2() {
  local debug cfg today
  debug=$(empty_dir debug_collide)
  today=$(date +%Y%m%d)
  : > "$debug/${today}-foo.md"
  cfg=$(fixture path-debug-coll.toml "debug_path = \"$debug\"")
  run_jimfile -c "$cfg" path debug foo
  assert_eq "appended -2" "$debug/${today}-foo-2.md" "$OUT"
}

# AC: path brainstorm appends -2 when target file already exists (Decision 5)
case_jimfile_path_brainstorm_collision_appends_2() {
  local brain cfg today
  brain=$(empty_dir brain_collide)
  today=$(date +%Y%m%d)
  : > "$brain/${today}-foo.md"
  cfg=$(fixture path-brain-coll.toml "brainstorms_path = \"$brain\"")
  run_jimfile -c "$cfg" path brainstorm foo
  assert_eq "appended -2" "$brain/${today}-foo-2.md" "$OUT"
}

# AC: glob specs without filter lists every spec dir across groups
case_jimfile_glob_specs_unfiltered() {
  local specs cfg
  specs=$(empty_dir glob_specs_all)
  mkdir -p "$specs/jim/001-a" "$specs/jim/002-b" "$specs/other/001-x"
  cfg=$(fixture glob-specs-all.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" glob specs
  assert_exit "rc" 0 "$RC"
  local lines
  lines=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq    "3 spec dirs"   "3"                    "$lines"
  assert_match "jim 001-a"     "$specs/jim/001-a"     "$OUT"
  assert_match "jim 002-b"     "$specs/jim/002-b"     "$OUT"
  assert_match "other 001-x"   "$specs/other/001-x"   "$OUT"
}

# AC: glob specs <group> filters to one group only
case_jimfile_glob_specs_filtered_by_group() {
  local specs cfg
  specs=$(empty_dir glob_specs_filtered)
  mkdir -p "$specs/jim/001-a" "$specs/jim/002-b" "$specs/other/001-x"
  cfg=$(fixture glob-specs-jim.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" glob specs jim
  local lines
  lines=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq    "2 jim specs" "2"                "$lines"
  assert_match "jim 001-a"   "$specs/jim/001-a" "$OUT"
  assert_match "jim 002-b"   "$specs/jim/002-b" "$OUT"
}

# AC: glob debug lists existing debug report files
case_jimfile_glob_debug() {
  local debug cfg
  debug=$(empty_dir glob_debug_dir)
  : > "$debug/20260101-x.md"
  : > "$debug/20260102-y.md"
  cfg=$(fixture glob-debug.toml "debug_path = \"$debug\"")
  run_jimfile -c "$cfg" glob debug
  local lines
  lines=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq "2 debug files" "2" "$lines"
}

# AC: glob brainstorms lists existing brainstorm files
case_jimfile_glob_brainstorms() {
  local brain cfg
  brain=$(empty_dir glob_brain_dir)
  : > "$brain/20260101-a.md"
  : > "$brain/20260102-b.md"
  : > "$brain/20260103-c.md"
  cfg=$(fixture glob-brain.toml "brainstorms_path = \"$brain\"")
  run_jimfile -c "$cfg" glob brainstorms
  local lines
  lines=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq "3 brainstorm files" "3" "$lines"
}

# AC: kinds outputs the valid artifact kinds, no I/O
case_jimfile_kinds_outputs_valid_kinds() {
  run_jimfile kinds
  assert_exit  "rc" 0 "$RC"
  assert_match "spec"       '^spec$'       "$OUT"
  assert_match "plan"       '^plan$'       "$OUT"
  assert_match "research"   '^research$'   "$OUT"
  assert_match "debug"      '^debug$'      "$OUT"
  assert_match "brainstorm" '^brainstorm$' "$OUT"
  local lines
  lines=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq "5 kinds" "5" "$lines"
}

# AC: unknown subcommand exits 2 with stderr explanation
case_jimfile_unknown_subcommand_exits_2() {
  run_jimfile bogus_subcmd
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: unknown kind under `path` exits 1 (validation failure)
case_jimfile_unknown_kind_exits_1() {
  run_jimfile path bogus_kind a b c
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: jimfile honors /jim:conf overrides for configurable directories (Spec AC #2)
case_jimfile_honors_jimconf_overrides() {
  local cfg today
  cfg=$(fixture honors-overrides.toml 'debug_path = "custom/debug-dir"')
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" path debug "topic"
  assert_exit "rc" 0 "$RC"
  assert_eq   "honors override" "custom/debug-dir/${today}-topic.md" "$OUT"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_JIMFILE" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_JIMFILE — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
