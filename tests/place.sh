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
#   Every step checks its own status: a fixture that failed silently would leave
#   the cases built on it comparing two empty strings and passing.
place_seed_collection() {
  local repo="$1" branch="$2" prefix="$3"; shift 3
  local entries="" pair name content blob tree commit
  for pair in "$@"; do
    name="${pair%%=*}"; content="${pair#*=}"
    blob="$(printf '%s\n' "$content" | git -C "$repo" hash-object -w --stdin)" || return 1
    entries+="$(printf '100644 blob %s\t%s' "$blob" "$name")"$'\n'
  done
  tree="$(printf '%s' "$entries" | git -C "$repo" mktree)" || return 1
  local seg rest="$prefix"
  # Wrap the collection tree back up through each prefix segment, innermost
  # first, so the branch mirrors the repository's own layout.
  while [[ "$rest" == */* ]]; do
    seg="${rest##*/}"; rest="${rest%/*}"
    tree="$(printf '040000 tree %s\t%s' "$tree" "$seg" | git -C "$repo" mktree)" || return 1
  done
  tree="$(printf '040000 tree %s\t%s' "$tree" "$rest" | git -C "$repo" mktree)" || return 1
  commit="$(git -C "$repo" commit-tree "$tree" -m seeded)" || return 1
  git -C "$repo" update-ref "refs/heads/$branch" "$commit" || return 1
  return 0
}

# place_seed_traversal <repo> <branch> <prefix>
#   Commit a collection whose only entry escapes the collection directory:
#   `../../evil`. Git refuses to create such a tree normally, so it is written
#   with --literally — which is exactly the shape a hostile or corrupted remote
#   can serve, since fetch does not fsck objects by default.
place_seed_traversal() {
  local repo="$1" branch="$2" prefix="$3"
  local blob inner mid tree seg rest commit
  blob="$(printf 'PWNED\n' | git -C "$repo" hash-object -w --stdin)" || return 1
  inner="$( { printf '100644 evil\0'; place_raw_sha "$blob"; } \
    | git -C "$repo" hash-object -t tree -w --stdin --literally )" || return 1
  mid="$( { printf '40000 ..\0'; place_raw_sha "$inner"; } \
    | git -C "$repo" hash-object -t tree -w --stdin --literally )" || return 1
  tree="$( { printf '40000 ..\0'; place_raw_sha "$mid"; } \
    | git -C "$repo" hash-object -t tree -w --stdin --literally )" || return 1
  rest="$prefix"
  while [[ "$rest" == */* ]]; do
    seg="${rest##*/}"; rest="${rest%/*}"
    tree="$(printf '040000 tree %s\t%s' "$tree" "$seg" | git -C "$repo" mktree)" || return 1
  done
  tree="$(printf '040000 tree %s\t%s' "$tree" "$rest" | git -C "$repo" mktree)" || return 1
  commit="$(git -C "$repo" commit-tree "$tree" -m crafted)" || return 1
  git -C "$repo" update-ref "refs/heads/$branch" "$commit" || return 1
  return 0
}

