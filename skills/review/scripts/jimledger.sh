#!/usr/bin/env bash
#
# skills/review/scripts/jimledger.sh — jim ledger for the /jim:review phase.
#
# Records the build's boundary and process events to <spec-dir>/ledger.md (an
# append-only, line-oriented log) and derives metrics from git + the ledger for
# the reviewer. This is the only jim script that reads git operationally.
#
# Subcommands:
#   start   <spec-dir>                         append a build-started event (base_sha)
#   finish  <spec-dir>                         append a build-finished event (head_sha)
#   event   <spec-dir> <phase> <event> [k=v…]  append a generic event
#   metrics <spec-dir>                         emit git + per-stage ledger key=value lines
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

# ledger_kv <ledger> <phase> <event> <key> <which:first|last>
#   Extract a kv value from the first/last line whose phase AND event fields
#   match and whose kv field carries <key>=. Empty if none. Scoping by phase
#   keeps a same-named event from another phase out of the build range.
#   Untrusted input — parsed only.
ledger_kv() {
  local ledger="$1" phase="$2" event="$3" key="$4" which="$5"
  awk -F'\t' -v ph="$phase" -v ev="$event" -v k="$key" -v which="$which" '
    $3==ph && $4==ev {
      n=split($5, a, ";")
      for (i=1; i<=n; i++) {
        if (index(a[i], k"=")==1) {
          val=substr(a[i], length(k)+2)
          if (which=="first") { print val; exit }
        }
      }
    }
    END { if (which=="last" && val!="") print val }
  ' "$ledger"
}

# resolve_range <spec-dir> — print "<base> <head>" for the build range, or
#   return 2 (no ledger / no baseline / malformed sha). SHAs are validated here
#   so callers can interpolate them into git ranges safely.
resolve_range() {
  local dir="$1" ledger="$dir/ledger.md"
  if [[ ! -f "$ledger" ]]; then echo "jimledger: no ledger at $ledger" >&2; return 2; fi
  local base head
  base="$(ledger_kv "$ledger" build started base_sha first)"
  head="$(ledger_kv "$ledger" build finished head_sha last)"
  if [[ -z "$base" ]]; then echo "jimledger: no build baseline in ledger" >&2; return 2; fi
  if [[ -z "$head" ]]; then head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)"; fi
  if ! validate_sha "$base" || ! validate_sha "$head"; then
    echo "jimledger: refusing malformed sha in ledger" >&2
    return 2
  fi
  printf '%s %s' "$base" "$head"
}

# cmd_files <spec-dir> — list changed paths over the build range (untrusted).
cmd_files() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger files: need <spec-dir>" >&2; return 2; fi
  local rr base head
  rr="$(resolve_range "$dir")" || return 2
  base="${rr% *}"; head="${rr#* }"
  git -C "$dir" diff --name-only "$base..$head" --
}

# Stages whose started/finished boundaries the ledger may carry. The metrics
# loop iterates THIS fixed list — key names are literals, never derived from
# ledger text — so a tampered ledger cannot inject spurious metric keys
# (sec Finding 7: the metrics stream stays a content-free trusted channel).
LEDGER_STAGES="spec research plan sec build"

# phase_event_metrics <ledger> — emit per-stage process metrics:
#   <stage>_runs, <stage>_interruptions, and (when both bounds exist)
#   <stage>_duration_seconds. runs = max(started, finished) so a stage that
#   records only `finished` (spec, whose dir does not exist at entry) still
#   counts as one run. Stages with no events are omitted (absent key = stage
#   not instrumented), matching the reviewer's graceful-degradation contract.
phase_event_metrics() {
  local ledger="$1" ph s f runs inter se fe
  for ph in $LEDGER_STAGES; do
    s="$(awk -F'\t' -v p="$ph" '$3==p && $4=="started"{n++}  END{print n+0}' "$ledger")"
    f="$(awk -F'\t' -v p="$ph" '$3==p && $4=="finished"{n++} END{print n+0}' "$ledger")"
    if (( s == 0 && f == 0 )); then continue; fi
    if (( s > f )); then runs=$s; inter=$(( s - f )); else runs=$f; inter=0; fi
    printf '%s_runs=%s\n' "$ph" "$runs"
    printf '%s_interruptions=%s\n' "$ph" "$inter"
    se="$(awk -F'\t' -v p="$ph" '$3==p && $4=="started"{print $1; exit}' "$ledger")"
    fe="$(awk -F'\t' -v p="$ph" '$3==p && $4=="finished"{e=$1} END{print e}' "$ledger")"
    if [[ "$se" =~ ^[0-9]+$ && "$fe" =~ ^[0-9]+$ ]]; then
      printf '%s_duration_seconds=%s\n' "$ph" "$(( fe - se ))"
    fi
  done
}

# cmd_metrics <spec-dir> — emit content-free key=value metrics (DD #9).
cmd_metrics() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then echo "jimledger metrics: need <spec-dir>" >&2; return 2; fi
  local rr base head
  rr="$(resolve_range "$dir")" || return 2
  base="${rr% *}"; head="${rr#* }"
  local ledger="$dir/ledger.md"
  local range="$base..$head"
  local commits ct cf cx cr stat fc ins del
  commits="$(git -C "$dir" rev-list --count "$range" 2>/dev/null || echo 0)"
  ct="$(git -C "$dir" log --format=%s "$range" 2>/dev/null | grep -cE '^test(\([^)]+\))?!?:')"
  cf="$(git -C "$dir" log --format=%s "$range" 2>/dev/null | grep -cE '^feat(\([^)]+\))?!?:')"
  cx="$(git -C "$dir" log --format=%s "$range" 2>/dev/null | grep -cE '^fix(\([^)]+\))?!?:')"
  cr="$(git -C "$dir" log --format=%s "$range" 2>/dev/null | grep -cE '^refactor(\([^)]+\))?!?:')"
  stat="$(git -C "$dir" diff --shortstat "$range" -- 2>/dev/null)"
  fc="$(printf '%s' "$stat"  | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || true)"
  ins="$(printf '%s' "$stat" | grep -oE '[0-9]+ insertion'      | grep -oE '[0-9]+' || true)"
  del="$(printf '%s' "$stat" | grep -oE '[0-9]+ deletion'       | grep -oE '[0-9]+' || true)"
  : "${fc:=0}" "${ins:=0}" "${del:=0}"

  printf 'base_sha=%s\n' "$base"
  printf 'head_sha=%s\n' "$head"
  printf 'commits=%s\n' "$commits"
  printf 'commits_test=%s\n' "$ct"
  printf 'commits_feat=%s\n' "$cf"
  printf 'commits_fix=%s\n' "$cx"
  printf 'commits_refactor=%s\n' "$cr"
  printf 'files_changed=%s\n' "$fc"
  printf 'insertions=%s\n' "$ins"
  printf 'deletions=%s\n' "$del"

  # Per-stage process metrics: build_runs / build_interruptions /
  # build_duration_seconds, plus the same triplet for every other instrumented
  # stage (spec/research/plan/sec). Iterates a fixed allowlist (LEDGER_STAGES) —
  # key names are literals, never derived from ledger text.
  phase_event_metrics "$ledger"
  return 0
}

main() {
  local sub="${1:-}"
  case "$sub" in
    start)   shift; cmd_start "$@" ;;
    metrics) shift; cmd_metrics "$@" ;;
    files)   shift; cmd_files "$@" ;;
    finish)  shift; cmd_finish "$@" ;;
    event)   shift; cmd_event "$@" ;;
    *) usage; return 2 ;;
  esac
}

main "$@"
exit $?
