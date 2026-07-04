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
#   check     <blueprint-dir> <map> <group>  (spec 035 Task 4) run the mechanical
#                                          floor and emit per-invariant outcomes.
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
  check     <blueprint-dir> <map-path> <group>  run the mechanical floor
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

# ─── Section: Argument dispatch ──────────────────────────────────────────────

main() {
  local sub="${1:-}"
  case "$sub" in
    parse)     shift; cmd_parse "$@" ;;
    territory) shift; cmd_territory "$@" ;;
    *) usage; return 2 ;;
  esac
}

main "$@"
exit $?
