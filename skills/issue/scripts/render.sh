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
#   When the regeneration fails, the prior index is still served — a
#   stale-but-valid view beats no answer on a read surface — but the run says
#   so on stderr and exits non-zero. The group's rule is that a view known to
#   be out of date is never reported as success: reconcile.sh carries the same
#   failure the same way, and place.sh refuses outright on the write path,
#   where the stale index would reach the shared branch.
#
#     render.sh stats [<dir>]            counts + clusters + blocking
#     render.sh list  [<filter>] [<dir>] terse, grouped, configurable view
#     render.sh show  <id> [<dir>]       one issue, cleaned-up
#     render.sh insights-graph [<dir>]   graph facts for the issue-analyst
#     render.sh help                     subcommand listing
#
#   <filter> ∈ {open, active, closed, critical, high, medium, low} — validated
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
#   1  Validation failure (unknown filter), or the view was served from an
#      index that is stale and could not be regenerated — stdout still carries
#      it, and stderr says which directory.
#   2  Malformed invocation (unknown subcommand, missing show id).
#

set -uo pipefail
export LC_ALL=C

# ─── Section: Globals ────────────────────────────────────────────────────────

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INDEX_SCRIPT="$HERE/index.sh"
IDENTITY_SCRIPT="$HERE/identity.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"

readonly INDEX_FILENAME="INDEX.md"
readonly BLOCKING_TOP_N=10
# Set when a verb served a view it knew was out of date. It degrades the run's
# exit status without suppressing the view, so a caller is told what a reader
# cannot see for itself.
STALE_VIEW=0
# The three lifecycle states, in lifecycle order: not started, underway,
# finished. This list is the single source for the `list` filter's accepted
# status tokens, for the default view's hide rule, and for the order status
# groups render in — so a state absent from it is one that passes the filter
# and then vanishes at grouping time.
readonly STATUS_TOKENS=(open active closed)
readonly PRIORITY_TOKENS=(critical high medium low)
readonly COL_TOKENS=(num date priority status slug labels title
                     type filed-by claimed-by outcome)
readonly TYPE_TOKENS=(issue epic)
readonly HELD_TOKENS=(claimed unclaimed)
readonly BLOCKED_TOKENS=(blocked unblocked)

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

# ensure_index <dir> — regen INDEX.md when stale, and disclose when it cannot.
#   A fresh index is reused as-is, turning a read verb from a full directory
#   rescan (one process per scalar field per issue) into a single stat-based
#   staleness check. Regen fires whenever an issue is added, removed, or edited.
#
#   When it fires and fails, the prior index is still the best view available,
#   so the read is served from it rather than refused. What does not happen is
#   reporting success: staleness was established one line above, so serving
#   quietly at rc 0 would state a currency the run knows it does not have. The
#   note names the directory because a placement routes reads through a
#   materialized copy, whose path is not the one the caller asked about.
ensure_index() {
  local dir="$1"
  # A read never brings a collection into being. `index.sh` mkdir -p's whatever
  # directory it is handed and every verb here regenerates through this one
  # function, so without this a mistyped filter or a steered argument got a
  # directory and an INDEX.md created for it, by a read, in the developer's
  # checkout. It is also the capability the analyst's agent definition states is
  # absent rather than merely forbidden — and an absent collection has nothing to
  # serve, which each caller already handles as "no issues".
  [[ -d "$dir" ]] || return 0
  index_is_stale "$dir" "$dir/$INDEX_FILENAME" || return 0
  if [[ -x "$INDEX_SCRIPT" || -r "$INDEX_SCRIPT" ]]; then
    bash "$INDEX_SCRIPT" "$dir" >/dev/null 2>&1 && return 0
  fi
  echo "warning: the index for '$dir' is stale and could not be regenerated;" \
       "serving the view it already held" >&2
  STALE_VIEW=1
  return 1
}

# in_list <needle> <haystack...> — 0 if needle is a member.
in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

is_filter_token() {
  in_list "$1" "${STATUS_TOKENS[@]}" "${PRIORITY_TOKENS[@]}" \
               "${TYPE_TOKENS[@]}" "${HELD_TOKENS[@]}" "${BLOCKED_TOKENS[@]}"
}

# The option names this file's filter parser accepts. An operand equal to one
# of these is a flag that landed where a value belongs — a typo rather than a
# value. See need_operand.
readonly RENDER_OPTIONS=(--status --priority --type --label --epic
                         --filed-by --claimed-by --spec --origin --cols)

# need_operand <flag> <argc> <operand> — the value <flag> requires, or refuse.
#   <argc> is the argument count remaining at the flag, so a flag standing last
#   in the argv is one with nothing to take.
#
#   Absent, empty, and flag-shaped operands all refuse. Swallowing one costs
#   twice over: the flag that was consumed goes unapplied, and the value it
#   became is one nobody typed — and on a read surface both halves are silent,
#   because a narrower query and a query that matched little look the same.
#
#   Only this file's own option names are refused. A value that merely looks
#   option-shaped is carried through, because the recordable-identity set
#   admits a leading hyphen deliberately and a real address can wear one.
#
#   SYNC(need-operand): a shape sibling of need_operand in
#   skills/issue/scripts/migrate.sh, deliberately NOT byte-identical — each
#   script refuses its own option list, and the two lists are disjoint. What
#   the two share is the rule, not the text: absent, empty and own-flag
#   operands refuse at status 2 having written nothing to stdout. A
#   byte-agreement fixture would assert a falsehood here, so there is none;
#   this note is what keeps the difference from reading as drift.
need_operand() {
  local flag="$1" argc="$2" operand="$3" known
  if (( argc < 2 )) || [[ -z "$operand" ]]; then
    echo "error: $flag requires a value" >&2
    return 2
  fi
  for known in "${RENDER_OPTIONS[@]}"; do
    if [[ "$operand" == "$known" ]]; then
      echo "error: $flag requires a value, but $known followed it" >&2
      return 2
    fi
  done
  printf '%s' "$operand"
}

