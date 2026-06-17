#!/usr/bin/env bash
#
# skills/issue/scripts/render.sh — deterministic read surface for /jim:issue.
#
# PURPOSE
#   The bash dispatcher behind the deterministic /jim:issue verbs. Every
#   verb regenerates INDEX.md only when it is stale (missing, or an issue
#   file was added/removed/edited — see ensure_index), then reads it (and,
#   for `show`, the resolved issue file) and emits a human-friendly view to
#   stdout. A fresh index is reused as-is, so a read over an unchanged
#   collection costs a stat-based staleness check rather than a full rescan.
#   Read-only with respect to issue content (AC-R3) — only index.sh's regen
#   writes, and it writes INDEX.md, not issue files.
#
#     render.sh stats [<dir>]            counts + clusters + blocking
#     render.sh list  [<filter>] [<dir>] terse, grouped, configurable view
#     render.sh show  <id> [<dir>]       one issue, cleaned-up
#     render.sh insights-graph [<dir>]   graph facts for the issue-analyst
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

# index_is_stale <dir> <index_file>
#   Return 0 (stale → regen) when INDEX.md is missing, an issue file was
#   edited (a .md file is newer than the index), or one was added/removed
#   (the directory entry is newer than the index). index.sh touches INDEX.md
#   as its final step, so a freshly built index is the newest entry in the
#   dir and none of these fire. Return 1 (fresh → reuse) otherwise.
index_is_stale() {
  local dir="$1" index_file="$2"
  [[ -f "$index_file" ]] || return 0
  # dir entry newer than index → a file was added or removed (mv/rm/create
  # all bump the directory mtime; an in-place edit does not).
  [[ "$dir" -nt "$index_file" ]] && return 0
  # any issue file newer than index → an issue was edited in place. Capture
  # find's output rather than piping to `grep -q` so a SIGPIPE-on-find exit
  # cannot trip `set -o pipefail`.
  local newer
  newer="$(find "$dir" -maxdepth 1 -name '*.md' ! -name "$INDEX_FILENAME" -newer "$index_file" 2>/dev/null | head -n1)"
  [[ -n "$newer" ]] && return 0
  return 1
}

