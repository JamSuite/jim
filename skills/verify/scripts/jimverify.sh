#!/usr/bin/env bash
#
# skills/verify/scripts/jimverify.sh — jim's deterministic invariant-verification
#   core (spec 035). Owns the Bash-vs-Prompt deterministic half of /jim:verify:
#   blueprint check-data parsing, territory resolution, and the native mechanical
#   floor. Judgment (registry execution, judge fan-out, report framing) lives in
#   the skill, not here.
#
# SUBCOMMANDS
#   parse     <blueprint-spec.md>          Invariants table + verify-checks block
#                                          → normalized TSV, one record per invariant.
#   territory <map-path> <group>           the group's declared territory paths,
#                                          one validated relpath per line.
#   check     <blueprint-dir> <map> <group> [files-list]  (spec 035 Task 4) run
#                                          the mechanical floor and emit
#                                          per-invariant outcomes. An optional 4th
#                                          files-list scopes the floor to a change
#                                          set (spec 036): patterns search only
#                                          listed files ∩ territory, structure runs
#                                          only when its param path is listed, and
#                                          conformance scans the listed set only.
#   faces     <blueprint-spec.md>          (spec 037) Provides/Requires face
#                                          entries joined with the optional
#                                          contract-checks block → one TSV record
#                                          per entry.
#
# faces OUTPUT (TAB-separated, one record per Provides/Requires entry):
#   kind \t key \t target \t criticality \t params \t text
#     - kind ∈ provides | requires
#     - key: slugified backticked surface name (provides) or slugified dotted
#       ref (requires)
#     - target: requires only — the readable <group>.<surface> when the leading
#       token is a valid group slug, else "-"; always "-" for provides
#     - criticality: provides only — the declared value from the entry's
#       contract-checks line, else "-"
#     - params: the entry's joined contract-checks line, or "-"; malformed
#       check data (bad criticality / unsafe scope) degrades to
#       "malformed:<reason>" — never a silent drop
#     - text: the entry's verbatim guarantee text (sanitized)
#   A contract-checks line whose key is not a valid slug matches no entry and is
#   inert (the verify-checks orphan precedent). rc 2 when the file is missing.
#   The record STRUCTURE is trusted; the carried text/params are untrusted data.
#   edges     <map-path>                    (spec 037) the persisted Contract
#                                          Graph → one edge per line.
#
# edges OUTPUT (one per data row):
#   consumer \t relies-on \t provider        consumer/provider are validated
#                                            group slugs; relies-on is sanitized
#                                            free text
#   HYGIENE \t <row>                         a row whose consumer/provider cell
#                                            is not a valid slug — excluded
#   rc 2 when the map has no `## Contract Graph` section (caller names the
#   degradation). A present-but-empty graph emits nothing and exits 0.
#
# parse OUTPUT (TAB-separated, one record per line):
#   id \t criticality \t method \t params \t invariant
#     - method ∈ pattern | structure | registry:<name> | judge | malformed
#     - params: the joined verify-checks line for <id>, or "-" when none
#     - a malformed row (bad id / criticality / registry name) emits
#       id \t criticality \t malformed \t <reason> \t invariant  (never an error,
#       never a silent drop). A legacy 3-column table (no Id column) maps every
#       row to the judge rung under a synthesized inv-<n> id (AC #10).
#   The verbatim invariant text is carried as field 5 so the skill has the rule
#   for the judge spawn and the report without re-parsing the blueprint.
#
# territory OUTPUT (one per line):
#   <relpath>                              a territory path that passed valid-relpath
#   HYGIENE \t <path>                      a declared path that failed the shape gate
#                                          (absolute / '..' segment) — excluded, reported
#   rc 2 when the group is absent from the map.
#
# SECURITY
#   set -uo pipefail; export LC_ALL=C. Blueprint, map, and config content are
#   untrusted DATA — parsed with awk/sed/grep, never sourced or eval'd. Field
#   content is sanitized on emission (tabs/CRs stripped, length capped) so a
#   crafted cell can never shift TSV columns or smuggle a record (Finding 7).
#   Registry names and territory paths are validated against a slug / relpath
#   shape before use, so a blueprint-recorded token is inert (Findings 1, 6).
#   No jim script executes config-derived command strings; registry execution
#   lives in the skill via the Bash tool (Decision 1).
#

