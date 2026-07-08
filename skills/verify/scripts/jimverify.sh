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
#   scope-census <blueprint-dir> <map-path> <group>  (spec 041) per
#                                          pattern/structure invariant, the
#                                          count of tracked files its resolved
#                                          scope covers — the staleness fact the
#                                          `check` grammar cannot express.
#
# scope-census OUTPUT (TAB-separated):
#   SCOPE \t <id> \t <count|na> \t <kind> \t <scope-desc>
#     - kind ∈ pattern | exists | absent
#     - count: tracked files under (pattern/exists) or matching (absent) the
#       resolved scope; `na` on a non-git tree (unavailable ≠ zero, AC #6)
#     - scope-desc: the resolved scope path(s) or `territory` (location-only)
#   UNSCOPED                               no territory declared (caller names it)
#   HYGIENE \t <scope>                     an explicit scope failing safe_path_param
#   judge/registry/malformed invariants emit no SCOPE record. The untrusted scope
#   is never handed to git as a pathspec (Finding 4). rc 2 on bad args.
#
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
#     - params: the entry's joined contract-checks line, or "-"; a malformed
#       criticality value degrades to "malformed:<reason>" — never a silent
#       drop. Path safety of a scope= value is NOT gated here: it is enforced at
#       execution by contracts-check's safe_path_param (the single validation
#       boundary), which degrades the check to `failed` if unsafe.
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
#   contracts-check <map-path> <specs-root> [files-list]  (spec 037) the
#                                          deterministic cross-group floor.
#
# contracts-check OUTPUT (record types, TAB-separated):
#   COVERAGE \t <groups-mapped> \t <groups-with-blueprints>   coverage fact
#   UNSCOPED-GROUP \t <group>                a mapped group with no territory
#   CROSS-REF \t <consumer> \t <file:line> \t <provider>   a consumer-territory
#                                          reference into provider territory —
#                                          a code-level-leak candidate, evidence
#                                          location-only (matched content never
#                                          emitted, Finding 2)
#   <consumer>><provider>#<entry-slug> \t <side> \t <outcome> \t <evidence>
#                                          a face-declared provider-ref /
#                                          consumer-ref pattern outcome
#                                          (holds | violated | failed); side ∈
#                                          provider | consumer
#   HYGIENE \t <line>                        an excluded unsafe files-list line
#   The optional files-list scopes every scan to the change set. CROSS-REF facts
#   are candidates the skill classifies — never autonomous verdicts (DD 1).
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
  scope-census <blueprint-dir> <map-path> <group>  per-invariant scope population (retirement)
  faces     <blueprint-spec.md>              provides/requires + contract-checks → TSV
  edges     <map-path>                        persisted Contract Graph → consumer/relies-on/provider
  contracts-check <map-path> <specs-root> [files-list]  cross-group floor: CROSS-REF facts + edge outcomes
  health    <map-path>                        graph-quality metrics: groups/edges/cycles/fan-in/coverage
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
#   The verify-checks / contract-checks grammar is `<key>=<value>` space-separated,
#   but a value may itself contain a space (e.g. an ERE character class `[^ ]` or
#   `provider-ref=function getIdentity`), so a naive space split corrupts the
#   regex. This parser is key-aware: a new param begins only at a token matching
#   `^<knownkey>=`; every other token is a continuation of the current value.
#   Input is streamed through awk on stdin so backslashes survive verbatim
#   (unlike awk -v, which processes escapes). The recognized-key set spans both
#   the verify-checks keys and the spec-037 contract-checks keys — additive, so
#   an unrelated grammar simply never sees the extra keys.
parse_params() {
  printf '%s\n' "$1" | awk '{
    key=""; val=""
    n = split($0, w, " ")
    for (i = 1; i <= n; i++) {
      p = w[i]
      if (p ~ /^(polarity|regex|scope|count|exists|absent|criticality|provider-ref|consumer-ref)=/) {
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

# ─── Section: scope-census — retirement staleness facts (spec 041) ───────────

# emit_scope <id> <count> <kind> <scope-desc> — one scope-census fact record.
#   count is a non-negative integer or `na` (non-git tree). scope-desc is
#   location-only (a declared path or `territory`), sanitized so untrusted
#   blueprint content can never shift TSV columns (the emit_outcome discipline).
emit_scope() {
  local id="$1" count="$2" kind="$3" desc="$4"
  desc="$(printf '%s' "$desc" | tr '\t\n\r' '   ' | cut -c1-512)"
  printf 'SCOPE\t%s\t%s\t%s\t%s\n' "$id" "$count" "$kind" "$desc"
}

# cmd_scope_census <blueprint-dir> <map-path> <group> — emit, per pattern /
#   structure invariant, the count of tracked files its resolved scope covers:
#   the one staleness fact the `check` grammar cannot express (a must-not over
#   an empty scope reads `holds`, indistinguishable from a genuinely-clean
#   scope). Facts only — the retirement skill classifies (Bash-vs-Prompt).
#   Counting mirrors check_conformance: `git ls-files` is enumerated ONCE with
#   NO pathspec and filtered by path_under in bash. The untrusted scope is NEVER
#   handed to git as a pathspec — git pathspec-magic (`:(exclude)…`, `:/`) can
#   slip past the relpath shape gate (security Finding 4); a magic scope either
#   fails safe_path_param (HYGIENE) or is counted literally (0). judge /
#   registry / malformed invariants have no mechanical scope and emit nothing.
cmd_scope_census() {
  local bpdir="${1:-}" map="${2:-}" group="${3:-}"
  if [[ -z "$bpdir" || -z "$map" || -z "$group" ]]; then
    echo "jimverify scope-census: need <blueprint-dir> <map-path> <group>" >&2; return 2
  fi
  local spec="$bpdir/spec.md"
  if [[ ! -f "$spec" ]]; then echo "jimverify scope-census: blueprint spec not found: $spec" >&2; return 2; fi
  if [[ ! "$group" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "jimverify scope-census: invalid group: $group" >&2; return 2
  fi
  # Resolve territory (valid paths only; HYGIENE lines are advisory), as cmd_check does.
  local terr_valid=""
  if [[ -f "$map" ]]; then
    terr_valid="$(cmd_territory "$map" "$group" 2>/dev/null | grep -v '^HYGIENE'"$(printf '\t')" || true)"
  fi
  local -a terr_paths=()
  local line
  if [[ -n "$terr_valid" ]]; then
    while IFS= read -r line; do [[ -n "$line" ]] && terr_paths+=("$line"); done <<< "$terr_valid"
  fi
  local scoped=1
  if [[ ${#terr_paths[@]} -eq 0 ]]; then scoped=0; printf 'UNSCOPED\n'; fi
  # Enumerate tracked files ONCE, no pathspec. A non-git tree → `na` per
  # invariant (unavailable ≠ zero — AC #6), never a false emptiness signal.
  local gitfiles rc_git
  gitfiles="$(git ls-files 2>/dev/null)"; rc_git=$?
  local id crit method params inv
  while IFS=$'\t' read -r id crit method params inv; do
    local kind="" k v scope="" exists="" absent=""
    case "$method" in
      pattern)
        while IFS=$'\t' read -r k v; do [[ "$k" == scope ]] && scope="$v"; done < <(parse_params "$params")
        kind=pattern
        ;;
      structure)
        while IFS=$'\t' read -r k v; do
          [[ "$k" == exists ]] && exists="$v"
          [[ "$k" == absent ]] && absent="$v"
        done < <(parse_params "$params")
        if   [[ -n "$exists" ]]; then kind=exists; scope="$exists"
        elif [[ -n "$absent" ]]; then kind=absent; scope="$absent"
        else continue    # malformed structure (no exists/absent) → no scope fact
        fi
        ;;
      *) continue ;;      # judge / registry / malformed → no mechanical scope
    esac
    if [[ $rc_git -ne 0 ]]; then
      emit_scope "$id" na "$kind" "${scope:-territory}"; continue
    fi
    local -a bases=(); local desc=""
    if [[ "$kind" == pattern && -z "$scope" ]]; then
      if [[ $scoped -eq 1 ]]; then bases=("${terr_paths[@]}"); else bases=("."); fi
      desc=territory
    else
      if ! safe_path_param "$scope"; then printf 'HYGIENE\t%s\n' "$scope"; continue; fi
      bases=("$scope"); desc="$scope"
    fi
    local count=0 f b
    if [[ "$kind" == absent ]]; then
      # A forbidden-glob count is not a staleness signal (the skill excludes
      # kind=absent, DD 3); reported for completeness via bash glob match.
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        # shellcheck disable=SC2053  # deliberate glob match against the absent pattern
        [[ "$f" == $scope ]] && count=$((count + 1))
      done <<< "$gitfiles"
    else
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        for b in "${bases[@]}"; do
          if path_under "$f" "$b"; then count=$((count + 1)); break; fi
        done
      done <<< "$gitfiles"
    fi
    emit_scope "$id" "$count" "$kind" "$desc"
  done < <(cmd_parse "$spec")
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

# ─── Section: contracts-check — the composite cross-group floor (spec 037) ───

# groups_of <map-path> — emit each group slug declared under `## Groups` (the
#   `### <group>` H3 subsections). The section ends at the next H2.
groups_of() {
  awk '
    /^##[ \t]+Groups[ \t]*$/ { insec = 1; next }
    insec && /^##[ \t]/ { insec = 0 }
    insec && /^###[ \t]+/ { g = $0; sub(/^###[ \t]+/, "", g); sub(/[ \t].*$/, "", g); if (g != "") print g }
  ' "$1"
}

# terr_of <map-path> <group> — the group's validated territory paths (HYGIENE
#   lines dropped). Reuses cmd_territory, which slug-validates the group and
#   valid-relpath-gates each path.
terr_of() {
  cmd_territory "$1" "$2" 2>/dev/null | grep -v "^HYGIENE$(printf '\t')" || true
}

# intersect_scope <base-path>... — in whole mode echo the base paths unchanged;
#   in scoped mode echo each change-set file (scope_files) that falls under one
#   of the base paths. Reads has_filelist / scope_files from the caller via
#   bash's dynamic scope — the same idiom check_pattern uses.
intersect_scope() {
  local -a bases=("$@")
  if [[ ${has_filelist:-0} -ne 1 ]]; then
    [[ ${#bases[@]} -gt 0 ]] && printf '%s\n' "${bases[@]}"
    return
  fi
  local sf base
  for sf in "${scope_files[@]}"; do
    for base in "${bases[@]}"; do
      if path_under "$sf" "$base"; then printf '%s\n' "$sf"; break; fi
    done
  done
}

# emit_edge <edge-key> <side> <outcome> <evidence> — one edge pattern-outcome
#   record. Evidence is sanitized (tabs/newlines/CRs → spaces, capped) so
#   untrusted code/blueprint content can never shift TSV columns (Finding 7) and
#   is location-only by construction at every call site (Finding 2).
emit_edge() {
  local ev; ev="$(printf '%s' "$4" | tr '\t\n\r' '   ' | cut -c1-512)"
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$ev"
}

# contract_ref_check <edge-key> <side> <ere> <scope> <group> <map> <absent-outcome>
#   Run a face-declared reference pattern with must-find semantics over the
#   group's territory (or the declared provider-side scope, re-gated through
#   safe_path_param). A match → holds with a file:line (never the matched line
#   content). No match → the <absent-outcome>: `violated` (a provider must still
#   expose the declared surface — a code-level breaking) or `abstain` (a consumer
#   not exercising the surface is not itself a code-level violation — it falls to
#   the judge / cross-ref floor). An unsafe scope → failed. Scoped runs intersect
#   the base with the change set; a fully scoped-out base abstains.
contract_ref_check() {
  local ekey="$1" side="$2" ere="$3" scope="$4" group="$5" map="$6" absent="$7"
  local -a bases=()
  if [[ -n "$scope" ]]; then
    if ! safe_path_param "$scope"; then emit_edge "$ekey" "$side" failed "invalid scope parameter"; return; fi
    bases=("$scope")
  else
    local terr l
    terr="$(terr_of "$map" "$group")"
    while IFS= read -r l; do [[ -n "$l" ]] && bases+=("$l"); done <<< "$terr"
  fi
  [[ ${#bases[@]} -eq 0 ]] && return
  local -a search=() l2
  while IFS= read -r l2; do [[ -n "$l2" ]] && search+=("$l2"); done < <(intersect_scope "${bases[@]}")
  [[ ${#search[@]} -eq 0 ]] && return
  local out
  out="$(grep -rHnE -e "$ere" -- "${search[@]}" 2>/dev/null | head -n 1)" || true
  if [[ -n "$out" ]]; then
    emit_edge "$ekey" "$side" holds "$(printf '%s' "$out" | cut -d: -f1,2)"
  elif [[ "$absent" == "violated" ]]; then
    emit_edge "$ekey" "$side" violated "declared surface pattern not found in $group territory"
  fi
}

# cmd_contracts_check <map-path> <specs-root> [files-list] — the deterministic
#   cross-group floor over every blueprint-bearing group pair. Emits COVERAGE
#   and per-group UNSCOPED-GROUP facts, CROSS-REF reference facts (consumer
#   territory referencing provider territory, location-only), and face-declared
#   provider-ref/consumer-ref pattern outcomes per graph edge. The optional
#   files-list scopes every scan to the listed change set (the spec-036 4th-arg
#   semantics, re-gated through safe_scope_file). No matched content is ever
#   emitted; every path-bearing value passes safe_path_param before use.
cmd_contracts_check() {
  local map="${1:-}" specs_root="${2:-}"
  if [[ -z "$map" || -z "$specs_root" ]]; then
    echo "jimverify contracts-check: need <map-path> <specs-root>" >&2; return 2
  fi
  if [[ ! -f "$map" ]]; then echo "jimverify contracts-check: map not found: $map" >&2; return 2; fi

  # Optional files-list: re-gate each line, HYGIENE the unsafe (Finding 10).
  local flist="${3:-}"
  local has_filelist=0
  local -a scope_files=()
  if [[ -n "$flist" ]]; then
    if [[ ! -r "$flist" ]]; then echo "jimverify contracts-check: files-list not readable: $flist" >&2; return 2; fi
    has_filelist=1
    local fl
    while IFS= read -r fl || [[ -n "$fl" ]]; do
      [[ -z "$fl" ]] && continue
      if safe_scope_file "$fl"; then scope_files+=("$fl"); else printf 'HYGIENE\t%s\n' "$fl"; fi
    done < "$flist"
  fi

  # Mapped groups (valid slugs only) + coverage.
  local -a groups=()
  local g
  while IFS= read -r g; do
    [[ -z "$g" ]] && continue
    [[ "$g" =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
    groups+=("$g")
  done < <(groups_of "$map")

  local mapped=${#groups[@]} withbp=0 bp
  for g in "${groups[@]}"; do
    bp="$specs_root/$g/000-blueprint/spec.md"
    [[ -f "$bp" ]] && withbp=$((withbp + 1))
    if [[ -z "$(terr_of "$map" "$g")" ]]; then printf 'UNSCOPED-GROUP\t%s\n' "$g"; fi
  done
  printf 'COVERAGE\t%s\t%s\n' "$mapped" "$withbp"

  # CROSS-REF facts: consumer territory referencing provider territory. The
  # provider path is a fixed string (never a regex), behind -e / --.
  local C P tp cterr pterr l out ln loc
  for C in "${groups[@]}"; do
    cterr="$(terr_of "$map" "$C")"
    [[ -z "$cterr" ]] && continue
    local -a cbases=() csearch=()
    while IFS= read -r l; do [[ -n "$l" ]] && cbases+=("$l"); done <<< "$cterr"
    while IFS= read -r l; do [[ -n "$l" ]] && csearch+=("$l"); done < <(intersect_scope "${cbases[@]}")
    [[ ${#csearch[@]} -eq 0 ]] && continue
    for P in "${groups[@]}"; do
      [[ "$P" == "$C" ]] && continue
      pterr="$(terr_of "$map" "$P")"
      [[ -z "$pterr" ]] && continue
      while IFS= read -r tp; do
        [[ -z "$tp" ]] && continue
        out="$(grep -rHnF -e "$tp" -- "${csearch[@]}" 2>/dev/null | head -n 50)" || true
        [[ -z "$out" ]] && continue
        while IFS= read -r ln; do
          loc="$(printf '%s' "$ln" | cut -d: -f1,2)"
          printf 'CROSS-REF\t%s\t%s\t%s\n' "$C" "$(printf '%s' "$loc" | tr '\t\n\r' '   ' | cut -c1-512)" "$P"
        done <<< "$out"
      done <<< "$pterr"
    done
  done

  # Pattern outcomes from face check-data, per graph edge.
  local relies kind slug tgt crit params text pbp pref cref cscope k v ekey
  cmd_edges "$map" 2>/dev/null | while IFS=$'\t' read -r C relies P; do
    [[ "$C" == "HYGIENE" ]] && continue
    [[ "$C" =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
    [[ "$P" =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
    pbp="$specs_root/$P/000-blueprint/spec.md"
    [[ -f "$pbp" ]] || continue
    cmd_faces "$pbp" 2>/dev/null | while IFS=$'\t' read -r kind slug tgt crit params text; do
      [[ "$kind" == "provides" ]] || continue
      [[ "$params" == "-" || "$params" == malformed:* ]] && continue
      pref=""; cref=""; cscope=""
      while IFS=$'\t' read -r k v; do
        case "$k" in
          provider-ref) pref="$v" ;;
          consumer-ref) cref="$v" ;;
          scope)        cscope="$v" ;;
        esac
      done < <(parse_params "$params")
      ekey="$C>$P#$slug"
      # scope= narrows the provider-side base only (where the surface lives);
      # the consumer side always scans the consumer's own territory.
      [[ -n "$pref" ]] && contract_ref_check "$ekey" provider "$pref" "$cscope" "$P" "$map" violated
      [[ -n "$cref" ]] && contract_ref_check "$ekey" consumer "$cref" ""       "$C" "$map" abstain
    done
  done
  return 0
}

# ─── Section: health — graph-quality metrics (spec 039) ──────────────────────

# cmd_health <map-path> — emit deterministic partition-quality measurements over
#   the just-persisted `## Contract Graph` plus territory coverage. Facts are
#   TAB-separated and san()-sanitized; group names arrive already slug-validated
#   from cmd_edges, so a crafted cell is HYGIENE-excluded upstream and can never
#   shift columns or smuggle a node. Measurement-only: no verdicts, thresholds,
#   or pass/fail wording — the skill frames, downstream sensors judge (spec 034
#   no-standing-verdict doctrine). rc 2 when the map is unreadable or carries no
#   `## Contract Graph` section (the caller names the degradation, mirroring the
#   edges verb).
cmd_health() {
  local map="${1:-}"
  if [[ -z "$map" ]]; then echo "jimverify health: need <map-path>" >&2; return 2; fi
  if [[ ! -f "$map" ]]; then echo "jimverify health: map not found: $map" >&2; return 2; fi
  if ! awk '/^##[ \t]+Contract Graph[ \t]*$/ { f = 1 } END { exit(f ? 0 : 1) }' "$map"; then
    echo "jimverify health: no Contract Graph section: $map" >&2; return 2
  fi
  # GROUPS — mapped groups under `## Groups` (the coverage/density denominator).
  printf 'GROUPS\t%s\n' "$(groups_of "$map" | grep -c . || true)"
  # Graph metrics from the valid (non-HYGIENE) edge rows. cmd_edges already
  # slug-validates and sanitizes consumer/provider, so the nodes fed here are
  # inert; the awk dedupes edges, walks the directed graph for cycle clusters
  # (Kahn peel of sources/sinks → weakly-connected components of the cyclic
  # core, DD 2), and reports max provider in-degree with every tied group named.
  cmd_edges "$map" 2>/dev/null | awk -F'\t' '
    function san(x) { gsub(/\t/, " ", x); gsub(/\r/, "", x); if (length(x) > 512) x = substr(x, 1, 512); return x }
    $1 == "HYGIENE" { next }
    {
      c = $1; p = $3
      rows++
      ek = c SUBSEP p
      if (!(ek in eseen)) {
        eseen[ek] = 1
        m++; EU[m] = c; EV[m] = p
        nodes[c] = 1; nodes[p] = 1
      }
    }
    END {
      print "EDGES\t" rows + 0

      # Cycle clusters: iteratively peel nodes with in- or out-degree 0 in the
      # remaining subgraph; the survivors are exactly the on-cycle nodes. Their
      # weakly-connected components (union-find over the alive undirected edges)
      # are the clusters. Deterministic — cluster ids assigned in sorted-node
      # order, output sorted.
      for (nd in nodes) alive[nd] = 1
      changed = 1
      while (changed) {
        changed = 0
        for (nd in nodes) { ind[nd] = 0; outd[nd] = 0 }
        for (i = 1; i <= m; i++) if (alive[EU[i]] && alive[EV[i]]) { outd[EU[i]]++; ind[EV[i]]++ }
        for (nd in nodes) if (alive[nd] && (ind[nd] == 0 || outd[nd] == 0)) { alive[nd] = 0; changed = 1 }
      }
      for (nd in nodes) if (alive[nd]) parent[nd] = nd
      for (i = 1; i <= m; i++) if (alive[EU[i]] && alive[EV[i]]) union(EU[i], EV[i])
      na = 0
      for (nd in nodes) if (alive[nd]) { na++; AN[na] = nd }
      isort(AN, na)
      cid = 0
      for (i = 1; i <= na; i++) { r = find(AN[i]); if (!(r in clab)) { cid++; clab[r] = cid } }
      print "CYCLES\t" cid + 0
      for (i = 1; i <= na; i++) print "CYCLE\t" clab[find(AN[i])] "\t" san(AN[i])

      # Fan-in: max provider in-degree over deduped edges; name every group at
      # the max, sorted (ties → all).
      for (i = 1; i <= m; i++) indeg[EV[i]]++
      maxf = 0
      for (nd in nodes) { d = (nd in indeg) ? indeg[nd] : 0; if (d > maxf) maxf = d }
      print "FANIN\t" maxf + 0
      if (maxf > 0) {
        k = 0
        for (nd in nodes) if ((nd in indeg) && indeg[nd] == maxf) { k++; FG[k] = nd }
        isort(FG, k)
        for (i = 1; i <= k; i++) print "FANIN_GROUP\t" san(FG[i])
      }
    }
    function find(x) { while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x] } return x }
    function union(a, b,   ra, rb) { ra = find(a); rb = find(b); if (ra != rb) parent[rb] = ra }
    function isort(arr, n,   i, j, key) {
      for (i = 2; i <= n; i++) { key = arr[i]; j = i - 1; while (j >= 1 && arr[j] > key) { arr[j+1] = arr[j]; j-- } arr[j+1] = key }
    }
  '
  # Coverage — tracked source paths owned by no group's territory. Union the
  # validated territory paths across all groups (the conformance set-difference,
  # unioned). No path-bearing territory at all → not computable (no-territories);
  # a non-git tree → not computable (no-git). `na` never reads as "0 uncovered"
  # (AC #7); the reason keeps not-applicable distinct from measurement failure
  # (security Finding 5, the 035 vocabulary doctrine).
  local -a terr=()
  local g tline
  while IFS= read -r g; do
    [[ -z "$g" ]] && continue
    while IFS= read -r tline; do
      [[ -n "$tline" ]] && terr+=("$tline")
    done < <(terr_of "$map" "$g")
  done < <(groups_of "$map")
  if [[ ${#terr[@]} -eq 0 ]]; then
    printf 'UNCOVERED\tna\n'
    printf 'UNCOVERED_NA_REASON\tno-territories\n'
    return 0
  fi
  local gitfiles rc_git
  gitfiles="$(git ls-files 2>/dev/null)"; rc_git=$?
  if [[ $rc_git -ne 0 ]]; then
    printf 'UNCOVERED\tna\n'
    printf 'UNCOVERED_NA_REASON\tno-git\n'
    return 0
  fi
  # Set-difference + aggregate by containing directory. Untrusted working-tree
  # filenames are control-stripped and length-capped, and the rendered list is
  # aggregated (the skill further caps it) so alarm fatigue stays bounded
  # (security Finding 1). Territory prefixes are fed tagged; tracked files are
  # the untagged single-field lines (git never emits a tab inside a path).
  {
    printf 'T\t%s\n' "${terr[@]}"
    printf '%s\n' "$gitfiles"
  } | awk -F'\t' '
    function san(x) { gsub(/[[:cntrl:]]/, "", x); if (length(x) > 512) x = substr(x, 1, 512); return x }
    NF >= 2 && $1 == "T" { t = $2; sub(/\/+$/, "", t); pref[t "/"] = 1; next }
    {
      f = $0
      if (f == "") next
      for (p in pref) if (index(f "/", p) == 1) next    # under a territory → covered
      total++
      d = f
      if (index(d, "/") > 0) { sub(/\/[^/]*$/, "", d); d = d "/" } else d = "./"
      if (!(d in dc)) { nd++; DN[nd] = d }
      dc[d]++
    }
    END {
      print "UNCOVERED\t" total + 0
      for (i = 2; i <= nd; i++) { key = DN[i]; j = i - 1; while (j >= 1 && DN[j] > key) { DN[j+1] = DN[j]; j-- } DN[j+1] = key }
      for (i = 1; i <= nd; i++) print "UNCOVERED_DIR\t" san(DN[i]) "\t" dc[DN[i]]
    }
  '
  return 0
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

main() {
  local sub="${1:-}"
  case "$sub" in
    parse)           shift; cmd_parse "$@" ;;
    territory)       shift; cmd_territory "$@" ;;
    check)           shift; cmd_check "$@" ;;
    scope-census)    shift; cmd_scope_census "$@" ;;
    faces)           shift; cmd_faces "$@" ;;
    edges)           shift; cmd_edges "$@" ;;
    contracts-check) shift; cmd_contracts_check "$@" ;;
    health)          shift; cmd_health "$@" ;;
    *) usage; return 2 ;;
  esac
}

main "$@"
exit $?
