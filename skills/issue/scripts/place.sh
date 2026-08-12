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
#   directory, and the result is committed by writing each entry with
#   hash-object, assembling the tree through a scratch index (update-index into
#   a private GIT_INDEX_FILE, then write-tree) and sealing it with commit-tree —
#   then landed with a ref compare-and-swap. A scratch index rather than mktree
#   because the destination tree has to keep every path outside the collection
#   exactly as the tip holds it, which is read-tree's job. The developer's working
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
#   bash place.sh run [--read] [--verb <enum>] [--id <slug>] -- CMD [ARGS...]
#     Run CMD against the collection. --verb is required for a write and
#     optional on a --read run, which publishes nothing and so composes no
#     commit subject. An ARG that is exactly `{}` becomes the
#     collection directory and one that is exactly `{token}` becomes this run's
#     token — but only where a caller building an invocation puts a placeholder:
#     as the operand of `--dir` / `--place-token`, or as the trailing argument.
#     Every other argument is forwarded untouched, because ARGS carry free-form
#     user text that can look exactly like a placeholder. --read discards the
#     result instead of publishing it.
#
#   bash place.sh begin [--read]
#     Materialize the collection and print `<token>\t<dir>` for a mutation with
#     no single command to wrap — the agent edits in <dir> and publishes with
#     `commit`. The two-phase door; `run` is the one-shot one.
#   bash place.sh commit <token> --verb <enum> [--id <slug>]
#     Publish a handle's edits through the same engine `run` uses.
#   bash place.sh abort <token>
#     Discard a handle, publishing nothing.
#
#   verb enum: file | edit | close | rename | realize | reindex | backfill |
#   migrate. Commit subjects are composed from the enum plus an optional
#   validated id, so no free text ever reaches a commit message.
#
# EXIT CODES
#   0  Success (stderr may carry degradation notes).
#   1  IO or engine failure, or a read served from an index that could not be
#      regenerated. A write refuses on that failure instead, since the stale
#      index would be what reaches the destination.
#   2  Config or validation refusal (junk branch name, coordination branch,
#      unknown verb, malformed invocation).
#   3  Concurrent-conflict refusal.
#
#   In passthrough the wrapped command's own status is forwarded verbatim, so a
#   caller sees the emitter's failure rather than a placement-flavored one.
#
# Parses with grep, sed, awk, tr and `read` only; never sources or evals config
# or issue content.
#
# PORTABILITY
#   This script raises the corpus's bash floor from 4.0 to **4.3**: it is the
#   first to use namerefs (`local -n`), which 4.2 does not have. It also uses
#   `grep -m1`, `find -mindepth` and `find -print0` — GNU and BSD both, so the
#   floor that moves is bash's, not coreutils'. The prior floor was already
#   above stock macOS bash 3.2 by way of associative arrays, so the marginal
#   cost is a Homebrew bash either way.

set -uo pipefail
export LC_ALL=C
# Placement touches the network on the developer's behalf, never at their
# prompt: an unreachable or credential-hungry remote must degrade loudly rather
# than stall a filing behind an invisible password prompt.
export GIT_TERMINAL_PROMPT=0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"
INDEX_SCRIPT="$HERE/index.sh"

readonly PLACE_VERBS=(file edit close rename realize reindex backfill migrate)
readonly PLACE_INDEX_FILE="INDEX.md"

# Built by place_substitute; the wrapped command with its placeholders resolved.
PLACE_CMD=()

# ─── Section: Config resolution ──────────────────────────────────────────────

# place_conf <key> — resolve one jimconf key from the primary checkout.
#   The resolver's own status is forwarded rather than discarded: a broken or
#   unreachable jimconf otherwise yields an empty value indistinguishable from
#   an unset key, and every caller here reads an unset key as a default. On the
#   placement key that default is `branch`, so an infrastructure failure would
#   silently stop centralizing and land the write on the working branch — the
#   fallback the gate below promises never happens.
place_conf() { bash "$JIMCONF" get "$1" 2>/dev/null; }

# place_issues_dir — the configured collection directory, trailing slash
# stripped. Used as the `{}` substitution when placement is not centralizing.
place_issues_dir() {
  local dir
  if ! dir="$(place_conf issues)"; then
    echo "place.sh: could not resolve the issues directory from configuration" >&2
    return 2
  fi
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
#
# SYNC(valid-branch): byte-identical to alloc_valid_branch in
# skills/file/scripts/jimalloc.sh. Duplicated rather than extracted because the
# two scripts share no library and neither should import the other; a
# byte-agreement fixture in tests/place.sh fails if they drift.
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
  # No local default: jimconf owns the default for this key, and a second copy
  # here would make changing it a multi-file edit. An empty result therefore
  # means the resolver failed, which is a refusal like any other unusable value.
  if ! b="$(place_conf id_coordination_branch)" || [[ -z "$b" ]]; then
    echo "place.sh: could not resolve id_coordination_branch, so the" \
         "coordination-branch guard cannot be established" >&2
    return 1
  fi
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
  # A failed resolve is not an unset key. Defaulting to `branch` on it would
  # answer "do not centralize" to a question that was never actually asked, and
  # the write would land on the working branch — the one outcome a project that
  # configured a destination is relying on this gate to prevent.
  if ! v="$(place_conf issue_placement)"; then
    echo "place.sh: could not resolve issue_placement from configuration, so" \
         "where this mutation belongs is unknown" >&2
    return 2
  fi
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
# command, replacing the placeholders the caller put there: `{}` with <dir> and
# `{token}` with <token>.
#
# A placeholder is recognized by position as well as value, because value alone
# cannot tell a marker from user text that looks like one. Substitution is
# whole-argument, so a directory containing spaces stays one word and an
# argument that merely *contains* braces is left alone — `interface{}` is
# ordinary in a developer-tool issue title. But an argument that *is* exactly
# `{}` can be user text too: the emitter re-execs carrying its own caller's
# entire argv, so `--title '{}'` arrives as a bare `{}` in a marker's shape.
# Rewriting it puts this run's temp path into the title and from there into the
# slug — the durable id an append-only registry has already recorded, which no
# later run can reclaim.
#
# So a marker counts only where a caller building an invocation puts one: as the
# operand of the flag that names it, or as the trailing argument appended after
# everything being forwarded. Every entry script uses one of those two shapes,
# and neither is reachable by text travelling through the middle of an argv.
place_substitute() {
  local dir="$1" token="$2"; shift 2
  local -a args=( "$@" )
  local n=${#args[@]} i prev
  PLACE_CMD=()
  for (( i = 0; i < n; i++ )); do
    prev=""
    (( i > 0 )) && prev="${args[i-1]}"
    case "${args[i]}" in
      '{}')
        if [[ "$prev" == "--dir" ]] || (( i == n - 1 )); then
          PLACE_CMD+=( "$dir" ); continue
        fi ;;
      '{token}')
        if [[ "$prev" == "--place-token" ]] || (( i == n - 1 )); then
          PLACE_CMD+=( "$token" ); continue
        fi ;;
    esac
    PLACE_CMD+=( "${args[i]}" )
  done
}

# ─── Section: Engine ─────────────────────────────────────────────────────────

PLACE_WORK=""    # this run's temp root, removed by the cleanup trap
PLACE_COLL=""    # the materialized collection inside it — the `{}` substitution
PLACE_GIT_INDEX=""   # scratch git index used to build the destination tree
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
  PLACE_GIT_INDEX="$PLACE_WORK/index"
  PLACE_TOKEN="${PLACE_WORK##*/}"
  mkdir -p -- "$PLACE_COLL"
}

