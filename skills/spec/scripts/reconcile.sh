#!/usr/bin/env bash
#
# skills/spec/scripts/reconcile.sh — realize pending provisional spec
#   identities into real, coordinated ordinals. One-shot and previewed, in the
#   backfill.sh / migrate.sh family — it never runs automatically; a developer
#   invokes it explicitly, typically once a session that scoped specs offline
#   reaches the coordination point again.
#
# PURPOSE
#   A spec scoped while the coordination point was unreachable is bound to a
#   provisional identity whose ordinal slot carries a reserved prefix, and it
#   wears that identity as its directory name. This script finds those pending
#   directories, asks the allocator what real ordinal each becomes, and reports
#   the mapping.
#
#   Two things must agree before a directory is treated as a pending identity:
#   its basename must be the reserved form the allocator issues, and its own
#   spec.md frontmatter must claim the same identity. Either failing is a
#   warning and a skip, never a fatal stop — one unusable directory must not
#   strand every other pending spec. Directory names and frontmatter are
#   ordinary branch content, writable by anyone who can commit, so every token
#   crosses jimfile.sh's boundary before it reaches the allocator or a path.
#
# CLI SUMMARY
#   bash reconcile.sh [<specs_dir>]
#     PREVIEW (read-only): list pending provisional identities and the real
#     ordinal each would take. Mutates nothing.
#   bash reconcile.sh --apply [<specs_dir>]
#     APPLY: realize through the allocator, then rename each directory onto its
#     ordinal — git mv when tracked, a plain move when not — and rewrite the
#     frontmatter id.
#   bash reconcile.sh -c <config> [...]
#     Forward -c to jimfile.sh / jimconf.sh / jimalloc.sh (used by tests).
#   specs_dir default: jimconf.sh get specs
#
#   The preview keeps the allocator's state column. An identity the registry
#   already holds reads "have" — which is how a resumed run looks, and equally
#   how two specs keying alike look, so it is the developer's tell rather than
#   something to hide.
#
# EXIT CODES
#   0  Success (including the nothing-pending no-op).
#   1  IO failure, or jimalloc.sh reconcile spec halts.
#   2  Malformed invocation (unknown option).
#
# Line-oriented only; never sources or evals a spec file.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
JIMALLOC="$(dirname "$JIMFILE")/jimalloc.sh"
JIMLEDGER="$(cd "$HERE/../../ledger/scripts" && pwd)/jimledger.sh"

# The reserved prefix a provisional identity's ordinal slot carries. The grammar
# belongs to the allocator; it is named here because a spec bound offline wears
# it as a directory name and this scan has to recognize one.
readonly PROV_PREFIX="P-"

CFG=""   # optional jimconf override path, forwarded to jimfile/jimconf/jimalloc

# jf / jc / ja <args...> — invoke jimfile.sh / jimconf.sh / jimalloc.sh,
# forwarding -c when set.
jf() { if [[ -n "$CFG" ]]; then bash "$JIMFILE" -c "$CFG" "$@"; else bash "$JIMFILE" "$@"; fi; }
jc() { if [[ -n "$CFG" ]]; then bash "$JIMCONF" -c "$CFG" "$@"; else bash "$JIMCONF" "$@"; fi; }
ja() { if [[ -n "$CFG" ]]; then bash "$JIMALLOC" -c "$CFG" "$@"; else bash "$JIMALLOC" "$@"; fi; }

# resolve_specs_dir <arg> — arg if non-empty, else the jimconf default; strip a
# trailing slash.
resolve_specs_dir() {
  local dir="${1:-}"
  [[ -z "$dir" ]] && dir="$(jc get specs 2>/dev/null)"
  dir="${dir%/}"
  if [[ -z "$dir" ]]; then
    echo "error: specs dir is empty" >&2
    return 2
  fi
  printf '%s\n' "$dir"
}

