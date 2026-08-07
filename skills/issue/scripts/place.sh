#!/usr/bin/env bash
#
# skills/issue/scripts/place.sh — decide where an issue-collection mutation
#   lands, and land it there. A project can keep its issue collection on the
#   branch the developer happens to be working on (the default), or designate
#   one branch — main, or a dedicated issues branch — as the collection's single
#   home. This script is the seam between those two worlds.
#
# WHY IT EXISTS
#   Issue files and INDEX.md are a cross-branch discovery artifact stored, by
#   default, in per-branch fragments: a finding filed on a feature branch is
#   invisible until that branch merges, and a close on one branch leaves the
#   issue open on every other. Pointing the collection at one branch fixes that,
#   but the issue scripts resolve their paths from the working directory, so
#   something has to put the destination branch's collection in front of them
#   and put the result back afterwards. That is this script.
#
# HOW WRITES REACH A BRANCH NOBODY HAS CHECKED OUT
#   By plumbing, never by checkout: the destination tip's collection is
#   extracted into a temp directory, the wrapped command runs against that
#   directory, and the result is committed with hash-object / mktree /
#   commit-tree and landed with a ref compare-and-swap. The developer's working
#   tree is never touched, and the wrapped command keeps the primary checkout as
#   its working directory, so config resolves to the project's real settings.
#
# SELF-ROUTING AND THE RUN TOKEN
#   The entry scripts ask `mode` whether to route, and re-exec themselves
#   through `run` when it says so. To stop that re-exec from recursing, place.sh
#   exports JIM_PLACE_TOKEN and passes the same value back to the re-exec'd
#   script as --place-token. Routing is suppressed only when the two agree.
#   An environment variable on its own — inherited from a parent shell, or set
#   by hand — matches nothing, so it is ignored and disclosed rather than
#   silently switching centralization off and landing the write on the working
#   branch.
#
# CLI SUMMARY
#   bash place.sh mode [--place-token <tok>]
#     Print `direct` (run against the working tree, today's behavior) or
#     `route` (re-exec through `run`). The config gate lives here.
#   bash place.sh run [--read] --verb <enum> [--id <slug>] -- CMD [ARGS...]
#     Run CMD against the collection. `{}` in ARGS becomes the collection
#     directory, `{token}` becomes this run's token. --read discards the result
#     instead of publishing it.
#
#   verb enum: file | edit | close | rename | realize | reindex | backfill |
#   migrate. Commit subjects are composed from the enum plus an optional
#   validated id, so no free text ever reaches a commit message.
#
# EXIT CODES
#   0  Success (stderr may carry degradation notes).
#   1  IO or engine failure.
#   2  Config or validation refusal (junk branch name, coordination branch,
#      unknown verb, malformed invocation).
#   3  Concurrent-conflict refusal.
#
#   In passthrough the wrapped command's own status is forwarded verbatim, so a
#   caller sees the emitter's failure rather than a placement-flavored one.
#
# Parses with grep/sed only; never sources or evals config or issue content.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"

readonly PLACE_VERBS=(file edit close rename realize reindex backfill migrate)

# Built by place_substitute; the wrapped command with its placeholders resolved.
PLACE_CMD=()

# ─── Section: Config resolution ──────────────────────────────────────────────

# place_conf <key> — resolve one jimconf key from the primary checkout.
place_conf() { bash "$JIMCONF" get "$1" 2>/dev/null; }

# place_issues_dir — the configured collection directory, trailing slash
# stripped. Used as the `{}` substitution when placement is not centralizing.
place_issues_dir() {
  local dir
  dir="$(place_conf issues)"
  dir="${dir%/}"
  if [[ -z "$dir" ]]; then
    echo "place.sh: the configured issues directory is empty" >&2
    return 2
  fi
  printf '%s\n' "$dir"
}

# place_valid_branch <branch> — exit 0 iff <branch> is safe to interpolate into
# a git command: non-empty, no leading '-' (option injection), and accepted by
# git's own ref-name policy (which rejects '..', control characters, ~^:?*[,
# .lock and the rest). Both branch names this script handles are config-supplied
# and reach fetch refspecs and ref paths, so they clear this gate first.
place_valid_branch() {
  local b="${1:-}"
  [[ -n "$b" ]] || return 1
  case "$b" in -*) return 1 ;; esac
  git check-ref-format "refs/heads/$b" >/dev/null 2>&1
}