# place_prefix — the collection's path inside the destination branch's tree.
# It mirrors the project's configured layout so a checkout of that branch is
# self-describing rather than a black box.
place_prefix() {
  local dir
  dir="$(place_issues_dir)" || return 2
  # Strip every leading `./`, not one: `././docs/issues` otherwise keeps a dot
  # segment that reads fine on this side and fails opaquely when git is asked to
  # build a tree from it.
  while [[ "$dir" == ./* ]]; do dir="${dir#./}"; done
  dir="${dir%/}"
  # A dot segment anywhere means the configured path does not name a directory
  # inside the tree — `.` names the repository root, which would make the whole
  # checkout the collection. It fails closed further down either way, but on a
  # message about entry names rather than about the setting that caused it.
  case "$dir" in
    .|..|*/.|*/..|./*|../*|*/./*|*/../*)
      echo "place.sh: the configured issues directory '$(place_shown "$dir")'" \
           "contains a '.' or '..' segment, so it does not name a directory" \
           "inside the destination branch's tree" >&2
      return 2 ;;
  esac
  if ! bash "$JIMFILE" valid-relpath "$dir" >/dev/null 2>&1; then
    echo "place.sh: the configured issues directory is not a safe repo-relative" \
         "path, so it cannot be mirrored onto a destination branch" >&2
    return 2
  fi
  case "$dir" in -*) echo "place.sh: the configured issues directory may not begin with '-'" >&2; return 2 ;; esac
  printf '%s\n' "$dir"
}

# place_shown <text> — <text> made safe to print, for messages that quote a name
# taken from branch content or configuration. The name is data: a terminal is
# not obliged to interpret whatever escape sequence it carries, and a message is
# not obliged to carry a whole file's worth of it. Same shape as the display
# sanitizer the ledger, spec-reconcile and partition scripts use — control
# characters out, length capped — so one class of name is not printable in four
# ways depending on which script met it.
place_shown() { printf '%s' "$1" | tr -d '\000-\037\177' | cut -c1-512; }

# place_bookmark_ref <branch> — the local ref recording the last destination tip
# this clone acted on. It lives outside refs/heads so it is never pushed,
# fetched, or mistaken for a branch.
place_bookmark_ref() {
  local ref="refs/jim/issue-placement/$1"
  git check-ref-format "$ref" >/dev/null 2>&1 || return 1
  printf '%s\n' "$ref"
}

# ─── Section: Remote tier ────────────────────────────────────────────────────

readonly PLACE_ATTEMPTS=5

# place_remote — a usable remote for the destination branch: origin when it
# exists, otherwise the first configured one. Empty output selects the local
# tier, where the ref update is the compare-and-swap.
place_remote() {
  local r
  if git remote 2>/dev/null | grep -qx origin; then
    r=origin
  else
    r="$(git remote 2>/dev/null | head -n1)"
  fi
  [[ -n "$r" ]] && printf '%s\n' "$r"
  return 0
}

# place_valid_sha <text> — exit 0 iff <text> is a plain object name. Whatever a
# remote advertises is remote-supplied text that later becomes a commit parent
# and a compare-and-swap old-value, so it crosses this boundary on arrival.
place_valid_sha() { [[ "${1:-}" =~ ^[0-9a-f]{40,64}$ ]]; }

# place_backoff <attempt> — a short, rising, jittered pause between attempts so
# racing sessions de-synchronize instead of colliding in lockstep.
place_backoff() {
  local ms=$(( $1 * 40 + RANDOM % 50 ))
  sleep "0.$(printf '%03d' "$ms")" 2>/dev/null || true
}

# place_remote_tip <remote> <branch>
#   The destination branch's tip on <remote>, with its objects fetched locally
#   so a commit can be built atop it. Empty output means the branch does not
#   exist there yet. rc 1 means the remote could not be reached — the caller
#   degrades rather than failing, but it must know the difference.
place_remote_tip() {
  local remote="$1" branch="$2" line tip
  if ! line="$(git ls-remote --heads --end-of-options "$remote" "$branch" 2>/dev/null)"; then
    return 1
  fi
  tip="$(printf '%s' "$line" | awk 'NR==1{print $1}')"
  if [[ -n "$tip" ]]; then
    if ! place_valid_sha "$tip"; then
      echo "place.sh: remote '$remote' advertised an unusable tip for '$branch'" >&2
      return 1
    fi
    git fetch --quiet --end-of-options "$remote" "$branch" 2>/dev/null || return 1
  fi
  printf '%s\n' "$tip"
}

# place_head_tip <branch> — this clone's own copy of the destination branch.
# It is the compare-and-swap old value for every local update of that ref, and
# an empty one is a value too: it requires the ref to still be absent, which is
# what makes the orphan bootstrap a compare-and-swap rather than a blind create.
place_head_tip() {
  git rev-parse --verify --quiet --end-of-options "refs/heads/$1" 2>/dev/null || true
}

# place_local_tip <branch> — the freshest destination state this clone can reach
# without the network.
#
# Two refs know something about it, and they are advanced by different events:
# `refs/heads/<branch>` moves only when a publish reaches the destination, while
# the bookmark moves on every run that reached the destination's owner, read or
# write. So neither is reliably the fresher, and preferring one outright is
# wrong in one direction or the other.
#
#   - A clone that has only ever read the collection has no local head at all:
#     `git clone` creates none for the destination, and a fetch writes
#     FETCH_HEAD and the remote-tracking ref rather than that head. Without the
#     bookmark an unreachable remote would serve an empty collection while
#     announcing the last-seen state, and a write would build on nothing.
#   - A clone that published once and later read online while a teammate
#     published has a head *behind* its bookmark. Preferring the head there
#     serves strictly less than the clone last saw, under a message saying
#     otherwise.
#
# Whichever descends from the other is the newer, and is taken. When they are
# unrelated the head wins: it carries this clone's own unpublished commits, and
# only the origin tier has the machinery to reconcile the two sides.
place_local_tip() {
  local branch="$1" head="" bref="" seen=""
  head="$(place_head_tip "$branch")"
  if bref="$(place_bookmark_ref "$branch")"; then
    seen="$(git rev-parse --verify --quiet --end-of-options "$bref" 2>/dev/null || true)"
  fi
  if [[ -z "$head" ]]; then
    [[ -n "$seen" ]] && printf '%s\n' "$seen"
    return 0
  fi
  if [[ -n "$seen" && "$seen" != "$head" ]] \
     && git merge-base --is-ancestor --end-of-options "$head" "$seen" 2>/dev/null; then
    printf '%s\n' "$seen"
    return 0
  fi
  printf '%s\n' "$head"
  return 0
}

# ─── Section: Unpublished local state ────────────────────────────────────────

# Set together by place_resolve_tips. A mutation is prepared against three
# commits, which are the same one in the ordinary case:
PLACE_ONTO_TIP=""    # what the new commit is built on, and swapped against
PLACE_WORK_TIP=""    # what the wrapped command or the agent sees
PLACE_BASE_TIP=""    # what the changed set is measured from
PLACE_TIP_STATE=""   # current | ahead | diverged

# place_merge_base <work-tip> <onto-tip>
#   The commit a mutation's changed set is measured from when it is applied onto
#   <onto-tip>: the two sides' common ancestor.
#
#   Measuring from <onto-tip> would read a teammate's own commit as a file this
#   mutation deleted. Measuring from <work-tip> would read this clone's own
#   unpublished commits as part of the destination's state rather than as
#   changes still to be carried, so a run that stopped building on them would
#   drop them with nothing in the changed set to replay.
#
#   Empty output — no common ancestor, or no destination yet — reads every local
#   file as this mutation's own: a union rather than a deletion of the other
#   side.
place_merge_base() {
  local work="${1:-}" onto="${2:-}"
  [[ -n "$work" && -n "$onto" ]] || return 0
  if [[ "$work" == "$onto" ]]; then
    printf '%s\n' "$work"
    return 0
  fi
  git merge-base --end-of-options "$work" "$onto" 2>/dev/null || true
}

# place_resolve_tips <dest> <tier> <tip>
#   Work out those three commits for a run that reached the destination's owner.
#
#   They diverge only when this clone is carrying destination commits the remote
#   has never seen: a mutation made while the remote was unreachable, whose
#   publication was deferred to the next reachable run. This is that run, and
#   nothing else will do it — every push sends a commit built on the remote's own
#   tip, so a deferred commit not picked up here is what the local ref update
#   afterwards discards.
#
#   `ahead` — the unpublished commits fast-forward from the remote's tip, so they
#   are simply what this mutation builds on and the push carries them along with
#   their own subjects intact.
#
#   `diverged` — the destination moved too, so there is nothing to fast-forward.
#   The commit is built on the remote's tip and the unpublished content travels
#   inside this run's changed set instead. That set has to be measured from the
#   two sides' common ancestor: measuring it from the remote's tip would read the
#   teammate's own commit as a file this mutation deleted.
place_resolve_tips() {
  local dest="$1" tier="$2" tip="$3" head
  PLACE_ONTO_TIP="$tip"
  PLACE_WORK_TIP="$tip"
  PLACE_BASE_TIP="$tip"
  PLACE_TIP_STATE="current"
  [[ "$tier" == "origin" ]] || return 0
  head="$(place_head_tip "$dest")"
  [[ -n "$head" && "$head" != "$tip" ]] || return 0
  # Contained in what the remote already has: the remote is simply ahead.
  if [[ -n "$tip" ]] && git merge-base --is-ancestor --end-of-options "$head" "$tip" 2>/dev/null; then
    return 0
  fi
  if [[ -z "$tip" ]] || git merge-base --is-ancestor --end-of-options "$tip" "$head" 2>/dev/null; then
    PLACE_ONTO_TIP="$head"
    PLACE_WORK_TIP="$head"
    PLACE_BASE_TIP="$head"
    PLACE_TIP_STATE="ahead"
    return 0
  fi
  PLACE_WORK_TIP="$head"
  PLACE_BASE_TIP="$(place_merge_base "$head" "$tip")"
  PLACE_TIP_STATE="diverged"
  return 0
}

# place_disclose_unpublished <dest> — say what is becoming of mutations an
# earlier run left unpublished. Silent when there are none, which is the norm.
place_disclose_unpublished() {
  case "$PLACE_TIP_STATE" in
    ahead)
      echo "place.sh: publishing mutations on '$1' that an earlier run left" \
           "unpublished" >&2 ;;
    diverged)
      echo "place.sh: '$1' moved on while this clone held unpublished mutations;" \
           "they are being reapplied on top of it" >&2 ;;
  esac
  return 0
}

# place_disclose_partial_view <dest> — the read-side counterpart: say what this
# view is *not* showing.
#
#   A diverged read is served from this clone's own unpublished tip, because
#   that is the only tree carrying its outstanding mutations — so it omits
#   everything the destination gained since the two sides forked. The run knows
#   this, having just fetched it.
#
#   It discloses rather than merging. Merging would mean building a union tree
#   on a path that publishes nothing, and presenting the reader a state that
#   exists at neither side as though it were the collection. This engine grafts
#   only as part of a publish, where the result is something a reader can go and
#   look at; the next write does exactly that, which is what closes the gap.
place_disclose_partial_view() {
  case "$PLACE_TIP_STATE" in
    diverged)
      echo "place.sh: this clone holds mutations to '$1' that were never" \
           "published, and '$1' has moved on since — so this view is served from" \
           "the unpublished side and omits what the destination gained. The next" \
           "write reapplies them on top and reconciles the two." >&2 ;;
  esac
  return 0
}

# place_base_snapshot <tip> <prefix> <scratch-dir> <assoc-array-name>
#   Snapshot the collection at <tip> without handing it to anybody: it is the
#   state the changed set is measured from, not the state being worked on. Only
#   the diverged case needs the two to differ.
place_base_snapshot() {
  local tip="$1" prefix="$2" dir="$3" rc=0
  rm -rf -- "$dir" || return 1
  mkdir -p -- "$dir" || return 1
  place_materialize "$tip" "$prefix" "$dir"
  rc=$?
  if (( rc != 0 )); then
    rm -rf -- "$dir"
    return "$rc"
  fi
  place_snapshot "$dir" "$4" || { rm -rf -- "$dir"; return 1; }
  rm -rf -- "$dir"
  return 0
}

# ─── Section: Direct mode ────────────────────────────────────────────────────

# place_new_token — a unique token for a run that has no temp directory to take
# its name from. mktemp -u only proposes a name; nothing is created, which is
# all this needs, since the token is only ever compared against the copy this
# same process passes to the command it runs.
place_new_token() {
  local t
  t="$(mktemp -u 2>/dev/null)" || return 1
  printf '%s\n' "${t##*/}"
}

# place_dirty_guard <prefix>
#   Refuse when the collection already carries uncommitted changes. Direct mode
#   commits by path, so a developer's half-finished manual edit inside the
#   collection would otherwise be swept into the mutation's commit and published
#   — a decision that is theirs, not this script's.
#
#   Paths reach git literally: a shape-valid path does not neutralize pathspec
#   magic, so a configured collection path is never interpreted as a pattern.
#
#   A guard that could not run has not passed. `status` reports a dirty
#   collection on stdout, so testing output alone reads every failure — a
#   corrupt index, a pathspec git refuses, a permissions error — as a clean
#   collection, and waves through exactly the states this exists to stop.
place_dirty_guard() {
  local prefix="$1" st rc
  st="$(git --literal-pathspecs status --porcelain -- "$prefix" 2>/dev/null)"
  rc=$?
  if (( rc != 0 )); then
    echo "place.sh: cannot tell whether the collection at '$prefix' has" \
         "uncommitted changes — git reported an error instead of a listing, so" \
         "this mutation is refused rather than published over work that may be" \
         "sitting there" >&2
    return 2
  fi
  [[ -n "$st" ]] || return 0
  echo "place.sh: the collection at '$prefix' has uncommitted changes; commit or" \
       "stash them first so this mutation does not publish them:" >&2
  printf '%s\n' "$st" >&2
  return 2
}

# place_direct <dest> <prefix> <verb> <id> <read-only> <cmd>...
#   Run the mutation against the working tree, because the destination is the
#   branch that is checked out. Moving the ref by plumbing here would leave the
#   index and working tree behind, so the collection would read as deleted; the
#   mutation is staged and committed by path instead.
#
#   A rejected push is disclosed rather than resolved. Rebasing a developer's
#   own checkout underneath them to publish an issue is far more invasive than
#   the problem warrants, and the local commit already means nothing is lost.
# place_worktree_contained <prefix>
#   Refuse a collection path that resolves outside the worktree. `place_prefix`
#   gates the path's *shape*, which is exactly the gate the staging precedent
#   describes as needing a second one: a shape-valid path can still symlink out
#   of the tree, and after that only git's own pathspec refusal stands between
#   the config and an arbitrary staging target.
#
#   It runs before the wrapped command as well as before staging, so a refused
#   run writes nothing anywhere — the discipline materialization already keeps.
place_worktree_contained() {
  local prefix="$1" top resolved
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "place.sh: not inside a git worktree" >&2
    return 2
  fi
  if ! resolved="$(realpath -m -- "$prefix" 2>/dev/null)" \
     || [[ "$resolved" != "$top"/* ]]; then
    echo "place.sh: the collection at '$prefix' resolves outside the worktree," \
         "so it will not be written or staged" >&2
    return 2
  fi
  return 0
}

place_direct() {
  local dest="$1" prefix="$2" verb="$3" id="$4" read_only="$5"; shift 5
  place_worktree_contained "$prefix" || return 2
  # The destination is checked out, so its tip is HEAD and no fetch is needed to
  # know it: a rebase, reset or amend of the branch the collection lives on is a
  # rewrite of the destination, and this arm is where a read verb meets it.
  place_disclose_rewrite "$dest" "$(place_head_commit)"
  if (( read_only == 0 )); then
    place_dirty_guard "$prefix" || return 2
  fi
  PLACE_TOKEN="$(place_new_token)" || return 1
  place_substitute "$prefix" "$PLACE_TOKEN" "$@"
  local rc=0
  JIM_PLACE_TOKEN="$PLACE_TOKEN" JIM_PLACE_PREFIX="$prefix" "${PLACE_CMD[@]}" || rc=$?
  (( rc == 0 )) || return "$rc"
  (( read_only == 0 )) || return 0
  place_direct_publish "$dest" "$prefix" "$verb" "$id"
}

# place_direct_publish <dest> <prefix> <verb> <id>
#   Stage and commit the collection in the working tree, then publish. Shared by
#   the wrapped-command path and the two-phase one, which differ only in how the
#   edits got there.
place_direct_publish() {
  local dest="$1" prefix="$2" verb="$3" id="$4"
  place_worktree_contained "$prefix" || return 2
  place_reindex "$prefix" || return 1
  local st
  st="$(git --literal-pathspecs status --porcelain -- "$prefix" 2>/dev/null)"
  [[ -n "$st" ]] || return 0
  git --literal-pathspecs add -- "$prefix" || return 1
  git --literal-pathspecs commit -q -m "$(place_message "$verb" "$id")" -- "$prefix" || return 1
  local commit remote
  commit="$(git rev-parse --verify --quiet HEAD 2>/dev/null || true)"
  remote="$(place_remote)"
  # The bookmark records what the destination was seen holding, so it follows a
  # publish that reached it — not one that was merely attempted. With no remote
  # configured the local branch *is* the destination, and committing to it is
  # reaching it.
  if [[ -z "$remote" ]]; then
    place_advance_bookmark "$dest" "$commit"
    return 0
  fi
  if git push --quiet --end-of-options "$remote" "HEAD:refs/heads/$dest" 2>/dev/null; then
    place_advance_bookmark "$dest" "$commit"
    return 0
  fi
  echo "place.sh: '$dest' has diverged from '$remote', so the mutation is" \
       "committed here but not published. Pull and push again to share it —" \
       "your checkout is left exactly as it is." >&2
  return 0
}

# ─── Section: Two-phase handles ──────────────────────────────────────────────
#
# Some mutations have no single command to wrap — "close issue #5" is the agent
# editing a file it just read. Those get the same placement door in two steps:
# `begin` materializes the destination and hands back a directory, the edits
# happen there, and `commit` publishes them through the same engine.
#
# A handle outlives its process, so unlike a wrapped run its state cannot sit in
# shell variables or a directory only that process can find. It lives under the
# git dir: local to the clone, on no branch, never fetched or pushed, and
# findable by the token `begin` printed. A crash between the two steps strands
# one directory there, which `commit` reports and `abort` removes.

readonly PLACE_TOKEN_NONE="none"     # no placement — the real collection dir
# A read handle publishes nothing and so needs no state: the flag is the token.
# It stays a literal in direct mode for that reason, and `commit` refuses it.
readonly PLACE_TOKEN_DIRECT_READ="direct-read"
# A *write* handle in direct mode is a real handle like any other. It was once a
# fixed literal, which meant `commit` could be called having no evidence that
# `begin` ever ran — and the dirty guard `begin` runs cannot be re-run at commit
# time, because by then the mutation's own edits are the dirty state. An
# unguessable token created only by `begin` is that evidence. What the handle
# carries is state alone; the directory it hands back is the working tree's own
# collection, since in direct mode that is where the edits belong.
readonly PLACE_TOKEN_DIRECT="direct"

# place_handle_root — the directory holding this clone's live handles, verified
# to resolve inside the git dir so a symlinked path cannot redirect the writes.
# Absolute: git reports a relative git dir from the project root, and a handle
# path is handed to a caller who will use it from wherever they happen to be.
# SYNC(write-contained): the containment check below is the same rule as
# alloc_write_contained in skills/file/scripts/jimalloc.sh — resolve both sides
# with realpath and require the target to sit under the permitted root — with
# one deliberate difference: this one permits a single fixed subdirectory of the
# git dir rather than an arbitrary caller-supplied path, so it is the tighter of
# the two. Kept separate for that reason; they are not interchangeable.
place_handle_root() {
  local gd gd_real root_real
  gd="$(git rev-parse --git-dir 2>/dev/null)" || {
    echo "place.sh: not inside a git repository" >&2
    return 1
  }
  gd_real="$(realpath -m -- "$gd" 2>/dev/null)" || return 1
  root_real="$(realpath -m -- "$gd/jim-place" 2>/dev/null)" || return 1
  if [[ "$root_real" != "$gd_real"/* ]]; then
    echo "place.sh: refusing to write placement handles outside the git dir" >&2
    return 1
  fi
  mkdir -p -- "$root_real" || return 1
  printf '%s\n' "$root_real"
}

# place_handle_dir <token> — the live handle's directory. The token is caller
# input that composes a path, so it is charset-gated to a plain name first: no
# separators, no leading dash, nothing that could climb out of the root.
place_handle_dir() {
  local tok="${1:-}" root dir
  # The token composes a filesystem path, so it clears the same boundary every
  # other identifier in the corpus clears rather than a charset spelled out here
  # — which was this one's charset minus its length cap and its '..' rejection.
  # Every token this script mints passes it unchanged.
  if ! bash "$JIMFILE" valid-id "$tok" >/dev/null 2>&1; then
    echo "place.sh: malformed handle token" >&2
    return 2
  fi
  root="$(place_handle_root)" || return 1
  dir="$root/$tok"
  if [[ ! -d "$dir" ]]; then
    echo "place.sh: no live placement handle '$tok' — it was aborted, already" \
         "committed, or never created" >&2
    return 2
  fi
  printf '%s\n' "$dir"
}

# place_state_get <file> <key> — one recorded value. Read with grep/sed; the
# file is never sourced, because sourcing state is executing it.
place_state_get() {
  grep -m1 "^$2=" "$1" 2>/dev/null | sed "s/^$2=//"
}

# place_save_snapshot <array-name> <file> / place_load_snapshot <file> <array-name>
#   Persist the base snapshot across the two steps. Tab-separated so a name with
#   spaces survives the round trip.
place_save_snapshot() {
  local -n _sv_snap="$1"
  local name
  : > "$2" || return 1
  for name in "${!_sv_snap[@]}"; do
    printf '%s\t%s\n' "${_sv_snap[$name]}" "$name" >> "$2" || return 1
  done
  return 0
}

place_load_snapshot() {
  local -n _ld_snap="$2"
  _ld_snap=()
  local line sha name
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    sha="${line%%$'\t'*}"
    name="${line#*$'\t'}"
    _ld_snap["$name"]="$sha"
  done < "$1"
  return 0
}

# place_head_commit — the checked-out commit. In direct mode the destination
# branch *is* HEAD, so this is the destination's own tip: what rewrite detection
# compares the bookmark against, with no fetch to make and nothing to guess.
place_head_commit() {
  git rev-parse --verify --quiet --end-of-options HEAD 2>/dev/null || true
}

# place_direct_handle <dest> <prefix>
#   Open a write handle for a destination that is already checked out, and print
#   "<token>\t<prefix>". The handle carries state only — the directory handed
#   back is the working tree's own collection, because that is where a direct
#   mutation's edits belong.
#
#   What it records is what `commit` has to prove again and cannot otherwise
#   know: the destination, and the collection path this handle was opened
#   against. Re-resolving the path at commit time instead publishes wherever the
#   configuration now points, which for a changed `issues` key is a fresh empty
#   collection while the agent's real edits stay uncommitted.
place_direct_handle() {
  local dest="$1" prefix="$2" root handle
  root="$(place_handle_root)" || return 1
  handle="$(mktemp -d "$root/handle.XXXXXXXX" 2>/dev/null)" || {
    echo "place.sh: could not create a placement handle" >&2
    return 1
  }
  {
    printf 'mode=direct\n'
    printf 'dest=%s\n'   "$dest"
    printf 'prefix=%s\n' "$prefix"
    printf 'read=0\n'
  } > "$handle/state" || { rm -rf -- "$handle"; return 1; }
  printf '%s\t%s\n' "${handle##*/}" "$prefix"
}

# cmd_begin [--read] — materialize the destination and print "<token>\t<dir>".
cmd_begin() {
  local read_only=0
  while (( $# )); do
    case "$1" in
      --read) read_only=1; shift ;;
      *) echo "place.sh begin: unknown option '$1'" >&2; return 2 ;;
    esac
  done
  local dest
  dest="$(place_destination)" || return 2
  if [[ "$dest" == "branch" ]]; then
    local dir
    dir="$(place_issues_dir)" || return 2
    printf '%s\t%s\n' "$PLACE_TOKEN_NONE" "$dir"
    return 0
  fi
  local prefix
  prefix="$(place_prefix)" || return 2
  local current
  current="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -n "$current" && "$current" == "$dest" ]]; then
    # Ahead of everything, as on the wrapped-command arm. There is no wrapped
    # command here — the agent is the writer — so a directory handed back is
    # already the write, and a refusal that arrives at `commit` arrives after
    # it. Shape validation does not resolve symlinks, and the dirty guard below
    # is a `git status` on the same path, which answers nothing about where it
    # leads.
    place_worktree_contained "$prefix" || return 2
    place_disclose_rewrite "$dest" "$(place_head_commit)"
    if (( read_only )); then
      printf '%s\t%s\n' "$PLACE_TOKEN_DIRECT_READ" "$prefix"
      return 0
    fi
    # The edits land in the working tree, so the guard has to run before them,
    # not at commit time when they are indistinguishable from the mutation.
    place_dirty_guard "$prefix" || return 2
    place_direct_handle "$dest" "$prefix"
    return $?
  fi
  local root handle
  root="$(place_handle_root)" || return 1
  handle="$(mktemp -d "$root/handle.XXXXXXXX" 2>/dev/null)" || {
    echo "place.sh: could not create a placement handle" >&2
    return 1
  }
  local remote tier tip ref_old unreachable=0
  remote="$(place_remote)"
  ref_old="$(place_head_tip "$dest")"
  if [[ -n "$remote" ]] && tip="$(place_remote_tip "$remote" "$dest")"; then
    tier="origin"
  else
    tier="local"
    tip="$(place_local_tip "$dest")"
    [[ -n "$remote" ]] && unreachable=1
  fi
  if (( unreachable )); then
    echo "place.sh: remote '$remote' is unreachable; working from the last-seen" \
         "state of '$dest'" >&2
  fi
  place_check_rewrite "$dest" "$tip" "$(( unreachable == 0 ? 1 : 0 ))"
  place_resolve_tips "$dest" "$tier" "$tip"
  tip="$PLACE_ONTO_TIP"
  if (( read_only )); then
    place_disclose_partial_view "$dest"
  else
    place_disclose_unpublished "$dest"
  fi
  mkdir -p -- "$handle/collection" || { rm -rf -- "$handle"; return 1; }
  # Every refusal below reaches the caller with the status it was refused with.
  # `begin`'s whole contract is the "<token><TAB><dir>" it prints, so a refusal
  # reported as success hands back an empty dir that resolves to wherever the
  # caller happens to be standing — and the containment gate is the one refusal
  # that must never be reported as anything else.
  local mrc=0
  place_materialize "$PLACE_WORK_TIP" "$prefix" "$handle/collection" || {
    mrc=$?
    rm -rf -- "$handle"
    return "$mrc"
  }
  # A read handle publishes nothing, so it has no changed set to measure and no
  # base to measure it from. Taking one anyway is only a way for a read to fail
  # on work it will never use.
  if (( read_only == 0 )); then
    local -A base=()
    if [[ "$PLACE_BASE_TIP" == "$PLACE_WORK_TIP" ]]; then
      place_snapshot "$handle/collection" base || { rm -rf -- "$handle"; return 1; }
    else
      place_base_snapshot "$PLACE_BASE_TIP" "$prefix" "$handle/base.d" base || {
        mrc=$?
        rm -rf -- "$handle"
        return "$mrc"
      }
    fi
    place_save_snapshot base "$handle/base" || { rm -rf -- "$handle"; return 1; }
  fi
  # The group's one read-failure posture, on the group's other read door. A
  # write cannot proceed: publishing a collection whose index was never brought
  # up to date is how the destination acquires a stale one. A read can, because
  # the materialized copy still carries the index the destination holds — so it
  # degrades, disclosed and carried in the status rather than refused. Deleting
  # the handle here would take that view away with it, which is the refusal by
  # another name.
  local stale=0
  if ! place_reindex "$handle/collection"; then
    (( read_only )) || { rm -rf -- "$handle"; return 1; }
    echo "place.sh: serving '$dest' from the index it already held" >&2
    stale=1
  fi
  {
    printf 'dest=%s\n'   "$dest"
    printf 'prefix=%s\n' "$prefix"
    printf 'tip=%s\n'    "$tip"
    printf 'work=%s\n'   "$PLACE_WORK_TIP"
    printf 'tier=%s\n'   "$tier"
    printf 'remote=%s\n' "$remote"
    printf 'ref=%s\n'    "$ref_old"
    printf 'read=%s\n'   "$read_only"
  } > "$handle/state" || { rm -rf -- "$handle"; return 1; }
  printf '%s\t%s\n' "${handle##*/}" "$handle/collection"
  return "$stale"
}

# place_handle_drift <dest> <prefix>
#   Re-establish at publish time the two facts `begin` established: that
#   placement still names this destination, and that the collection still sits
#   where the handle was opened against it.
#
#   Both arms need this and for the same reason. The destination reaches `push`,
#   `update-ref`, `ls-remote` and `fetch`; the prefix composes the tree entries
#   the publish writes. A handle records them so `commit` need not re-resolve —
#   but recording is not proving, and a value that cleared the gate in one
#   process is not thereby cleared in the next. Re-asking is also what puts the
#   coordination-branch refusal back in front of a destination retargeted onto
#   it after the handle was opened.
place_handle_drift() {
  local dest="$1" prefix="$2" now_dest now_prefix
  now_dest="$(place_destination)" || return 2
  if [[ "$now_dest" != "$dest" ]]; then
    echo "place.sh commit: this handle was opened for '$dest', but issue" \
         "placement now names '$(place_shown "$now_dest")'" >&2
    return 2
  fi
  now_prefix="$(place_prefix)" || return 2
  if [[ "$now_prefix" != "$prefix" ]]; then
    echo "place.sh commit: this handle was opened against '$prefix', but the" \
         "configured collection is now '$(place_shown "$now_prefix")'; the" \
         "edits it holds are not the ones that would be published" >&2
    return 2
  fi
  return 0
}

# cmd_commit <token> --verb <enum> [--id <slug>] — publish a handle's edits.
cmd_commit() {
  local token="${1:-}"; shift || true
  local verb="" id=""
  while (( $# )); do
    case "$1" in
      --verb) verb="${2-}"; shift 2 || break ;;
      --id)   id="${2-}";   shift 2 || break ;;
      *) echo "place.sh commit: unknown option '$1'" >&2; return 2 ;;
    esac
  done
  place_valid_verb "$verb" || return 2
  if [[ -n "$id" ]] && ! bash "$JIMFILE" valid-id "$id" >/dev/null 2>&1; then
    echo "place.sh commit: --id is not a valid issue id" >&2
    return 2
  fi
  case "$token" in
    "$PLACE_TOKEN_NONE")
      # No placement: the collection is the working tree and committing it is
      # the developer's own git flow, exactly as before.
      return 0 ;;
    "$PLACE_TOKEN_DIRECT_READ")
      echo "place.sh commit: this handle was opened read-only and may not" \
           "publish; use abort to discard it" >&2
      return 2 ;;
    "$PLACE_TOKEN_DIRECT")
      # A write handle is issued by `begin` and is unguessable. The bare literal
      # is nobody's handle, and honouring it would publish whatever uncommitted
      # work sits in the collection with nothing having run the dirty guard.
      echo "place.sh commit: '$PLACE_TOKEN_DIRECT' is not a handle — run" \
           "\`place.sh begin\` and commit the token it prints" >&2
      return 2 ;;
  esac
  local handle
  handle="$(place_handle_dir "$token")" || return $?
  if [[ "$(place_state_get "$handle/state" read)" == "1" ]]; then
    echo "place.sh commit: handle '$token' was opened read-only and may not" \
         "publish; use abort to discard it" >&2
    return 2
  fi
  local dest prefix tip work_tip tier remote ref_old current where
  dest="$(place_state_get "$handle/state" dest)"
  prefix="$(place_state_get "$handle/state" prefix)"
  # Both arms re-prove what `begin` established, before either reaches git with
  # a value read back out of handle state.
  place_handle_drift "$dest" "$prefix" || return 2
  current="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ "$(place_state_get "$handle/state" mode)" == "direct" ]]; then
    # A handle opened against a checked-out destination. Its edits are already
    # in the working tree, so there is nothing to replay — but the branch they
    # are committed onto has to still be the one they were made for.
    where="${current:-a detached HEAD}"
    if [[ "$current" != "$dest" ]]; then
      echo "place.sh commit: this handle was opened with '$dest' checked out," \
           "but HEAD is now $where; refusing to commit the collection onto it" >&2
      return 2
    fi
    local drc=0
    place_direct_publish "$dest" "$prefix" "$verb" "$id" || drc=$?
    (( drc == 0 )) || return "$drc"
    rm -rf -- "$handle"
    return 0
  fi
  # The mirror image on this arm. A plumbing handle publishes by moving
  # `refs/heads/<dest>`, and `update-ref` has no checked-out-branch protection:
  # if the developer checked the destination out after `begin`, that ref moves
  # under their index and working tree and the collection reads as deleted. It
  # is the transition the other arm guards, reached through the other door.
  if [[ -n "$current" && "$current" == "$dest" ]]; then
    echo "place.sh commit: '$dest' is now the checked-out branch, and this" \
         "handle publishes by moving its ref — which would leave your index and" \
         "working tree behind it, with the collection reading as deleted. Run" \
         "\`begin\` again to take the checked-out path" >&2
    return 2
  fi
  tip="$(place_state_get "$handle/state" tip)"
  # What the agent's edits were made against. It differs from the tip only when
  # this clone was carrying unpublished commits when the handle was opened, and
  # a publish that loses a race needs it to work out what is still to be carried.
  work_tip="$(place_state_get "$handle/state" work)"
  tier="$(place_state_get "$handle/state" tier)"
  remote="$(place_state_get "$handle/state" remote)"
  ref_old="$(place_state_get "$handle/state" ref)"
  PLACE_WORK="$handle"
  PLACE_COLL="$handle/collection"
  PLACE_GIT_INDEX="$handle/index"
  local -A before=() after=()
  place_load_snapshot "$handle/base" before || return 1
  place_reindex "$PLACE_COLL" || return 1
  place_snapshot "$PLACE_COLL" after || return 1
  local rc=0
  place_commit_changes "$dest" "$prefix" before after "$verb" "$id" \
                       "$remote" "$tier" "$work_tip" "$tip" "$ref_old" || rc=$?
  # A refused publish keeps the handle: the edits in it are work, and losing
  # them to a conflict would make refusing worse than overwriting.
  (( rc == 0 )) || return "$rc"
  # `begin` could not reach the remote, so this landed locally only. Say so —
  # this is the edit path, with no allocator ahead of it to fail first, so
  # silence here is the whole exposure.
  if [[ "$tier" == "local" && -n "$remote" ]]; then
    echo "place.sh: remote '$remote' was unreachable when this handle was opened;" \
         "the mutation is committed locally on '$dest' and publication is deferred" \
         "until the next reachable run" >&2
  fi
  rm -rf -- "$handle"
  return 0
}