# ─── Section: The filter grammar ─────────────────────────────────────────────

# token_safe <token> — an operator token bounded and stripped, for stderr.
#   The discipline row_safe applies to a value written into the index, applied
#   to the other surface that renders untrusted-shaped text. A token arriving
#   through argv is no safer than one arriving through a file, and a terminal
#   is a terminal either way. The separator deletion row_safe also does is
#   absent here on purpose — nothing parses a refusal — so the two functions
#   are siblings in intent rather than copies, and neither claims the other.
token_safe() {
  printf '%s' "$1" | tr -d '\000-\037\177' | cut -c1-64
}

# bare_word_help — the reserved vocabularies, as a refusal's second half.
bare_word_help() {
  echo "       bare words are one of:" >&2
  echo "         ${STATUS_TOKENS[*]} · ${PRIORITY_TOKENS[*]} · ${TYPE_TOKENS[*]}" >&2
  echo "         ${HELD_TOKENS[*]} · ${BLOCKED_TOKENS[*]}" >&2
}

# filter_axis_add <axis> <csv> — record one flag's or bare word's alternatives.
#   The comma is the operator's own separator, so it is the only one applied.
#   Alternatives are stored newline-separated: a value can legitimately carry a
#   space — an origin prefix is free text — and splitting on one would widen a
#   query the operator narrowed, which is the failure quoting the prefix
#   comparison exists to prevent, arriving one step earlier.
filter_axis_add() {
  local axis="$1" csv="$2" v
  local -a vals=()
  IFS=',' read -ra vals <<< "$csv"
  for v in "${vals[@]}"; do
    v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
    [[ -z "$v" ]] || FILTER_AXIS[$axis]="${FILTER_AXIS[$axis]:+${FILTER_AXIS[$axis]}$'\n'}$v"
  done
}

