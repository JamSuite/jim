#!/usr/bin/env bash
#
# skills/partition/scripts/jimpartition.sh — deterministic extraction/coverage
#   substrate for /jim:partition.
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
#   before use; this script NEVER resolves or executes an operator extractor
#   command — the operator's config activates those commands (through
#   jimconf.sh) and the model runs them via the Bash tool (the registry
#   trust boundary). The extractor-registry family name appears
#   nowhere in this script by design.
#
# EXIT CODES
#   0  Success (HYGIENE / UNCOVERED counts may be > 0 — a report, not an error).
#   1  The verb ran and reported a failure condition — a dirty worktree, or a
#      rewrite that could not be installed. Remaining targets were still
#      processed, so the run is partial rather than abandoned.
#   2  Malformed invocation, malformed caller-written input, or not a git tree.
#

set -uo pipefail
export LC_ALL=C

# jimfile.sh provides the single valid-relpath boundary. Resolved
# BASH_SOURCE-relative so it travels with the plugin tree
# (skills/partition/scripts/ → skills/file/scripts/).
JIMFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../file/scripts" 2>/dev/null && pwd)/jimfile.sh"

# Sibling scripts the health verb composes, BASH_SOURCE-relative so
# they travel with the plugin tree: the reconcile-series trend source (ledger)
# and the threshold-knob resolver (conf). Reading numeric knobs via jimconf is
# not the never-execute-config boundary — nothing config-derived is executed,
# only integer-compared.
JIMLEDGER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ledger/scripts" 2>/dev/null && pwd)/jimledger.sh"
JIMCONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../conf/scripts" 2>/dev/null && pwd)/jimconf.sh"

# ─── Section: Shared helpers ─────────────────────────────────────────────────

usage() {
  cat >&2 <<'USAGE'
usage: jimpartition.sh <subcommand> [args]
  scan                                          native import scan → EDGE/CHANNEL/UNMODELED
  ingest    <raw-file> <channel>                validate raw edges → EDGE/HYGIENE
  aggregate <edges-file> <territories-file>     group edges → GEDGE/STRADDLE/UNASSIGNED
  coverage  <territories-file>                  uncovered dirs → UNCOVERED/TOTAL
  rename-preflight <map> <specs-dir> <old> <new>   CHECK/DIRT/TERRITORY-IDENTITY
  split-preflight <map> <specs-dir> <old> <new>...  ARM/CHECK/DIRT/TERRITORY-IDENTITY
  merge-preflight <map> <specs-dir> <target> <src>...  ARM/EFFECTIVE/CHECK/COLLAPSE/DIRT
  renumber-map <old> <targets-csv> <assign-file> <child>=<start>...   split spec renumber remap → MAP
  merge-map <specs-dir> <target> <start> <src>...  merge spec renumber-append remap → MAP
  occurrences <slug> <path>...                  whole-token hits → HIT file line kind
  rewrite-identity [--skip-typed-refs] <old> <new> <file>...  in-place identity rewrite → REWROTE file line kind
  rewrite-refs <remap-file> <file>...           remap-keyed ref rewrite → REWROTE file line kind
  edges-diff <before-tsv> <after-tsv> <old> <new>  edge set modulo rename → MISSING/EXTRA
  merge-edges-diff <before-tsv> <after-tsv> <target> <src>...  edge set modulo merge → MISSING/EXTRA
  health-eval <specs-dir>                        threshold eval over reconcile series → THRESHOLDS/INVALID/CROSSED
  identity-check <map> [<specs-dir>]             territory name-mismatch sensor → MISMATCH foreign|retired
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

# emit_territories <territories-file> — validate every line and echo one
#   `<group>\t<path>` per declared territory. The file is caller-written (the
#   skill writes it from the approved partition), so a malformed line, a
#   non-slug group, or an unsafe path is a caller error → rc 2 (distinct from
#   ingest's HYGIENE counting of untrusted extractor output). Shared by the
#   coverage and aggregate verbs.
#   territories-file line: GROUP \t <group-slug> \t <repo-relative-path>
emit_territories() {
  local terr_file="$1" line f1 f2 f3 rest
  if [[ ! -f "$terr_file" ]]; then
    echo "jimpartition: territories file not found: $terr_file" >&2; return 2
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    IFS=$'\t' read -r f1 f2 f3 rest <<<"$line"
    if [[ "$f1" != "GROUP" || -n "${rest:-}" || -z "${f3:-}" ]]; then
      echo "jimpartition: malformed territories line: $line" >&2; return 2
    fi
    if ! valid_slug "$f2"; then
      echo "jimpartition: invalid group slug: $f2" >&2; return 2
    fi
    if ! valid_relpath "$f3"; then
      echo "jimpartition: invalid territory path: $f3" >&2; return 2
    fi
    printf '%s\t%s\n' "$f2" "$f3"
  done < "$terr_file"
}

# ─── Section: coverage ───────────────────────────────────────────────────────

# cmd_coverage <territories-file> — tracked files owned by no proposed group's
#   territory, aggregated by containing directory, plus
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

  local terr_lines tl
  terr_lines="$(emit_territories "$terr_file")" || return 2
  local -a terr=()
  while IFS= read -r tl; do
    [[ -z "$tl" ]] && continue
    terr+=("${tl#*$'\t'}")           # path is the field after the group slug
  done <<<"$terr_lines"

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
#   dropped (the ingest choke point).
#
#   Raw line: <from-relpath> \t <to-relpath> [\t <channel>]   (the operator
#   extractor output contract; a per-edge 3rd field overrides the CLI <channel>).
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

# ─── Section: scan ───────────────────────────────────────────────────────────

# classify_ext <ext> — for a known SOURCE extension print "<modeled|source> \t
#   <lang>"; print nothing for a non-source extension (manifests, docs, config,
#   assets are ignored, never counted as unmodeled source). The map is the
#   single source of truth for "what counts as source" — UNMODELED never inflates
#   with non-code files.
classify_ext() {
  case "$1" in
    go)                    printf 'modeled\tgo' ;;
    py)                    printf 'modeled\tpython' ;;
    js|jsx|ts|tsx|mjs|cjs) printf 'modeled\tjs-ts' ;;
    rs)                    printf 'modeled\trust' ;;
    ex|exs)                printf 'modeled\telixir' ;;
    java)                  printf 'source\tjava' ;;
    rb)                    printf 'source\truby' ;;
    c|h)                   printf 'source\tc' ;;
    cc|cpp|cxx|hh|hpp|hxx) printf 'source\tcpp' ;;
    cs)                    printf 'source\tcsharp' ;;
    php)                   printf 'source\tphp' ;;
    kt|kts)                printf 'source\tkotlin' ;;
    swift)                 printf 'source\tswift' ;;
    scala|sc)              printf 'source\tscala' ;;
    clj|cljs|cljc)         printf 'source\tclojure' ;;
    hs)                    printf 'source\thaskell' ;;
    pl|pm)                 printf 'source\tperl' ;;
    lua)                   printf 'source\tlua' ;;
    dart)                  printf 'source\tdart' ;;
    r)                     printf 'source\tr' ;;
    *)                     : ;;
  esac
}

