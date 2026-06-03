#!/usr/bin/env bash
#
# skills/issue/scripts/render.sh — deterministic read surface for /jim:issue.
#
# PURPOSE
#   The bash dispatcher behind the deterministic /jim:issue verbs. Every
#   verb regenerates INDEX.md defensively, then reads it (and, for `show`,
#   the resolved issue file) and emits a human-friendly view to stdout.
#   Read-only with respect to issue content (AC-R3) — only index.sh's regen
#   writes, and it writes INDEX.md, not issue files.
#
#     render.sh stats [<dir>]            counts + clusters + blocking
#     render.sh list  [<filter>] [<dir>] terse, grouped, configurable view
#     render.sh show  <id> [<dir>]       one issue, cleaned-up
#     render.sh help                     subcommand listing
#
#   <filter> ∈ {open, closed, critical, high, medium, low} — validated
#   against this closed set (security 019 Finding 3); anything else errors.
#   <id> is resolved ONLY against the indexed set of known issues
#   (ordinal / exact slug / prefix / substring) — never composed into a
#   filesystem path from raw input (security 019 Finding 1).
#
# CLI SUMMARY
#   bash render.sh <subcommand> [args] [<issues_dir>]
#     issues_dir default: jimconf.sh get issues
#
# EXIT CODES
#   0  Success (rendering failures degrade to empty sections).
#   1  Validation failure (unknown filter).
#   2  Malformed invocation (unknown subcommand, missing show id).
#

set -uo pipefail
export LC_ALL=C

# ─── Section: Globals ────────────────────────────────────────────────────────

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INDEX_SCRIPT="$HERE/index.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"

readonly INDEX_FILENAME="INDEX.md"
readonly BLOCKING_TOP_N=10
readonly STATUS_TOKENS=(open closed)
readonly PRIORITY_TOKENS=(critical high medium low)
readonly COL_TOKENS=(num date priority status slug labels title)

# ─── Section: Shared helpers ─────────────────────────────────────────────────

# resolve_dir <arg> — arg first, jimconf fallback, trailing-slash strip.
resolve_dir() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then
    dir="$(bash "$JIMCONF" get issues 2>/dev/null)"
  fi
  printf '%s\n' "${dir%/}"
}

# ensure_index <dir> — defensive INDEX.md regen; tolerant of failure.
ensure_index() {
  local dir="$1"
  if [[ -x "$INDEX_SCRIPT" || -r "$INDEX_SCRIPT" ]]; then
    bash "$INDEX_SCRIPT" "$dir" >/dev/null 2>&1 || true
  fi
}

# in_list <needle> <haystack...> — 0 if needle is a member.
in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

is_filter_token() {
  in_list "$1" "${STATUS_TOKENS[@]}" "${PRIORITY_TOKENS[@]}"
}

# cfg_validated <key> <default> <allowed...>
#   Resolve a jimconf key; return it only if it is in the allowed set,
#   otherwise fall back to <default> (security 019 Finding 5).
cfg_validated() {
  local key="$1" def="$2"; shift 2
  local val
  val="$(bash "$JIMCONF" get "$key" 2>/dev/null)"
  if in_list "$val" "$@"; then
    printf '%s' "$val"
  else
    printf '%s' "$def"
  fi
}

# read_issue_rows <index_file>
#   Emit TSV per issue: slug \t num \t status \t priority \t created \t labels \t title \t origin
#   ("-" for any empty field). Parses the INDEX.md ## Issues section only.
read_issue_rows() {
  awk '
    /^## Issues$/ { insec = 1; next }
    /^## / && insec { insec = 0 }
    insec && /^- `/ {
      line = $0
      slug = line; sub(/^- `/, "", slug); sub(/`.*/, "", slug)
      title = line; sub(/^- `[^`]*` — /, "", title); sub(/ · .*/, "", title)
      num = ""; status = ""; prio = ""; created = ""; labels = ""; origin = ""
      n = split(line, parts, / · /)
      for (i = 2; i <= n; i++) {
        kv = parts[i]; key = kv; sub(/:.*/, "", key)
        val = kv; sub(/^[^:]*:[[:space:]]*/, "", val)
        if (key == "num") num = val
        else if (key == "status") status = val
        else if (key == "priority") prio = val
        else if (key == "created") created = val
        else if (key == "origin") origin = val
        else if (key == "labels") { gsub(/^\[|\]$/, "", val); labels = val }
      }
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        slug, (num == "" ? "-" : num), (status == "" ? "open" : status),
        (prio == "" ? "-" : prio), (created == "" ? "-" : created),
        (labels == "" ? "-" : labels), title, (origin == "" ? "-" : origin)
    }
  ' "$1"
}