set -uo pipefail
export LC_ALL=C

# jimfile.sh provides the single valid-relpath boundary. Resolved
# BASH_SOURCE-relative so it travels with the plugin tree
# (skills/verify/scripts/ → skills/file/scripts/).
JIMFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../file/scripts" 2>/dev/null && pwd)/jimfile.sh"

usage() {
  cat >&2 <<'USAGE'
usage: jimverify.sh <subcommand> [args]
  parse     <blueprint-spec.md>              invariants → normalized TSV
  territory <map-path> <group>               group territory paths (validated)
  check     <blueprint-dir> <map-path> <group> [files-list]  run the mechanical floor
  faces     <blueprint-spec.md>              provides/requires + contract-checks → TSV
  edges     <map-path>                        persisted Contract Graph → consumer/relies-on/provider
USAGE
}

# ─── Section: parse ──────────────────────────────────────────────────────────

# cmd_parse <blueprint-spec.md> — emit the normalized invariant TSV. All parsing
#   is a single awk pass: the verify-checks block and the Invariants table are
#   collected regardless of order, then joined and emitted at END.
cmd_parse() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then echo "jimverify parse: need <blueprint-spec.md>" >&2; return 2; fi
  if [[ ! -f "$file" ]]; then echo "jimverify parse: file not found: $file" >&2; return 2; fi
  awk '
    function san(x) { gsub(/\t/, " ", x); gsub(/\r/, "", x); if (length(x) > 1024) x = substr(x, 1, 1024); return x }
    function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
    function emit(id, inv, crit, chk,   method, p, reason, name) {
      reason = ""
      if (id !~ /^[a-z0-9][a-z0-9-]*$/)                reason = "malformed check data: invalid id"
      else if (crit !~ /^(critical|high|medium|low)$/) reason = "malformed check data: invalid criticality"
      method = ""
      if (reason == "") {
        if (chk == "pattern")            method = "pattern"
        else if (chk == "structure")     method = "structure"
        else if (chk == "judge")         method = "judge"
        else if (chk ~ /^registry:/) {
          name = substr(chk, 10)
          if (name ~ /^[a-z0-9][a-z0-9-]*$/) method = "registry:" name
          else                               reason = "malformed check data: invalid registry name"
        }
        else method = "judge"   # unknown / prose / empty → judge fallback (AC #10)
      }
      p = "-"
      if (id in params && params[id] != "") p = params[id]
      if (reason != "")
        printf "%s\t%s\t%s\t%s\t%s\n", san(id), san(crit), "malformed", san(reason), san(inv)
      else
        printf "%s\t%s\t%s\t%s\t%s\n", san(id), san(crit), san(method), san(p), san(inv)
    }
    BEGIN { FS = "|"; in_inv = 0; in_checks = 0; hdr = 0; fmt = 0; nrow = 0 }

    # verify-checks fenced block (anywhere in the file): <id> <key>=<value>...
    /^```verify-checks[ \t]*$/ { in_checks = 1; next }
    in_checks && /^```/        { in_checks = 0; next }
    in_checks {
      line = $0; sub(/^[ \t]+/, "", line)
      if (line == "") next
      cid = line;  sub(/[ \t].*$/, "", cid)          # first token = id
      rest = line; sub(/^[^ \t]+[ \t]*/, "", rest)   # remainder = params
      if (cid != "") params[cid] = rest
      next
    }

    # Invariants section: from "## Invariants" to the next "## " heading.
    /^##[ \t]+Invariants[ \t]*$/ { in_inv = 1; hdr = 0; next }
    in_inv == 1 && /^##[ \t]/    { in_inv = 0 }

    in_inv == 1 && /^[ \t]*\|/ {
      c1 = trim($2)
      if (c1 ~ /^:?-+:?$/) next                       # separator row
      if (hdr == 0) {                                 # header row → detect format
        hdr = 1
        ncols = NF - 2
        if (ncols >= 4 && tolower(c1) == "id") fmt = 4; else fmt = 3
        next
      }
      nrow++
      if (fmt == 4) { rid[nrow] = trim($2); rinv[nrow] = trim($3); rcrit[nrow] = trim($4); rchk[nrow] = trim($5) }
      else          { rid[nrow] = "inv-" nrow; rinv[nrow] = trim($2); rcrit[nrow] = trim($3); rchk[nrow] = "judge" }
    }

    END { for (i = 1; i <= nrow; i++) emit(rid[i], rinv[i], rcrit[i], rchk[i]) }
  ' "$file"
}

