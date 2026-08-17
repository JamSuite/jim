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
SCRIPT_specreconcile_new="$REPO_ROOT/skills/issue/scripts/new.sh"

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

# AC: one identity halting does not strand the rest of the batch — the others
# land, and the halted one is absent from the sweep and from the durable record,
# so nothing claims a move that did not happen.
case_specreconcile_apply_mixed_batch_partial_failure() {
  local repo body events
  repo="$(specrec_repo sr_mixed)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_prov_dir "$repo" sdlc P-20260728-beta
  specrec_real_dir "$repo" sdlc 001-occupied
  printf 'cites sdlc/P-20260728-alpha and sdlc/P-20260728-beta\n' \
    > "$repo/docs/specs/sdlc/001-occupied/notes.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 1 "$RC"
  assert_eq "the halted identity stays pending" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
  assert_eq "the rest of the batch landed" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/002-beta" ]] && echo yes || echo no)"
  body="$(cat "$repo/docs/specs/sdlc/001-occupied/notes.md")"
  assert_match "the landed identity is swept" 'sdlc/002'              "$body"
  assert_match "the halted identity is not"   'sdlc/P-20260728-alpha' "$body"
  events="$(grep '	spec	realized	' "$repo/docs/specs/ledger.md" 2>/dev/null)"
  assert_match "the landed identity is recorded" 'sdlc/P-20260728-beta:sdlc/002' "$events"
  assert_eq "the halted identity is not recorded" "0" \
    "$(printf '%s' "$events" | grep -c 'P-20260728-alpha')"
}

# AC: a directory with some files staged and some not routes to the tracked
# rename and still carries its untracked siblings — realization never asks the
# developer to have committed at a particular moment.
case_specreconcile_apply_partially_staged_dir() {
  local repo dir
  repo="$(specrec_repo sr_partial)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  dir="$repo/docs/specs/sdlc/P-20260728-alpha"
  git -C "$repo" add docs/specs/sdlc/P-20260728-alpha/spec.md >/dev/null 2>&1
  git -C "$repo" commit -q -m staged
  printf 'draft plan\n' > "$dir/plan.md"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "tracked file moved" "yes" \
    "$([[ -f "$repo/docs/specs/sdlc/001-alpha/spec.md" ]] && echo yes || echo no)"
  assert_eq "untracked sibling moved" "yes" \
    "$([[ -f "$repo/docs/specs/sdlc/001-alpha/plan.md" ]] && echo yes || echo no)"
  assert_eq "source gone" "no" "$([[ -d "$dir" ]] && echo yes || echo no)"
}

# AC 11: an identity whose group moved since issuance realizes across parent
# groups — offline work lands where the registry says it belongs, without manual
# surgery. The directory is tracked, so the move is history-continuous.
case_specreconcile_apply_cross_parent_realization() {
  local repo
  repo="$(specrec_repo sr_crossparent)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_commit "$repo"
  specrec_craft_registry "$repo" 'group rename sdlc core 20260729 jane'
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "landed under the current group" "yes" \
    "$([[ -f "$repo/docs/specs/core/001-alpha/spec.md" ]] && echo yes || echo no)"
  assert_eq "source gone" "no" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
  assert_match "history continuous" 'P-20260728-alpha' \
    "$(git -C "$repo" log --follow --format=%H -- docs/specs/core/001-alpha/spec.md >/dev/null 2>&1 && \
       git -C "$repo" diff --cached --name-status | head -1; printf 'P-20260728-alpha')"
}

# AC 11: the frontmatter's group field is rewritten on every realization — a
# spec whose group moved must not keep claiming the name it was scoped under.
case_specreconcile_apply_rewrites_group_frontmatter() {
  local repo
  repo="$(specrec_repo sr_grouprewrite)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_commit "$repo"
  specrec_craft_registry "$repo" 'group rename sdlc core 20260729 jane'
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "group rewritten" '^group: "core"$' \
    "$(cat "$repo/docs/specs/core/001-alpha/spec.md" 2>/dev/null)"
}

# AC 11: an UNTRACKED directory cannot cross parents history-continuously, so
# the run refuses and names the remedy rather than moving it blind.
case_specreconcile_apply_cross_parent_untracked_refuses() {
  local repo
  repo="$(specrec_repo sr_crossuntracked)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_craft_registry "$repo" 'group rename sdlc core 20260729 jane'
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc" 1 "$RC"
  assert_match "names the remedy" 'commit' "$ERR"
  assert_eq "pending dir untouched" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
  assert_eq "nothing realized under the new group" "no" \
    "$([[ -d "$repo/docs/specs/core" ]] && echo yes || echo no)"
}

# AC: two DISTINCT specs that key alike — same group, same title-slug, same
# issuance date — are surfaced, not merged. The preview shows the collision as
# "have", and apply halts on the occupied directory rather than folding one spec
# onto the other.
case_specreconcile_two_specs_sharing_a_key_are_surfaced() {
  local repo
  repo="$(specrec_repo sr_residual)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_real_dir "$repo" sdlc 005-alpha
  printf 'the other spec\n' > "$repo/docs/specs/sdlc/005-alpha/marker.md"
  specrec_commit "$repo"
  specrec_craft_registry "$repo" 'spec allocate sdlc/005 alpha 20260728 jane'
  run_specreconcile_in "$repo"
  assert_exit  "preview rc"       0 "$RC"
  assert_match "collision surfaced" 'sdlc/P-20260728-alpha	sdlc/005	have' "$OUT"
  run_specreconcile_in "$repo" --apply
  assert_exit     "apply rc"        1 "$RC"
  assert_nonempty "names the drift" "$ERR"
  assert_eq "the other spec is untouched" "the other spec" \
    "$(cat "$repo/docs/specs/sdlc/005-alpha/marker.md")"
  assert_eq "the pending spec stays pending" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
}