# ─── Section: help ───────────────────────────────────────────────────────────

cmd_help() {
  cat <<'HELP'
jim issue — capture & review discovery artifacts

  add <subject>           capture a new issue from the conversation
  list [status|priority]  terse list, grouped by status (default)
  stats                   counts + clustering
  show <id>               view a single issue (by number, slug, or prefix)

  Issues live in the configured issues directory. Close one by editing its
  `status:` field directly.
HELP
}

# ─── Section: stats ──────────────────────────────────────────────────────────

cmd_stats() {
  local dir
  dir="$(resolve_dir "${1:-}")"
  if [[ -z "$dir" ]]; then
    echo "Issue Collection — (unconfigured)"
    return 0
  fi
  ensure_index "$dir"
  local index_file="$dir/$INDEX_FILENAME"
  printf 'Issue Collection — %s\n\n' "$dir"
  if [[ ! -f "$index_file" ]]; then
    printf '  Open: 0 · Closed: 0\n\n_No INDEX.md present._\n'
    return 0
  fi

  local open_count closed_count
  open_count=$(grep -E '^- Open: [0-9]+$'   "$index_file" | head -n 1 | sed -E 's/^- Open: //')
  closed_count=$(grep -E '^- Closed: [0-9]+$' "$index_file" | head -n 1 | sed -E 's/^- Closed: //')
  : "${open_count:=0}"; : "${closed_count:=0}"
  printf '  Open: %s · Closed: %s\n\n' "$open_count" "$closed_count"

  printf '== Clusters ==\n\n'
  declare -A origin_count label_count priority_count
  origin_count[__s__]=0;   unset 'origin_count[__s__]'
  label_count[__s__]=0;    unset 'label_count[__s__]'
  priority_count[__s__]=0; unset 'priority_count[__s__]'
  local slug num status prio created labels title origin
  while IFS=$'\t' read -r slug num status prio created labels title origin; do
    [[ -z "$slug" ]] && continue
    [[ "$origin" == "-" || -z "$origin" ]] && origin="(unattributed)"
    origin_count[$origin]=$(( ${origin_count[$origin]:-0} + 1 ))
    if [[ "$prio" != "-" && -n "$prio" ]]; then
      priority_count[$prio]=$(( ${priority_count[$prio]:-0} + 1 ))
    fi
    if [[ "$labels" != "-" && -n "$labels" ]]; then
      local lab lab_arr
      IFS=',' read -ra lab_arr <<< "$labels"
      for lab in "${lab_arr[@]}"; do
        lab="${lab# }"; lab="${lab% }"
        [[ -z "$lab" ]] && continue
        label_count[$lab]=$(( ${label_count[$lab]:-0} + 1 ))
      done
    fi
  done < <(read_issue_rows "$index_file")

  printf '  By priority\n'
  if (( ${#priority_count[@]} == 0 )); then
    printf '    _none_\n'
  else
    local p
    for p in "${PRIORITY_TOKENS[@]}"; do
      [[ -n "${priority_count[$p]:-}" ]] && printf '    %-12s %d\n' "$p" "${priority_count[$p]}"
    done
  fi

  printf '\n  By origin\n'
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

  printf '== Blocking ==\n\n'
  declare -A blocks_out blocks_targets
  blocks_out[__s__]=0;     unset 'blocks_out[__s__]'
  blocks_targets[__s__]=""; unset 'blocks_targets[__s__]'
  local row edge_src edge_tgt
  while IFS= read -r row; do
    [[ "$row" =~ ^-\ \`([a-z0-9-]+)\`\ --blocks--\>\ \`([a-z0-9-]+)\`$ ]] || continue
    edge_src="${BASH_REMATCH[1]}"; edge_tgt="${BASH_REMATCH[2]}"
    blocks_out[$edge_src]=$(( ${blocks_out[$edge_src]:-0} + 1 ))
    blocks_targets[$edge_src]="${blocks_targets[$edge_src]:-} $edge_tgt"
  done < <(awk '
    /^## Graph$/ { insec=1; next }
    /^## / && insec { insec=0 }
    insec && /^- `/ { print }
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

  local warnings_block
  warnings_block=$(awk '/^## Integrity Warnings$/,EOF' "$index_file" | sed -n '2,$p' | grep -E '^- ')
  if [[ -n "$warnings_block" ]]; then
    printf '== Integrity Warnings ==\n\n'
    printf '%s\n' "$warnings_block"
  fi
}

# ─── Section: list ───────────────────────────────────────────────────────────

# format_row <cols-csv> <slug> <num> <status> <priority> <created> <labels> <title>
format_row() {
  local cols="$1" slug="$2" num="$3" status="$4" prio="$5" created="$6" labels="$7" title="$8"
  local out="" c
  IFS=',' read -ra _cols <<< "$cols"
  for c in "${_cols[@]}"; do
    case "$c" in
      num)      out+=$(printf '#%-5s' "${num}") ;;
      date)     out+=$(printf '%-12s' "$created") ;;
      priority) out+=$(printf '%-9s' "$prio") ;;
      status)   out+=$(printf '%-8s' "$status") ;;
      slug)     out+="$slug " ;;
      title)    out+="$title " ;;
      labels)   out+="[$labels] " ;;
    esac
    out+=" "
  done
  printf '  %s\n' "$out"
}

