#!/usr/bin/env bash
#
# tests/specreconcile.sh — Tests for skills/spec/scripts/reconcile.sh
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# HOW TO RUN
#   bash tests/specreconcile.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_specreconcile="$REPO_ROOT/skills/spec/scripts/reconcile.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_specreconcile_in <repo> <args...>
#   Invoke the realizer with CWD inside <repo>, so the allocator's git plumbing
#   and the config lookup both operate on that repo. Captures OUT/ERR/RC.
run_specreconcile_in() {
  local repo="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && bash "$SCRIPT_specreconcile" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Fixtures ───────────────────────────────────────────────────────

# specrec_repo <name>
#   A git repo with a spec tree and a committer identity and NO remote — the
#   always-reachable local tier — so realization runs end to end without a
#   network. Prints the repo root.
specrec_repo() {
  local repo="$TMP_BASE/$1"
  mkdir -p "$repo/docs/specs" "$repo/docs/issues"
  git -C "$repo" init -q
  git -C "$repo" config user.name  "Test User"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config commit.gpgsign false
  printf '%s' "$repo"
}

# specrec_prov_dir <repo> <group> <basename> [frontmatter-id]
#   Create a pending provisional spec dir whose spec.md carries its identity.
#   <frontmatter-id> defaults to the basename — the matching case.
specrec_prov_dir() {
  local repo="$1" group="$2" base="$3" id="${4:-$3}"
  mkdir -p "$repo/docs/specs/$group/$base"
  printf -- '---\ntitle: "A spec"\ngroup: "%s"\nid: "%s"\nstatus: draft\n---\n\n# body\n' \
    "$group" "$id" > "$repo/docs/specs/$group/$base/spec.md"
}

# specrec_real_dir <repo> <group> <basename>
#   Create an ordinary realized spec dir (nothing pending about it).
specrec_real_dir() {
  local repo="$1" group="$2" base="$3"
  mkdir -p "$repo/docs/specs/$group/$base"
  printf -- '---\ntitle: "A spec"\ngroup: "%s"\nid: "%s"\n---\n' \
    "$group" "${base%%-*}" > "$repo/docs/specs/$group/$base/spec.md"
}

# specrec_registry <repo> — print the repo's specs.log on the coordination branch.
specrec_registry() {
  git -C "$1" cat-file -p refs/heads/jim/registry:specs.log 2>/dev/null
}

# specrec_craft_registry <repo> <log-line>...
#   Plant a specs.log on the coordination branch through plumbing. The branch is
#   push-writable, so a record the allocator itself would never emit is exactly
#   what a crafted registry looks like from the realizer's side — the vector the
#   realized ordinal has to be revalidated against.
specrec_craft_registry() {
  local repo="$1"; shift
  local blob tree commit
  blob="$(printf '%s\n' "$@" | git -C "$repo" hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tspecs.log\n' "$blob" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" -m crafted)"
  git -C "$repo" update-ref refs/heads/jim/registry "$commit"
}

# ─── Section: Test cases — scan ──────────────────────────────────────────────

# AC: the realizer finds every pending provisional spec dir across groups and
# previews the ordinal each would take, without being told where they are.
case_specreconcile_scans_pending() {
  local repo; repo="$(specrec_repo sr_scan)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_prov_dir "$repo" platform P-20260728-beta
  run_specreconcile_in "$repo"
  assert_exit  "rc" 0 "$RC"
  assert_match "previews the sdlc identity"     'sdlc/P-20260728-alpha	sdlc/001	new'         "$OUT"
  assert_match "previews the platform identity" 'platform/P-20260728-beta	platform/001	new' "$OUT"
}

# AC: a realized spec dir is not pending — only the reserved form scans.
case_specreconcile_ignores_realized_dirs() {
  local repo; repo="$(specrec_repo sr_ignore)"
  specrec_real_dir "$repo" sdlc 001-already-real
  specrec_real_dir "$repo" sdlc 000-blueprint
  run_specreconcile_in "$repo"
  assert_exit "rc" 0 "$RC"
  assert_eq "nothing previewed" "0" "$(printf '%s\n' "$OUT" | grep -c 'already-real')"
}

