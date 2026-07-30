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

# rewrite_id <file> <new-id> — print <file> with its FRONTMATTER id: field (the
# first top-level field inside the leading --- block) replaced by <new-id>. A
# body line that happens to read "id:" sits outside that block and is never
# matched.
rewrite_id() {
  local file="$1" newid="$2"
  awk -v n="$newid" '
    /^---$/ { fm++; print; next }
    fm == 1 && /^id:/ && !done { print "id: \"" n "\""; done = 1; next }
    { print }
  ' "$file"
}

# ordinal_holder <specs_dir> <group> <ordinal> — print the directory already
# holding <ordinal> in <group>, if any. Matches the ordinal, not the whole name:
# a spec ordinal is path identity, so another slug on the same ordinal is the
# same collision.
ordinal_holder() {
  local root="$1" group="$2" ord="$3" entry
  for entry in "$root/$group/$ord"-*/ "$root/$group/$ord"/; do
    [[ -d "$entry" ]] || continue
    printf '%s\n' "${entry%/}"
    return 0
  done
  return 1
}

# apply_pending <specs_dir> <pending-rows> <mapping>
#   Rename each realized identity's directory onto its ordinal and rewrite the
#   spec's frontmatter id. The rename is history-continuous when the directory
#   is already tracked (git mv, through the sibling-constrained ledger verb) and
#   a plain move when it is not, so realization never asks the developer to
#   change when they commit.
#
#   An identity halts — loudly, with nothing applied for it, and the whole run
#   ending non-zero — when the realized ordinal is already held by a directory
#   in the group, or when the allocator answered under a different group than
#   the identity was issued under. Both are registry-vs-tree drift, and a spec
#   ordinal is path identity: there is no silent suffixing and no overwrite, and
#   repairing the drift is not this script's business. Other identities in the
#   batch are unaffected — their ordinals are already durable.
#
#   Prints one "REALIZED <identity> <dir>" line per directory renamed.
apply_pending() {
  local root="$1" rows="$2" mapping="$3"
  local pend dir real group base body slug ord target held spec tmp
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
    body="${base#"$PROV_PREFIX"}"
    slug="${body#*-}"
    target="$root/$group/$ord-$slug"
    if held="$(ordinal_holder "$root" "$group" "$ord")"; then
      echo "error: $pend — realized ordinal $real is already held by '$held' (registry-vs-tree drift); nothing applied for this identity" >&2
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
    apply_pending "$dir" "$rows" "$mapping"
    return $?
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