# place_coord_branch — the configured coordination branch (default
# jim/registry), validated. A configured value that is not a usable branch name
# is a refusal rather than a fallback: the placement guard compares against this
# name, and a guard that cannot be established must not be assumed to pass.
place_coord_branch() {
  local b
  b="$(place_conf id_coordination_branch)"
  [[ -n "$b" ]] || b="jim/registry"
  if ! place_valid_branch "$b"; then
    echo "place.sh: id_coordination_branch '$b' is not a valid git branch name," \
         "so the coordination-branch guard cannot be established" >&2
    return 1
  fi
  printf '%s\n' "$b"
}

# place_destination — print `branch` when the collection stays on the working
# branch, otherwise the destination branch name. rc 2 refuses, naming the value:
# a junk placement never falls back to the working branch, because a silent
# fallback would scatter a team's collection across feature branches at rc 0.
place_destination() {
  local v
  v="$(place_conf issue_placement)"
  [[ -n "$v" ]] || v="branch"
  if [[ "$v" == "branch" ]]; then
    printf 'branch\n'
    return 0
  fi
  if ! place_valid_branch "$v"; then
    echo "place.sh: issue_placement '$v' is not a valid git branch name" >&2
    return 2
  fi
  local coord
  coord="$(place_coord_branch)" || return 2
  if [[ "$v" == "$coord" ]]; then
    echo "place.sh: issue_placement '$v' names the coordination branch," \
         "which holds registry logs only" >&2
    return 2
  fi
  printf '%s\n' "$v"
}

# ─── Section: Argument validation ────────────────────────────────────────────

# place_valid_verb <verb> — exit 0 iff <verb> is one of the trusted subjects a
# commit message may be composed from.
place_valid_verb() {
  local want="${1:-}" v
  for v in "${PLACE_VERBS[@]}"; do
    [[ "$want" == "$v" ]] && return 0
  done
  echo "place.sh: unknown verb; expected one of: ${PLACE_VERBS[*]}" >&2
  return 1
}

# place_substitute <dir> <token> <arg>... — fill PLACE_CMD with the wrapped
# command, replacing every `{}` with <dir> and every `{token}` with <token>.
# Substitution is per-argument, so a directory containing spaces stays one word.
place_substitute() {
  local dir="$1" token="$2"; shift 2
  PLACE_CMD=()
  local a
  for a in "$@"; do
    a="${a//\{\}/$dir}"
    a="${a//\{token\}/$token}"
    PLACE_CMD+=( "$a" )
  done
}

# ─── Section: Engine ─────────────────────────────────────────────────────────

PLACE_WORK=""    # this run's temp root, removed by the cleanup trap
PLACE_COLL=""    # the materialized collection inside it — the `{}` substitution
PLACE_INDEX=""   # scratch git index used to build the destination tree
PLACE_TOKEN=""   # this run's token

# place_cleanup — discard the run's temp root. Registered on EXIT, INT and TERM
# so an interrupted run leaves no materialized collection behind.
place_cleanup() {
  if [[ -n "$PLACE_WORK" && -d "$PLACE_WORK" ]]; then
    rm -rf -- "$PLACE_WORK"
  fi
  return 0
}

# place_open_work — create the run's temp root and derive this run's token from
# its basename, which mktemp already made unique and unguessable.
place_open_work() {
  PLACE_WORK="$(mktemp -d 2>/dev/null)" || {
    echo "place.sh: could not create a working directory" >&2
    return 1
  }
  trap place_cleanup EXIT INT TERM
  PLACE_COLL="$PLACE_WORK/collection"
  PLACE_INDEX="$PLACE_WORK/index"
  PLACE_TOKEN="${PLACE_WORK##*/}"
  mkdir -p -- "$PLACE_COLL"
}

# place_prefix — the collection's path inside the destination branch's tree.
# It mirrors the project's configured layout so a checkout of that branch is
# self-describing rather than a black box.
place_prefix() {
  local dir
  dir="$(place_issues_dir)" || return 2
  dir="${dir#./}"
  dir="${dir%/}"
  if ! bash "$JIMFILE" valid-relpath "$dir" >/dev/null 2>&1; then
    echo "place.sh: the configured issues directory is not a safe repo-relative" \
         "path, so it cannot be mirrored onto a destination branch" >&2
    return 2
  fi
  case "$dir" in -*) echo "place.sh: the configured issues directory may not begin with '-'" >&2; return 2 ;; esac
  printf '%s\n' "$dir"
}

