#!/usr/bin/env bash
#
# skills/issues/scripts/render.sh — Trend view over the jim issue collection.
#
# PURPOSE
#   /jim:issues read-side wrapper. Runs index.sh defensively, then reads the
#   resulting INDEX.md and emits a human-friendly summary to stdout:
#
#     Issue Collection — <dir>
#
#       Open: <N> · Closed: <N>
#
#     == Clusters ==
#
#       By origin
#         <origin-path>   <count>
#
#       By label
#         <label>         <count>
#
#     == Blocking ==
#
#       <slug>
#         blocks <N> issues
#           - <target>
#
#     == Integrity Warnings ==
#       (only when present)
#
#   Read-only: render.sh never mutates the collection (AC-R3). All emission
#   goes to stdout; index.sh's regen writes INDEX.md.
#
# CLI SUMMARY
#   bash render.sh [<issues_dir>]
#     issues_dir default: jimconf.sh get issues
#
# EXIT CODES
#   0  Always — rendering failures degrade to empty sections.
#

set -uo pipefail
export LC_ALL=C

# ─── Section: Globals ────────────────────────────────────────────────────────

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INDEX_SCRIPT="$HERE/index.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"

readonly INDEX_FILENAME="INDEX.md"
readonly BLOCKING_TOP_N=10

# ─── Section: Helpers ────────────────────────────────────────────────────────

# resolve_dir <arg>
#   Same as index.sh — arg first, jimconf fallback, trailing-slash strip.
resolve_dir() {
  local arg="$1"
  local dir="$arg"
  if [[ -z "$dir" ]]; then
    dir="$(bash "$JIMCONF" get issues 2>/dev/null)"
  fi
  printf '%s\n' "${dir%/}"
}

# ─── Section: Main ───────────────────────────────────────────────────────────