# cmd_scan — native import scan over `git ls-files` in the CWD repo. Channels:
#   imports only, per modeled language. Emits validated EDGE lines (both
#   endpoints tracked by construction — the resolvers only target tracked files
#   / package dirs), CHANNEL facts per language scanned, and UNMODELED facts for
#   tracked source the baseline does not model (an honest, degraded graph — the
#   coverage-label input, never a promise of channel completeness).
cmd_scan() {
  local gitfiles rc_git
  gitfiles="$(git ls-files 2>/dev/null)"; rc_git=$?
  if [[ $rc_git -ne 0 ]]; then
    echo "jimpartition scan: not a git work tree" >&2; return 2
  fi

  # Tracked-file set + ancestor-directory set. HASDIR lets a resolver target a
  # package directory (Go) or a crate src dir (Rust cross-crate) that contains
  # tracked files. Both are local; the scan_* helpers read them via bash's
  # dynamic scope (they are only ever called from here).
  local -A TRACKED=() HASDIR=()
  local -a GO_FILES=() PY_FILES=() JS_FILES=() RS_FILES=() EX_FILES=()
  local -A UNMOD=()
  local f d base ext cl kind lang
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    TRACKED["$f"]=1
    d="$f"
    while [[ "$d" == */* ]]; do d="${d%/*}"; HASDIR["$d"]=1; done
    base="${f##*/}"
    if [[ "$base" == *.* ]]; then ext="${base##*.}"; else ext=""; fi
    cl="$(classify_ext "$ext")"
    [[ -z "$cl" ]] && continue
    kind="${cl%%$'\t'*}"; lang="${cl#*$'\t'}"
    if [[ "$kind" == "modeled" ]]; then
      case "$lang" in
        go)     GO_FILES+=("$f") ;;
        python) PY_FILES+=("$f") ;;
        js-ts)  JS_FILES+=("$f") ;;
        rust)   RS_FILES+=("$f") ;;
        elixir) EX_FILES+=("$f") ;;
      esac
    else
      UNMOD["$lang"]=$(( ${UNMOD["$lang"]:-0} + 1 ))
    fi
  done <<<"$gitfiles"

  local edges="" channels="" out rc
  # A modeled language whose manifest fails the charset gate degrades
  # to UNMODELED for that language — the scanner returns non-zero and emits no
  # edges, so a poisoned manifest never injects a match.
  if [[ ${#GO_FILES[@]} -gt 0 ]]; then
    out="$(scan_go "${GO_FILES[@]}")"; rc=$?
    if [[ $rc -eq 0 ]]; then
      edges+="$out"$'\n'
      channels+="$(printf 'CHANNEL\timports\tgo\t%d' "${#GO_FILES[@]}")"$'\n'
    else
      UNMOD["go"]=$(( ${UNMOD["go"]:-0} + ${#GO_FILES[@]} ))
    fi
  fi
  if [[ ${#PY_FILES[@]} -gt 0 ]]; then
    out="$(scan_python "${PY_FILES[@]}")"
    edges+="$out"$'\n'
    channels+="$(printf 'CHANNEL\timports\tpython\t%d' "${#PY_FILES[@]}")"$'\n'
  fi
  if [[ ${#JS_FILES[@]} -gt 0 ]]; then
    out="$(scan_jsts "${JS_FILES[@]}")"
    edges+="$out"$'\n'
    channels+="$(printf 'CHANNEL\timports\tjs-ts\t%d' "${#JS_FILES[@]}")"$'\n'
  fi
  if [[ ${#RS_FILES[@]} -gt 0 ]]; then
    out="$(scan_rust "${RS_FILES[@]}")"
    local rmeta rmod rdeg
    rmeta="$(printf '%s\n' "$out" | grep '^RUSTMETA' | head -1)"
    rmod="$(printf '%s' "$rmeta" | cut -f2)"; rdeg="$(printf '%s' "$rmeta" | cut -f3)"
    edges+="$(printf '%s\n' "$out" | grep '^EDGE' || true)"$'\n'
    [[ "${rmod:-0}" -gt 0 ]] && channels+="$(printf 'CHANNEL\timports\trust\t%d' "$rmod")"$'\n'
    [[ "${rdeg:-0}" -gt 0 ]] && UNMOD["rust"]=$(( ${UNMOD["rust"]:-0} + rdeg ))
  fi
  if [[ ${#EX_FILES[@]} -gt 0 ]]; then
    out="$(scan_elixir "${EX_FILES[@]}")"
    edges+="$out"$'\n'
    channels+="$(printf 'CHANNEL\timports\telixir\t%d' "${#EX_FILES[@]}")"$'\n'
  fi

  # Emit EDGEs (deduped + sorted), then CHANNEL facts (sorted), then UNMODELED
  # facts (sorted) — a deterministic, stable substrate. EDGE endpoint paths pass
  # the same san() control-strip/length-cap the other verbs apply, so the
  # "field-sanitized" contract holds at this emit without relying on git's
  # C-escaping guarantee (the belt scan endpoints are tracked-by-construction).
  if [[ -n "${edges//[$'\n']/}" ]]; then
    printf '%s\n' "$edges" | grep -v '^$' \
      | awk -F'\t' 'function san(x){gsub(/[[:cntrl:]]/,"",x); if(length(x)>512)x=substr(x,1,512); return x} {print $1"\t"san($2)"\t"san($3)"\t"$4}' \
      | sort -u
  fi
  if [[ -n "${channels//[$'\n']/}" ]]; then
    printf '%s\n' "$channels" | grep -v '^$' | sort
  fi
  local ul
  while IFS= read -r ul; do
    [[ -z "$ul" ]] && continue
    printf 'UNMODELED\t%s\t%d\n' "$ul" "${UNMOD[$ul]}"
  done < <(printf '%s\n' "${!UNMOD[@]}" | sort)
  return 0
}

# go_imports <file> — emit one imported package path per line (single and block
#   `import ( ... )` forms; the quoted path from each import line).
go_imports() {
  awk '
    /^[[:space:]]*import[[:space:]]*\(/ { inb = 1; next }
    inb && /^[[:space:]]*\)/            { inb = 0; next }
    inb {
      if (match($0, /"[^"]*"/)) print substr($0, RSTART + 1, RLENGTH - 2)
      next
    }
    /^[[:space:]]*import[[:space:]]/ {
      if (match($0, /"[^"]*"/)) print substr($0, RSTART + 1, RLENGTH - 2)
    }
  ' "$1"
}

# scan_go <go-file...> — resolve internal imports to package dirs. Reads ./go.mod
#   for the module prefix, charset-gated before use: a Go module path
#   is alnum + . _ - / ~ only; anything else (or a missing go.mod) degrades the
#   whole language (return 1). The gated module is stripped as a LITERAL prefix
#   (quoted parameter expansion), never interpolated into a pattern.
scan_go() {
  local module=""
  if [[ -f go.mod ]]; then
    module="$(grep -E '^[[:space:]]*module[[:space:]]+' go.mod 2>/dev/null | head -n1 \
      | sed -E 's/^[[:space:]]*module[[:space:]]+//; s/[[:space:]]+$//')"
  fi
  if [[ -z "$module" || ! "$module" =~ ^[A-Za-z0-9][A-Za-z0-9._/~-]*$ ]]; then
    return 1
  fi
  local f imp rel
  for f in "$@"; do
    while IFS= read -r imp; do
      [[ -z "$imp" ]] && continue
      rel="${imp#"$module"/}"
      [[ "$rel" == "$imp" ]] && continue          # external import
      [[ -n "${HASDIR[$rel]:-}" ]] && printf 'EDGE\t%s\t%s\timports\n' "$f" "$rel"
    done < <(go_imports "$f")
  done
  return 0
}

# py_imports <file> — emit one candidate dotted module per line for a .py file:
#   every `import a.b.c` (comma lists, `as` aliases) and, for `from a.b import
#   x, y`, the package `a.b` plus each `a.b.x`. Relative imports (leading dot)
#   are unmodeled and skipped.
py_imports() {
  awk '
    /^[[:space:]]*import[[:space:]]+/ {
      s = $0
      sub(/^[[:space:]]*import[[:space:]]+/, "", s)
      sub(/#.*/, "", s)
      n = split(s, parts, ",")
      for (i = 1; i <= n; i++) {
        m = parts[i]
        sub(/[[:space:]]+as[[:space:]]+.*/, "", m)
        gsub(/[[:space:]]/, "", m)
        if (m ~ /^[A-Za-z_][A-Za-z0-9_.]*$/) print m
      }
      next
    }
    /^[[:space:]]*from[[:space:]]+/ {
      s = $0
      sub(/^[[:space:]]*from[[:space:]]+/, "", s)
      mod = s
      sub(/[[:space:]]+import[[:space:]].*/, "", mod)
      gsub(/[[:space:]]/, "", mod)
      if (mod ~ /^\./ || mod !~ /^[A-Za-z_][A-Za-z0-9_.]*$/) next
      print mod
      names = s
      sub(/^.*[[:space:]]import[[:space:]]+/, "", names)
      gsub(/[()]/, "", names); sub(/#.*/, "", names)
      nn = split(names, nm, ",")
      for (i = 1; i <= nn; i++) {
        x = nm[i]
        sub(/[[:space:]]+as[[:space:]]+.*/, "", x)
        gsub(/[[:space:]]/, "", x)
        if (x ~ /^[A-Za-z_][A-Za-z0-9_]*$/) print mod "." x
      }
      next
    }
  ' "$1"
}

# scan_python <py-file...> — resolve each candidate dotted module to a tracked
#   a/b.py or a/b/__init__.py. Always models (Python has no manifest to gate).
scan_python() {
  local f cand slashed
  for f in "$@"; do
    while IFS= read -r cand; do
      [[ -z "$cand" ]] && continue
      slashed="${cand//./\/}"
      if [[ -n "${TRACKED[$slashed.py]:-}" ]]; then
        printf 'EDGE\t%s\t%s\timports\n' "$f" "$slashed.py"
      elif [[ -n "${TRACKED[$slashed/__init__.py]:-}" ]]; then
        printf 'EDGE\t%s\t%s\timports\n' "$f" "$slashed/__init__.py"
      fi
    done < <(py_imports "$f")
  done
  return 0
}

# norm_path <relpath> — collapse '.' and '..' segments (pure string math, no
#   filesystem). A path that escapes the root (leading '..') simply won't match
#   a tracked file, so no edge is emitted.
norm_path() {
  local p="$1"
  local -a out=()
  local seg IFS='/'
  local -a segs
  read -ra segs <<<"$p"
  for seg in "${segs[@]}"; do
    case "$seg" in
      ''|.) continue ;;
      ..)
        if [[ ${#out[@]} -gt 0 && "${out[-1]}" != ".." ]]; then unset 'out[-1]'
        else out+=(".."); fi
        ;;
      *) out+=("$seg") ;;
    esac
  done
  printf '%s' "${out[*]}"
}

# jsts_specs <file> — emit one relative module specifier per line from a JS/TS
#   file (import / require / export-from, single- or double-quoted). Bare
#   package specifiers (react, lodash) are external and skipped.
jsts_specs() {
  awk -v Q="'" '
    {
      line = $0
      if (line !~ /(^|[^A-Za-z0-9_$])(import|require|export)([^A-Za-z0-9_$]|$)/ && line !~ /[[:space:]]from([[:space:]]|$)/)
        next
      gsub(Q, "\"", line)
      if (match(line, /"[^"]*"/)) {
        s = substr(line, RSTART + 1, RLENGTH - 2)
        if (substr(s, 1, 2) == "./" || substr(s, 1, 3) == "../") print s
      }
    }
  ' "$1"
}

# scan_jsts <js-file...> — resolve each relative specifier against the importing
#   file's directory, trying the exact path, then each extension, then an index
#   file (the Node/bundler resolution order the baseline models).
scan_jsts() {
  local -a exts=(js jsx ts tsx mjs cjs)
  local f dir spec base target ext
  for f in "$@"; do
    dir="${f%/*}"; [[ "$dir" == "$f" ]] && dir=""
    while IFS= read -r spec; do
      [[ -z "$spec" ]] && continue
      base="$(norm_path "${dir:+$dir/}$spec")"
      [[ -z "$base" ]] && continue
      target=""
      [[ -n "${TRACKED[$base]:-}" ]] && target="$base"
      if [[ -z "$target" ]]; then
        for ext in "${exts[@]}"; do
          if [[ -n "${TRACKED[$base.$ext]:-}" ]]; then target="$base.$ext"; break; fi
        done
      fi
      if [[ -z "$target" ]]; then
        for ext in "${exts[@]}"; do
          if [[ -n "${TRACKED[$base/index.$ext]:-}" ]]; then target="$base/index.$ext"; break; fi
        done
      fi
      [[ -n "$target" ]] && printf 'EDGE\t%s\t%s\timports\n' "$f" "$target"
    done < <(jsts_specs "$f")
  done
  return 0
}

# cargo_name <Cargo.toml> — the crate's `[package] name`, or nothing (a bare
#   `[workspace]` manifest has none).
cargo_name() {
  awk '
    /^[[:space:]]*\[package\]/ { inpkg = 1; next }
    /^[[:space:]]*\[/          { inpkg = 0 }
    inpkg && /^[[:space:]]*name[[:space:]]*=/ {
      if (match($0, /"[^"]*"/)) { print substr($0, RSTART + 1, RLENGTH - 2); exit }
    }
  ' "$1"
}

# rust_uses <file> — emit `MOD <name>` for each `mod name;` and `USE <path>` for
#   each `use <path>` (the module prefix before any `{` brace group).
rust_uses() {
  awk '
    /^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*;/ {
      m = $0
      sub(/^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]+/, "", m)
      sub(/[[:space:]]*;.*/, "", m); gsub(/[[:space:]]/, "", m)
      print "MOD\t" m; next
    }
    /^[[:space:]]*(pub[[:space:]]+)?use[[:space:]]+/ {
      u = $0
      sub(/^[[:space:]]*(pub[[:space:]]+)?use[[:space:]]+/, "", u)
      sub(/\{.*/, "", u)
      sub(/[[:space:]]+as[[:space:]].*/, "", u)
      sub(/;.*/, "", u); gsub(/[[:space:]]/, "", u)
      sub(/(::)?$/, "", u)
      print "USE\t" u; next
    }
  ' "$1"
}

# rust_resolve_mod <file> <name> — resolve a `mod <name>;` declaration to a
#   sibling file. A crate root (lib.rs/main.rs) or mod.rs declares submodules in
#   its own directory; any other file declares them under a dir named for its
#   stem (Rust 2018).
rust_resolve_mod() {
  local f="$1" name="$2"
  local fdir="${f%/*}"; [[ "$fdir" == "$f" ]] && fdir=""
  local fbase="${f##*/}"; fbase="${fbase%.rs}"
  local pfx
  if [[ "$fbase" == lib || "$fbase" == main || "$fbase" == mod ]]; then
    pfx="${fdir:+$fdir/}"
  else
    pfx="${fdir:+$fdir/}$fbase/"
  fi
  if [[ -n "${TRACKED[$pfx$name.rs]:-}" ]]; then
    printf 'EDGE\t%s\t%s\timports\n' "$f" "$pfx$name.rs"
  elif [[ -n "${TRACKED[$pfx$name/mod.rs]:-}" ]]; then
    printf 'EDGE\t%s\t%s\timports\n' "$f" "$pfx$name/mod.rs"
  fi
}

# rust_resolve_local <file> <crate-src> <rest-path> — resolve a `crate::<rest>`
#   module path under the crate src root, deepest module first (an item leaf
#   collapses to its containing module file).
rust_resolve_local() {
  local f="$1" cs="$2" rest="$3"
  [[ -z "$rest" ]] && return
  local -a segs=(); local tmp="$rest"
  while [[ -n "$tmp" ]]; do
    segs+=("${tmp%%::*}")
    if [[ "$tmp" == *"::"* ]]; then tmp="${tmp#*::}"; else tmp=""; fi
  done
  local n=${#segs[@]} k i path
  for (( k = n; k >= 1; k-- )); do
    path="$cs"
    for (( i = 0; i < k; i++ )); do path="$path/${segs[$i]}"; done
    if [[ -n "${TRACKED[$path.rs]:-}" ]]; then printf 'EDGE\t%s\t%s\timports\n' "$f" "$path.rs"; return; fi
    if [[ -n "${TRACKED[$path/mod.rs]:-}" ]]; then printf 'EDGE\t%s\t%s\timports\n' "$f" "$path/mod.rs"; return; fi
  done
}

# rust_resolve_use <file> <crate-src> <own-name> <path> — dispatch a use path:
#   crate:: is crate-local; self/super are unmodeled; any other leading segment
#   is a cross-crate reference resolved against the member map (to the member's
#   src dir). MEMBER is scan_rust's local, read here via dynamic scope.
rust_resolve_use() {
  local f="$1" cs="$2" own="$3" path="$4"
  [[ -z "$path" ]] && return
  local first rest
  first="${path%%::*}"
  rest="${path#*::}"; [[ "$rest" == "$path" ]] && rest=""
  case "$first" in
    crate)      [[ -n "$cs" ]] && rust_resolve_local "$f" "$cs" "$rest" ;;
    self|super|"") return ;;
    *)
      local src="${MEMBER[$first]:-}"
      if [[ -n "$src" && "$src" != "$cs" && -n "${HASDIR[$src]:-}" ]]; then
        printf 'EDGE\t%s\t%s\timports\n' "$f" "$src"
      fi
      ;;
  esac
}

# scan_rust <rs-file...> — emit EDGE lines plus a trailing `RUSTMETA <modeled>
#   <degraded>` line. Crate identity comes from tracked Cargo.toml [package]
#   names, charset-gated; a file under a bad-named crate degrades to
#   UNMODELED rather than resolving. The normalized (hyphen→underscore) name is
#   how source `use crate_a::` matches the member `crate-a`.
scan_rust() {
  local -A CRATE_SRC_NAME=() CRATE_SRC_DEGRADED=() MEMBER=()
  local toml cdir name norm src
  while IFS= read -r toml; do
    [[ -z "$toml" ]] && continue
    [[ "${toml##*/}" == "Cargo.toml" ]] || continue
    cdir="${toml%/*}"; [[ "$cdir" == "$toml" ]] && cdir="."
    name="$(cargo_name "$toml")"
    [[ -z "$name" ]] && continue
    if [[ "$cdir" == "." ]]; then src="src"; else src="$cdir/src"; fi
    if [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
      norm="${name//-/_}"
      CRATE_SRC_NAME["$src"]="$norm"
      MEMBER["$norm"]="$src"
    else
      CRATE_SRC_DEGRADED["$src"]=1
    fi
  done < <(printf '%s\n' "${!TRACKED[@]}")

  local modeled=0 degraded=0
  local f cs own deg bestlen srcdir line tag val
  for f in "$@"; do
    cs=""; own=""; deg=0; bestlen=-1
    for srcdir in "${!CRATE_SRC_NAME[@]}"; do
      if [[ "$f" == "$srcdir/"* && ${#srcdir} -gt $bestlen ]]; then
        cs="$srcdir"; own="${CRATE_SRC_NAME[$srcdir]}"; deg=0; bestlen=${#srcdir}
      fi
    done
    for srcdir in "${!CRATE_SRC_DEGRADED[@]}"; do
      if [[ "$f" == "$srcdir/"* && ${#srcdir} -gt $bestlen ]]; then
        cs="$srcdir"; own=""; deg=1; bestlen=${#srcdir}
      fi
    done
    if [[ $deg -eq 1 ]]; then degraded=$((degraded + 1)); continue; fi
    modeled=$((modeled + 1))
    while IFS= read -r line; do
      tag="${line%%$'\t'*}"; val="${line#*$'\t'}"
      case "$tag" in
        MOD) rust_resolve_mod "$f" "$val" ;;
        USE) rust_resolve_use "$f" "$cs" "$own" "$val" ;;
      esac
    done < <(rust_uses "$f")
  done
  printf 'RUSTMETA\t%d\t%d\n' "$modeled" "$degraded"
}

# elixir_defmodules <file> — emit each `defmodule <Name>` module name.
elixir_defmodules() {
  awk '
    /^[[:space:]]*defmodule[[:space:]]+[A-Z]/ {
      s = $0
      sub(/^[[:space:]]*defmodule[[:space:]]+/, "", s)
      sub(/[[:space:]].*/, "", s); sub(/,.*/, "", s)
      print s
    }
  ' "$1"
}

# elixir_refs <file> — emit each aliased/imported/used/required module name,
#   expanding the `Prefix.{A, B}` brace form into Prefix.A, Prefix.B.
elixir_refs() {
  awk '
    /^[[:space:]]*(alias|import|use|require)[[:space:]]+[A-Z]/ {
      s = $0
      sub(/^[[:space:]]*(alias|import|use|require)[[:space:]]+/, "", s)
      sub(/#.*/, "", s)
      if (match(s, /\.\{[^}]*\}/)) {
        prefix = substr(s, 1, RSTART - 1)
        inner  = substr(s, RSTART + 2, RLENGTH - 3)
        ni = split(inner, items, ",")
        for (i = 1; i <= ni; i++) {
          it = items[i]; gsub(/[[:space:]]/, "", it)
          if (it != "") print prefix "." it
        }
        next
      }
      sub(/[,[:space:]].*/, "", s); gsub(/[[:space:]]/, "", s)
      if (s != "") print s
    }
  ' "$1"
}

# scan_elixir <ex-file...> — build a defmodule->file map over all tracked
#   Elixir source (module names charset-gated), then resolve each
#   file's references to that map. Bare qualified calls are unmodeled; a
#   self-reference emits no edge. Always models (no whole-language manifest).
scan_elixir() {
  local -A MODMAP=()
  local f mod ref tgt
  for f in "$@"; do
    while IFS= read -r mod; do
      [[ -z "$mod" ]] && continue
      [[ "$mod" =~ ^[A-Z][A-Za-z0-9_]*(\.[A-Z][A-Za-z0-9_]*)*$ ]] || continue
      [[ -z "${MODMAP[$mod]:-}" ]] && MODMAP["$mod"]="$f"
    done < <(elixir_defmodules "$f")
  done
  for f in "$@"; do
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      [[ "$ref" =~ ^[A-Z][A-Za-z0-9_]*(\.[A-Z][A-Za-z0-9_]*)*$ ]] || continue
      tgt="${MODMAP[$ref]:-}"
      [[ -n "$tgt" && "$tgt" != "$f" ]] && printf 'EDGE\t%s\t%s\timports\n' "$f" "$tgt"
    done < <(elixir_refs "$f")
  done
  return 0
}

# ─── Section: aggregate ──────────────────────────────────────────────────────

# cmd_aggregate <edges-file> <territories-file> — project file-level EDGEs onto
#   proposed territories. Emits group-level edges (GEDGE, intra-group dropped),
#   STRADDLE facts (a territory-assigned unit consumed by >=2 distinct foreign
#   groups — a single foreign consumer is a normal GEDGE), and
#   UNASSIGNED dirs (endpoints under no territory, dirname-aggregated). Group
#   assignment is a slash-anchored longest-prefix match. The
#   edges-file's non-EDGE lines (CHANNEL / UNMODELED substrate metadata) are
#   ignored; a missing file or a malformed territories line is rc 2.
cmd_aggregate() {
  local edges_file="${1:-}" terr_file="${2:-}"
  if [[ -z "$edges_file" || -z "$terr_file" ]]; then
    echo "jimpartition aggregate: need <edges-file> <territories-file>" >&2; return 2
  fi
  if [[ ! -f "$edges_file" ]]; then
    echo "jimpartition aggregate: edges file not found: $edges_file" >&2; return 2
  fi
  local terr_lines
  terr_lines="$(emit_territories "$terr_file")" || return 2

  {
    printf '%s\n' "$terr_lines" | awk -F'\t' 'NF >= 2 { print "G\t" $1 "\t" $2 }'
    awk -F'\t' '$1 == "EDGE" && NF >= 3 { print "E\t" $2 "\t" $3 }' "$edges_file"
  } | awk -F'\t' '
    function san(x) { gsub(/[[:cntrl:]]/, "", x); if (length(x) > 512) x = substr(x, 1, 512); return x }
    function dirof(e,  d) { d = e; if (index(d, "/") > 0) { sub(/\/[^/]*$/, "", d); return d "/" } return "./" }
    function assign(e,  i, best, bestlen, tp) {
      best = ""; bestlen = -1
      for (i = 1; i <= nt; i++) {
        tp = TP[i]
        if (index(e "/", tp "/") == 1 && length(tp) > bestlen) { bestlen = length(tp); best = TG[i] }
      }
      return best
    }
    $1 == "G" { nt++; TG[nt] = $2; tp = $3; sub(/\/+$/, "", tp); TP[nt] = tp; next }
    $1 == "E" {
      from = $2; to = $3
      fg = assign(from); tg = assign(to)
      if (fg == "" && !(from in seenun)) { seenun[from] = 1; UND[dirof(from)]++ }
      if (tg == "" && !(to in seenun))   { seenun[to]   = 1; UND[dirof(to)]++ }
      if (fg != "" && tg != "" && fg != tg) {
        GE[fg SUBSEP tg]++
        TOOWNER[to] = tg
        if (!((to SUBSEP fg) in seenfc)) { seenfc[to SUBSEP fg] = 1; FCC[to]++ }
      }
      next
    }
    END {
      for (k in GE)  { split(k, a, SUBSEP); print "GEDGE\t" a[1] "\t" a[2] "\t" GE[k] }
      for (u in FCC) if (FCC[u] >= 2) print "STRADDLE\t" san(u) "\t" TOOWNER[u] "\t" FCC[u]
      for (d in UND) print "UNASSIGNED\t" san(d) "\t" UND[d]
    }
  ' | sort
  return 0
}

# ─── Section: rename ─────────────────────────────────────────────────────────
#
# Three read-only verbs for /jim:partition rename. Like the rest of this script
# they write nothing and run no operator command — the deterministic floor the
# skill's classification/gate/materialize flow builds on. The git primitives
# (rename-tracked, commit-rename) and every doc edit live elsewhere; these verbs
# only observe (preflight facts, occurrence enumeration, edge-set comparison).

# san_field <str> — control-strip + length-cap one field for emission. The
#   rename verbs' bash-emitted lines carry map- and git-derived (untrusted)
#   paths; this matches the awk san() the other verbs apply.
san_field() {
  printf '%s' "$1" | tr -d '\000-\037\177' | cut -c1-512
}

# slug_token_match <slug> <string> — 0 iff <slug> occurs in <string> as a whole
#   slug token: bounded on both sides by a byte outside [a-z0-9-] (or a string
#   edge). `cart` matches in `modules/cart`, `cart.x`, `verify_appetite_cart`;
#   it never matches inside `cart-session-api` or `cartel`. The single boundary
#   rule shared by rename-preflight (territory identity) and occurrences.
slug_token_match() {
  awk -v slug="$1" -v s="$2" '
    BEGIN {
      n = length(slug); i = 1
      while ((p = index(substr(s, i), slug)) > 0) {
        pos = i + p - 1
        before = (pos > 1) ? substr(s, pos - 1, 1) : ""
        after  = substr(s, pos + n, 1)
        if (before !~ /[a-z0-9-]/ && after !~ /[a-z0-9-]/) exit 0
        i = pos + 1
      }
      exit 1
    }'
}

# map_group_slugs <map> — emit each group slug declared as an `### <slug>` H3 in
#   the map's `## Groups` section (ends at the next H2). Slug-gated so a crafted
#   heading can never smuggle a non-slug token.
map_group_slugs() {
  awk '
    /^##[ \t]+Groups[ \t]*$/ { insec = 1; next }
    insec && /^##[ \t]/ { insec = 0 }
    insec && /^###[ \t]+/ {
      s = $0; sub(/^###[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
      if (s ~ /^[a-z0-9][a-z0-9-]*$/) print s
    }' "$1"
}

# old_group_territories <map> <group> — emit each backticked path on the
#   `Territory` line(s) inside the given group's `### <group>` subsection.
old_group_territories() {
  awk -v grp="$2" '
    /^##[ \t]+Groups[ \t]*$/ { insec = 1; next }
    insec && /^##[ \t]/ { insec = 0 }
    insec && /^###[ \t]+/ {
      s = $0; sub(/^###[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
      cur = (s == grp) ? 1 : 0; next
    }
    insec && cur && /[Tt]erritory/ {
      line = $0
      while (match(line, /`[^`]+`/)) {
        print substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
      }
    }' "$1"
}

# emit_check <name> <pass|fail> <detail>
emit_check() {
  printf 'CHECK\t%s\t%s\t%s\n' "$1" "$2" "$(san_field "$3")"
}

# pending_provisionals <specs-dir> <group> — print the basename of every spec
#   directory in <group> wearing the reserved provisional prefix, space-joined.
#
#   Prefix match, deliberately: this is a refusal, and the fail-safe reading of
#   a directory that merely LOOKS provisional is still "do not move it". Asking
#   the full grammar here would both admit a malformed pending dir into a move
#   and put a fourth copy of that grammar in a fourth script.
pending_provisionals() {
  local specs_dir="$1" group="$2" d bn out=""
  for d in "$specs_dir/$group"/P-*/; do
    [[ -d "$d" ]] || continue
    bn="$(basename "$d")"
    out+="${out:+ }$bn"
  done
  printf '%s' "$out"
}

# check_pending_provisionals <specs-dir> <group>... — emit the pending-provisional
#   CHECK fact for each group and, when any holds one, the operator-facing
#   refusal on stderr. rc 1 iff any group holds a pending identity.
#
#   A provisional identity is not issued yet: moving its directory leaves a
#   pending claim under a name the allocator will resolve away from, and the
#   realization that follows would have to find it somewhere its own record does
#   not describe. Refusing is fail-safe and, unlike the map-verb gates behind it,
#   it happens before the operator has been shown a plan.
check_pending_provisionals() {
  local specs_dir="$1"; shift
  local g pend shown rc=0
  for g in "$@"; do
    # Slug-gate before the filesystem probe — never glob an unvalidated
    # component. Rename and split gate their group at entry, so this changes
    # nothing for them; merge passes its whole effective set through here.
    if ! valid_slug "$g"; then
      emit_check pending-provisionals fail "$g: invalid group slug"
      rc=1
      continue
    fi
    pend="$(pending_provisionals "$specs_dir" "$g")"
    if [[ -n "$pend" ]]; then
      # The fact's whole point is naming EVERY pending identity, so a display
      # cut must say so — a capped list with no note reads as the whole list
      # (the sweep's truncation discipline). Capped below the emit_check field
      # limit so the note itself survives the fact's own sanitizer.
      shown="$(san_field "$pend" | cut -c1-256)"
      [[ "$shown" != "$pend" ]] && shown="$shown … (list truncated)"
      emit_check pending-provisionals fail "$g: $shown"
      echo "error: pending provisional spec(s) in $(san_field "$g"): $shown" \
           "— realize them first (/jim:spec reconcile), then re-run" >&2
      rc=1
    else
      emit_check pending-provisionals pass "$g"
    fi
  done
  return $rc
}

# cmd_rename_preflight <map> <specs-dir> <old> <new> — structural preflight for a
#   group rename. Emits CHECK facts (map-exists, old-mapped, new-slug-valid,
#   new-collision, blueprint-exists, tree-clean), TERRITORY-IDENTITY lines for
#   territories embedding <old>, and DIRT lines classifying each uncommitted path
#   as affected (inside the group's spec dir or an identity territory) vs
#   unrelated. rc 1 iff any STRUCTURAL check fails (tree-clean/dirt are not fatal
#   — the dirty tree is a warn-and-confirm, not a refusal); rc 2 on usage.
cmd_rename_preflight() {
  local map="${1:-}" specs_dir="${2:-}" old="${3:-}" new="${4:-}"
  if [[ -z "$map" || -z "$specs_dir" || -z "$old" || -z "$new" ]]; then
    echo "jimpartition rename-preflight: need <map> <specs-dir> <old> <new>" >&2; return 2
  fi
  if ! valid_slug "$old"; then
    echo "jimpartition rename-preflight: invalid old slug: $old" >&2; return 2
  fi
  if ! valid_relpath "$specs_dir"; then
    echo "jimpartition rename-preflight: invalid specs-dir: $specs_dir" >&2; return 2
  fi

  local fail=0 groups=""

  if [[ -f "$map" ]]; then
    emit_check map-exists pass "$map"
    groups="$(map_group_slugs "$map")"
  else
    emit_check map-exists fail "map not found: $map"; fail=1
  fi

  if printf '%s\n' "$groups" | grep -qxF -- "$old"; then
    emit_check old-mapped pass "$old"
  else
    emit_check old-mapped fail "not a mapped group: $old"; fail=1
  fi

  local new_ok=0
  if valid_slug "$new"; then
    emit_check new-slug-valid pass "$new"; new_ok=1
  else
    emit_check new-slug-valid fail "not a valid group slug: $new"; fail=1
  fi

  if [[ $new_ok -eq 1 ]]; then
    if printf '%s\n' "$groups" | grep -qxF -- "$new"; then
      emit_check new-collision fail "collides with mapped group: $new"; fail=1
    elif [[ -d "$specs_dir/$new" ]]; then
      emit_check new-collision fail "collides with spec-group dir: $specs_dir/$new"; fail=1
    else
      emit_check new-collision pass "$new"
    fi
  else
    emit_check new-collision fail "new slug invalid"; fail=1
  fi

  local bp_name; bp_name="$(bash "$JIMFILE" blueprint-dirname)"
  if [[ -d "$specs_dir/$old/$bp_name" ]]; then
    emit_check blueprint-exists pass "$specs_dir/$old/$bp_name"
  else
    emit_check blueprint-exists fail "absent: $specs_dir/$old/$bp_name"; fail=1
  fi

  # Territory identity — territories of <old> whose paths embed <old> as a slug
  # token gate the code-move fork. Collected here so DIRT can classify against them.
  local terr
  local -a idterr=()
  while IFS= read -r terr; do
    [[ -z "$terr" ]] && continue
    if slug_token_match "$old" "$terr"; then
      printf 'TERRITORY-IDENTITY\t%s\n' "$(san_field "$terr")"
      idterr+=("$terr")
    fi
  done < <([[ -f "$map" ]] && old_group_territories "$map" "$old")

  # Tree cleanliness + dirt classification (non-fatal).
  local status git_rc
  status="$(git status --porcelain 2>/dev/null)"; git_rc=$?
  if [[ $git_rc -ne 0 ]]; then
    emit_check tree-clean fail "not a git work tree"
  elif [[ -z "$status" ]]; then
    emit_check tree-clean pass "clean"
  else
    emit_check tree-clean fail "uncommitted changes present"
    local line path klass t affected_pref="$specs_dir/$old/"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      path="${line:3}"                 # strip the 2-char status + space
      path="${path##* -> }"            # on a rename line, keep the new path
      klass="unrelated"
      [[ "$path" == "$affected_pref"* ]] && klass="affected"
      for t in "${idterr[@]}"; do
        [[ "$path" == "$t" || "$path" == "$t/"* ]] && klass="affected"
      done
      printf 'DIRT\t%s\t%s\n' "$klass" "$(san_field "$path")"
    done <<<"$status"
  fi

  check_pending_provisionals "$specs_dir" "$old" || fail=1

  [[ $fail -eq 1 ]] && return 1
  return 0
}

# cmd_split_preflight <map> <specs-dir> <old> <new>... — structural preflight for a
#   group split, the rename-preflight cousin over 2+ targets. Emits the
#   split ARM (extraction iff <old> is among the targets — the remainder continues
#   under its own identity/dir/numbering; else symmetric — the source is retired),
#   per-target CHECK facts, TERRITORY-IDENTITY lines for territories embedding
#   <old>, and DIRT classification of a dirty tree. Structural checks (map-exists,
#   old-mapped, blueprint-exists, targets-arity [≥2, no dups], per-target
#   slug-valid + collision) are fatal (rc 1); tree-clean/dirt is warn-confirm
#   (non-fatal), rename parity. The collision check is SKIPPED for a target equal
#   to <old>: the extraction remainder legitimately keeps its pre-existing group
#   and dir. rc 0 clean · 1 structural fail · 2 usage / invalid old slug.
cmd_split_preflight() {
  local map="${1:-}" specs_dir="${2:-}" old="${3:-}"
  if [[ -z "$map" || -z "$specs_dir" || -z "$old" ]]; then
    echo "jimpartition split-preflight: need <map> <specs-dir> <old> <new>..." >&2; return 2
  fi
  shift 3
  if [[ $# -eq 0 ]]; then
    echo "jimpartition split-preflight: need <new>... (>=2 targets)" >&2; return 2
  fi
  if ! valid_slug "$old"; then
    echo "jimpartition split-preflight: invalid old slug: $old" >&2; return 2
  fi
  if ! valid_relpath "$specs_dir"; then
    echo "jimpartition split-preflight: invalid specs-dir: $specs_dir" >&2; return 2
  fi
  local -a targets=("$@")

  # ARM — extraction iff <old> is one of the targets, else symmetric.
  local arm="symmetric" t
  for t in "${targets[@]}"; do
    [[ "$t" == "$old" ]] && { arm="extraction"; break; }
  done
  printf 'ARM\t%s\n' "$arm"

  local fail=0 groups=""

  if [[ -f "$map" ]]; then
    emit_check map-exists pass "$map"
    groups="$(map_group_slugs "$map")"
  else
    emit_check map-exists fail "map not found: $map"; fail=1
  fi

  if printf '%s\n' "$groups" | grep -qxF -- "$old"; then
    emit_check old-mapped pass "$old"
  else
    emit_check old-mapped fail "not a mapped group: $old"; fail=1
  fi

  local bp_name; bp_name="$(bash "$JIMFILE" blueprint-dirname)"
  if [[ -d "$specs_dir/$old/$bp_name" ]]; then
    emit_check blueprint-exists pass "$specs_dir/$old/$bp_name"
  else
    emit_check blueprint-exists fail "absent: $specs_dir/$old/$bp_name"; fail=1
  fi

  # Targets arity: ≥2, no duplicates.
  if [[ ${#targets[@]} -lt 2 ]]; then
    emit_check targets-arity fail "need >=2 targets, got ${#targets[@]}"; fail=1
  else
    local dup="" i j
    for ((i = 0; i < ${#targets[@]}; i++)); do
      for ((j = i + 1; j < ${#targets[@]}; j++)); do
        [[ "${targets[i]}" == "${targets[j]}" ]] && dup="${targets[i]}"
      done
    done
    if [[ -n "$dup" ]]; then
      emit_check targets-arity fail "duplicate target: $dup"; fail=1
    else
      emit_check targets-arity pass "${#targets[@]} targets"
    fi
  fi

  # Per-target slug validity + collision (collision SKIPPED for t == old).
  for t in "${targets[@]}"; do
    if valid_slug "$t"; then
      emit_check "target-slug-valid:$t" pass "$t"
    else
      emit_check "target-slug-valid:$t" fail "not a valid group slug: $t"; fail=1
      continue
    fi
    [[ "$t" == "$old" ]] && continue          # extraction remainder — not a collision
    if printf '%s\n' "$groups" | grep -qxF -- "$t"; then
      emit_check "target-collision:$t" fail "collides with mapped group: $t"; fail=1
    elif [[ -d "$specs_dir/$t" ]]; then
      emit_check "target-collision:$t" fail "collides with spec-group dir: $specs_dir/$t"; fail=1
    else
      emit_check "target-collision:$t" pass "$t"
    fi
  done

  # Territory identity — territories of <old> embedding <old> as a slug token,
  # collected so DIRT can classify against them (rename-preflight parity).
  local terr
  local -a idterr=()
  while IFS= read -r terr; do
    [[ -z "$terr" ]] && continue
    if slug_token_match "$old" "$terr"; then
      printf 'TERRITORY-IDENTITY\t%s\n' "$(san_field "$terr")"
      idterr+=("$terr")
    fi
  done < <([[ -f "$map" ]] && old_group_territories "$map" "$old")

  # Tree cleanliness + dirt classification (non-fatal).
  local status git_rc
  status="$(git status --porcelain 2>/dev/null)"; git_rc=$?
  if [[ $git_rc -ne 0 ]]; then
    emit_check tree-clean fail "not a git work tree"
  elif [[ -z "$status" ]]; then
    emit_check tree-clean pass "clean"
  else
    emit_check tree-clean fail "uncommitted changes present"
    local line path klass affected_pref="$specs_dir/$old/"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      path="${line:3}"
      path="${path##* -> }"
      klass="unrelated"
      [[ "$path" == "$affected_pref"* ]] && klass="affected"
      for t in "${idterr[@]}"; do
        [[ "$path" == "$t" || "$path" == "$t/"* ]] && klass="affected"
      done
      printf 'DIRT\t%s\t%s\n' "$klass" "$(san_field "$path")"
    done <<<"$status"
  fi

  check_pending_provisionals "$specs_dir" "$old" || fail=1

  [[ $fail -eq 1 ]] && return 1
  return 0
}

# cmd_merge_preflight <map> <specs-dir> <target> <src>... — structural preflight
#   for a group merge, the N->1 counterpart of split-preflight. Emits the merge
#   ARM (absorption iff <target> is a mapped group — the target continues and the
#   listed sources are absorbed; else fresh-target — every source retires into a
#   new group), one EFFECTIVE row per effective source (effective set = listed
#   sources ∪ {target if mapped}, order-preserving dedup; provenance `listed` for
#   a listed source, `implicit` for the sugar-promoted target), per-source CHECK
#   facts, a COLLAPSE full advisory when the effective set covers every mapped
#   group, TERRITORY-IDENTITY lines per effective source, and DIRT classification
#   of a dirty tree across every source. Structural checks (map-exists,
#   source-mapped, blueprint-exists, sources-arity [effective ≥2; a smaller set
#   points to rename], sources-dup, target-slug-valid, target-collision [fresh
#   target only]) are fatal (rc 1); tree-clean / dirt is warn-confirm (non-fatal),
#   split parity. rc 0 clean · 1 structural fail · 2 usage / bad specs-dir.
cmd_merge_preflight() {
  local map="${1:-}" specs_dir="${2:-}" target="${3:-}"
  if [[ -z "$map" || -z "$specs_dir" || -z "$target" ]]; then
    echo "jimpartition merge-preflight: need <map> <specs-dir> <target> <src>..." >&2; return 2
  fi
  shift 3
  if [[ $# -eq 0 ]]; then
    echo "jimpartition merge-preflight: need <src>... (>=1 source)" >&2; return 2
  fi
  if ! valid_relpath "$specs_dir"; then
    echo "jimpartition merge-preflight: invalid specs-dir: $specs_dir" >&2; return 2
  fi
  local -a listed=("$@")
  local -a effective=() idterr=()
  local fail=0 groups="" target_mapped=0 target_implicit=0
  local s e seen g covered dup i j terr line path klass status git_rc

  if [[ -f "$map" ]]; then groups="$(map_group_slugs "$map")"; fi

  # ARM — absorption iff <target> is a mapped group, else fresh-target.
  if printf '%s\n' "$groups" | grep -qxF -- "$target"; then target_mapped=1; fi
  if [[ $target_mapped -eq 1 ]]; then printf 'ARM\tabsorption\n'; else printf 'ARM\tfresh-target\n'; fi

  # Effective set = listed ∪ {target if mapped}, order-preserving dedup. Provenance
  # is `listed` for a listed source, `implicit` for a mapped target not already
  # among the listed sources (the sugar-promoted target).
  for s in "${listed[@]}"; do
    seen=0
    for e in "${effective[@]}"; do [[ "$e" == "$s" ]] && { seen=1; break; }; done
    [[ $seen -eq 0 ]] && effective+=("$s")
  done
  if [[ $target_mapped -eq 1 ]]; then
    seen=0
    for e in "${effective[@]}"; do [[ "$e" == "$target" ]] && { seen=1; break; }; done
    if [[ $seen -eq 0 ]]; then effective+=("$target"); target_implicit=1; fi
  fi
  for e in "${effective[@]}"; do
    if [[ $target_implicit -eq 1 && "$e" == "$target" ]]; then
      printf 'EFFECTIVE\t%s\timplicit\n' "$(san_field "$e")"
    else
      printf 'EFFECTIVE\t%s\tlisted\n' "$(san_field "$e")"
    fi
  done

  # CHECKS.
  if [[ -f "$map" ]]; then
    emit_check map-exists pass "$map"
  else
    emit_check map-exists fail "map not found: $map"; fail=1
  fi

  # source-mapped per LISTED source (the implicit target is already known mapped).
  for s in "${listed[@]}"; do
    if printf '%s\n' "$groups" | grep -qxF -- "$s"; then
      emit_check "source-mapped:$s" pass "$s"
    else
      emit_check "source-mapped:$s" fail "not a mapped group: $s"; fail=1
    fi
  done

  # blueprint-exists per EFFECTIVE source (the fusion target's blueprint included).
  # Slug-gate before the filesystem probe — never `test -d` an unvalidated
  # component (split-preflight / rename-preflight parity).
  local bp_name; bp_name="$(bash "$JIMFILE" blueprint-dirname)"
  for e in "${effective[@]}"; do
    if ! valid_slug "$e"; then
      emit_check "blueprint-exists:$e" fail "invalid source slug: $e"; fail=1; continue
    fi
    if [[ -d "$specs_dir/$e/$bp_name" ]]; then
      emit_check "blueprint-exists:$e" pass "$specs_dir/$e/$bp_name"
    else
      emit_check "blueprint-exists:$e" fail "absent: $specs_dir/$e/$bp_name"; fail=1
    fi
  done

  # sources-arity: the effective set must be ≥2, else this is a 1->1 rename.
  if [[ ${#effective[@]} -lt 2 ]]; then
    emit_check sources-arity fail "effective set <2 — use /jim:partition rename for a 1->1"; fail=1
  else
    emit_check sources-arity pass "${#effective[@]} effective sources"
  fi

  # sources-dup: no duplicate among the listed sources.
  for ((i = 0; i < ${#listed[@]}; i++)); do
    for ((j = i + 1; j < ${#listed[@]}; j++)); do
      [[ "${listed[i]}" == "${listed[j]}" ]] && dup="${listed[i]}"
    done
  done
  if [[ -n "${dup:-}" ]]; then
    emit_check sources-dup fail "duplicate listed source: $dup"; fail=1
  else
    emit_check sources-dup pass "${#listed[@]} listed"
  fi

  # target-slug-valid.
  if valid_slug "$target"; then
    emit_check target-slug-valid pass "$target"
  else
    emit_check target-slug-valid fail "not a valid group slug: $target"; fail=1
  fi

  # target-collision: a FRESH target must not already be a spec-group directory
  # (an unmapped group / stray dir). Skipped for a mapped absorption target.
  if [[ $target_mapped -eq 1 ]]; then
    :                                          # absorption target legitimately pre-exists
  elif ! valid_slug "$target"; then
    :                                          # already failed target-slug-valid — never probe an unvalidated slug
  elif [[ -d "$specs_dir/$target" ]]; then
    emit_check "target-collision:$target" fail "collides with spec-group dir: $specs_dir/$target"; fail=1
  else
    emit_check "target-collision:$target" pass "$target"
  fi

  # COLLAPSE full — the effective set covers every mapped group.
  if [[ -n "$groups" ]]; then
    covered=1
    while IFS= read -r g; do
      [[ -z "$g" ]] && continue
      seen=0
      for e in "${effective[@]}"; do [[ "$e" == "$g" ]] && { seen=1; break; }; done
      [[ $seen -eq 0 ]] && { covered=0; break; }
    done <<<"$groups"
    [[ $covered -eq 1 ]] && printf 'COLLAPSE\tfull\n'
  fi

  # Territory identity per effective source: territories embedding the source slug
  # as a token, collected so DIRT can classify against them (split parity, but
  # keyed by source since a merge unions several territories).
  for e in "${effective[@]}"; do
    while IFS= read -r terr; do
      [[ -z "$terr" ]] && continue
      if slug_token_match "$e" "$terr"; then
        printf 'TERRITORY-IDENTITY\t%s\t%s\n' "$(san_field "$e")" "$(san_field "$terr")"
        idterr+=("$terr")
      fi
    done < <([[ -f "$map" ]] && old_group_territories "$map" "$e")
  done

  # Tree cleanliness + dirt classification (non-fatal). Affected = under any
  # effective source's spec dir or any identity territory; else unrelated.
  status="$(git status --porcelain 2>/dev/null)"; git_rc=$?
  if [[ $git_rc -ne 0 ]]; then
    emit_check tree-clean fail "not a git work tree"
  elif [[ -z "$status" ]]; then
    emit_check tree-clean pass "clean"
  else
    emit_check tree-clean fail "uncommitted changes present"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      path="${line:3}"
      path="${path##* -> }"
      klass="unrelated"
      for e in "${effective[@]}"; do
        [[ "$path" == "$specs_dir/$e/"* ]] && klass="affected"
      done
      for terr in "${idterr[@]}"; do
        [[ "$path" == "$terr" || "$path" == "$terr/"* ]] && klass="affected"
      done
      printf 'DIRT\t%s\t%s\n' "$klass" "$(san_field "$path")"
    done <<<"$status"
  fi

  check_pending_provisionals "$specs_dir" "${effective[@]}" || fail=1

  [[ $fail -eq 1 ]] && return 1
  return 0
}

# cmd_renumber_map <old> <targets-csv> <assign-file> <child>=<start>... —
#   compute the full spec renumber remap for a split, the deterministic id
#   arithmetic the gate presents verbatim (no LLM arithmetic). Each assign
#   line is `<NNN[-wip]>\t<child>` (child ∈ targets). Emits one
#   `MAP\t<old>/<src>\t<child>/<new>` per assignment: a continuing child
#   (child == old) keeps its numbers; a fresh child renumbers its arrivals
#   densely from its <start>, ordered by ascending source number (a `-wip` row
#   rides in the same sequence, suffix preserved). Every fresh child REQUIRES a
#   start — the ordinal part of `jimalloc.sh peek spec <child>` stdout, copied
#   verbatim — because the registry never reissues a vacated ordinal, so a
#   child name that was previously retired must resume above its high-water
#   rather than assume 001. The peek is advisory; what binds the ids is the
#   Close's `partition-batch spec`, which refuses any ordinal claimed or spent
#   in the meantime. rc 0 · 1 validation (unknown child, duplicate source, bad
#   shape, id space exhausted — no partial output) · 2 usage / bad start.
cmd_renumber_map() {
  local old="${1:-}" targets_csv="${2:-}" assign="${3:-}"
  if [[ -z "$old" || -z "$targets_csv" || -z "$assign" ]]; then
    echo "jimpartition renumber-map: need <old> <targets-csv> <assign-file> <child>=<start>..." >&2; return 2
  fi
  shift 3
  if ! valid_slug "$old"; then
    echo "jimpartition renumber-map: invalid old slug: $old" >&2; return 2
  fi
  if [[ ! -f "$assign" ]]; then
    echo "jimpartition renumber-map: assign-file not found: $assign" >&2; return 2
  fi
  local -a targets=()
  IFS=',' read -r -a targets <<< "$targets_csv"
  if [[ ${#targets[@]} -lt 2 ]]; then
    echo "jimpartition renumber-map: need >=2 targets" >&2; return 2
  fi
  local t
  for t in "${targets[@]}"; do
    valid_slug "$t" || { echo "jimpartition renumber-map: invalid target slug: $t" >&2; return 2; }
  done

  # Per-fresh-child starts: <child>=<NNN>, child a fresh target, NNN a nonzero
  # ordinal inside the registry's width bound — the value `peek spec <child>`
  # prints, copied verbatim, whatever its width. Required for every fresh child,
  # refused for the continuing one.
  local -A start_of=()
  local arg schild snnn
  for arg in "$@"; do
    if [[ "$arg" != *=* ]]; then
      echo "jimpartition renumber-map: bad start (want <child>=<NNN>): $arg" >&2; return 2
    fi
    schild="${arg%%=*}"; snnn="${arg#*=}"
    local known=0
    for t in "${targets[@]}"; do [[ "$schild" == "$t" ]] && known=1; done
    if [[ $known -eq 0 ]]; then
      echo "jimpartition renumber-map: start names an unknown child: $schild" >&2; return 2
    fi
    if [[ "$schild" == "$old" ]]; then
      echo "jimpartition renumber-map: the continuing child keeps its numbers — no start for: $schild" >&2; return 2
    fi
    if [[ ! "$snnn" =~ ^[0-9]{3,15}$ ]] || (( 10#$snnn < 1 )); then
      echo "jimpartition renumber-map: start must be a 3-15 digit id, 001 or higher: $arg" >&2; return 2
    fi
    if [[ -n "${start_of[$schild]:-}" ]]; then
      echo "jimpartition renumber-map: duplicate start for: $schild" >&2; return 2
    fi
    start_of["$schild"]=$((10#$snnn))
  done
  for t in "${targets[@]}"; do
    [[ "$t" == "$old" ]] && continue
    if [[ -z "${start_of[$t]:-}" ]]; then
      echo "jimpartition renumber-map: missing start for fresh child: $t (pass $t=<NNN>, the ordinal part of jimalloc.sh peek spec $t)" >&2; return 2
    fi
  done

  local rowsfile
  rowsfile="$(mktemp 2>/dev/null)" || { echo "jimpartition renumber-map: cannot create temp" >&2; return 2; }

  # Validate every assignment; accumulate `<child>\t<NNN>\t<src>` rows. Any bad
  # line aborts with rc 1 and no output.
  local line src child rest nnn ok rc=0
  local -A seen=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    IFS=$'\t' read -r src child rest <<<"$line"
    if [[ -z "${src:-}" || -z "${child:-}" || -n "${rest:-}" ]]; then
      echo "jimpartition renumber-map: malformed assign line: $line" >&2; rc=1; break
    fi
    if [[ ! "$src" =~ ^[0-9]{3,15}(-wip)?$ ]]; then
      echo "jimpartition renumber-map: bad source shape: $src" >&2; rc=1; break
    fi
    ok=0
    for t in "${targets[@]}"; do [[ "$child" == "$t" ]] && ok=1; done
    if [[ $ok -eq 0 ]]; then
      echo "jimpartition renumber-map: unknown child (not in targets): $child" >&2; rc=1; break
    fi
    if [[ -n "${seen[$src]:-}" ]]; then
      echo "jimpartition renumber-map: duplicate source: $src" >&2; rc=1; break
    fi
    seen[$src]=1
    nnn="${src%%-*}"
    printf '%s\t%s\t%s\n' "$child" "$nnn" "$src" >> "$rowsfile"
  done < "$assign"

  if [[ $rc -ne 0 ]]; then rm -f "$rowsfile"; return 1; fi

  # Global numeric sort by source NNN; per-child filtering below then sees each
  # child's arrivals in ascending source order.
  local sorted="$rowsfile.sorted"
  sort -t$'\t' -k2,2n -k3,3 "$rowsfile" > "$sorted"

  # Rows are buffered so an overflow returns rc 1 with no partial output —
  # the gate presents this map verbatim, so half a map must never print.
  local ch seq srctok suffix newtok _c _n
  local -a out_rows=()
  for ch in "${targets[@]}"; do
    seq="${start_of[$ch]:-0}"
    while IFS=$'\t' read -r _c _n srctok; do
      [[ -z "${srctok:-}" ]] && continue
      suffix=""
      [[ "$srctok" == *-wip ]] && suffix="-wip"
      if [[ "$ch" == "$old" ]]; then
        newtok="$srctok"                       # continuing child keeps its number
      else
        if (( ${#seq} > 15 )); then
          echo "jimpartition renumber-map: id space exhausted for $ch (would exceed 15 digits)" >&2
          rm -f "$rowsfile" "$sorted"; return 1
        fi
        newtok="$(printf '%03d' "$seq")$suffix" # fresh child: dense from its start
        seq=$(( seq + 1 ))
      fi
      out_rows+=("$(printf 'MAP\t%s/%s\t%s/%s' "$old" "$srctok" "$ch" "$newtok")")
    done < <(awk -F'\t' -v c="$ch" '$1==c' "$sorted")
  done
  rm -f "$rowsfile" "$sorted"
  local r
  for r in "${out_rows[@]}"; do printf '%s\n' "$r"; done
  return 0
}

# cmd_merge_map <specs-dir> <target> <start> <src>... — compute the merge spec
#   renumber-append remap, the deterministic id arithmetic the gate presents
#   verbatim (no LLM arithmetic). Reads each source group's numbered spec dirs
#   under <specs-dir> and appends them onto <target> starting at <start> — the
#   first id to assign, passed VERBATIM as the ordinal part of
#   `jimalloc.sh peek spec <target>` stdout (001 for a fresh target), so the
#   model copies a script value and never computes the seed itself. The peek is
#   advisory; what binds the ids is the Close's `partition-batch spec`.
#   Sources are consumed in CLI argument order,
#   each source's specs ascending by original id (the LC_ALL=C dir glob is
#   pre-sorted); a source equal to <target> (the absorption target) emits no
#   rows; the 000-blueprint is never a moved spec; an in-flight `-wip` dir rides
#   in sequence with its suffix preserved. Sources are read in NUMERIC ordinal
#   order, not the glob's lexical order, which stop agreeing once two ordinals
#   differ in width. A spec dir outside the ordinal width bound is refused
#   loudly, never omitted — a map that silently drops a representable spec is
#   the one outcome the gate's operator cannot act on. rc 0 · 1 (an assignment
#   would exceed the width bound, or a spec dir falls outside it; no partial
#   output) · 2 usage / bad start.
cmd_merge_map() {
  local specs_dir="${1:-}" target="${2:-}" start="${3:-}"
  if [[ -z "$specs_dir" || -z "$target" || -z "$start" ]]; then
    echo "jimpartition merge-map: need <specs-dir> <target> <start> <src>..." >&2; return 2
  fi
  shift 3
  if [[ $# -eq 0 ]]; then
    echo "jimpartition merge-map: need <src>... (>=1 source)" >&2; return 2
  fi
  if ! valid_relpath "$specs_dir"; then
    echo "jimpartition merge-map: invalid specs-dir: $specs_dir" >&2; return 2
  fi
  if ! valid_slug "$target"; then
    echo "jimpartition merge-map: invalid target slug: $target" >&2; return 2
  fi
  if [[ ! "$start" =~ ^[0-9]{3,15}$ ]] || (( 10#$start < 1 )); then
    echo "jimpartition merge-map: start must be a 3-15 digit id, 001 or higher: $start" >&2; return 2
  fi
  local -a srcs=("$@")
  local src
  for src in "${srcs[@]}"; do
    valid_slug "$src" || { echo "jimpartition merge-map: invalid source slug: $src" >&2; return 2; }
  done

  # Buffer rows so an overflow returns rc 1 with no partial output.
  local seq=$((10#$start))
  local -a rows=()
  local d bn onum srctok suffix r
  for src in "${srcs[@]}"; do
    [[ "$src" == "$target" ]] && continue        # absorption target keeps its numbers
    local -a bns=()
    for d in "$specs_dir/$src"/*/; do
      [[ -d "$d" ]] || continue
      bn="${d%/}"; bns+=("${bn##*/}")
    done
    (( ${#bns[@]} )) || continue
    # Numerically by ordinal. A bare LC_ALL=C glob is lexical, which stops
    # agreeing with numeric order the moment two ordinals differ in width —
    # 1000 sorts ahead of 999. renumber-map sorts numerically for this reason.
    while IFS= read -r bn; do
      [[ -n "$bn" ]] || continue
      if [[ ! "$bn" =~ ^[0-9]{3,15}(-.*)?$ ]]; then
        # A directory that is not ordinal-shaped at all is not a spec, and not
        # this verb's business. One that leads with digits but falls outside the
        # width bound IS a spec the registry can represent, and dropping it
        # would hand the gate a map that looks complete and is not.
        if [[ "$bn" =~ ^[0-9] ]]; then
          echo "jimpartition merge-map: spec dir outside the ordinal width bound: $src/$bn" >&2
          return 1
        fi
        continue
      fi
      onum="${bn%%-*}"
      [[ "$((10#$onum))" -eq 0 ]] && continue    # the blueprint is not a moved spec
      if [[ "$bn" == *-wip ]]; then srctok="$onum-wip"; suffix="-wip"; else srctok="$onum"; suffix=""; fi
      if (( ${#seq} > 15 )); then
        echo "jimpartition merge-map: id space exhausted for $target (would exceed 15 digits)" >&2; return 1
      fi
      rows+=("$(printf 'MAP\t%s/%s\t%s/%03d%s' "$src" "$srctok" "$target" "$seq" "$suffix")")
      seq=$(( seq + 1 ))
    done < <(printf '%s\n' "${bns[@]}" | sort -t- -k1,1n)
  done
  for r in "${rows[@]}"; do printf '%s\n' "$r"; done
  return 0
}

# cmd_occurrences <slug> <path>... — enumerate whole-slug-token occurrences of
#   <slug> across the given files, one HIT per (file, line, kind). Kind is a
#   STRUCTURAL hint derived from the match's position only — dotted-key (slug is
#   the group half of a dotted `slug.surface`), config-key / config-value (slug
#   sits left / right of the `=` on a TOML-ish assignment line), path (slug is a
#   `/`-bounded segment), else prose. The matched line CONTENT is never emitted
#   (a structural guarantee, not a discipline): only file, line number,
#   and kind leave this verb. rc 2 on an invalid slug or no paths.
cmd_occurrences() {
  local slug="${1:-}"
  if [[ -z "$slug" ]]; then
    echo "jimpartition occurrences: need <slug> <path>..." >&2; return 2
  fi
  shift
  if ! valid_slug "$slug"; then
    echo "jimpartition occurrences: invalid slug: $slug" >&2; return 2
  fi
  if [[ $# -eq 0 ]]; then
    echo "jimpartition occurrences: need at least one <path>" >&2; return 2
  fi
  local f
  for f in "$@"; do
    [[ -f "$f" && -r "$f" ]] || continue
    awk -v slug="$slug" -v file="$f" '
      function outside(c) { return (c == "" || c !~ /[a-z0-9-]/) }
      {
        line = $0
        # TOML-ish `key = value` assignment? capture the assignment = position.
        eqpos = 0
        if (match(line, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*=/)) eqpos = index(line, "=")
        split("", kseen)                 # dedupe kinds within this line
        n = length(slug); i = 1
        while ((p = index(substr(line, i), slug)) > 0) {
          pos = i + p - 1
          before = (pos > 1) ? substr(line, pos - 1, 1) : ""
          after  = substr(line, pos + n, 1)
          if (outside(before) && outside(after)) {
            if (after == ".")            kind = "dotted-key"
            else if (eqpos > 0)          kind = (pos < eqpos) ? "config-key" : "config-value"
            else if (before == "/" || after == "/") kind = "path"
            else                         kind = "prose"
            if (!(kind in kseen)) { printf "HIT\t%s\t%d\t%s\n", file, NR, kind; kseen[kind] = 1 }
          }
          i = pos + 1
        }
      }' "$f"
  done
  return 0
}

# cmd_edges_diff <before-tsv> <after-tsv> <old> <new> — compare two persisted
#   contract-graph edge sets (each a `jimverify.sh edges` capture: consumer TAB
#   relies-on TAB provider per line) modulo the rename. The expected after-set is
#   <before> with <old>→<new> rewritten ONLY in the consumer and provider columns
#   (whole-field match); the relies-on surface column is compared untouched — the
#   ratchet. Emits MISSING for an expected edge absent from <after> and EXTRA for
#   an <after> edge not expected. rc 0 identical-modulo-rename · rc 1 divergent ·
#   rc 2 usage.
cmd_edges_diff() {
  local before="${1:-}" after="${2:-}" old="${3:-}" new="${4:-}"
  if [[ -z "$before" || -z "$after" || -z "$old" || -z "$new" ]]; then
    echo "jimpartition edges-diff: need <before-tsv> <after-tsv> <old> <new>" >&2; return 2
  fi
  if [[ ! -f "$before" ]]; then echo "jimpartition edges-diff: before file not found: $before" >&2; return 2; fi
  if [[ ! -f "$after"  ]]; then echo "jimpartition edges-diff: after file not found: $after" >&2; return 2; fi
  if ! valid_slug "$old" || ! valid_slug "$new"; then
    echo "jimpartition edges-diff: invalid slug" >&2; return 2
  fi
  local rc
  {
    awk 'NF{print "B\t" $0}' "$before"
    awk 'NF{print "A\t" $0}' "$after"
  } | awk -F'\t' -v old="$old" -v new="$new" '
    function rw(c) { return (c == old) ? new : c }
    $2 == "HYGIENE" { next }
    {
      c1 = $2; c2 = $3; c3 = $4
      if (c1 == "" && c2 == "" && c3 == "") next
      if ($1 == "B") want[rw(c1) "\t" c2 "\t" rw(c3)]++
      else           have[c1 "\t" c2 "\t" c3]++
    }
    END {
      diverge = 0
      for (k in want) { d = want[k] - (k in have ? have[k] : 0); for (j = 0; j < d; j++) { print "MISSING\t" k; diverge = 1 } }
      for (k in have) { d = have[k] - (k in want ? want[k] : 0); for (j = 0; j < d; j++) { print "EXTRA\t" k; diverge = 1 } }
      exit (diverge ? 1 : 0)
    }'
  rc=$?
  return $rc
}

# cmd_merge_edges_diff <before-tsv> <after-tsv> <target> <src>... — the merge form
#   of edges-diff: the post-merge graph done-condition. The expected after-set is
#   <before> with EVERY <src> rewritten to <target> in the consumer and provider
#   columns (whole-field match), then any row whose rewritten consumer equals its
#   rewritten provider DROPPED — a cross-source edge that became internal to the
#   merged group dissolves. The relies-on surface column is compared untouched
#   (the ratchet). The self-edge elision is safe by construction: a pre-merge
#   contract graph cannot contain a self-edge (the requires face is cross-group by
#   template), so a post-rewrite self-row can only be a dissolved cross-source
#   edge. Emits MISSING for an expected edge absent from <after> and EXTRA for an
#   <after> edge not expected. rc 0 identical-modulo-merge · rc 1 divergent · rc 2
#   usage.
cmd_merge_edges_diff() {
  local before="${1:-}" after="${2:-}" target="${3:-}"
  if [[ -z "$before" || -z "$after" || -z "$target" ]]; then
    echo "jimpartition merge-edges-diff: need <before-tsv> <after-tsv> <target> <src>..." >&2; return 2
  fi
  shift 3
  if [[ $# -eq 0 ]]; then
    echo "jimpartition merge-edges-diff: need <src>... (>=1 source)" >&2; return 2
  fi
  if [[ ! -f "$before" ]]; then echo "jimpartition merge-edges-diff: before file not found: $before" >&2; return 2; fi
  if [[ ! -f "$after"  ]]; then echo "jimpartition merge-edges-diff: after file not found: $after" >&2; return 2; fi
  if ! valid_slug "$target"; then
    echo "jimpartition merge-edges-diff: invalid target slug: $target" >&2; return 2
  fi
  local src srcs_csv=""
  for src in "$@"; do
    valid_slug "$src" || { echo "jimpartition merge-edges-diff: invalid source slug: $src" >&2; return 2; }
    srcs_csv="${srcs_csv:+$srcs_csv,}$src"
  done
  local rc
  {
    awk 'NF{print "B\t" $0}' "$before"
    awk 'NF{print "A\t" $0}' "$after"
  } | awk -F'\t' -v target="$target" -v srcs="$srcs_csv" '
    BEGIN { n = split(srcs, a, ","); for (i = 1; i <= n; i++) issrc[a[i]] = 1 }
    function rw(c) { return (c in issrc) ? target : c }
    $2 == "HYGIENE" { next }
    {
      c1 = $2; c2 = $3; c3 = $4
      if (c1 == "" && c2 == "" && c3 == "") next
      if ($1 == "B") {
        r1 = rw(c1); r3 = rw(c3)
        if (r1 == r3) next                       # dissolved internal edge — elided
        want[r1 "\t" c2 "\t" r3]++
      } else {
        have[c1 "\t" c2 "\t" c3]++
      }
    }
    END {
      diverge = 0
      for (k in want) { d = want[k] - (k in have ? have[k] : 0); for (j = 0; j < d; j++) { print "MISSING\t" k; diverge = 1 } }
      for (k in have) { d = have[k] - (k in want ? want[k] : 0); for (j = 0; j < d; j++) { print "EXTRA\t" k; diverge = 1 } }
      exit (diverge ? 1 : 0)
    }'
  rc=$?
  return $rc
}

# ─── Section: rewrite-identity ───────────────────────────────────────────────
#
# The ONE in-place file-mutating verb in this otherwise stdout-only substrate
# script. It carries the deterministic mechanical floor of a `rewrite`-mode group
# migration: the structurally-unambiguous identity edits in a moved numbered
# spec's body. Free prose is never touched — that judgment is the read-only
# gatherer's (freeze-on-doubt). As the first mutating verb it clears the
# write-primitive containment guard (each target under the worktree top, a
# symlink escape or non-tracked path refused) BEFORE any edit, so the
# deterministic path is safer than a raw skill Edit.

# rewrite_scan_malformed <file> — read-only pre-scan: emit `<file>:<line>`
#   (location-only, NO content) for each frontmatter `group:` line whose value is
#   not a single slug token. A corrupt identity frontmatter is fail-closed —
#   the verb refuses to guess rather than risk corrupting substance (the
#   signal stays location-only).
rewrite_scan_malformed() {
  awk -v file="$1" '
    NR == 1 && $0 == "---" { infm = 1; next }
    infm && $0 == "---"    { infm = 0; next }
    infm && /^[ \t]*group:[ \t]/ {
      val = $0; sub(/^[ \t]*group:[ \t]*/, "", val); sub(/[ \t]*$/, "", val)
      if (val ~ /^".*"$/)              v = substr(val, 2, length(val) - 2)
      else if (val ~ /^\047.*\047$/)   v = substr(val, 2, length(val) - 2)
      else                             v = val
      if (v !~ /^[a-z0-9][a-z0-9-]*$/) print file ":" NR
    }' "$1"
}

# cmd_rewrite_identity [--skip-typed-refs] <old> <new> <file>... — rewrite
#   whole-token identity occurrences of <old> to <new>, in place, in each
#   numbered-spec <file>: frontmatter `group:` value, dotted-key group-halves
#   (`<old>.<surface>` — the surface half untouched), and typed group/NNN refs
#   (`<old>/<digit>`). With --skip-typed-refs the typed-ref kind is left untouched
#   (no edit, no record): on a renumbering move the typed ref's number changes, so
#   it belongs to rewrite-refs' remap sweep exclusively and must not be number-
#   preserved by this pass. Free prose is left for the gatherer. Emits one
#   location-only `REWROTE\t<file>\t<line>\t<kind>` per edit; success and error
#   output alike never carry matched or surrounding content. rc: 0
#   applied (zero edits is success) · 2 usage / invalid slug / a target that
#   fails the containment guard / a malformed identity frontmatter.
cmd_rewrite_identity() {
  # Optional first-position flag. Only the exact literal is recognized; any other
  # leading token (a typo'd --foo) falls through to <old> and fails the slug gate
  # below — flag parsing is fail-closed by construction.
  local skiptyped=0
  if [[ "${1:-}" == "--skip-typed-refs" ]]; then
    skiptyped=1; shift
  fi
  local old="${1:-}" new="${2:-}"
  if [[ -z "$old" || -z "$new" ]]; then
    echo "jimpartition rewrite-identity: need [--skip-typed-refs] <old> <new> <file>..." >&2; return 2
  fi
  shift 2
  if [[ $# -eq 0 ]]; then
    echo "jimpartition rewrite-identity: need at least one <file>" >&2; return 2
  fi
  if ! valid_slug "$old" || ! valid_slug "$new"; then
    echo "jimpartition rewrite-identity: invalid slug" >&2; return 2
  fi
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "jimpartition rewrite-identity: not in a git repo" >&2; return 2
  fi

  # Guard pass — run to completion over ALL targets before any edit (the
  # write-primitive containment guard): each
  # path shape-valid, resolved inside the worktree top (rejecting a symlink
  # escape), and tracked; and no target carries a malformed identity frontmatter.
  # Any failure aborts with a location-only reason and no file touched.
  local f resolved
  for f in "$@"; do
    if ! valid_relpath "$f"; then
      echo "jimpartition rewrite-identity: unsafe path rejected: $(san_field "$f")" >&2; return 2
    fi
    if ! resolved="$(realpath -m -- "$f" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "jimpartition rewrite-identity: path escapes worktree: $(san_field "$f")" >&2; return 2
    fi
    if [[ -z "$(git ls-files -- "$f" 2>/dev/null)" ]]; then
      echo "jimpartition rewrite-identity: path not tracked: $(san_field "$f")" >&2; return 2
    fi
    local bad
    bad="$(rewrite_scan_malformed "$f")"
    if [[ -n "$bad" ]]; then
      echo "jimpartition rewrite-identity: malformed group frontmatter at $(san_field "$bad")" >&2; return 2
    fi
  done

  # Edit pass — every guard passed. Each file's rewrite runs in one awk: the
  # rewritten body to a temp, the location-only REWROTE records to a side file.
  # old/new are slug-gated above, so neither can carry a regex/quote
  # metacharacter into awk (-v literals).
  local rwtmp tmp_out rec awk_rc rw_failed=0
  if ! rwtmp="$(mktemp -d 2>/dev/null)"; then
    echo "jimpartition rewrite-identity: cannot create temp dir" >&2; return 2
  fi
  tmp_out="$rwtmp/out"; rec="$rwtmp/rec"
  for f in "$@"; do
    : > "$rec"
    awk -v old="$old" -v new="$new" -v file="$f" -v recfile="$rec" \
        -v skiptyped="$skiptyped" \
        -v exts="js ts jsx tsx mjs cjs rs ex exs go py rb java c h cc cpp cxx hh hpp hxx cs php kt kts swift scala sc clj cljs cljc hs pl pm lua dart r md json sh bash toml yaml yml txt html css cfg ini xml csv" '
      BEGIN {
        oldn = length(old)
        ne = split(exts, ea, " "); for (ei = 1; ei <= ne; ei++) EXT[ea[ei]] = 1
      }
      {
        line = $0
        if (NR == 1 && line == "---") { infm = 1; print; next }
        if (infm && line == "---")    { infm = 0; print; next }
        if (infm && line ~ /^[ \t]*group:[ \t]/) {
          val = line; sub(/^[ \t]*group:[ \t]*/, "", val); sub(/[ \t]*$/, "", val)
          q = ""
          if (val ~ /^".*"$/)            { q = "\""; v = substr(val, 2, length(val) - 2) }
          else if (val ~ /^\047.*\047$/) { q = "\047"; v = substr(val, 2, length(val) - 2) }
          else                           { v = val }
          if (v == old) {
            ind = line; sub(/group:.*/, "", ind)
            printf "%sgroup: %s%s%s\n", ind, q, new, q
            print "REWROTE\t" file "\t" NR "\tgroup" > recfile
            next
          }
          print line; next
        }
        if (infm) { print line; next }   # only `group:` is an identity field in frontmatter
        # Body token scan: rewrite <old> only as a whole slug token in a
        # dotted-key (<old>.<surface>, excluding a bare file-extension suffix)
        # or typed group/NNN ref (<old>/[0-9]) position; leave prose and
        # code-path segments (and filenames) to the gatherer.
        out = ""; i = 1
        while ((p = index(substr(line, i), old)) > 0) {
          pos = i + p - 1
          before = (pos > 1) ? substr(line, pos - 1, 1) : ""
          after  = substr(line, pos + oldn, 1)
          after2 = substr(line, pos + oldn + 1, 1)
          isbound = (before !~ /[a-z0-9-]/ && after !~ /[a-z0-9-]/)
          # The dotted suffix is the identifier run after the dot; a bare
          # file-extension suffix (cart.json) is a filename, not a group.surface
          # dotted-key, so it is excluded.
          dotsuffix = ""
          if (after == ".") {
            k = pos + oldn + 1
            while (k <= length(line) && substr(line, k, 1) ~ /[a-z0-9-]/) { dotsuffix = dotsuffix substr(line, k, 1); k++ }
          }
          dotted  = (after == "." && after2 ~ /[a-z0-9]/ && !(dotsuffix in EXT))
          typed   = (after == "/" && after2 ~ /[0-9]/)
          if (isbound && (dotted || (typed && !skiptyped))) {
            out = out substr(line, i, pos - i) new
            print "REWROTE\t" file "\t" NR "\t" (dotted ? "dotted-key" : "typed-ref") > recfile
          } else {
            out = out substr(line, i, pos - i + oldn)
          }
          i = pos + oldn
        }
        out = out substr(line, i)
        print out
      }' "$f" > "$tmp_out"
    # A rewrite that died partway through has already written whatever records it
    # got to, so a non-empty record file is NOT evidence the output is whole.
    # Install only on a clean exit; other files still rewrite, and the run fails.
    awk_rc=$?
    if (( awk_rc != 0 )); then
      echo "jimpartition rewrite-identity: the rewrite failed partway through '$(san_field "$f")'; nothing installed for it" >&2
      rw_failed=1
      continue
    fi
    if [[ -s "$rec" ]]; then
      # The awk check covers the producer; this covers the consumer. Reporting
      # REWROTE for an install that failed is the same lie one step later.
      if ! cat -- "$tmp_out" > "$f"; then
        echo "jimpartition rewrite-identity: could not install the rewrite of '$(san_field "$f")'; it may be partially written" >&2
        rw_failed=1
        continue
      fi
      cat -- "$rec"
    fi
  done
  rm -rf -- "$rwtmp"
  return "$rw_failed"
}

# cmd_rewrite_refs <remap-file> <file>... — rewrite whole-token `group/NNN`
#   references to their remap targets, in place, across the given files.
#   The sibling of rewrite-identity for the wider reference surface: where
#   rewrite-identity carries one global <old>→<new> group rename, this carries a
#   per-occurrence remap TABLE — and that table IS the whitelist: only a
#   `<og>/<onum>` present in the remap is ever touched, so a reference to an
#   unmoved spec is unrewritable by construction. Each remap line
#   is `<og>/<onum>\t<ng>/<nnum>`, slug-and-ordinal gated in bash; a malformed
#   line → rc 2 before any edit. The match is whole-token:
#   the char before <og> is not [a-z0-9-] and the char after <onum> is not
#   [a-z0-9] — a dash or any other delimiter after the number is permitted, so a
#   typed ref (`cart/006`) and a dir-path prefix (`docs/specs/cart/006-foo`) both
#   match while `cart/0060`, `cart/006abc`, `cart/006x`, `xcart/006` never do.
#   Both halves are rewritten; everything else is verbatim. The guard pass runs
#   over ALL files before ANY edit (the rewrite-identity loop-separation
#   precedent): each target is valid_relpath, resolves under the worktree top, and
#   is tracked; any failure aborts rc 2 with zero files touched. Emits one
#   location-only `REWROTE\t<file>\t<line>\t<typed-ref|path>` per edit. rc: 0
#   applied (zero edits is success) · 2 usage / malformed remap / containment.
cmd_rewrite_refs() {
  local remap="${1:-}"
  if [[ -z "$remap" ]]; then
    echo "jimpartition rewrite-refs: need <remap-file> <file>..." >&2; return 2
  fi
  shift
  if [[ ! -f "$remap" ]]; then
    echo "jimpartition rewrite-refs: remap-file not found: $remap" >&2; return 2
  fi
  if [[ $# -eq 0 ]]; then
    echo "jimpartition rewrite-refs: need at least one <file>" >&2; return 2
  fi

  # Parse + validate the remap (the whitelist); any malformed line aborts rc 2
  # before any file is touched. Normalized rows land in $parsed as
  # `<og>\t<onum>\t<ng>\t<nnum>` for the awk lookup.
  local parsed
  if ! parsed="$(mktemp 2>/dev/null)"; then
    echo "jimpartition rewrite-refs: cannot create temp" >&2; return 2
  fi
  local line og_on ng_nn rest og onum ng nnum
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    IFS=$'\t' read -r og_on ng_nn rest <<<"$line"
    if [[ -z "${og_on:-}" || -z "${ng_nn:-}" || -n "${rest:-}" ]]; then
      echo "jimpartition rewrite-refs: malformed remap line: $line" >&2; rm -f "$parsed"; return 2
    fi
    og="${og_on%%/*}"; onum="${og_on#*/}"
    ng="${ng_nn%%/*}"; nnum="${ng_nn#*/}"
    if ! valid_slug "$og" || ! valid_slug "$ng" \
       || [[ ! "$onum" =~ ^[0-9]{3,15}$ || ! "$nnum" =~ ^[0-9]{3,15}$ ]]; then
      echo "jimpartition rewrite-refs: malformed remap line: $line" >&2; rm -f "$parsed"; return 2
    fi
    printf '%s\t%s\t%s\t%s\n' "$og" "$onum" "$ng" "$nnum" >> "$parsed"
  done < "$remap"

  # Guard pass — run over ALL targets before ANY edit (rewrite-identity precedent).
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "jimpartition rewrite-refs: not in a git repo" >&2; rm -f "$parsed"; return 2
  fi
  local f resolved
  for f in "$@"; do
    if ! valid_relpath "$f"; then
      echo "jimpartition rewrite-refs: unsafe path rejected: $(san_field "$f")" >&2; rm -f "$parsed"; return 2
    fi
    if ! resolved="$(realpath -m -- "$f" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "jimpartition rewrite-refs: path escapes worktree: $(san_field "$f")" >&2; rm -f "$parsed"; return 2
    fi
    if [[ -z "$(git ls-files -- "$f" 2>/dev/null)" ]]; then
      echo "jimpartition rewrite-refs: path not tracked: $(san_field "$f")" >&2; rm -f "$parsed"; return 2
    fi
  done

  # Edit pass — every guard passed. The awk loads the remap (keyed on FILENAME so
  # an empty remap never mis-reads the target's first line), then does the
  # boundary-gated whole-token rewrite per line; location-only records to a side
  # file. og/onum/ng/nnum are slug/digit gated above, so none carries a regex or
  # quote metacharacter.
  local rwtmp tmp_out rec awk_rc rw_failed=0
  if ! rwtmp="$(mktemp -d 2>/dev/null)"; then
    echo "jimpartition rewrite-refs: cannot create temp dir" >&2; rm -f "$parsed"; return 2
  fi
  tmp_out="$rwtmp/out"; rec="$rwtmp/rec"
  for f in "$@"; do
    : > "$rec"
    awk -F'\t' -v file="$f" -v recfile="$rec" '
      BEGIN { rf = ARGV[1] }
      FILENAME == rf { SRC[FNR] = $1 "/" $2; DST[FNR] = $3 "/" $4; nmap = FNR; next }
      {
        line = $0; out = ""; i = 1; L = length(line)
        while (i <= L) {
          matched = 0
          for (m = 1; m <= nmap; m++) {
            s = SRC[m]; sl = length(s)
            if (substr(line, i, sl) == s) {
              before = (i > 1) ? substr(line, i - 1, 1) : ""
              ap = i + sl; after = (ap <= L) ? substr(line, ap, 1) : ""
              if (before !~ /[a-z0-9-]/ && after !~ /[a-z0-9]/) {
                out = out DST[m]
                print "REWROTE\t" file "\t" FNR "\t" (before == "/" ? "path" : "typed-ref") > recfile
                i += sl; matched = 1; break
              }
            }
          }
          if (!matched) { out = out substr(line, i, 1); i++ }
        }
        print out
      }' "$parsed" "$f" > "$tmp_out"
    # A rewrite that died partway through has already written whatever records it
    # got to, so a non-empty record file is NOT evidence the output is whole.
    # Install only on a clean exit; other files still rewrite, and the run fails.
    awk_rc=$?
    if (( awk_rc != 0 )); then
      echo "jimpartition rewrite-refs: the rewrite failed partway through '$(san_field "$f")'; nothing installed for it" >&2
      rw_failed=1
      continue
    fi
    if [[ -s "$rec" ]]; then
      # The awk check covers the producer; this covers the consumer. Reporting
      # REWROTE for an install that failed is the same lie one step later.
      if ! cat -- "$tmp_out" > "$f"; then
        echo "jimpartition rewrite-refs: could not install the rewrite of '$(san_field "$f")'; it may be partially written" >&2
        rw_failed=1
        continue
      fi
      cat -- "$rec"
    fi
  done
  rm -rf -- "$rwtmp"; rm -f "$parsed"
  return "$rw_failed"
}

# ─── Section: health ─────────────────────────────────────────────────────────
#
# Two read-only verbs for /jim:partition health. Like the rest of this script
# they write nothing and run no operator command — the deterministic floor the
# skill's inline trend-interpretation builds on. health-eval composes the
# reconcile-series trend source with the threshold knobs; identity-check compares
# a group's declared territory paths against current and retired group slugs.

# cmd_health_eval <specs-dir> — deterministic threshold evaluation over the
#   reconcile-event series. Composes `jimledger.sh reconcile-series` (trend
#   input) with `jimconf.sh get` (the five health_threshold_* knobs), both
#   BASH_SOURCE-relative, and emits:
#     THRESHOLDS\t<active>\t<disabled>   counts over the five keys
#     INVALID\t<key>                     a set-but-malformed key
#     CROSSED\t<signal>\t<observed>\t<threshold>
#   Predicates: cycles|fanin|uncovered|faces_max → the LATEST event's value >= N
#   (`na` never crosses); breaking_runs → trailing consecutive events with
#   breaking>0 >= N (a single noisy reconcile never arms). Threshold values are
#   integer-compared, never executed. Firing derives only from the whitelisted
#   trusted counter channel — never from claims in scanned content. rc: 0
#   facts emitted · 1 no series · 2 bad args.
cmd_health_eval() {
  local specs_dir="${1:-}"
  if [[ -z "$specs_dir" ]]; then
    echo "jimpartition health-eval: need <specs-dir>" >&2; return 2
  fi
  local series
  series="$(bash "$JIMLEDGER" reconcile-series "$specs_dir")" || return 1

  # Resolve the five bare-name integer thresholds. A positive integer arms the
  # key; "0" is the disabled default; any other value is set-but-malformed →
  # disabled and noted INVALID.
  local sig val active=0 disabled=0
  local -a invalid=()
  local -A armed=()
  for sig in cycles fanin uncovered faces_max breaking_runs; do
    val="$(bash "$JIMCONF" get "health_threshold_$sig" 2>/dev/null)"
    if [[ "$val" =~ ^[0-9]+$ && "$val" -gt 0 ]]; then
      armed[$sig]="$val"; active=$((active + 1))
    elif [[ "$val" =~ ^[0-9]+$ ]]; then
      disabled=$((disabled + 1))                    # exactly 0 → disabled, silent
    else
      disabled=$((disabled + 1)); invalid+=("$sig") # junk → disabled + noted
    fi
  done

  printf 'THRESHOLDS\t%d\t%d\n' "$active" "$disabled"
  for sig in "${invalid[@]}"; do printf 'INVALID\thealth_threshold_%s\n' "$sig"; done

  # Latest-event counters + the trailing breaking>0 run length, from the EVENT
  # lines only (oldest→newest, so the last EVENT is the latest).
  local facts
  facts="$(printf '%s\n' "$series" | awk -F'\t' '
    $1 == "EVENT" {
      split("", cur)
      for (i = 3; i <= NF; i++) { eq = index($i, "="); if (eq > 0) cur[substr($i,1,eq-1)] = substr($i,eq+1) }
      lc = ("cycles"    in cur) ? cur["cycles"]    : ""
      lf = ("fanin"     in cur) ? cur["fanin"]     : ""
      lu = ("uncovered" in cur) ? cur["uncovered"] : ""
      lm = ("faces_max" in cur) ? cur["faces_max"] : ""
      b  = ("breaking"  in cur) ? cur["breaking"]  : ""
      if (b ~ /^[0-9]+$/ && b + 0 > 0) run++; else run = 0
    }
    END { print "cycles=" lc; print "fanin=" lf; print "uncovered=" lu; print "faces_max=" lm; print "run=" (run + 0) }')"
  local latest_cycles latest_fanin latest_uncovered latest_faces_max breaking_run
  latest_cycles="$(printf '%s\n' "$facts" | sed -n 's/^cycles=//p')"
  latest_fanin="$(printf '%s\n' "$facts" | sed -n 's/^fanin=//p')"
  latest_uncovered="$(printf '%s\n' "$facts" | sed -n 's/^uncovered=//p')"
  latest_faces_max="$(printf '%s\n' "$facts" | sed -n 's/^faces_max=//p')"
  breaking_run="$(printf '%s\n' "$facts" | sed -n 's/^run=//p')"

  local n v
  for sig in cycles fanin uncovered faces_max breaking_runs; do
    n="${armed[$sig]:-}"
    [[ -n "$n" ]] || continue
    if [[ "$sig" == "breaking_runs" ]]; then
      if (( breaking_run >= n )); then printf 'CROSSED\tbreaking_runs\t%s\t%s\n' "$breaking_run" "$n"; fi
      continue
    fi
    case "$sig" in
      cycles)    v="$latest_cycles" ;;
      fanin)     v="$latest_fanin" ;;
      uncovered) v="$latest_uncovered" ;;
      faces_max) v="$latest_faces_max" ;;
    esac
    if [[ "$v" =~ ^[0-9]+$ ]] && (( v >= n )); then
      printf 'CROSSED\t%s\t%s\t%s\n' "$sig" "$v" "$n"
    fi
  done
  return 0
}

# cmd_identity_check <map> [<specs-dir>] — deterministic name-mismatch sensor.
#   For each mapped group G and each of its declared territory paths P, emit a
#   MISMATCH when P embeds an identity token conflicting with G's own name:
#     foreign — P whole-token-matches another CURRENT group's slug
#     retired — P whole-token-matches a slug retired by a `partition finished`
#               op=rename / op=split / op=merge event (only when <specs-dir> is
#               given; whitelisted, slug-gated parse) — a stalled docs-only move.
#   A path embedding no conflicting token is not a mismatch (the false-positive
#   guard). Reuses map_group_slugs / old_group_territories /
#   slug_token_match. rc: 0 (clean or mismatches) · 2 absent/invalid map.
cmd_identity_check() {
  local map="${1:-}" specs_dir="${2:-}"
  if [[ -z "$map" ]]; then
    echo "jimpartition identity-check: need <map> [<specs-dir>]" >&2; return 2
  fi
  if [[ ! -f "$map" ]]; then
    echo "jimpartition identity-check: map not found: $map" >&2; return 2
  fi

  local groups
  groups="$(map_group_slugs "$map")"

  # Retired slugs: old= tokens from `partition finished` op=rename / op=split /
  # op=merge events, under ONE uniform rule — an old token is retired iff it is
  # not among the new tokens. Whitelisted (the three ops) and slug-gated per
  # token so a hand-edited ledger cannot inject a non-slug token. The single rule
  # subsumes every arm: rename (old single, new single), split (old single, new
  # the child list — an extraction remainder listed in new stays live), and merge
  # (old the effective sources, new the single target — a surviving absorption
  # target listed in new stays live). Only consulted when a specs-dir with a
  # ledger is supplied.
  local retired=""
  if [[ -n "$specs_dir" && -f "$specs_dir/ledger.md" ]]; then
    retired="$(awk -F'\t' '
      $3 == "partition" && $4 == "finished" {
        if (index(";" $5 ";", ";op=rename;") == 0 &&
            index(";" $5 ";", ";op=split;")  == 0 &&
            index(";" $5 ";", ";op=merge;")  == 0) next
        oldv = ""; newv = ""
        n = split($5, pairs, ";")
        for (j = 1; j <= n; j++) {
          if (index(pairs[j], "old=") == 1)      oldv = substr(pairs[j], 5)
          else if (index(pairs[j], "new=") == 1) newv = substr(pairs[j], 5)
        }
        split("", newset)                              # per-event new-token set
        m = split(newv, na, ",")
        for (k = 1; k <= m; k++) if (na[k] ~ /^[a-z0-9][a-z0-9-]*$/) newset[na[k]] = 1
        p = split(oldv, oa, ",")
        for (k = 1; k <= p; k++) {
          if (oa[k] ~ /^[a-z0-9][a-z0-9-]*$/ && !(oa[k] in newset)) print oa[k]
        }
      }' "$specs_dir/ledger.md" | sort -u)"
  fi

  local g terr other r
  while IFS= read -r g; do
    [[ -z "$g" ]] && continue
    while IFS= read -r terr; do
      [[ -z "$terr" ]] && continue
      while IFS= read -r other; do
        [[ -z "$other" || "$other" == "$g" ]] && continue
        if slug_token_match "$other" "$terr"; then
          printf 'MISMATCH\t%s\t%s\t%s\tforeign\n' "$g" "$(san_field "$terr")" "$other"
        fi
      done <<<"$groups"
      if [[ -n "$retired" ]]; then
        while IFS= read -r r; do
          [[ -z "$r" || "$r" == "$g" ]] && continue
          if slug_token_match "$r" "$terr"; then
            printf 'MISMATCH\t%s\t%s\t%s\tretired\n' "$g" "$(san_field "$terr")" "$r"
          fi
        done <<<"$retired"
      fi
    done < <(old_group_territories "$map" "$g")
  done <<<"$groups"
  return 0
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

main() {
  local sub="${1:-}"
  case "$sub" in
    scan)      shift; cmd_scan "$@" ;;
    ingest)    shift; cmd_ingest "$@" ;;
    aggregate) shift; cmd_aggregate "$@" ;;
    coverage)  shift; cmd_coverage "$@" ;;
    rename-preflight) shift; cmd_rename_preflight "$@" ;;
    split-preflight) shift; cmd_split_preflight "$@" ;;
    merge-preflight) shift; cmd_merge_preflight "$@" ;;
    renumber-map) shift; cmd_renumber_map "$@" ;;
    merge-map) shift; cmd_merge_map "$@" ;;
    occurrences) shift; cmd_occurrences "$@" ;;
    rewrite-identity) shift; cmd_rewrite_identity "$@" ;;
    rewrite-refs) shift; cmd_rewrite_refs "$@" ;;
    edges-diff) shift; cmd_edges_diff "$@" ;;
    merge-edges-diff) shift; cmd_merge_edges_diff "$@" ;;
    health-eval) shift; cmd_health_eval "$@" ;;
    identity-check) shift; cmd_identity_check "$@" ;;
    *)         usage; return 2 ;;
  esac
}

main "$@"
exit $?
