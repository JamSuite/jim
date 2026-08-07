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

# place_raw_sha <hex> — the 20 raw bytes of a hex object name, for hand-built
# tree objects.
place_raw_sha() { printf '%b' "$(printf '%s' "$1" | sed 's/../\\x&/g')"; }

# place_seed_collection <repo> <branch> <prefix> <name=content>...
#   Commit a collection onto <branch> under <prefix> by plumbing, without
#   checking the branch out — the same way a teammate's push would leave it.
place_seed_collection() {
  local repo="$1" branch="$2" prefix="$3"; shift 3
  local entries="" pair name content blob tree commit
  for pair in "$@"; do
    name="${pair%%=*}"; content="${pair#*=}"
    blob="$(printf '%s\n' "$content" | git -C "$repo" hash-object -w --stdin)"
    entries+="$(printf '100644 blob %s\t%s' "$blob" "$name")"$'\n'
  done
  tree="$(printf '%s' "$entries" | git -C "$repo" mktree)"
  local seg rest="$prefix"
  # Wrap the collection tree back up through each prefix segment, innermost
  # first, so the branch mirrors the repository's own layout.
  while [[ "$rest" == */* ]]; do
    seg="${rest##*/}"; rest="${rest%/*}"
    tree="$(printf '040000 tree %s\t%s' "$tree" "$seg" | git -C "$repo" mktree)"
  done
  tree="$(printf '040000 tree %s\t%s' "$tree" "$rest" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" -m seeded)"
  git -C "$repo" update-ref "refs/heads/$branch" "$commit"
}

# place_seed_traversal <repo> <branch> <prefix>
#   Commit a collection whose only entry escapes the collection directory:
#   `../../evil`. Git refuses to create such a tree normally, so it is written
#   with --literally — which is exactly the shape a hostile or corrupted remote
#   can serve, since fetch does not fsck objects by default.
place_seed_traversal() {
  local repo="$1" branch="$2" prefix="$3"
  local blob inner mid tree seg rest commit
  blob="$(printf 'PWNED\n' | git -C "$repo" hash-object -w --stdin)"
  inner="$( { printf '100644 evil\0'; place_raw_sha "$blob"; } \
    | git -C "$repo" hash-object -t tree -w --stdin --literally )"
  mid="$( { printf '40000 ..\0'; place_raw_sha "$inner"; } \
    | git -C "$repo" hash-object -t tree -w --stdin --literally )"
  tree="$( { printf '40000 ..\0'; place_raw_sha "$mid"; } \
    | git -C "$repo" hash-object -t tree -w --stdin --literally )"
  rest="$prefix"
  while [[ "$rest" == */* ]]; do
    seg="${rest##*/}"; rest="${rest%/*}"
    tree="$(printf '040000 tree %s\t%s' "$tree" "$seg" | git -C "$repo" mktree)"
  done
  tree="$(printf '040000 tree %s\t%s' "$tree" "$rest" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$tree" -m crafted)"
  git -C "$repo" update-ref "refs/heads/$branch" "$commit"
}

# place_dest_file <repo> <branch> <path> — the content of <path> on <branch>.
place_dest_file() { git -C "$1" cat-file -p "refs/heads/$2:$3" 2>/dev/null; }

# place_dest_paths <repo> <branch> — every path on <branch>, newline separated.
place_dest_paths() { git -C "$1" ls-tree -r --name-only "refs/heads/$2" 2>/dev/null; }

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

# ─── Section: Local engine — materialize, run, publish ───────────────────────

# AC: under a branch placement a mutation lands on the destination branch,
# committed there by plumbing, while the developer stays on their own branch
# (spec AC #3, AC #4).
case_place_write_lands_on_destination_branch() {
  local repo
  repo="$(place_repo place_land 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "landed on destination" "hello" \
    "$(place_dest_file "$repo" jim/issues docs/issues/20260101-x.md)"
}

# AC: one mutation is exactly one commit, with a conventional subject composed
# from the trusted verb enum (spec AC #4).
case_place_write_is_one_commit_with_enum_subject() {
  local repo
  repo="$(place_repo place_one_commit 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --verb file --id 20260101-x -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq   "one commit" "1" \
    "$(git -C "$repo" rev-list --count refs/heads/jim/issues)"
  assert_eq   "subject" "docs(issues): file 20260101-x" \
    "$(git -C "$repo" log -1 --format=%s refs/heads/jim/issues)"
}