# ─── Section: territory ──────────────────────────────────────────────────────

# cmd_territory <map-path> <group> — extract the group's declared territory paths
#   from the project map and validate each through jimfile.sh valid-relpath. A
#   safe path prints on its own line; an unsafe one (absolute / '..' segment)
#   prints as `HYGIENE\t<path>` and is excluded. rc 2 if the group section is
#   absent. The group name is slug-validated before any grep so it can never
#   inject a pattern.
cmd_territory() {
  local map="${1:-}" group="${2:-}"
  if [[ -z "$map" || -z "$group" ]]; then
    echo "jimverify territory: need <map-path> <group>" >&2; return 2
  fi
  if [[ ! -f "$map" ]]; then echo "jimverify territory: map not found: $map" >&2; return 2; fi
  if [[ ! "$group" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimverify territory: invalid group: $group" >&2; return 2
  fi
  # Group section must exist in the map, else there is no boundary to read.
  if ! awk -v g="### $group" '$0 == g { f = 1 } END { exit(f ? 0 : 1) }' "$map"; then
    echo "jimverify territory: group not in map: $group" >&2; return 2
  fi
  # The Territory line inside the group's "### <group>" section (first match).
  local terr_line
  terr_line="$(awk -v g="### $group" '
    $0 == g { insec = 1; next }
    insec && /^#{2,3}[ \t]/ { insec = 0 }
    insec && /\*\*Territory:\*\*/ { print; exit }
  ' "$map")"
  [[ -z "$terr_line" ]] && return 0
  # Strip everything up to and including the label, drop backticks, split on comma.
  local rest
  rest="$(printf '%s' "$terr_line" | sed 's/.*\*\*Territory:\*\*//' | tr -d '`')"
  local IFS=',' part p
  local -a parts
  read -ra parts <<< "$rest"
  for part in "${parts[@]}"; do
    p="$(printf '%s' "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$p" in
      ""|"—"|"-"|none|None|"*None*"|"*none*") continue ;;
    esac
    if bash "$JIMFILE" valid-relpath "$p" >/dev/null 2>&1; then
      printf '%s\n' "$p"
    else
      printf 'HYGIENE\t%s\n' "$p"
    fi
  done
}

# ─── Section: check — the mechanical floor ───────────────────────────────────

# safe_path_param <value> — return 0 iff a path-bearing check parameter (scope /
#   exists / absent) is safe to hand to grep/find: non-empty, no leading dash
#   (option injection), and passing jimfile valid-relpath (not absolute, no '..'
#   segment). The Finding-6 gate — a failing parameter degrades its check to
#   `failed` and is never executed. Values are ALSO passed behind `-e` / `--`
#   guards at the call site (defense in depth).
safe_path_param() {
  local v="$1"
  [[ -n "$v" ]] || return 1
  [[ "$v" == -* ]] && return 1
  bash "$JIMFILE" valid-relpath "$v" >/dev/null 2>&1 || return 1
  return 0
}

# safe_scope_file <path> — return 0 iff an untrusted files-list line is safe to
#   use as a scope path. Stricter than safe_path_param: it ALSO rejects any
#   whitespace or double-quote byte, so git's C-quoted output (a non-ASCII path
#   arrives double-quoted and octal-escaped) and space-bearing paths are excluded
#   rather than word-split or mis-read as a real file (security.md Finding 10). An
#   excluded line emits HYGIENE and the invariant falls to the caller's sweep.
safe_scope_file() {
  local v="$1"
  safe_path_param "$v" || return 1
  [[ "$v" == *[[:space:]]* ]] && return 1
  [[ "$v" == *'"'* ]] && return 1
  return 0
}

# path_under <file> <base> — 0 iff <file> is at or under <base> (prefix match on
#   a normalized trailing slash); base "." matches everything. Both are already
#   shape-gated relpaths, so this is pure string logic.
path_under() {
  local f="$1" base="$2" bp
  [[ "$base" == "." ]] && return 0
  bp="${base%/}/"
  case "$f/" in "$bp"*) return 0 ;; esac
  return 1
}