# cmd_abort <token> — discard a handle and everything materialized in it.
cmd_abort() {
  local token="${1:-}"
  case "$token" in
    "$PLACE_TOKEN_NONE"|"$PLACE_TOKEN_DIRECT_READ")
      # Neither owns anything to discard: one is the working tree itself, the
      # other a read that materialized nothing. A direct *write* handle is a
      # real handle and falls through to be removed like any other.
      return 0 ;;
  esac
  local handle
  handle="$(place_handle_dir "$token")" || return $?
  rm -rf -- "$handle"
  return 0
}

# place_advance_bookmark <branch> <sha> — record <sha> as the destination state
# this clone has now seen.
place_advance_bookmark() {
  local bref
  [[ -n "${2:-}" ]] || return 0
  bref="$(place_bookmark_ref "$1")" || return 0
  git update-ref --end-of-options "$bref" "$2" 2>/dev/null || true
  return 0
}

# place_check_rewrite <branch> <tip> <authoritative>
#   Compare the destination's current tip against the state this clone last
#   acted on, and disclose loudly when the branch moved non-fast-forward.
#
#   A collection branch has no self-evident tamper tell. An append-only log
#   screams when it is truncated, because its content may only grow; issue
#   content is legitimately edited and deleted, so a force-push there looks
#   exactly like ordinary work. The tip this clone last saw is the only honest
#   freshness fact available, which is why it is recorded on every read as well
#   as every publish.
#
#   Detection discloses; it never blocks. Whether a rewritten destination is
#   sabotage or a teammate cleaning up history is not something this script can
#   know, and refusing to file an issue is a poor answer to either.
#   Disclosing and recording answer different questions — what is at the
#   destination now, and what this clone may claim to have seen published there
#   — so they are separable, and direct mode needs the first without the second.
place_disclose_rewrite() {
  local branch="$1" tip="$2" bref seen rc
  bref="$(place_bookmark_ref "$branch")" || return 0
  seen="$(git rev-parse --verify --quiet --end-of-options "$bref" 2>/dev/null || true)"
  [[ -n "$seen" ]] || return 0
  if [[ -z "$tip" ]]; then
    echo "place.sh: destination branch '$branch' no longer exists; the" \
         "collection this clone last saw at $seen is gone from it" >&2
    return 0
  fi
  [[ "$seen" != "$tip" ]] || return 0
  git merge-base --is-ancestor --end-of-options "$seen" "$tip" 2>/dev/null
  rc=$?
  if (( rc == 1 )); then
    echo "place.sh: destination branch '$branch' was rewritten — the state this" \
         "clone last saw ($seen) is not an ancestor of its current tip ($tip)." \
         "Mutations published before the rewrite may no longer be there." >&2
  elif (( rc != 0 )); then
    # A missing object, usually this clone having gc'd it. Reporting a rewrite
    # here would be a guess; reporting nothing would be the fail-open this
    # function exists to avoid.
    echo "place.sh: cannot tell whether destination branch '$branch' was" \
         "rewritten — the state this clone last saw ($seen) is no longer" \
         "readable here." >&2
  fi
  return 0
}