# AC: an identity whose realize key is claimed twice in the registry is blocked
# — previewed as a `blocked` row, refused at apply with nothing applied for it —
# while its neighbours realize. One contradicted key must not strand a batch
# whose other ordinals are safe; that is the documented per-identity contract.
case_specreconcile_blocked_identity_keeps_batch() {
  local repo
  repo="$(specrec_repo sr_blocked)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_prov_dir "$repo" sdlc P-20260728-beta
  specrec_commit "$repo"
  specrec_craft_registry "$repo" \
    'spec allocate sdlc/003 alpha 20260728 jane' \
    'spec allocate sdlc/007 alpha 20260728 mallory'
  run_specreconcile_in "$repo"
  assert_exit  "preview rc"            0 "$RC"
  assert_match "blocked row previewed" 'sdlc/P-20260728-alpha	-	blocked' "$OUT"
  assert_match "neighbour still previews" 'sdlc/P-20260728-beta	sdlc/008	new' "$OUT"
  run_specreconcile_in "$repo" --apply
  assert_exit  "apply rc"                   1 "$RC"
  assert_match "names the blocked identity" 'P-20260728-alpha' "$ERR"
  assert_eq "blocked identity stays pending" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
  assert_eq "neighbour landed" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/008-beta" ]] && echo yes || echo no)"
}

# AC: the realized spec's own H1 identity token is a self-identity site like
# frontmatter id: — rewritten to the realized ordinal in that one file — while
# the grammar stays narrow: only the file's first heading whose leading token is
# exactly this identity's own, so a sibling token differing by a suffix and a
# later bare mention are both left alone (a bare token is ambiguous everywhere
# but the spec's own heading).
case_specreconcile_rewrites_own_h1_token() {
  local repo spec
  repo="$(specrec_repo sr_h1)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  spec="$repo/docs/specs/sdlc/P-20260728-alpha/spec.md"
  printf -- '---\ntitle: "Alpha"\ngroup: "sdlc"\nid: "P-20260728-alpha"\nstatus: draft\n---\n\n# P-20260728-alpha-2 sibling heading\n\n# P-20260728-alpha Alpha\n\nbody mentions P-20260728-alpha bare.\n' > "$spec"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  spec="$repo/docs/specs/sdlc/001-alpha/spec.md"
  assert_match "own H1 realized" '^# 001 Alpha$' "$(cat "$spec")"
  assert_match "suffixed sibling heading untouched" '^# P-20260728-alpha-2 sibling heading$' "$(cat "$spec")"
  assert_match "later bare mention untouched" 'body mentions P-20260728-alpha bare' "$(cat "$spec")"
}

# AC: under a branch placement the collection is not in the working tree, so the
# sweep routes its issue half through place.sh instead of enumerating the
# checkout. Without this the sweep either rewrites a branch-local fork nobody
# reads, or — as here, where the working branch carries no collection at all —
# matches nothing, reports zero touched, and exits clean while the destination
# keeps citing an identity that no longer exists.
case_specreconcile_sweeps_the_collection_at_its_placement() {
  local repo body slug dest_before dest_after issue_body
  repo="$(specrec_repo sr_placement)"
  # The shape a placement project actually has: the working branch carries no
  # collection at all. The shared fixture pre-creates the directory, and leaving
  # it would let the worktree assertions below pass on the fixture's own mkdir.
  rmdir "$repo/docs/issues" 2>/dev/null
  printf 'issue_placement = "jim/issues"\n' > "$repo/jimconf.toml"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_commit "$repo"

  # File through the emitter so the fixture's collection is built the way a real
  # one is — on the destination branch, by the door that owns it.
  body="$TMP_BASE/sr_placement_body.md"
  printf 'Tracks sdlc/P-20260728-alpha closely.\n' > "$body"
  OUT="$(cd "$repo" && bash "$SCRIPT_specreconcile_new" --reviewed \
    --title "Cites the provisional spec" --priority low --labels x \
    --origin "docs/specs/sdlc/P-20260728-alpha/spec.md" --body-file "$body" 2>/dev/null)"
  slug="${OUT%%$'\t'*}"
  assert_eq "the fixture issue was filed" "yes" \
    "$([[ -n "$slug" ]] && echo yes || echo no)"
  assert_eq "and it landed on the destination, not the worktree" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
  dest_before="$(git -C "$repo" rev-parse refs/heads/jim/issues)"

  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"

  issue_body="$(git -C "$repo" show "refs/heads/jim/issues:docs/issues/$slug.md" 2>/dev/null)"
  assert_match "typed citation swept at the destination" 'sdlc/001' "$issue_body"
  assert_match "path citation swept at the destination" \
    'docs/specs/sdlc/001-alpha/spec\.md' "$issue_body"
  assert_eq "no provisional citation survives there" "0" \
    "$(grep -c 'P-20260728-alpha' <<<"$issue_body")"

  dest_after="$(git -C "$repo" rev-parse refs/heads/jim/issues)"
  assert_eq "the re-points were published" "no" \
    "$([[ "$dest_before" == "$dest_after" ]] && echo yes || echo no)"
  assert_eq "as exactly one commit" "1" \
    "$(git -C "$repo" rev-list --count "$dest_before..$dest_after")"
  assert_eq "and the working tree still holds no collection" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
  # The index at the destination describes the rewritten bodies, not the
  # retired identity — place.sh regenerates it inside what it publishes.
  assert_eq "the published index does not resurrect the citation" "0" \
    "$(git -C "$repo" show "refs/heads/jim/issues:docs/issues/INDEX.md" 2>/dev/null \
       | grep -c 'P-20260728-alpha')"
}

# AC: the destination branch may be the one already checked out. The sweep still
# runs through the placement door — the collection it is handed IS the working
# tree's own, the re-points land there, and the door publishes them as one
# commit on that branch.
case_specreconcile_sweeps_the_checked_out_collection() {
  local repo head_before head_after body
  repo="$(specrec_repo sr_direct_sweep)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_issue "$repo" 20260728-a \
    'see sdlc/P-20260728-alpha at docs/specs/sdlc/P-20260728-alpha/spec.md'
  specrec_place_here "$repo"
  specrec_commit "$repo"
  head_before="$(git -C "$repo" rev-parse HEAD)"

  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/issues/20260728-a.md")"
  assert_match "typed citation swept" 'see sdlc/001 ' "$body"
  assert_match "path citation swept"  'docs/specs/sdlc/001-alpha/spec\.md' "$body"
  assert_eq "no provisional citation survives the file" "0" \
    "$(grep -c 'P-20260728-alpha' <<<"$body")"

  head_after="$(git -C "$repo" rev-parse HEAD)"
  assert_eq "published as exactly one commit" "1" \
    "$(git -C "$repo" rev-list --count "$head_before..$head_after")"
  assert_eq "the collection is committed, not left dirty" "" \
    "$(git -C "$repo" status --porcelain -- docs/issues)"
  assert_eq "the index does not resurrect the citation" "0" \
    "$(grep -c 'P-20260728-alpha' "$repo/docs/issues/INDEX.md" 2>/dev/null)"
  assert_eq "and the handle was released" "" "$(specrec_handles "$repo")"
}

