#!/usr/bin/env bash
#
# skills/issue/scripts/reconcile.sh — realize pending provisional issue
#   ordinals into real, coordinated ones. One-shot, previewed migration in
#   the backfill.sh / migrate.sh family — it does not run automatically; a
#   developer invokes it explicitly, typically after a provisional filing
#   reconnects to the coordination point.
#
# PURPOSE
#   Scan an issues directory for files whose num: field is a provisional
#   marker (P-<id>), feed each such file's durable id — read from its own
#   id: frontmatter field, revalidated through jimfile.sh's id boundary
#   before it ever reaches jimalloc.sh or a composed path (the coordination
#   branch is push-writable, so a frontmatter field is just as untrusted as
#   any other registry-adjacent input) — to jimalloc.sh reconcile issue, and
#   report the provisional -> real ordinal mapping it computes.
#
#   --apply publishes the realization through the allocator and rewrites
#   each affected file's num: field, anchored to the leading frontmatter
#   block only (a body line that happens to read "num:" is never touched),
#   atomically (tmp + mv), then regenerates INDEX.md once. Realization is
#   idempotent — jimalloc.sh's own reconcile issue maps an already-realized
#   identity to its existing ordinal, never a second one.
#
#   A pending file whose frontmatter id fails validation is skipped (a
#   warning on stderr) and excluded from the set fed to jimalloc.sh — it is
#   never composed into a path or a stdin line.
#
# CLI SUMMARY
#   bash reconcile.sh [<issues_dir>]
#     PREVIEW (read-only): list pending provisionals and their would-be real
#     ordinal. Mutates nothing.
#   bash reconcile.sh --apply [<issues_dir>]
#     APPLY: realize + rewrite num: (tmp + mv) + regenerate INDEX once.
#   bash reconcile.sh -c <config> [...]
#     Forward -c to jimfile.sh / jimconf.sh / jimalloc.sh (used by tests).
#   issues_dir default: jimconf.sh get issues
#
# EXIT CODES
#   0  Success (including the nothing-pending no-op).
#   1  IO failure, a failed index regeneration after the realization landed, or
#      jimalloc.sh reconcile issue halts (a within-batch duplicate identity or a
#      boundary-invalid pending id).
#   2  Malformed invocation (unknown option).
#
# Line-oriented only; never source/evals an issue file.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
JIMALLOC="$(dirname "$JIMFILE")/jimalloc.sh"
readonly INDEX_FILENAME="INDEX.md"
CFG=""   # optional jimconf override path, forwarded to jimfile/jimconf/jimalloc

# jf / jc / ja <args...> — invoke jimfile.sh / jimconf.sh / jimalloc.sh,
# forwarding -c when set.
jf() { if [[ -n "$CFG" ]]; then bash "$JIMFILE" -c "$CFG" "$@"; else bash "$JIMFILE" "$@"; fi; }
jc() { if [[ -n "$CFG" ]]; then bash "$JIMCONF" -c "$CFG" "$@"; else bash "$JIMCONF" "$@"; fi; }
ja() { if [[ -n "$CFG" ]]; then bash "$JIMALLOC" -c "$CFG" "$@"; else bash "$JIMALLOC" "$@"; fi; }

# resolve_dir <arg> — arg if non-empty, else jimconf default; strip trailing /.
resolve_dir() {
  local dir="${1:-}"
  [[ -z "$dir" ]] && dir="$(jc get issues 2>/dev/null)"
  dir="${dir%/}"
  if [[ -z "$dir" ]]; then
    echo "error: issues_dir is empty" >&2
    return 2
  fi
  printf '%s\n' "$dir"
}

# field_value <file> <field> — the value of <field> inside the file's LEADING
# frontmatter block, quotes stripped; empty when there is no leading block or it
# does not carry the field.
#
# Detection reads the SAME region the rewrite writes. Scanning the whole file
# instead makes a body line that happens to read "num:" decide that a file is
# pending, and the rewrite then cannot touch it — a realization reported with
# nothing behind it. The opening line must be exactly "---": a CRLF "---\r" is
# not a frontmatter open here, so such a file is simply not pending, which is
# the fail-safe direction. Mirrors the spec-side realizer.
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