# field_value <file> <field> — the value of <field> inside the file's LEADING
# frontmatter block, quotes stripped; empty when there is no leading block or it
# does not carry the field.
#
# Detection reads the SAME region the rewrite writes. Scanning the whole file
# instead makes a body line that happens to read "id:" decide that a directory
# is pending, and the rewrite then cannot touch it — a rename with no
# frontmatter change behind it. The opening line must be exactly "---": a CRLF
# "---\r" is not a frontmatter open here, so such a file is simply not pending,
# which is the fail-safe direction. Mirrors the issue-side realizer.
field_value() {
  awk -v f="$2" '
    NR == 1 { if ($0 != "---") exit; fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, f ":") == 1 {
      v = substr($0, length(f) + 2)
      sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
      sub(/^"/, "", v); sub(/"$/, "", v)
      print v; exit
    }
  ' "$1" 2>/dev/null
}

# is_prov_identity <name>
#   Exit 0 iff <name> is the reserved provisional ordinal form the allocator
#   issues: the prefix, then an 8-digit issuance date, then a slug, the whole
#   token through jimfile.sh's id boundary. The full grammar is checked here,
#   not just the prefix, so a malformed directory is skipped with a warning
#   instead of halting the batch when the allocator rejects it.
is_prov_identity() {
  local name="$1" body date slug
  [[ "$name" == "$PROV_PREFIX"* ]] || return 1
  body="${name#"$PROV_PREFIX"}"
  [[ -n "$body" ]] || return 1
  date="${body%%-*}"; slug="${body#*-}"
  [[ "$date" =~ ^[0-9]{8}$ ]] || return 1
  [[ -n "$slug" && "$slug" != "$body" ]] || return 1
  jf valid-id "$body" >/dev/null 2>&1
}

# scan_pending <specs_dir> — emit one row per pending provisional spec dir:
# "<group>/<basename>\t<dir>". A directory qualifies only when its basename is
# the reserved form AND its own spec.md frontmatter claims that same identity;
# anything else warns on stderr and is skipped, never fed to the allocator and
# never composed into a path.
scan_pending() {
  local root="$1" gdir group entry base specmd id
  for gdir in "$root"/*/; do
    [[ -d "$gdir" ]] || continue
    group="$(basename "$gdir")"
    if ! jf valid-id "$group" >/dev/null 2>&1; then
      echo "warning: $group — group name failed validation; skipped" >&2
      continue
    fi
    for entry in "$gdir$PROV_PREFIX"*/; do
      [[ -d "$entry" ]] || continue
      base="$(basename "$entry")"
      if ! is_prov_identity "$base"; then
        echo "warning: $group/$base — not a provisional identity the allocator issues; skipped" >&2
        continue
      fi
      specmd="${entry%/}/spec.md"
      if [[ ! -f "$specmd" ]]; then
        echo "warning: $group/$base — no spec.md to corroborate the identity; skipped" >&2
        continue
      fi
      id="$(field_value "$specmd" id)"
      if [[ "$id" != "$base" ]]; then
        echo "warning: $group/$base — frontmatter id '$id' disagrees with the directory; skipped" >&2
        continue
      fi
      printf '%s/%s\t%s\n' "$group" "$base" "${entry%/}"
    done
  done
}

# realize_mapping <apply-flag> <pending-rows> — feed the pending identities to
# `jimalloc.sh reconcile spec` (preview or --apply per <apply-flag>) and print
# its mapping verbatim, all three fields. The rows carry identities scan_pending
# already validated; this composes no path from them, only the stdin the
# allocator expects.
realize_mapping() {
  local apply="$1" rows="$2" ids
  [[ -n "$rows" ]] || return 0
  ids="$(printf '%s\n' "$rows" | cut -f1)"
  if (( apply )); then
    printf '%s\n' "$ids" | ja reconcile spec --apply
  else
    printf '%s\n' "$ids" | ja reconcile spec
  fi
}

# is_tracked <path> — exit 0 iff git already tracks <path>. The path is handed
# to git literally, so pathspec magic is never interpreted.
is_tracked() {
  [[ -n "$(git --literal-pathspecs ls-files -- "$1" 2>/dev/null)" ]]
}