cmd_list() {
  local filter="" dir=""
  if [[ $# -eq 2 ]]; then
    filter="$1"; dir="$2"
  elif [[ $# -eq 1 ]]; then
    if is_filter_token "$1"; then filter="$1"; else dir="$1"; fi
  fi
  if [[ -n "$filter" ]] && ! is_filter_token "$filter"; then
    echo "error: unknown filter '$filter' (valid: ${STATUS_TOKENS[*]} ${PRIORITY_TOKENS[*]})" >&2
    return 1
  fi
  dir="$(resolve_dir "$dir")"
  ensure_index "$dir"
  local index_file="$dir/$INDEX_FILENAME"
  printf 'Issues — %s\n\n' "$dir"
  [[ -f "$index_file" ]] || { printf '_No issues._\n'; return 0; }

  local group sort cols
  group="$(cfg_validated issue_list_group status status priority origin none)"
  sort="$(cfg_validated issue_list_sort date date priority num)"
  cols="$(bash "$JIMCONF" get issue_list_cols 2>/dev/null)"
  # Validate every column token; fall back to the default set on any unknown.
  local _c _ok=1 _carr
  IFS=',' read -ra _carr <<< "$cols"
  for _c in "${_carr[@]}"; do in_list "$_c" "${COL_TOKENS[@]}" || _ok=0; done
  [[ "$_ok" == 1 && -n "$cols" ]] || cols="num,date,priority,slug"

  # Load rows, applying the filter.
  local rows=() slug num status prio created labels title origin
  while IFS=$'\t' read -r slug num status prio created labels title origin; do
    [[ -z "$slug" ]] && continue
    if [[ -n "$filter" ]]; then
      if in_list "$filter" "${STATUS_TOKENS[@]}"; then
        [[ "$status" == "$filter" ]] || continue
      else
        [[ "$prio" == "$filter" ]] || continue
      fi
    fi
    rows+=("$slug"$'\t'"$num"$'\t'"$status"$'\t'"$prio"$'\t'"$created"$'\t'"$labels"$'\t'"$title")
  done < <(read_issue_rows "$index_file")

  if (( ${#rows[@]} == 0 )); then
    printf '_No matching issues._\n'
    return 0
  fi

  # Determine group order.
  local group_values=()
  case "$group" in
    status)   group_values=("${STATUS_TOKENS[@]}") ;;
    priority) group_values=("${PRIORITY_TOKENS[@]}") ;;
    none|origin)
      # `none` is a flat list; `origin` degrades to flat here because the
      # list rows carry no origin column (origin lives in stats clustering).
      group_values=("__all__")
      ;;
  esac

  # sort key for `sort` command on the row TSV:
  #   date → field 5 (created) desc; num → field 2 desc; priority → custom rank.
  sort_rows() {
    case "$sort" in
      num)  sort -t$'\t' -k2,2nr ;;
      date) sort -t$'\t' -k5,5r ;;
      priority)
        awk -F'\t' 'BEGIN{r["critical"]=0;r["high"]=1;r["medium"]=2;r["low"]=3}
          {k=($4 in r)?r[$4]:9; print k"\t"$0}' \
          | sort -t$'\t' -k1,1n | cut -f2-
        ;;
      *) cat ;;
    esac
  }

  local gv printed_any=0
  for gv in "${group_values[@]}"; do
    local group_rows=() r rstatus
    for r in "${rows[@]}"; do
      if [[ "$gv" == "__all__" ]]; then
        group_rows+=("$r")
      else
        case "$group" in
          status)   [[ "$(printf '%s' "$r" | cut -f3)" == "$gv" ]] && group_rows+=("$r") ;;
          priority) [[ "$(printf '%s' "$r" | cut -f4)" == "$gv" ]] && group_rows+=("$r") ;;
        esac
      fi
    done
    (( ${#group_rows[@]} == 0 )) && continue
    if [[ "$gv" != "__all__" ]]; then
      printf '%s (%d)\n' "$gv" "${#group_rows[@]}"
    fi
    local sorted
    sorted="$(printf '%s\n' "${group_rows[@]}" | sort_rows)"
    while IFS=$'\t' read -r slug num status prio created labels title; do
      [[ -z "$slug" ]] && continue
      format_row "$cols" "$slug" "$num" "$status" "$prio" "$created" "$labels" "$title"
    done <<< "$sorted"
    printf '\n'
    printed_any=1
  done
  (( printed_any == 0 )) && printf '_No matching issues._\n'
  return 0
}

# ─── Section: show ───────────────────────────────────────────────────────────

is_valid_slug() {
  local slug="$1"
  [[ -z "$slug" ]] && return 1
  [[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

# render_issue_file <dir> <slug>
render_issue_file() {
  local dir="$1" slug="$2"
  is_valid_slug "$slug" || { echo "error: refusing to read invalid slug" >&2; return 1; }
  local f="$dir/$slug.md"
  [[ -f "$f" ]] || { printf 'no issue file for `%s`.\n' "$slug"; return 0; }
  local fm num title status prio labels origin created
  fm="$(awk '/^---$/{c++; if(c==2) exit; if(c==1) next} c==1{print}' "$f")"
  field() { printf '%s\n' "$fm" | grep -E "^$1:" | head -n1 | sed -E "s/^$1:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"; }
  num="$(field num)"; title="$(field title)"; status="$(field status)"
  prio="$(field priority)"; labels="$(field labels)"; origin="$(field origin)"; created="$(field created)"
  printf '#%s · %s\n' "${num:--}" "$slug"
  printf '%s\n' "${title}"
  printf '  status: %s   priority: %s\n' "${status:-open}" "${prio:--}"
  [[ -n "$labels" ]] && printf '  labels: %s\n' "$labels"
  [[ -n "$origin" ]] && printf '  origin: %s\n' "$origin"
  [[ -n "$created" ]] && printf '  created: %s\n' "$created"
  printf '\n'
  # Body: everything after the second ---.
  awk '/^---$/{c++; next} c>=2{print}' "$f"
}

cmd_show() {
  local id="${1:-}" dir="${2:-}"
  if [[ -z "$id" ]]; then
    echo "error: 'show' requires an id (number, slug, or prefix)" >&2
    return 2
  fi
  dir="$(resolve_dir "$dir")"
  ensure_index "$dir"
  local index_file="$dir/$INDEX_FILENAME"
  [[ -f "$index_file" ]] || { printf 'no issue matched `%s`.\n' "$id"; return 0; }

  # Build slug/num table from the indexed set only.
  local slugs=() nums=() slug num rest
  while IFS=$'\t' read -r slug num rest; do
    [[ -z "$slug" ]] && continue
    slugs+=("$slug"); nums+=("$num")
  done < <(read_issue_rows "$index_file")

  local matches=() i
  if [[ "$id" =~ ^[0-9]+$ ]]; then
    for i in "${!slugs[@]}"; do
      [[ "${nums[$i]}" == "$id" ]] && matches+=("${slugs[$i]}")
    done
  else
    # exact slug
    for i in "${!slugs[@]}"; do [[ "${slugs[$i]}" == "$id" ]] && matches+=("${slugs[$i]}"); done
    # prefix
    if (( ${#matches[@]} == 0 )); then
      for i in "${!slugs[@]}"; do [[ "${slugs[$i]}" == "$id"* ]] && matches+=("${slugs[$i]}"); done
    fi
    # substring
    if (( ${#matches[@]} == 0 )); then
      for i in "${!slugs[@]}"; do [[ "${slugs[$i]}" == *"$id"* ]] && matches+=("${slugs[$i]}"); done
    fi
  fi

  if (( ${#matches[@]} == 0 )); then
    printf 'no issue matched `%s`.\n' "$id"
    return 0
  elif (( ${#matches[@]} == 1 )); then
    render_issue_file "$dir" "${matches[0]}"
    return 0
  else
    printf 'Multiple issues match `%s`:\n' "$id"
    local m
    for m in "${matches[@]}"; do printf '  - %s\n' "$m"; done
    printf '\nRe-run `show` with a more specific id.\n'
    return 0
  fi
}

# ─── Section: Dispatch ───────────────────────────────────────────────────────

main() {
  local sub="${1:-help}"
  [[ $# -gt 0 ]] && shift
  case "$sub" in
    stats) cmd_stats "$@" ;;
    list)  cmd_list  "$@" ;;
    show)  cmd_show  "$@" ;;
    help|-h|--help) cmd_help ;;
    *)
      echo "error: unknown subcommand '$sub' (valid: stats list show help)" >&2
      cmd_help >&2
      return 2
      ;;
  esac
}

main "$@"