# AC: a directory that merely starts with the reserved prefix but carries a
# token the id boundary rejects is skipped with a warning and never reaches the
# allocator or a composed path — a warning, never a fatal stop.
case_specreconcile_invalid_token_skipped() {
  local repo; repo="$(specrec_repo sr_badtok)"
  specrec_prov_dir "$repo" sdlc P---bad
  specrec_prov_dir "$repo" sdlc P-20260728-good
  run_specreconcile_in "$repo"
  assert_exit  "rc"                     0 "$RC"
  assert_match "warns about the token"  'P---bad' "$ERR"
  assert_match "good identity previewed" 'sdlc/P-20260728-good	sdlc/001	new' "$OUT"
  assert_eq "bad identity not previewed" "0" "$(printf '%s\n' "$OUT" | grep -c 'P---bad')"
}

# AC: a failed issue-index regeneration is reported, never swallowed — the sweep
# rewrote citations on disk, so an INDEX.md that no longer describes them is a
# failure the run has to carry rather than a silent exit 0.
case_specreconcile_surfaces_failed_regen() {
  local repo issues
  repo="$(specrec_repo sr_regenfail)"
  issues="$repo/docs/issues"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  printf -- '---\nid: 20260101-c\nnum: 1\nstatus: open\ntitle: "Cites it"\n---\n\nSee sdlc/P-20260728-alpha for context.\n' \
    > "$issues/20260101-c.md"
  specrec_commit "$repo"
  # An unwritable directory where INDEX.md belongs: the atomic write's rename
  # cannot land, so index.sh fails while the sweep itself still succeeds.
  mkdir -p "$issues/INDEX.md"
  chmod 500 "$issues/INDEX.md"
  run_specreconcile_in "$repo" --apply
  chmod 700 "$issues/INDEX.md"
  assert_exit     "rc"                      1 "$RC"
  assert_nonempty "names the regen failure" "$ERR"
  assert_match "the citation was rewritten" 'See sdlc/001 for context' \
    "$(cat "$issues/20260101-c.md")"
}

# AC: detection and rewrite anchor to the SAME leading-frontmatter region — a
# file whose only matching identity line sits in the body is never treated as
# pending, so no directory is renamed behind a rewrite that cannot touch it.
case_specreconcile_body_id_is_not_pending() {
  local repo dir
  repo="$(specrec_repo sr_bodyid)"
  dir="$repo/docs/specs/sdlc/P-20260728-alpha"
  mkdir -p "$dir"
  printf -- '---\ntitle: "A spec"\ngroup: "sdlc"\n---\n\nid: "P-20260728-alpha"\n' \
    > "$dir/spec.md"
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc"                   0 "$RC"
  assert_match "nothing to realize"   'nothing to realize' "$OUT"
  assert_eq "dir untouched" "yes" "$([[ -d "$dir" ]] && echo yes || echo no)"
}

# AC: a frontmatter opened with a CRLF marker is not a frontmatter open here, so
# the file is simply not pending — the fail-safe direction (no rename) rather
# than a rename the rewrite would then no-op behind.
case_specreconcile_crlf_frontmatter_is_not_pending() {
  local repo dir
  repo="$(specrec_repo sr_crlf)"
  dir="$repo/docs/specs/sdlc/P-20260728-alpha"
  mkdir -p "$dir"
  printf -- '---\r\ntitle: "A spec"\r\nid: "P-20260728-alpha"\r\n---\r\n' \
    > "$dir/spec.md"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "dir untouched" "yes" "$([[ -d "$dir" ]] && echo yes || echo no)"
}

# AC: with the identity in the frontmatter AND a mirror line in the body, only
# the frontmatter is rewritten — the body line is quoted material, not identity.
case_specreconcile_body_mirror_line_not_rewritten() {
  local repo dir
  repo="$(specrec_repo sr_mirror)"
  dir="$repo/docs/specs/sdlc/P-20260728-alpha"
  mkdir -p "$dir"
  printf -- '---\ntitle: "A spec"\ngroup: "sdlc"\nid: "P-20260728-alpha"\n---\n\nid: "P-20260728-alpha"\n' \
    > "$dir/spec.md"
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "frontmatter realized" '^id: "001"$' \
    "$(cat "$repo/docs/specs/sdlc/001-alpha/spec.md")"
  assert_match "body mirror untouched" '^id: "P-20260728-alpha"$' \
    "$(cat "$repo/docs/specs/sdlc/001-alpha/spec.md")"
}