# place_shown <text> — <text> with control characters removed, for messages that
# quote a name taken from branch content. The name is data, and a terminal is
# not obliged to interpret whatever escape sequence it carries.
place_shown() { printf '%s' "$1" | tr -d '[:cntrl:]'; }

# place_bookmark_ref <branch> — the local ref recording the last destination tip
# this clone acted on. It lives outside refs/heads so it is never pushed,
# fetched, or mistaken for a branch.
place_bookmark_ref() {
  local ref="refs/jim/issue-placement/$1"
  git check-ref-format "$ref" >/dev/null 2>&1 || return 1
  printf '%s\n' "$ref"
}

# place_materialize <tip> <prefix> <dest>
#   Extract the collection at <prefix> in commit <tip> into <dest>, one entry at
#   a time. Branch content is untrusted — a tree can carry an entry name that
#   escapes the directory it is listed under, and no fetch validates that — so
#   every entry clears three gates before a single byte is written: it must be a
#   regular file, it must be a plain name inside the collection (the collection
#   is one flat directory of files, which is all any issue script reads or
#   writes), and its resolved destination must land under <dest>. Blobs are read
#   by object name, never by tree path, so a crafted name never reaches a git
#   argument at all. The first violation aborts the whole extraction, so a
#   refused run leaves no partial collection and never runs the wrapped command.
place_materialize() {
  local tip="$1" prefix="$2" dest="$3"
  [[ -n "$tip" ]] || return 0
  local subtree
  subtree="$(git rev-parse --verify --quiet --end-of-options "$tip:$prefix" 2>/dev/null)" || return 0
  [[ -n "$subtree" ]] || return 0
  local dest_real
  dest_real="$(realpath -m -- "$dest" 2>/dev/null)" || return 1
  local rec meta mode type sha name shown resolved
  while IFS= read -r -d '' rec; do
    name="${rec#*$'\t'}"
    meta="${rec%%$'\t'*}"
    read -r mode type sha <<< "$meta"
    shown="$(place_shown "$name")"
    case "$mode" in
      100644|100755) ;;
      *)
        echo "place.sh: refusing '$shown' from branch '$prefix' — the collection" \
             "holds regular files only" >&2
        return 2 ;;
    esac
    if [[ "$name" == */* || "$name" == "." || "$name" == ".." ]]; then
      echo "place.sh: refusing '$shown' from branch '$prefix' — a collection entry" \
           "must be a plain file name" >&2
      return 2
    fi
    case "$name" in -*)
      echo "place.sh: refusing '$shown' from branch '$prefix' — a collection entry" \
           "may not begin with '-'" >&2
      return 2 ;;
    esac
    if ! bash "$JIMFILE" valid-relpath "$name" >/dev/null 2>&1; then
      echo "place.sh: refusing '$shown' from branch '$prefix' — not a safe" \
           "relative path" >&2
      return 2
    fi
    if ! resolved="$(realpath -m -- "$dest/$name" 2>/dev/null)" \
       || [[ "$resolved" != "$dest_real"/* ]]; then
      echo "place.sh: refusing '$shown' from branch '$prefix' — it resolves" \
           "outside the collection directory" >&2
      return 2
    fi
    if ! git cat-file blob "$sha" > "$dest/$name" 2>/dev/null; then
      echo "place.sh: could not read collection content from branch '$prefix'" >&2
      return 1
    fi
  done < <(git ls-tree -r -z "$subtree")
  return 0
}

# place_snapshot <dir> <assoc-array-name>
#   Fill the named associative array with name → blob sha for every file in the
#   collection. Comparing two snapshots is what yields the changed set, and it
#   yields deletions as naturally as additions — a mutation that removes a file
#   (a rename is a remove plus a create) must remove it at the destination too,
#   or the old name comes back the moment the write is replayed.
#   The nameref locals carry a reserved prefix throughout this script: a
#   nameref whose own name matches the array it points at resolves to itself,
#   and bash yields an empty array rather than an error.
place_snapshot() {
  local dir="$1"
  local -n _ps_snap="$2"
  _ps_snap=()
  local entry name sha
  while IFS= read -r -d '' entry; do
    name="${entry##*/}"
    if [[ ! -f "$entry" || -L "$entry" ]]; then
      echo "place.sh: the collection may hold regular files only; found '$name'" >&2
      return 1
    fi
    # -w stores the blob: the destination tree is built from these object names,
    # so a sha that was only computed names nothing the tree can reference.
    sha="$(git hash-object -w -- "$entry")" || return 1
    _ps_snap["$name"]="$sha"
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  return 0
}