# place_bookmark <repo> <branch> — the tip this clone last recorded as seen at
# the destination. Reading it is how a case pins what the bookmark means; no
# assertion touched it before, so neither of its guarding conditions was held
# in place by anything.
place_bookmark() {
  git -C "$1" rev-parse --verify --quiet "refs/jim/issue-placement/$2" 2>/dev/null
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

# AC: an issues_path that is not a safe repo-relative path refuses before it can
# be mirrored onto a destination branch — it becomes a tree prefix and a
# pathspec, so it clears the boundary first (spec AC #10).
case_place_refuses_an_unsafe_issues_path() {
  local repo
  repo="$(place_repo place_unsafe_prefix \
    'issue_placement = "jim/issues"' 'issues_path = "../outside"')"
  run_place_in "$repo" run --verb file -- sh -c 'true'
  assert_exit     "rc"       2      "$RC"
  assert_nonempty "explains" "$ERR"
  assert_eq "no branch created" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# AC: a dot segment in issues_path refuses naming the setting, rather than
# failing later on a message about entry names or about building a tree. `./`
# alone resolves to the repository root, which would make the whole checkout the
# collection (spec AC #10).
case_place_refuses_a_dot_segment_issues_path() {
  local repo
  repo="$(place_repo place_dot_prefix \
    'issue_placement = "jim/issues"' 'issues_path = "./"')"
  run_place_in "$repo" run --verb file -- sh -c 'true'
  assert_exit  "rc"                        2                   "$RC"
  assert_match "names the setting"         'issues directory'  "$ERR"
  assert_match "and what is wrong with it" "'\\.' or '\\.\\.' segment" "$ERR"
  assert_eq "no branch created" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# AC: and a repeated `./` is stripped rather than half-stripped — one leading
# pair removed leaves a dot segment that reads fine here and fails opaquely when
# git is asked to build a tree from it.
case_place_normalizes_a_repeated_dot_slash_issues_path() {
  local repo
  repo="$(place_repo place_dotdot_prefix \
    'issue_placement = "jim/issues"' 'issues_path = "././docs/issues"')"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_match "lands at the normalized prefix" 'docs/issues/20260101-a\.md' \
    "$(place_dest_paths "$repo" jim/issues)"
}

# AC: place_valid_branch and alloc_valid_branch are knowingly duplicated — the
# two scripts share no library and neither imports the other — so the agreement
# is asserted here rather than assumed. The SYNC comments on both name this
# fixture; without it a drift in either is silent.
case_place_valid_branch_agrees_with_the_allocator_copy() {
  local mine theirs
  mine="$(awk 'index($0,"place_valid_branch()")==1 {f=1} f {print} f && /^}$/ {exit}' \
    "$REPO_ROOT/skills/issue/scripts/place.sh" | sed 's/place_/X_/g')"
  theirs="$(awk 'index($0,"alloc_valid_branch()")==1 {f=1} f {print} f && /^}$/ {exit}' \
    "$REPO_ROOT/skills/file/scripts/jimalloc.sh" | sed 's/alloc_/X_/g')"
  assert_nonempty "place copy found" "$mine"
  assert_nonempty "alloc copy found" "$theirs"
  assert_eq "the two copies agree modulo their prefix" "$mine" "$theirs"
}

# AC: an --id that is not a real issue id refuses at both call sites. The verb
# half of "no free text reaches a commit message" is what the enum covers; the
# id half is this.
case_place_refuses_a_malformed_id() {
  local repo
  repo="$(place_repo place_bad_id 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --verb close --id 'not; an id' -- sh -c 'true'
  assert_exit     "run rc"   2      "$RC"
  assert_nonempty "explains" "$ERR"
  run_place_in "$repo" commit none --verb close --id 'not; an id'
  assert_exit     "commit rc" 2     "$RC"
  assert_nonempty "explains"  "$ERR"
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

# ─── Section: Placeholder substitution ───────────────────────────────────────

# AC: only an argument that is exactly `{}` or `{token}` is a placeholder.
# Braces are ordinary text in a developer-tool issue title — `interface{}`, an
# empty JSON literal — and a substring rewrite would put this run's temp path
# into the title, and from there into the slug, which is the durable id
# (spec AC #3).
case_place_substitutes_whole_arguments_only() {
  local repo
  repo="$(place_repo place_subst_whole 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --read --verb reindex -- \
    printf '%s|%s' 'Fix the {} placeholder' 'a{token}b'
  assert_exit "rc" 0 "$RC"
  assert_eq   "both left verbatim" 'Fix the {} placeholder|a{token}b' "$OUT"
}

# AC: the same rule holds on the passthrough path, where the substitution would
# be the configured issues directory rather than a temp one.
case_place_passthrough_substitutes_whole_arguments_only() {
  local dir
  dir="$(empty_dir place_subst_passthrough)"
  run_place_in "$dir" run --verb file -- printf '%s' 'map[string]interface{}'
  assert_exit "rc" 0 "$RC"
  assert_eq   "left verbatim" 'map[string]interface{}' "$OUT"
}

# AC: an argument that is exactly `{}` is a placeholder only where the caller
# that built the invocation put one — after `--dir`/`--place-token`, or as the
# trailing operand it appended. Whole-argument matching alone is not enough:
# the emitter re-execs carrying its own caller's entire argv, so a title of
# exactly `{}` occupies a marker's shape while being user text. Substituting it
# puts this run's temp path into the title and from there into the slug — the
# durable id an append-only registry has already recorded, which no later run
# can reclaim (spec AC #3).
case_place_user_text_matching_a_marker_is_not_substituted() {
  local repo body out rc log err
  repo="$(place_repo place_subst_user_marker 'issue_placement = "jim/issues"')"
  body="$(fixture place_subst_marker_body.md 'body')"
  err="$TMP_BASE/.subst-marker.err"
  out="$(cd "$repo" && bash "$REPO_ROOT/skills/issue/scripts/new.sh" \
           --title '{}' --priority medium --labels x \
           --origin conversation --body-file "$body" 2>"$err")"
  rc=$?
  log="$(git -C "$repo" cat-file -p refs/heads/jim/registry:issues.log 2>/dev/null)"
  # A slug built from the run's temp root is unmistakable, and permanent.
  if printf '%s\n' "$out$log" | grep -q 'tmp'; then
    CURRENT_FAILED=1
    echo "    [the run's temp path reached the durable id] [$out] [$log]"
  fi
  # The title arrived verbatim, so slug derivation refuses it — the right
  # outcome for a degenerate title, and it burns no ordinal.
  assert_exit  "refuses rather than filing"   1      "$rc"
  assert_match "the emitter saw the literal"  "'\\{\\}'" "$(cat "$err")"
  assert_eq    "nothing was allocated"        ""     "$log"
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
  assert_eq "collection alone" "docs/issues/20260101-x.md
docs/issues/INDEX.md" "$(place_dest_paths "$repo" jim/issues)"
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
  # Asserted alongside the absences, so a run that wrote nothing anywhere cannot
  # pass this by leaving the working tree undisturbed.
  assert_eq "the mutation landed at the destination" "hello" \
    "$(place_dest_file "$repo" jim/issues docs/issues/20260101-x.md)"
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

# AC: a tmp file stranded in the collection is not published. Atomic writers
# stage through `.<name>.tmp.XXXXXX` beside the file they replace, and a crash
# mid-write leaves one behind; this is the one enumerator whose output becomes
# tree entries, so admitting it would put a half-written file on the shared
# branch — where it is re-materialized every run, sits unchanged in both
# snapshots, and appears in no index (the group's atomic-index-write rule).
case_place_does_not_publish_a_stranded_tmp() {
  local repo paths
  repo="$(place_repo place_tmp_ns 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "real\n" > "$1/20260101-a.md"; printf "half\n" > "$1/.INDEX.md.tmp.abc123"' \
    _ '{}'
  assert_exit "rc" 0 "$RC"
  paths="$(place_dest_paths "$repo" jim/issues)"
  assert_match "the issue landed"     'docs/issues/20260101-a\.md' "$paths"
  assert_eq "and the tmp did not" "no" \
    "$(grep -q 'tmp\.abc123' <<< "$paths" && echo yes || echo no)"
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

# AC: an entry whose name begins with '-' is refused on its own account. It is
# plain, relpath-valid and resolves inside the collection, so every other gate
# admits it — and it goes on to be a bare argument to the tools that read the
# collection back.
case_place_refuses_a_leading_dash_tree_entry() {
  local repo
  repo="$(place_repo place_dash_entry 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '-rf.md=payload'
  assert_exit "fixture seeded" 0 "$?"
  run_place_in "$repo" run --read --verb reindex -- sh -c 'true'
  assert_exit  "rc"                 2         "$RC"
  assert_match "names the entry"    '\-rf\.md' "$ERR"
  assert_match "and the dash rule"  "begin with '-'" "$ERR"
}

# AC: the collection the *wrapped command* leaves behind clears the same
# regular-files bar the destination's own content does. Materialization gates
# what comes in; this gates what goes out, and it is the only thing standing
# between a symlink the command created and a published tree entry.
case_place_refuses_a_symlink_the_command_created() {
  local repo
  repo="$(place_repo place_out_symlink 'issue_placement = "jim/issues"')"
  # A *live* symlink: it satisfies -f, so only the -L half of the guard refuses
  # it. A dangling one would be caught either way and would not pin this.
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "real\n" > "$1/20260101-a.md"; ln -s 20260101-a.md "$1/20260101-b.md"' \
    _ '{}'
  assert_eq    "refuses"          "no" "$([[ "$RC" == 0 ]] && echo yes || echo no)"
  assert_match "names the entry"  '20260101-b\.md' "$ERR"
  assert_eq "and nothing was published" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# AC: the containment gate refuses through the two-phase door too, and says so
# with the same status. `begin`'s contract is "<token><TAB><dir>" on stdout, so a
# refusal reported as success hands the caller an empty dir — an agent following
# it edits relative paths in the project checkout instead of the collection
# (security Finding 7; the same gate `run` clears at rc 2).
case_place_begin_refuses_an_uncontained_tree_entry() {
  local repo escaped
  repo="$(place_repo place_begin_traversal 'issue_placement = "jim/issues"')"
  place_seed_traversal "$repo" jim/issues docs/issues
  assert_exit "fixture seeded" 0 "$?"
  run_place_in "$repo" begin
  assert_exit  "refuses as a validation error" 2      "$RC"
  assert_eq    "hands back no handle"          ""     "$OUT"
  assert_match "names the offending entry"     'evil' "$ERR"
  escaped="$(find "$repo" -name evil -print -quit 2>/dev/null)"
  assert_eq    "nothing escaped the collection dir" "" "$escaped"
}

# place_issue_file <slug> <status> — an issue file's content, the shape index.sh
# parses.
place_issue_file() {
  printf -- '---\nid: %s\ntitle: "Alpha"\nstatus: %s\nnum: 1\npriority: medium\ncreated: 2026-01-01T00:00:00Z\n---\n' \
    "$1" "$2"
}

# AC: what a read is served carries an index describing it. Content reaches the
# destination branch by routes the emitter never sees — a hand commit, a merge,
# a bulk import — and asserting the materialized index was fresh defeated the
# reader's own staleness gate, hiding such an issue until some later write
# happened to regenerate (the group blueprint's staleness-gated-reads).
case_place_read_serves_a_current_index() {
  local repo
  repo="$(place_repo place_stale_index 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues \
    "20260101-a.md=$(place_issue_file 20260101-a open)" \
    'INDEX.md=# Issues Index'
  run_place_in "$repo" run --read --verb reindex -- \
    sh -c 'cat "$1/INDEX.md"' _ '{}'
  assert_exit  "rc" 0 "$RC"
  assert_match "the issue is in the served index" '20260101-a' "$OUT"
}

# AC: and a write publishes that correction, so the next reader is not made to
# repeat it.
case_place_write_publishes_a_corrected_index() {
  local repo
  repo="$(place_repo place_stale_index_write 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues \
    "20260101-a.md=$(place_issue_file 20260101-a open)" \
    'INDEX.md=# Issues Index'
  run_place_in "$repo" run --verb file -- \
    sh -c 'true' _ '{}'
  assert_exit  "rc" 0 "$RC"
  assert_match "the published index knows the issue" '20260101-a' \
    "$(place_dest_file "$repo" jim/issues docs/issues/INDEX.md)"
}

# AC: a read-only run publishes nothing — the destination tip is exactly where
# it was, even when the wrapped command writes (spec AC #5: reads serve, they
# do not commit).
case_place_read_run_publishes_nothing() {
  local repo before
  repo="$(place_repo place_read_only 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=alpha'
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  run_place_in "$repo" run --read --verb reindex -- \
    sh -c 'printf "sneak\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "tip unmoved" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
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
  local paths; paths="$(place_dest_paths "$repo" jim/issues)"
  assert_match "survivor remains" 'docs/issues/20260101-b\.md' "$paths"
  assert_eq "deleted file is gone" "no" \
    "$(printf '%s\n' "$paths" | grep -q '20260101-a\.md' && echo yes || echo no)"
}

# AC: a mutation that changes nothing publishes nothing — no empty commit is
# left behind on the destination branch.
case_place_no_change_makes_no_commit() {
  local repo before
  repo="$(place_repo place_nochange 'issue_placement = "jim/issues"')"
  # Seeded through a real write, so the published index is already current —
  # otherwise the first run would legitimately have an index to add.
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "alpha\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  run_place_in "$repo" run --verb reindex -- sh -c 'true'
  assert_exit "rc" 0 "$RC"
  assert_eq "tip unmoved" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
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
  assert_eq "at the configured path" "notes/findings/20260101-x.md
notes/findings/INDEX.md" "$(place_dest_paths "$repo" jim/issues)"
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
# the run. The landing assertion is what keeps this honest — an absent temp dir
# is also what a script that never ran leaves behind.
case_place_cleans_up_its_temp_directory() {
  local repo leftovers rc
  repo="$(place_repo place_cleanup 'issue_placement = "jim/issues"')"
  mkdir -p "$repo/tmproot"
  ( cd "$repo" && TMPDIR="$repo/tmproot" bash "$SCRIPT_place" run --verb file -- \
      sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}' >/dev/null 2>&1 )
  rc=$?
  assert_exit "rc" 0 "$rc"
  assert_eq "the mutation landed" "hello" \
    "$(place_dest_file "$repo" jim/issues docs/issues/20260101-x.md)"
  leftovers="$(find "$repo/tmproot" -mindepth 1 -print -quit 2>/dev/null)"
  assert_eq "temp dir removed" "" "$leftovers"
}

# ─── Section: Remote sync ────────────────────────────────────────────────────

# place_bare <name> — an empty bare repository standing in for the shared remote.
place_bare() {
  local d; d="$(empty_dir "$1")"
  git init -q --bare "$d/r.git"
  printf '%s' "$d/r.git"
}

# place_clone <bare> <name> [config-lines] — a working clone with an identity.
place_clone() {
  local bare="$1" name="$2"; shift 2
  local dir; dir="$(empty_dir "$name")"
  git clone -q "$bare" "$dir"
  git -C "$dir" config user.name  "$name"
  git -C "$dir" config user.email "$name@example.com"
  if (( $# > 0 )); then printf '%s\n' "$@" > "$dir/jimconf.toml"; fi
  printf '%s' "$dir"
}

# AC: a write propagates to the remote, so a teammate's clone can see the
# discovery without waiting for a branch to merge (spec AC #7).
case_place_publishes_to_the_remote() {
  local bare clone
  bare="$(place_bare place_pub_bare)"
  clone="$(place_clone "$bare" place_pub_clone 'issue_placement = "jim/issues"')"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "on the remote" "hello" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-x.md 2>/dev/null)"
}

# AC: an unreachable remote does not block a write. The local commit stands,
# propagation is deferred, and the degradation is disclosed — no mutation is
# ever silently dropped (spec AC #7).
case_place_defers_push_when_remote_unreachable() {
  local repo
  repo="$(place_repo place_defer 'issue_placement = "jim/issues"')"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit  "rc"        0          "$RC"
  assert_match "discloses" 'defer'    "$ERR"
  assert_eq "local commit stands" "hello" \
    "$(place_dest_file "$repo" jim/issues docs/issues/20260101-x.md)"
}

# AC: when the remote is unreachable a read serves the last-seen state and says
# so, rather than failing or pretending to be current (spec AC #6).
case_place_read_degrades_when_remote_unreachable() {
  local repo
  repo="$(place_repo place_read_degrade 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=alpha'
  git -C "$repo" remote add origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$repo" run --read --verb reindex -- \
    sh -c 'cat "$1/20260101-a.md"' _ '{}'
  assert_exit  "rc"          0            "$RC"
  assert_eq    "still serves" "alpha"     "$OUT"
  assert_match "discloses"    'last-seen' "$ERR"
}

# AC: a write rejected because the remote moved is reapplied to the winner's
# state and retried, not lost — two teammates filing at once both end up
# published (spec AC #7).
case_place_retries_after_the_remote_advances() {
  local bare mine theirs teammate
  bare="$(place_bare place_race_bare)"
  mine="$(place_clone "$bare" place_race_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_race_them 'issue_placement = "jim/issues"')"
  # The teammate publishes from inside the wrapped command, so `mine` has
  # already materialized and snapshotted against the older tip by the time it
  # tries to publish — a genuine lost race, not a sequential write. It lives in
  # a file because a literal {} in the outer argv would be substituted away.
  teammate="$TMP_BASE/place-race-teammate.sh"
  cat > "$teammate" <<TEAMMATE
cd "$theirs" && bash "$SCRIPT_place" run --verb file -- \\
  sh -c 'printf "theirs\\n" > "\$1/20260101-b.md"' _ '{}'
TEAMMATE
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "mine\n" > "$2/20260101-a.md"; sh "$1" >/dev/null 2>&1' \
    _ "$teammate" '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "mine landed"   "mine" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null)"
  assert_eq "theirs survived" "theirs" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-b.md 2>/dev/null)"
}

# place_reject_pushes <bare> — a remote that refuses every push, the way a
# protected branch or a missing push right does. The rejection is
# indistinguishable from contention at the push itself, which is the point.
place_reject_pushes() {
  printf '#!/bin/sh\nexit 1\n' > "$1/hooks/pre-receive"
  chmod +x "$1/hooks/pre-receive"
}

# AC: a rejection from a destination that has not moved is not contention, and
# saying it is sends the developer to fix the wrong thing — and to fix it five
# times, since every further attempt fails identically (spec AC #7's "the
# degradation is reported").
case_place_non_contention_rejection_is_named_as_such() {
  local bare clone
  bare="$(place_bare place_reject_bare)"
  clone="$(place_clone "$bare" place_reject 'issue_placement = "jim/issues"')"
  place_reject_pushes "$bare"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit  "rc"                       3                "$RC"
  assert_match "says it is not contention" 'not contention' "$ERR"
  assert_eq "and nothing reached the remote" "" \
    "$(git -C "$bare" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# AC: the same diagnosis is owed on the local tier. An `update-ref` that fails
# for a reason retrying cannot fix — a locked ref, a directory/file conflict, a
# read-only object store — left the loop burning all five attempts and then
# reporting that the branch "kept moving", which is a false cause: it never
# moved at all (spec AC #7's "the degradation is reported").
case_place_local_tier_non_contention_is_named_as_such() {
  local repo empty
  repo="$(place_repo place_local_df 'issue_placement = "jim/issues"')"
  # `refs/heads/jim` cannot be both a ref and the parent of one, so every
  # update-ref to the destination fails identically.
  empty="$(git -C "$repo" mktree < /dev/null)"
  git -C "$repo" update-ref refs/heads/jim \
    "$(git -C "$repo" commit-tree "$empty" -m block)"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit  "rc"                        3                 "$RC"
  assert_match "says it is not contention" 'not contention'  "$ERR"
  assert_match "and relays what git said"  'cannot lock ref' "$ERR"
  assert_eq "nothing was published" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/issues)"
}

# place_reject_once <bare> — a remote that refuses the first push and accepts
# every one after it, so a run takes exactly one retry.
place_reject_once() {
  cat > "$1/hooks/pre-receive" <<'HOOK'
#!/bin/sh
if [ -e "$GIT_DIR/rejected-once" ]; then exit 0; fi
: > "$GIT_DIR/rejected-once"
exit 1
HOOK
  chmod +x "$1/hooks/pre-receive"
}

# AC: no empty commit reaches the destination — including after a retry has
# moved the merge base. The changed set is measured before the loop, and a
# rejection that re-reads the remote refreshes it in place, so a set that was
# non-empty on the first attempt can be empty on the second; building from it
# writes a tree identical to the tip's and publishes a commit with no diff
# (spec AC #4's "exactly one commit").
case_place_retry_publishes_no_empty_commit() {
  local bare mine before_count after_count
  bare="$(place_bare place_empty_bare)"
  mine="$(place_clone "$bare" place_empty_mine 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  before_count="$(git -C "$bare" rev-list --count refs/heads/jim/issues)"
  # Defer a close, so this clone's head runs ahead of the remote.
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --verb close --id 20260101-a -- \
    sh -c 'printf "closed\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "offline close rc" 0 "$RC"
  git -C "$mine" remote set-url origin "$bare"
  place_reject_once "$bare"
  # A mutation that undoes the deferred one. The first attempt builds on this
  # clone's own head and is rejected; the retry re-reads the remote, the merge
  # base moves back to it, and the refreshed base already holds exactly what
  # this run produced — so there is nothing left to publish.
  run_place_in "$mine" run --verb edit --id 20260101-a -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  after_count="$(git -C "$bare" rev-list --count refs/heads/jim/issues)"
  assert_eq "the destination gained no commit" "$before_count" "$after_count"
  assert_eq "and still reads as it did" "open" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null)"
}

# place_reject_and_advance <bare> <branch>
#   A remote that rejects every push *and* moves the branch on each attempt, so
#   every re-read finds a genuinely different tip. That is what keeps the run in
#   the retry loop rather than diagnosing a fixed rejection — contention, five
#   times over.
place_reject_and_advance() {
  local bare="$1" branch="$2"
  cat > "$bare/hooks/pre-receive" <<HOOK
#!/bin/sh
# A push hook runs inside git's object quarantine, where ref updates are
# forbidden outright and new objects are discarded when the push is refused.
# Leaving it is what lets this hook move the branch it is about to reject.
unset GIT_QUARANTINE_PATH GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
old=\$(git rev-parse --verify --quiet "refs/heads/$branch") || exit 1
n=\$(cat "\$GIT_DIR/attempts" 2>/dev/null || echo 0)
n=\$((n + 1))
echo "\$n" > "\$GIT_DIR/attempts"
new=\$(git commit-tree "\$old^{tree}" -p "\$old" -m "advance \$n") || exit 1
git update-ref "refs/heads/$branch" "\$new" "\$old"
exit 1
HOOK
  chmod +x "$bare/hooks/pre-receive"
}

# AC: a destination that keeps moving exhausts the attempt budget rather than
# retrying forever, and says the mutation is unpublished rather than lost — the
# one exit from the loop no case drives, since every race fixture loses exactly
# one race (spec AC #7's "no mutation is ever silently dropped").
case_place_exhausted_attempts_reports_unpublished() {
  local bare clone
  bare="$(place_bare place_exhaust_bare)"
  clone="$(place_clone "$bare" place_exhaust 'issue_placement = "jim/issues"')"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "alpha\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  git -C "$bare" config user.name  "Remote"
  git -C "$bare" config user.email "remote@example.com"
  place_reject_and_advance "$bare" jim/issues
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "mine\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit  "rc"                       3             "$RC"
  assert_match "says the branch kept moving" 'kept moving' "$ERR"
  assert_match "and that nothing is lost"    'not lost'    "$ERR"
  assert_eq "the mutation is not at the destination" "" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-b.md 2>/dev/null)"
  assert_eq "and the remote saw every attempt" "5" \
    "$(cat "$bare/attempts" 2>/dev/null)"
}

# AC: a remote that drops out between attempts leaves the run on the local tier,
# where the mutation still lands — but silently doing so is the deferral nobody
# is told about, and the notices for that are fixed before the loop begins
# (spec AC #7).
case_place_mid_publish_degradation_is_disclosed() {
  local bare clone breaker
  bare="$(place_bare place_middrop_bare)"
  clone="$(place_clone "$bare" place_middrop 'issue_placement = "jim/issues"')"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "seed\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  # The remote goes away after this run read it and before it can publish.
  breaker="$TMP_BASE/place-middrop-breaker.sh"
  cat > "$breaker" <<BREAKER
git -C "$clone" remote set-url origin "$TMP_BASE/no-such-remote.git"
BREAKER
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "later\n" > "$2/20260101-b.md"; sh "$1"' _ "$breaker" '{}'
  assert_exit  "rc"                    0               "$RC"
  assert_match "discloses the drop"    'lost contact'  "$ERR"
  assert_match "and that it is deferred" 'deferred'    "$ERR"
  assert_eq "the mutation is on the local branch" "later" \
    "$(place_dest_file "$clone" jim/issues docs/issues/20260101-b.md)"
}

# AC: a read consults the remote before serving, so a collection published by a
# teammate is visible without any manual fetch (spec AC #6).
case_place_read_fetches_before_serving() {
  local bare mine theirs
  bare="$(place_bare place_fresh_bare)"
  theirs="$(place_clone "$bare" place_fresh_them 'issue_placement = "jim/issues"')"
  mine="$(place_clone "$bare" place_fresh_mine   'issue_placement = "jim/issues"')"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "published\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "their write landed" 0 "$RC"
  run_place_in "$mine" run --read --verb reindex -- \
    sh -c 'cat "$1/20260101-a.md"' _ '{}'
  assert_exit "rc"            0           "$RC"
  assert_eq   "sees the fresh state" "published" "$OUT"
}

# AC: a clone that has only ever *read* the destination still serves the
# collection it last saw when the remote goes away. `git clone` creates no local
# head for the destination and a fetch writes only the remote-tracking ref, so
# the branch ref is not the record of what this clone saw — the bookmark is, and
# an empty answer announced as "the last-seen state" would be a lie (spec AC #6).
case_place_offline_read_serves_the_last_seen_collection() {
  local bare theirs mine
  bare="$(place_bare place_offline_read_bare)"
  theirs="$(place_clone "$bare" place_offline_read_them 'issue_placement = "jim/issues"')"
  mine="$(place_clone "$bare" place_offline_read_mine   'issue_placement = "jim/issues"')"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "published\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "their write landed" 0 "$RC"
  # Read once while the remote is reachable, so this clone has seen it...
  run_place_in "$mine" run --read --verb reindex -- \
    sh -c 'cat "$1/20260101-a.md"' _ '{}'
  assert_exit "online read rc"  0           "$RC"
  assert_eq   "saw it online"   "published" "$OUT"
  assert_eq   "still no local head" "" \
    "$(git -C "$mine" rev-parse --verify --quiet refs/heads/jim/issues)"
  # ...then take the remote away.
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --read --verb reindex -- \
    sh -c 'cat "$1/20260101-a.md"' _ '{}'
  assert_exit  "rc"        0           "$RC"
  assert_match "discloses" 'last-seen' "$ERR"
  assert_eq    "serves what it last saw" "published" "$OUT"
}

# AC: the same clone can still write offline, and the mutation is prepared
# against that last-seen state rather than against nothing — a local commit that
# orphaned the collection would drop every issue the clone had already seen
# (spec AC #7).
case_place_offline_write_builds_on_the_last_seen_state() {
  local bare theirs mine paths
  bare="$(place_bare place_offline_write_bare)"
  theirs="$(place_clone "$bare" place_offline_write_them 'issue_placement = "jim/issues"')"
  mine="$(place_clone "$bare" place_offline_write_mine   'issue_placement = "jim/issues"')"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "published\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "their write landed" 0 "$RC"
  run_place_in "$mine" run --read --verb reindex -- sh -c 'true'
  assert_exit "online read rc" 0 "$RC"
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "mine\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit  "rc"        0       "$RC"
  assert_match "discloses" 'defer' "$ERR"
  paths="$(place_dest_paths "$mine" jim/issues)"
  assert_match "mine committed locally"    'docs/issues/20260101-b\.md' "$paths"
  assert_match "what it had seen survives" 'docs/issues/20260101-a\.md' "$paths"
}

# AC: a mutation the remote was unreachable for is published by the next run
# that can reach it — that is what "propagation completes later" means, and no
# mutation is ever silently dropped (spec AC #7).
case_place_deferred_mutation_publishes_on_reconnect() {
  local bare mine
  bare="$(place_bare place_defer_pub_bare)"
  mine="$(place_clone "$bare" place_defer_pub_mine 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --verb close --id 20260101-a -- \
    sh -c 'printf "closed\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit  "offline rc" 0       "$RC"
  assert_match "discloses"  'defer' "$ERR"
  # Reconnect. A read first, because a read is what used to consume the only
  # signal that anything was outstanding.
  git -C "$mine" remote set-url origin "$bare"
  run_place_in "$mine" run --read --verb reindex -- sh -c 'true'
  assert_exit "read rc" 0 "$RC"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "later\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "later write rc" 0 "$RC"
  # The resuming run says which of the two things it is doing with the backlog.
  assert_match "discloses that it is publishing the backlog" \
    'left unpublished' "$ERR"
  assert_eq "the deferred close reached the remote" "closed" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null)"
  assert_eq "and is still closed here" "closed" \
    "$(place_dest_file "$mine" jim/issues docs/issues/20260101-a.md)"
}

# AC: the same holds when the destination moved on in the meantime. There is
# nothing to fast-forward then, so the unpublished work is reapplied on top of
# what is there now — without disturbing the teammate's own commit (spec AC #7).
case_place_deferred_mutation_survives_a_moved_destination() {
  local bare mine theirs index
  bare="$(place_bare place_defer_div_bare)"
  mine="$(place_clone "$bare" place_defer_div_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_defer_div_them 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --verb close --id 20260101-a -- \
    sh -c 'printf "closed\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "offline rc" 0 "$RC"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "theirs\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "their write landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$bare"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "mine\n" > "$1/20260101-c.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  # The other arm of the same disclosure: there was nothing to fast-forward, so
  # the backlog is being reapplied rather than carried.
  assert_match "discloses that the destination moved on" 'moved on' "$ERR"
  assert_eq "the deferred close reached the remote" "closed" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null)"
  assert_eq "the teammate's issue survived" "theirs" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-b.md 2>/dev/null)"
  assert_eq "and so did this run's" "mine" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-c.md 2>/dev/null)"
  # The index travels in the same commit as the content it describes. A
  # collection regenerated from this clone's own head never saw the teammate's
  # file, so publishing that index alongside their surviving file leaves the
  # destination listing less than it holds — and every reader parses the index.
  index="$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/INDEX.md 2>/dev/null)"
  assert_match "the published index knows the teammate's" '20260101-b' "$index"
  assert_match "and this run's"                           '20260101-c' "$index"
}

# AC: a read in that same diverged state is served from the unpublished side —
# the only tree carrying this clone's own outstanding mutations — so it omits
# everything the destination gained since the fork. The run knows, having just
# fetched it, and the disclosure for that state is gated to writes, so the
# reader was told nothing at all (spec AC #6, and the user story's "never act on
# a stale or partial view").
case_place_diverged_read_discloses_what_it_omits() {
  local bare mine theirs
  bare="$(place_bare place_div_read_bare)"
  mine="$(place_clone "$bare" place_div_read_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_div_read_them 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --verb close --id 20260101-a -- \
    sh -c 'printf "closed\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "offline write rc" 0 "$RC"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "theirs\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "their write landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$bare"
  run_place_in "$mine" run --read --verb reindex -- \
    sh -c 'ls "$1" | tr "\n" " "' _ '{}'
  assert_exit "read rc" 0 "$RC"
  assert_eq "the teammate's issue is genuinely not in the view" "no" \
    "$(grep -q '20260101-b' <<< "$OUT" && echo yes || echo no)"
  assert_match "so the read says the view is partial" 'omits' "$ERR"
  assert_match "and names what closes it"             'next write' "$ERR"
  # The write path's own disclosure is a different sentence for a different
  # audience, and must not be the one a read prints.
  assert_eq "not the write path's wording" "no" \
    "$(grep -q 'being reapplied' <<< "$ERR" && echo yes || echo no)"
}

# AC: a deferred mutation survives the resuming run losing a push race. The
# deferral arm builds on this clone's own head, so the changed set measured
# against it does not contain the deferred paths — they are the base, not the
# change. Re-parenting onto a winner that never saw them therefore drops them
# with nothing in the changed set to replay, at rc 0 (spec AC #7: no mutation is
# ever silently dropped).
case_place_deferred_mutation_survives_a_lost_race() {
  local bare mine theirs teammate
  bare="$(place_bare place_defer_race_bare)"
  mine="$(place_clone "$bare" place_defer_race_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_defer_race_them 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  # Close it while the remote is away, so the clone carries one unpublished
  # commit the destination has never seen.
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --verb close --id 20260101-a -- \
    sh -c 'printf "closed\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "offline rc" 0 "$RC"
  # Reconnect and write again — but lose the race for the push that would have
  # carried the deferred commit along with it.
  git -C "$mine" remote set-url origin "$bare"
  teammate="$TMP_BASE/place-defer-race-teammate.sh"
  cat > "$teammate" <<TEAMMATE
cd "$theirs" && bash "$SCRIPT_place" run --verb file -- \\
  sh -c 'printf "theirs\\n" > "\$1/20260101-b.md"' _ '{}'
TEAMMATE
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "mine\n" > "$2/20260101-c.md"; sh "$1" >/dev/null 2>&1' \
    _ "$teammate" '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "the deferred close survived the race" "closed" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null)"
  assert_eq "the winner's issue survived" "theirs" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-b.md 2>/dev/null)"
  assert_eq "and so did this run's" "mine" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-c.md 2>/dev/null)"
  # The local branch must not be advanced past a commit that never landed.
  assert_eq "the local branch agrees with the remote" \
    "$(git -C "$bare" rev-parse --verify refs/heads/jim/issues 2>/dev/null)" \
    "$(git -C "$mine" rev-parse --verify refs/heads/jim/issues 2>/dev/null)"
}

