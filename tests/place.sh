#!/usr/bin/env bash
#
# tests/place.sh — Tests for skills/issue/scripts/place.sh
#
# WHAT THIS FILE TESTS
#   The issue-placement primitive: the config gate that decides whether a
#   collection mutation runs against the working tree or against a designated
#   destination branch, the run-scoped token that suppresses self-routing, and
#   the materialize / publish engine that lands a mutation on a branch nobody
#   has checked out.
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# HOW TO RUN
#   bash tests/place.sh                     # every case in this file
#   bash skills/meta-test/scripts/run.sh    # this file alongside every other tests/*.sh
#

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

SCRIPT_place="$REPO_ROOT/skills/issue/scripts/place.sh"

# ─── Section: Per-script invoker ─────────────────────────────────────────────

# run_place_in <dir> <args...>
#   Invoke place.sh with <dir> as CWD — placement resolves config from the
#   primary checkout, so every case drives it the way production does rather
#   than through a -c seam. Captures OUT / ERR / RC.
run_place_in() {
  local dir="$1"; shift
  local err_file="$TMP_BASE/.err"
  OUT="$(cd "$dir" && bash "$SCRIPT_place" "$@" 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
}

# ─── Section: Fixtures ───────────────────────────────────────────────────────

# place_repo <name> [config-lines]
#   A fresh git repo with a committer identity and an optional jimconf.toml.
place_repo() {
  local repo; repo="$(empty_dir "$1")"; shift
  git -C "$repo" init -q
  git -C "$repo" config user.name  "Test User"
  git -C "$repo" config user.email "test@example.com"
  if (( $# > 0 )); then printf '%s\n' "$@" > "$repo/jimconf.toml"; fi
  printf '%s' "$repo"
}

# ─── Section: Config gate ────────────────────────────────────────────────────

# AC: a placement value that is not a valid git branch name refuses, naming the
# value — placement never silently falls back to the working branch (spec AC
# #10). Both reads and writes refuse, so the gate sits in `mode`, ahead of any
# git interpolation.
case_place_refuses_junk_branch_name() {
  local repo
  repo="$(place_repo place_junk_branch 'issue_placement = "bad..name"')"
  run_place_in "$repo" mode
  assert_exit  "rc"          2           "$RC"
  assert_match "names value" 'bad\.\.name' "$ERR"
}

# AC: a leading-dash placement value refuses before it can reach a git command
# line as an injected option (spec AC #10).
case_place_refuses_leading_dash_branch() {
  local repo
  repo="$(place_repo place_dash_branch 'issue_placement = "--upload-pack=evil"')"
  run_place_in "$repo" mode
  assert_exit  "rc"          2                  "$RC"
  assert_match "names value" 'upload-pack=evil' "$ERR"
}

# AC: a placement naming the configured coordination branch refuses — that
# branch holds registry logs only (spec AC #9).
case_place_refuses_coordination_branch() {
  local repo
  repo="$(place_repo place_coord_branch 'issue_placement = "jim/registry"')"
  run_place_in "$repo" mode
  assert_exit  "rc"           2              "$RC"
  assert_match "names branch" 'jim/registry' "$ERR"
  assert_match "says why"     'coordination' "$ERR"
}

# AC: the coordination-branch refusal follows the configured branch, not the
# default spelling — a project that renamed its registry branch is protected at
# the name it actually uses (spec AC #9).
case_place_refuses_configured_coordination_branch() {
  local repo
  repo="$(place_repo place_coord_custom \
    'issue_placement = "team/registry"' \
    'id_coordination_branch = "team/registry"')"
  run_place_in "$repo" mode
  assert_exit  "rc"           2               "$RC"
  assert_match "names branch" 'team/registry' "$ERR"
}

# AC: a verb outside the trusted enum refuses — commit subjects are composed
# from the enum, so free text never reaches a commit message.
case_place_refuses_unknown_verb() {
  local repo
  repo="$(place_repo place_bad_verb 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --verb "bogus; rm -rf /" -- true
  assert_exit     "rc"       2      "$RC"
  assert_nonempty "explains" "$ERR"
}

# ─── Section: Passthrough (default placement) ────────────────────────────────

# AC: with the key absent, `mode` reports direct — the entry scripts behave
# exactly as today and no placement machinery engages (spec AC #2).
case_place_mode_direct_by_default() {
  local repo
  repo="$(place_repo place_mode_default)"
  run_place_in "$repo" mode
  assert_exit "rc"     0        "$RC"
  assert_eq   "direct" "direct" "$OUT"
}

# AC: the reserved sentinel `branch` is the explicit spelling of the default —
# current working branch, today's behavior (spec AC #1).
case_place_mode_direct_under_branch_sentinel() {
  local repo
  repo="$(place_repo place_mode_sentinel 'issue_placement = "branch"')"
  run_place_in "$repo" mode
  assert_exit "rc"     0        "$RC"
  assert_eq   "direct" "direct" "$OUT"
}

# AC: any other value names a destination branch, so `mode` reports route and
# the entry script re-execs itself through place.sh (spec AC #1).
case_place_mode_route_under_branch_placement() {
  local repo
  repo="$(place_repo place_mode_route 'issue_placement = "jim/issues"')"
  run_place_in "$repo" mode
  assert_exit "rc"    0       "$RC"
  assert_eq   "route" "route" "$OUT"
}

# AC: under default placement `run` is transparent — {} resolves to the
# configured issues directory, the wrapped command runs unchanged, and no git
# choreography happens at all (so it works outside a repository) (spec AC #2).
case_place_passthrough_substitutes_configured_dir() {
  local dir
  dir="$(empty_dir place_passthrough)"
  run_place_in "$dir" run --verb file -- printf '%s' '{}'
  assert_exit "rc"           0               "$RC"
  assert_eq   "configured dir" "./docs/issues" "$OUT"
}

# AC: passthrough forwards the wrapped command's exit status, so a caller sees
# the emitter's own failure rather than a placement-flavored one.
case_place_passthrough_forwards_exit_status() {
  local dir
  dir="$(empty_dir place_passthrough_rc)"
  run_place_in "$dir" run --verb file -- sh -c 'exit 7'
  assert_exit "forwarded rc" 7 "$RC"
}

# AC: a configured issues_path is honored in passthrough — placement never
# second-guesses where the collection lives when it is not centralizing.
case_place_passthrough_honors_configured_issues_path() {
  local dir
  dir="$(empty_dir place_passthrough_cfg)"
  printf 'issues_path = "notes/findings/"\n' > "$dir/jimconf.toml"
  run_place_in "$dir" run --verb file -- printf '%s' '{}'
  assert_exit "rc"            0                 "$RC"
  assert_eq   "configured dir" "notes/findings" "$OUT"
}

# ─── Section: Run-scoped token (security Finding 10) ─────────────────────────

# AC: an inherited or hand-exported JIM_PLACE_TOKEN cannot switch centralization
# off. It suppresses routing only when it equals the value place.sh passed on
# the same invocation; any other value is ignored and disclosed, so a stale
# variable can never silently land a write on the working branch at rc 0.
case_place_stale_env_token_is_ignored_and_disclosed() {
  local repo err_file
  repo="$(place_repo place_stale_token 'issue_placement = "jim/issues"')"
  err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && JIM_PLACE_TOKEN=stale-value \
    bash "$SCRIPT_place" mode --place-token other-value 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
  assert_exit  "rc"              0        "$RC"
  assert_eq    "still routes"    "route"  "$OUT"
  assert_match "discloses" 'ignor(ed|ing)' "$ERR"
}

# AC: a bare JIM_PLACE_TOKEN with no matching --place-token on the argv is the
# same non-suppressing case — the pair must agree, so an environment variable
# alone is never a boolean opt-out.
case_place_env_token_without_argv_token_still_routes() {
  local repo err_file
  repo="$(place_repo place_env_only_token 'issue_placement = "jim/issues"')"
  err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && JIM_PLACE_TOKEN=lonely \
    bash "$SCRIPT_place" mode 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
  assert_exit  "rc"           0       "$RC"
  assert_eq    "still routes" "route" "$OUT"
  assert_match "discloses" 'ignor(ed|ing)' "$ERR"
}

# AC: the matching pair — the value place.sh exported and the value it passed —
# does suppress routing, which is how the re-exec'd entry script avoids
# recursing forever.
case_place_matching_token_suppresses_routing() {
  local repo err_file
  repo="$(place_repo place_matching_token 'issue_placement = "jim/issues"')"
  err_file="$TMP_BASE/.err"
  OUT="$(cd "$repo" && JIM_PLACE_TOKEN=tok-1234 \
    bash "$SCRIPT_place" mode --place-token tok-1234 2> "$err_file")"
  RC=$?
  ERR="$(cat "$err_file")"
  assert_exit "rc"           0        "$RC"
  assert_eq   "direct"       "direct" "$OUT"
  assert_eq   "no disclosure" ""      "$(cat "$err_file")"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_place" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_place — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