# AC: a pending dir whose frontmatter identity disagrees with its directory name
# is skipped with a warning — the two must corroborate before the identity is
# treated as this spec's.
case_specreconcile_id_mismatch_warns() {
  local repo; repo="$(specrec_repo sr_mismatch)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha P-20260728-something-else
  run_specreconcile_in "$repo"
  assert_exit  "rc"       0 "$RC"
  assert_match "warns about the mismatch" 'P-20260728-alpha' "$ERR"
  assert_eq "nothing previewed" "0" "$(printf '%s\n' "$OUT" | grep -c '	sdlc/')"
}

# AC: a pending dir with no spec.md to corroborate its identity is skipped with
# a warning rather than trusted on the directory name alone.
case_specreconcile_missing_spec_md_warns() {
  local repo; repo="$(specrec_repo sr_nospec)"
  mkdir -p "$repo/docs/specs/sdlc/P-20260728-orphan"
  run_specreconcile_in "$repo"
  assert_exit     "rc"      0 "$RC"
  assert_nonempty "warns"   "$ERR"
  assert_eq "nothing previewed" "0" "$(printf '%s\n' "$OUT" | grep -c '	sdlc/')"
}

# AC: an empty scan is a clean no-op that says so.
case_specreconcile_empty_scan_noop() {
  local repo; repo="$(specrec_repo sr_empty)"
  run_specreconcile_in "$repo"
  assert_exit     "rc"       0  "$RC"
  assert_nonempty "says so"  "$OUT"
  assert_eq "no registry written" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# ─── Section: Test cases — preview ───────────────────────────────────────────

# AC: the preview mutates nothing — no registry, no rename, no frontmatter edit.
case_specreconcile_preview_mutates_nothing() {
  local repo before
  repo="$(specrec_repo sr_prevnm)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  before="$(cat "$repo/docs/specs/sdlc/P-20260728-alpha/spec.md")"
  run_specreconcile_in "$repo"
  assert_exit "rc" 0 "$RC"
  assert_eq "no registry written" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
  assert_eq "dir still pending" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
  assert_eq "frontmatter untouched" "$before" \
    "$(cat "$repo/docs/specs/sdlc/P-20260728-alpha/spec.md")"
}

# AC: the preview carries the allocator's state column, so an identity the
# registry already holds is visible as such before anything is applied — the
# tell that separates a resumed run from two specs keying alike.
case_specreconcile_preview_shows_state() {
  local repo
  repo="$(specrec_repo sr_prevstate)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  printf '%s\n' 'sdlc/P-20260728-alpha' \
    | ( cd "$repo" && bash "$REPO_ROOT/skills/file/scripts/jimalloc.sh" reconcile spec --apply ) >/dev/null 2>&1
  run_specreconcile_in "$repo"
  assert_exit  "rc" 0 "$RC"
  assert_match "state column names the held identity" '	have' "$OUT"
}

# AC: an unknown option is a usage error, distinct from a guard refusal.
case_specreconcile_unknown_option_exits_2() {
  local repo; repo="$(specrec_repo sr_badopt)"
  run_specreconcile_in "$repo" --bogus
  assert_exit     "rc"     2  "$RC"
  assert_nonempty "stderr" "$ERR"
}

# AC: the specs dir can be named explicitly, so the realizer is testable and
# usable outside a repo whose config happens to point at it.
case_specreconcile_explicit_specs_dir() {
  local repo; repo="$(specrec_repo sr_explicit)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  run_specreconcile_in "$repo" docs/specs
  assert_exit  "rc" 0 "$RC"
  assert_match "previews the identity" 'sdlc/P-20260728-alpha	sdlc/001	new' "$OUT"
}

# ─── Section: Test cases — apply ─────────────────────────────────────────────

# AC: apply realizes an uncommitted pending spec — the directory takes its final
# ordinal-slug name, the frontmatter carries the real id, and the registry holds
# the record. The developer is not asked to commit first.
case_specreconcile_apply_uncommitted() {
  local repo
  repo="$(specrec_repo sr_apply_unc)"
  specrec_prov_dir "$repo" sdlc P-20260728-new-widget
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "provisional dir gone" "no" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-new-widget" ]] && echo yes || echo no)"
  assert_eq "realized dir exists" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/001-new-widget" ]] && echo yes || echo no)"
  assert_match "frontmatter carries the real id" '^id: "001"$' \
    "$(cat "$repo/docs/specs/sdlc/001-new-widget/spec.md")"
  assert_match "record published" '^spec allocate sdlc/001 new-widget 20260728 ' \
    "$(specrec_registry "$repo")"
}

# AC: apply realizes a committed pending spec too, and git records the move as a
# rename so history stays continuous across it.
case_specreconcile_apply_committed() {
  local repo
  repo="$(specrec_repo sr_apply_com)"
  specrec_prov_dir "$repo" sdlc P-20260728-new-widget
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" commit -q -m "provisional spec"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "realized dir exists" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/001-new-widget" ]] && echo yes || echo no)"
  assert_match "recorded as a rename, not add+delete" '^R' \
    "$(git -C "$repo" diff --cached --name-status -M)"
}