# ensure_index <dir> — regen INDEX.md only when stale; tolerant of failure.
#   A fresh index is reused as-is, turning a read verb from a full directory
#   rescan (one process per scalar field per issue) into a single stat-based
#   staleness check. Regen still fires whenever an issue is added, removed, or
#   edited, so reads never serve a stale view.
ensure_index() {
  local dir="$1"
  index_is_stale "$dir" "$dir/$INDEX_FILENAME" || return 0
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

# cfg_validated <value> <default> <allowed...>
#   Return <value> if it is a member of the allowed set, otherwise fall back
#   to <default> (security 019 Finding 5). The caller resolves <value> from
#   the single config blob (see cmd_list) — this validates, it does not fetch.
cfg_validated() {
  local val="$1" def="$2"; shift 2
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
      # SYNC(ts-shape): ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$
      # Degrade a non-conforming created so malformed frontmatter can never
      # corrupt the TSV (embedded tab/garbage): keep the day-start date prefix
      # when present, else empty (rendered "-"). Spec 022 AC #8 / Finding F6.
      if (created != "" && created !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$/) {
        if (match(created, /^[0-9]{4}-[0-9]{2}-[0-9]{2}/))
          created = substr(created, RSTART, RLENGTH)
        else
          created = ""
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
  insights                LLM analysis: convergence, sequencing, parallel work

  Issues live in the configured issues directory. Close one by editing its
  `status:` field directly.

  By default `list` hides closed issues; use `list closed` to see them, or set
  `issue_list_closed = "true"` in jimconf.toml to include them in every view.
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
#   Fixed-width columns are formatted with `printf -v` (into a scratch var)
#   rather than `out+=$(printf …)` — the latter forks a subshell per column per
#   row, which dominates list cost on larger collections.
format_row() {
  local cols="$1" slug="$2" num="$3" status="$4" prio="$5" created="$6" labels="$7" title="$8"
  local out="" c pad
  IFS=',' read -ra _cols <<< "$cols"
  for c in "${_cols[@]}"; do
    case "$c" in
      num)      printf -v pad '#%-5s' "$num";     out+=$pad ;;
      # date portion only; sub-day precision drives sort + shows in `show`.
      date)     printf -v pad '%-12s' "${created:0:10}"; out+=$pad ;;
      priority) printf -v pad '%-9s' "$prio";     out+=$pad ;;
      status)   printf -v pad '%-8s' "$status";   out+=$pad ;;
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

  # Resolve all issue_list_* config in ONE jimconf invocation. jimconf has no
  # batch `get`, but `list` emits every key=value (defaults already applied) in
  # a single process; parsing that blob into an assoc array is pure bash, so
  # the four keys cost one fork total instead of one external process each.
  local group sort cols order cfg_blob _k _v
  local -A _cfg=()
  cfg_blob="$(bash "$JIMCONF" list 2>/dev/null)"
  while IFS='=' read -r _k _v; do
    [[ -n "$_k" ]] && _cfg["$_k"]="$_v"
  done <<< "$cfg_blob"
  group="$(cfg_validated "${_cfg[issue_list_group]:-}" status status priority origin none)"
  sort="$(cfg_validated "${_cfg[issue_list_sort]:-}" date date priority num)"
  order="$(cfg_validated "${_cfg[issue_list_order]:-}" desc desc asc)"
  local show_closed
  show_closed="$(cfg_validated "${_cfg[issue_list_closed]:-}" false false true)"
  cols="${_cfg[issue_list_cols]:-}"

  # Hide closed issues from the default and priority-filtered views unless the
  # issue_list_closed toggle opts them in. An explicit status filter
  # (`list open` / `list closed`) is the user being deliberate about status, so
  # it always overrides the toggle — `list closed` is the ad-hoc closed view.
  local hide_closed=0
  if ! in_list "$filter" "${STATUS_TOKENS[@]}" && [[ "$show_closed" != "true" ]]; then
    hide_closed=1
  fi
  # Validate every column token; fall back to the default set on any unknown.
  local _c _ok=1 _carr
  IFS=',' read -ra _carr <<< "$cols"
  for _c in "${_carr[@]}"; do in_list "$_c" "${COL_TOKENS[@]}" || _ok=0; done
  [[ "$_ok" == 1 && -n "$cols" ]] || cols="num,date,priority,slug"

  # Load rows, applying the filter.
  local rows=() slug num status prio created labels title origin
  while IFS=$'\t' read -r slug num status prio created labels title origin; do
    [[ -z "$slug" ]] && continue
    [[ "$hide_closed" == 1 && "$status" == "closed" ]] && continue
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

  # sort key for `sort` command on the row TSV. `order` (desc default | asc)
  #   flips the primary direction; same-day ties always break by num in the
  #   primary direction so a batch stays monotonic.
  #     date → field 5 (created); num → field 2; priority → severity rank.
  local rflag="r"           # desc → reverse
  [[ "$order" == "asc" ]] && rflag=""
  sort_rows() {
    case "$sort" in
      num)  sort -t$'\t' -k2,2n${rflag} ;;
      date) sort -t$'\t' -k5,5${rflag} -k2,2n${rflag} ;;
      priority)
        # Rank critical=0 … low=3. desc (default) = most severe first
        # (ascending rank); asc = least severe first (descending rank).
        awk -F'\t' 'BEGIN{r["critical"]=0;r["high"]=1;r["medium"]=2;r["low"]=3}
          {k=($4 in r)?r[$4]:9; print k"\t"$0}' \
          | sort -t$'\t' -k1,1n${rflag} | cut -f2-
        ;;
      *) cat ;;
    esac
  }

  local gv printed_any=0
  for gv in "${group_values[@]}"; do
    local group_rows=() r rstatus rprio
    for r in "${rows[@]}"; do
      if [[ "$gv" == "__all__" ]]; then
        group_rows+=("$r")
      else
        # Split the TAB-packed row in-shell (read is a builtin — no subshell)
        # rather than forking `printf | cut` per row per group value. Fields:
        # slug \t num \t status \t prio \t created \t labels \t title; status
        # and prio are always populated, so no IFS-collapse on those columns.
        IFS=$'\t' read -r _ _ rstatus rprio _ <<< "$r"
        case "$group" in
          status)   [[ "$rstatus" == "$gv" ]] && group_rows+=("$r") ;;
          priority) [[ "$rprio"   == "$gv" ]] && group_rows+=("$r") ;;
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

