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
#   before use; this script NEVER resolves or executes an operator extractor
#   command — the operator's config activates those commands (through
#   jimconf.sh) and the model runs them via the Bash tool (the spec 035
#   registry trust boundary). The extractor-registry family name appears
#   nowhere in this script by design.
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
  rename-preflight <map> <specs-dir> <old> <new>   CHECK/DIRT/TERRITORY-IDENTITY
  occurrences <slug> <path>...                  whole-token hits → HIT file line kind
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
#   dropped (the ingest choke point, security Finding 3).
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
  # A modeled language whose manifest fails the charset gate (Finding 7) degrades
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
#   for the module prefix, charset-gated before use (Finding 7): a Go module path
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
#   names, charset-gated (Finding 7); a file under a bad-named crate degrades to
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
#   Elixir source (module names charset-gated, Finding 7), then resolve each
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
#   groups — a single foreign consumer is a normal GEDGE, DD 14), and
#   UNASSIGNED dirs (endpoints under no territory, dirname-aggregated). Group
#   assignment is a slash-anchored longest-prefix match (039 semantics). The
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

# ─── Section: rename (spec 043) ──────────────────────────────────────────────
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

  if [[ -d "$specs_dir/$old/000-blueprint" ]]; then
    emit_check blueprint-exists pass "$specs_dir/$old/000-blueprint"
  else
    emit_check blueprint-exists fail "absent: $specs_dir/$old/000-blueprint"; fail=1
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

  [[ $fail -eq 1 ]] && return 1
  return 0
}

# cmd_occurrences <slug> <path>... — enumerate whole-slug-token occurrences of
#   <slug> across the given files, one HIT per (file, line, kind). Kind is a
#   STRUCTURAL hint derived from the match's position only — dotted-key (slug is
#   the group half of a dotted `slug.surface`), config-key / config-value (slug
#   sits left / right of the `=` on a TOML-ish assignment line), path (slug is a
#   `/`-bounded segment), else prose. The matched line CONTENT is never emitted
#   (AC 19 is a structural guarantee, not a discipline): only file, line number,
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

# ─── Section: Argument dispatch ──────────────────────────────────────────────

main() {
  local sub="${1:-}"
  case "$sub" in
    scan)      shift; cmd_scan "$@" ;;
    ingest)    shift; cmd_ingest "$@" ;;
    aggregate) shift; cmd_aggregate "$@" ;;
    coverage)  shift; cmd_coverage "$@" ;;
    rename-preflight) shift; cmd_rename_preflight "$@" ;;
    occurrences) shift; cmd_occurrences "$@" ;;
    *)         usage; return 2 ;;
  esac
}

main "$@"
exit $?