# AC: the frontmatter rewrite is anchored to the leading frontmatter block — a
# body line that happens to read "id:" is never touched.
case_specreconcile_apply_rewrites_only_frontmatter() {
  local repo spec
  repo="$(specrec_repo sr_apply_fm)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  spec="$repo/docs/specs/sdlc/P-20260728-alpha/spec.md"
  printf 'A body line: id: "P-20260728-alpha" stays as written.\n' >> "$spec"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  spec="$repo/docs/specs/sdlc/001-alpha/spec.md"
  assert_match "frontmatter rewritten" '^id: "001"$' "$(cat "$spec")"
  assert_match "body line untouched" 'A body line: id: "P-20260728-alpha" stays as written\.' \
    "$(cat "$spec")"
}

# AC: a local identity collision halts loudly and writes nothing further — the
# realized ordinal's directory already exists, which is registry-vs-tree drift,
# and a spec ordinal is path identity so there is no silent suffixing.
case_specreconcile_apply_halts_on_drift() {
  local repo
  repo="$(specrec_repo sr_apply_drift)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-occupied"
  printf 'occupied\n' > "$repo/docs/specs/sdlc/001-occupied/spec.md"
  # The realized ordinal will be sdlc/001, whose slug differs — so the halt has
  # to notice the ordinal is taken, not merely that the exact name exists.
  run_specreconcile_in "$repo" --apply
  assert_exit     "rc"      1 "$RC"
  assert_nonempty "names the drift" "$ERR"
  assert_eq "provisional dir untouched" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
  assert_eq "occupant untouched" "occupied" \
    "$(cat "$repo/docs/specs/sdlc/001-occupied/spec.md")"
}

# AC: the realized ordinal is revalidated before it is used as a path component,
# a glob, a git argument, or written into frontmatter. A crafted unpadded record
# halts that identity loudly and writes nothing for it — the one registry-derived
# token that used to cross the boundary ungated.
case_specreconcile_apply_gates_realized_ordinal() {
  local repo; repo="$(specrec_repo sr_ordgate)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_real_dir "$repo" sdlc 018-alpha
  specrec_commit "$repo"
  specrec_craft_registry "$repo" 'spec allocate sdlc/18 alpha 20260728 attacker'
  run_specreconcile_in "$repo" --apply
  assert_exit     "rc"             1 "$RC"
  assert_nonempty "names the halt" "$ERR"
  assert_eq "no unpadded dir" "no" \
    "$([[ -d "$repo/docs/specs/sdlc/18-alpha" ]] && echo yes || echo no)"
  assert_eq "pending dir untouched" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
  assert_eq "occupant untouched" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/018-alpha" ]] && echo yes || echo no)"
  assert_match "frontmatter still provisional" '^id: "P-20260728-alpha"$' \
    "$(cat "$repo/docs/specs/sdlc/P-20260728-alpha/spec.md")"
}