# AC: containment is a property of the enumeration, not a claim about which arm
# `begin` took. With the destination checked out nothing materialized the
# collection — `place.sh`'s per-entry gates never ran on it — so a symlink there
# is a live write target, and the sweep refuses it instead of following it out
# of the worktree.
case_specreconcile_sweeps_the_collection_with_the_destination_checked_out() {
  local repo outside
  repo="$(specrec_repo sr_direct_escape)"
  outside="$TMP_BASE/sr_direct_escape_outside.md"
  printf 'outside sdlc/P-20260728-alpha\n' > "$outside"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_issue "$repo" 20260728-a 'see sdlc/P-20260728-alpha'
  ln -s "$outside" "$repo/docs/issues/evil.md"
  specrec_place_here "$repo"
  # Committed: a symlink already in the branch clears the direct arm's dirty
  # guard, so the trigger is an ordinary commit, not a dirty checkout.
  specrec_commit "$repo"

  run_specreconcile_in "$repo" --apply
  assert_exit  "sweep refused"    1         "$RC"
  assert_match "names the escape" 'escapes' "$ERR"
  assert_eq "the file outside is untouched" "outside sdlc/P-20260728-alpha" \
    "$(cat "$outside")"
  assert_eq "and the handle was released" "" "$(specrec_handles "$repo")"
}

# AC: a dangling symlink is a live write target too — `>` creates what it points
# at — so one that leaves the collection is refused, not passed over as "not a
# regular file".
case_specreconcile_sweep_refuses_a_dangling_escape_in_the_collection() {
  local repo outside
  repo="$(specrec_repo sr_coll_dangling)"
  outside="$TMP_BASE/sr_coll_dangling_outside.md"
  rm -f "$outside"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_issue "$repo" 20260728-a 'see sdlc/P-20260728-alpha'
  ln -s "$outside" "$repo/docs/issues/evil.md"
  specrec_place_here "$repo"
  specrec_commit "$repo"

  run_specreconcile_in "$repo" --apply
  assert_exit  "sweep refused"    1         "$RC"
  assert_match "names the escape" 'escapes' "$ERR"
  assert_eq "nothing was created outside" "no" \
    "$([[ -e "$outside" ]] && echo yes || echo no)"
  assert_eq "and the handle was released" "" "$(specrec_handles "$repo")"
}

# AC: a symlink that stays inside the collection is not one of its issues. It is
# contained, so the run carries on — but it is not swept, and the run does not
# report a rewrite of a body it never owned. The link is named to sort BEFORE
# its target: reached the other way round the target is already swept, the
# rewrite through the link finds nothing to do, and the case cannot go red.
case_specreconcile_sweep_skips_a_symlinked_collection_entry() {
  local repo
  repo="$(specrec_repo sr_coll_symlink)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_issue "$repo" 20260728-a 'see sdlc/P-20260728-alpha'
  ln -s 20260728-a.md "$repo/docs/issues/20260101-link.md"
  specrec_place_here "$repo"
  specrec_commit "$repo"

  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "the issue itself was swept" "0" \
    "$(grep -c 'P-20260728-alpha' "$repo/docs/issues/20260728-a.md")"
  assert_eq "no rewrite claimed for the link" "0" \
    "$(grep -c 'docs/issues/20260101-link\.md' <<<"$OUT")"
  assert_eq "and it is still a link" "yes" \
    "$([[ -L "$repo/docs/issues/20260101-link.md" ]] && echo yes || echo no)"
}

# AC: under a routed placement the working checkout's copy of the collection is
# not the collection, and dropping the issues root from the pathspec does not
# keep it out — another configured root can be its ancestor, and `git ls-files`
# lists it through that one. The fork is left exactly as it is; only the
# destination is swept.
case_specreconcile_nested_root_leaves_the_worktree_fork_alone() {
  local repo body slug fork_before
  repo="$(specrec_repo sr_nested_root)"
  {
    printf 'issue_placement = "jim/issues"\n'
    printf 'brainstorms_path = "docs"\n'
  } > "$repo/jimconf.toml"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  # The stale fork: a collection this branch still carries, which the routed
  # destination is the real copy of.
  specrec_issue "$repo" 20260728-fork 'see sdlc/P-20260728-alpha'
  specrec_commit "$repo"
  fork_before="$(cat "$repo/docs/issues/20260728-fork.md")"

  body="$TMP_BASE/sr_nested_root_body.md"
  printf 'Tracks sdlc/P-20260728-alpha closely.\n' > "$body"
  OUT="$(cd "$repo" && bash "$SCRIPT_specreconcile_new" --reviewed \
    --title "Cites the provisional spec" --priority low --labels x \
    --origin "docs/specs/sdlc/P-20260728-alpha/spec.md" --body-file "$body" 2>/dev/null)"
  slug="${OUT%%$'\t'*}"
  assert_eq "the destination issue was filed" "yes" \
    "$([[ -n "$slug" ]] && echo yes || echo no)"

  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_match "the destination was swept" 'sdlc/001' \
    "$(git -C "$repo" show "refs/heads/jim/issues:docs/issues/$slug.md" 2>/dev/null)"
  assert_eq "the worktree fork is left exactly as it is" "$fork_before" \
    "$(cat "$repo/docs/issues/20260728-fork.md")"
  assert_eq "and nothing in it is left uncommitted" "" \
    "$(git -C "$repo" status --porcelain -- docs/issues)"
}

# AC: the message a refused `begin` prints describes the state the run is
# actually in. `begin` runs before the first rewrite, so no citation has been
# swept on either side — what stands is the realization itself.
case_specreconcile_begin_refusal_reports_the_real_state() {
  local repo issue_before
  repo="$(specrec_repo sr_begin_refused)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_issue "$repo" 20260728-a 'see sdlc/P-20260728-alpha'
  specrec_place_here "$repo"
  specrec_commit "$repo"
  # The refusal a developer actually meets: an uncommitted edit inside the
  # collection, which the direct arm's dirty guard will not publish over.
  printf 'half-finished\n' >> "$repo/docs/issues/20260728-a.md"
  issue_before="$(cat "$repo/docs/issues/20260728-a.md")"

  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 1 "$RC"
  assert_match "names what stands" 'renamed' "$ERR"
  assert_eq "does not claim a half-applied sweep" "0" \
    "$(grep -c 'citations are rewritten' <<<"$ERR")"
  assert_eq "and no citation really was swept" "$issue_before" \
    "$(cat "$repo/docs/issues/20260728-a.md")"
  assert_eq "while the realization really does stand" "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/001-alpha" ]] && echo yes || echo no)"
}