# AC: a destination branch that does not exist yet is born as an orphan whose
# tree carries the collection alone — no parent, nothing else from the working
# branch (spec AC #8).
case_place_orphan_bootstrap_carries_only_the_collection() {
  local repo
  repo="$(place_repo place_orphan 'issue_placement = "jim/issues"')"
  printf 'unrelated\n' > "$repo/README.md"
  git -C "$repo" add README.md && git -C "$repo" commit -q -m base
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "collection alone" "docs/issues/20260101-x.md" \
    "$(place_dest_paths "$repo" jim/issues)"
  assert_eq "parentless" "0" \
    "$(git -C "$repo" cat-file -p refs/heads/jim/issues | grep -c '^parent ')"
}

# AC: the working tree is never disturbed — no collection appears in it, and an
# unrelated uncommitted edit survives untouched (spec AC #3).
case_place_leaves_the_working_tree_untouched() {
  local repo before after
  repo="$(place_repo place_untouched 'issue_placement = "jim/issues"')"
  printf 'unrelated\n' > "$repo/README.md"
  git -C "$repo" add README.md && git -C "$repo" commit -q -m base
  printf 'edited\n' > "$repo/README.md"
  before="$(git -C "$repo" status --porcelain)"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  after="$(git -C "$repo" status --porcelain)"
  assert_eq "status unchanged"    "$before" "$after"
  assert_eq "edit survives"       "edited"  "$(cat "$repo/README.md")"
  assert_eq "no collection in tree" "no" \
    "$([[ -e "$repo/docs/issues" ]] && echo yes || echo no)"
}

# AC: the destination branch's existing collection is what the wrapped command
# sees — a mutation composes with what is already published there (spec AC #3).
case_place_materializes_the_existing_collection() {
  local repo
  repo="$(place_repo place_materialize 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues \
    '20260101-a.md=alpha' 'INDEX.md=index'
  run_place_in "$repo" run --read --verb reindex -- \
    sh -c 'cat "$1/20260101-a.md"' _ '{}'
  assert_exit "rc"        0       "$RC"
  assert_eq   "sees seeded" "alpha" "$OUT"
}

# AC: a destination tree entry that escapes the collection directory is refused
# before any blob is written — extraction is gated per entry, so a crafted tree
# cannot turn a read verb into an arbitrary file write (security Finding 7).
case_place_refuses_uncontained_tree_entry() {
  local repo sentinel escaped
  repo="$(place_repo place_traversal 'issue_placement = "jim/issues"')"
  place_seed_traversal "$repo" jim/issues docs/issues
  sentinel="$repo/ran.txt"
  mkdir -p "$repo/tmproot"
  OUT="$(cd "$repo" && TMPDIR="$repo/tmproot" bash "$SCRIPT_place" \
    run --read --verb reindex -- sh -c 'printf ran > "$0"' "$sentinel" \
    2> "$TMP_BASE/.err")"
  RC=$?
  ERR="$(cat "$TMP_BASE/.err")"
  assert_exit  "rc"           2         "$RC"
  assert_match "names path"   'evil'    "$ERR"
  assert_eq    "command never ran" "no" \
    "$([[ -e "$sentinel" ]] && echo yes || echo no)"
  escaped="$(find "$repo" -name evil -print -quit 2>/dev/null)"
  assert_eq    "nothing escaped the collection dir" "" "$escaped"
}

# AC: a collection entry that is not a regular file — a symlink, a submodule —
# is refused rather than materialized. A symlink in the collection would be a
# write target the next mutation follows out of the temp directory.
case_place_refuses_non_regular_tree_entry() {
  local repo blob tree outer commit
  repo="$(place_repo place_symlink 'issue_placement = "jim/issues"')"
  blob="$(printf '/etc/passwd' | git -C "$repo" hash-object -w --stdin)"
  tree="$(printf '120000 blob %s\tlink.md' "$blob" | git -C "$repo" mktree)"
  tree="$(printf '040000 tree %s\tissues' "$tree" | git -C "$repo" mktree)"
  outer="$(printf '040000 tree %s\tdocs' "$tree" | git -C "$repo" mktree)"
  commit="$(git -C "$repo" commit-tree "$outer" -m seeded)"
  git -C "$repo" update-ref refs/heads/jim/issues "$commit"
  run_place_in "$repo" run --read --verb reindex -- sh -c 'true'
  assert_exit  "rc"        2        "$RC"
  assert_match "explains"  'link\.md' "$ERR"
}