# structure_relevant <exists> <absent> — 0 iff the change set (scope_files, read
#   via dynamic scope) touches this structure check's subject: the concrete
#   exists path is a listed file, or some listed file matches the absent glob.
#   Consulted only in scoped mode; an irrelevant check makes no record so the
#   invariant falls to the caller's sweep/judge accounting (interface contract).
structure_relevant() {
  local exists="$1" absent="$2" sf
  if [[ -n "$exists" ]]; then
    for sf in "${scope_files[@]}"; do [[ "$sf" == "$exists" ]] && return 0; done
    return 1
  fi
  if [[ -n "$absent" ]]; then
    for sf in "${scope_files[@]}"; do
      # shellcheck disable=SC2053  # deliberate glob match against the absent pattern
      [[ "$sf" == $absent ]] && return 0
    done
    return 1
  fi
  return 1
}

# emit_outcome <id> <outcome> <evidence> — print one floor result record. The
#   evidence field is sanitized (tabs/newlines/CRs → spaces, length capped) so
#   untrusted code/blueprint content can never shift TSV columns (Finding 7).
emit_outcome() {
  local id="$1" outcome="$2" evidence="$3"
  evidence="$(printf '%s' "$evidence" | tr '\t\n\r' '   ' | cut -c1-1024)"
  printf '%s\t%s\t%s\n' "$id" "$outcome" "$evidence"
}

# parse_params <params> — emit one `key\tvalue` line per recognized param key.
#   The verify-checks grammar is `<key>=<value>` space-separated, but a value may
#   itself contain a space (e.g. an ERE character class `[^ ]`), so a naive
#   space split corrupts the regex. This parser is key-aware: a new param begins
#   only at a token matching `^<knownkey>=`; every other token is a continuation
#   of the current value. Input is streamed through awk on stdin so backslashes
#   survive verbatim (unlike awk -v, which processes escapes).
parse_params() {
  printf '%s\n' "$1" | awk '{
    key=""; val=""
    n = split($0, w, " ")
    for (i = 1; i <= n; i++) {
      p = w[i]
      if (p ~ /^(polarity|regex|scope|count|exists|absent)=/) {
        if (key != "") print key "\t" val
        eq = index(p, "=")
        key = substr(p, 1, eq - 1)
        val = substr(p, eq + 1)
      } else if (key != "") {
        val = val " " p
      }
    }
    if (key != "") print key "\t" val
  }'
}