# rewrite_id <file> <new-id> — print <file> with the id: field inside its leading
# frontmatter block replaced by <new-id>. A body line that happens to read "id:"
# sits outside that block and is never matched — the same region field_value
# reads.
#
# rc 0 when the field was actually replaced, rc 1 when it was not: a rewrite that
# changed nothing, behind a directory this run just renamed, is that identity's
# failure and not a silent success.
rewrite_id() {
  local file="$1" newid="$2"
  awk -v n="$newid" '
    NR == 1 && $0 == "---" { fm = 1; print; next }
    NR == 1                { nofm = 1 }
    !nofm && fm == 1 && $0 == "---" { fm = 2 }
    !nofm && fm == 1 && index($0, "id:") == 1 && !done {
      print "id: \"" n "\""; done = 1; next
    }
    { print }
    END { exit (done ? 0 : 1) }
  ' "$file"
}

# apply_pending <specs_dir> <pending-rows> <mapping>
#   Rename each realized identity's directory onto its ordinal and rewrite the
#   spec's frontmatter id. The rename is history-continuous when the directory
#   is already tracked (git mv, through the sibling-constrained ledger verb) and
#   a plain move when it is not, so realization never asks the developer to
#   change when they commit.
#
#   An identity halts — loudly, with nothing applied for it, and the whole run
#   ending non-zero — when the realized ordinal is not one a spec directory can
#   carry, when that ordinal is already held by a directory in the group, or
#   when the allocator answered under a different group than the identity was
#   issued under. The ordinal comes from a push-writable coordination point, so
#   it is revalidated before it becomes a path, a glob, a git argument, or
#   frontmatter. The latter two are registry-vs-tree drift, and a spec ordinal is
#   path identity: there is no silent suffixing and no overwrite, and repairing
#   the drift is not this script's business. Other identities in the batch are
#   unaffected — their ordinals are already durable.
#
#   Prints one "REALIZED <identity> <dir>" line per directory renamed.
apply_pending() {
  local root="$1" rows="$2" mapping="$3"
  local pend dir real group base body slug ord target held held_rc spec tmp
  local failed=0
  while IFS=$'\t' read -r pend dir; do
    [[ -n "$pend" ]] || continue
    real="$(awk -F'\t' -v k="$pend" '$1==k{print $2; exit}' <<<"$mapping")"
    [[ -n "$real" ]] || continue
    group="${pend%/*}"; base="${pend##*/}"
    if [[ "${real%/*}" != "$group" ]]; then
      echo "error: $pend — the registry answers under group '${real%/*}'; a group renamed since issuance is not a rename this step can follow" >&2
      failed=1; continue
    fi
    ord="${real##*/}"
    # The realized ordinal is registry-derived, and the coordination branch is
    # push-writable — so it crosses the id boundary like every other untrusted
    # token, BEFORE it becomes a path component, a glob, a git argument, or
    # frontmatter. A non-conforming ordinal halts this identity and writes
    # nothing for it.
    if [[ ! "$ord" =~ ^[0-9]{3,15}$ ]]; then
      echo "error: $pend — the registry answers with ordinal '$ord', which is not an ordinal a spec directory can carry; nothing applied for this identity" >&2
      failed=1; continue
    fi
    body="${base#"$PROV_PREFIX"}"
    slug="${body#*-}"
    target="$root/$group/$ord-$slug"
    # Occupancy through the same predicate the rename verbs enforce, so the
    # realize path and the creation path cannot disagree about what an ordinal
    # is. The tracked branch needs it here in its own right: rename-tracked
    # gates the new basename's shape, not the ordinal's occupancy.
    held="$(jf spec-ordinal-holder "$group" "$ord")"; held_rc=$?
    if (( held_rc == 0 )); then
      echo "error: $pend — realized ordinal $real is already held by '$held' (registry-vs-tree drift); nothing applied for this identity" >&2
      failed=1; continue
    fi
    if (( held_rc != 1 )); then
      echo "error: $pend — could not decide whether ordinal $real is free; nothing applied for this identity" >&2
      failed=1; continue
    fi
    if is_tracked "$dir"; then
      if ! bash "$JIMLEDGER" rename-tracked "$dir" "$target"; then
        echo "error: $pend — tracked rename to '$target' failed" >&2
        failed=1; continue
      fi
    else
      if ! jf mv-spec-id "$group" "$base" "$ord" "$slug" >/dev/null; then
        echo "error: $pend — rename to '$target' failed" >&2
        failed=1; continue
      fi
    fi
    spec="$target/spec.md"
    if [[ -f "$spec" ]]; then
      if ! tmp="$(mktemp "$target/.reconcile.tmp.XXXXXX")"; then
        echo "error: cannot create tmp file in '$target'" >&2
        failed=1; continue
      fi
      if rewrite_id "$spec" "$ord" > "$tmp" && mv "$tmp" "$spec"; then
        :
      else
        rm -f "$tmp"
        echo "error: $pend — frontmatter rewrite failed for '$spec'" >&2
        failed=1; continue
      fi
    fi
    printf 'REALIZED %s %s\n' "$pend" "$target"
  done <<<"$rows"
  return "$failed"
}