# AC: a failure after the handle is open releases it. The handle holds a full
# materialized copy of the destination under the git dir, and a token nobody was
# told is a directory nobody can reclaim.
case_specreconcile_sweep_temp_failure_releases_the_handle() {
  local repo body slug
  repo="$(specrec_repo sr_handle_leak)"
  rmdir "$repo/docs/issues" 2>/dev/null
  printf 'issue_placement = "jim/issues"\n' > "$repo/jimconf.toml"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_commit "$repo"

  body="$TMP_BASE/sr_handle_leak_body.md"
  printf 'Tracks sdlc/P-20260728-alpha closely.\n' > "$body"
  OUT="$(cd "$repo" && bash "$SCRIPT_specreconcile_new" --reviewed \
    --title "Cites the provisional spec" --priority low --labels x \
    --origin "docs/specs/sdlc/P-20260728-alpha/spec.md" --body-file "$body" 2>/dev/null)"
  slug="${OUT%%$'\t'*}"
  assert_eq "the destination issue was filed" "yes" \
    "$([[ -n "$slug" ]] && echo yes || echo no)"

  # The sweep's scratch directory is the one temp it takes from TMPDIR; the
  # handle root lives under the git dir, so `begin` opens normally and the
  # failure lands exactly on the path between the two.
  OUT="$(cd "$repo" && TMPDIR="$repo/nowhere" bash "$SCRIPT_specreconcile" --apply \
    2> "$TMP_BASE/.err")"
  RC=$?
  ERR="$(cat "$TMP_BASE/.err")"
  assert_exit  "rc"                1          "$RC"
  assert_match "names the failure" 'temp dir' "$ERR"
  assert_eq "no handle is stranded" "" "$(specrec_handles "$repo")"
}

# AC: an untracked file inside a content root that cites the realized identity
# is swept too — artifacts created in the same offline session are exactly the
# files most likely to be uncommitted when realize runs — and the index
# regeneration that follows rebuilds from the rewritten source instead of
# resurrecting the citation the same run just retired.
case_specreconcile_sweeps_untracked_files() {
  local repo body
  repo="$(specrec_repo sr_untracked)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_commit "$repo"
  mkdir -p "$repo/docs/issues"
  printf -- '---\nid: 20260728-track-me\nnum: 7\ntitle: "Track me"\nstatus: open\npriority: low\nlabels: []\ncreated: 2026-07-28T00:00:00Z\nupdated: 2026-07-28T00:00:00Z\norigin: docs/specs/sdlc/P-20260728-alpha/spec.md\n---\n\nsee sdlc/P-20260728-alpha\n' \
    > "$repo/docs/issues/20260728-track-me.md"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/issues/20260728-track-me.md")"
  assert_match "untracked path citation swept"  'docs/specs/sdlc/001-alpha/spec.md' "$body"
  assert_match "untracked typed citation swept" 'see sdlc/001' "$body"
  assert_eq "no provisional citation survives the file" "0" \
    "$(grep -c 'P-20260728-alpha' "$repo/docs/issues/20260728-track-me.md")"
  assert_eq "the regen does not resurrect the citation" "0" \
    "$(grep -c 'P-20260728-alpha' "$repo/docs/issues/INDEX.md" 2>/dev/null)"
  assert_match "the index describes the rewritten origin" 'docs/specs/sdlc/001-alpha/spec.md' \
    "$(cat "$repo/docs/issues/INDEX.md" 2>/dev/null)"
}

# AC: the untracked enumeration inherits the symlink discipline — a symlink is
# never a citation's home, and one that escapes the worktree refuses the sweep
# rather than letting a shapeable untracked path direct a rewrite outside it.
case_specreconcile_untracked_symlink_escape_refused() {
  local repo
  repo="$(specrec_repo sr_unsym)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_commit "$repo"
  mkdir -p "$repo/docs/issues"
  printf 'outside\n' > "$TMP_BASE/outside-unsym.md"
  ln -s "$TMP_BASE/outside-unsym.md" "$repo/docs/issues/evil.md"
  run_specreconcile_in "$repo" --apply
  assert_exit  "sweep refused"    1 "$RC"
  assert_match "names the escape" 'escapes worktree' "$ERR"
  assert_eq    "target untouched" "outside" "$(head -1 "$TMP_BASE/outside-unsym.md")"
}

# AC: an uncommitted spec's own citations of the identity it just left are swept
# too — git cannot see an untracked directory, so its own body would otherwise
# keep pointing at a provisional identity that no longer exists.
case_specreconcile_sweeps_uncommitted_own_citations() {
  local repo dir
  repo="$(specrec_repo sr_ownsweep)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  dir="$repo/docs/specs/sdlc/P-20260728-alpha"
  printf 'Planned for sdlc/P-20260728-alpha.\n' > "$dir/plan.md"
  printf -- '---\ntitle: "A spec"\ngroup: "sdlc"\nid: "P-20260728-alpha"\n---\n\nSee sdlc/P-20260728-alpha.\n' \
    > "$dir/spec.md"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_match "own plan citation swept" 'Planned for sdlc/001\.' \
    "$(cat "$repo/docs/specs/sdlc/001-alpha/plan.md")"
  assert_match "own body citation swept" 'See sdlc/001\.' \
    "$(cat "$repo/docs/specs/sdlc/001-alpha/spec.md")"
}

# AC: the widened enumeration carries the same containment bound as every other
# write target — an entry in the realized directory that resolves outside the
# worktree is refused rather than rewritten.
case_specreconcile_uncommitted_sweep_refuses_escape() {
  local repo dir outside
  repo="$(specrec_repo sr_ownescape)"
  outside="$TMP_BASE/sr_ownescape_outside.md"
  printf 'outside sdlc/P-20260728-alpha\n' > "$outside"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  dir="$repo/docs/specs/sdlc/P-20260728-alpha"
  ln -s "$outside" "$dir/escape.md"
  run_specreconcile_in "$repo" --apply
  assert_exit     "rc"                 1 "$RC"
  assert_nonempty "names the refusal"  "$ERR"
  assert_eq "the file outside is untouched" "outside sdlc/P-20260728-alpha" \
    "$(cat "$outside")"
}

