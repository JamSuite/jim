#!/usr/bin/env bash
#
# skills/partition/scripts/jimpartition.sh — deterministic extraction/coverage
#   substrate for /jim:partition (spec 038).
#
# PURPOSE
#   The Bash-owned half of the partition migration skill: import extraction, raw
#   extractor-output hygiene, group-edge aggregation, and territory coverage —
#   the set math, regex scanning, and validation that must be deterministic
#   (the Bash-vs-Prompt rule). Partition judgment, the interview, invariant
#   authoring, and every map/blueprint write live in the skill, not here.
#
# CLI SUMMARY
#   scan                              native import scan over `git ls-files`
#                                     → EDGE / CHANNEL / UNMODELED (imports only)
#   ingest <raw-file> <channel>       validate one extractor's raw edge lines
#                                     → EDGE / HYGIENE
#   aggregate <edges-file> <territories-file>
#                                     file edges × territories → group edges
#                                     → GEDGE / STRADDLE / UNASSIGNED
#   coverage <territories-file>       tracked files under no proposed territory
#                                     → UNCOVERED / TOTAL
#
#   All output is TAB-separated and field-sanitized (control-stripped,
#   length-capped). Emitted / declared paths pass the valid-relpath boundary
#   before use; this script NEVER resolves or executes a deps_command_<name>
#   value — the operator's config activates extractor commands and the model
#   runs them via the Bash tool (the spec 035 registry trust boundary).
#
# EXIT CODES
#   0  Success (HYGIENE / UNCOVERED counts may be > 0 — a report, not an error).
#   2  Malformed invocation, malformed caller-written input, or not a git tree.
#

set -uo pipefail
export LC_ALL=C

# jimfile.sh provides the single valid-relpath boundary (spec 033 security
# Finding 9). Resolved BASH_SOURCE-relative so it travels with the plugin tree
# (skills/partition/scripts/ → skills/file/scripts/).
JIMFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../file/scripts" 2>/dev/null && pwd)/jimfile.sh"

# ─── Section: Shared helpers ─────────────────────────────────────────────────

usage() {
  cat >&2 <<'USAGE'
usage: jimpartition.sh <subcommand> [args]
  scan                                          native import scan → EDGE/CHANNEL/UNMODELED
  ingest    <raw-file> <channel>                validate raw edges → EDGE/HYGIENE
  aggregate <edges-file> <territories-file>     group edges → GEDGE/STRADDLE/UNASSIGNED
  coverage  <territories-file>                  uncovered dirs → UNCOVERED/TOTAL
USAGE
}

# valid_relpath <path> — 0 iff <path> passes jimfile.sh's shape gate (the single
#   valid-relpath boundary: non-empty, not absolute, no '..' segment). Forked
#   like jimverify.sh's territory validation; callers apply it to the few
#   caller-written territory paths, so per-path cost is negligible.
valid_relpath() {
  bash "$JIMFILE" valid-relpath "$1" >/dev/null 2>&1
}

# valid_slug <s> — 0 iff <s> is slug-class (lowercase alnum + dash, alnum-start).
#   Inlined charset check (the jimverify.sh / jimconf.sh convention) — a stable
#   regex needs no boundary fork.
valid_slug() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

# ─── Section: coverage ───────────────────────────────────────────────────────

