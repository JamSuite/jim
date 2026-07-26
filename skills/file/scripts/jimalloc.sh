#!/usr/bin/env bash
#
# skills/file/scripts/jimalloc.sh — jim's ID-coordination allocator.
#
# PURPOSE
#   Hand out jim's IDs (spec ordinals, issue ordinals + durable issue ids, and
#   group names) through a shared, append-only registry so separate users on
#   separate clones never claim the same ID. Allocation appends a
#   compare-and-swap (CAS)-guarded record to a per-kind log on a dedicated
#   coordination branch, using git plumbing so the developer's working tree is
#   never disturbed mid-flow.
#
#   This is jim's first script to fetch/push and write a shared ref. The
#   coordination branch is writable by anyone who can push it, so every value
#   read back from the registry or from config is revalidated through
#   jimfile.sh's id/slug/path boundary before it reaches a git command, a ref,
#   or a filesystem path (the single security boundary — no fourth copy).
#
# CLI SUMMARY
#   bash jimalloc.sh allocate spec  <group> <subject>   → "<group>/<NNN>"
#   bash jimalloc.sh allocate issue <subject>           → "<full-id>\t<num>"
#   bash jimalloc.sh peek     spec  <group>             → advisory "<group>/<NNN>"
#   bash jimalloc.sh peek     issue                     → advisory "<num>"
#   bash jimalloc.sh resolve  spec  <group>/<NNN>       → current "<group>/<NNN>"
#   bash jimalloc.sh resolve  issue <num|full-id>       → current id
#   bash jimalloc.sh -c <path> <subcmd>                 use <path> as jimconf.toml
#
# EXIT CODES
#   0  Success.
#   1  Hard failure (unreachable coordination point / erosion detected /
#      retries exhausted / a rejected registry or config token).
#   2  Malformed invocation (missing argument, unknown subcommand).
#

set -uo pipefail
# LC_ALL=C — locale-independent text handling (matches jimfile.sh / jimconf.sh).
export LC_ALL=C
# Non-interactive git: a mid-flow credential prompt must never hang a consumer;
# an unreachable coordination point surfaces as a failed command, not a stall.
export GIT_TERMINAL_PROMPT=0

# ─── Section: Globals ────────────────────────────────────────────────────────

# Sibling platform CLIs, resolved BASH_SOURCE-relative so the composition
# travels with the plugin tree regardless of install scope. jimfile.sh is the
# id/slug/date/path boundary; jimconf.sh resolves the id_coordination_* keys.
JIMFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jimfile.sh"
JIMCONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../conf/scripts" && pwd)/jimconf.sh"

# Optional -c <path> override for jimconf.toml. Empty when not supplied;
# production consumers never pass it (tests and ad-hoc inspection do).
CONFIG_FILE=""

# ─── Section: Record layer (pure — operates on a log, no git) ────────────────
#
# The registry is one append-only, space-separated, newline-delimited log per
# kind, file-order authoritative. It is writable by anyone who can push the
# coordination branch, so it is untrusted data: every id/group/slug token read
# back is revalidated through jimfile.sh's boundary before use, and a malformed
# record is degraded and skipped — never executed (parsed as data; never sourced).
#
# Record grammar (fields after `<kind> <verb>`):
#   spec  allocate <group>/<NNN> <slug> <date> <who>
#   group allocate <group> <date> <who>
#   issue allocate <NNN> <full-id> <date> <who>
#   spec  rename   <group>/<NNN> <newgroup>/<newNNN> <date>
#   group rename   <old-group> <new-group> <date>
#   issue rename   <NNN> <newNNN> <date>
# Only allocate records are emitted by this build; rename/group-rename are parsed
# and resolved (format frozen) so a later spec can begin emitting them unchanged.

# alloc_log_file <kind> — the log file name for <kind>. Group records ride the
# spec log so resolving a spec id replays a single file.
alloc_log_file() {
  case "$1" in
    spec|group) printf 'specs.log' ;;
    issue)      printf 'issues.log' ;;
    *) return 1 ;;
  esac
}

# alloc_read_log <kind> — print the current registry log for <kind> to stdout
# (empty if none). Source precedence:
#   1. $JIMALLOC_REGISTRY_DIR (offline/local staging + test seam), if set.
#   2. the coordination branch via git plumbing (wired in a later task).
alloc_read_log() {
  local kind="$1" file
  file="$(alloc_log_file "$kind")" || { echo "error: no log for kind '$kind'" >&2; return 1; }
  if [[ -n "${JIMALLOC_REGISTRY_DIR:-}" ]]; then
    local p="$JIMALLOC_REGISTRY_DIR/$file"
    [[ -f "$p" ]] && cat -- "$p"
    return 0
  fi
  echo "error: coordination-branch registry read is not wired yet" >&2
  return 1
}