# AC: a deferred edit to a file the destination has already changed refuses
# rather than reverting it. The conflict rule exists, but a destination that
# moved on while this clone was offline is already at the tip the first attempt
# builds on — so the push fast-forwards and succeeds, and the teammate's
# published content is reverted at rc 0 with no path named. The symmetric
# ordinary race is refused at rc 3, and this asymmetry is the same rule seen one
# state earlier (spec AC #7).
case_place_deferred_edit_refuses_a_concurrent_edit() {
  local bare mine theirs
  bare="$(place_bare place_defer_conflict_bare)"
  mine="$(place_clone "$bare" place_defer_conflict_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_defer_conflict_them 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --verb close --id 20260101-a -- \
    sh -c 'printf "closed\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "offline rc" 0 "$RC"
  # The teammate edits the same file and publishes it while this clone is away.
  run_place_in "$theirs" run --verb edit --id 20260101-a -- \
    sh -c 'printf "theirs\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "their edit landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$bare"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "mine\n" > "$1/20260101-c.md"' _ '{}'
  assert_exit  "refuses the concurrent edit" 3             "$RC"
  assert_match "names the path"              '20260101-a'  "$ERR"
  assert_eq "the teammate's content is intact" "theirs" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null)"
}

# AC: a wrapped write's stdout is a statement about the destination — the
# emitter prints the slug and destination-relative path an issue was filed at —
# so it is withheld until the publish that makes it true has landed. On a
# refusal it must not reach stdout, where a caller would read it as a file it
# can go open (spec AC #3).
case_place_write_withholds_stdout_from_a_refused_publish() {
  local bare mine theirs
  bare="$(place_bare place_stdout_refused_bare)"
  mine="$(place_clone "$bare" place_stdout_refused_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_stdout_refused_them 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --verb close --id 20260101-a -- \
    sh -c 'printf "closed\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "offline rc" 0 "$RC"
  run_place_in "$theirs" run --verb edit --id 20260101-a -- \
    sh -c 'printf "theirs\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "their edit landed" 0 "$RC"
  git -C "$mine" remote set-url origin "$bare"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "20260101-c\t%s/20260101-c.md\n" "$JIM_PLACE_PREFIX"
           printf "mine\n" > "$1/20260101-c.md"' _ '{}'
  assert_exit "the publish is refused" 3 "$RC"
  if printf '%s\n' "$OUT" | grep -q '20260101-c'; then
    CURRENT_FAILED=1
    echo "    [a path nothing landed at must not reach stdout] [$OUT]"
  fi
  # Kept rather than dropped: the ordinal the line names was drawn from an
  # append-only registry and is spent whether or not the publish landed, so
  # discarding the line would lose the only record of which one was burned.
  assert_match "the line is kept on stderr" '20260101-c\.md' "$ERR"
  assert_match "and marked unpublished"     'not published'  "$ERR"
}