# parse_filters <args...>
#   Classify every argument before any of them can mean anything else, and
#   leave what is left for the caller. Populates three globals:
#
#     FILTER_AXIS[<axis>]  newline-separated alternatives, one entry per axis
#                          named: status priority type label epic filed-by
#                          claimed-by spec origin held blocked
#     FILTER_COLS          the ad-hoc column selection, or empty
#     FILTER_RESIDUE       what is not a filter — at most one word, and only
#                          ever the trailing one, which is where a collection
#                          is named
#
#   Returns 0 on success; 1 on any refusal, having written nothing anywhere.
#   That ordering is the load-bearing part: the collection positional binds
#   only after every argument has been classified, so a flag's operand can
#   never be read as a directory and a mistyped filter never reaches one.
#
#   Precedence is stated rather than emergent: a reserved word always reads as
#   a filter and never as a collection. The corollary is deliberate — a
#   directory whose name collides with a reserved word can no longer be passed
#   as the collection.
parse_filters() {
  declare -gA FILTER_AXIS=()
  declare -ga FILTER_RESIDUE=()
  FILTER_COLS=""
  local a v c
  local -a carr=()
  while (( $# )); do
    a="$1"
    case "$a" in
      --status|--priority|--type|--label|--epic|--filed-by|--claimed-by|--spec|--origin)
        v="$(need_operand "$a" "$#" "${2:-}")" || return 1
        filter_axis_add "${a#--}" "$v"
        shift 2
        ;;
      --cols)
        v="$(need_operand "$a" "$#" "${2:-}")" || return 1
        IFS=',' read -ra carr <<< "$v"
        for c in "${carr[@]}"; do
          if ! in_list "$c" "${COL_TOKENS[@]}"; then
            echo "error: unrecognized column: $(token_safe "$c")" >&2
            echo "       columns are one of: ${COL_TOKENS[*]}" >&2
            return 1
          fi
        done
        FILTER_COLS="$v"
        shift 2
        ;;
      --*)
        echo "error: unknown filter flag: $(token_safe "$a")" >&2
        echo "       flags are one of: ${RENDER_OPTIONS[*]}" >&2
        return 1
        ;;
      *)
        if   in_list "$a" "${STATUS_TOKENS[@]}";   then filter_axis_add status   "$a"
        elif in_list "$a" "${PRIORITY_TOKENS[@]}"; then filter_axis_add priority "$a"
        elif in_list "$a" "${TYPE_TOKENS[@]}";     then filter_axis_add type     "$a"
        elif in_list "$a" "${HELD_TOKENS[@]}";     then filter_axis_add held     "$a"
        elif in_list "$a" "${BLOCKED_TOKENS[@]}";  then filter_axis_add blocked  "$a"
        elif (( $# == 1 )); then
          # The trailing word is the one position a collection is named in, so
          # this is the only word the parser cannot judge alone. The caller
          # answers it, and owns the message either way.
          FILTER_RESIDUE+=("$a")
        else
          echo "error: unrecognized filter token: $(token_safe "$a")" >&2
          bare_word_help
          if [[ -d "$a" ]]; then
            echo "       a collection is named as the trailing argument" >&2
          else
            echo "       to open an issue by id: /jim:issue show $(token_safe "$a")" >&2
          fi
          return 1
        fi
        shift
        ;;
    esac
  done
  return 0
}

# bind_collection — settle which collection to read, from what parse_filters
#   left behind. Sets FILTER_DIR to the named directory, or to empty when the
#   collection comes from configuration.
#
#   The residue holds at most the trailing word, because that is the only
#   position a collection is ever named in. If it is a directory it is the
#   collection. If it is anything else the caller named something that is
#   neither a filter nor a collection, and both readings were genuinely open —
#   which is the difference between "you mistyped a filter" and "there is no
#   such collection", two different answers to two different questions.
bind_collection() {
  FILTER_DIR=""
  (( ${#FILTER_RESIDUE[@]} == 0 )) && return 0
  local named="${FILTER_RESIDUE[0]}"
  if [[ -d "$named" ]]; then
    FILTER_DIR="$named"
    return 0
  fi
  echo "error: $(token_safe "$named") is neither a filter nor an existing directory" >&2
  bare_word_help
  return 1
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
#   Emit TSV per issue, twelve TAB-separated fields ("-" for any empty one):
#     slug num status priority created labels title origin
#     type filed-by claimed-by outcome
#   Parses the INDEX.md ## Issues section only. Unknown keys in a row are
#   ignored, so an index written by a newer emitter still reads here.
read_issue_rows() {
  awk '
    /^## Issues$/ { insec = 1; next }
    /^## / && insec { insec = 0 }
    insec && /^- `/ {
      line = $0
      slug = line; sub(/^- `/, "", slug); sub(/`.*/, "", slug)
      title = line; sub(/^- `[^`]*` — /, "", title); sub(/ · .*/, "", title)
      num = ""; status = ""; prio = ""; created = ""; labels = ""; origin = ""
      type = ""; filed_by = ""; claimed_by = ""; outcome = ""
      n = split(line, parts, / · /)
      for (i = 2; i <= n; i++) {
        kv = parts[i]; key = kv; sub(/:.*/, "", key)
        val = kv; sub(/^[^:]*:[[:space:]]*/, "", val)
        if (key == "num") num = val
        else if (key == "status") status = val
        else if (key == "priority") prio = val
        else if (key == "created") created = val
        else if (key == "origin") origin = val
        else if (key == "type") type = val
        else if (key == "filed-by") filed_by = val
        else if (key == "claimed-by") claimed_by = val
        else if (key == "outcome") outcome = val
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
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        slug, (num == "" ? "-" : num), (status == "" ? "open" : status),
        (prio == "" ? "-" : prio), (created == "" ? "-" : created),
        (labels == "" ? "-" : labels), title, (origin == "" ? "-" : origin),
        (type == "" ? "-" : type), (filed_by == "" ? "-" : filed_by),
        (claimed_by == "" ? "-" : claimed_by), (outcome == "" ? "-" : outcome)
    }
  ' "$1"
}

# read_graph_edges <index_file> <type>
#   Emit "<source>\t<target>" for every edge of one relation type in the
#   index's Graph section.
#
#   The slug pattern is is_valid_id's character class and only that. That
#   function's emptiness check, its 128-character cap and its explicit `..`
#   rejection are applied before its regex and are not reproduced here, so this
#   is the laxer of the two. It is the right laxness for this path: an edge
#   slug is only ever compared against a row slug — never composed into a path
#   and never opened — so the gate those extra rules exist for is not in play.
#   What matching the class buys is agreement with the ids the collection
#   accepts. A narrower pattern drops every edge touching an uppercase or
#   dotted id and says nothing about it.
#
#   The awk program is a literal and takes no value from the caller; the type
#   is compared in shell over what it emits.
read_graph_edges() {
  local index_file="$1" want="$2" etype esrc etgt
  while IFS=$'\t' read -r etype esrc etgt; do
    [[ "$etype" == "$want" ]] || continue
    printf '%s\t%s\n' "$esrc" "$etgt"
  done < <(awk '
    /^## Graph$/ { insec = 1; next }
    /^## / && insec { insec = 0 }
    insec && /^- `[A-Za-z0-9][A-Za-z0-9._-]*` --[a-z][a-z-]*--> `[A-Za-z0-9][A-Za-z0-9._-]*`$/ {
      line = $0
      sub(/^- `/, "", line)
      src = line; sub(/`.*$/, "", src)
      rest = line; sub(/^[^`]*` --/, "", rest)
      etype = rest; sub(/-->.*$/, "", etype)
      tgt = rest; sub(/^[^>]*> `/, "", tgt); sub(/`$/, "", tgt)
      printf "%s\t%s\t%s\n", etype, src, tgt
    }
  ' "$index_file")
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

  claim <id>              take the issue (--force takes over one held)
  release <id>            give it up
  start <id>              mark it underway, claiming it when unheld
  close <id> [--as <o>]   finish it; <o> is done | wontfix | duplicate |
                          obsolete, and done is what a bare close records
  reopen <id>             return it to not-started, keeping the outcome

  reconcile               realize ordinals bound while offline

  Issues live in the configured issues directory. The verbs above are how one
  moves: a close written by hand leaves `outcome` empty, and the index reports
  that record as closed with no outcome recorded.

  By default `list` hides closed issues; use `list closed` to see them, or set
  `issue_list_closed = "true"` in jimconf.toml to include them in every view.
HELP
}

# ─── Section: stats ──────────────────────────────────────────────────────────

# named_dir_exists <arg> — refuse a collection the caller *named* that is not
#   there. One resolved from config that does not exist is an ordinary empty
#   project and still reads as one; a name handed in that is not a directory is
#   a mistake, and reading it as a collection is how a read verb came to create
#   one in the developer's checkout.
named_dir_exists() {
  [[ -z "${1:-}" || -d "$1" ]] && return 0
  echo "error: '$1' is not an existing collection directory" >&2
  return 1
}

cmd_stats() {
  local dir
  # The same grammar, in the same order, as the list view: every argument is
  # classified before the collection binds, so a refusal here touches nothing
  # either.
  parse_filters "$@"  || return 1
  bind_collection     || return 1
  resolve_person_axes || return 1
  dir="$(resolve_dir "$FILTER_DIR")"
  if [[ -z "$dir" ]]; then
    echo "Issue Collection — (unconfigured)"
    return 0
  fi
  ensure_index "$dir"
  local index_file="$dir/$INDEX_FILENAME"
  local specs_root
  specs_root="$(bash "$JIMCONF" get specs 2>/dev/null)"
  : "${specs_root:=docs/specs}"
  printf 'Issue Collection — %s\n\n' "$dir"
  if [[ ! -f "$index_file" ]]; then
    printf '  Open: 0 · Closed: 0\n\n_No INDEX.md present._\n'
    return 0
  fi

  # Clusters, counts and the blocking rollup all describe the same set of
  # records, so the set is settled once. A census never hides finished
  # records: one that reports a closed count cannot also conceal one.
  declare -A origin_count label_count priority_count matching
  origin_count[__s__]=0;   unset 'origin_count[__s__]'
  label_count[__s__]=0;    unset 'label_count[__s__]'
  priority_count[__s__]=0; unset 'priority_count[__s__]'
  matching[__s__]=0;       unset 'matching[__s__]'
  local open_count=0 closed_count=0
  local slug num status prio created labels title origin
  local type filed_by claimed_by outcome
  if [[ -n "${FILTER_AXIS[blocked]:-}" || -n "${FILTER_AXIS[epic]:-}" ]]; then
    build_derived_axes "$index_file"
  fi
  while IFS=$'\t' read -r slug num status prio created labels title origin \
      type filed_by claimed_by outcome; do
    [[ -z "$slug" ]] && continue
    row_matches || continue
    matching[$slug]=1
    if [[ "$status" == "closed" ]]; then
      closed_count=$(( closed_count + 1 ))
    else
      open_count=$(( open_count + 1 ))
    fi
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

  scope_line
  printf '  Open: %s · Closed: %s\n\n' "$open_count" "$closed_count"
  printf '== Clusters ==\n\n'

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
  local edge_src edge_tgt
  while IFS=$'\t' read -r edge_src edge_tgt; do
    [[ -n "$edge_src" ]] || continue
    [[ -n "${matching[$edge_src]:-}" ]] || continue
    blocks_out[$edge_src]=$(( ${blocks_out[$edge_src]:-0} + 1 ))
    blocks_targets[$edge_src]="${blocks_targets[$edge_src]:-} $edge_tgt"
  done < <(read_graph_edges "$index_file" blocks)

  if (( ${#blocks_out[@]} == 0 )); then
    printf '  _No blocking edges._\n\n'
  else
    local s count src
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

# format_row <cols-csv> <slug> <num> <status> <priority> <created> <labels> \
#            <title> <type> <filed-by> <claimed-by> <outcome>
#   Fixed-width columns are formatted with `printf -v` (into a scratch var)
#   rather than `out+=$(printf …)` — the latter forks a subshell per column per
#   row, which dominates list cost on larger collections.
format_row() {
  local cols="$1" slug="$2" num="$3" status="$4" prio="$5" created="$6" labels="$7" title="$8"
  local type="${9:--}" filed_by="${10:--}" claimed_by="${11:--}" outcome="${12:--}"
  local out="" c pad
  local -a _cols=()
  IFS=',' read -ra _cols <<< "$cols"
  for c in "${_cols[@]}"; do
    case "$c" in
      num)
        # A provisional ordinal (P-<id>) is never rendered as a settled #N —
        # the "(provisional)" marker is what distinguishes it (spec 010 AC 9).
        if [[ "$num" == P-* ]]; then
          printf -v pad '%s (provisional)' "$num"
        else
          printf -v pad '#%-5s' "$num"
        fi
        out+=$pad
        ;;
      # date portion only; sub-day precision drives sort + shows in `show`.
      date)     printf -v pad '%-12s' "${created:0:10}"; out+=$pad ;;
      priority) printf -v pad '%-9s' "$prio";     out+=$pad ;;
      status)   printf -v pad '%-8s' "$status";   out+=$pad ;;
      type)     printf -v pad '%-6s' "$type";     out+=$pad ;;
      outcome)  printf -v pad '%-9s' "$outcome";  out+=$pad ;;
      # Identities are wider than the enumerated fields and vary in length, so
      # they are padded to the widest form the recordable set commonly holds
      # rather than truncated — a clipped address is a wrong one.
      filed-by)   printf -v pad '%-22s' "$filed_by";   out+=$pad ;;
      claimed-by) printf -v pad '%-22s' "$claimed_by"; out+=$pad ;;
      slug)     out+="$slug " ;;
      title)    out+="$title " ;;
      labels)   out+="[$labels] " ;;
    esac
    out+=" "
  done
  printf '  %s\n' "$out"
}

