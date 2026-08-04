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

set -uo pipefail
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

# extract_fn <name> <script>
#   Print the named function's body (def line through its column-0 closing
#   brace). Used to assert hand-synced copies of a shared rule stay
#   byte-identical across the scripts that carry them.
extract_fn() {
  local def="$1() {"
  awk -v def="$def" 'index($0, def) == 1 {f=1} f{print} f&&/^\}/{exit}' "$2"
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

# AC 9: the tree-scan spec-group form is retired. The registry is the one
# ordinal authority, so this surface no longer answers for a spec group at all —
# two computations that can disagree mid-move is the window the coordination
# work exists to close, and a patched second answer is still a second answer.
case_jimfile_next_id_spec_group_form_retired() {
  local specs cfg
  specs=$(empty_dir nextid_retired)
  mkdir -p "$specs/sdlc/001-alpha"
  cfg=$(fixture nextid-retired.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" next-id sdlc
  assert_exit  "rc"                  2  "$RC"
  assert_eq    "no ordinal on stdout" "" "$OUT"
  assert_match "points at the allocator" "jimalloc" "$ERR"
}

# ─── spec 047: next-id vacated-id floor (consults the specs-root ledger) ──────



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






# AC: mv-spec-id renames a pending provisional dir onto its realized ordinal —
# taking its source by explicit basename — and the ledger travels with it.
case_jimfile_mv_spec_id_renames_provisional() {
  local specs cfg
  specs=$(empty_dir mvspecid_prov)
  mkdir -p "$specs/sdlc/P-20260728-new-widget"
  printf 'x\n' > "$specs/sdlc/P-20260728-new-widget/ledger.md"
  cfg=$(fixture mvspecid-prov.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-new-widget 018 new-widget
  assert_exit "rc" 0 "$RC"
  assert_eq "target printed"   "$specs/sdlc/018-new-widget" "$OUT"
  assert_eq "source removed"   "no"  "$([[ -d "$specs/sdlc/P-20260728-new-widget" ]] && echo yes || echo no)"
  assert_eq "final exists"     "yes" "$([[ -d "$specs/sdlc/018-new-widget" ]] && echo yes || echo no)"
  assert_eq "ledger travelled" "yes" "$([[ -f "$specs/sdlc/018-new-widget/ledger.md" ]] && echo yes || echo no)"
}

# AC: mv-spec-id also absorbs an ordinal shift — the advisory id that named the
# placeholder giving way to the one actually bound at write.
case_jimfile_mv_spec_id_absorbs_ordinal_shift() {
  local specs cfg
  specs=$(empty_dir mvspecid_shift)
  mkdir -p "$specs/sdlc/017-wip"
  cfg=$(fixture mvspecid-shift.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc 017-wip 019 coordinated-identity
  assert_exit "rc" 0 "$RC"
  assert_eq "target printed" "$specs/sdlc/019-coordinated-identity" "$OUT"
  assert_eq "old id gone"    "no" "$([[ -d "$specs/sdlc/017-wip" ]] && echo yes || echo no)"
}

# AC: a target ordinal wider than three digits is accepted up to the width the
# registry can be rebuilt from, so the verb never becomes the reason a legal
# allocation cannot land.
case_jimfile_mv_spec_id_accepts_wide_ordinal() {
  local specs cfg
  specs=$(empty_dir mvspecid_wide)
  mkdir -p "$specs/sdlc/P-20260728-x"
  cfg=$(fixture mvspecid-wide.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-x 123456789012345 x
  assert_exit "rc" 0 "$RC"
  assert_eq "wide target printed" "$specs/sdlc/123456789012345-x" "$OUT"
}

# AC: binding offline needs the placeholder renamed onto a provisional identity,
# whose basename is the whole reserved token rather than an ordinal and a slug —
# so the same verb takes a three-argument form for that target.
case_jimfile_mv_spec_id_renames_to_provisional_target() {
  local specs cfg
  specs=$(empty_dir mvspecid_toprov)
  mkdir -p "$specs/sdlc/017-wip"
  printf 'x\n' > "$specs/sdlc/017-wip/ledger.md"
  cfg=$(fixture mvspecid-toprov.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc 017-wip P-20260728-new-widget
  assert_exit "rc" 0 "$RC"
  assert_eq "target printed"   "$specs/sdlc/P-20260728-new-widget" "$OUT"
  assert_eq "placeholder gone" "no"  "$([[ -d "$specs/sdlc/017-wip" ]] && echo yes || echo no)"
  assert_eq "ledger travelled" "yes" \
    "$([[ -f "$specs/sdlc/P-20260728-new-widget/ledger.md" ]] && echo yes || echo no)"
}

# AC: the three-argument form is for that one target and nothing else — it is
# not a general way to rename a spec dir to an arbitrary name, so a real-ordinal
# target must still go through the four-argument form.
case_jimfile_mv_spec_id_three_arg_form_is_provisional_only() {
  local specs cfg bad
  specs=$(empty_dir mvspecid_3argonly)
  mkdir -p "$specs/sdlc/017-wip"
  cfg=$(fixture mvspecid-3argonly.toml "specs_path = \"$specs\"")
  for bad in 018 018-new-widget notes P---bad "P-abc-x" "../evil"; do
    run_jimfile -c "$cfg" mv-spec-id sdlc 017-wip "$bad"
    if (( RC == 0 )); then
      CURRENT_FAILED=1; echo "    [3-arg target] accepted '$bad'"
    fi
  done
  assert_eq "placeholder untouched" "yes" "$([[ -d "$specs/sdlc/017-wip" ]] && echo yes || echo no)"
}

# AC: the provisional target refuses to clobber too — a second spec scoped the
# same day under the same title must not overwrite the first.
case_jimfile_mv_spec_id_provisional_target_refuses_clobber() {
  local specs cfg
  specs=$(empty_dir mvspecid_provclobber)
  mkdir -p "$specs/sdlc/017-wip" "$specs/sdlc/P-20260728-x"
  printf 'first\n' > "$specs/sdlc/P-20260728-x/spec.md"
  cfg=$(fixture mvspecid-provclobber.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc 017-wip P-20260728-x
  assert_exit     "rc"     1  "$RC"
  assert_nonempty "stderr" "$ERR"
  assert_eq "occupant untouched" "first" "$(cat "$specs/sdlc/P-20260728-x/spec.md")"
}

# AC: mv-spec-id refuses to clobber an existing target — a spec ordinal is path
# identity, so a collision halts rather than overwriting or suffixing.
case_jimfile_mv_spec_id_refuses_clobber() {
  local specs cfg
  specs=$(empty_dir mvspecid_clobber)
  mkdir -p "$specs/sdlc/P-20260728-x" "$specs/sdlc/018-x"
  printf 'occupied\n' > "$specs/sdlc/018-x/spec.md"
  cfg=$(fixture mvspecid-clobber.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-x 018 x
  assert_exit     "rc"       1  "$RC"
  assert_nonempty "stderr"   "$ERR"
  assert_eq "source untouched"  "yes" "$([[ -d "$specs/sdlc/P-20260728-x" ]] && echo yes || echo no)"
  assert_eq "target untouched"  "occupied" "$(cat "$specs/sdlc/018-x/spec.md")"
}

# AC: the target ordinal is digits at the padded floor and the legality ceiling —
# an unpadded, over-wide, or non-numeric id never becomes a directory name.
case_jimfile_mv_spec_id_rejects_bad_target_id() {
  local specs cfg bad
  specs=$(empty_dir mvspecid_badid)
  mkdir -p "$specs/sdlc/P-20260728-x"
  cfg=$(fixture mvspecid-badid.toml "specs_path = \"$specs\"")
  for bad in 18 1234567890123456 01a ../7 ""; do
    run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-x "$bad" x
    if (( RC == 0 )); then
      CURRENT_FAILED=1; echo "    [target id] accepted '$bad'"
    fi
  done
  assert_eq "source untouched" "yes" "$([[ -d "$specs/sdlc/P-20260728-x" ]] && echo yes || echo no)"
}

# AC: the source basename is gated to the forms a spec dir can actually carry —
# a real ordinal or the reserved provisional form — so an arbitrary directory
# name, a path escape, or a prefixed name with a token the boundary rejects
# cannot be moved through this verb.
case_jimfile_mv_spec_id_rejects_bad_source() {
  local specs cfg bad
  specs=$(empty_dir mvspecid_badsrc)
  mkdir -p "$specs/sdlc/notes" "$specs/sdlc/P---bad" "$specs/other/001-x"
  cfg=$(fixture mvspecid-badsrc.toml "specs_path = \"$specs\"")
  for bad in notes P---bad "../other/001-x" ".." "P-"; do
    run_jimfile -c "$cfg" mv-spec-id sdlc "$bad" 018 x
    if (( RC == 0 )); then
      CURRENT_FAILED=1; echo "    [source] accepted '$bad'"
    fi
  done
  assert_eq "sibling group untouched" "yes" "$([[ -d "$specs/other/001-x" ]] && echo yes || echo no)"
}

# AC: group and name cross the same boundaries every other path-composing verb
# uses, before any move happens.
case_jimfile_mv_spec_id_rejects_bad_group_and_name() {
  local specs cfg
  specs=$(empty_dir mvspecid_badgn)
  mkdir -p "$specs/sdlc/P-20260728-x"
  cfg=$(fixture mvspecid-badgn.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id "../evil" P-20260728-x 018 x
  assert_exit "bad group rc" 1 "$RC"
  run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-x 018 "../evil"
  assert_exit "bad name rc" 1 "$RC"
  assert_eq "source untouched" "yes" "$([[ -d "$specs/sdlc/P-20260728-x" ]] && echo yes || echo no)"
}

# AC: a missing source dir is a guard failure, not a silent success.
case_jimfile_mv_spec_id_missing_source_exits_1() {
  local specs cfg
  specs=$(empty_dir mvspecid_nosrc)
  mkdir -p "$specs/sdlc"
  cfg=$(fixture mvspecid-nosrc.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-absent 018 x
  assert_exit     "rc"     1  "$RC"
  assert_nonempty "stderr" "$ERR"
}

# AC: mv-spec-id with too few args exits 2 with a message — a usage error, kept
# distinct from a guard refusal. Three args is a valid arity (the provisional
# target form), so the short invocation is two.
case_jimfile_mv_spec_id_missing_args_exits_2() {
  run_jimfile mv-spec-id sdlc P-20260728-x
  assert_exit     "rc"     2  "$RC"
  assert_nonempty "stderr" "$ERR"
}

# AC: with a directory already on the target ordinal under a different slug,
# binding that ordinal halts loudly naming the drift instead of writing a second
# directory onto it. The creation path's halt, enforced in the primitive.
case_jimfile_mv_spec_id_refuses_held_ordinal() {
  local specs cfg
  specs=$(empty_dir mvspecid_held)
  mkdir -p "$specs/sdlc/P-20260728-foo" "$specs/sdlc/001-bar"
  cfg=$(fixture mvspecid-held.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-foo 001 foo
  assert_exit     "rc"     1 "$RC"
  assert_nonempty "stderr" "$ERR"
  assert_eq "source untouched" "yes" "$([[ -d "$specs/sdlc/P-20260728-foo" ]] && echo yes || echo no)"
  assert_eq "no second dir on the ordinal" "no" \
    "$([[ -d "$specs/sdlc/001-foo" ]] && echo yes || echo no)"
}

# AC: the creation-side halt is numeric too — a wider-padded occupant holds the
# same ordinal, so binding it refuses rather than writing a padding twin.
case_jimfile_mv_spec_id_refuses_padding_variant_holder() {
  local specs cfg
  specs=$(empty_dir mvspecid_padheld)
  mkdir -p "$specs/sdlc/P-20260728-foo" "$specs/sdlc/0018-alpha"
  cfg=$(fixture mvspecid-padheld.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-foo 018 foo
  assert_exit "rc" 1 "$RC"
  assert_eq "no padding twin" "no" "$([[ -d "$specs/sdlc/018-foo" ]] && echo yes || echo no)"
}

# AC: a rename does not collide with itself — the placeholder already sitting on
# the ordinal it is being named within is excluded from the occupancy check, so
# binding a spec's slug onto its own advisory ordinal still works.
case_jimfile_mv_spec_id_excludes_its_own_source() {
  local specs cfg
  specs=$(empty_dir mvspecid_selfexcl)
  mkdir -p "$specs/sdlc/018-wip"
  cfg=$(fixture mvspecid-selfexcl.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" mv-spec-id sdlc 018-wip 018 finish-coordinated-spec-identity
  assert_exit "rc" 0 "$RC"
  assert_eq "renamed in place" "yes" \
    "$([[ -d "$specs/sdlc/018-finish-coordinated-spec-identity" ]] && echo yes || echo no)"
}



# jimfile_dir_inode <path> — the inode of <path> itself, the way the guard reads
# it, so the fixture and the code agree on what identifies a directory.
jimfile_dir_inode() {
  ls -di -- "$1" 2>/dev/null | awk 'NR==1{print $1}'
}

# AC: when the target appears as a directory between the existence check and the
# move, the rename refuses rather than nests — the source goes back where it was
# and the command fails. The window is a race no CLI invocation can open
# deterministically (the check and the move are consecutive statements in one
# process), so the guard is exercised against exactly the state the race leaves.
case_jimfile_nesting_guard_restores_and_fails() {
  local specs src target ino err rc
  specs=$(empty_dir nestguard)
  mkdir -p "$specs/sdlc"
  src="$specs/sdlc/P-20260728-x"
  target="$specs/sdlc/018-x"
  mkdir -p "$src"
  printf 'payload\n' > "$src/spec.md"
  ino="$(jimfile_dir_inode "$src")"
  # Exactly what `mv <src> <target>` leaves behind when a directory appeared at
  # the target: the source now sits inside it.
  mkdir -p "$target"
  mv -- "$src" "$target/"
  err="$( source "$SCRIPT_JIMFILE" >/dev/null 2>&1
          undo_nested_rename "$src" "$target" "$ino" 2>&1 )"
  rc=$?
  assert_exit     "rc"     1 "$rc"
  assert_nonempty "names the race" "$err"
  assert_eq "source restored"  "yes" "$([[ -d "$src" ]] && echo yes || echo no)"
  assert_eq "payload restored" "payload" "$(cat "$src/spec.md" 2>/dev/null)"
  assert_eq "nothing left nested" "no" \
    "$([[ -d "$target/P-20260728-x" ]] && echo yes || echo no)"
}

# AC: a rename that actually landed is not mistaken for the race — the guard
# identifies the moved directory itself, so a target that merely happens to
# contain a similarly-named entry is left alone.
case_jimfile_nesting_guard_passes_a_real_rename() {
  local specs src target ino rc
  specs=$(empty_dir nestguard_ok)
  mkdir -p "$specs/sdlc"
  src="$specs/sdlc/P-20260728-x"
  target="$specs/sdlc/018-x"
  mkdir -p "$src"
  ino="$(jimfile_dir_inode "$src")"
  mv -- "$src" "$target"
  # A sub-entry sharing the source basename must not read as the artifact.
  mkdir -p "$target/P-20260728-x"
  ( source "$SCRIPT_JIMFILE" >/dev/null 2>&1
    undo_nested_rename "$src" "$target" "$ino" ) 2>/dev/null
  rc=$?
  assert_exit "rc" 0 "$rc"
  assert_eq "target left in place" "yes" "$([[ -d "$target" ]] && echo yes || echo no)"
  assert_eq "source not resurrected" "no" "$([[ -d "$src" ]] && echo yes || echo no)"
}

# AC: a rename that landed by copying rather than by renaming is not mistaken for
# the race. `mv` guarantees the contents arrive, not that the inode survives — on
# a cross-device move it copies and deletes, which is what renaming a lower or
# merged directory on an overlay filesystem becomes. Staged here exactly as `mv`
# leaves it: new inode, correct tree, source gone.
case_jimfile_nesting_guard_copy_fallback_reads_as_landed() {
  local specs src target ino rc err
  specs=$(empty_dir nestguard_copy)
  mkdir -p "$specs/sdlc"
  src="$specs/sdlc/P-20260728-x"
  target="$specs/sdlc/018-x"
  mkdir -p "$src"
  printf 'payload\n' > "$src/spec.md"
  ino="$(jimfile_dir_inode "$src")"
  cp -R -- "$src" "$target" && rm -rf -- "$src"
  err="$( source "$SCRIPT_JIMFILE" >/dev/null 2>&1
          undo_nested_rename "$src" "$target" "$ino" 2>&1 )"
  rc=$?
  assert_exit "rc"                 0         "$rc"
  assert_eq   "no repair demanded" ""        "$err"
  assert_eq   "target holds the payload" "payload" "$(cat "$target/spec.md" 2>/dev/null)"
  assert_eq   "source not resurrected" "no" "$([[ -d "$src" ]] && echo yes || echo no)"
}

# AC: an unreadable source inode degrades to the basename tell rather than passing
# everything — the guard still refuses a move that nested. The callers refuse
# before the move, so this is the residual shape only.
case_jimfile_nesting_guard_empty_inode_still_detects_nesting() {
  local specs src target rc
  specs=$(empty_dir nestguard_noino)
  mkdir -p "$specs/sdlc"
  src="$specs/sdlc/P-20260728-x"
  target="$specs/sdlc/018-x"
  mkdir -p "$src"
  mkdir -p "$target"
  mv -- "$src" "$target/"
  ( source "$SCRIPT_JIMFILE" >/dev/null 2>&1
    undo_nested_rename "$src" "$target" "" ) 2>/dev/null
  rc=$?
  assert_exit "rc" 1 "$rc"
  assert_eq "source restored" "yes" "$([[ -d "$src" ]] && echo yes || echo no)"
}

# jimfile_copying_mv_shim — a directory holding an `mv` that copies and deletes
# instead of renaming, the way `mv` behaves across devices. Prepended to PATH so
# the rename verbs are driven through their real command surface against that
# behavior: the guard's own fixtures call it directly and never exercise the
# `src_ino` capture or the `|| return 1` wiring, which is where a false positive
# actually reaches a caller.
jimfile_copying_mv_shim() {
  local dir
  dir=$(empty_dir "$1")
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -uo pipefail' \
    '[[ "${1:-}" == "--" ]] && shift' \
    'cp -R -- "$1" "$2" && rm -rf -- "$1"' > "$dir/mv"
  chmod +x "$dir/mv"
  printf '%s' "$dir"
}

# AC: mv-spec-id reports success when the underlying move copied rather than
# renamed — the whole verb, not the guard in isolation.
case_jimfile_mv_spec_id_lands_through_a_copying_mv() {
  local specs cfg shim oldpath
  specs=$(empty_dir mvspecid_copy)
  mkdir -p "$specs/sdlc/P-20260728-x"
  printf 'payload\n' > "$specs/sdlc/P-20260728-x/spec.md"
  cfg=$(fixture mvspecid-copy.toml "specs_path = \"$specs\"")
  shim=$(jimfile_copying_mv_shim mvspecid_copy_bin)
  oldpath="$PATH"; PATH="$shim:$PATH"
  run_jimfile -c "$cfg" mv-spec-id sdlc P-20260728-x 018 x
  PATH="$oldpath"
  assert_exit "rc"          0 "$RC"
  assert_eq   "no stderr"   "" "$ERR"
  assert_eq   "landed"      "yes" "$([[ -d "$specs/sdlc/018-x" ]] && echo yes || echo no)"
  assert_eq   "payload"     "payload" "$(cat "$specs/sdlc/018-x/spec.md" 2>/dev/null)"
  assert_eq   "source gone" "no" "$([[ -d "$specs/sdlc/P-20260728-x" ]] && echo yes || echo no)"
}


# AC: a leading token wider than an ordinal the registry could be rebuilt from
# is not an ordinal — the predicate reads that ordinal as free rather than held
# by a sibling it cannot represent.
case_jimfile_spec_ordinal_holder_over_wide_sibling_is_free() {
  local specs cfg
  specs=$(empty_dir soh_overwide)
  mkdir -p "$specs/sdlc/001-alpha" "$specs/sdlc/0000000000000000018-wide"
  cfg=$(fixture soh-overwide.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 18
  assert_exit "predicate reports free" 1 "$RC"
}

# AC: an ordinal spelled with different padding is the same ordinal — a spec
# ordinal is a number, so '18' collides with an existing '018-…' rather than
# reading as free space.
case_jimfile_spec_ordinal_holder_padding_variant_held() {
  local specs cfg
  specs=$(empty_dir soh_padding)
  mkdir -p "$specs/sdlc/018-alpha"
  cfg=$(fixture soh-padding.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 18
  assert_exit "held rc"       0            "$RC"
  assert_eq   "names the holder" "018-alpha" "$OUT"
}

# AC: a bare-ordinal directory (no slug) holds its ordinal too — occupancy is
# about the ordinal, not about carrying a name after it.
case_jimfile_spec_ordinal_holder_bare_occupant_held() {
  local specs cfg
  specs=$(empty_dir soh_bare)
  mkdir -p "$specs/sdlc/018"
  cfg=$(fixture soh-bare.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 018
  assert_exit "held rc"          0     "$RC"
  assert_eq   "names the holder" "018" "$OUT"
}

# AC: an unheld ordinal reports free — rc 1 with no holder named, distinct from
# the rc 2 an unusable argument earns.
case_jimfile_spec_ordinal_holder_free_ordinal() {
  local specs cfg
  specs=$(empty_dir soh_free)
  mkdir -p "$specs/sdlc/001-a" "$specs/sdlc/003-c"
  cfg=$(fixture soh-free.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 002
  assert_exit "free rc"      1  "$RC"
  assert_eq   "no holder"    "" "$OUT"
}

# AC: a rename excludes its own source, so a directory already sitting on the
# ordinal it is being renamed within does not collide with itself.
case_jimfile_spec_ordinal_holder_excludes_source() {
  local specs cfg
  specs=$(empty_dir soh_exclude)
  mkdir -p "$specs/sdlc/018-wip"
  cfg=$(fixture soh-exclude.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 018 --exclude 018-wip
  assert_exit "excluded source reads free" 1  "$RC"
  assert_eq   "no holder"                  "" "$OUT"
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 018
  assert_exit "unexcluded still held" 0 "$RC"
}

# AC: a sibling whose leading token is not a usable ordinal — a plain name, a
# pending provisional dir, or a token wider than the registry could be rebuilt
# from — is never counted as a holder and never errors the run.
case_jimfile_spec_ordinal_holder_skips_malformed_siblings() {
  local specs cfg
  specs=$(empty_dir soh_malformed)
  mkdir -p "$specs/sdlc/notes" "$specs/sdlc/P-20260728-x" \
           "$specs/sdlc/0000000000000000018-wide" "$specs/sdlc/018-alpha"
  cfg=$(fixture soh-malformed.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 019
  assert_exit "junk siblings do not hold 019" 1  "$RC"
  assert_eq   "no stderr noise"               "" "$ERR"
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 18
  assert_exit "the real holder is still found" 0            "$RC"
  assert_eq   "names the holder"               "018-alpha"  "$OUT"
}

# AC: a group with no directory at all holds nothing — free, not an error.
case_jimfile_spec_ordinal_holder_absent_group_is_free() {
  local specs cfg
  specs=$(empty_dir soh_nogroup)
  mkdir -p "$specs"
  cfg=$(fixture soh-nogroup.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 001
  assert_exit "free rc"   1  "$RC"
  assert_eq   "no holder" "" "$OUT"
}

# AC: unusable arguments are a usage failure (rc 2), never a silent "free" —
# reading a rejected ordinal as unoccupied is what lets a bad token through.
case_jimfile_spec_ordinal_holder_rejects_bad_input() {
  local specs cfg
  specs=$(empty_dir soh_badinput)
  mkdir -p "$specs/sdlc/018-alpha"
  cfg=$(fixture soh-badinput.toml "specs_path = \"$specs\"")
  run_jimfile -c "$cfg" spec-ordinal-holder "../evil" 018
  assert_exit "bad group rc" 2 "$RC"
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 01a
  assert_exit "non-numeric ordinal rc" 2 "$RC"
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 1234567890123456
  assert_exit "over-wide ordinal rc" 2 "$RC"
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc 018 --exclude "../evil"
  assert_exit "bad exclude rc" 2 "$RC"
  run_jimfile -c "$cfg" spec-ordinal-holder sdlc
  assert_exit "missing ordinal rc" 2 "$RC"
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

# AC: a provisional spec's artifact paths resolve through the same helper — the
# reserved token IS the whole directory basename, so the two-argument form takes
# it as one piece rather than composing a fabricated '{token}-{name}' directory.
case_jimfile_path_spec_provisional_form() {
  local cfg
  cfg=$(fixture path-prov.toml 'specs_path = "docs/specs"')
  run_jimfile -c "$cfg" path spec sdlc P-20260728-new-widget
  assert_exit "rc" 0 "$RC"
  assert_eq   "spec path" "docs/specs/sdlc/P-20260728-new-widget/spec.md" "$OUT"
  run_jimfile -c "$cfg" path plan sdlc P-20260728-new-widget
  assert_eq "plan path" "docs/specs/sdlc/P-20260728-new-widget/plan.md" "$OUT"
  run_jimfile -c "$cfg" path research sdlc P-20260728-new-widget
  assert_eq "research path" "docs/specs/sdlc/P-20260728-new-widget/research.md" "$OUT"
}

# AC: the two-argument form is the provisional form only — a bare ordinal, a
# malformed token, or a path escape is refused rather than composed into a
# directory of its own.
case_jimfile_path_spec_two_arg_is_provisional_only() {
  local cfg bad
  cfg=$(fixture path-prov-only.toml 'specs_path = "docs/specs"')
  for bad in 018 P---bad "P-20260728" "../evil" "P-2026072-x"; do
    run_jimfile -c "$cfg" path spec sdlc "$bad"
    if (( RC == 0 )); then
      CURRENT_FAILED=1; echo "    [two-arg] accepted '$bad' → $OUT"
    fi
  done
}

# AC 15: the provisional-identity grammar is one authoritative rule — the
# is_prov_token body is byte-identical across the three scripts that read the
# form, so a loosened copy fails here instead of silently widening a boundary.
case_jimfile_is_prov_token_triplicate_identical() {
  local a b c
  a="$(extract_fn is_prov_token "$REPO_ROOT/skills/file/scripts/jimfile.sh")"
  b="$(extract_fn is_prov_token "$REPO_ROOT/skills/file/scripts/jimalloc.sh")"
  c="$(extract_fn is_prov_token "$REPO_ROOT/skills/spec/scripts/reconcile.sh")"
  assert_nonempty "jimfile.sh is_prov_token extracted" "$a"
  assert_eq "jimalloc.sh copy matches jimfile.sh"  "$a" "$b"
  assert_eq "reconcile.sh copy matches jimfile.sh" "$a" "$c"
}

# AC 15: the shared rule carries the slug through the id boundary too, so a
# token the allocator could never mint — its slug leading with a separator — is
# refused rather than composed into a directory name.
case_jimfile_path_spec_provisional_slug_clears_boundary() {
  local cfg bad
  cfg=$(fixture path-prov-slug.toml 'specs_path = "docs/specs"')
  for bad in "P-20260728--leading" "P-20260728-.dot" "P-20260728-_under"; do
    run_jimfile -c "$cfg" path spec sdlc "$bad"
    if (( RC == 0 )); then
      CURRENT_FAILED=1; echo "    [slug boundary] accepted '$bad' → $OUT"
    fi
  done
}

# AC: the numeric form validates its tokens at the composition boundary, the way
# every other path-composing arm does — a malformed group, id, or name never
# becomes part of a path this helper hands back.
case_jimfile_path_spec_validates_numeric_form() {
  local cfg
  cfg=$(fixture path-numeric-gates.toml 'specs_path = "docs/specs"')
  run_jimfile -c "$cfg" path spec "../evil" 018 name
  assert_exit "bad group rc" 1 "$RC"
  run_jimfile -c "$cfg" path spec sdlc 18 name
  assert_exit "unpadded id rc" 1 "$RC"
  run_jimfile -c "$cfg" path spec sdlc 01a name
  assert_exit "non-numeric id rc" 1 "$RC"
  run_jimfile -c "$cfg" path spec sdlc 1234567890123456 name
  assert_exit "over-wide id rc" 1 "$RC"
  run_jimfile -c "$cfg" path spec sdlc 018 "../evil"
  assert_exit "bad name rc" 1 "$RC"
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
  a="$(extract_fn is_valid_id "$REPO_ROOT/skills/file/scripts/jimfile.sh")"
  b="$(extract_fn is_valid_id "$REPO_ROOT/skills/issue/scripts/index.sh")"
  c="$(extract_fn is_valid_id "$REPO_ROOT/skills/issue/scripts/render.sh")"
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

# ─── Section: ordinal width bound (cross-file value agreement) ───────────────

# The ordinal width bound is ONE value — ALLOC_MAX_ORD_DIGITS in jimalloc.sh —
# worn in spellings that cannot be byte-compared: jimalloc compares against the
# constant (in exactly one function, alloc_valid_ord), jimfile and jimledger
# carry regex literals, and jimledger's awk isord carries arithmetic bounds.
# This case compares extracted VALUES, so a divergence in any spelling is loud.
# Two deliberate rules share the ceiling: CANONICAL SPELLING {3,15} (the %03d
# form — tree basenames, mv-spec-id, the path composer, the ledger parser and
# move gates) and NUMERIC ACCEPTANCE {1,15} (occupancy, which reads '18' and
# '018' as one ordinal, the same leniency the registry's canon input has). The
# partition maps' exactly-3 starts are a protocol cap (≤999), not this bound.
case_jimfile_ordinal_width_bound_single_sourced() {
  local alloc="$REPO_ROOT/skills/file/scripts/jimalloc.sh"
  local ledger="$REPO_ROOT/skills/ledger/scripts/jimledger.sh"
  local max
  max="$(grep -oE '^ALLOC_MAX_ORD_DIGITS=[0-9]+' "$alloc" | cut -d= -f2)"
  assert_eq "the one named constant" "15" "$max"
  assert_eq "jimalloc compares against the constant in one function only" "1" \
    "$(grep -cE '[<>]=? ALLOC_MAX_ORD_DIGITS' "$alloc")"
  assert_eq "jimalloc spells no width literal of its own" "0" \
    "$(grep -oE '\[0-9\]\{[0-9]+,[0-9]+\}' "$alloc" | wc -l | tr -d ' ')"
  assert_eq "jimfile canonical-spelling sites (3 gates + 2 messages)" "5" \
    "$(grep -cE "\[0-9\]\{3,$max\}" "$SCRIPT_JIMFILE")"
  assert_eq "jimfile numeric-acceptance sites (occupancy pair)" "2" \
    "$(grep -cE "\[0-9\]\{1,$max\}" "$SCRIPT_JIMFILE")"
  assert_eq "jimfile carries no other width spelling" "7" \
    "$(grep -oE '\[0-9\]\{[0-9]+,[0-9]+\}' "$SCRIPT_JIMFILE" | wc -l | tr -d ' ')"
  assert_eq "jimledger canonical-spelling sites (the two move gates)" "2" \
    "$(grep -cE "\[0-9\]\{3,$max\}" "$ledger")"
  assert_eq "jimledger carries no other width spelling" "2" \
    "$(grep -oE '\[0-9\]\{[0-9]+,[0-9]+\}' "$ledger" | wc -l | tr -d ' ')"
  assert_match "isord: canonical floor and the shared ceiling, in awk" \
    "length\(s\) >= 3 && length\(s\) <= $max" \
    "$(grep 'function isord' "$ledger")"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_JIMFILE" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_JIMFILE — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