place_check_rewrite() {
  local branch="$1" tip="$2" authoritative="$3"
  # Only a run that reached the destination's owner learned anything about it,
  # and a run that learned nothing has nothing to compare and nothing to record.
  # The tip read off this clone's own branch while the remote was unreachable is
  # this clone's state, not the destination's: comparing against it calls an
  # ordinary teammate push a rewrite, and recording it rewinds the bookmark to a
  # commit the destination moved past — after which a force-push built on that
  # commit is an ordinary fast-forward and passes in silence.
  (( authoritative )) || return 0
  place_disclose_rewrite "$branch" "$tip"
  place_advance_bookmark "$branch" "$tip"
  return 0
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
  done < <(git ls-tree -r -z --end-of-options "$subtree")
  return 0
}

# place_snapshot <dir> <assoc-array-name>
#   Fill the named associative array with name → blob sha for every file in the
#   collection. Comparing two snapshots is what yields the changed set, and it
#   yields deletions as naturally as additions — a mutation that removes a file
#   (a rename is a remove plus a create) must remove it at the destination too,
#   or the old name comes back the moment the write is replayed.
#   The dotfile namespace is excluded, as every other collection enumerator in
#   the group excludes it. Atomic writers stage through `.<name>.tmp.XXXXXX`
#   beside the file they are replacing, and this is the one enumerator whose
#   output becomes tree entries — so without the exclusion a tmp stranded by a
#   crash mid-write is publishable, after which it is re-materialized on every
#   run, sits unchanged in both snapshots, and appears in no index. Excluding it
#   makes the atomicity self-enforcing here rather than dependent on every
#   writer's cleanup surviving a crash. A path absent from both snapshots is
#   left alone in the destination tree, so nothing already there is disturbed.
#
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
      echo "place.sh: the collection may hold regular files only; found" \
           "'$(place_shown "$name")'" >&2
      return 1
    fi
    # -w stores the blob: the destination tree is built from these object names,
    # so a sha that was only computed names nothing the tree can reference.
    sha="$(git hash-object -w -- "$entry")" || return 1
    _ps_snap["$name"]="$sha"
  done < <(find "$dir" -mindepth 1 -maxdepth 1 ! -name '.*' -print0 2>/dev/null)
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