# AC: and it does reach stdout once the publish lands, unchanged. Without this
# the case above passes against a run that discards every wrapped command's
# output.
case_place_write_emits_stdout_once_the_publish_lands() {
  local repo
  repo="$(place_repo place_stdout_landed 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues 'INDEX.md=# Issues Index'
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "20260101-a\t%s/20260101-a.md\n" "$JIM_PLACE_PREFIX"
           printf "open\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit  "rc"                            0                            "$RC"
  assert_match "the wrapped line reaches stdout" '20260101-a\.md'           "$OUT"
  assert_match "naming the destination, not the temp dir" 'docs/issues/'    "$OUT"
}

# AC: a read publishes nothing, so there is nothing to withhold — its output is
# handed back as the command produced it.
case_place_read_emits_stdout_unheld() {
  local repo
  repo="$(place_repo place_stdout_read 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues \
    "20260101-a.md=$(place_issue_file 20260101-a open)" \
    'INDEX.md=# Issues Index'
  run_place_in "$repo" run --read --verb reindex -- \
    sh -c 'printf "read-side output\n"' _ '{}'
  assert_exit  "rc"                    0                   "$RC"
  assert_match "the read's own output" 'read-side output'  "$OUT"
}

# AC: the two-phase flow discloses a deferral too. It is the edit path with no
# allocator ahead of it to fail first, so silence there is the whole exposure
# (spec AC #7).
case_place_begin_commit_discloses_a_deferral() {
  local repo token dir
  repo="$(place_repo place_defer_handle 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=open'
  git -C "$repo" remote add origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  printf 'closed\n' > "$dir/20260101-a.md"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "commit rc" 0       "$RC"
  assert_match "discloses"  'defer' "$ERR"
  assert_eq "local commit stands" "closed" \
    "$(place_dest_file "$repo" jim/issues docs/issues/20260101-a.md)"
}

# ─── Section: Graft retry and conflict refusal ───────────────────────────────

# place_issue_writer <file> <slug> <title>
#   Write a shell script that files one issue into its placement collection and
#   regenerates the index there — the shape every real mutation has. It lives in
#   a file so its literal {} survives the outer argument substitution.
place_issue_writer() {
  local out="$1" slug="$2" title="$3"
  cat > "$out" <<WRITER
set -e
d="\$1"
{
  printf -- '---\n'
  printf 'id: %s\n' '$slug'
  printf 'title: "%s"\n' '$title'
  printf 'status: open\nnum: 1\npriority: medium\n'
  printf 'created: 2026-01-01T00:00:00Z\n'
  printf -- '---\n'
} > "\$d/$slug.md"
bash "$REPO_ROOT/skills/issue/scripts/index.sh" "\$d" >/dev/null
WRITER
}

# AC: two teammates filing at once both survive, and the index that lands
# describes the merged collection rather than either side's partial view
# (spec AC #7).
case_place_grafts_disjoint_concurrent_mutations() {
  local bare mine theirs mine_w theirs_w teammate index
  bare="$(place_bare place_graft_bare)"
  mine="$(place_clone "$bare" place_graft_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_graft_them 'issue_placement = "jim/issues"')"
  mine_w="$TMP_BASE/place-graft-mine.sh";   place_issue_writer "$mine_w"   20260101-a Alpha
  theirs_w="$TMP_BASE/place-graft-them.sh"; place_issue_writer "$theirs_w" 20260101-b Beta
  teammate="$TMP_BASE/place-graft-teammate.sh"
  cat > "$teammate" <<TEAMMATE
cd "$theirs" && bash "$SCRIPT_place" run --verb file -- sh "$theirs_w" '{}'
TEAMMATE
  run_place_in "$mine" run --verb file -- \
    sh -c 'sh "$1" "$3"; sh "$2" >/dev/null 2>&1' _ "$mine_w" "$teammate" '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "mine survived"   "yes" \
    "$(git -C "$bare" cat-file -e refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null && echo yes || echo no)"
  assert_eq "theirs survived" "yes" \
    "$(git -C "$bare" cat-file -e refs/heads/jim/issues:docs/issues/20260101-b.md 2>/dev/null && echo yes || echo no)"
  index="$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/INDEX.md 2>/dev/null)"
  assert_match "index knows mine"   '20260101-a' "$index"
  assert_match "index knows theirs" '20260101-b' "$index"
}