# scan_pending <dir> — emit one row per pending provisional issue file:
# <durable-id>\t<file>. A file's num: field marks it pending when it starts
# with "P-"; the durable id is then read from that SAME file's own id:
# frontmatter field and revalidated through jimfile.sh's id boundary before
# it is ever fed to jimalloc.sh or used as a path component (security
# Finding 5) — a file whose frontmatter id fails that check is skipped with
# a warning, never included in the pending set.
scan_pending() {
  local dir="$1" f base num id
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    num="$(field_value "$f" num)"
    [[ "$num" == P-* ]] || continue
    id="$(field_value "$f" id)"
    if ! jf valid-id "$id" >/dev/null 2>&1; then
      echo "warning: $base — frontmatter id '$id' failed validation; skipped" >&2
      continue
    fi
    printf '%s\t%s\n' "$id" "$f"
  done
}

# realize_mapping <apply-flag> <pending-rows> — feed the pending durable ids
# to jimalloc.sh reconcile issue (preview or --apply per <apply-flag>) and
# print its provisional -> real mapping verbatim ("<id>\t<ordinal>" per
# line). <pending-rows> already carry ids scan_pending validated; this
# function composes no path from them, only the stdin jimalloc.sh expects.
realize_mapping() {
  local apply="$1" rows="$2" ids
  [[ -n "$rows" ]] || return 0
  ids="$(printf '%s\n' "$rows" | cut -f1)"
  if (( apply )); then
    printf '%s\n' "$ids" | ja reconcile issue --apply
  else
    printf '%s\n' "$ids" | ja reconcile issue
  fi
}

# rewrite_num <file> <new-num> — print <file> with the num: field inside its
# leading frontmatter block replaced by <new-num>. A body line that happens to
# read "num:" sits outside that block and is never matched — the same region
# field_value reads.
#
# rc 0 when the field was actually replaced, rc 1 when it was not: a rewrite that
# changed nothing, behind a realization this run already published, is that
# file's failure and not a silent success.
rewrite_num() {
  local file="$1" newnum="$2"
  awk -v n="$newnum" '
    NR == 1 && $0 == "---" { fm = 1; print; next }
    NR == 1                { nofm = 1 }
    !nofm && fm == 1 && $0 == "---" { fm = 2 }
    !nofm && fm == 1 && index($0, "num:") == 1 && !done {
      print "num: " n; done = 1; next
    }
    { print }
    END { exit (done ? 0 : 1) }
  ' "$file"
}

# apply_pending <dir> <pending-rows> <mapping> — rewrite each pending file's
# num: to its realized ordinal, atomically (tmp + mv) per file. Prints the
# count of files rewritten.
#
# A file that fails is reported and the batch continues: every ordinal in the
# mapping is already durably published, so abandoning the rest strands more work
# than it saves and leaves the index describing a state that no longer exists.
# rc 0 all clear · rc 1 at least one file failed, the rest still rewritten.
# Mirrors the spec-side realizer's per-identity semantics.
apply_pending() {
  local dir="$1" rows="$2" mapping="$3"
  local id file newnum tmp realized=0 failed=0
  while IFS=$'\t' read -r id file; do
    [[ -n "$id" ]] || continue
    newnum="$(awk -F'\t' -v k="$id" '$1==k{print $2; exit}' <<<"$mapping")"
    [[ -n "$newnum" ]] || continue
    # A blocked identity maps to '-', never an ordinal: the registry claims its
    # durable id twice and the allocator refused to pick a winner. Loud,
    # per-file, num: left provisional — the rest of the batch still rewrites.
    if [[ ! "$newnum" =~ ^[0-9]+$ ]]; then
      echo "error: $id — the allocator refused this identity (blocked; see its report); num: left provisional" >&2
      failed=1; continue
    fi
    tmp="$(mktemp "$dir/.reconcile.tmp.XXXXXX")" || {
      echo "error: cannot create tmp file in '$dir'" >&2
      failed=1; continue
    }
    if rewrite_num "$file" "$newnum" > "$tmp"; then
      mv "$tmp" "$file" || {
        rm -f "$tmp"
        echo "error: atomic rename failed for '$file'" >&2
        failed=1; continue
      }
    else
      rm -f "$tmp"
      echo "error: rewrite failed for '$file'" >&2
      failed=1; continue
    fi
    realized=$(( realized + 1 ))
  done <<<"$rows"
  printf '%s\n' "$realized"
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
  dir="$(resolve_dir "$dir")" || return $?
  if [[ ! -d "$dir" ]]; then
    printf 'reconcile: no pending provisional issues — nothing to realize.\n'
    return 0
  fi

  local rows
  rows="$(scan_pending "$dir")"
  if [[ -z "$rows" ]]; then
    printf 'reconcile: no pending provisional issues — nothing to realize.\n'
    return 0
  fi

  local mapping rc
  mapping="$(realize_mapping "$apply" "$rows")"; rc=$?
  (( rc == 0 )) || return "$rc"

  if [[ -z "$mapping" ]]; then
    printf 'reconcile: still offline — nothing changed.\n'
    return 0
  fi

  if (( apply )); then
    local realized arc
    # A failure inside the batch is carried, not returned on: the files that DID
    # rewrite have their ordinals on disk, so returning here would skip the
    # regeneration below and leave exactly the stale index it exists to prevent.
    realized="$(apply_pending "$dir" "$rows" "$mapping")"; arc=$?
    # The ordinals are already in the files, so a failed regeneration leaves
    # INDEX.md describing a state that no longer exists. Report it and carry the
    # failure rather than exiting 0 on a stale index.
    if ! bash "$HERE/index.sh" "$dir" >/dev/null 2>&1; then
      echo "error: the issue index failed to regenerate for '$dir'; the realized ordinals are in the files and INDEX.md no longer describes them" >&2
      arc=1
    fi
    printf 'reconcile: realized %s provisional issue(s):\n' "$realized"
    printf '%s\n' "$mapping" | sed 's/^/  /'
    return "$arc"
  else
    printf 'reconcile preview — %s\n\n' "$dir"
    printf '%s\n' "$mapping" | sed 's/^/  /'
    printf '\n%d pending.\n' "$(printf '%s\n' "$rows" | grep -c .)"
  fi
}