# AC: occupancy is numeric on the realize path — a differently-padded occupant
# holds the same ordinal, so realization halts naming the drift instead of
# landing a second directory on it. The tracked rename is the path that carries
# this all the way through, since its slug gate admits the twin basename.
case_specreconcile_apply_halts_on_padding_variant_occupant() {
  local repo; repo="$(specrec_repo sr_padocc)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_real_dir "$repo" sdlc 0001-legacy
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit     "rc"             1 "$RC"
  assert_nonempty "names the halt" "$ERR"
  assert_eq "no twin on the ordinal" "no" \
    "$([[ -d "$repo/docs/specs/sdlc/001-alpha" ]] && echo yes || echo no)"
  assert_eq "pending dir untouched" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
}

# AC: a bare-ordinal occupant (no slug) holds its ordinal too — realization onto
# it halts rather than treating a nameless directory as free space.
case_specreconcile_apply_halts_on_bare_ordinal_occupant() {
  local repo; repo="$(specrec_repo sr_bareocc)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_real_dir "$repo" sdlc 001
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit     "rc"             1 "$RC"
  assert_nonempty "names the halt" "$ERR"
  assert_eq "pending dir untouched" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
}

# AC: a realization whose durable moved= mapping is rejected surfaces loudly — a
# warning naming the row and a failure status, never a silent drop with exit 0.
# The record grammar is narrower than the scan's id boundary, so a group the scan
# accepts can still be unrecordable; the mapping is the audit bridge a citation
# frozen while the spec was provisional depends on, so losing one has to be
# visible.
case_specreconcile_apply_rejected_record_is_loud() {
  local repo; repo="$(specrec_repo sr_recloud)"
  specrec_prov_dir "$repo" SDLC P-20260728-alpha
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc"                     1                       "$RC"
  assert_match "names the rejected row" 'SDLC/P-20260728-alpha'  "$ERR"
  assert_eq "the rename itself still landed" "yes" \
    "$([[ -d "$repo/docs/specs/SDLC/001-alpha" ]] && echo yes || echo no)"
}

# AC: batch semantics are unchanged by the loud rejection — an identity whose
# mapping records fine still records, and the run's failure status reflects only
# the one that could not.
case_specreconcile_apply_rejected_record_keeps_batch() {
  local repo; repo="$(specrec_repo sr_recbatch)"
  specrec_prov_dir "$repo" SDLC P-20260728-alpha
  specrec_prov_dir "$repo" sdlc P-20260728-beta
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc" 1 "$RC"
  assert_match "the recordable identity is in the ledger" 'sdlc/P-20260728-beta:sdlc/001' \
    "$(cat "$repo/docs/specs/ledger.md" 2>/dev/null)"
  assert_eq "both renames landed" "yes" \
    "$([[ -d "$repo/docs/specs/SDLC/001-alpha" && -d "$repo/docs/specs/sdlc/001-beta" ]] && echo yes || echo no)"
}

# AC: a crashed apply converges on re-run — the ordinal is durable before any
# rename, so the second pass finds its own record and renames onto the same
# ordinal rather than allocating a second one.
case_specreconcile_apply_resume_converges() {
  local repo count
  repo="$(specrec_repo sr_apply_resume)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  # Simulate the crash window: the record lands, the rename never happens.
  printf '%s\n' 'sdlc/P-20260728-alpha' \
    | ( cd "$repo" && bash "$REPO_ROOT/skills/file/scripts/jimalloc.sh" reconcile spec --apply ) >/dev/null 2>&1
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "realized dir exists" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/001-alpha" ]] && echo yes || echo no)"
  count="$(specrec_registry "$repo" | grep -c '^spec allocate sdlc/')"
  assert_eq "exactly one record, no second allocation" "1" "$count"
}