# AC: when both sides changed the same file the mutation is refused with the
# path named, rather than one edit silently erasing the other. A refusal is not
# a loss — the local state survives for a re-run (spec AC #7).
case_place_refuses_same_file_concurrency() {
  local bare mine theirs teammate
  bare="$(place_bare place_conflict_bare)"
  mine="$(place_clone "$bare" place_conflict_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_conflict_them 'issue_placement = "jim/issues"')"
  # Seed a shared collection both clones start from.
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "base\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  teammate="$TMP_BASE/place-conflict-teammate.sh"
  cat > "$teammate" <<TEAMMATE
cd "$theirs" && bash "$SCRIPT_place" run --verb edit -- \\
  sh -c 'printf "theirs\\n" > "\$1/20260101-a.md"' _ '{}'
TEAMMATE
  run_place_in "$mine" run --verb edit -- \
    sh -c 'printf "mine\n" > "$2/20260101-a.md"; sh "$1" >/dev/null 2>&1' \
    _ "$teammate" '{}'
  assert_exit  "rc"        3              "$RC"
  assert_match "names path" '20260101-a\.md' "$ERR"
  assert_eq "their edit intact" "theirs" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null)"
}

# AC: a deletion replays as a deletion. A rename is a remove plus a create, so a
# graft that carried only the create would resurrect the old filename and leave
# the collection holding one issue under two names (security Finding 8).
case_place_graft_replays_a_deletion() {
  local bare mine theirs teammate paths
  bare="$(place_bare place_gdel_bare)"
  mine="$(place_clone "$bare" place_gdel_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_gdel_them 'issue_placement = "jim/issues"')"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "old\n" > "$1/20260101-old.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  teammate="$TMP_BASE/place-gdel-teammate.sh"
  cat > "$teammate" <<TEAMMATE
cd "$theirs" && bash "$SCRIPT_place" run --verb file -- \\
  sh -c 'printf "other\\n" > "\$1/20260101-other.md"' _ '{}'
TEAMMATE
  # A rename: remove the old name, create the new one, while the branch moves.
  run_place_in "$mine" run --verb rename -- \
    sh -c 'git mv --help >/dev/null 2>&1; mv "$2/20260101-old.md" "$2/20260101-new.md"; sh "$1" >/dev/null 2>&1' \
    _ "$teammate" '{}'
  assert_exit "rc" 0 "$RC"
  paths="$(git -C "$bare" ls-tree -r --name-only refs/heads/jim/issues 2>/dev/null)"
  assert_match "new name present"  'docs/issues/20260101-new\.md'   "$paths"
  assert_match "teammate survived" 'docs/issues/20260101-other\.md' "$paths"
  assert_eq "old name gone" "no" \
    "$(printf '%s\n' "$paths" | grep -q '20260101-old\.md' && echo yes || echo no)"
}

# AC: a lost race never re-runs the wrapped command, so a filing that races does
# not burn a second coordinated ordinal — the registry records one allocation,
# not one per attempt (spec AC #7).
case_place_graft_does_not_reallocate_on_retry() {
  local bare mine theirs body teammate log
  bare="$(place_bare place_realloc_bare)"
  mine="$(place_clone "$bare" place_realloc_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_realloc_them 'issue_placement = "jim/issues"')"
  body="$(fixture place_realloc_body.md 'body')"
  teammate="$TMP_BASE/place-realloc-teammate.sh"
  cat > "$teammate" <<TEAMMATE
cd "$theirs" && bash "$SCRIPT_place" run --verb file -- \\
  sh -c 'printf "theirs\\n" > "\$1/20260101-b.md"' _ '{}'
TEAMMATE
  run_place_in "$mine" run --verb file -- sh -c \
    'bash "$1" --dir "$4" --title "Alpha bug" --priority medium --labels x \
       --origin conversation --body-file "$2" >/dev/null; sh "$3" >/dev/null 2>&1' \
    _ "$REPO_ROOT/skills/issue/scripts/new.sh" "$body" "$teammate" '{}'
  assert_exit "rc" 0 "$RC"
  log="$(git -C "$mine" cat-file -p refs/heads/jim/registry:issues.log 2>/dev/null)"
  assert_eq "exactly one allocation" "1" \
    "$(printf '%s\n' "$log" | grep -c '^issue allocate ')"
}

# AC: the retry path works on the local tier too, where the ref update is itself
# the compare-and-swap rather than the push. Every other race case drives the
# origin tier, so a regression dropping the local old-value would otherwise be
# invisible — it would clobber the winner at rc 0 instead of regrafting
# (spec AC #7).
case_place_local_tier_retries_after_the_branch_moves() {
  local repo racer paths
  repo="$(place_repo place_local_race 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "base\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  # No remote at all, so both runs land by ref update. The second publishes from
  # inside the first's wrapped command, which makes the loss deterministic.
  racer="$TMP_BASE/place-local-race.sh"
  cat > "$racer" <<RACER
cd "$repo" && bash "$SCRIPT_place" run --verb file -- \\
  sh -c 'printf "theirs\\n" > "\$1/20260101-b.md"' _ '{}'
RACER
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "mine\n" > "$2/20260101-c.md"; sh "$1" >/dev/null 2>&1' \
    _ "$racer" '{}'
  assert_exit "rc" 0 "$RC"
  paths="$(place_dest_paths "$repo" jim/issues)"
  assert_match "mine landed"      'docs/issues/20260101-c\.md' "$paths"
  assert_match "the racer survived" 'docs/issues/20260101-b\.md' "$paths"
  assert_match "the base survived"  'docs/issues/20260101-a\.md' "$paths"
}

# ─── Section: Rewrite detection ──────────────────────────────────────────────

# place_force_unrelated <bare> <branch>
#   Replace <branch> on the bare remote with an unrelated history, the way a
#   force-push does. Issue content is legitimately edited, so unlike an
#   append-only log a placement branch has no self-evident tamper tell — the
#   only honest signal is the tip this clone last saw.
place_force_unrelated() {
  local bare="$1" branch="$2" blob tree commit
  blob="$(printf 'rewritten\n' | git -C "$bare" hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tother.md' "$blob" | git -C "$bare" mktree)"
  commit="$(git -C "$bare" commit-tree "$tree" -m rewritten)"
  git -C "$bare" update-ref "refs/heads/$branch" "$commit"
  printf '%s' "$commit"
}

# AC: a destination whose tip moved non-fast-forward is detected and disclosed
# by the read verbs, naming what was last seen and what is there now — a
# rewritten collection is never served silently as current (spec AC #12).
case_place_read_discloses_a_rewritten_destination() {
  local bare clone seen
  bare="$(place_bare place_rw_read_bare)"
  clone="$(place_clone "$bare" place_rw_read 'issue_placement = "jim/issues"')"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  seen="$(git -C "$clone" rev-parse --verify refs/heads/jim/issues)"
  place_force_unrelated "$bare" jim/issues >/dev/null
  run_place_in "$clone" run --read --verb reindex -- sh -c 'true'
  assert_exit  "rc"              0            "$RC"
  assert_match "discloses rewrite" 'rewritten' "$ERR"
  assert_match "names last seen"   "$seen"     "$ERR"
}

# AC: the same detection applies before a write, so a mutation is never
# published onto a rewritten collection without the developer being told
# (spec AC #12).
case_place_write_discloses_a_rewritten_destination() {
  local bare clone seen
  bare="$(place_bare place_rw_write_bare)"
  clone="$(place_clone "$bare" place_rw_write 'issue_placement = "jim/issues"')"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  seen="$(git -C "$clone" rev-parse --verify refs/heads/jim/issues)"
  place_force_unrelated "$bare" jim/issues >/dev/null
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "second\n" > "$1/20260101-y.md"' _ '{}'
  assert_exit  "rc"              0            "$RC"
  assert_match "discloses rewrite" 'rewritten' "$ERR"
  assert_match "names last seen"   "$seen"     "$ERR"
}

# AC: detection discloses, it does not block — the run advances past a
# rewritten destination and the mutation still lands (spec AC #12).
case_place_rewrite_does_not_block_the_mutation() {
  local bare clone
  bare="$(place_bare place_rw_nonblock_bare)"
  clone="$(place_clone "$bare" place_rw_nonblock 'issue_placement = "jim/issues"')"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  place_force_unrelated "$bare" jim/issues >/dev/null
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "second\n" > "$1/20260101-y.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "mutation landed" "second" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-y.md 2>/dev/null)"
}

# AC: a rewrite that arrives *during* a publish is disclosed too. The run reads
# the destination once before it starts, so a branch rewritten after that point
# is only ever seen by the retry — and a retry that regrafts onto the rewritten
# tip without looking erases the evidence that anything happened (spec AC #12).
case_place_retry_discloses_a_rewrite_that_arrived_mid_publish() {
  local bare clone seen rewriter
  bare="$(place_bare place_rw_retry_bare)"
  clone="$(place_clone "$bare" place_rw_retry 'issue_placement = "jim/issues"')"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  seen="$(git -C "$clone" rev-parse --verify refs/heads/jim/issues)"
  # The rewrite lands from inside the wrapped command, so this run has already
  # read the pre-rewrite tip and will only meet the new one when its push is
  # rejected.
  rewriter="$TMP_BASE/place-rw-retry-rewriter.sh"
  cat > "$rewriter" <<REWRITER
blob="\$(printf 'rewritten\\n' | git -C "$bare" hash-object -w --stdin)"
tree="\$(printf '100644 blob %s\\tother.md' "\$blob" | git -C "$bare" mktree)"
commit="\$(git -C "$bare" commit-tree "\$tree" -m rewritten)"
git -C "$bare" update-ref refs/heads/jim/issues "\$commit"
REWRITER
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "second\n" > "$2/20260101-y.md"; sh "$1"' _ "$rewriter" '{}'
  assert_exit  "rc"                0            "$RC"
  assert_match "discloses rewrite" 'rewritten'  "$ERR"
  assert_match "names last seen"   "$seen"      "$ERR"
}

# AC: an ordinary fast-forward is not a rewrite and says nothing — the
# disclosure has to stay rare enough to mean something.
case_place_fast_forward_is_not_a_rewrite() {
  local bare mine theirs
  bare="$(place_bare place_ff_bare)"
  mine="$(place_clone "$bare" place_ff_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_ff_them 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "a\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "b\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "their write landed" 0 "$RC"
  run_place_in "$mine" run --read --verb reindex -- sh -c 'true'
  assert_exit "rc" 0 "$RC"
  assert_eq   "silent on a fast-forward" "" "$ERR"
}

