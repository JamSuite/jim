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

# extract_is_valid_id <script>
#   Print the is_valid_id function body (def line through its column-0 closing
#   brace). Used to assert the three hand-synced copies stay byte-identical
#   (spec 021 security.md Finding 5).
extract_is_valid_id() {
  awk '/^is_valid_id\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$1"
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

# AC: now prints the current second-resolution UTC timestamp (ISO 8601 Z)
case_jimfile_now_utc_iso8601() {
  run_jimfile now
  assert_exit  "rc" 0 "$RC"
  assert_match "iso8601 utc" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$OUT"
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

# AC: path <key> (single-arg) returns the documented default (D3)
case_jimfile_path_key_returns_configured_path() {
  local dir actual
  dir=$(empty_dir path_key_default)
  actual=$(cd "$dir" && bash "$SCRIPT_JIMFILE" path vision)
  assert_eq "vision default" "VISION.md" "$actual"
}

# AC: path <key> (single-arg) honors a /jim:conf override (D3)
case_jimfile_path_key_honors_override() {
  local cfg
  cfg=$(fixture path-key-override.toml 'vision_path = "docs/VISION.md"')
  run_jimfile -c "$cfg" path vision
  assert_exit "rc" 0 "$RC"
  assert_eq   "vision override" "docs/VISION.md" "$OUT"
}

# AC: path <key> returns the configured path regardless of disk existence (D3 write-target use case)
case_jimfile_path_key_returns_path_even_if_missing() {
  local cfg
  cfg=$(fixture path-key-missing.toml 'architecture_path = "nowhere/ARCH.md"')
  run_jimfile -c "$cfg" path architecture
  assert_exit "rc" 0 "$RC"
  assert_eq   "architecture path (missing file)" "nowhere/ARCH.md" "$OUT"
}

# AC: arity dispatch — `path debug` (no further args) returns the configured debug dir (D3)
case_jimfile_path_debug_no_arg_returns_dir() {
  local cfg
  cfg=$(fixture path-debug-no-arg.toml 'debug_path = "docs/debug"')
  run_jimfile -c "$cfg" path debug
  assert_exit "rc" 0 "$RC"
  assert_eq   "debug dir" "docs/debug" "$OUT"
}

# AC: arity dispatch — `path debug <topic>` still produces collision-resolved topic path (D3 regression guard)
case_jimfile_path_debug_with_topic_still_works() {
  local cfg today
  cfg=$(fixture path-debug-with-topic.toml 'debug_path = "docs/debug"')
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" path debug "Topic Idea"
  assert_exit "rc" 0 "$RC"
  assert_eq   "debug topic path" "docs/debug/${today}-topic-idea.md" "$OUT"
}

# AC: path <unknown_key> (single-arg) bubbles up jimconf's unknown-key error
case_jimfile_path_unknown_key_exits_1() {
  run_jimfile path bogus_key
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
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
  assert_match "issue"      '^issue$'      "$OUT"
  local lines
  lines=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq "6 kinds" "6" "$lines"
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

# AC: get returns the literal string NOT_FOUND when the resolved path does not exist on disk (D2-revised; spec 011 amendment 2026-05-13)
case_jimfile_get_returns_not_found_when_file_missing() {
  local dir actual
  dir=$(empty_dir get_not_found)
  actual=$(cd "$dir" && bash "$SCRIPT_JIMFILE" get vision)
  assert_eq "vision missing → NOT_FOUND" "NOT_FOUND" "$actual"
}

# AC: get with -c forwards the override; NOT_FOUND when override target missing (D2-revised)
case_jimfile_get_honors_override_not_found_when_missing() {
  local cfg
  cfg=$(fixture get-override.toml 'architecture_path = "docs/arch.md"')
  run_jimfile -c "$cfg" get architecture
  assert_exit "rc" 0 "$RC"
  assert_eq   "missing override → NOT_FOUND" "NOT_FOUND" "$OUT"
}

# AC: get pre_commit returns NOT_FOUND when default ./pre-commit.sh does not exist (D2-revised)
case_jimfile_get_pre_commit_default_not_found_when_missing() {
  local dir actual
  dir=$(empty_dir get_pre_commit)
  actual=$(cd "$dir" && bash "$SCRIPT_JIMFILE" get pre_commit)
  assert_eq "pre_commit missing → NOT_FOUND" "NOT_FOUND" "$actual"
}

# AC: get returns the resolved path when the file exists on disk (D2)
case_jimfile_get_returns_path_when_file_exists() {
  local dir target cfg
  dir=$(empty_dir get_present_file)
  target="$dir/V.md"
  : > "$target"
  cfg=$(fixture get-present.toml "vision_path = \"$target\"")
  run_jimfile -c "$cfg" get vision
  assert_exit "rc" 0 "$RC"
  assert_eq   "vision present → path" "$target" "$OUT"
}

# AC: get returns NOT_FOUND when the resolved path is missing under an explicit override (D2-revised)
case_jimfile_get_returns_not_found_with_explicit_override() {
  local cfg
  cfg=$(fixture get-missing.toml 'vision_path = "/nonexistent/V.md"')
  run_jimfile -c "$cfg" get vision
  assert_exit "rc" 0 "$RC"
  assert_eq   "vision missing → NOT_FOUND" "NOT_FOUND" "$OUT"
}

# AC: directory-typed path key — exists → returns dir path (D2 dir semantics)
case_jimfile_get_specs_dir_exists_returns_path() {
  local specs cfg
  specs=$(empty_dir get_specs_present)
  cfg=$(fixture get-specs-present.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" get specs
  assert_exit "rc" 0 "$RC"
  assert_eq   "specs dir exists → path" "$specs" "$OUT"
}

# AC: directory-typed path key — missing → NOT_FOUND (D2-revised dir semantics)
case_jimfile_get_specs_dir_missing_returns_not_found() {
  local cfg
  cfg=$(fixture get-specs-missing.toml 'specs_path = "/nonexistent/specs"')
  run_jimfile -c "$cfg" get specs
  assert_exit "rc" 0 "$RC"
  assert_eq   "specs dir missing → NOT_FOUND" "NOT_FOUND" "$OUT"
}

# AC: directory-typed brainstorms key — exists → returns dir path
case_jimfile_get_brainstorms_dir_exists_returns_path() {
  local brain cfg
  brain=$(empty_dir get_brain_present)
  cfg=$(fixture get-brain-present.toml "brainstorms_path = \"$brain\"")
  run_jimfile -c "$cfg" get brainstorms
  assert_exit "rc" 0 "$RC"
  assert_eq   "brainstorms dir exists → path" "$brain" "$OUT"
}

# AC: directory-typed brainstorms key — missing → NOT_FOUND
case_jimfile_get_brainstorms_dir_missing_returns_not_found() {
  local cfg
  cfg=$(fixture get-brain-missing.toml 'brainstorms_path = "/nonexistent/brain"')
  run_jimfile -c "$cfg" get brainstorms
  assert_exit "rc" 0 "$RC"
  assert_eq   "brainstorms dir missing → NOT_FOUND" "NOT_FOUND" "$OUT"
}

# AC: directory-typed debug key — exists → returns dir path
case_jimfile_get_debug_dir_exists_returns_path() {
  local debug cfg
  debug=$(empty_dir get_debug_present)
  cfg=$(fixture get-debug-present.toml "debug_path = \"$debug\"")
  run_jimfile -c "$cfg" get debug
  assert_exit "rc" 0 "$RC"
  assert_eq   "debug dir exists → path" "$debug" "$OUT"
}

# AC: directory-typed debug key — missing → NOT_FOUND
case_jimfile_get_debug_dir_missing_returns_not_found() {
  local cfg
  cfg=$(fixture get-debug-missing.toml 'debug_path = "/nonexistent/debug"')
  run_jimfile -c "$cfg" get debug
  assert_exit "rc" 0 "$RC"
  assert_eq   "debug dir missing → NOT_FOUND" "NOT_FOUND" "$OUT"
}

# AC: get with no key argument exits 2 (malformed invocation)
case_jimfile_get_missing_arg_exits_2() {
  run_jimfile get
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: get with an unknown key bubbles up jimconf's exit-1
case_jimfile_get_unknown_key_exits_1() {
  run_jimfile get bogus_key
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: path issue <slug> returns <issues_dir>/<slug>.md (spec 017 AC-P1)
# Pure path composition; does not touch the filesystem. Slug must pass
# AC-C7 validation (alphanumeric + dash); see case_jimfile_path_issue_*
# rejection cases for invalid-slug behavior.
case_jimfile_path_issue_basic() {
  local issues cfg
  issues=$(empty_dir issues_basic)
  cfg=$(fixture path-issue-basic.toml "issues_path = \"$issues\"")
  run_jimfile -c "$cfg" path issue 20260530-test-slug
  assert_exit "rc" 0 "$RC"
  assert_eq   "issue path" "$issues/20260530-test-slug.md" "$OUT"
}

# AC: next-id issue <subject> returns YYYYMMDD-normalized-slug (spec 017 AC-C6, AC-C7)
case_jimfile_next_id_issue_basic() {
  run_jimfile next-id issue "Auth Bug"
  local today
  today=$(date +%Y%m%d)
  assert_exit "rc" 0 "$RC"
  assert_eq   "next-id issue" "$today-auth-bug" "$OUT"
}

# AC: path issue rejects path-traversal in slug (security.md Finding 1)
case_jimfile_path_issue_rejects_path_traversal() {
  run_jimfile path issue "../etc/passwd"
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: path issue rejects literal '..' slug (security.md Finding 1)
case_jimfile_path_issue_rejects_dotdot() {
  run_jimfile path issue ".."
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: path issue rejects slug containing slash (security.md Finding 1)
case_jimfile_path_issue_rejects_slash() {
  run_jimfile path issue "foo/bar"
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: path issue rejects slug with backslash (security.md Finding 1)
case_jimfile_path_issue_rejects_backslash() {
  run_jimfile path issue 'foo\bar'
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: path issue rejects slug with leading dot (security.md Finding 1)
case_jimfile_path_issue_rejects_leading_dot() {
  run_jimfile path issue ".hidden"
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: path issue accepts an uppercase new-scheme id under is_valid_id (spec 021 AC #7)
# The broadened id charset admits the project/template prefixes (e.g. JIM-…),
# replacing the old lowercase-only is_valid_slug guard at this callsite.
case_jimfile_path_issue_accepts_uppercase_id() {
  local cfg
  cfg=$(fixture path-issue-upper.toml 'issues_path = "docs/issues"')
  run_jimfile -c "$cfg" path issue "JIM-wire-consumers"
  assert_exit "rc" 0 "$RC"
  assert_eq   "uppercase id path" "docs/issues/JIM-wire-consumers.md" "$OUT"
}

# AC: path issue (no slug) returns the configured issues_path
# Single-arg form mirrors `path debug` — returns the directory, not an error.
case_jimfile_path_issue_no_arg_returns_dir() {
  local cfg
  cfg=$(fixture path-issue-no-arg.toml 'issues_path = "docs/issues"')
  run_jimfile -c "$cfg" path issue
  assert_exit "rc" 0 "$RC"
  assert_eq   "issues dir" "docs/issues" "$OUT"
}

# AC: path issue honors configured issues_path (AC-P2)
case_jimfile_path_issue_honors_override() {
  local cfg
  cfg=$(fixture path-issue-override.toml 'issues_path = "docs/my-findings"')
  run_jimfile -c "$cfg" path issue 20260530-x
  assert_exit "rc" 0 "$RC"
  assert_eq   "issue path with override" "docs/my-findings/20260530-x.md" "$OUT"
}

# AC: path issue strips trailing slash from issues_path
case_jimfile_path_issue_strips_trailing_slash() {
  local cfg
  cfg=$(fixture path-issue-trail.toml 'issues_path = "docs/issues/"')
  run_jimfile -c "$cfg" path issue 20260530-y
  assert_eq "no double slash" "docs/issues/20260530-y.md" "$OUT"
}

# AC: next-id issue with no subject exits 2 (malformed invocation)
case_jimfile_next_id_issue_missing_subject_exits_2() {
  run_jimfile next-id issue
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: next-id issue rejects subject that normalizes to empty (e.g., "!!!")
case_jimfile_next_id_issue_rejects_invalid_subject() {
  run_jimfile next-id issue "!!!"
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: next-id issue normalizes subject with special characters (AC-C7)
case_jimfile_next_id_issue_normalizes_special_chars() {
  run_jimfile next-id issue "Foo, Bar & Baz?!"
  local today
  today=$(date +%Y%m%d)
  assert_eq "normalized" "$today-foo-bar-baz" "$OUT"
}

# AC: next-id issue strips dotdot in subject (path-safety in slug step)
case_jimfile_next_id_issue_handles_dotdot_in_subject() {
  run_jimfile next-id issue "../../etc/passwd"
  local today
  today=$(date +%Y%m%d)
  assert_exit "rc" 0 "$RC"
  assert_eq   "no traversal in slug" "$today-etc-passwd" "$OUT"
}

# AC: existing next-id <group> behavior is preserved (regression guard)
# 'issue' as a kind-arg should not break group-name dispatch for other groups.
case_jimfile_next_id_group_still_works() {
  local specs cfg
  specs=$(empty_dir specs_issue_regression)
  mkdir -p "$specs/jim/001-a"
  cfg=$(fixture next-issue-regression.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id jim
  assert_eq "002 from existing group" "002" "$OUT"
}

# AC: next-num issue returns 1 when no issue carries a num: field (spec 019 DD #5)
case_jimfile_nextnum_empty_returns_1() {
  local issues cfg
  issues=$(empty_dir nextnum_empty)
  cfg=$(fixture nextnum-empty.toml "issues_path = \"$issues\"")
  run_jimfile -c "$cfg" next-num issue
  assert_exit "rc" 0 "$RC"
  assert_eq   "next-num empty dir" "1" "$OUT"
}

# AC: next-num issue returns max(num)+1 across the collection (spec 019 DD #5)
# Files without a num: line are ignored; INDEX.md (no num:) is ignored too.
case_jimfile_nextnum_returns_max_plus_one() {
  local issues cfg
  issues=$(empty_dir nextnum_max)
  printf -- '---\nnum: 3\nstatus: open\n---\nbody\n' > "$issues/20260101-a.md"
  printf -- '---\nnum: 7\nstatus: open\n---\nbody\n' > "$issues/20260102-b.md"
  printf -- '---\nstatus: open\n---\nno num here\n'  > "$issues/20260103-c.md"
  printf -- '# INDEX\n- nothing\n'                   > "$issues/INDEX.md"
  cfg=$(fixture nextnum-max.toml "issues_path = \"$issues\"")
  run_jimfile -c "$cfg" next-num issue
  assert_exit "rc" 0 "$RC"
  assert_eq   "next-num max+1" "8" "$OUT"
}

# AC: next-num requires the 'issue' kind (malformed invocation)
case_jimfile_nextnum_requires_issue_kind() {
  run_jimfile next-num
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "stderr explains" "$ERR"
}

# AC: next-id issue default scheme is byte-identical to YYYYMMDD-<slug> (spec 021 AC #1)
case_jimfile_next_id_issue_preset_default_unchanged() {
  run_jimfile next-id issue "Auth Bug"
  local today
  today=$(date +%Y%m%d)
  assert_exit "rc" 0 "$RC"
  assert_eq   "default scheme unchanged" "$today-auth-bug" "$OUT"
}

# AC: sequential preset projects the display ordinal (num) zero-padded (spec 021 AC #3a/#4)
case_jimfile_next_id_issue_preset_sequential() {
  local issues cfg
  issues=$(empty_dir nextid_seq)
  printf -- '---\nnum: 3\nstatus: open\n---\nbody\n' > "$issues/20260101-a.md"
  printf -- '---\nnum: 7\nstatus: open\n---\nbody\n' > "$issues/20260102-b.md"
  cfg=$(fixture nextid-seq.toml "issues_path = \"$issues\"
issue_id_prefix = \"sequential\"")
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit "rc" 0 "$RC"
  assert_eq   "sequential id" "0008-auth-bug" "$OUT"
}

# AC: project preset prepends the static issue_id_project tag (spec 021 AC #3b)
case_jimfile_next_id_issue_preset_project() {
  local cfg
  cfg=$(fixture nextid-project.toml 'issue_id_prefix = "project"
issue_id_project = "JIM"')
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit "rc" 0 "$RC"
  assert_eq   "project id" "JIM-auth-bug" "$OUT"
}

# AC: timestamp preset yields a sub-day-resolution prefix (spec 021 AC #3c)
case_jimfile_next_id_issue_preset_timestamp() {
  local cfg
  cfg=$(fixture nextid-timestamp.toml 'issue_id_prefix = "timestamp"')
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit  "rc" 0 "$RC"
  assert_match "timestamp id" '^[0-9]{8}T[0-9]{6}-auth-bug$' "$OUT"
}

# AC: template escape hatch renders a custom date format (spec 021 AC #3d)
case_jimfile_next_id_issue_template_date_format() {
  local cfg
  cfg=$(fixture nextid-tmpl-date.toml 'issue_id_prefix = "{date:%Y.%m.%d}"')
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit  "rc" 0 "$RC"
  assert_match "dotted date id" '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}-auth-bug$' "$OUT"
}

# AC: template escape hatch composes literal + date + seq tokens (spec 021 AC #2/#3)
case_jimfile_next_id_issue_template_combined() {
  local issues cfg
  issues=$(empty_dir nextid_tmpl_combined)
  printf -- '---\nnum: 7\nstatus: open\n---\nbody\n' > "$issues/20260101-a.md"
  cfg=$(fixture nextid-tmpl-combined.toml "issues_path = \"$issues\"
issue_id_prefix = \"JIM-{date:%Y%m%d}-{seq:03}\"")
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit  "rc" 0 "$RC"
  assert_match "combined template id" '^JIM-[0-9]{8}-008-auth-bug$' "$OUT"
}

# AC: unknown preset name informs via stderr and falls back to date (spec 021 AC #8)
case_jimfile_next_id_issue_fallback_unknown_preset() {
  local cfg today
  cfg=$(fixture nextid-fb-unknown.toml 'issue_id_prefix = "bogus"')
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit     "rc" 0 "$RC"
  assert_eq       "date fallback" "$today-auth-bug" "$OUT"
  assert_nonempty "notice on stderr" "$ERR"
}

# AC: project preset with empty tag informs and falls back to date (spec 021 AC #8)
case_jimfile_next_id_issue_fallback_empty_project() {
  local cfg today
  cfg=$(fixture nextid-fb-emptyproj.toml 'issue_id_prefix = "project"')
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit     "rc" 0 "$RC"
  assert_eq       "date fallback" "$today-auth-bug" "$OUT"
  assert_nonempty "notice on stderr" "$ERR"
}

# AC: template rendering an out-of-allowlist char informs and falls back (spec 021 AC #7/#8)
case_jimfile_next_id_issue_fallback_invalid_charset() {
  local cfg today
  cfg=$(fixture nextid-fb-charset.toml 'issue_id_prefix = "{date:%Y/%m}"')
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit     "rc" 0 "$RC"
  assert_eq       "date fallback" "$today-auth-bug" "$OUT"
  assert_nonempty "notice on stderr" "$ERR"
}

# AC: an over-length resolved prefix informs and falls back to date (spec 021 AC #11)
case_jimfile_next_id_issue_fallback_over_length() {
  local cfg today big
  big=$(printf 'a%.0s' {1..129})
  cfg=$(fixture nextid-fb-overlen.toml "issue_id_prefix = \"project\"
issue_id_project = \"$big\"")
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit     "rc" 0 "$RC"
  assert_eq       "date fallback" "$today-auth-bug" "$OUT"
  assert_nonempty "notice on stderr" "$ERR"
}

# AC: blank issue_id_prefix is zero-config — silent date default, no notice (spec 021 AC #9)
case_jimfile_next_id_issue_blank_is_silent() {
  local cfg today
  cfg=$(fixture nextid-blank.toml 'issue_id_prefix = ""')
  today=$(date +%Y%m%d)
  run_jimfile -c "$cfg" next-id issue "Auth Bug"
  assert_exit "rc" 0 "$RC"
  assert_eq   "date default" "$today-auth-bug" "$OUT"
  assert_eq   "no notice on stderr" "" "$ERR"
}

# AC: the is_valid_id validator is byte-identical across its three copies
# (spec 021 security.md Finding 5 — guard against hand-sync drift).
case_jimfile_is_valid_id_triplicate_identical() {
  local a b c
  a="$(extract_is_valid_id "$REPO_ROOT/skills/file/scripts/jimfile.sh")"
  b="$(extract_is_valid_id "$REPO_ROOT/skills/issue/scripts/index.sh")"
  c="$(extract_is_valid_id "$REPO_ROOT/skills/issue/scripts/render.sh")"
  assert_nonempty "jimfile.sh is_valid_id extracted" "$a"
  assert_eq "index.sh copy matches jimfile.sh"  "$a" "$b"
  assert_eq "render.sh copy matches jimfile.sh" "$a" "$c"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_JIMFILE" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_JIMFILE — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