# place_build_commit <tip> <prefix> <before-array> <after-array> <message>
#   Replay the changed set into a scratch index seeded from <tip>, write the
#   tree, and commit it. Print the new commit. The scratch index is a file in
#   this run's temp root, so the developer's own index is never touched.
#
#   Rebuilding from <tip> is also what makes a retry correct: a rejected publish
#   re-reads the branch and calls this again, so the mutation is reapplied onto
#   the winner's state instead of a stale tree being pushed a second time.
place_build_commit() {
  local tip="$1" prefix="$2" msg="$5"
  local -n _pp_before="$3"
  local -n _pp_after="$4"
  local name tree commit rc
  (
    export GIT_INDEX_FILE="$PLACE_GIT_INDEX"
    rm -f -- "$PLACE_GIT_INDEX"
    if [[ -n "$tip" ]]; then
      git read-tree --end-of-options "$tip" || exit 1
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
  printf '%s\n' "$commit"
}

# place_land <remote> <tier> <branch> <ref-old> <commit>
#   Move the destination branch to <commit>, compare-and-swap against <ref-old>
#   — the value this clone's own copy of the branch held when the mutation was
#   prepared. rc 3 means the branch moved underneath this attempt; the caller
#   re-reads and reapplies rather than overwriting whoever won.
#
#   On the origin tier the push itself is the compare-and-swap: git's default
#   non-fast-forward rejection is exactly the check, so there is no window
#   between testing the remote's state and updating it, and the local update
#   afterwards only records the result. On the local tier the old-value argument
#   does the whole job.
#
#   <ref-old> is not always the commit's parent. A clone that has only ever read
#   the collection prepares against the tip the bookmark remembers while its own
#   copy of the branch does not exist yet, and it is the ref's state — absent —
#   that the swap has to match.
place_land() {
  local remote="$1" tier="$2" branch="$3" ref_old="$4" commit="$5"
  if [[ "$tier" == "origin" ]]; then
    if git push --quiet --end-of-options "$remote" "$commit:refs/heads/$branch" 2>/dev/null; then
      git update-ref --end-of-options "refs/heads/$branch" "$commit" "$ref_old" 2>/dev/null || true
      return 0
    fi
    return 3
  fi
  git update-ref --end-of-options "refs/heads/$branch" "$commit" "$ref_old" 2>/dev/null || return 3
  return 0
}

# place_reindex <dir> — regenerate the collection index in <dir>.
#   Every write regenerates it, so what lands at the destination is one commit
#   holding both the change and an index that describes it. A read regenerates
#   too, inside the materialized copy it is about to throw away — so it is still
#   a read that commits nothing. The destination's index is current for whatever
#   the emitter published, but content arrives by other routes as well, and the
#   alternative to regenerating is asserting freshness the collection may not
#   have.
place_reindex() {
  if ! bash "$INDEX_SCRIPT" "$1" >/dev/null 2>&1; then
    echo "place.sh: could not regenerate the collection index" >&2
    return 1
  fi
  return 0
}

# place_regraft <tip> <prefix> <before> <after> <upstream-out> <merged-out>
#   Reapply this mutation onto a destination that moved. The collection at the
#   new <tip> is materialized fresh, and every path the mutation touched is
#   replayed onto it under one rule: if the destination's copy is unchanged
#   since the base this mutation was prepared against, ours wins; if it changed
#   too, the run refuses (rc 3, path named) rather than erasing a concurrent
#   edit at rc 0. Deletions replay as deletions — a rename is a remove plus a
#   create, and replaying only the create resurrects the old filename.
#
#   The index is the one path never grafted. It is derived, so either side's
#   copy describes only that side's collection; it is regenerated over the
#   merged result instead, which is the only view that matches what lands.
place_regraft() {
  local tip="$1" prefix="$2"
  local -n _rg_before="$3"
  local -n _rg_after="$4"
  local -n _rg_upstream="$5"
  local merge="$PLACE_WORK/merge"
  rm -rf -- "$merge" || return 1
  mkdir -p -- "$merge" || return 1
  place_materialize "$tip" "$prefix" "$merge" || return $?
  place_snapshot "$merge" "$5" || return 1
  local -A touched=()
  local name base ours theirs
  for name in "${!_rg_after[@]}"; do
    [[ "${_rg_before[$name]:-}" == "${_rg_after[$name]}" ]] || touched["$name"]=1
  done
  for name in "${!_rg_before[@]}"; do
    [[ -n "${_rg_after[$name]:-}" ]] || touched["$name"]=1
  done
  for name in "${!touched[@]}"; do
    [[ "$name" == "$PLACE_INDEX_FILE" ]] && continue
    base="${_rg_before[$name]:-}"
    ours="${_rg_after[$name]:-}"
    theirs="${_rg_upstream[$name]:-}"
    if [[ "$theirs" != "$base" ]]; then
      echo "place.sh: '$(place_shown "$name")' also changed at the destination" \
           "while this mutation was being prepared; refusing to overwrite it." \
           "Nothing is lost — re-run to reapply on the current state." >&2
      return 3
    fi
    if [[ -n "$ours" ]]; then
      git cat-file blob "$ours" > "$merge/$name" || return 1
    else
      rm -f -- "$merge/$name" || return 1
    fi
  done
  place_reindex "$merge" || return 1
  place_snapshot "$merge" "$6" || return 1
  return 0
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

# place_release_held <file> <published>
#   Hand back the stdout a wrapped write produced. When the publish landed it is
#   the command's own output, byte for byte, on the stream it was written to.
#
#   When it did not, the same bytes go to stderr under a marker instead. They
#   are not discarded: the emitter's line names an ordinal drawn from an
#   append-only registry, which is spent whether or not the publish succeeded,
#   so dropping the line would destroy the only record of which one was burned.
#   Moving it to stderr keeps that record while taking it off the stream a
#   caller parses for a path it can open.
place_release_held() {
  local file="$1" published="$2"
  [[ -s "$file" ]] || return 0
  if (( published )); then
    cat -- "$file"
  else
    echo "place.sh: not published — the wrapped command reported:" >&2
    cat -- "$file" >&2
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
  # A read-only run publishes nothing, so it has no commit subject to compose
  # and needs no verb. A write always does.
  if (( read_only == 0 )) || [[ -n "$verb" ]]; then
    place_valid_verb "$verb" || return 2
  fi
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

  local current
  current="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -n "$current" && "$current" == "$dest" ]]; then
    place_direct "$dest" "$prefix" "$verb" "$id" "$read_only" "$@"
    return $?
  fi

  place_open_work || return 1

  # Resolve the freshest state of the destination this clone can reach. A
  # configured remote is authoritative; when it cannot be reached the run falls
  # back to the last-seen local state and says so, rather than failing (a
  # discovery is not worth losing to a dropped network) or pretending to be
  # current.
  local remote tier tip ref_old unreachable=0
  remote="$(place_remote)"
  ref_old="$(place_head_tip "$dest")"
  if [[ -n "$remote" ]] && tip="$(place_remote_tip "$remote" "$dest")"; then
    tier="origin"
  else
    tier="local"
    tip="$(place_local_tip "$dest")"
    [[ -n "$remote" ]] && unreachable=1
  fi
  if (( unreachable )) && (( read_only )); then
    echo "place.sh: remote '$remote' is unreachable; serving the last-seen state" \
         "of '$dest'" >&2
  fi
  # Authoritative means this run actually reached whoever owns the branch, so
  # an absent destination is really absent rather than merely unreachable.
  place_check_rewrite "$dest" "$tip" "$(( unreachable == 0 ? 1 : 0 ))"
  place_resolve_tips "$dest" "$tier" "$tip"
  tip="$PLACE_ONTO_TIP"
  if (( read_only )); then
    place_disclose_partial_view "$dest"
  else
    place_disclose_unpublished "$dest"
  fi

  place_materialize "$PLACE_WORK_TIP" "$prefix" "$PLACE_COLL" || return $?
  local -A before=() after=()
  # A read publishes nothing, so it measures no changed set and needs no base to
  # measure one from — and taking one anyway is a way for a read to fail on work
  # it will never use.
  if (( read_only == 0 )); then
    if [[ "$PLACE_BASE_TIP" == "$PLACE_WORK_TIP" ]]; then
      place_snapshot "$PLACE_COLL" before || return 1
    else
      place_base_snapshot "$PLACE_BASE_TIP" "$prefix" "$PLACE_WORK/base" before || return $?
    fi
  fi
  # Only now, with the destination's own state recorded, bring the index up to
  # date. Content reaches the destination by routes the emitter never sees — a
  # hand commit, a merge — and the index that arrives with it can be stale;
  # regenerating over a snapshot already taken means a read is served a current
  # one and a write publishes the correction rather than hiding it.
  #
  # A write cannot proceed on a failure here: publishing a collection whose
  # index was never brought up to date is how the destination acquires the
  # stale one. A read can, because the materialized copy still carries the
  # index the destination holds — so it degrades to what a reader in the
  # working tree gets, disclosed and carried in the status rather than refused.
  local stale=0
  if ! place_reindex "$PLACE_COLL"; then
    (( read_only )) || return 1
    echo "place.sh: serving '$dest' from the index it already held" >&2
    stale=1
  fi
  place_substitute "$PLACE_COLL" "$PLACE_TOKEN" "$@"
  local rc=0
  # The prefix travels with the token so a wrapped command can report where its
  # work will actually live, rather than the temp directory it composed it in.
  # It names a location only — routing turns on the token pair alone.
  #
  # That is also why the output is held rather than passed straight through: it
  # describes the destination, and on this arm the destination is not written
  # until the publish below succeeds. The temp collection the command wrote into
  # is discarded with the run, so a caller handed a path from a publish that
  # failed holds one that exists nowhere.
  JIM_PLACE_TOKEN="$PLACE_TOKEN" JIM_PLACE_PREFIX="$prefix" "${PLACE_CMD[@]}" \
    > "$PLACE_WORK/held" || rc=$?
  if (( rc != 0 )); then
    place_release_held "$PLACE_WORK/held" 0
    return "$rc"
  fi
  if (( read_only )); then
    place_release_held "$PLACE_WORK/held" 1
    return "$stale"
  fi
  local prc=0
  if ! place_reindex "$PLACE_COLL"; then
    prc=1
  elif ! place_snapshot "$PLACE_COLL" after; then
    prc=1
  else
    place_commit_changes "$dest" "$prefix" before after "$verb" "$id" \
                         "$remote" "$tier" "$PLACE_WORK_TIP" "$tip" "$ref_old" || prc=$?
  fi
  place_release_held "$PLACE_WORK/held" "$(( prc == 0 ))"
  (( prc == 0 )) || return "$prc"
  if (( unreachable )); then
    echo "place.sh: remote '$remote' is unreachable; the mutation is committed" \
         "locally on '$dest' and publication is deferred until the next" \
         "reachable run" >&2
  fi
  return 0
}

# place_changed <before> <after> — exit 0 iff the collection changed at all.
place_changed() {
  local -n _ch_before="$1"
  local -n _ch_after="$2"
  local name
  for name in "${!_ch_after[@]}"; do
    [[ "${_ch_before[$name]:-}" == "${_ch_after[$name]}" ]] || return 0
  done
  for name in "${!_ch_before[@]}"; do
    [[ -n "${_ch_after[$name]:-}" ]] || return 0
  done
  return 1
}

# place_commit_changes <branch> <prefix> <before> <after> <verb> <id>
#                      <remote> <tier> <work-tip> <onto-tip> <ref-old>
#   Publish the changed set, retrying against a moved destination.
#
#   Every attempt has the same shape, and that is what keeps the rare states
#   honest. The changed set is measured from the common ancestor of what this
#   clone was working on and what the mutation is being applied onto, and
#   whenever those two are different commits the mutation is grafted rather than
#   written straight over the destination's tree. Against an unmoved destination
#   the ancestor *is* the tip, so the graft collapses into a plain build; every
#   other case — a destination that moved on while this clone held unpublished
#   commits, a lost race, both at once — takes that same path with a different
#   ancestor. An attempt is not a state of its own.
#
#   The ancestor is recomputed whenever the tip moves, and the changed set is
#   measured again from it. A mutation deferred while the remote was unreachable
#   is the case that needs this: its content is the base on the first attempt,
#   because the commit carrying it is what the run is building on — and the
#   moment a lost race moves the run onto a tip that never had it, it stops
#   being the base and becomes part of what has to be carried.
#
#   The wrapped command is never re-run — re-running a filing would burn a
#   second coordinated ordinal on every lost race.
#
#   A mutation that changed nothing publishes nothing: no empty commit is left
#   behind on the destination branch.
place_commit_changes() {
  local dest="$1" prefix="$2" verb="$5" id="$6"
  local remote="$7" tier="$8" work_tip="$9" tip="${10}" ref_old="${11}"
  place_changed "$3" "$4" || return 0
  local msg commit attempt rc base prev_tip new_base
  local -A upstream=() merged=()
  msg="$(place_message "$verb" "$id")"
  base="$(place_merge_base "$work_tip" "$tip")"
  for (( attempt=1; attempt<=PLACE_ATTEMPTS; attempt++ )); do
    if [[ "$base" == "$tip" ]]; then
      commit="$(place_build_commit "$tip" "$prefix" "$3" "$4" "$msg")" || return 1
    else
      place_regraft "$tip" "$prefix" "$3" "$4" upstream merged || return $?
      # The mutation may already be present at the destination — someone
      # applied the same change while this run was retrying.
      place_changed upstream merged || return 0
      commit="$(place_build_commit "$tip" "$prefix" upstream merged "$msg")" || return 1
    fi
    place_land "$remote" "$tier" "$dest" "$ref_old" "$commit"
    rc=$?
    if (( rc == 0 )); then
      # A commit that only reached this clone was never seen at the destination,
      # so it is not what the bookmark records. With no remote configured at all
      # the local ref *is* the destination, and it is.
      if [[ "$tier" == "origin" || -z "$remote" ]]; then
        place_advance_bookmark "$dest" "$commit"
      fi
      return 0
    fi
    (( rc == 3 )) || return "$rc"
    (( attempt < PLACE_ATTEMPTS )) && place_backoff "$attempt"
    prev_tip="$tip"
    # Re-read whatever won the race. A remote that dropped out mid-retry
    # degrades to the local tier rather than spinning against it. On either tier
    # the ref's own value is read *before* the tip it is paired with: a racer
    # landing between the two reads then makes the compare-and-swap fail rather
    # than match, and a spurious refusal only costs a retry where a spurious
    # match costs the racer's mutation.
    if [[ "$tier" == "origin" ]]; then
      if tip="$(place_remote_tip "$remote" "$dest")"; then
        # The re-read is a fetch, so what it learned about the destination is
        # worth checking: a rejection caused by a rewrite would otherwise be
        # regrafted onto the rewritten tip and lose its own evidence.
        place_check_rewrite "$dest" "$tip" 1
      else
        tier="local"
        echo "place.sh: lost contact with '$remote' while publishing to '$dest';" \
             "the mutation is being committed locally instead and publication is" \
             "deferred until the next reachable run" >&2
        ref_old="$(place_head_tip "$dest")"
        tip="$(place_local_tip "$dest")"
      fi
    else
      ref_old="$(place_head_tip "$dest")"
      tip="$(place_local_tip "$dest")"
    fi
    # A destination that did not move cannot have rejected this for contention,
    # and every further attempt would fail the same way — the diagnosis has to
    # name the cause it actually has.
    if [[ "$tier" == "origin" && "$tip" == "$prev_tip" ]]; then
      echo "place.sh: '$remote' rejected the publish to '$dest', which has not" \
           "moved — so this is not contention and retrying cannot help. Check" \
           "push rights, branch protection, or the connection. The mutation was" \
           "not published." >&2
      return 3
    fi
    new_base="$(place_merge_base "$work_tip" "$tip")"
    if [[ "$new_base" != "$base" ]]; then
      base="$new_base"
      place_base_snapshot "$base" "$prefix" "$PLACE_WORK/retry.d" "$3" || return $?
    fi
  done
  echo "place.sh: '$dest' kept moving; the mutation was not published after" \
       "$PLACE_ATTEMPTS attempts. It is unpublished, not lost — re-run to apply it." >&2
  return 3
}

usage() {
  cat <<'USAGE'
Usage:
  place.sh mode [--place-token <tok>]        print `direct` or `route`
  place.sh run [--read] --verb <enum> [--id <slug>] -- CMD [ARGS...]
  place.sh begin [--read]                    print "<token><TAB><dir>"
  place.sh commit <token> --verb <enum> [--id <slug>]
  place.sh abort <token>

  verbs: file edit close rename realize reindex backfill migrate
  an ARG of exactly `{}` becomes the collection directory, `{token}` the token.
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
    mode)   cmd_mode   "$@" ;;
    run)    cmd_run    "$@" ;;
    begin)  cmd_begin  "$@" ;;
    commit) cmd_commit "$@" ;;
    abort)  cmd_abort  "$@" ;;
    help|--help|-h) usage; return 0 ;;
    *)
      echo "place.sh: unknown subcommand '$subcmd'" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