# AC: a read-only run publishes nothing — the destination tip is exactly where
# it was, even when the wrapped command writes (spec AC #5: reads serve, they
# do not commit).
case_place_read_run_publishes_nothing() {
  local repo before
  repo="$(place_repo place_read_only 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=alpha'
  before="$(git -C "$repo" rev-parse refs/heads/jim/issues)"
  run_place_in "$repo" run --read --verb reindex -- \
    sh -c 'printf "sneak\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "tip unmoved" "$before" \
    "$(git -C "$repo" rev-parse refs/heads/jim/issues)"
}

# AC: the changed set carries deletions, not only additions and edits — a
# mutation that removes a file removes it at the destination (security
# Finding 8's engine-level half).
case_place_carries_deletions() {
  local repo
  repo="$(place_repo place_delete 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues \
    '20260101-a.md=alpha' '20260101-b.md=beta'
  run_place_in "$repo" run --verb close -- \
    sh -c 'rm "$1/20260101-a.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "only the survivor remains" "docs/issues/20260101-b.md" \
    "$(place_dest_paths "$repo" jim/issues)"
}

# AC: a mutation that changes nothing publishes nothing — no empty commit is
# left behind on the destination branch.
case_place_no_change_makes_no_commit() {
  local repo before
  repo="$(place_repo place_nochange 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=alpha'
  before="$(git -C "$repo" rev-parse refs/heads/jim/issues)"
  run_place_in "$repo" run --verb reindex -- sh -c 'true'
  assert_exit "rc" 0 "$RC"
  assert_eq "tip unmoved" "$before" \
    "$(git -C "$repo" rev-parse refs/heads/jim/issues)"
}

# AC: a failing wrapped command publishes nothing and its status is forwarded —
# a half-written mutation never reaches the destination.
case_place_failed_command_publishes_nothing() {
  local repo
  repo="$(place_repo place_cmd_fail 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "partial\n" > "$1/20260101-x.md"; exit 4' _ '{}'
  assert_exit "forwarded rc" 4 "$RC"
  assert_eq   "no branch created" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# AC: the collection sits at the project's configured path inside the
# destination branch, so a checkout of that branch is self-describing.
case_place_honors_configured_issues_path() {
  local repo
  repo="$(place_repo place_custom_path \
    'issue_placement = "jim/issues"' 'issues_path = "notes/findings/"')"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "at the configured path" "notes/findings/20260101-x.md" \
    "$(place_dest_paths "$repo" jim/issues)"
}

# AC: the run token reaches the wrapped command both ways — exported in the
# environment and substituted into its arguments — and the two agree, which is
# what lets a re-exec'd entry script recognize its own placement run.
case_place_exports_a_matching_run_token() {
  local repo
  repo="$(place_repo place_token_pair 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --read --verb reindex -- \
    sh -c 'test -n "$JIM_PLACE_TOKEN" && test "$JIM_PLACE_TOKEN" = "$1" && echo match' _ '{token}'
  assert_exit "rc"    0       "$RC"
  assert_eq   "token pair agrees" "match" "$OUT"
}

# AC: the temp directory the collection is materialized into does not outlive
# the run.
case_place_cleans_up_its_temp_directory() {
  local repo leftovers
  repo="$(place_repo place_cleanup 'issue_placement = "jim/issues"')"
  mkdir -p "$repo/tmproot"
  ( cd "$repo" && TMPDIR="$repo/tmproot" bash "$SCRIPT_place" run --verb file -- \
      sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}' >/dev/null 2>&1 )
  leftovers="$(find "$repo/tmproot" -mindepth 1 -print -quit 2>/dev/null)"
  assert_eq "temp dir removed" "" "$leftovers"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_place" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_place — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