# place_commit_tree <tree> <message> [<parent>]
#   Build the commit object. A parentless commit is the destination branch's
#   birth: a branch that does not exist yet is created carrying the collection
#   alone, rather than forking the whole working branch into every later
#   materialization. The committer identity is git's own unless the clone has
#   none configured, in which case a fixed one stands in.
place_commit_tree() {
  local tree="$1" msg="$2" parent="${3:-}"
  local -a ident=() parent_arg=()
  if [[ -z "$(git config user.email 2>/dev/null)" ]]; then
    ident=(-c "user.name=jim-placement" -c "user.email=jim-placement@localhost")
  fi
  [[ -n "$parent" ]] && parent_arg=(-p "$parent")
  git "${ident[@]}" commit-tree "$tree" "${parent_arg[@]}" -m "$msg"
}

# place_publish <branch> <tip> <prefix> <before-array> <after-array> <message>
#   Land the changed set on <branch> with git plumbing: replay the changes into
#   a scratch index seeded from <tip>, write the tree, commit it, and move the
#   ref with an old-value compare-and-swap so a concurrent session that advanced
#   the branch is detected rather than overwritten. Prints the new commit.
#   rc 3 means the compare-and-swap was rejected.
place_publish() {
  local branch="$1" tip="$2" prefix="$3" msg="$6"
  local -n _pp_before="$4"
  local -n _pp_after="$5"
  local name tree commit rc
  (
    export GIT_INDEX_FILE="$PLACE_INDEX"
    rm -f -- "$PLACE_INDEX"
    if [[ -n "$tip" ]]; then
      git read-tree "$tip" || exit 1
    else
      git read-tree --empty || exit 1
    fi
    for name in "${!_pp_after[@]}"; do
      [[ "${_pp_before[$name]:-}" == "${_pp_after[$name]}" ]] && continue
      git update-index --add --cacheinfo 100644 "${_pp_after[$name]}" "$prefix/$name" || exit 1
    done
    for name in "${!_pp_before[@]}"; do
      [[ -n "${_pp_after[$name]:-}" ]] && continue
      git update-index --force-remove -- "$prefix/$name" || exit 1
    done
    git write-tree
  ) > "$PLACE_WORK/tree" 2>/dev/null
  rc=$?
  (( rc == 0 )) || { echo "place.sh: could not build the destination tree" >&2; return 1; }
  tree="$(cat "$PLACE_WORK/tree")"
  [[ -n "$tree" ]] || { echo "place.sh: could not build the destination tree" >&2; return 1; }
  commit="$(place_commit_tree "$tree" "$msg" "$tip")" || {
    echo "place.sh: could not build the destination commit" >&2
    return 1
  }
  # An empty old-value requires the ref to be absent, which is what makes the
  # orphan bootstrap a compare-and-swap too rather than a blind create.
  if ! git update-ref "refs/heads/$branch" "$commit" "$tip" 2>/dev/null; then
    return 3
  fi
  printf '%s\n' "$commit"
}

# place_message <verb> <id> — the commit subject, composed from the trusted verb
# enum plus an id that has already cleared the issue-id boundary. No caller text
# reaches a commit message.
place_message() {
  local verb="$1" id="${2:-}"
  if [[ -n "$id" ]]; then
    printf 'docs(issues): %s %s\n' "$verb" "$id"
  else
    printf 'docs(issues): %s\n' "$verb"
  fi
}

# ─── Section: Verbs ──────────────────────────────────────────────────────────

# cmd_mode [--place-token <tok>] — the self-routing decision, and the only place
# the config gate is evaluated. See the header for the token contract.
cmd_mode() {
  local passed=""
  while (( $# )); do
    case "$1" in
      --place-token) passed="${2-}"; shift 2 || break ;;
      *) echo "place.sh mode: unknown option '$1'" >&2; return 2 ;;
    esac
  done
  local dest
  dest="$(place_destination)" || return 2
  if [[ "$dest" == "branch" ]]; then
    printf 'direct\n'
    return 0
  fi
  local env_tok="${JIM_PLACE_TOKEN:-}"
  if [[ -n "$passed" && -n "$env_tok" && "$passed" == "$env_tok" ]]; then
    printf 'direct\n'
    return 0
  fi
  if [[ -n "$env_tok" ]]; then
    echo "place.sh: ignoring JIM_PLACE_TOKEN — it does not match this invocation's" \
         "run token; issue placement stays active" >&2
  fi
  printf 'route\n'
}