# AC: rewrite detection rests entirely on the bookmark meaning what it claims —
# the tip this clone last saw *at the destination*. Both conditions that keep it
# honest are asserted here, because a bookmark that records something else turns
# the disclosure into noise and, worse, lets a rewrite built on the recorded
# commit pass the ancestry check silently (spec AC #12).

# A commit that only ever reached this clone is not something the destination
# was seen holding, so a deferred write must leave the bookmark where it was.
case_place_offline_write_does_not_advance_the_bookmark() {
  local bare clone published
  bare="$(place_bare place_bm_write_bare)"
  clone="$(place_clone "$bare" place_bm_write 'issue_placement = "jim/issues"')"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "a\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  published="$(git -C "$bare" rev-parse --verify refs/heads/jim/issues)"
  assert_eq "the bookmark records what was published" \
    "$published" "$(place_bookmark "$clone" jim/issues)"
  git -C "$clone" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$clone" run --verb file -- \
    sh -c 'printf "b\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "offline rc" 0 "$RC"
  assert_eq "the local branch moved" "no" \
    "$([[ "$(git -C "$clone" rev-parse --verify refs/heads/jim/issues)" == "$published" ]] \
      && echo yes || echo no)"
  assert_eq "but the bookmark did not" \
    "$published" "$(place_bookmark "$clone" jim/issues)"
}

# AC: with no remote configured at all the local branch *is* the destination, so
# a publish that reached it is one the bookmark records. The tier is `local` on
# that path, so testing the tier alone would skip the advance — and rewrite
# detection would then be silently inert for every remote-less centralized repo
# (spec AC #12).
case_place_remoteless_publish_advances_the_bookmark() {
  local repo published
  repo="$(place_repo place_bm_noremote 'issue_placement = "jim/issues"')"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "a\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  published="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  assert_nonempty "the write landed"   "$published"
  assert_eq "the bookmark records it"  "$published" \
    "$(place_bookmark "$repo" jim/issues)"
}

# A run that could not reach the destination's owner learned nothing about it,
# so it may not rewind the bookmark to its own state either. Rewinding is worse
# than noisy: a force-push built on the rewound commit is then an ordinary
# fast-forward, and the detector says nothing at all.
case_place_offline_read_does_not_rewind_the_bookmark() {
  local bare mine theirs seen
  bare="$(place_bare place_bm_read_bare)"
  mine="$(place_clone "$bare" place_bm_read_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_bm_read_them 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "a\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "b\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "their write landed" 0 "$RC"
  # An online read advances the bookmark past this clone's own branch ref, which
  # a publish is the only thing that moves — so the two now disagree.
  run_place_in "$mine" run --read --verb reindex -- sh -c 'true'
  assert_exit "online read rc" 0 "$RC"
  seen="$(place_bookmark "$mine" jim/issues)"
  assert_eq "the bookmark followed the destination" \
    "$(git -C "$bare" rev-parse --verify refs/heads/jim/issues)" "$seen"
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --read --verb reindex -- sh -c 'true'
  assert_exit "offline read rc" 0 "$RC"
  assert_eq "an offline read leaves it alone" "$seen" "$(place_bookmark "$mine" jim/issues)"
  # And it serves what the bookmark names, not this clone's own older branch
  # ref. The two are advanced by different events — only a publish moves the
  # branch, every authoritative read moves the bookmark — so preferring the
  # branch serves *less* than the clone last saw while announcing the opposite.
  run_place_in "$mine" run --read --verb reindex -- \
    sh -c 'ls "$1" | tr "\n" " "' _ '{}'
  assert_exit  "offline read rc"         0                "$RC"
  assert_match "serves what it last saw" '20260101-b\.md' "$OUT"
  # Nor may it raise the alarm. Comparing the bookmark against this clone's own
  # branch ref, which only a publish advances, makes an ordinary teammate push
  # look like a rewrite on a routine offline read.
  assert_eq "and says nothing about a rewrite" "no" \
    "$(grep -q 'rewritten' <<< "$ERR" && echo yes || echo no)"
}

# AC: the detector still fires after that sequence, which is the half that
# matters. A bookmark rewound to an older commit makes a force-push built on
# that commit an ordinary fast-forward — the disclosure goes quiet for exactly
# the history rewrite it exists to catch (spec AC #12).
case_place_rewrite_after_an_offline_read_is_still_detected() {
  local bare mine theirs first forged
  bare="$(place_bare place_bm_fn_bare)"
  mine="$(place_clone "$bare" place_bm_fn_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_bm_fn_them 'issue_placement = "jim/issues"')"
  run_place_in "$mine" run --verb file -- \
    sh -c 'printf "a\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  first="$(git -C "$bare" rev-parse --verify refs/heads/jim/issues)"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "b\n" > "$1/20260101-b.md"' _ '{}'
  assert_exit "their write landed" 0 "$RC"
  run_place_in "$mine" run --read --verb reindex -- sh -c 'true'
  assert_exit "online read rc" 0 "$RC"
  git -C "$mine" remote set-url origin "$TMP_BASE/no-such-remote.git"
  run_place_in "$mine" run --read --verb reindex -- sh -c 'true'
  assert_exit "offline read rc" 0 "$RC"
  git -C "$mine" remote set-url origin "$bare"
  # A history rewrite that discards the teammate's commit while keeping the one
  # before it — the shape that hides behind a rewound bookmark.
  forged="$(git -C "$bare" commit-tree "$first^{tree}" -p "$first" -m forged)"
  git -C "$bare" update-ref refs/heads/jim/issues "$forged"
  run_place_in "$mine" run --read --verb reindex -- sh -c 'true'
  assert_exit  "rc"                0            "$RC"
  assert_match "discloses rewrite" 'rewritten'  "$ERR"
}

# ─── Section: Direct mode (destination is the checked-out branch) ────────────