# alloc_valid_token <tok> — exit 0 iff <tok> passes jimfile.sh's id boundary
# (is_valid_id). THE single security boundary — no fourth copy. Forecloses
# option-injection (leading '-'), path traversal ('..'), and ref metacharacters,
# all of which fall outside the ^[A-Za-z0-9][A-Za-z0-9._-]*$ allowlist.
alloc_valid_token() {
  bash "$JIMFILE" valid-id "$1" >/dev/null 2>&1
}

# alloc_valid_specid <id> — exit 0 iff <id> is "<group>/<NNN>": exactly one '/',
# a boundary-valid group, and an all-digits ordinal.
alloc_valid_specid() {
  local id="$1" grp num
  [[ "$id" == */* ]] || return 1
  grp="${id%/*}"; num="${id##*/}"
  [[ "$grp" == *"/"* ]] && return 1
  [[ "$num" =~ ^[0-9]+$ ]] || return 1
  alloc_valid_token "$grp"
}

# alloc_sanitize_who <raw> — reduce a free-text provenance value to a single safe
# token: every character outside [A-Za-z0-9._@-] (space, tab, NEWLINE, CR, and
# ref/shell metacharacters) becomes '-', runs collapse, ends trim, cap 64. A
# newline here would otherwise forge a second record on a plain grep/replay; it
# is advisory provenance only, so lossy normalization is acceptable (DD 7 / F8).
alloc_sanitize_who() {
  printf '%s' "${1:-}" \
    | tr -c 'A-Za-z0-9._@-' '-' \
    | sed 's/-\+/-/g; s/^-//; s/-$//' \
    | cut -c1-64
}

# alloc_encode_allocate_spec  <specid> <slug> <date> <who>
# alloc_encode_allocate_group <group> <date> <who>
# alloc_encode_allocate_issue <num> <full-id> <date> <who>
#   Build exactly one record line. Fixed fields are pre-validated single tokens
#   supplied by the allocate path; the trailing free-text <who> is sanitized
#   here (write-side complement to read-side revalidation).
alloc_encode_allocate_spec() {
  printf 'spec allocate %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}
alloc_encode_allocate_group() {
  printf 'group allocate %s %s %s\n' "$1" "$2" "$(alloc_sanitize_who "${3:-}")"
}
alloc_encode_allocate_issue() {
  printf 'issue allocate %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}

# alloc_resolve_spec <queried>  (log on stdin)
#   Forward-replay a spec id to its current name. Replay is anchored at the
#   queried id's own (last) allocate record so a string later reused does not
#   inherit an earlier referent's rename history; if the queried id has no
#   allocate record of its own (it may be the current name a rename produced),
#   replay runs from the top. Each record applies at most once in file order,
#   so a reverted rename cycle terminates. rc 1 if the id is invalid or never
#   appears in the registry (as an allocate id, a rename target, or a member of
#   a renamed-into group).
alloc_resolve_spec() {
  local queried="$1"
  alloc_valid_specid "$queried" || { echo "error: invalid spec id '$queried'" >&2; return 1; }
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6
  local qgroup="${queried%/*}"
  local anchor=-1 known=0
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == allocate ]]; then
      alloc_valid_specid "$c3" || continue
      [[ "$c3" == "$queried" ]] && { anchor=$i; known=1; }
    elif [[ "$c1" == spec && "$c2" == rename ]]; then
      alloc_valid_specid "$c3" && alloc_valid_specid "$c4" || continue
      [[ "$c4" == "$queried" ]] && known=1
    elif [[ "$c1" == group && "$c2" == rename ]]; then
      alloc_valid_token "$c3" && alloc_valid_token "$c4" || continue
      [[ "$c4" == "$qgroup" ]] && known=1
    fi
  done
  local current="$queried"
  for ((i=0; i<n; i++)); do
    (( anchor >= 0 && i <= anchor )) && continue
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == rename ]]; then
      alloc_valid_specid "$c3" && alloc_valid_specid "$c4" || continue
      [[ "$c3" == "$current" ]] && current="$c4"
    elif [[ "$c1" == group && "$c2" == rename ]]; then
      alloc_valid_token "$c3" && alloc_valid_token "$c4" || continue
      [[ "$current" == "$c3"/* ]] && current="$c4/${current#*/}"
    fi
  done
  (( known )) || { echo "error: spec id '$queried' not allocated" >&2; return 1; }
  printf '%s\n' "$current"
}