# AC: a resumed realization converges against a log holding an UNPADDED record —
# it finds its own prior record rather than allocating a second ordinal, and
# lands on the canonical directory and frontmatter. Two spellings of one ordinal
# are one identity all the way from the registry to the tree.
case_specreconcile_apply_resume_unpadded_record() {
  local repo count
  repo="$(specrec_repo sr_resume_unpadded)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_commit "$repo"
  specrec_craft_registry "$repo" 'spec allocate sdlc/18 alpha 20260728 jane'
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "canonical dir" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/018-alpha" ]] && echo yes || echo no)"
  assert_eq "no unpadded twin" "no" \
    "$([[ -d "$repo/docs/specs/sdlc/18-alpha" ]] && echo yes || echo no)"
  assert_match "canonical frontmatter" '^id: "018"$' \
    "$(cat "$repo/docs/specs/sdlc/018-alpha/spec.md")"
  count="$(specrec_registry "$repo" | grep -c '^spec allocate sdlc/')"
  assert_eq "no second allocation" "1" "$count"
}

# AC: once realized, a spec is no longer pending — a further run has nothing to
# do, so realization is idempotent at the surface the developer touches.
case_specreconcile_apply_idempotent() {
  local repo
  repo="$(specrec_repo sr_apply_idem)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  run_specreconcile_in "$repo" --apply
  assert_exit "first rc" 0 "$RC"
  run_specreconcile_in "$repo" --apply
  assert_exit  "second rc" 0 "$RC"
  assert_match "nothing left to realize" 'nothing to realize' "$OUT"
}

# AC: realizing several pending specs at once renames each onto its own ordinal.
case_specreconcile_apply_batch() {
  local repo
  repo="$(specrec_repo sr_apply_batch)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_prov_dir "$repo" sdlc P-20260728-beta
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "first realized"  "yes" "$([[ -d "$repo/docs/specs/sdlc/001-alpha" ]] && echo yes || echo no)"
  assert_eq "second realized" "yes" "$([[ -d "$repo/docs/specs/sdlc/002-beta" ]] && echo yes || echo no)"
}

# AC: with the coordination point unreachable, apply realizes nothing and
# changes nothing — the pending spec stays exactly as it was.
case_specreconcile_apply_still_offline() {
  local repo
  repo="$(specrec_repo sr_apply_offline)"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-spec-realizer.git"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "dir still pending" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
  assert_eq "no registry written" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/registry || true)"
}

# ─── Section: Test cases — citation sweep ────────────────────────────────────

# specrec_commit <repo> — track everything currently in the repo.
specrec_commit() {
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" commit -q -m "fixture"
}

# specrec_claim <repo> <group> <subject> — allocate a real ordinal, so a spec
# dir the fixture already put in the tree has the registry record it would
# have had. Without this the tree holds an ordinal the registry never issued,
# which is the drift case, not the sweep case.
specrec_claim() {
  ( cd "$1" && bash "$REPO_ROOT/skills/file/scripts/jimalloc.sh" allocate spec "$2" "$3" ) \
    >/dev/null 2>&1
}

# AC: realization rewrites in-tree citations of the provisional identity by
# exact-token match in both forms it is written in — the typed id, and the
# directory path, whose tail is that same token.
case_specreconcile_sweep_rewrites_typed_and_path() {
  local repo
  repo="$(specrec_repo sr_sweep_forms)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf 'Depends on sdlc/P-20260728-alpha for identity.\n' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  printf -- '---\nid: 20260728-x\nnum: 1\norigin: docs/specs/sdlc/P-20260728-alpha/spec.md\n---\nbody\n' \
    > "$repo/docs/issues/20260728-x.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_match "typed citation rewritten" 'Depends on sdlc/002 for identity\.' \
    "$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "path citation keeps its slug" '^origin: docs/specs/sdlc/002-alpha/spec\.md$' \
    "$(cat "$repo/docs/issues/20260728-x.md")"
}

# AC: the match is whole-token — an identity that merely shares a prefix with
# the realized one is left as written. The suffixed sibling matters most: two
# specs scoped the same day with the same title differ only by that suffix.
case_specreconcile_sweep_prefix_overlap_untouched() {
  local repo body
  repo="$(specrec_repo sr_sweep_prefix)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf '%s\n%s\n%s\n' \
    'sibling sdlc/P-20260728-alpha-2 stays' \
    'suffixed sdlc/P-20260728-alphax stays' \
    'other group core/P-20260728-alpha stays' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "suffixed sibling untouched"  'sdlc/P-20260728-alpha-2 stays'  "$body"
  assert_match "prefix overlap untouched"    'sdlc/P-20260728-alphax stays'   "$body"
  assert_match "other group untouched"       'core/P-20260728-alpha stays'    "$body"
}

