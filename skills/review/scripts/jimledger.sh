#!/usr/bin/env bash
#
# skills/review/scripts/jimledger.sh — Build ledger for the /jim:review phase.
#
# Records the build's boundary and process events to <spec-dir>/ledger.md (an
# append-only, line-oriented log) and derives metrics from git + the ledger for
# the reviewer. This is the only jim script that reads git operationally.
#
# Subcommands:
#   start   <spec-dir>                         append a build-started event (base_sha)
#   finish  <spec-dir>                         append a build-finished event (head_sha)
#   event   <spec-dir> <phase> <event> [k=v…]  append a generic event
#   metrics <spec-dir>                         emit git + ledger derived key=value lines
#   files   <spec-dir>                         list changed file paths over base..head
#
# Ledger line format (TAB-separated): <epoch>\t<iso8601>\t<phase>\t<event>\t<kv>
#
# Security: commit/diff/ledger content is untrusted — never sourced or eval'd.
# SHAs read from the ledger are validated via jimfile.sh `valid-id` before any
# git range use (forecloses option injection). The script never commits; the
# build commits ledger.md.

set -uo pipefail
export LC_ALL=C

# jimfile.sh provides the single is_valid_id boundary (via `valid-id`). Resolved
# BASH_SOURCE-relative so it travels with the plugin tree.
JIMFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../file/scripts" 2>/dev/null && pwd)/jimfile.sh"

usage() {
  cat >&2 <<'USAGE'
usage: jimledger.sh <subcommand> <spec-dir> [args]
  start   <spec-dir>                          record build start (base_sha)
  finish  <spec-dir>                          record build finish (head_sha)
  event   <spec-dir> <phase> <event> [k=v …]  append a generic event
  metrics <spec-dir>                          emit key=value metrics to stdout
  files   <spec-dir>                          list changed files over the build range
USAGE
}

# append_line <spec-dir> <phase> <event> <kv>
#   Append one TAB-separated event to <spec-dir>/ledger.md.
append_line() {
  local dir="$1" phase="$2" event="$3" kv="$4"
  if [[ ! -d "$dir" ]]; then
    echo "jimledger: spec-dir not found: $dir" >&2
    return 2
  fi
  local epoch iso
  epoch="$(date -u +%s)"
  iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "$iso" "$phase" "$event" "$kv" >> "$dir/ledger.md"
}

# validate_sha <sha> — return 0 iff <sha> passes jimfile.sh's is_valid_id.
validate_sha() {
  bash "$JIMFILE" valid-id "$1" >/dev/null 2>&1
}

# resolve_head <spec-dir> — echo the validated HEAD sha of the repo containing
#   <spec-dir>, or return 2 (not a repo / no HEAD / invalid sha).
resolve_head() {
  local dir="$1" sha
  sha="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || {
    echo "jimledger: not a git repo or no HEAD: $dir" >&2
    return 2
  }
  if ! validate_sha "$sha"; then
    echo "jimledger: refusing malformed sha: $sha" >&2
    return 2
  fi
  printf '%s' "$sha"
}

# cmd_start <spec-dir> — record the build baseline.
cmd_start() {
  local dir="${1:-}" sha
  if [[ -z "$dir" ]]; then echo "jimledger start: need <spec-dir>" >&2; return 2; fi
  sha="$(resolve_head "$dir")" || return 2
  append_line "$dir" build started "base_sha=$sha"
}

# cmd_finish <spec-dir> — record the build head.
cmd_finish() {
  local dir="${1:-}" sha
  if [[ -z "$dir" ]]; then echo "jimledger finish: need <spec-dir>" >&2; return 2; fi
  sha="$(resolve_head "$dir")" || return 2
  append_line "$dir" build finished "head_sha=$sha"
}

# cmd_event <spec-dir> <phase> <event> [k=v ...]
cmd_event() {
  local dir="${1:-}" phase="${2:-}" event="${3:-}"
  if [[ -z "$dir" || -z "$phase" || -z "$event" ]]; then
    echo "jimledger event: need <spec-dir> <phase> <event> [k=v ...]" >&2
    return 2
  fi
  shift 3
  local kv="" tok
  for tok in "$@"; do
    kv="${kv:+$kv;}$tok"
  done
  append_line "$dir" "$phase" "$event" "$kv"
}

main() {
  local sub="${1:-}"
  case "$sub" in
    start)   shift; cmd_start "$@" ;;
    finish)  shift; cmd_finish "$@" ;;
    event)   shift; cmd_event "$@" ;;
    *) usage; return 2 ;;
  esac
}

main "$@"
exit $?
