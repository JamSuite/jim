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