# AC: fenced code is verbatim material — a citation inside a fence is quoted
# text, not a live reference, and is left as written.
case_specreconcile_sweep_fenced_code_untouched() {
  local repo body
  repo="$(specrec_repo sr_sweep_fence)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf '%s\n%s\n%s\n%s\n' \
    'live sdlc/P-20260728-alpha here' \
    '```' \
    'quoted sdlc/P-20260728-alpha here' \
    '```' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "live citation rewritten" 'live sdlc/002 here'                  "$body"
  assert_match "fenced citation kept"    'quoted sdlc/P-20260728-alpha here'   "$body"
}

# AC: the sweep reports locations, never the content it read — a rewritten line
# is named by file and line number and the kind of reference, so the report
# cannot become a channel for whatever the file happened to contain.
case_specreconcile_sweep_reports_locations_only() {
  local repo
  repo="$(specrec_repo sr_sweep_loc)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf 'secret-canary sdlc/P-20260728-alpha\n' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "names file, line and kind" \
    'REWROTE	docs/specs/sdlc/001-other/spec.md	1	typed-ref' "$OUT"
  assert_eq "line content never echoed" "0" \
    "$(printf '%s\n' "$OUT" | grep -c 'secret-canary')"
}

# AC: the sweep covers the four content roots a citation can live in.
case_specreconcile_sweep_covers_four_roots() {
  local repo
  repo="$(specrec_repo sr_sweep_roots)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/brainstorms" "$repo/docs/debug" "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf 'see sdlc/P-20260728-alpha\n' > "$repo/docs/brainstorms/20260728-idea.md"
  printf 'see sdlc/P-20260728-alpha\n' > "$repo/docs/debug/20260728-trace.md"
  printf -- '---\nid: 20260728-x\nnum: 1\n---\nsee sdlc/P-20260728-alpha\n' \
    > "$repo/docs/issues/20260728-x.md"
  printf 'see sdlc/P-20260728-alpha\n' > "$repo/docs/specs/sdlc/001-other/spec.md"
  printf 'README sdlc/P-20260728-alpha untouched\n' > "$repo/README.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_match "brainstorms swept" 'see sdlc/002' "$(cat "$repo/docs/brainstorms/20260728-idea.md")"
  assert_match "debug swept"       'see sdlc/002' "$(cat "$repo/docs/debug/20260728-trace.md")"
  assert_match "issues swept"      'see sdlc/002' "$(cat "$repo/docs/issues/20260728-x.md")"
  assert_match "specs swept"       'see sdlc/002' "$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "outside the roots untouched" 'sdlc/P-20260728-alpha untouched' \
    "$(cat "$repo/README.md")"
}

# AC: the issue index is regenerated when the sweep touched an issue file, so a
# rewritten origin is reflected there rather than left stale.
case_specreconcile_sweep_regenerates_index() {
  local repo
  repo="$(specrec_repo sr_sweep_index)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  printf -- '---\nid: 20260728-x\nnum: 1\ntitle: "X"\nstatus: open\norigin: docs/specs/sdlc/P-20260728-alpha/spec.md\n---\nbody\n' \
    > "$repo/docs/issues/20260728-x.md"
  printf 'stale\n' > "$repo/docs/issues/INDEX.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "index regenerated" "0" \
    "$(grep -c '^stale$' "$repo/docs/issues/INDEX.md")"
}

# AC: with nothing to rewrite, the sweep leaves the index alone — it is
# regenerated only when an issue file actually changed.
case_specreconcile_sweep_index_untouched_when_no_issue_changed() {
  local repo
  repo="$(specrec_repo sr_sweep_noindex)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  printf -- '---\nid: 20260728-x\nnum: 1\ntitle: "X"\nstatus: open\n---\nbody\n' \
    > "$repo/docs/issues/20260728-x.md"
  printf 'untouched-canary\n' > "$repo/docs/issues/INDEX.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_match "index left as written" 'untouched-canary' \
    "$(cat "$repo/docs/issues/INDEX.md")"
}

