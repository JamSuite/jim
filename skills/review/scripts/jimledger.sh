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
    event)   shift; cmd_event "$@" ;;
    *) usage; return 2 ;;
  esac
}

main "$@"
exit $?