# axis_matches <axis> <value> — does one row value satisfy one axis?
#   An axis nobody named matches everything. An axis that was named matches
#   when the value equals any of its alternatives: alternatives within an axis
#   are alternatives, and the caller conjoins the axes.
axis_matches() {
  local axis="$1" value="$2" alt
  [[ -n "${FILTER_AXIS[$axis]:-}" ]] || return 0
  while IFS= read -r alt; do
    [[ "$value" == "$alt" ]] && return 0
  done <<< "${FILTER_AXIS[$axis]}"
  return 1
}

# label_matches <labels-csv> — the label axis, which is a membership test
#   rather than an equality one: a row carries a list, and an alternative
#   matches when the list holds it.
label_matches() {
  local labels="$1" alt lab
  local -a larr=()
  [[ -n "${FILTER_AXIS[label]:-}" ]] || return 0
  [[ "$labels" == "-" || -z "$labels" ]] && return 1
  IFS=',' read -ra larr <<< "$labels"
  while IFS= read -r alt; do
    for lab in "${larr[@]}"; do
      lab="${lab#"${lab%%[![:space:]]*}"}"; lab="${lab%"${lab##*[![:space:]]}"}"
      [[ "$lab" == "$alt" ]] && return 0
    done
  done <<< "${FILTER_AXIS[label]}"
  return 1
}

# prefix_axis <axis> <origin> <root> — an axis whose alternatives are literal
#   path prefixes of the row's recorded origin, each resolved under <root>
#   first when one is given.
#
#   A prefix rather than an equality, so naming a spec's directory reaches
#   every artifact filed from it — a review, a plan, a research pass — and not
#   only the spec document. Naming a group and an ordinal reaches the directory
#   without spelling the rest of its name, which matters because a spec's
#   ordinal is not stable: the rename and split verbs renumber directories and
#   sweep the citations, so the filter matches whatever origin currently
#   records rather than any resolution held anywhere.
#
#   The pattern operand is quoted. Unquoted it is a glob, and a value carrying
#   `*`, `?` or `[` would then silently widen a query the developer narrowed.
prefix_axis() {
  local axis="$1" origin="$2" root="$3" alt pfx
  [[ -n "${FILTER_AXIS[$axis]:-}" ]] || return 0
  [[ "$origin" == "-" || -z "$origin" ]] && return 1
  root="${root%/}"
  while IFS= read -r alt; do
    pfx="${root:+$root/}$alt"
    [[ "$origin" == "$pfx"* ]] && return 0
  done <<< "${FILTER_AXIS[$axis]}"
  return 1
}

# The derived predicates, computed from what the collection already holds.
# Neither is recorded, so no record can disagree with either — there is no
# second copy to fall out of step.
declare -A DERIVED_BLOCKED=()
declare -A DERIVED_EPIC=()

# build_derived_axes <index_file> — populate the two maps above.
#   Both read the Graph section the index already renders, so the umbrella and
#   dependency axes need no row column of their own.
#
#   Blocked is one hop and keys on the target being unfinished rather than on
#   the target being blocked. Those two agree — an issue depending on a blocked
#   issue is already blocked by that dependency's own unfinished state — but
#   only under this keying; keying it on blocked-ness would make them diverge
#   and demand a traversal.
build_derived_axes() {
  local index_file="$1" slug status src tgt rest
  local -A unfinished=()
  while IFS=$'\t' read -r slug _ status rest; do
    [[ -z "$slug" ]] && continue
    [[ "$status" != "closed" ]] && unfinished[$slug]=1
  done < <(read_issue_rows "$index_file")
  while IFS=$'\t' read -r src tgt; do
    [[ -n "${unfinished[$tgt]:-}" ]] && DERIVED_BLOCKED[$src]=1
  done < <(read_graph_edges "$index_file" depends-on)
  while IFS=$'\t' read -r src tgt; do
    DERIVED_EPIC[$src]="${DERIVED_EPIC[$src]:+${DERIVED_EPIC[$src]}$'\n'}$tgt"
  done < <(read_graph_edges "$index_file" part-of)
}

# state_matches <axis> <state> — a derived axis, whose alternatives are the two
#   directions of one predicate.
state_matches() {
  local axis="$1" state="$2" alt
  [[ -n "${FILTER_AXIS[$axis]:-}" ]] || return 0
  while IFS= read -r alt; do
    [[ "$alt" == "$state" ]] && return 0
  done <<< "${FILTER_AXIS[$axis]}"
  return 1
}

# held_matches <recorded-holder> — the held axis. Emptiness is the whole test:
#   an issue is held when a holder is recorded on it and unheld when none is.
held_matches() {
  [[ -n "${FILTER_AXIS[held]:-}" ]] || return 0
  if [[ "$1" == "-" || -z "$1" ]]; then
    state_matches held unclaimed
  else
    state_matches held claimed
  fi
}

# blocked_matches <slug> — the blocked axis, read from the map built above.
blocked_matches() {
  [[ -n "${FILTER_AXIS[blocked]:-}" ]] || return 0
  if [[ -n "${DERIVED_BLOCKED[$1]:-}" ]]; then
    state_matches blocked blocked
  else
    state_matches blocked unblocked
  fi
}

# disclose_hidden_closed <hidden> — say so when a filtered view dropped
#   finished records by the standing default.
#
#   A view that narrowed by one axis and then quietly dropped finished records
#   by another rule reports a match that is not the whole match. It matters
#   most where the result is empty: without this line, "nothing matched" and
#   "everything that matched was hidden" read identically.
#
#   The unfiltered default keeps hiding them silently, as it always has —
#   there is no filter for the result to be mistaken against.
disclose_hidden_closed() {
  (( $1 )) || return 0
  (( ${#FILTER_AXIS[@]} > 0 )) || return 0
  printf '  (closed hidden — add `closed` to include them)\n'
}

# scope_line — what a filtered run was scoped to.
#   A rollup is read as a statement about the collection unless it says
#   otherwise, so a scoped one has to name its scope or it reports something
#   true about part of the collection as though it were true of all of it.
scope_line() {
  (( ${#FILTER_AXIS[@]} > 0 )) || return 0
  local axis parts="" alt vals
  for axis in $(printf '%s\n' "${!FILTER_AXIS[@]}" | sort); do
    vals=""
    while IFS= read -r alt; do vals="${vals:+$vals,}$alt"; done <<< "${FILTER_AXIS[$axis]}"
    parts="${parts:+$parts · }$axis=$vals"
  done
  printf '  scope: %s\n' "$parts"
}

# row_matches — every axis, applied to the row variables already in scope.
#   The two read verbs ask the same question of a row, so they ask it in one
#   place: a second copy is a second place for the combining rules to drift.
row_matches() {
  axis_matches status   "$status" || return 1
  axis_matches priority "$prio"   || return 1
  axis_matches type     "$type"   || return 1
  label_matches         "$labels" || return 1
  person_matches filed-by   "$filed_by"   || return 1
  person_matches claimed-by "$claimed_by" || return 1
  prefix_axis origin "$origin" ""            || return 1
  prefix_axis spec   "$origin" "$specs_root" || return 1
  held_matches    "$claimed_by" || return 1
  blocked_matches "$slug"       || return 1
  epic_matches    "$slug"       || return 1
  return 0
}

# epic_matches <slug> — is this record a member of a named umbrella?
#   Membership is recorded on the member's side only, so the edge points from
#   the member to the umbrella and the umbrella itself never satisfies it.
epic_matches() {
  local slug="$1" alt tgt
  [[ -n "${FILTER_AXIS[epic]:-}" ]] || return 0
  [[ -n "${DERIVED_EPIC[$slug]:-}" ]] || return 1
  while IFS= read -r alt; do
    while IFS= read -r tgt; do
      [[ "$tgt" == "$alt" ]] && return 0
    done <<< "${DERIVED_EPIC[$slug]}"
  done <<< "${FILTER_AXIS[epic]}"
  return 1
}

# The project's form applied to one value, memoized per distinct value.
# `identity.sh normalize` is a subprocess, and a collection holds a handful of
# distinct contributors across hundreds of records — the same reasoning, and
# the same shape, as index.sh's own ident_seen.
declare -A IDENT_FORM=()

# ident_form <value> — <value> under the project's configured form, or <value>
#   unchanged when the form cannot judge it.
#
#   Falling back rather than refusing is what keeps the records the
#   re-normalization skips reachable. Refusing on that class would make exactly
#   the records the index's drift warning asks an operator to go fix
#   unfilterable, which is the opposite of what that warning is for.
ident_form() {
  local v="$1" n
  if [[ -z "${IDENT_FORM[$v]+set}" ]]; then
    if n="$(bash "$IDENTITY_SCRIPT" normalize "$v" 2>/dev/null)"; then
      IDENT_FORM["$v"]="$n"
    else
      IDENT_FORM["$v"]="$v"
    fi
  fi
  printf '%s' "${IDENT_FORM[$v]}"
}

# person_matches <axis> <recorded> — does this record's contributor satisfy the
#   axis? Both sides go through the same definition the write paths use, so a
#   filter and a capture cannot disagree about who someone is.
person_matches() {
  local axis="$1" recorded="$2" alt rec
  [[ -n "${FILTER_AXIS[$axis]:-}" ]] || return 0
  [[ "$recorded" == "-" || -z "$recorded" ]] && return 1
  rec="$(ident_form "$recorded")"
  while IFS= read -r alt; do
    [[ "$(ident_form "$alt")" == "$rec" ]] && return 0
  done <<< "${FILTER_AXIS[$axis]}"
  return 1
}

# resolve_person_axes — replace `me` with the environment's own identity.
#   A developer names themselves rather than an address, so a query does not
#   depend on which of their addresses this machine commits under. Resolution
#   happens once, before any row is read and before any index is built, so a
#   refusal here writes nothing.
#
#   An empty result is not an answer. Returning nothing matched would be
#   indistinguishable from genuinely holding nothing, which is the
#   stale-view-reported-as-current failure this group refuses everywhere else.
#
#   Two conditions, two remedies, told apart by the resolver's own status
#   rather than by its output: an environment carrying no identity is fixed by
#   configuring one, and an identity the project's form cannot record is fixed
#   by changing the form or the address. Collapsing them would send an operator
#   to the wrong setting. Neither message carries the value — the operator did
#   not supply it, so echoing it discloses something they did not choose to
#   put on their terminal.
resolve_person_axes() {
  local axis alt out resolved="" resolved_rc=0 resolved_done=0
  for axis in filed-by claimed-by; do
    [[ -n "${FILTER_AXIS[$axis]:-}" ]] || continue
    out=""
    while IFS= read -r alt; do
      if [[ "$alt" == "me" ]]; then
        if (( ! resolved_done )); then
          resolved="$(bash "$IDENTITY_SCRIPT" resolve 2>/dev/null)"
          resolved_rc=$?
          resolved_done=1
        fi
        if (( resolved_rc != 0 )); then
          echo "error: cannot resolve 'me': $(person_refusal_reason "$resolved_rc")" >&2
          person_refusal_remedy "$resolved_rc"
          return 1
        fi
        alt="$resolved"
      fi
      out="${out:+$out$'\n'}$alt"
    done <<< "${FILTER_AXIS[$axis]}"
    FILTER_AXIS[$axis]="$out"
  done
  return 0
}

# person_refusal_reason <rc> / person_refusal_remedy <rc> — the two halves of
#   the refusal, keyed on which condition the resolver reported.
person_refusal_reason() {
  case "$1" in
    1) printf 'no contributor identity is configured' ;;
    *) printf 'the identity this environment carries is not one the project can record' ;;
  esac
}

person_refusal_remedy() {
  case "$1" in
    1) echo "       set one with: git config user.email <address>" >&2 ;;
    *) echo "       the form is identity_scheme in jimconf.toml; the address is the one git reports" >&2 ;;
  esac
}

cmd_list() {
  local dir=""
  # Classification runs before anything can bind, so a flag's operand never
  # reaches the collection question and a reserved word never leaves the
  # filter vocabulary.
  parse_filters "$@" || return 1
  bind_collection   || return 1
  resolve_person_axes || return 1
  dir="$(resolve_dir "$FILTER_DIR")"
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
  local specs_root="${_cfg[specs]:-docs/specs}"

  # Hide closed issues from the default and every non-lifecycle-filtered view
  # unless the issue_list_closed toggle opts them in. A filter naming lifecycle
  # state is the user being deliberate about it, so it always overrides the
  # toggle — `list closed` is the ad-hoc closed view. Every other axis leaves
  # the default in place.
  local hide_closed=0
  if [[ -z "${FILTER_AXIS[status]:-}" && "$show_closed" != "true" ]]; then
    hide_closed=1
  fi
  # Validate every column token; fall back to the default set on any unknown.
  local _c _ok=1 _carr
  IFS=',' read -ra _carr <<< "$cols"
  for _c in "${_carr[@]}"; do in_list "$_c" "${COL_TOKENS[@]}" || _ok=0; done
  [[ "$_ok" == 1 && -n "$cols" ]] || cols="num,date,priority,title"
  # A selection made for this invocation wins over the configured default, and
  # replaces it rather than merging with it — a query naming its columns is
  # naming all of them. It has already cleared the column vocabulary at parse
  # time, which is why the two fail differently: a flag is this run's explicit
  # ask and refuses, while a standing setting degrades so a typo in it never
  # makes the collection unreadable.
  [[ -n "$FILTER_COLS" ]] && cols="$FILTER_COLS"

  # Load rows, applying the filter.
  local rows=() slug num status prio created labels title origin
  # Only when an axis needs them: both walk the index a second time.
  if [[ -n "${FILTER_AXIS[blocked]:-}" || -n "${FILTER_AXIS[epic]:-}" ]]; then
    build_derived_axes "$index_file"
  fi
  local seen_rows=0 saw_type=0 hidden_closed=0
  local type filed_by claimed_by outcome
  while IFS=$'\t' read -r slug num status prio created labels title origin \
      type filed_by claimed_by outcome; do
    [[ -z "$slug" ]] && continue
    (( seen_rows++ ))
    [[ "$type" != "-" ]] && saw_type=1
    row_matches || continue
    # Last, so that only a record the query would otherwise have matched counts
    # as hidden. A finished record excluded on some other axis was not hidden by
    # this default and disclosing it would report a narrowing that never happened.
    if [[ "$hide_closed" == 1 && "$status" == "closed" ]]; then
      hidden_closed=1
      continue
    fi
    rows+=("$slug"$'\t'"$num"$'\t'"$status"$'\t'"$prio"$'\t'"$created"$'\t'"$labels"$'\t'"$title"$'\t'"$type"$'\t'"$filed_by"$'\t'"$claimed_by"$'\t'"$outcome")
  done < <(read_issue_rows "$index_file")

  # An index written before the row carried these fields can be newer than
  # every issue file, so the staleness gate reuses it and every axis reading
  # them matches nothing. That is a true statement about the index and a false
  # one about the collection, and the two are indistinguishable to a reader.
  #
  # The condition needs no schema stamp and no version marker: `type` is
  # non-empty on every record the current schema produces, so rows that exist
  # while none carries one identify the older index on their own. The repair is
  # a single regeneration.
  if (( seen_rows > 0 && saw_type == 0 )); then
    local -a unanswerable=()
    local ax
    for ax in type filed-by claimed-by; do
      [[ -n "${FILTER_AXIS[$ax]:-}" ]] && unanswerable+=("$ax")
    done
    if (( ${#unanswerable[@]} )); then
      echo "error: the index for '$dir' does not describe: ${unanswerable[*]}" >&2
      echo "       it was written before those fields were recorded" >&2
      echo "       regenerate it with: bash $INDEX_SCRIPT '$dir'" >&2
      echo "       if the records themselves predate the schema, convert them first" >&2
      return 1
    fi
  fi

  if (( ${#rows[@]} == 0 )); then
    printf '_No matching issues._\n'
    disclose_hidden_closed "$hidden_closed"
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
    while IFS=$'\t' read -r slug num status prio created labels title \
        type filed_by claimed_by outcome; do
      [[ -z "$slug" ]] && continue
      format_row "$cols" "$slug" "$num" "$status" "$prio" "$created" "$labels" \
        "$title" "$type" "$filed_by" "$claimed_by" "$outcome"
    done <<< "$sorted"
    printf '\n'
    printed_any=1
  done
  (( printed_any == 0 )) && printf '_No matching issues._\n'
  disclose_hidden_closed "$hidden_closed"
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
  local type filed_by claimed_by outcome
  fm="$(awk '/^---$/{c++; if(c==2) exit; if(c==1) next} c==1{print}' "$f")"
  field() { printf '%s\n' "$fm" | grep -E "^$1:" | head -n1 | sed -E "s/^$1:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"; }
  num="$(field num)"; title="$(field title)"; status="$(field status)"
  prio="$(field priority)"; labels="$(field labels)"; origin="$(field origin)"; created="$(field created)"
  type="$(field type)"; filed_by="$(field filed-by)"
  claimed_by="$(field claimed-by)"; outcome="$(field outcome)"
  # A provisional ordinal is never rendered as a settled #N (spec 010 AC 9).
  if [[ "$num" == P-* ]]; then
    printf '%s (provisional) · %s\n' "$num" "$slug"
  else
    printf '#%s · %s\n' "${num:--}" "$slug"
  fi
  printf '%s\n' "${title}"
  printf '  status: %s   priority: %s\n' "${status:-open}" "${prio:--}"
  [[ -n "$type" ]] && printf '  type: %s\n' "$type"
  # Shown only when set. An unheld issue and one with no outcome are the
  # ordinary cases, and printing an empty field for each would push the states
  # that do carry a value out of a reader's eye.
  [[ -n "$filed_by" ]]   && printf '  filed-by: %s\n' "$filed_by"
  [[ -n "$claimed_by" ]] && printf '  claimed-by: %s\n' "$claimed_by"
  [[ -n "$outcome" ]]    && printf '  outcome: %s\n' "$outcome"
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
  named_dir_exists "$dir" || return 1
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
# Read-only, and degrades to empty output on an absent or empty index. Exits
# non-zero only when the facts were read from an index that could not be
# refreshed — the analyst is the terminal reader and has no other way to learn
# that the graph it is told to trust may be behind the collection.
cmd_insights_graph() {
  local dir
  named_dir_exists "${1:-}" || return 1
  dir="$(resolve_dir "${1:-}")"
  [[ -z "$dir" ]] && return 0
  ensure_index "$dir"
  local index_file="$dir/$INDEX_FILENAME"
  [[ -f "$index_file" ]] || return 0

  declare -A is_open
  local slug num status prio created labels title origin
  local type filed_by claimed_by outcome
  while IFS=$'\t' read -r slug num status prio created labels title origin \
      type filed_by claimed_by outcome; do
    [[ -z "$slug" ]] && continue
    # Unfinished, not merely not-started: an underway issue is live work and
    # belongs in the isolation report exactly as a not-started one does.
    [[ "$status" != "closed" ]] && is_open[$slug]=1
  done < <(read_issue_rows "$index_file")

  # blocks / depends-on edges → endpoints (non-isolated) + blocking out-degree.
  # related-to and duplicates are ordering-neutral and ignored (spec 020 AC5).
  declare -A related blocks_out
  local esrc etgt
  while IFS=$'\t' read -r esrc etgt; do
    [[ -n "$esrc" ]] || continue
    related[$esrc]=1; related[$etgt]=1
    blocks_out[$esrc]=$(( ${blocks_out[$esrc]:-0} + 1 ))
  done < <(read_graph_edges "$index_file" blocks)
  while IFS=$'\t' read -r esrc etgt; do
    [[ -n "$esrc" ]] || continue
    related[$esrc]=1; related[$etgt]=1
  done < <(read_graph_edges "$index_file" depends-on)

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

# named_collection <args...>
#   Exit 0 when the invocation names a collection directory under the filter
#   grammar — the trailing word, left unclassified, and a directory.
#
#   Routing and binding have to read argv the same way. Routing decides *which*
#   collection a read serves and is settled before any verb runs, so a grammar
#   it alone gets wrong does not produce an error: it produces a plausible
#   answer over the wrong data. The arms below answered on argument shape, and
#   a flag's operand wears the same shape as a directory.
#
#   A query the parser refuses names no collection either, but there is nothing
#   to route it to: report a collection so the verb runs here and refuses
#   immediately, rather than materializing a destination for a query that
#   cannot run against it.
named_collection() {
  parse_filters "$@" 2>/dev/null || return 0
  (( ${#FILTER_RESIDUE[@]} == 1 )) && [[ -d "${FILTER_RESIDUE[0]}" ]]
}

# dir_given <sub> <args...>
#   Exit 0 when the invocation already names a collection directory. Each verb
#   spells its optional directory differently, so the shapes are read here
#   rather than guessed: naming a directory opts out of placement routing, and
#   it is also what keeps the placement re-exec from recursing.
dir_given() {
  local sub="$1"; shift
  # `insights-graph` and `show` stay on count. Neither takes a filter, so their
  # operand is a directory or it is nothing and a bad one is a usage error each
  # verb refuses. Routing instead would be worse than the bypass: the re-exec
  # appends the real collection as a trailing argument, and both read their
  # directory positionally, so the bad token would bind as the collection and
  # the real one be ignored.
  case "$sub" in
    stats|list)     named_collection "$@" ;;
    insights-graph) (( $# >= 1 )) ;;
    show)           (( $# >= 2 )) ;;
    *) return 1 ;;
  esac
}

# route_placement <place-token> <sub> <args...>
#   Re-exec through place.sh when the project keeps its collection on a
#   designated branch, so the read verbs serve that branch rather than whatever
#   the working tree happens to hold. The run is read-only: it materializes the
#   destination and discards it, so a read never becomes a write.
route_placement() {
  local token="$1"; shift
  local sub="$1"; shift
  local place="$HERE/place.sh" mode
  [[ -r "$place" ]] || return 0
  # The re-exec appends the collection directory as a trailing argument, so an
  # invocation missing a required operand must not be routed: `show` with no id
  # would take that directory *as* the id, turning a clean usage error into a
  # lookup for the run's temp path.
  [[ "$sub" == "show" && $# -eq 0 ]] && return 0
  dir_given "$sub" "$@" && return 0
  mode="$(bash "$place" mode --place-token "$token")" || exit $?
  [[ "$mode" == "route" ]] || return 0
  exec bash "$place" run --read -- \
    bash "${BASH_SOURCE[0]}" --place-token '{token}' "$sub" "$@" '{}'
}

main() {
  local place_token=""
  if [[ "${1:-}" == "--place-token" ]]; then
    place_token="${2:-}"
    shift 2
  fi
  local sub="${1:-help}"
  [[ $# -gt 0 ]] && shift
  case "$sub" in
    stats|list|show|insights-graph) route_placement "$place_token" "$sub" "$@" ;;
  esac
  local rc=0
  case "$sub" in
    stats) cmd_stats "$@" || rc=$? ;;
    list)  cmd_list  "$@" || rc=$? ;;
    show)  cmd_show  "$@" || rc=$? ;;
    insights-graph) cmd_insights_graph "$@" || rc=$? ;;
    help|-h|--help) cmd_help || rc=$? ;;
    *)
      echo "error: unknown subcommand '$sub' (valid: stats list show insights-graph help)" >&2
      cmd_help >&2
      return 2
      ;;
  esac
  # A verb that otherwise succeeded still fails the run when it served a view it
  # could not refresh. A verb that already failed keeps its own status, which is
  # the more specific of the two.
  (( rc == 0 )) && (( STALE_VIEW )) && rc=1
  return "$rc"
}

main "$@"