main() {
  local arg="${1:-}"
  local dir
  dir="$(resolve_dir "$arg")"
  if [[ -z "$dir" ]]; then
    echo "Issue Collection — (unconfigured)"
    return 0
  fi

  # Defensive regen — index.sh handles missing dir, bad files, etc.
  if [[ -x "$INDEX_SCRIPT" || -r "$INDEX_SCRIPT" ]]; then
    bash "$INDEX_SCRIPT" "$dir" >/dev/null 2>&1 || true
  fi

  local index_file="$dir/$INDEX_FILENAME"
  printf 'Issue Collection — %s\n\n' "$dir"

  if [[ ! -f "$index_file" ]]; then
    printf '  Open: 0 · Closed: 0\n\n_No INDEX.md present._\n'
    return 0
  fi

  # ── Summary line: extract Open/Closed counts from INDEX.md ──
  local open_count closed_count
  open_count=$(grep -E '^- Open: [0-9]+$'   "$index_file" | head -n 1 | sed -E 's/^- Open: //')
  closed_count=$(grep -E '^- Closed: [0-9]+$' "$index_file" | head -n 1 | sed -E 's/^- Closed: //')
  : "${open_count:=0}"
  : "${closed_count:=0}"
  printf '  Open: %s · Closed: %s\n\n' "$open_count" "$closed_count"

  # ── Clusters ──
  # Parse the Issues section: each row is
  #   - `<slug>` — <title> · status: <s> · priority: <p> · labels: <l> · origin: <o>
  printf '== Clusters ==\n\n'

  declare -A origin_count label_count
  # Bash 5+ under set -u trips on ${#assoc[@]} for never-touched associative
  # arrays. A sentinel write+unset puts them in a defined-but-empty state.
  origin_count[__sentinel__]=0; unset 'origin_count[__sentinel__]'
  label_count[__sentinel__]=0;  unset 'label_count[__sentinel__]'
  local row
  while IFS= read -r row; do
    [[ "$row" =~ ^-\ \`([a-z0-9][a-z0-9-]*)\`\ —\  ]] || continue
    # Extract origin: text after "origin: " up to end of line
    local origin labels
    origin=$(printf '%s\n' "$row" | sed -nE 's/.* origin: ([^ ·]+).*$/\1/p')
    labels=$(printf '%s\n' "$row" | sed -nE 's/.* labels: \[([^]]*)\].*$/\1/p')
    [[ -z "$origin" ]] && origin="(unattributed)"
    origin_count[$origin]=$(( ${origin_count[$origin]:-0} + 1 ))
    if [[ -n "$labels" ]]; then
      local lab
      IFS=',' read -ra lab_arr <<< "$labels"
      for lab in "${lab_arr[@]}"; do
        lab="${lab# }"; lab="${lab% }"
        [[ -z "$lab" ]] && continue
        label_count[$lab]=$(( ${label_count[$lab]:-0} + 1 ))
      done
    fi
  done < <(awk '
    /^## Issues$/ { in_section=1; next }
    /^## / && in_section { in_section=0 }
    in_section && /^- `/ { print }
  ' "$index_file")

  printf '  By origin\n'
  if (( ${#origin_count[@]} == 0 )); then
    printf '    _none_\n'
  else
    local k
    for k in "${!origin_count[@]}"; do
      printf '    %-50s %d\n' "$k" "${origin_count[$k]}"
    done | sort -k2,2nr -k1,1
  fi
  printf '\n  By label\n'
  if (( ${#label_count[@]} == 0 )); then
    printf '    _none_\n'
  else
    local k
    for k in "${!label_count[@]}"; do
      printf '    %-20s %d\n' "$k" "${label_count[$k]}"
    done | sort -k2,2nr -k1,1
  fi
  printf '\n'

  # ── Blocking ──
  # Parse Graph section: each edge "- `<src>` --<type>--> `<tgt>`"
  # Count outgoing blocks per source; show top-N.
  printf '== Blocking ==\n\n'
  declare -A blocks_out
  declare -A blocks_targets
  blocks_out[__sentinel__]=0;     unset 'blocks_out[__sentinel__]'
  blocks_targets[__sentinel__]=""; unset 'blocks_targets[__sentinel__]'
  local edge_src edge_tgt
  while IFS= read -r row; do
    [[ "$row" =~ ^-\ \`([a-z0-9-]+)\`\ --blocks--\>\ \`([a-z0-9-]+)\`$ ]] || continue
    edge_src="${BASH_REMATCH[1]}"
    edge_tgt="${BASH_REMATCH[2]}"
    blocks_out[$edge_src]=$(( ${blocks_out[$edge_src]:-0} + 1 ))
    blocks_targets[$edge_src]="${blocks_targets[$edge_src]:-} $edge_tgt"
  done < <(awk '
    /^## Graph$/ { in_section=1; next }
    /^## / && in_section { in_section=0 }
    in_section && /^- `/ { print }
  ' "$index_file")

  if (( ${#blocks_out[@]} == 0 )); then
    printf '  _No blocking edges._\n\n'
  else
    local s
    for s in "${!blocks_out[@]}"; do
      printf '%d\t%s\n' "${blocks_out[$s]}" "$s"
    done | sort -k1,1nr -k2,2 | head -n "$BLOCKING_TOP_N" | while IFS=$'\t' read -r count src; do
      printf '  %s\n    blocks %s issues\n' "$src" "$count"
      local tgt
      for tgt in ${blocks_targets[$src]}; do
        printf '      - %s\n' "$tgt"
      done
    done
    printf '\n'
  fi

  # ── Integrity Warnings (passthrough if any) ──
  local warnings_block
  warnings_block=$(awk '/^## Integrity Warnings$/,EOF' "$index_file" \
    | sed -n '2,$p' \
    | grep -E '^- ')
  if [[ -n "$warnings_block" ]]; then
    printf '== Integrity Warnings ==\n\n'
    printf '%s\n' "$warnings_block"
  fi
}

main "$@"
