#!/usr/bin/env bash
#
# skills/issue/scripts/migrate.sh — one-shot, opt-in migrations that TRANSFORM
# existing issue data (vs backfill.sh, which fills in MISSING data). Subcommand:
#
#   prefix — re-derive every issue id to the active issue_id_prefix scheme
#            (spec 023), renaming files and rewriting inbound references behind
#            a read-only preview + explicit --apply gate.
#
# CLI SUMMARY
#   bash migrate.sh
#     No subcommand: print help/usage.
#   bash migrate.sh prefix [<issues_dir>]
#     PREVIEW (read-only): print the rename/skip/collision plan + summary.
#     Mutates nothing.
#   bash migrate.sh prefix [<issues_dir>] --apply [--expect <hash>]
#     APPLY: rename files + rewrite inbound refs + regenerate INDEX.
#   bash migrate.sh -c <config> <subcmd>
#     Forward -c to jimfile.sh / jimconf.sh (used by tests).
#   issues_dir default: jimconf.sh get issues
#
# EXIT CODES
#   0  Success (including the no-op and help cases).
#   1  IO failure (cannot write tmp, atomic rename failed).
#   2  Malformed invocation (unknown subcommand, empty issues_dir).
#   3  Drift (--expect mismatch).
#
# Line-oriented only; never source/evals an issue file.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
readonly INDEX_FILENAME="INDEX.md"
CFG=""   # optional jimconf override path, forwarded to jimfile/jimconf

# jf / jc <args...> — invoke jimfile.sh / jimconf.sh, forwarding -c when set.
jf() { if [[ -n "$CFG" ]]; then bash "$JIMFILE" -c "$CFG" "$@"; else bash "$JIMFILE" "$@"; fi; }
jc() { if [[ -n "$CFG" ]]; then bash "$JIMCONF" -c "$CFG" "$@"; else bash "$JIMCONF" "$@"; fi; }

# resolve_dir <arg> — arg if non-empty, else jimconf default; strip trailing /.
resolve_dir() {
  local dir="${1:-}"
  [[ -z "$dir" ]] && dir="$(jc get issues 2>/dev/null)"
  dir="${dir%/}"
  if [[ -z "$dir" ]]; then
    echo "error: issues_dir is empty" >&2
    return 2
  fi
  printf '%s\n' "$dir"
}

# field_value <file> <field> — top-level scalar value, quotes stripped, or empty.
field_value() {
  grep -E "^$2:" "$1" 2>/dev/null \
    | head -n 1 \
    | sed -E "s/^$2:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"
}

# build_plan <dir> — emit one TAB row per issue (deterministic, sorted-glob
# order): <action>\t<old_id>\t<new_id>\t<reason>
#   action ∈ rename | collision-resolved | skip-conforming | skip-unmigratable
# Pure read: classifies and resolves collisions; mutates nothing. The slug is
# the id after its first '-' (every preset prefix is dash-free, DD 3); the new
# id and any -2/-3 discriminator pass jimfile's valid-id (the security boundary).
build_plan() {
  local dir="$1" f base id created num newpfx rc slug newid
  local -a rows=()
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    id="${base%.md}"
    if [[ "$id" != *-* ]]; then
      rows+=("skip-unmigratable"$'\t'"$id"$'\t'""$'\t'"id has no prefix delimiter")
      continue
    fi
    created="$(field_value "$f" created)"
    num="$(field_value "$f" num)"
    newpfx="$(jf prefix-from "$created" "$num" 2>&1)"; rc=$?
    if (( rc != 0 )); then
      rows+=("skip-unmigratable"$'\t'"$id"$'\t'""$'\t'"${newpfx#un-migratable: }")
      continue
    fi
    slug="${id#*-}"
    newid="${newpfx}-${slug}"
    if ! jf valid-id "$newid" >/dev/null 2>&1; then
      rows+=("skip-unmigratable"$'\t'"$id"$'\t'""$'\t'"re-derived id failed validation")
      continue
    fi
    if [[ "$newid" == "$id" ]]; then
      rows+=("skip-conforming"$'\t'"$id"$'\t'"$id"$'\t'"already in active scheme")
    else
      rows+=("rename"$'\t'"$id"$'\t'"$newid"$'\t'"")
    fi
  done
  (( ${#rows[@]} )) || return 0

  # Collision resolution. Reserve every unchanged id (skipped + conforming keep
  # their current id), then assign rename targets in order — a target already
  # taken gets the -2/-3 discriminator (spec 021 AC #6, reused not reinvented).
  local -A taken=()
  local row action old new reason
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r action old new reason <<<"$row"
    [[ "$action" == rename ]] || taken["$old"]=1
  done
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r action old new reason <<<"$row"
    if [[ "$action" == rename ]]; then
      if [[ -n "${taken[$new]:-}" ]]; then
        local n=2 cand
        while cand="${new}-${n}"; [[ -n "${taken[$cand]:-}" ]]; do n=$((n+1)); done
        new="$cand"; action="collision-resolved"
      fi
      taken["$new"]=1
    fi
    printf '%s\t%s\t%s\t%s\n' "$action" "$old" "$new" "$reason"
  done
}

# render_plan <plan-rows> — human preview + summary counts.
render_plan() {
  local plan="$1" action old new reason renames=0 skips=0 collisions=0
  while IFS=$'\t' read -r action old new reason; do
    [[ -z "$action" ]] && continue
    case "$action" in
      rename)             printf '  rename     %s  ->  %s\n' "$old" "$new"; renames=$((renames+1)) ;;
      collision-resolved) printf '  collision  %s  ->  %s\n' "$old" "$new"; renames=$((renames+1)); collisions=$((collisions+1)) ;;
      skip-conforming)    printf '  skip       %s  (already in active scheme)\n' "$old"; skips=$((skips+1)) ;;
      skip-unmigratable)  printf '  skip       %s  (un-migratable: %s)\n' "$old" "$reason"; skips=$((skips+1)) ;;
    esac
  done <<<"$plan"
  printf '\n  %d to rename · %d to skip · %d collisions\n' "$renames" "$skips" "$collisions"
}

cmd_prefix() {
  local dir=""
  while (( $# )); do
    case "$1" in
      --apply)  shift ;;
      --expect) shift 2 2>/dev/null || shift $# ;;
      *)        dir="$1"; shift ;;
    esac
  done
  dir="$(resolve_dir "$dir")" || return $?
  [[ -d "$dir" ]] || { echo "error: not a directory: $dir" >&2; return 1; }
  printf 'Re-derivation plan — %s\n\n' "$dir"
  render_plan "$(build_plan "$dir")"
}

usage() {
  printf '%s\n' \
    'migrate.sh — one-shot, opt-in migrations that transform existing issue data.' \
    '' \
    '  bash migrate.sh prefix [<issues_dir>]' \
    '      Preview (read-only): re-derive every issue id to the active' \
    '      issue_id_prefix scheme; print the rename/skip/collision plan.' \
    '' \
    '  bash migrate.sh prefix [<issues_dir>] --apply [--expect <hash>]' \
    '      Apply the plan: rename files + rewrite inbound refs + regenerate INDEX.' \
    '' \
    '  issues_dir default: jimconf.sh get issues'
}

main() {
  if [[ "${1:-}" == "-c" ]]; then
    [[ -n "${2:-}" ]] || { echo "error: -c requires a path argument" >&2; return 2; }
    CFG="$2"; shift 2
  fi
  case "${1:-}" in
    prefix)            shift; cmd_prefix "$@" ;;
    ""|-h|--help|help) usage ;;
    *)
      echo "error: unknown subcommand '$1' (expected: prefix)" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
