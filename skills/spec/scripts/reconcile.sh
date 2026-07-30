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

# field_value <file> <field> — first top-level scalar value, quotes stripped.
# Frontmatter always precedes the body, so the first occurrence of "^field:" in
# the whole file is the frontmatter's — mirrors the issue-side realizer.
field_value() {
  grep -E "^$2:" "$1" 2>/dev/null \
    | head -n 1 \
    | sed -E "s/^$2:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"
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

# realize_mapping <pending-rows> — feed the pending identities to
# `jimalloc.sh reconcile spec` and print its mapping verbatim, all three fields.
# The rows carry identities scan_pending already validated; this composes no
# path from them, only the stdin the allocator expects.
realize_mapping() {
  local rows="$1" ids
  [[ -n "$rows" ]] || return 0
  ids="$(printf '%s\n' "$rows" | cut -f1)"
  printf '%s\n' "$ids" | ja reconcile spec
}

cmd_reconcile() {
  local dir=""
  while (( $# )); do
    case "$1" in
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

  local mapping rc
  mapping="$(realize_mapping "$rows")"; rc=$?
  (( rc == 0 )) || return "$rc"

  if [[ -z "$mapping" ]]; then
    printf 'reconcile: still offline — nothing changed.\n'
    return 0
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