# is_valid_id <id>
#   Bounded allowlist for a full issue id (spec 021 AC #7, AC #11).
#   SYNC: the function body below is byte-identical to the copies in
#   skills/file/scripts/jimfile.sh and skills/issue/scripts/index.sh — a
#   tests/jimfile.sh case asserts the three agree. Keep them in lockstep.
is_valid_id() {
  local id="$1"
  if [[ -z "$id" ]]; then
    echo "error: id rejected — empty" >&2
    return 1
  fi
  if (( ${#id} > 128 )); then
    echo "error: id rejected — exceeds 128 characters" >&2
    return 1
  fi
  if [[ "$id" == *..* ]]; then
    echo "error: id rejected — '$id' contains '..'" >&2
    return 1
  fi
  if [[ ! "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "error: id rejected — '$id' (allowed: ^[A-Za-z0-9][A-Za-z0-9._-]*$)" >&2
    return 1
  fi
  return 0
}

# render_issue_file <dir> <slug>
render_issue_file() {
  local dir="$1" slug="$2"
  is_valid_id "$slug" 2>/dev/null || { echo "error: refusing to read invalid id" >&2; return 1; }
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

# ─── Section: insights-graph ─────────────────────────────────────────────────

# cmd_insights_graph [<dir>] — deterministic graph facts for the issue-analyst
# subagent (spec 020). Emits to stdout (LC_ALL=C stable ordering):
#   ISOLATED <slug>          one per OPEN issue in no blocks/depends-on edge
#   BLOCKING <count> <slug>  blocking out-degree per source, count desc then slug
# Read-only; exit 0 always (degrades to empty output on an absent/empty index).
cmd_insights_graph() {
  local dir
  dir="$(resolve_dir "${1:-}")"
  [[ -z "$dir" ]] && return 0
  ensure_index "$dir"
  local index_file="$dir/$INDEX_FILENAME"
  [[ -f "$index_file" ]] || return 0

  declare -A is_open
  local slug num status prio created labels title origin
  while IFS=$'\t' read -r slug num status prio created labels title origin; do
    [[ -z "$slug" ]] && continue
    [[ "$status" == "open" ]] && is_open[$slug]=1
  done < <(read_issue_rows "$index_file")

  # blocks / depends-on edges → endpoints (non-isolated) + blocking out-degree.
  # related-to and duplicates are ordering-neutral and ignored (spec 020 AC5).
  declare -A related blocks_out
  local row etype esrc etgt
  while IFS= read -r row; do
    [[ "$row" =~ ^-\ \`([a-z0-9-]+)\`\ --(blocks|depends-on)--\>\ \`([a-z0-9-]+)\`$ ]] || continue
    esrc="${BASH_REMATCH[1]}"; etype="${BASH_REMATCH[2]}"; etgt="${BASH_REMATCH[3]}"
    related[$esrc]=1; related[$etgt]=1
    [[ "$etype" == "blocks" ]] && blocks_out[$esrc]=$(( ${blocks_out[$esrc]:-0} + 1 ))
  done < <(awk '
    /^## Graph$/ { insec=1; next }
    /^## / && insec { insec=0 }
    insec && /^- `/ { print }
  ' "$index_file")

  local s
  for s in "${!is_open[@]}"; do
    [[ -n "${related[$s]:-}" ]] && continue
    printf 'ISOLATED %s\n' "$s"
  done | sort

  for s in "${!blocks_out[@]}"; do
    printf 'BLOCKING %d %s\n' "${blocks_out[$s]}" "$s"
  done | sort -k2,2nr -k3,3
}

# ─── Section: Dispatch ───────────────────────────────────────────────────────

main() {
  local sub="${1:-help}"
  [[ $# -gt 0 ]] && shift
  case "$sub" in
    stats) cmd_stats "$@" ;;
    list)  cmd_list  "$@" ;;
    show)  cmd_show  "$@" ;;
    insights-graph) cmd_insights_graph "$@" ;;
    help|-h|--help) cmd_help ;;
    *)
      echo "error: unknown subcommand '$sub' (valid: stats list show insights-graph help)" >&2
      cmd_help >&2
      return 2
      ;;
  esac
}

main "$@"