# build_remap <applied-lines> <mapping>
#   Turn the identities apply_pending actually renamed into the sweep's
#   whitelist, one row per identity:
#     "<group>/P-<token>\t<group>/<NNN>\t<group>/<NNN>-<slug>"
#   the second field being how the identity is written as a typed reference and
#   the third how it is written inside a path. An identity that halted is
#   absent, so the sweep cannot rewrite a citation of a spec that did not move.
build_remap() {
  local applied="$1" mapping="$2"
  local pend real ord slug body
  [[ -n "$applied" ]] || return 0
  while read -r _ pend _; do
    [[ -n "$pend" ]] || continue
    real="$(awk -F'\t' -v k="$pend" '$1==k{print $2; exit}' <<<"$mapping")"
    [[ -n "$real" ]] || continue
    ord="${real##*/}"
    body="${pend##*/}"; body="${body#"$PROV_PREFIX"}"
    slug="${body#*-}"
    printf '%s\t%s\t%s-%s\n' "$pend" "$real" "$real" "$slug"
  done <<<"$applied"
}

# sweep_citations <remap-rows>
#   Rewrite in-tree citations of each realized identity across the four roots a
#   citation can live in — specs, issues, brainstorms, debug — over the tracked
#   markdown in each. The remap IS the whitelist: only an identity that actually
#   moved is ever rewritten, so a reference to an unrelated spec cannot be
#   touched by construction.
#
#   The match is whole-token: the character before the identity is not
#   [a-z0-9-] and the character after is not [a-z0-9-] either. Excluding the
#   trailing dash matters here in a way it does not for a real ordinal — two
#   specs scoped the same day under the same title differ only by a "-2" suffix,
#   and the shorter identity must not match inside the longer one.
#
#   How an identity is written decides what replaces it: preceded by a slash it
#   is part of a path and takes the realized directory name, slug included;
#   anywhere else it is a typed reference and takes the bare ordinal. Fenced
#   blocks are skipped — a citation quoted inside one is verbatim material, not
#   a live reference.
#
#   Guards run over EVERY target before ANY edit: each path clears the relpath
#   boundary and resolves inside the worktree. Output is location-only — file,
#   line, and which form matched — never the content of the line. The issue
#   index is regenerated once, and only when an issue file actually changed; a
#   regeneration that fails is reported and fails the sweep, since the citations
#   are already rewritten and INDEX.md no longer describes them.
sweep_citations() {
  local remap="$1"
  [[ -n "$remap" ]] || return 0
  local top
  if ! top="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$top" ]]; then
    echo "error: citation sweep — not in a git repo" >&2
    return 1
  fi
  local -a roots=() files=()
  local key root issues_root=""
  for key in specs issues brainstorms debug; do
    root="$(jc get "$key" 2>/dev/null)"; root="${root%/}"; root="${root#./}"
    [[ -n "$root" ]] || continue
    roots+=("$root")
    [[ "$key" == issues ]] && issues_root="$root"
  done
  (( ${#roots[@]} )) || return 0
  mapfile -t files < <(git --literal-pathspecs ls-files -- "${roots[@]}" 2>/dev/null | grep -E '\.md$')
  (( ${#files[@]} )) || return 0

  local f resolved
  for f in "${files[@]}"; do
    if ! jf valid-relpath "$f" >/dev/null 2>&1; then
      echo "error: citation sweep — unsafe path rejected: $f" >&2; return 1
    fi
    if ! resolved="$(realpath -m -- "$f" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "error: citation sweep — path escapes worktree: $f" >&2; return 1
    fi
  done

  local swtmp parsed tmp_out rec issue_touched=0
  if ! swtmp="$(mktemp -d 2>/dev/null)"; then
    echo "error: citation sweep — cannot create temp dir" >&2; return 1
  fi
  parsed="$swtmp/remap"; tmp_out="$swtmp/out"; rec="$swtmp/rec"
  printf '%s\n' "$remap" > "$parsed"
  for f in "${files[@]}"; do
    : > "$rec"
    awk -F'\t' -v file="$f" -v recfile="$rec" '
      BEGIN { rf = ARGV[1] }
      FILENAME == rf { SRC[FNR] = $1; TYPED[FNR] = $2; PATHED[FNR] = $3; nmap = FNR; next }
      {
        line = $0
        if (line ~ /^[[:space:]]*(```|~~~)/) { fence = !fence; print; next }
        if (fence) { print; next }
        out = ""; i = 1; L = length(line)
        while (i <= L) {
          matched = 0
          for (m = 1; m <= nmap; m++) {
            s = SRC[m]; sl = length(s)
            if (substr(line, i, sl) == s) {
              before = (i > 1) ? substr(line, i - 1, 1) : ""
              ap = i + sl; after = (ap <= L) ? substr(line, ap, 1) : ""
              if (before !~ /[a-z0-9-]/ && after !~ /[a-z0-9-]/) {
                if (before == "/") {
                  out = out PATHED[m]
                  print "REWROTE\t" file "\t" FNR "\tpath" > recfile
                } else {
                  out = out TYPED[m]
                  print "REWROTE\t" file "\t" FNR "\ttyped-ref" > recfile
                }
                i += sl; matched = 1; break
              }
            }
          }
          if (!matched) { out = out substr(line, i, 1); i++ }
        }
        print out
      }' "$parsed" "$f" > "$tmp_out"
    if [[ -s "$rec" ]]; then
      cat -- "$tmp_out" > "$f"
      cat -- "$rec"
      [[ -n "$issues_root" && "$f" == "$issues_root"/* ]] && issue_touched=1
    fi
  done
  rm -rf -- "$swtmp"

  if (( issue_touched )); then
    if ! bash "$HERE/../../issue/scripts/index.sh" "$issues_root" >/dev/null 2>&1; then
      echo "error: citation sweep — the issue index failed to regenerate for '$issues_root'; the rewritten citations are on disk and INDEX.md no longer describes them" >&2
      return 1
    fi
  fi
  return 0
}

# record_realized <specs_dir> <remap-rows>
#   Append one `spec realized` event to the SPECS-ROOT ledger carrying the
#   provisional→real mapping in the same moved= grammar the partition operations
#   use. Recording it durably is what lets a citation frozen while the spec was
#   provisional stay traceable, and lets the rename-emitting follow-on lift the
#   mapping into registry redirect records without re-deriving anything.
#
#   Every element is charset-gated immediately before it is appended. The ledger
#   append writes whatever it is handed, so composing the value out of tokens
#   re-checked at this boundary is what keeps a crafted directory name from
#   reaching the record. The mapping is chunked at element boundaries rather
#   than truncated, so a large batch stays wholly recorded.
#
#   This grammar is NARROWER than the scan's id boundary, so a row can arrive
#   here already renamed and still be unrecordable. That row is dropped from the
#   record — but loudly, naming the mapping and failing the run: the durable
#   record is what keeps a citation frozen while the spec was provisional
#   traceable, so losing one silently at exit 0 is the wrong failure mode. Other
#   rows in the batch record normally.
#
#   The phase token sits outside the measured stage set on purpose — realization
#   is not a stage. It is inert to the vacated-id floor too, which reads only
#   split and merge events: a provisional never held a real ordinal, so it
#   vacates nothing and no floor may rise because of it.
record_realized() {
  local root="$1" remap="$2"
  [[ -n "$remap" ]] || return 0
  local pend real elem cand cur="" failed=0
  local -a tokens=()
  while IFS=$'\t' read -r pend real _; do
    [[ -n "$pend" && -n "$real" ]] || continue
    if [[ ! "$pend" =~ ^[a-z0-9][a-z0-9-]*/P-[0-9]{8}-[a-z0-9][a-z0-9-]*$ ]] \
       || [[ ! "$real" =~ ^[a-z0-9][a-z0-9-]*/[0-9]{3,15}$ ]]; then
      echo "warning: $pend → $real — the mapping does not clear the record boundary; this realization is NOT in the durable record" >&2
      failed=1; continue
    fi
    elem="$pend:$real"
    if [[ -z "$cur" ]]; then cand="moved=$elem"; else cand="$cur,$elem"; fi
    if (( ${#cand} > 256 )) && [[ -n "$cur" ]]; then
      tokens+=("$cur")
      cur="moved=$elem"
    else
      cur="$cand"
    fi
  done <<<"$remap"
  [[ -n "$cur" ]] && tokens+=("$cur")
  (( ${#tokens[@]} )) || return "$failed"
  bash "$JIMLEDGER" event "$root" spec realized "${tokens[@]}" || failed=1
  return "$failed"
}

cmd_reconcile() {
  local dir="" apply=0
  while (( $# )); do
    case "$1" in
      --apply) apply=1; shift ;;
      -*) echo "error: unknown option '$1'" >&2; return 2 ;;
      *)  dir="$1"; shift ;;
    esac
  done
  dir="$(resolve_specs_dir "$dir")" || return $?
  if [[ ! -d "$dir" ]]; then
    printf 'reconcile: no pending provisional specs — nothing to realize.\n'
    return 0
  fi

  local rows
  rows="$(scan_pending "$dir")"
  if [[ -z "$rows" ]]; then
    printf 'reconcile: no pending provisional specs — nothing to realize.\n'
    return 0
  fi

  # The uncommitted-case rename composes its target from the CONFIGURED specs
  # dir, so applying into a tree other than the one just scanned would move a
  # directory nobody asked about. Refuse rather than guess.
  if (( apply )); then
    local cfg_dir
    cfg_dir="$(jc get specs 2>/dev/null)"; cfg_dir="${cfg_dir%/}"
    if [[ "$(realpath -m -- "$cfg_dir" 2>/dev/null)" != "$(realpath -m -- "$dir" 2>/dev/null)" ]]; then
      echo "error: --apply operates on the configured specs dir ('$cfg_dir'), not '$dir'" >&2
      return 1
    fi
  fi

  local mapping rc
  mapping="$(realize_mapping "$apply" "$rows")"; rc=$?
  (( rc == 0 )) || return "$rc"

  if [[ -z "$mapping" ]]; then
    printf 'reconcile: still offline — nothing changed.\n'
    return 0
  fi

  if (( apply )); then
    printf 'reconcile — %s\n\n' "$dir"
    printf '%s\n' "$mapping" | sed 's/^/  /'
    printf '\n'
    local applied arc remap
    applied="$(apply_pending "$dir" "$rows" "$mapping")"; arc=$?
    [[ -n "$applied" ]] && printf '%s\n' "$applied"
    remap="$(build_remap "$applied" "$mapping")"
    sweep_citations "$remap" || arc=1
    record_realized "$dir" "$remap" || arc=1
    return "$arc"
  fi

  printf 'reconcile preview — %s\n\n' "$dir"
  printf '%s\n' "$mapping" | sed 's/^/  /'
  printf '\n%d pending.\n' "$(printf '%s\n' "$rows" | grep -c .)"
}

usage() {
  printf '%s\n' \
    'reconcile.sh — realize pending provisional spec identities into real ordinals.' \
    '' \
    '  bash reconcile.sh [<specs_dir>]' \
    '      Preview (read-only): list pending provisional identities and the real' \
    '      ordinal each would take. Mutates nothing.' \
    '' \
    '  bash reconcile.sh --apply [<specs_dir>]' \
    '      Apply: realize through the allocator, rename each directory onto its' \
    '      ordinal, and rewrite the frontmatter id.' \
    '' \
    '  specs_dir default: jimconf.sh get specs'
}

main() {
  if [[ "${1:-}" == "-c" ]]; then
    [[ -n "${2:-}" ]] || { echo "error: -c requires a path argument" >&2; return 2; }
    CFG="$2"; shift 2
  fi
  case "${1:-}" in
    -h|--help|help) usage ;;
    *) cmd_reconcile "$@" ;;
  esac
}

main "$@"