# place_here <name> [extra-config-lines]
#   A repo with one commit whose issue_placement names the branch it is sitting
#   on — filing from `main` with the collection on `main` is an ordinary setup,
#   and plumbing a ref update under a checked-out branch would desync its tree.
place_here() {
  local repo branch; repo="$(empty_dir "$1")"; shift
  git -C "$repo" init -q
  git -C "$repo" config user.name  "Test User"
  git -C "$repo" config user.email "test@example.com"
  printf 'unrelated\n' > "$repo/README.md"
  git -C "$repo" add README.md && git -C "$repo" commit -q -m base
  branch="$(git -C "$repo" symbolic-ref --short HEAD)"
  { printf 'issue_placement = "%s"\n' "$branch"; (( $# > 0 )) && printf '%s\n' "$@"; } \
    > "$repo/jimconf.toml"
  # Committed, so `status` in the cases below reports only what a case dirties.
  git -C "$repo" add jimconf.toml && git -C "$repo" commit -q -m conf
  printf '%s' "$repo"
}

# AC: a write to the checked-out branch lands in the working tree as one
# path-scoped commit, and an unrelated uncommitted edit is neither committed
# nor disturbed (spec AC #3, AC #4; security Finding 9's other half).
case_place_direct_mode_commits_path_scoped() {
  local repo files
  repo="$(place_here place_direct_scoped)"
  printf 'edited\n' > "$repo/README.md"
  run_place_in "$repo" run --verb file -- \
    sh -c 'mkdir -p "$1" && printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "rc" 0 "$RC"
  assert_eq "committed in the working tree" "hello" \
    "$(git -C "$repo" show "HEAD:docs/issues/20260101-x.md" 2>/dev/null)"
  files="$(git -C "$repo" show --name-only --format= HEAD)"
  assert_eq "only collection paths" "docs/issues/20260101-x.md
docs/issues/INDEX.md" "$files"
  assert_eq "unrelated edit still uncommitted" "edited" "$(cat "$repo/README.md")"
  # The index and working tree must agree with the new HEAD. A plumbing ref
  # update under a checked-out branch would leave the collection looking
  # deleted, so the only thing status may report is the unrelated edit.
  assert_eq "status shows only the unrelated edit" " M README.md" \
    "$(git -C "$repo" status --porcelain)"
  assert_eq "collection present in the working tree" "hello" \
    "$(cat "$repo/docs/issues/20260101-x.md" 2>/dev/null)"
}

# AC: a pre-existing uncommitted edit inside the collection refuses the run
# rather than being absorbed into the mutation's commit and published — the
# developer's half-finished work is not this script's to publish (security
# Finding 9).
case_place_direct_mode_refuses_dirty_collection() {
  local repo
  repo="$(place_here place_direct_dirty)"
  mkdir -p "$repo/docs/issues"
  printf 'committed\n' > "$repo/docs/issues/20260101-a.md"
  git -C "$repo" add docs/issues && git -C "$repo" commit -q -m seed
  printf 'half-finished\n' > "$repo/docs/issues/20260101-a.md"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit  "rc"         2                "$RC"
  assert_match "names path" '20260101-a\.md' "$ERR"
  assert_eq "the edit is still uncommitted" "half-finished" \
    "$(cat "$repo/docs/issues/20260101-a.md")"
  assert_eq "nothing new committed" "committed" \
    "$(git -C "$repo" show "HEAD:docs/issues/20260101-a.md" 2>/dev/null)"
}

# AC: a read in direct mode serves the working tree — the checked-out branch is
# the destination, so its checkout is the destination's state (spec AC #5).
case_place_direct_mode_read_serves_the_working_tree() {
  local repo
  repo="$(place_here place_direct_read)"
  mkdir -p "$repo/docs/issues"
  printf 'alpha\n' > "$repo/docs/issues/20260101-a.md"
  run_place_in "$repo" run --read --verb reindex -- \
    sh -c 'cat "$1/20260101-a.md"' _ '{}'
  assert_exit "rc"     0       "$RC"
  assert_eq   "serves" "alpha" "$OUT"
}

# AC: when the remote has moved, the local commit stands and the divergence is
# disclosed with resolution guidance — the developer's checkout is never
# rebased underneath them (spec AC #7).
case_place_direct_mode_discloses_push_divergence() {
  local bare theirs mine branch
  bare="$(place_bare place_direct_div_bare)"
  theirs="$(place_clone "$bare" place_direct_div_them)"
  printf 'base\n' > "$theirs/README.md"
  git -C "$theirs" add README.md && git -C "$theirs" commit -q -m base
  branch="$(git -C "$theirs" symbolic-ref --short HEAD)"
  git -C "$theirs" push -q origin "HEAD:refs/heads/$branch"
  mine="$(place_clone "$bare" place_direct_div_mine)"
  printf 'issue_placement = "%s"\n' "$branch" > "$mine/jimconf.toml"
  printf 'moved\n' > "$theirs/README.md"
  git -C "$theirs" commit -q -am moved
  git -C "$theirs" push -q origin "HEAD:refs/heads/$branch"
  run_place_in "$mine" run --verb file -- \
    sh -c 'mkdir -p "$1" && printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit  "rc"          0          "$RC"
  assert_match "discloses"   'diverged' "$ERR"
  assert_match "says how"    '[Pp]ull'  "$ERR"
  assert_eq "local commit stands" "hello" \
    "$(git -C "$mine" show "HEAD:docs/issues/20260101-x.md" 2>/dev/null)"
}

# place_here_seeded <name> — a direct-mode repo with one committed issue, the
# starting point for every two-phase case below.
place_here_seeded() {
  local repo; repo="$(place_here "$1")"
  mkdir -p "$repo/docs/issues"
  printf 'open\n' > "$repo/docs/issues/20260101-a.md"
  git -C "$repo" add docs/issues && git -C "$repo" commit -q -m seed
  printf '%s' "$repo"
}

# AC: a write handle is something `begin` issues. The bare literal is nobody's
# handle, and honouring it publishes whatever uncommitted work is sitting in the
# collection with nothing having run the dirty guard — which cannot be re-run at
# commit time, because by then the mutation's own edits are the dirty state
# (security Finding 9, the write half).
case_place_direct_commit_refuses_the_bare_literal() {
  local repo head_before
  repo="$(place_here_seeded place_direct_literal)"
  printf 'HALF-FINISHED PRIVATE NOTE\n' > "$repo/docs/issues/20260101-a.md"
  head_before="$(git -C "$repo" rev-parse --verify HEAD)"
  run_place_in "$repo" commit direct --verb close --id 20260101-a
  assert_exit  "refuses"          2          "$RC"
  assert_match "says what to do"  'begin'    "$ERR"
  assert_eq "nothing was committed" "$head_before" \
    "$(git -C "$repo" rev-parse --verify HEAD)"
  assert_eq "the note is still the developer's own" "HALF-FINISHED PRIVATE NOTE" \
    "$(cat "$repo/docs/issues/20260101-a.md")"
}

# AC: the collection path a handle was opened against is what it publishes. The
# direct arm re-resolved it instead, so a changed `issues` key sent the publish
# to a path `index.sh` then created — an empty collection onto the shared
# branch at rc 0, while the agent's real edits stayed uncommitted (spec AC #3).
case_place_direct_commit_refuses_a_moved_collection() {
  local repo token head_before
  repo="$(place_here_seeded place_direct_prefix_drift)"
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"
  printf 'closed\n' > "$repo/docs/issues/20260101-a.md"
  printf 'issue_placement = "%s"\nissues_path = "docs/tickets"\n' \
    "$(git -C "$repo" symbolic-ref --short HEAD)" > "$repo/jimconf.toml"
  head_before="$(git -C "$repo" rev-parse --verify HEAD)"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "refuses"                 2                  "$RC"
  assert_match "names the moved collection" 'docs/tickets'  "$ERR"
  assert_eq "nothing was committed" "$head_before" \
    "$(git -C "$repo" rev-parse --verify HEAD)"
  assert_eq "and no empty collection was created" "no" \
    "$([[ -e "$repo/docs/tickets" ]] && echo yes || echo no)"
}

# AC: a destination that is checked out has its tip in hand, so a read verb can
# say whether the branch the collection lives on was rewritten under it — a
# rebase or reset of that branch is exactly the case AC #12 names, and this arm
# performed no ancestry check at all.
case_place_direct_read_discloses_a_rewritten_destination() {
  local repo seen
  repo="$(place_here_seeded place_direct_rewrite)"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "x\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  seen="$(git -C "$repo" rev-parse --verify HEAD)"
  # Rewrite the branch the collection lives on, the way a rebase would.
  git -C "$repo" reset -q --hard HEAD~1
  printf 'other\n' > "$repo/README.md"
  git -C "$repo" add README.md && git -C "$repo" commit -q -m rewritten
  run_place_in "$repo" run --read --verb reindex -- sh -c 'true'
  assert_exit  "rc"                0           "$RC"
  assert_match "discloses rewrite" 'rewritten' "$ERR"
  assert_match "names last seen"   "$seen"     "$ERR"
}

# AC: a collection path that resolves outside the worktree is not staged. Shape
# validation is what the staging precedent describes as needing this second
# gate, since a shape-valid path can still symlink out of the tree.
case_place_direct_refuses_a_collection_outside_the_worktree() {
  local repo outside
  repo="$(place_here place_direct_escape)"
  outside="$(empty_dir place_direct_escape_target)"
  ln -s "$outside" "$repo/docs"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit  "refuses"            2           "$RC"
  assert_match "says why"           'worktree'  "$ERR"
  assert_eq "nothing was committed outside" "no" \
    "$([[ -e "$outside/issues/INDEX.md" ]] && echo yes || echo no)"
}

# AC: and it refuses through the two-phase door, which is the door that needs it
# most — there is no wrapped command on that arm, so the agent is the writer.
# `begin` handing back an escaping directory means the write has already
# happened outside the worktree by the time `commit` objects, and the refusal it
# prints then ("it will not be written or staged") is false (security Finding 7).
case_place_direct_begin_refuses_a_collection_outside_the_worktree() {
  local repo outside
  repo="$(place_here place_direct_begin_escape)"
  outside="$(empty_dir place_direct_begin_escape_target)"
  ln -s "$outside" "$repo/docs"
  run_place_in "$repo" begin
  assert_exit  "refuses"              2          "$RC"
  assert_match "says why"             'worktree' "$ERR"
  assert_eq    "hands back no handle" ""         "$OUT"
  # The read arm names the same directory, and § 6a opens one on every insights
  # run — so it clears the same gate rather than a weaker one.
  run_place_in "$repo" begin --read
  assert_exit  "the read arm refuses too" 2      "$RC"
  assert_eq    "and names no directory"   ""     "$OUT"
}

# AC: direct mode records what the destination was seen holding on the same
# terms as the plumbing path. A commit whose push was rejected reached nobody,
# so a bookmark advanced before the attempt names a commit only this clone has —
# and every later read compares against it (spec AC #12).
case_place_direct_rejected_push_does_not_advance_the_bookmark() {
  local repo branch
  repo="$(place_here place_direct_bm)"
  branch="$(git -C "$repo" symbolic-ref --short HEAD)"
  git -C "$repo" remote add origin "$TMP_BASE/no-such-remote.git"
  mkdir -p "$repo/docs/issues"
  run_place_in "$repo" run --verb file -- \
    sh -c 'printf "hello\n" > "$1/20260101-x.md"' _ '{}'
  assert_exit  "rc"                    0          "$RC"
  assert_match "discloses the failure" 'not published' "$ERR"
  assert_eq "the mutation is committed here" "hello" \
    "$(git -C "$repo" show "HEAD:docs/issues/20260101-x.md" 2>/dev/null)"
  assert_eq "but the bookmark records nothing seen" "" \
    "$(place_bookmark "$repo" "$branch")"
}

# AC: the two-phase door runs the dirty guard as well, and it has to run at
# `begin` — by `commit` time the handle's own edits are the dirty state and the
# guard can no longer tell them from a developer's half-finished one. The
# wrapped-command arm is covered above; this is the arm where the edits arrive
# from outside the script entirely (security Finding 9).
case_place_direct_begin_refuses_a_dirty_collection() {
  local repo
  repo="$(place_here place_direct_begin_dirty)"
  mkdir -p "$repo/docs/issues"
  printf 'committed\n' > "$repo/docs/issues/20260101-a.md"
  git -C "$repo" add docs/issues && git -C "$repo" commit -q -m seed
  printf 'half-finished\n' > "$repo/docs/issues/20260101-a.md"
  run_place_in "$repo" begin
  assert_exit  "refuses"    2                "$RC"
  assert_match "names path" '20260101-a\.md' "$ERR"
  assert_eq    "hands back no handle" "" "$OUT"
  assert_eq "the edit is still the developer's own" "half-finished" \
    "$(cat "$repo/docs/issues/20260101-a.md")"
}

# AC: a guard that cannot run has not passed. `status` reports a dirty
# collection on stdout, so testing output alone reads every failure — a corrupt
# index, a refused pathspec, a permissions error — as "clean", and the guard
# waves through exactly the states it exists to stop (security Finding 9).
case_place_direct_begin_refuses_when_the_dirty_guard_cannot_run() {
  local repo
  repo="$(place_here place_direct_begin_guard_blind)"
  mkdir -p "$repo/docs/issues"
  printf 'committed\n' > "$repo/docs/issues/20260101-a.md"
  git -C "$repo" add docs/issues && git -C "$repo" commit -q -m seed
  # A corrupt index: `status` exits non-zero having printed nothing, while
  # `rev-parse` still answers — so the containment gate passes and this guard is
  # the one being driven.
  printf 'GARBAGE' > "$repo/.git/index"
  run_place_in "$repo" begin
  assert_exit  "refuses"              2             "$RC"
  assert_eq    "hands back no handle" ""            "$OUT"
  assert_match "says it could not tell" 'cannot tell' "$ERR"
}

# AC: a read handle takes the arm that has no edits to protect, so the guard is
# deliberately not in its way — a dirty collection must still be readable.
case_place_direct_begin_read_allows_a_dirty_collection() {
  local repo
  repo="$(place_here place_direct_begin_read_dirty)"
  mkdir -p "$repo/docs/issues"
  printf 'committed\n' > "$repo/docs/issues/20260101-a.md"
  git -C "$repo" add docs/issues && git -C "$repo" commit -q -m seed
  printf 'half-finished\n' > "$repo/docs/issues/20260101-a.md"
  run_place_in "$repo" begin --read
  assert_exit "rc" 0 "$RC"
  assert_eq   "hands back the read token" "direct-read" "${OUT%%$'\t'*}"
}

# AC: the two-phase flow works in direct mode too — it hands back the working
# tree's own collection and publishes the edits made there (spec AC #3, #4).
case_place_direct_begin_commit_publishes_an_edit() {
  local repo token dir
  repo="$(place_here_seeded place_direct_begin)"
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  assert_eq "the working tree collection" "docs/issues" "$dir"
  printf 'closed\n' > "$repo/docs/issues/20260101-a.md"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit "commit rc" 0 "$RC"
  assert_eq "published" "closed" \
    "$(git -C "$repo" show HEAD:docs/issues/20260101-a.md 2>/dev/null)"
  assert_eq "subject" "docs(issues): close 20260101-a" \
    "$(git -C "$repo" log -1 --format=%s)"
}

# AC: a read handle cannot publish in direct mode either. The insights flow
# opens one on every run, so a read token that published would make that flow a
# capability to commit whatever half-finished edits happen to be sitting in the
# collection (spec AC #5).
case_place_direct_read_handle_cannot_commit() {
  local repo token head_before
  repo="$(place_here_seeded place_direct_read_handle)"
  printf 'HALF-FINISHED PRIVATE NOTE\n' > "$repo/docs/issues/20260101-a.md"
  head_before="$(git -C "$repo" rev-parse --verify HEAD)"
  run_place_in "$repo" begin --read
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "refuses"                2                  "$RC"
  # Pinned to the read-handle arm's own words: with that arm deleted the literal
  # falls through to the handle lookup, which refuses at the same rc 2 with a
  # message about a handle it cannot find.
  assert_match "because it is read-only" 'opened read-only' "$ERR"
  assert_eq "nothing published" "$head_before" \
    "$(git -C "$repo" rev-parse --verify HEAD)"
  assert_eq "the note is still the developer's own" "HALF-FINISHED PRIVATE NOTE" \
    "$(cat "$repo/docs/issues/20260101-a.md")"
  run_place_in "$repo" abort "$token"
  assert_exit "abort is a no-op" 0 "$RC"
}

# AC: `direct` is a fixed literal rather than an unguessable handle, so `commit`
# proves for itself that the destination is still the checked-out branch. A
# branch switch between the two steps would otherwise commit the collection onto
# the feature branch and push that whole branch to the shared one (spec AC #3).
case_place_direct_commit_refuses_after_a_branch_switch() {
  local repo token head_before
  repo="$(place_here_seeded place_direct_switch)"
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"
  git -C "$repo" checkout -q -b feature
  head_before="$(git -C "$repo" rev-parse --verify HEAD)"
  printf 'closed\n' > "$repo/docs/issues/20260101-a.md"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "refuses"       2         "$RC"
  assert_match "names where HEAD is now" 'feature' "$ERR"
  assert_eq "nothing committed on the feature branch" "$head_before" \
    "$(git -C "$repo" rev-parse --verify HEAD)"
}

# AC: the destination a handle was opened for is what it may publish to. A
# placement changed to the reserved sentinel between the two steps means the
# collection no longer belongs on a branch at all, and taking `branch` for a
# branch name would push to a remote branch literally called that (spec AC #1).
case_place_direct_commit_refuses_the_branch_sentinel() {
  local repo token
  repo="$(place_here_seeded place_direct_sentinel)"
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"
  printf 'issue_placement = "branch"\n' > "$repo/jimconf.toml"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "refuses" 2 "$RC"
  # Pin this refusal's own words. Without the check, the prefix and HEAD guards
  # below it both pass — the collection path has not moved and the branch is
  # still checked out — and the mutation publishes at rc 0.
  assert_match "names the placement change" 'issue placement now names' "$ERR"
}

# ─── Section: Two-phase begin / commit / abort ───────────────────────────────

# AC: an agent-interactive mutation with no single wrapped command — editing an
# issue's status in place — gets a placement door too: materialize, edit, then
# publish through the same engine (spec AC #3).
case_place_begin_commit_publishes_an_edit() {
  local repo handle token dir
  repo="$(place_repo place_begin_edit 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=open'
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  assert_nonempty "token" "$token"
  assert_eq "materialized for editing" "open" "$(cat "$dir/20260101-a.md")"
  printf 'closed\n' > "$dir/20260101-a.md"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit "commit rc" 0 "$RC"
  assert_eq "published" "closed" \
    "$(place_dest_file "$repo" jim/issues docs/issues/20260101-a.md)"
  assert_eq "subject" "docs(issues): close 20260101-a" \
    "$(git -C "$repo" log -1 --format=%s refs/heads/jim/issues)"
  assert_eq "handle cleaned up" "no" "$([[ -d "$dir" ]] && echo yes || echo no)"
}

# AC: a concurrent edit to the same file refuses and keeps the work. The temp
# state survives so the developer can re-run rather than retype (spec AC #7).
case_place_begin_commit_conflict_preserves_state() {
  local bare mine theirs token dir
  bare="$(place_bare place_begin_conf_bare)"
  mine="$(place_clone "$bare" place_begin_conf_mine   'issue_placement = "jim/issues"')"
  theirs="$(place_clone "$bare" place_begin_conf_them 'issue_placement = "jim/issues"')"
  run_place_in "$theirs" run --verb file -- \
    sh -c 'printf "base\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "seed landed" 0 "$RC"
  run_place_in "$mine" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  printf 'mine\n' > "$dir/20260101-a.md"
  run_place_in "$theirs" run --verb edit -- \
    sh -c 'printf "theirs\n" > "$1/20260101-a.md"' _ '{}'
  assert_exit "their edit landed" 0 "$RC"
  run_place_in "$mine" commit "$token" --verb edit --id 20260101-a
  assert_exit  "refuses"    3                "$RC"
  assert_match "names path" '20260101-a\.md' "$ERR"
  assert_eq "handle preserved" "yes" "$([[ -d "$dir" ]] && echo yes || echo no)"
  assert_eq "edit preserved"   "mine" "$(cat "$dir/20260101-a.md")"
  assert_eq "their edit intact" "theirs" \
    "$(git -C "$bare" cat-file -p refs/heads/jim/issues:docs/issues/20260101-a.md 2>/dev/null)"
}

# AC: everything that made a handle safe to publish was established at `begin`,
# and each of those facts can have changed since — so the routed arm re-proves
# them, as the checked-out arm already does. It reads its destination back from
# handle state and hands it to push / update-ref / ls-remote / fetch, so the
# gate has to be re-established on this side of that read (spec AC #9, AC #10).
case_place_commit_refuses_a_retargeted_destination() {
  local repo token dir before
  repo="$(place_repo place_commit_dest_drift 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=open'
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  printf 'closed\n' > "$dir/20260101-a.md"
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  printf 'issue_placement = "jim/other"\n' > "$repo/jimconf.toml"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "refuses"                        2            "$RC"
  assert_match "names the handle's destination" 'jim/issues' "$ERR"
  assert_match "and the one now configured"     'jim/other'  "$ERR"
  assert_eq "the handle's destination is unmoved" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  assert_eq "and nothing was created at the new one" "" \
    "$(git -C "$repo" rev-parse --verify --quiet refs/heads/jim/other)"
}

# AC: the reachable case the gate exists for — the coordination branch retargeted
# onto a destination already in flight. `place_destination` refuses that pairing,
# and it is the refusal the routed arm never re-asked for, publishing issue
# content onto the registry's own branch (spec AC #9).
case_place_commit_refuses_a_destination_that_became_the_coordination_branch() {
  local repo token dir before
  repo="$(place_repo place_commit_coord_drift 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=open'
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  printf 'closed\n' > "$dir/20260101-a.md"
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  printf 'issue_placement = "jim/issues"\nid_coordination_branch = "jim/issues"\n' \
    > "$repo/jimconf.toml"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "refuses"  2              "$RC"
  assert_match "says why" 'coordination' "$ERR"
  assert_eq "nothing was published" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
}

# AC: the collection path is re-proved on this arm too. It composes the tree
# entries the publish writes, so a changed `issues` key publishes the handle's
# edits at a path they were never prepared for (spec AC #3).
case_place_commit_refuses_a_moved_collection_path() {
  local repo token dir before
  repo="$(place_repo place_commit_prefix_drift 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=open'
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  printf 'closed\n' > "$dir/20260101-a.md"
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  printf 'issue_placement = "jim/issues"\nissues_path = "docs/tickets"\n' \
    > "$repo/jimconf.toml"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "refuses"                    2              "$RC"
  assert_match "names the moved collection" 'docs/tickets' "$ERR"
  assert_eq "nothing was published" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  assert_eq "and no collection appeared at the new path" "no" \
    "$(place_dest_paths "$repo" jim/issues | grep -q 'docs/tickets' && echo yes || echo no)"
}

# AC: a plumbing handle publishes by moving `refs/heads/<dest>` with update-ref,
# which has no checked-out-branch protection of its own. If the developer checks
# the destination out between the two steps, that ref moves under their index and
# working tree and the collection reads as deleted. The checked-out arm guards
# this exact transition; this arm reached the same outcome by the other door.
case_place_commit_refuses_when_the_destination_became_checked_out() {
  local repo token dir before
  repo="$(place_repo place_commit_head_drift 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=open'
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  printf 'closed\n' > "$dir/20260101-a.md"
  git -C "$repo" checkout -q jim/issues
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  run_place_in "$repo" commit "$token" --verb close --id 20260101-a
  assert_exit  "refuses"               2            "$RC"
  assert_match "names the destination" 'jim/issues' "$ERR"
  assert_eq "the ref did not move under the working tree" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  assert_eq "and the checkout still reads as it did" "open" \
    "$(cat "$repo/docs/issues/20260101-a.md")"
}

# AC: abort discards the materialized collection and publishes nothing.
case_place_abort_leaves_nothing() {
  local repo token dir before
  repo="$(place_repo place_abort 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=open'
  before="$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
  run_place_in "$repo" begin
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  printf 'discarded\n' > "$dir/20260101-a.md"
  run_place_in "$repo" abort "$token"
  assert_exit "abort rc" 0 "$RC"
  assert_eq "handle gone" "no" "$([[ -d "$dir" ]] && echo yes || echo no)"
  assert_eq "tip unmoved" "$before" \
    "$(git -C "$repo" rev-parse --verify refs/heads/jim/issues)"
}

# AC: the insights persona is handed a materialized collection through the same
# door, read-only — and a read handle may not publish (spec AC #5).
case_place_begin_read_handle_cannot_commit() {
  local repo token dir
  repo="$(place_repo place_begin_read 'issue_placement = "jim/issues"')"
  place_seed_collection "$repo" jim/issues docs/issues '20260101-a.md=alpha'
  run_place_in "$repo" begin --read
  assert_exit "begin rc" 0 "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  assert_eq "materialized to read" "alpha" "$(cat "$dir/20260101-a.md")"
  printf 'sneak\n' > "$dir/20260101-a.md"
  run_place_in "$repo" commit "$token" --verb edit
  assert_exit     "refuses"  2      "$RC"
  assert_nonempty "explains" "$ERR"
  run_place_in "$repo" abort "$token"
  assert_exit "abort rc" 0 "$RC"
}

# AC: under the default placement the two-phase flow still works — it hands back
# the real collection directory and publishes nothing, so today's edit-in-place
# convention is unchanged (spec AC #2).
case_place_begin_is_transparent_under_default_placement() {
  local repo token dir
  repo="$(place_repo place_begin_default)"
  run_place_in "$repo" begin
  assert_exit "begin rc"    0                "$RC"
  token="${OUT%%$'\t'*}"; dir="${OUT##*$'\t'}"
  assert_eq   "no handle"   "none"           "$token"
  assert_eq   "the real dir" "./docs/issues" "$dir"
  run_place_in "$repo" commit "$token" --verb close
  assert_exit "commit is a no-op" 0 "$RC"
  run_place_in "$repo" abort "$token"
  assert_exit "abort is a no-op"  0 "$RC"
}

# AC: a token that names no live handle refuses rather than guessing — which is
# how a crash between begin and commit is surfaced.
case_place_commit_unknown_token_refuses() {
  local repo
  repo="$(place_repo place_bad_token 'issue_placement = "jim/issues"')"
  run_place_in "$repo" commit "handle.deadbeef" --verb close
  assert_exit     "rc"       2      "$RC"
  assert_nonempty "explains" "$ERR"
  # Pinned to the charset gate's own words. A bare "rc 2 and something on
  # stderr" passes with that gate deleted, because the next guard down refuses
  # a handle it cannot find in exactly the same shape.
  run_place_in "$repo" commit "../../escape" --verb close
  assert_exit  "traversal refused"      2                         "$RC"
  assert_match "at the token boundary" 'malformed handle token'   "$ERR"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT_place" ]]; then
    echo "NOTE: script under test not found at $SCRIPT_place — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