# check_pattern <id> <params> — run a pattern (must / must-not) check. Reads the
#   verify-checks params: polarity, regex, optional scope (default: territory),
#   optional count. The regex is handed to grep behind `-e`, search paths behind
#   `--`. A missing regex / bad polarity / unsafe scope / bad count → failed.
check_pattern() {
  local id="$1" params="$2"
  local polarity="" regex="" scope="" count="" k v
  while IFS=$'\t' read -r k v; do
    case "$k" in
      polarity) polarity="$v" ;;
      regex)    regex="$v" ;;
      scope)    scope="$v" ;;
      count)    count="$v" ;;
    esac
  done < <(parse_params "$params")
  if [[ -z "$regex" ]]; then emit_outcome "$id" failed "no regex parameter"; return; fi
  if [[ "$polarity" != "must" && "$polarity" != "must-not" ]]; then
    emit_outcome "$id" failed "invalid polarity parameter"; return
  fi
  if [[ -n "$count" && ! "$count" =~ ^[0-9]+$ ]]; then
    emit_outcome "$id" failed "invalid count parameter"; return
  fi
  local -a search=()
  if [[ -n "$scope" ]]; then
    if ! safe_path_param "$scope"; then emit_outcome "$id" failed "invalid scope parameter"; return; fi
    search=("$scope")
  elif [[ ${#terr_paths[@]} -gt 0 ]]; then
    search=("${terr_paths[@]}")
  else
    search=(".")
  fi
  # Scoped mode: intersect the search base with the listed change set. An
  # invariant no listed file falls under makes no record (falls to the caller's
  # sweep), so the floor never spuriously judges code the change did not touch.
  if [[ ${has_filelist:-0} -eq 1 ]]; then
    local -a scoped_search=()
    local sf base
    for sf in "${scope_files[@]}"; do
      for base in "${search[@]}"; do
        if path_under "$sf" "$base"; then scoped_search+=("$sf"); break; fi
      done
    done
    if [[ ${#scoped_search[@]} -eq 0 ]]; then return; fi
    search=("${scoped_search[@]}")
  fi
  local out n
  # Force -H in scoped mode: a single listed file otherwise greps without a
  # filename prefix, and must-not evidence must carry file:line so the caller's
  # two-channel classifier can attribute it to the trusted change set. Whole-group
  # (no files-list) keeps the exact original invocation (byte-compatible).
  local -a gflags=(-rnE)
  [[ ${has_filelist:-0} -eq 1 ]] && gflags=(-rHnE)
  out="$(grep "${gflags[@]}" -e "$regex" -- "${search[@]}" 2>/dev/null)" || true
  if [[ -z "$out" ]]; then n=0; else n="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"; fi
  local outcome evidence
  if [[ -n "$count" ]]; then
    if [[ "$n" -eq "$count" ]]; then outcome=holds;    evidence="matched $n (expected $count)"
    else                             outcome=violated; evidence="matched $n, expected $count"; fi
  elif [[ "$polarity" == "must" ]]; then
    if [[ "$n" -gt 0 ]]; then outcome=holds;    evidence="$n match(es)"
    else                      outcome=violated; evidence="required pattern not found in scope"; fi
  else
    if [[ "$n" -eq 0 ]]; then outcome=holds;    evidence="no forbidden matches"
    else                      outcome=violated; evidence="$(printf '%s\n' "$out" | head -n 3 | cut -d: -f1,2 | tr '\n' ' ')"; fi
  fi
  emit_outcome "$id" "$outcome" "$evidence"
}

# check_structure <id> <params> — run a structure check: exists=<relpath> (holds
#   iff the path exists) or absent=<glob> (holds iff nothing matches). The path /
#   glob passes safe_path_param before use; the glob is anchored under `./` so it
#   can never be read as a find option (Finding 6).
check_structure() {
  local id="$1" params="$2"
  local exists="" absent="" k v
  while IFS=$'\t' read -r k v; do
    case "$k" in
      exists) exists="$v" ;;
      absent) absent="$v" ;;
    esac
  done < <(parse_params "$params")
  # Scoped mode: run only when the change set touches this check's subject;
  # otherwise no record (the invariant falls to the caller's sweep/judge).
  if [[ ${has_filelist:-0} -eq 1 ]] && ! structure_relevant "$exists" "$absent"; then
    return
  fi
  if [[ -n "$exists" ]]; then
    if ! safe_path_param "$exists"; then emit_outcome "$id" failed "invalid exists parameter"; return; fi
    if [[ -e "$exists" ]]; then emit_outcome "$id" holds "$exists exists"
    else                        emit_outcome "$id" violated "$exists is absent"; fi
    return
  fi
  if [[ -n "$absent" ]]; then
    if ! safe_path_param "$absent"; then emit_outcome "$id" failed "invalid absent parameter"; return; fi
    local hit
    hit="$(find . -path "./$absent" -print 2>/dev/null | head -n 3 | tr '\n' ' ')" || true
    if [[ -z "$hit" ]]; then emit_outcome "$id" holds "no match for $absent"
    else                     emit_outcome "$id" violated "present: $hit"; fi
    return
  fi
  emit_outcome "$id" failed "no exists/absent parameter"
}

# check_conformance — emit a TERRITORY-CONFORMANCE record for every tracked file
#   outside every declared territory path (the deterministic set difference).
#   The skill frames attribution (group code = violation, docs/config =
#   informational); the script only emits the raw data (DD #8). Reads the
#   dynamically-scoped terr_paths from cmd_check.
check_conformance() {
  local f t tp inside
  # Scoped mode: the conformance scan set is the listed change set, not every
  # tracked file — a pre-existing outside file the change never touched is not
  # re-flagged on every scoped run (interface contract).
  if [[ ${has_filelist:-0} -eq 1 ]]; then
    for f in "${scope_files[@]}"; do
      inside=0
      for t in "${terr_paths[@]}"; do
        tp="${t%/}/"
        case "$f/" in "$tp"*) inside=1; break ;; esac
      done
      [[ $inside -eq 0 ]] && printf 'TERRITORY-CONFORMANCE\t%s\n' "$f"
    done
    return 0
  fi
  git ls-files 2>/dev/null | while IFS= read -r f; do
    inside=0
    for t in "${terr_paths[@]}"; do
      tp="${t%/}/"
      case "$f/" in
        "$tp"*) inside=1; break ;;
      esac
    done
    if [[ $inside -eq 0 ]]; then printf 'TERRITORY-CONFORMANCE\t%s\n' "$f"; fi
  done
}

# cmd_check <blueprint-dir> <map-path> <group> — run the mechanical floor: every
#   pattern/structure invariant scoped to the group's declared territory, plus
#   territory conformance. registry / judge / malformed invariants are NOT run
#   here (the skill executes the registry via the Bash tool and fans out judges);
#   this verb owns only the deterministic floor. With no declared territory the
#   floor runs unscoped and emits the UNSCOPED sentinel, skipping conformance.
cmd_check() {
  local bpdir="${1:-}" map="${2:-}" group="${3:-}"
  if [[ -z "$bpdir" || -z "$map" || -z "$group" ]]; then
    echo "jimverify check: need <blueprint-dir> <map-path> <group>" >&2; return 2
  fi
  local spec="$bpdir/spec.md"
  if [[ ! -f "$spec" ]]; then echo "jimverify check: blueprint spec not found: $spec" >&2; return 2; fi
  if [[ ! "$group" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimverify check: invalid group: $group" >&2; return 2
  fi
  # Optional 4th arg: a files-list scoping the floor to a change set (spec 036).
  # Absent → whole-group (byte-compatible). Present → each line re-gated through
  # safe_scope_file; safe lines become the scope, unsafe lines emit HYGIENE and
  # are excluded (never mis-scoped, security.md Finding 10). An unreadable list
  # is a contained rc 2 so the caller degrades rather than running whole-group.
  local flist="${4:-}"
  local has_filelist=0
  local -a scope_files=()
  if [[ -n "$flist" ]]; then
    if [[ ! -r "$flist" ]]; then echo "jimverify check: files-list not readable: $flist" >&2; return 2; fi
    has_filelist=1
    local fl
    while IFS= read -r fl || [[ -n "$fl" ]]; do
      [[ -z "$fl" ]] && continue
      if safe_scope_file "$fl"; then scope_files+=("$fl")
      else printf 'HYGIENE\t%s\n' "$fl"; fi
    done < "$flist"
  fi
  # Resolve territory (valid paths only; HYGIENE lines are advisory, not scope).
  local terr_valid=""
  if [[ -f "$map" ]]; then
    terr_valid="$(cmd_territory "$map" "$group" 2>/dev/null | grep -v '^HYGIENE'"$(printf '\t')" || true)"
  fi
  local -a terr_paths=()
  local line
  if [[ -n "$terr_valid" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && terr_paths+=("$line")
    done <<< "$terr_valid"
  fi
  local scoped=1
  if [[ ${#terr_paths[@]} -eq 0 ]]; then scoped=0; printf 'UNSCOPED\n'; fi
  # Run the floor for pattern/structure invariants.
  local id crit method params inv
  cmd_parse "$spec" | while IFS=$'\t' read -r id crit method params inv; do
    case "$method" in
      pattern)   check_pattern   "$id" "$params" ;;
      structure) check_structure "$id" "$params" ;;
    esac
  done
  # Territory conformance is only meaningful when a territory is declared.
  if [[ $scoped -eq 1 ]]; then check_conformance; fi
  return 0
}

# ─── Section: faces — provides/requires + contract-checks (spec 037) ─────────

# cmd_faces <blueprint-spec.md> — emit one normalized TSV record per Provides /
#   Requires face entry, joined with the optional `contract-checks` block. A
#   single awk pass collects the block and both face sections regardless of
#   order, then emits at END. The record *structure* is script-normalized and
#   trusted; the carried `text`/`params` face content stays UNTRUSTED DATA the
#   skill wraps under its Step-8 discipline — the same split the `parse` verb
#   documents, restated so it survives for faces (security Finding 7).
cmd_faces() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then echo "jimverify faces: need <blueprint-spec.md>" >&2; return 2; fi
  if [[ ! -f "$file" ]]; then echo "jimverify faces: file not found: $file" >&2; return 2; fi
  awk '
    function san(x) { gsub(/\t/, " ", x); gsub(/\r/, "", x); if (length(x) > 1024) x = substr(x, 1, 1024); return x }
    function is_slug(x) { return x ~ /^[a-z0-9][a-z0-9-]*$/ }
    function slugify(x,   s) { s = tolower(x); gsub(/[^a-z0-9]+/, "-", s); gsub(/^-+|-+$/, "", s); return s }
    # crit_of — the criticality= token value (values are single, space-free tokens).
    function crit_of(p,   s) {
      if (match(p, /(^|[ \t])criticality=[^ \t]+/)) {
        s = substr(p, RSTART, RLENGTH); sub(/^[ \t]*criticality=/, "", s); return s
      }
      return ""
    }
    # scope_unsafe — a cheap in-parser shape gate on the scope= path (absolute,
    #   leading dash, or a `..` segment). contracts-check re-gates every path at
    #   execution via safe_path_param; this is early, defense-in-depth flagging.
    function scope_unsafe(p,   s) {
      if (match(p, /(^|[ \t])scope=[^ \t]+/)) {
        s = substr(p, RSTART, RLENGTH); sub(/^[ \t]*scope=/, "", s)
        if (s ~ /^\//) return 1
        if (s ~ /^-/) return 1
        if (s ~ /(^|\/)\.\.(\/|$)/) return 1
      }
      return 0
    }
    BEGIN { in_prov = 0; in_req = 0; in_cc = 0; np = 0; nr = 0 }

    # contract-checks fenced block (anywhere): <entry-slug> <key>=<value>...
    /^```contract-checks[ \t]*$/ { in_cc = 1; next }
    in_cc && /^```/ { in_cc = 0; next }
    in_cc {
      line = $0; sub(/^[ \t]+/, "", line)
      if (line == "") next
      cid = line;  sub(/[ \t].*$/, "", cid)          # first token = entry-slug
      rest = line; sub(/^[^ \t]+[ \t]*/, "", rest)   # remainder = params
      if (!is_slug(cid)) next                        # bad key slug → inert orphan
      cparams[cid] = rest
      next
    }

    # section tracking — the specific face headings consume their line (next),
    # so only OTHER H2 headings fall through to the reset rule.
    /^##[ \t]+Provides[ \t]*$/ { in_prov = 1; in_req = 0; next }
    /^##[ \t]+Requires[ \t]*$/ { in_req = 1; in_prov = 0; next }
    /^##[ \t]/ { in_prov = 0; in_req = 0 }

    (in_prov || in_req) && /^[ \t]*[-*][ \t]+`/ {
      line = $0
      if (!match(line, /`[^`]*`/)) next
      surf = substr(line, RSTART + 1, RLENGTH - 2)
      text = substr(line, RSTART + RLENGTH)
      sub(/^[ \t]+/, "", text)
      sub(/^—[ \t]*/, "", text)      # em-dash separator
      sub(/^-[ \t]*/, "", text)      # hyphen separator
      if (in_prov) { np++; psurf[np] = surf; ptext[np] = text }
      else         { nr++; rref[nr]  = surf; rtext[nr] = text }
    }

    END {
      for (i = 1; i <= np; i++) {
        slug = slugify(psurf[i])
        if (!is_slug(slug)) {
          printf "provides\t%s\t-\t-\tmalformed:unslugifiable provides surface\t%s\n", san(psurf[i]), san(ptext[i])
          continue
        }
        crit = "-"; params = "-"
        if (slug in cparams) {
          p = cparams[slug]; c = crit_of(p)
          if (c != "" && c !~ /^(critical|high|medium|low)$/) params = "malformed:invalid criticality"
          else if (scope_unsafe(p))                           params = "malformed:unsafe scope"
          else { params = p; if (c != "") crit = c }
        }
        printf "provides\t%s\t-\t%s\t%s\t%s\n", san(slug), san(crit), san(params), san(ptext[i])
      }
      for (i = 1; i <= nr; i++) {
        ref = rref[i]; slug = slugify(ref)
        if (!is_slug(slug)) slug = san(ref)
        target = "-"; grp = ref; sub(/\..*$/, "", grp)
        if (is_slug(grp) && ref ~ /\./) target = ref
        printf "requires\t%s\t%s\t-\t-\t%s\n", san(slug), san(target), san(rtext[i])
      }
    }
  ' "$file"
}

# ─── Section: edges — the persisted contract graph (spec 037) ────────────────

# cmd_edges <map-path> — emit the persisted `## Contract Graph` as one edge per
#   line: consumer \t relies-on \t provider. The reconcile pass is the graph's
#   sole writer; this verb only reads it. Consumer/provider cells must be valid
#   group slugs (a crafted cell can never smuggle a path or shift columns); the
#   relies-on cell is free text, sanitized only. A row failing the slug gate
#   emits `HYGIENE \t <row>` and is excluded. rc 2 when there is no Contract
#   Graph section — the caller names that degradation (DD 8), never fabricating
#   an empty graph. A present-but-empty graph ("Nothing to reconcile") emits
#   nothing and exits 0.
cmd_edges() {
  local map="${1:-}"
  if [[ -z "$map" ]]; then echo "jimverify edges: need <map-path>" >&2; return 2; fi
  if [[ ! -f "$map" ]]; then echo "jimverify edges: map not found: $map" >&2; return 2; fi
  if ! awk '/^##[ \t]+Contract Graph[ \t]*$/ { f = 1 } END { exit(f ? 0 : 1) }' "$map"; then
    echo "jimverify edges: no Contract Graph section: $map" >&2; return 2
  fi
  awk '
    function san(x) { gsub(/\t/, " ", x); gsub(/\r/, "", x); if (length(x) > 512) x = substr(x, 1, 512); return x }
    function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
    function is_slug(x) { return x ~ /^[a-z0-9][a-z0-9-]*$/ }
    BEGIN { FS = "|"; insec = 0 }
    /^##[ \t]+Contract Graph[ \t]*$/ { insec = 1; next }
    insec && /^##[ \t]/ { insec = 0 }
    insec && /^[ \t]*\|/ {
      c1 = trim($2); c2 = trim($3); c3 = trim($4)
      if (c1 ~ /^:?-+:?$/) next               # separator row
      if (tolower(c1) == "consumer") next      # header row
      if (is_slug(c1) && is_slug(c3)) printf "%s\t%s\t%s\n", san(c1), san(c2), san(c3)
      else                            printf "HYGIENE\t%s\n", san(trim($0))
    }
  ' "$map"
  return 0
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

main() {
  local sub="${1:-}"
  case "$sub" in
    parse)     shift; cmd_parse "$@" ;;
    territory) shift; cmd_territory "$@" ;;
    check)     shift; cmd_check "$@" ;;
    faces)     shift; cmd_faces "$@" ;;
    edges)     shift; cmd_edges "$@" ;;
    *) usage; return 2 ;;
  esac
}

main "$@"
exit $?