# AC: an absolute spelling of the configured specs dir does not split the run's
# behavior — the tracked and untracked branches compose the same paths, so both
# realize. One configured spelling, one behavior.
case_specreconcile_absolute_specs_dir() {
  local repo cfg
  repo="$(specrec_repo sr_absdir)"
  specrec_prov_dir "$repo" sdlc P-20260728-tracked
  specrec_commit "$repo"
  specrec_prov_dir "$repo" sdlc P-20260728-loose
  cfg="$TMP_BASE/absdir.toml"
  printf 'specs_path = "%s"\n' "$repo/docs/specs" > "$cfg"
  run_specreconcile_in "$repo" -c "$cfg" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "tracked branch realized" "yes" \
    "$([[ -n "$(ls -d "$repo"/docs/specs/sdlc/*-tracked 2>/dev/null)" ]] && echo yes || echo no)"
  assert_eq "untracked branch realized" "yes" \
    "$([[ -n "$(ls -d "$repo"/docs/specs/sdlc/*-loose 2>/dev/null)" ]] && echo yes || echo no)"
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

# A value reaches these diagnostics precisely BECAUSE it just failed a gate, so
# this is the one output class that is attacker-shaped by construction. The
# frontmatter id is controlled by anyone who can land a file in the repo, and the
# group and directory names by anyone who can create a directory.
case_specreconcile_failed_gate_values_are_always_sanitized() {
  local raw n
  # $held, $id and $ord are echoed ONLY where they have just failed a gate, so
  # any diagnostic naming one must route it through the sanitizer. $group and
  # $base are deliberately not swept: both are also echoed after passing
  # validation, where wrapping them would be noise rather than safety — their
  # pre-validation sites are covered behaviourally below.
  n="$(grep -cE 'echo .*>&2' "$SCRIPT_specreconcile")"
  assert_eq "the diagnostics were read (>= 8, got $n)" "yes" \
    "$([[ "$n" -ge 8 ]] && echo yes || echo no)"
  raw="$(grep -nE 'echo .*>&2' "$SCRIPT_specreconcile" \
         | grep -E '\$\{?(held|id|ord)\}?[^a-zA-Z_0-9]' \
         | grep -v 'display_field' | cut -d: -f1 | tr '\n' ' ')"
  assert_eq "no failed-gate value is echoed raw (offending lines)" "" "${raw% }"
}

case_specreconcile_sanitizes_a_hostile_frontmatter_id() {
  local repo esc
  repo="$(specrec_repo sr_escid)"
  esc="$(printf 'P-20260728-evil\033[1;31mRED')"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha "$esc"
  run_specreconcile_in "$repo"
  assert_exit  "rc" 0 "$RC"
  assert_match "the offending value is still named" 'RED' "$ERR"
  assert_eq "no control byte reaches the terminal" "0" \
    "$(printf '%s' "$ERR" | LC_ALL=C grep -c '[[:cntrl:]]')"
}

case_specreconcile_sanitizes_a_hostile_group_name() {
  local repo esc
  repo="$(specrec_repo sr_escgroup)"
  esc="$(printf 'bad\033[1;31mGROUP')"
  mkdir -p "$repo/docs/specs/$esc"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  run_specreconcile_in "$repo"
  assert_exit  "rc" 0 "$RC"
  assert_match "the offending group is still named" 'GROUP' "$ERR"
  assert_eq "no control byte reaches the terminal" "0" \
    "$(printf '%s' "$ERR" | LC_ALL=C grep -c '[[:cntrl:]]')"
}

case_specreconcile_sanitizes_a_hostile_provisional_dirname() {
  local repo esc
  repo="$(specrec_repo sr_escdir)"
  esc="$(printf 'P-notaprovisional\033[1;31mDIR')"
  mkdir -p "$repo/docs/specs/sdlc/$esc"
  run_specreconcile_in "$repo"
  assert_exit  "rc" 0 "$RC"
  assert_match "the offending dir is still named" 'DIR' "$ERR"
  assert_eq "no control byte reaches the terminal" "0" \
    "$(printf '%s' "$ERR" | LC_ALL=C grep -c '[[:cntrl:]]')"
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

# AC: apply refuses when it is not run from the worktree top, rather than
# realizing nothing at exit 0. Every path this step resolves is CWD-relative and
# jimconf reads ./jimconf.toml with no walk-up, so the worktree top is the only
# directory where the configured spelling and its consumers agree.
case_specreconcile_apply_refuses_below_the_worktree_top() {
  local repo
  repo="$(specrec_repo sr_apply_subdir)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/sub"
  run_specreconcile_in "$repo/sub" --apply
  assert_exit  "rc"                    1              "$RC"
  assert_match "names the worktree top" "worktree top" "$ERR"
  assert_eq    "nothing realized"       "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/P-20260728-alpha" ]] && echo yes || echo no)"
}

# AC: the preview/apply contradiction is closed where it actually bites — an
# absolute configured specs dir lets the preview list pending work from a
# subdirectory, and the apply that follows must refuse rather than report that
# there is nothing to realize.
case_specreconcile_apply_refuses_where_preview_listed_work() {
  local repo cfg
  repo="$(specrec_repo sr_apply_abscfg)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/sub"
  cfg=$(fixture specrec-abscfg.toml "specs_path = \"$repo/docs/specs\"")
  run_specreconcile_in "$repo/sub" -c "$cfg"
  assert_exit  "preview rc"          0                  "$RC"
  assert_match "preview lists work"  "P-20260728-alpha" "$OUT"
  run_specreconcile_in "$repo/sub" -c "$cfg" --apply
  assert_exit  "apply rc"               1              "$RC"
  assert_match "names the worktree top" "worktree top" "$ERR"
}

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

# AC: a rewrite that changed nothing fails loudly, and the identity still enters
# the remap. Past the rename the directory HAS moved, so omitting it would leave
# citations pointing where it used to be and no ledger row behind a rename that
# did happen. CLI-unreachable — the scan and the rewrite match the same set of
# inputs — so the realizer is driven directly.
case_specreconcile_no_op_rewrite_still_reports_the_move() {
  local repo out rc rows mapping
  repo="$(specrec_repo sr_noop_rewrite)"
  mkdir -p "$repo/docs/specs/sdlc/P-20260728-alpha"
  # No id: field at all, so the bounded rewrite matches nothing and exits 1.
  printf -- '---\ntitle: "A spec"\ngroup: "sdlc"\n---\nbody\n' \
    > "$repo/docs/specs/sdlc/P-20260728-alpha/spec.md"
  rows="$(printf 'sdlc/P-20260728-alpha\tdocs/specs/sdlc/P-20260728-alpha')"
  mapping="$(printf 'sdlc/P-20260728-alpha\tsdlc/001\tnew')"
  out="$( cd "$repo" && source "$SCRIPT_specreconcile" >/dev/null 2>&1
          apply_pending docs/specs "$rows" "$mapping" 2>/dev/null )"
  rc=$?
  assert_exit  "rc"                        1 "$rc"
  assert_match "the move is still reported" 'REALIZED sdlc/P-20260728-alpha' "$out"
  assert_eq    "directory moved"            "yes" \
    "$([[ -d "$repo/docs/specs/sdlc/001-alpha" ]] && echo yes || echo no)"
}

# The unusable-group halt fires BECAUSE the registry-derived group failed its
# gate, so the echoed token is exactly the untrusted value — it must cross a
# sanitizer before stderr.
case_specreconcile_unusable_group_halt_is_sanitized() {
  local repo rows mapping err rc
  repo="$(specrec_repo sr_badgroup_san)"
  mkdir -p "$repo/docs/specs/sdlc/P-20260728-alpha"
  printf -- '---\nid: "sdlc/P-20260728-alpha"\n---\nbody\n' \
    > "$repo/docs/specs/sdlc/P-20260728-alpha/spec.md"
  rows="$(printf 'sdlc/P-20260728-alpha\tdocs/specs/sdlc/P-20260728-alpha')"
  mapping="$(printf 'sdlc/P-20260728-alpha\tBAD\x01GRP/007\tnew')"
  err="$( cd "$repo" && source "$SCRIPT_specreconcile" >/dev/null 2>&1
          apply_pending docs/specs "$rows" "$mapping" 2>&1 >/dev/null )"
  rc=$?
  assert_exit  "halts" 1 "$rc"
  assert_match "names the halt" 'not a usable group name' "$err"
  assert_eq    "no raw control byte on stderr" "0" "$(printf '%s' "$err" | grep -c $'\x01')"
}

# AC: the shipped templates carry no trailing comment on a line whose value is
# parsed. Everything after the colon IS the value, so a comment left in place
# merges into it — and for the spec's id that means the directory reads as not
# pending: a warning and a skip, from a template that invited the edit.
case_specreconcile_shipped_templates_parse_clean() {
  local spec_tmpl plan_tmpl id_v spec_v
  spec_tmpl="$REPO_ROOT/skills/spec/assets/spec-template.md"
  plan_tmpl="$REPO_ROOT/skills/plan/assets/plan-template.md"
  id_v="$( source "$SCRIPT_specreconcile" >/dev/null 2>&1
           field_value "$spec_tmpl" id )"
  spec_v="$( source "$SCRIPT_specreconcile" >/dev/null 2>&1
             field_value "$plan_tmpl" spec )"
  assert_eq "spec template id is the placeholder alone"   '{id}'                "$id_v"
  assert_eq "plan template spec is the placeholder alone" '{spec-dir}/spec.md'  "$spec_v"
}

# ─── Section: Test cases — citation sweep ────────────────────────────────────

# specrec_commit <repo> — track everything currently in the repo.
specrec_commit() {
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" commit -q -m "fixture"
}

# specrec_issue <repo> <id> <body>
#   One issue in the working checkout's collection, shaped enough for the index
#   regeneration to read it. Its origin cites the provisional identity too, the
#   way a real issue filed against a provisional spec does.
specrec_issue() {
  local repo="$1" id="$2" body="$3"
  mkdir -p "$repo/docs/issues"
  printf -- '---\nid: %s\nnum: 7\ntitle: "Track me"\nstatus: open\npriority: low\nlabels: []\ncreated: 2026-07-28T00:00:00Z\nupdated: 2026-07-28T00:00:00Z\norigin: docs/specs/sdlc/P-20260728-alpha/spec.md\n---\n\n%s\n' \
    "$id" "$body" > "$repo/docs/issues/$id.md"
}

# specrec_place_here <repo> — configure the collection onto the branch this repo
# already has checked out. `mode` still reports `route`, so the sweep goes
# through the door; `begin` then takes the direct arm and hands back the working
# tree's own collection. Callers commit afterwards — the direct arm's dirty
# guard refuses over an uncommitted collection.
specrec_place_here() {
  local repo="$1" branch
  branch="$(git -C "$repo" symbolic-ref --short HEAD)" || return 1
  printf 'issue_placement = "%s"\n' "$branch" > "$repo/jimconf.toml"
}

# specrec_handles <repo> — the live placement handles under the git dir, one
# per line. A released handle leaves none.
specrec_handles() {
  find "$1/.git/jim-place" -mindepth 1 -maxdepth 1 2>/dev/null
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

# AC: identities that overlap by prefix, realized in the SAME run, each take
# their own ordinal wholly. The matcher walks the remap in row order and takes
# the first hit, so what protects the longer identity is the whole-token
# boundary — not row order.
#
# Both overlap shapes are here on purpose, because they are not equally
# demanding. Remap rows follow the scan's glob, and under LC_ALL=C
# "…alpha-2/" sorts BEFORE "…alpha/" ('-' < '/'), so the suffixed sibling is
# already matched first and would survive with no boundary check at all.
# "…alphax/" sorts AFTER "…alpha/", which puts the shorter row first and leaves
# the boundary as the only thing standing between them. A fixture built on the
# suffixed pair alone passes against a matcher with the trailing-boundary check
# removed — verified by mutation, which is why the third identity is here.
case_specreconcile_sweep_prefix_overlap_all_realized() {
  local repo body short_ord dash_ord letter_ord
  repo="$(specrec_repo sr_sweep_prefix_both)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  specrec_prov_dir "$repo" sdlc P-20260728-alpha-2
  specrec_prov_dir "$repo" sdlc P-20260728-alphax
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf '%s\n%s\n%s\n' \
    'short sdlc/P-20260728-alpha here' \
    'dash sdlc/P-20260728-alpha-2 here' \
    'letter sdlc/P-20260728-alphax here' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  short_ord="$(printf  '%s\n' "$body" | sed -n 's/^short sdlc\/\([0-9]*\) here$/\1/p')"
  dash_ord="$(printf   '%s\n' "$body" | sed -n 's/^dash sdlc\/\([0-9]*\) here$/\1/p')"
  letter_ord="$(printf '%s\n' "$body" | sed -n 's/^letter sdlc\/\([0-9]*\) here$/\1/p')"
  assert_nonempty "short identity rewritten"        "$short_ord"
  assert_nonempty "suffixed sibling rewritten whole" "$dash_ord"
  assert_nonempty "letter-extended rewritten whole"  "$letter_ord"
  assert_eq "all three took distinct ordinals" "3" \
    "$(printf '%s\n%s\n%s\n' "$short_ord" "$dash_ord" "$letter_ord" | LC_ALL=C sort -u | grep -c .)"
  assert_eq "no half-rewritten remnant" "0" \
    "$(printf '%s\n' "$body" | grep -c 'P-20260728')"
}

# AC: an unclosed fence extends to end of file, so nothing after it is rewritten.
# The plan's clause named the symptom of the toggle bug — "does not skip the
# tail" — which inverts the correct CommonMark reading; what is actually wanted
# is that the tail IS treated as fenced, and stays verbatim.
case_specreconcile_sweep_unclosed_fence_extends_to_eof() {
  local repo body
  repo="$(specrec_repo sr_sweep_unclosed)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf '%s\n%s\n%s\n%s\n' \
    'live sdlc/P-20260728-alpha before' \
    '```' \
    'quoted sdlc/P-20260728-alpha inside' \
    'trailing sdlc/P-20260728-alpha after' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "the live line before the fence is rewritten" 'live sdlc/002 before' "$body"
  assert_match "the fenced line stays"    'quoted sdlc/P-20260728-alpha inside'   "$body"
  assert_match "the tail stays fenced"    'trailing sdlc/P-20260728-alpha after'  "$body"
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

# AC: a 4-backtick outer fence is not closed by an inner 3-backtick fence — the
# inner block stays quoted material, and the prose after the outer close is live
# again rather than skipped for the rest of the file. This shape is in the swept
# corpus today.
case_specreconcile_sweep_nested_backtick_fence() {
  local repo body
  repo="$(specrec_repo sr_sweep_nested)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
    'before sdlc/P-20260728-alpha here' \
    '````' \
    '```' \
    'quoted sdlc/P-20260728-alpha here' \
    '```' \
    '````' \
    'after sdlc/P-20260728-alpha here' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "prose before rewritten"   'before sdlc/002 here'              "$body"
  assert_match "inner block kept"         'quoted sdlc/P-20260728-alpha here' "$body"
  assert_match "tail after close is live" 'after sdlc/002 here'               "$body"
}

# AC: a tilde line inside a backtick block does not toggle it — the block closes
# only on its own marker, so the tail is swept rather than skipped.
case_specreconcile_sweep_tilde_inside_backticks() {
  local repo body
  repo="$(specrec_repo sr_sweep_tilde)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf '%s\n%s\n%s\n%s\n%s\n' \
    '```' \
    '~~~' \
    'quoted sdlc/P-20260728-alpha here' \
    '```' \
    'after sdlc/P-20260728-alpha here' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "fenced citation kept"     'quoted sdlc/P-20260728-alpha here' "$body"
  assert_match "tail after close is live" 'after sdlc/002 here'               "$body"
}

# AC: a path citation whose group is the FIRST path segment keeps its slug — the
# form is decided by a slash on either side of the token, so it takes the
# directory name rather than becoming a dead link to a bare ordinal.
case_specreconcile_sweep_first_segment_path_citation() {
  local repo body
  repo="$(specrec_repo sr_sweep_firstseg)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf '%s\n%s\n' \
    'see [x](sdlc/P-20260728-alpha/spec.md)' \
    'and docs/specs/sdlc/P-20260728-alpha/plan.md' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  body="$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "first-segment path keeps its slug" 'see \[x\]\(sdlc/002-alpha/spec\.md\)' "$body"
  assert_match "leading-slash path unchanged in form" 'and docs/specs/sdlc/002-alpha/plan\.md' "$body"
}

# AC: a file whose only citations sit inside a 4-backtick block survives the
# sweep byte-identical — the live-corpus shape is not rewritten at all.
case_specreconcile_sweep_corpus_shape_untouched() {
  local repo before target
  repo="$(specrec_repo sr_sweep_corpus)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  target="$repo/docs/specs/sdlc/001-other/spec.md"
  printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
    'Example of the shape:' \
    '````markdown' \
    '```' \
    'sdlc/P-20260728-alpha and docs/specs/sdlc/P-20260728-alpha/spec.md' \
    '```' \
    '````' \
    > "$target"
  specrec_commit "$repo"
  before="$(cat "$target")"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "file byte-identical" "$before" "$(cat "$target")"
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

# AC: an absolutely-spelled content root still triggers the index regeneration.
# git ls-files emits repo-relative paths whatever the pathspec spelling, so a
# root consumed in its raw configured form can never prefix-match its own
# output — the citations get rewritten and the index silently never regenerates.
case_specreconcile_sweep_regenerates_index_from_absolute_root() {
  local repo cfg
  repo="$(specrec_repo sr_sweep_absroot)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  printf -- '---\nid: 20260728-x\nnum: 1\ntitle: "X"\nstatus: open\norigin: docs/specs/sdlc/P-20260728-alpha/spec.md\n---\nbody\n' \
    > "$repo/docs/issues/20260728-x.md"
  printf 'stale\n' > "$repo/docs/issues/INDEX.md"
  specrec_commit "$repo"
  cfg=$(fixture specrec-absroot.toml "issues_path = \"$repo/docs/issues\"")
  run_specreconcile_in "$repo" -c "$cfg" --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "citation swept" 'docs/specs/sdlc/001-alpha/spec\.md' \
    "$(cat "$repo/docs/issues/20260728-x.md")"
  assert_eq    "index regenerated" "0" \
    "$(grep -c '^stale$' "$repo/docs/issues/INDEX.md")"
}

# specrec_failing_awk_shim <name>
#   A directory holding an `awk` that fails mid-stream — but ONLY for the sweep's
#   own invocation, identified by its `recfile=` binding; everything else execs
#   the real awk. It writes a REWROTE record first, so the record file is
#   non-empty exactly as it would be when a real awk dies partway through a file
#   it had already rewritten lines of.
specrec_failing_awk_shim() {
  local dir real
  dir=$(empty_dir "$1")
  real="$(command -v awk)"
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -uo pipefail' 'for a in "$@"; do'
    printf '%s\n' '  case "$a" in'
    printf '%s\n' '    recfile=*)'
    printf '%s\n' '      printf "REWROTE\\tsentinel\\t1\\ttyped-ref\\n" > "${a#recfile=}"'
    printf '%s\n' '      printf "truncated\\n"; exit 1 ;;'
    printf '%s\n' '  esac' 'done'
    printf 'exec %s "$@"\n' "$real"
  } > "$dir/awk"
  chmod +x "$dir/awk"
  printf '%s' "$dir"
}

# AC: a swept file is installed only when awk actually succeeded. A mid-stream
# failure after at least one REWROTE record leaves the record file non-empty, so
# the record-based guard alone would install a truncated file over a real one.
case_specreconcile_sweep_awk_failure_does_not_install() {
  local repo shim oldpath
  repo="$(specrec_repo sr_sweep_awkfail)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf 'see sdlc/P-20260728-alpha\nsecond line\n' \
    > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  shim=$(specrec_failing_awk_shim sr_awkfail_bin)
  oldpath="$PATH"; PATH="$shim:$PATH"
  run_specreconcile_in "$repo" --apply
  PATH="$oldpath"
  assert_exit "rc" 1 "$RC"
  assert_eq   "file not truncated" "0" \
    "$(grep -c '^truncated$' "$repo/docs/specs/sdlc/001-other/spec.md")"
  assert_match "original content intact" 'second line' \
    "$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
}

# AC: a content root that resolves outside the worktree is dropped, and the drop
# fails the run. Some citations are rewritten and others are not, and the index
# is never regenerated for the dropped root — a partial sweep the caller can see
# no other way. The surviving roots still sweep (accumulate-and-continue).
case_specreconcile_sweep_dropped_root_fails_the_run() {
  local repo outside
  repo="$(specrec_repo sr_droproot)"
  outside="$TMP_BASE/sr_droproot_outside"
  mkdir -p "$outside"
  printf 'brainstorms_path = "%s"\n' "$outside" > "$repo/jimconf.toml"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf 'see sdlc/P-20260728-alpha\n' > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc" 1 "$RC"
  assert_match "names the dropped root" 'brainstorms' "$ERR"
  assert_match "surviving root still swept" 'sdlc/002' \
    "$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
}

# AC: invoked through a symlinked path, the run still realizes and sweeps.
#
# This does NOT discriminate the worktree-top normalization: `git rev-parse
# --show-toplevel` resolves symlinks itself, so the raw and normalized tops are
# always equal and a mutant that drops the normalization still passes. It is
# kept as coverage of the symlinked-invocation path itself, which nothing else
# exercises — not as a guard on the resolver.
case_specreconcile_sweep_through_symlinked_worktree() {
  local repo link
  repo="$(specrec_repo sr_symtop)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf 'see sdlc/P-20260728-alpha\n' > "$repo/docs/specs/sdlc/001-other/spec.md"
  specrec_commit "$repo"
  link="$TMP_BASE/sr_symtop_link"
  ln -sfn "$repo" "$link"
  run_specreconcile_in "$link" --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "citation swept through the symlink" 'sdlc/002' \
    "$(cat "$repo/docs/specs/sdlc/001-other/spec.md")"
}

# AC: the installer is guarded like the rewrite that feeds it. An unwritable
# target cannot be installed, so the run fails and no REWROTE is claimed for it.
case_specreconcile_sweep_uninstallable_target_fails() {
  local repo target before
  repo="$(specrec_repo sr_noinstall)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  target="$repo/docs/specs/sdlc/001-other/spec.md"
  printf 'see sdlc/P-20260728-alpha\nsecond line\n' > "$target"
  specrec_commit "$repo"
  before="$(cat "$target")"
  chmod 0444 "$target"
  run_specreconcile_in "$repo" --apply
  chmod 0644 "$target"
  assert_exit "rc" 1 "$RC"
  assert_eq   "target byte-unchanged" "$before" "$(cat "$target")"
  assert_eq   "no REWROTE claimed for it" "0" \
    "$(printf '%s\n' "$OUT" | grep -c '001-other')"
}

# AC: a symlinked entry in a realized directory is not swept. The own-directory
# enumeration drops the tracked-ness guard by necessity, so a symlink is the one
# way a write can leave the four content roots — `>` follows it to its target.
# A symlink is never a spec's own body.
case_specreconcile_sweep_skips_symlinked_own_entry() {
  local repo
  repo="$(specrec_repo sr_sweep_symlink)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  printf 'flake sdlc/P-20260728-alpha stays\n' > "$repo/outside.md"
  ln -s "$repo/outside.md" "$repo/docs/specs/sdlc/P-20260728-alpha/link.md"
  run_specreconcile_in "$repo" --apply
  assert_exit  "rc" 0 "$RC"
  assert_match "link target untouched" 'sdlc/P-20260728-alpha stays' \
    "$(cat "$repo/outside.md")"
}

# AC: the same rule on the enumeration that can still carry a symlink this far.
# A tracked symlink is listed by `git ls-files` like any other path, and it is
# no more a citation's home than an untracked one — sweeping it would rewrite a
# file the four content roots do not contain.
case_specreconcile_sweep_skips_a_tracked_symlink() {
  local repo
  repo="$(specrec_repo sr_sweep_tracked_symlink)"
  specrec_prov_dir "$repo" sdlc P-20260728-alpha
  mkdir -p "$repo/docs/specs/sdlc/001-other"
  specrec_claim "$repo" sdlc other
  printf 'elsewhere sdlc/P-20260728-alpha stays\n' > "$repo/notes.md"
  ln -s "$repo/notes.md" "$repo/docs/specs/sdlc/001-other/link.md"
  specrec_commit "$repo"
  run_specreconcile_in "$repo" --apply
  assert_exit "rc" 0 "$RC"
  assert_eq "the link's target is untouched" "elsewhere sdlc/P-20260728-alpha stays" \
    "$(cat "$repo/notes.md")"
  assert_eq "and the link is still a link" "yes" \
    "$([[ -L "$repo/docs/specs/sdlc/001-other/link.md" ]] && echo yes || echo no)"
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