# ─── Section: Test cases — durable realize record ────────────────────────────

# AC: every realization durably records its provisional→real mapping as a ledger
# redirect on the specs-root ledger, in the same moved= grammar the partition
# operations use, so a citation frozen while provisional stays traceable and the
# rename-emitting follow-on can lift the mapping without re-deriving it.
case_specreconcile_realized_event_recorded() {
  local repo line
  repo="$(specrec_repo sr_event)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  line="$(grep '	spec	realized	' "$repo/docs/specs/ledger.md" 2>/dev/null)"
  assert_nonempty "realize event appended" "$line"
  assert_match "carries the mapping in moved= grammar" \
    'moved=sdlc/P-20260728-alpha:sdlc/001' "$line"
}

# AC: the record covers every identity realized in the batch.
case_specreconcile_realized_event_covers_batch() {
  local repo events
  repo="$(specrec_repo sr_event_batch)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_prov_dir "$repo" platform P-20260728-beta
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  events="$(grep '	spec	realized	' "$repo/docs/specs/ledger.md" 2>/dev/null)"
  assert_match "carried in moved= grammar" 'moved='                                "$events"
  assert_match "first mapping recorded"    'sdlc/P-20260728-alpha:sdlc/001'        "$events"
  assert_match "second mapping recorded"   'platform/P-20260728-beta:platform/001' "$events"
}

# AC: an identity that halted is not recorded as moved — the durable record
# describes what happened, not what was attempted.
case_specreconcile_realized_event_omits_halted() {
  local repo events
  repo="$(specrec_repo sr_event_halt)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-occupied"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 1 "$RC"
  events="$(grep '	spec	realized	' "$repo/docs/specs/ledger.md" 2>/dev/null)"
  assert_eq "no mapping recorded for the halted identity" "" "$events"
}

# AC: the mapping is chunked at element boundaries rather than silently
# truncated, so a large batch stays wholly recorded and every chunk stays within
# the ledger's value bound.
case_specreconcile_realized_event_chunks_at_boundaries() {
  local repo events i longest
  repo="$(specrec_repo sr_event_chunk)"
  for i in 1 2 3 4 5 6 7 8; do
    specrec_prov_dir "$repo" sdlc "P-20260728-a-fairly-long-spec-slug-number-$i"
  done
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  events="$(grep '	spec	realized	' "$repo/docs/specs/ledger.md" 2>/dev/null)"
  assert_nonempty "event appended" "$events"
  for i in 1 2 3 4 5 6 7 8; do
    assert_match "identity $i recorded" \
      "sdlc/P-20260728-a-fairly-long-spec-slug-number-$i:sdlc/00$i" "$events"
  done
  longest="$(printf '%s\n' "$events" | tr ';' '\n' | grep '^moved=' \
    | awk '{ print length($0) }' | sort -rn | head -n1)"
  if [[ -n "$longest" ]] && (( longest > 256 )); then
    CURRENT_FAILED=1; echo "    [chunk] a moved= chunk is $longest bytes, over the bound"
  fi
}

# AC: the realize record feeds no vacated-id floor — a provisional never held a
# real ordinal, so it vacates nothing and next-id must be unaffected by it.
case_specreconcile_realized_event_inert_to_vacated_max() {
  local repo before after
  repo="$(specrec_repo sr_event_vacated)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs"
  before="$( cd "$repo" && bash "$REPO_ROOT/skills/ledger/scripts/jimledger.sh" \
    vacated-max docs/specs sdlc 2>/dev/null )"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  after="$( cd "$repo" && bash "$REPO_ROOT/skills/ledger/scripts/jimledger.sh" \
    vacated-max docs/specs sdlc 2>/dev/null )"
  assert_eq "vacated floor unchanged by realization" "$before" "$after"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# This file works two ways:
#   1. bash tests/specreconcile.sh        → runs only this file's cases (standalone).
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
  if [[ ! -e "$SCRIPT_specreconcile" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_specreconcile — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