usage() {
  printf '%s\n' \
    'reconcile.sh — realize pending provisional issue ordinals into real ones.' \
    '' \
    '  bash reconcile.sh [<issues_dir>]' \
    '      Preview (read-only): list pending provisionals and their would-be' \
    '      real ordinal. Mutates nothing.' \
    '' \
    '  bash reconcile.sh --apply [<issues_dir>]' \
    '      Apply: realize + rewrite num: (tmp + mv) + regenerate INDEX once.' \
    '' \
    '  issues_dir default: jimconf.sh get issues'
}

# route_placement <place-token> <args...>
#   Re-exec through place.sh when the project keeps its collection on a
#   designated branch, so a realization rewrites num: there rather than on
#   whatever branch the developer is standing on. An explicit directory argument
#   opts out, which is also what stops the re-exec recursing.
#
#   A preview routes read-only. Previewing is the default here, and a preview
#   that published would make "mutates nothing" untrue.
route_placement() {
  local token="$1"; shift
  local place="$HERE/place.sh" mode arg dir="" apply=0 skip_next=0
  [[ -r "$place" ]] || return 0
  for arg in "$@"; do
    # A flag's *value* is not a directory argument. Without skipping it, `-c
    # <cfg>` reads as "the caller named a collection", routing is declined, and
    # a realization rewrites the working tree instead of the destination.
    if (( skip_next )); then skip_next=0; continue; fi
    case "$arg" in
      --apply) apply=1 ;;
      -c)      skip_next=1 ;;
      -*)      ;;
      *)       dir="$arg" ;;
    esac
  done
  [[ -z "$dir" ]] || return 0
  mode="$(bash "$place" mode --place-token "$token")" || exit $?
  [[ "$mode" == "route" ]] || return 0
  local -a run=(run)
  if (( apply )); then run+=(--verb realize); else run+=(--read); fi
  # {token} is the fourth word of the command below and {} the last; the
  # wrapper substitutes at those offsets and nowhere else.
  exec bash "$place" "${run[@]}" --token-at 3 --dir-at -1 -- \
    bash "${BASH_SOURCE[0]}" --place-token '{token}' "$@" '{}'
}

main() {
  local place_token=""
  if [[ "${1:-}" == "--place-token" ]]; then
    place_token="${2:-}"
    shift 2
  fi
  case "${1:-}" in
    -h|--help|help) ;;
    *) route_placement "$place_token" "$@" ;;
  esac
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