# cmd_run [--read] --verb <enum> [--id <slug>] -- CMD [ARGS...]
#   Run the wrapped command against the collection. Under the default placement
#   this is transparent: `{}` resolves to the configured issues directory and the
#   command is exec'd, so its exit status is the caller's and no git work
#   happens at all — the script is usable outside a repository.
cmd_run() {
  local verb="" id="" read_only=0
  while (( $# )); do
    case "$1" in
      --read) read_only=1; shift ;;
      --verb) verb="${2-}"; shift 2 || break ;;
      --id)   id="${2-}";   shift 2 || break ;;
      --)     shift; break ;;
      *) echo "place.sh run: unknown option '$1'" >&2; return 2 ;;
    esac
  done
  place_valid_verb "$verb" || return 2
  if [[ -n "$id" ]] && ! bash "$JIMFILE" valid-id "$id" >/dev/null 2>&1; then
    echo "place.sh run: --id is not a valid issue id" >&2
    return 2
  fi
  if (( $# == 0 )); then
    echo "place.sh run: no command given after --" >&2
    return 2
  fi
  local dest
  dest="$(place_destination)" || return 2
  if [[ "$dest" == "branch" ]]; then
    # Passthrough: no git choreography at all, and the wrapped command's own
    # exit status is the caller's. A read-only run publishes nothing either
    # way, so the flag selects the same behavior here as a write.
    local dir
    dir="$(place_issues_dir)" || return 2
    place_substitute "$dir" "" "$@"
    exec "${PLACE_CMD[@]}"
  fi
  local prefix
  prefix="$(place_prefix)" || return 2
  place_open_work || return 1
  local tip
  tip="$(git rev-parse --verify --quiet --end-of-options "refs/heads/$dest" 2>/dev/null || true)"
  place_materialize "$tip" "$prefix" "$PLACE_COLL" || return $?
  local -A before=() after=()
  place_snapshot "$PLACE_COLL" before || return 1
  place_substitute "$PLACE_COLL" "$PLACE_TOKEN" "$@"
  local rc=0
  JIM_PLACE_TOKEN="$PLACE_TOKEN" "${PLACE_CMD[@]}" || rc=$?
  (( rc == 0 )) || return "$rc"
  (( read_only == 0 )) || return 0
  place_snapshot "$PLACE_COLL" after || return 1
  place_commit_changes "$dest" "$tip" "$prefix" before after "$verb" "$id"
}

# place_commit_changes <branch> <tip> <prefix> <before> <after> <verb> <id>
#   Publish the changed set, or report honestly that there was nothing to
#   publish. A mutation that changed nothing leaves no empty commit behind.
place_commit_changes() {
  local dest="$1" tip="$2" prefix="$3" verb="$6" id="$7"
  local -n _pc_before="$4"
  local -n _pc_after="$5"
  local name changed=0
  for name in "${!_pc_after[@]}"; do
    [[ "${_pc_before[$name]:-}" == "${_pc_after[$name]}" ]] || { changed=1; break; }
  done
  if (( changed == 0 )); then
    for name in "${!_pc_before[@]}"; do
      [[ -n "${_pc_after[$name]:-}" ]] || { changed=1; break; }
    done
  fi
  (( changed )) || return 0
  local commit rc=0
  commit="$(place_publish "$dest" "$tip" "$prefix" "$4" "$5" "$(place_message "$verb" "$id")")" || rc=$?
  if (( rc != 0 )); then
    if (( rc == 3 )); then
      echo "place.sh: '$dest' moved while this mutation was being prepared;" \
           "re-run to apply it to the current state" >&2
    fi
    return "$rc"
  fi
  local bref
  if bref="$(place_bookmark_ref "$dest")"; then
    git update-ref "$bref" "$commit" 2>/dev/null || true
  fi
  return 0
}

usage() {
  cat <<'USAGE'
Usage:
  place.sh mode [--place-token <tok>]        print `direct` or `route`
  place.sh run [--read] --verb <enum> [--id <slug>] -- CMD [ARGS...]

  verbs: file edit close rename realize reindex backfill migrate
  `{}` in ARGS becomes the collection directory, `{token}` the run token.
USAGE
}

main() {
  local subcmd="${1:-}"
  if [[ -z "$subcmd" ]]; then
    usage >&2
    return 2
  fi
  shift
  case "$subcmd" in
    mode) cmd_mode "$@" ;;
    run)  cmd_run  "$@" ;;
    help|--help|-h) usage; return 0 ;;
    *)
      echo "place.sh: unknown subcommand '$subcmd'" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