# alloc_resolve_issue <queried>  (log on stdin)
#   Resolve an issue citation (an ordinal or a durable full-id) to its current
#   ordinal, following issue-rename records. A full-id is first mapped to its
#   ordinal via its allocate record. Same anchoring / cycle-safety discipline
#   as the spec resolver; issues have no group dimension.
alloc_resolve_issue() {
  local queried="$1"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6
  local target=""
  if [[ "$queried" =~ ^[0-9]+$ ]]; then
    target="$queried"
  else
    alloc_valid_token "$queried" || { echo "error: invalid issue id '$queried'" >&2; return 1; }
    for ((i=0; i<n; i++)); do
      read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
      [[ "$c1" == issue && "$c2" == allocate ]] || continue
      [[ "$c3" =~ ^[0-9]+$ ]] || continue
      alloc_valid_token "$c4" || continue
      [[ "$c4" == "$queried" ]] && target="$c3"
    done
    [[ -n "$target" ]] || { echo "error: issue id '$queried' not allocated" >&2; return 1; }
  fi
  local anchor=-1 known=0
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == issue && "$c2" == allocate ]]; then
      [[ "$c3" =~ ^[0-9]+$ ]] || continue
      [[ "$c3" == "$target" ]] && { anchor=$i; known=1; }
    elif [[ "$c1" == issue && "$c2" == rename ]]; then
      [[ "$c3" =~ ^[0-9]+$ && "$c4" =~ ^[0-9]+$ ]] || continue
      [[ "$c4" == "$target" ]] && known=1
    fi
  done
  local current="$target"
  for ((i=0; i<n; i++)); do
    (( anchor >= 0 && i <= anchor )) && continue
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    [[ "$c1" == issue && "$c2" == rename ]] || continue
    [[ "$c3" =~ ^[0-9]+$ && "$c4" =~ ^[0-9]+$ ]] || continue
    [[ "$c3" == "$current" ]] && current="$c4"
  done
  (( known )) || { echo "error: issue '$queried' not allocated" >&2; return 1; }
  printf '%s\n' "$current"
}

# ─── Section: Subcommand handlers ────────────────────────────────────────────

cmd_allocate() {
  echo "error: 'allocate' not yet implemented" >&2
  return 1
}

cmd_peek() {
  echo "error: 'peek' not yet implemented" >&2
  return 1
}

cmd_resolve() {
  local kind="${1:-}" queried="${2:-}"
  if [[ -z "$kind" || -z "$queried" ]]; then
    echo "error: 'resolve' requires <kind> and <id>" >&2
    return 2
  fi
  case "$kind" in
    spec)  alloc_read_log spec  | alloc_resolve_spec  "$queried" ;;
    issue) alloc_read_log issue | alloc_resolve_issue "$queried" ;;
    *)
      echo "error: resolve kind must be 'spec' or 'issue'" >&2
      return 2
      ;;
  esac
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

usage() {
  cat >&2 <<'USAGE'
usage:
  jimalloc.sh allocate spec  <group> <subject>   allocate a spec id
  jimalloc.sh allocate issue <subject>           allocate an issue id
  jimalloc.sh peek     spec  <group>             advisory next spec id (no commit)
  jimalloc.sh peek     issue                     advisory next issue num (no commit)
  jimalloc.sh resolve  spec  <group>/<NNN>       resolve a spec id to its current name
  jimalloc.sh resolve  issue <num|full-id>       resolve an issue id to its current name
  jimalloc.sh -c <path> <subcmd>                 use <path> instead of ./jimconf.toml
USAGE
}

main() {
  if [[ "${1:-}" == "-c" ]]; then
    if [[ -z "${2:-}" ]]; then
      echo "error: -c requires a path argument" >&2
      return 2
    fi
    CONFIG_FILE="$2"
    shift 2
  fi
  local subcmd="${1:-}"
  if [[ -z "$subcmd" ]]; then
    usage
    return 2
  fi
  shift
  case "$subcmd" in
    allocate) cmd_allocate "$@" ;;
    peek)     cmd_peek     "$@" ;;
    resolve)  cmd_resolve  "$@" ;;
    *)
      echo "error: unknown subcommand '$subcmd'" >&2
      usage
      return 2
      ;;
  esac
}

# Guarded so the pure record-layer functions can be sourced and unit-tested
# without executing the CLI (BASH_SOURCE[0] != $0 when sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
