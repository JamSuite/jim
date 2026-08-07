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
  local verb="" id=""
  while (( $# )); do
    case "$1" in
      # A read-only run publishes nothing either way, so under the default
      # placement the flag selects the same behavior as a write.
      --read) shift ;;
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
    local dir
    dir="$(place_issues_dir)" || return 2
    place_substitute "$dir" "" "$@"
    exec "${PLACE_CMD[@]}"
  fi
  echo "place.sh run: the placement engine is not available in this build" >&2
  return 1
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