# cmd_coverage <territories-file> — tracked files owned by no proposed group's
#   territory, aggregated by containing directory (the 039 coverage rule), plus
#   a TOTAL count. The territories-file is caller-written (the skill writes it
#   from the approved partition), so every line is validated on read and a
#   malformed line is a caller error → rc 2, distinct from ingest's HYGIENE
#   counting of untrusted extractor output.
#
#   territories-file line: GROUP \t <group-slug> \t <repo-relative-path>
cmd_coverage() {
  local terr_file="${1:-}"
  if [[ -z "$terr_file" ]]; then
    echo "jimpartition coverage: need <territories-file>" >&2; return 2
  fi
  if [[ ! -f "$terr_file" ]]; then
    echo "jimpartition coverage: territories file not found: $terr_file" >&2; return 2
  fi

  local -a terr=()
  local line f1 f2 f3 rest
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    IFS=$'\t' read -r f1 f2 f3 rest <<<"$line"
    if [[ "$f1" != "GROUP" || -n "${rest:-}" || -z "${f3:-}" ]]; then
      echo "jimpartition coverage: malformed territories line: $line" >&2; return 2
    fi
    if ! valid_slug "$f2"; then
      echo "jimpartition coverage: invalid group slug: $f2" >&2; return 2
    fi
    if ! valid_relpath "$f3"; then
      echo "jimpartition coverage: invalid territory path: $f3" >&2; return 2
    fi
    terr+=("$f3")
  done < "$terr_file"

  local gitfiles rc_git
  gitfiles="$(git ls-files 2>/dev/null)"; rc_git=$?
  if [[ $rc_git -ne 0 ]]; then
    echo "jimpartition coverage: not a git work tree" >&2; return 2
  fi

  # Set-difference + aggregate by containing directory. Territory prefixes are
  # fed tagged (`T`); tracked files are the untagged single-field lines (git
  # quotes any path with a tab, so a tracked line never has NF>1). Untrusted
  # working-tree filenames are control-stripped and length-capped on output.
  {
    [[ ${#terr[@]} -gt 0 ]] && printf 'T\t%s\n' "${terr[@]}"
    printf '%s\n' "$gitfiles"
  } | awk -F'\t' '
    function san(x) { gsub(/[[:cntrl:]]/, "", x); if (length(x) > 512) x = substr(x, 1, 512); return x }
    NF >= 2 && $1 == "T" { t = $2; sub(/\/+$/, "", t); pref[t "/"] = 1; next }
    {
      f = $0
      if (f == "") next
      for (p in pref) if (index(f "/", p) == 1) next   # under a territory → covered
      total++
      d = f
      if (index(d, "/") > 0) { sub(/\/[^/]*$/, "", d); d = d "/" } else d = "./"
      if (!(d in dc)) { nd++; DN[nd] = d }
      dc[d]++
    }
    END {
      for (i = 2; i <= nd; i++) { key = DN[i]; j = i - 1; while (j >= 1 && DN[j] > key) { DN[j+1] = DN[j]; j-- } DN[j+1] = key }
      for (i = 1; i <= nd; i++) print "UNCOVERED\t" san(DN[i]) "\t" dc[DN[i]]
      print "TOTAL\t" total + 0
    }
  '
  return 0
}

# ─── Section: ingest ─────────────────────────────────────────────────────────

# cmd_ingest <raw-file> <channel> — validate one extractor's raw edge lines and
#   emit the clean, deduped edge set plus counted hygiene facts. Raw output is
#   UNTRUSTED (the native scan or an operator command), so unlike coverage's
#   caller-written territories-file a bad line is never fatal: it is counted and
#   dropped (the ingest choke point, security Finding 3).
#
#   Raw line: <from-relpath> \t <to-relpath> [\t <channel>]   (the deps_command
#   output contract; a per-edge 3rd field overrides the CLI <channel>).
#   Endpoint gate: valid-relpath (shape) AND tracked (a tracked file, or a
#   directory containing tracked files — Go edges are package dirs). Both
#   endpoints must pass or the whole edge is dropped.
#   HYGIENE reasons: malformed-line | unsafe-path | untracked.
cmd_ingest() {
  local raw="${1:-}" channel="${2:-}"
  if [[ -z "$raw" || -z "$channel" ]]; then
    echo "jimpartition ingest: need <raw-file> <channel>" >&2; return 2
  fi
  if [[ ! -f "$raw" || ! -r "$raw" ]]; then
    echo "jimpartition ingest: raw file not readable: $raw" >&2; return 2
  fi
  if ! valid_slug "$channel"; then
    echo "jimpartition ingest: invalid channel slug: $channel" >&2; return 2
  fi

  # The tracked-file set feeds the endpoint gate. Outside a git tree it is empty
  # (every endpoint then untracked) — ingest never rc-2s on no-git; only scan
  # requires a work tree.
  local gitfiles
  gitfiles="$(git ls-files 2>/dev/null)"

  # One awk pass: tracked files tagged `F` (all emitted before any `R` so the
  # tracked[]/dir[] sets are complete when edges are processed), raw lines tagged
  # `R`. safe() inlines jimfile.sh cmd_valid_relpath's shape rules (non-empty,
  # not absolute, no '..' segment) — the boundary is forked per-line only for the
  # few caller-written territory paths (coverage), never for untrusted edges at
  # ingest scale. Endpoint precedence: malformed-line > unsafe-path > untracked.
  {
    printf '%s\n' "$gitfiles" | awk 'NF { print "F\t" $0 }'
    awk '{ print "R\t" $0 }' "$raw"
  } | awk -F'\t' -v chan="$channel" '
    function san(x) { gsub(/[[:cntrl:]]/, "", x); if (length(x) > 512) x = substr(x, 1, 512); return x }
    function safe(p) {
      if (p == "") return 0
      if (substr(p, 1, 1) == "/") return 0             # absolute
      if (index("/" p "/", "/../") > 0) return 0        # ".." segment
      return 1
    }
    function tracked(e) { return (e in trk) || (e in dir) }
    $1 == "F" {
      f = $2
      trk[f] = 1
      d = f
      while (index(d, "/") > 0) { sub(/\/[^/]*$/, "", d); if (d == "") break; dir[d] = 1 }
      next
    }
    $1 == "R" {
      # $2=from $3=to $4=channel(optional). NF counts the R tag.
      from = (NF >= 2 ? $2 : "")
      to   = (NF >= 3 ? $3 : "")
      if (NF == 2 && from == "") next                   # blank line — benign, skip
      if (NF < 3 || NF > 4 || from == "" || to == "") { hy["malformed-line"]++; next }
      ch = chan
      if (NF == 4) {
        if ($4 !~ /^[a-z0-9][a-z0-9-]*$/) { hy["malformed-line"]++; next }
        ch = $4
      }
      if (!safe(from) || !safe(to)) { hy["unsafe-path"]++; next }
      if (!tracked(from) || !tracked(to)) { hy["untracked"]++; next }
      key = from "\t" to "\t" ch
      if (!(key in seen)) { seen[key] = 1; nk++; K[nk] = key }
      next
    }
    END {
      for (i = 2; i <= nk; i++) { keyv = K[i]; j = i - 1; while (j >= 1 && K[j] > keyv) { K[j+1] = K[j]; j-- } K[j+1] = keyv }
      for (i = 1; i <= nk; i++) { n = split(K[i], a, "\t"); print "EDGE\t" san(a[1]) "\t" san(a[2]) "\t" san(a[3]) }
      split("malformed-line unsafe-path untracked", order, " ")
      for (i = 1; i <= 3; i++) if (hy[order[i]] > 0) print "HYGIENE\t" order[i] "\t" hy[order[i]]
    }
  '
  return 0
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

main() {
  local sub="${1:-}"
  case "$sub" in
    ingest)    shift; cmd_ingest "$@" ;;
    coverage)  shift; cmd_coverage "$@" ;;
    *)         usage; return 2 ;;
  esac
}

main "$@"
exit $?
