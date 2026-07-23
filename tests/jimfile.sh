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

# AC: next-id ignores a 000-blueprint dir (parses to id 0, never raises max) —
#     regression-locks the reserved-slot invariant (029 plan Task 2)
case_jimfile_next_id_ignores_000_blueprint() {
  local specs cfg
  specs=$(empty_dir next_ignores_bp)
  mkdir -p "$specs/jim/000-blueprint" "$specs/jim/001-foo" "$specs/jim/002-bar"
  cfg=$(fixture next-bp.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id jim
  assert_exit "rc" 0 "$RC"
  assert_eq "000-blueprint ignored; max is 002" "003" "$OUT"
}

# ─── spec 047: next-id vacated-id floor (consults the specs-root ledger) ──────

# AC 11: a tail-move split vacated cart/006..009 — the floor raises next-id past
# the directory max, so cart never re-mints a moved id.
case_jimfile_next_id_split_floor_raises() {
  local specs cfg
  specs=$(empty_dir nextid_floor)
  mkdir -p "$specs/cart/001-a" "$specs/cart/005-e"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=cart,checkout;moved=cart/006:checkout/001,cart/009:checkout/004\n' > "$specs/ledger.md"
  cfg=$(fixture nextid-floor.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id cart
  assert_exit "rc" 0 "$RC"
  assert_eq "floor 009 raises to 010" "010" "$OUT"
}

# AC 11: the merge is monotonic — when the directory max exceeds the vacated
# floor, the directory wins (floor only ever raises, never lowers).
case_jimfile_next_id_dir_max_wins() {
  local specs cfg
  specs=$(empty_dir nextid_dirwins)
  mkdir -p "$specs/cart/012-l"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=cart,checkout;moved=cart/006:checkout/001,cart/009:checkout/004\n' > "$specs/ledger.md"
  cfg=$(fixture nextid-dirwins.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id cart
  assert_eq "dir max 012 wins over floor 009" "013" "$OUT"
}

# AC 11: no specs-root ledger → the floor consult degrades and next-id keeps its
# directory-only behavior (older checkouts unaffected).
case_jimfile_next_id_no_ledger_dir_behavior() {
  local specs cfg
  specs=$(empty_dir nextid_noledger)
  mkdir -p "$specs/cart/001-a" "$specs/cart/002-b"
  cfg=$(fixture nextid-noledger.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id cart
  assert_exit "rc" 0 "$RC"
  assert_eq "pure dir max+1" "003" "$OUT"
}

# AC 11 / security Finding 2: a malformed moved= element is inert end-to-end — a
# valid sibling still floors next-id (fail-closed floor).
case_jimfile_next_id_ignores_malformed_moved() {
  local specs cfg
  specs=$(empty_dir nextid_badmoved)
  mkdir -p "$specs/cart/002-b"
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=cart,checkout;moved=GARBAGE,cart/006:checkout/001\n' > "$specs/ledger.md"
  cfg=$(fixture nextid-badmoved.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id cart
  assert_eq "valid sibling floors to 007" "007" "$OUT"
}

# AC 11: a group name retired by a symmetric split and later re-minted floors
# PAST the old archive — a fresh empty cart/ still gets 004, never 001, so a
# vacated id never comes to mean two specs.
case_jimfile_next_id_retired_group_remint_floors() {
  local specs cfg
  specs=$(empty_dir nextid_remint)
  mkdir -p "$specs/cart"   # re-minted, empty
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=split;old=cart;new=shop,store;moved=cart/001:shop/001,cart/003:store/001\n' > "$specs/ledger.md"
  cfg=$(fixture nextid-remint.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id cart
  assert_eq "floors past old archive" "004" "$OUT"
}

# AC 15: a source group retired by a merge and later re-minted floors PAST its
# old archive — a fresh empty wishlist/ gets 004, never 001, so an id absorbed
# into the merge target never comes to mean two specs (the merge dual of the
# split re-mint floor, riding task 1's vacated-max widening end-to-end).
case_jimfile_next_id_merge_retired_source_remint_floors() {
  local specs cfg
  specs=$(empty_dir nextid_merge_remint)
  mkdir -p "$specs/wishlist"   # re-minted, empty
  printf '100\t2026-01-01T00:00:00Z\tpartition\tfinished\ttier=project;op=merge;old=wishlist,cart;new=cart;moved=wishlist/001:cart/007,wishlist/002:cart/008,wishlist/003:cart/009\n' > "$specs/ledger.md"
  cfg=$(fixture nextid-merge-remint.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id wishlist
  assert_eq "floors past merged-away archive" "004" "$OUT"
}

# AC 11: id-space exhaustion — a next id above 999 is refused rc 1 with a stderr
# message, never emitting a 4-digit id.
case_jimfile_next_id_999_exhaustion_rc1() {
  local specs cfg
  specs=$(empty_dir nextid_exhaust)
  mkdir -p "$specs/cart/999-z"
  cfg=$(fixture nextid-exhaust.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id cart
  assert_exit "rc" 1 "$RC"
  assert_match "names exhaustion" "id space exhausted" "$ERR"
  assert_eq "no id printed" "" "$OUT"
}

# AC: mv-spec renames the {id}-wip dir to {id}-{name}; the ledger travels with it
case_jimfile_mv_spec_renames_wip() {
  local specs cfg
  specs=$(empty_dir mvspec_rename)
  mkdir -p "$specs/jim/027-wip"
  printf 'x\n' > "$specs/jim/027-wip/ledger.md"
  cfg=$(fixture mvspec-rename.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec jim 027 review
  assert_exit "rc" 0 "$RC"
  assert_eq "target printed"   "$specs/jim/027-review" "$OUT"
  assert_eq "wip removed"      "no"  "$([[ -d "$specs/jim/027-wip" ]] && echo yes || echo no)"
  assert_eq "final exists"     "yes" "$([[ -d "$specs/jim/027-review" ]] && echo yes || echo no)"
  assert_eq "ledger travelled" "yes" "$([[ -f "$specs/jim/027-review/ledger.md" ]] && echo yes || echo no)"
}

# AC: mv-spec is a no-op success when the dir already carries the target name
case_jimfile_mv_spec_noop_when_named() {
  local specs cfg
  specs=$(empty_dir mvspec_noop)
  mkdir -p "$specs/jim/030-review"
  cfg=$(fixture mvspec-noop.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec jim 030 review
  assert_exit "rc" 0 "$RC"
  assert_eq "target printed" "$specs/jim/030-review" "$OUT"
  assert_eq "still exists"   "yes" "$([[ -d "$specs/jim/030-review" ]] && echo yes || echo no)"
}

# AC: path blueprint <group> resolves the reserved 000-blueprint/spec.md slot
case_jimfile_path_blueprint_resolves_reserved_slot() {
  local specs cfg
  specs=$(empty_dir bp_path)
  mkdir -p "$specs/jim"
  cfg=$(fixture bp-path.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" path blueprint jim
  assert_exit "rc" 0 "$RC"
  assert_eq "reserved slot path" "$specs/jim/000-blueprint/spec.md" "$OUT"
}

# AC: path blueprint rejects an invalid group via the is_valid_slug boundary
#     (security Finding 3 — write target validated, not composed from raw input)
case_jimfile_path_blueprint_rejects_invalid_group() {
  local specs cfg
  specs=$(empty_dir bp_badgroup)
  mkdir -p "$specs/jim"
  cfg=$(fixture bp-badgroup.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" path blueprint "Bad Group"
  assert_exit "rc" 1 "$RC"
  assert_eq "no path emitted"      ""    "$OUT"
  assert_eq "slug rejection reason" "yes" "$([[ "$ERR" == *rejected* ]] && echo yes || echo no)"
}

# AC: blueprint-dirname emits the reserved directory name so sibling scripts can
#     compose the path on their own base, single-sourcing the 000-blueprint literal
case_jimfile_blueprint_dirname_emits_reserved_name() {
  run_jimfile blueprint-dirname
  assert_exit "rc" 0 "$RC"
  assert_eq "reserved dir name" "000-blueprint" "$OUT"
}

# AC: mv-spec rejects a non-slug new-name before any move (is_valid_slug)
case_jimfile_mv_spec_rejects_bad_name() {
  local specs cfg
  specs=$(empty_dir mvspec_badname)
  mkdir -p "$specs/jim/031-wip"
  cfg=$(fixture mvspec-badname.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec jim 031 "../evil"
  assert_exit     "rc" 1 "$RC"
  assert_nonempty "stderr" "$ERR"
  assert_eq "wip untouched" "yes" "$([[ -d "$specs/jim/031-wip" ]] && echo yes || echo no)"
}

# AC: mv-spec rejects a non-3-digit id
case_jimfile_mv_spec_rejects_bad_id() {
  local specs cfg
  specs=$(empty_dir mvspec_badid)
  mkdir -p "$specs/jim/032-wip"
  cfg=$(fixture mvspec-badid.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec jim 32 review
  assert_exit "rc" 1 "$RC"
}

# AC: mv-spec errors when no {id}-* source dir exists
case_jimfile_mv_spec_missing_source_exits_1() {
  local specs cfg
  specs=$(empty_dir mvspec_nosrc)
  mkdir -p "$specs/jim"
  cfg=$(fixture mvspec-nosrc.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec jim 040 review
  assert_exit "rc" 1 "$RC"
}

# AC: mv-spec refuses when more than one {id}-* dir matches (ambiguous source)
case_jimfile_mv_spec_multiple_match_exits_1() {
  local specs cfg
  specs=$(empty_dir mvspec_multi)
  mkdir -p "$specs/jim/050-wip" "$specs/jim/050-foo"
  cfg=$(fixture mvspec-multi.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec jim 050 review
  assert_exit "rc" 1 "$RC"
}

# AC: mv-spec with too few args exits 2 with a message
case_jimfile_mv_spec_missing_args_exits_2() {
  run_jimfile mv-spec jim 027
  assert_exit     "rc" 2 "$RC"
  assert_nonempty "stderr" "$ERR"
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
  assert_match "blueprint"  '^blueprint$'  "$OUT"
  local lines
  lines=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  assert_eq "7 kinds" "7" "$lines"
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

# spec 023 Task 1: `valid-id` exposes is_valid_id as a rc-only subcommand so
# migrate.sh can validate a full re-derived id without a 4th SYNC copy.
case_jimfile_valid_id_accepts_good() {
  run_jimfile valid-id "20260613-re-derive-existing-issue-ids"
  assert_exit "good id rc 0" 0 "$RC"
}

case_jimfile_valid_id_rejects_traversal() {
  run_jimfile valid-id "../etc/passwd"
  assert_exit "traversal rc 1" 1 "$RC"
}

case_jimfile_valid_id_rejects_empty() {
  run_jimfile valid-id ""
  assert_exit "empty rc 1" 1 "$RC"
}

case_jimfile_valid_id_rejects_overlong() {
  local long; long="$(head -c 129 /dev/zero | tr '\0' a)"
  run_jimfile valid-id "$long"
  assert_exit "129 chars rc 1" 1 "$RC"
}

# spec 023 Task 2: prefix-from re-derives the active scheme's prefix from an
# issue's OWN stored created/num, never the run clock.
case_jimfile_prefix_from_date() {
  local cfg; cfg=$(fixture pf-date.toml 'issue_id_prefix = "date"')
  run_jimfile -c "$cfg" prefix-from "2026-06-13T14:45:30Z" 7
  assert_exit "rc" 0 "$RC"
  assert_eq   "date prefix from created" "20260613" "$OUT"
}

case_jimfile_prefix_from_timestamp() {
  local cfg; cfg=$(fixture pf-ts.toml 'issue_id_prefix = "timestamp"')
  run_jimfile -c "$cfg" prefix-from "2026-06-13T14:45:30Z" 7
  assert_exit "rc" 0 "$RC"
  assert_eq   "timestamp prefix from created" "20260613T144530" "$OUT"
}

# AC #3: a normalized day-start placeholder re-derives literally to T000000.
case_jimfile_prefix_from_timestamp_daystart() {
  local cfg; cfg=$(fixture pf-ts2.toml 'issue_id_prefix = "timestamp"')
  run_jimfile -c "$cfg" prefix-from "2026-06-13T00:00:00Z" 7
  assert_exit "rc" 0 "$RC"
  assert_eq   "day-start literal" "20260613T000000" "$OUT"
}

case_jimfile_prefix_from_sequential() {
  local cfg; cfg=$(fixture pf-seq.toml 'issue_id_prefix = "sequential"')
  run_jimfile -c "$cfg" prefix-from "2026-06-13T14:45:30Z" 7
  assert_exit "rc" 0 "$RC"
  assert_eq   "sequential from num" "0007" "$OUT"
}

case_jimfile_prefix_from_project() {
  local cfg; cfg=$(fixture pf-proj.toml 'issue_id_prefix = "project"
issue_id_project = "JIM"')
  run_jimfile -c "$cfg" prefix-from "2026-06-13T14:45:30Z" 7
  assert_exit "rc" 0 "$RC"
  assert_eq   "project tag" "JIM" "$OUT"
}

case_jimfile_prefix_from_missing_created_unmigratable() {
  local cfg; cfg=$(fixture pf-miss.toml 'issue_id_prefix = "date"')
  run_jimfile -c "$cfg" prefix-from "" 7
  assert_exit  "rc 1" 1 "$RC"
  assert_match "reason" 'un-migratable' "$ERR"
}

# F6: a present-but-non-conforming created is un-migratable, not reshaped.
case_jimfile_prefix_from_malformed_created_unmigratable() {
  local cfg; cfg=$(fixture pf-bad.toml 'issue_id_prefix = "date"')
  run_jimfile -c "$cfg" prefix-from "2026-06" 7
  assert_exit  "rc 1" 1 "$RC"
  assert_match "reason" 'un-migratable' "$ERR"
}

# DD 9: a custom {date:...} template can't be reshaped without date -d.
case_jimfile_prefix_from_custom_date_template_unmigratable() {
  local cfg; cfg=$(fixture pf-tmpl.toml 'issue_id_prefix = "X-{date:%Y%j}"')
  run_jimfile -c "$cfg" prefix-from "2026-06-13T14:45:30Z" 7
  assert_exit  "rc 1" 1 "$RC"
  assert_match "reason" 'un-migratable' "$ERR"
}

# AC: `blueprint` kind-vs-key disambiguation (spec 033 Task 2, plan DD 2).
# `get blueprint` is existence-gated: NOT_FOUND until the map file exists,
# then the configured path. Contract-lock case — behavior exists post-T1.
case_jimfile_get_blueprint_existence_gated() {
  local dir
  dir=$(empty_dir jf_map_get)
  local out
  out=$(cd "$dir" && bash "$SCRIPT_JIMFILE" get blueprint)
  assert_eq "absent map NOT_FOUND" "NOT_FOUND" "$out"
  printf '# map\n' > "$dir/BLUEPRINT.md"
  out=$(cd "$dir" && bash "$SCRIPT_JIMFILE" get blueprint)
  assert_eq "present map resolves" "BLUEPRINT.md" "$out"
}

# AC: arity disambiguates the blueprint key from the blueprint kind (spec 033
# Task 2, plan DD 2 — build-time correction): single-arg `path blueprint`
# resolves the configured map path like every other strategic key; the
# two-arg form still resolves the group-tier 000-blueprint slot.
case_jimfile_path_blueprint_arity_disambiguation() {
  run_jimfile path blueprint
  assert_exit "single-arg rc"   0              "$RC"
  assert_eq   "single-arg map"  "BLUEPRINT.md" "$OUT"
  run_jimfile path blueprint storage
  assert_exit "two-arg rc"      0              "$RC"
  assert_eq   "two-arg group slot" "docs/specs/storage/000-blueprint/spec.md" "$OUT"
}

# AC: valid-relpath accepts safe repo-relative territory paths (spec 033
# Task 2, AC #8, security Finding 9). rc-only, mirrors valid-id's shape.
case_jimfile_valid_relpath_accepts_relative() {
  run_jimfile valid-relpath "src/billing/"
  assert_exit "dir with slash"  0 "$RC"
  run_jimfile valid-relpath "api/billing"
  assert_exit "plain relative"  0 "$RC"
  run_jimfile valid-relpath "a..b/file.txt"
  assert_exit "dotdot-in-name ok (not a segment)" 0 "$RC"
}

# AC: valid-relpath rejects absolute, ..-segment, and empty paths (spec 033
# Task 2, AC #8, security Finding 9).
case_jimfile_valid_relpath_rejects_unsafe() {
  run_jimfile valid-relpath "/etc/passwd"
  assert_exit "absolute"        1 "$RC"
  run_jimfile valid-relpath "../up"
  assert_exit "leading dotdot"  1 "$RC"
  run_jimfile valid-relpath "a/../b"
  assert_exit "inner dotdot"    1 "$RC"
  run_jimfile valid-relpath ".."
  assert_exit "bare dotdot"     1 "$RC"
  run_jimfile valid-relpath ""
  assert_exit "empty"           1 "$RC"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_JIMFILE" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_JIMFILE — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
