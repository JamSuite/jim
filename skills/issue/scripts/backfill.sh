#!/usr/bin/env bash
#
# skills/issue/scripts/backfill.sh — one-shot, opt-in migrations that fill in
# missing issue data: `num` display ordinals (spec 019) and `created`/`updated`
# second-resolution timestamps (spec 022). Subcommands: `num`, `timestamp`.
#
# PURPOSE
#   Assign a `num:` display ordinal to every issue file that lacks one,
#   in `created:`-ascending order, continuing from the collection's current
#   max ordinal. This is a ONE-TIME migration for the spec 019 `num:` field
#   change — it is NOT wired into the /jim:issue verb flow. New issues get
#   their ordinal at creation (jimfile.sh next-num issue); this script only
#   numbers the legacy collection, once, up-front (before normal use), so
#   ordinals stay ascending with creation.
#
#   Each file is rewritten via a per-file atomic tmp + mv so a partial run
#   never corrupts an issue file; the migration is idempotent, so a retry
#   completes any unfinished work. All other file content is preserved —
#   `num:` is inserted as the first frontmatter field, nothing else changes.
#   Line-oriented only; never `source`/`eval`s an issue file.
#
# CLI SUMMARY
#   bash backfill.sh
#     No subcommand: print help/usage listing the subcommands.
#   bash backfill.sh num [<issues_dir>]
#     Assign a `num:` display ordinal to every issue lacking one, in
#     created-ascending order. Prints "Assigned display numbers to N issue(s)."
#     iff N>0; otherwise silent (idempotent no-op). (spec 019)
#   bash backfill.sh timestamp [<issues_dir>]
#     Rewrite date-only created/updated to YYYY-MM-DDT00:00:00Z (a day-start
#     placeholder, not a recovered time), atomically per file. Idempotent —
#     already-timestamped values untouched; malformed values skipped with a
#     warning. Prints "Normalized N issue(s) ..." iff N>0; else silent. (spec 022)
#   issues_dir default: jimconf.sh get issues
#
# EXIT CODES
#   0  Success (including the no-op and help cases).
#   1  IO failure (cannot write tmp, atomic rename failed).
#   2  Malformed invocation (unknown subcommand, empty issues_dir).
#

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
readonly INDEX_FILENAME="INDEX.md"

# resolve_dir <arg> — arg if non-empty, else jimconf default; strip trailing /.
resolve_dir() {
  local dir="${1:-}"
  [[ -z "$dir" ]] && dir="$(bash "$JIMCONF" get issues 2>/dev/null)"
  dir="${dir%/}"
  if [[ -z "$dir" ]]; then
    echo "error: issues_dir is empty" >&2
    return 2
  fi
  printf '%s\n' "$dir"
}

# field_value <file> <field> — top-level scalar value, quotes stripped, or empty.
field_value() {
  grep -E "^$2:" "$1" 2>/dev/null \
    | head -n 1 \
    | sed -E "s/^$2:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"
}

# num_of <file> — the file's num: value, or empty.
num_of() {
  grep -E '^num:[[:space:]]*[0-9]+' "$1" 2>/dev/null \
    | head -n 1 | sed -E 's/^num:[[:space:]]*([0-9]+).*/\1/'
}

# normalize_ts <value> <file> <field> — echo the canonical form of a
# created/updated value:
#   - date-only YYYY-MM-DD      -> YYYY-MM-DDT00:00:00Z (day-start placeholder)
#   - already a full timestamp  -> unchanged (idempotent)
#   - empty                     -> unchanged
#   - malformed (anything else) -> unchanged + a warning on stderr (skip)
# SYNC(ts-shape): ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$
normalize_ts() {
  local v="$1" file="$2" field="$3"
  if [[ -z "$v" ]]; then printf '%s' "$v"; return 0; fi
  if [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf '%s' "${v}T00:00:00Z"
  elif [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    printf '%s' "$v"
  else
    echo "warning: $(basename "$file") $field is not a valid date or timestamp; left unchanged" >&2
    printf '%s' "$v"
  fi
}

cmd_assign_numbers() {
  local dir
  dir="$(resolve_dir "${1:-}")" || return $?
  [[ -d "$dir" ]] || return 0

  # Current max ordinal across the collection.
  local max=0 f n base
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" == "$INDEX_FILENAME" ]] && continue
    n="$(num_of "$f")"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( n > max )) && max=$n
  done

  # Collect un-numbered issues as "<created>\t<file>" for stable ordering.
  local list="" created
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    [[ -n "$(num_of "$f")" ]] && continue
    created="$(field_value "$f" created)"
    list+="$created"$'\t'"$f"$'\n'
  done

  [[ -z "$list" ]] && return 0

  # Assign in created-ascending order (path as tie-break), continuing from max.
  local assigned=0 next=$(( max + 1 )) createdkey file tmp
  while IFS=$'\t' read -r createdkey file; do
    [[ -z "$file" ]] && continue
    tmp="$(mktemp "$dir/.backfill.tmp.XXXXXX")" || {
      echo "error: cannot create tmp file in '$dir'" >&2
      return 1
    }
    if awk -v n="$next" '
      BEGIN { inserted = 0 }
      /^---$/ && inserted == 0 { print; print "num: " n; inserted = 1; next }
      { print }
    ' "$file" > "$tmp"; then
      mv "$tmp" "$file" || {
        rm -f "$tmp"
        echo "error: atomic rename failed for '$file'" >&2
        return 1
      }
    else
      rm -f "$tmp"
      echo "error: rewrite failed for '$file'" >&2
      return 1
    fi
    next=$(( next + 1 ))
    assigned=$(( assigned + 1 ))
  done < <(printf '%s' "$list" | sort -t$'\t' -k1,1 -k2,2)

  if (( assigned > 0 )); then
    printf 'Assigned display numbers to %d issue(s).\n' "$assigned"
  fi
  return 0
}

cmd_timestamp() {
  local dir
  dir="$(resolve_dir "${1:-}")" || return $?
  [[ -d "$dir" ]] || return 0

  local normalized=0 f base tmp cval uval new_c new_u wr_c wr_u
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue

    cval="$(field_value "$f" created)"
    uval="$(field_value "$f" updated)"
    new_c="$(normalize_ts "$cval" "$f" created)"
    new_u="$(normalize_ts "$uval" "$f" updated)"
    [[ "$new_c" == "$cval" && "$new_u" == "$uval" ]] && continue

    tmp="$(mktemp "$dir/.normalize.tmp.XXXXXX")" || {
      echo "error: cannot create tmp file in '$dir'" >&2
      return 1
    }
    # Rewrite only a field whose canonical form normalize_ts actually minted, so
    # the sole value this writes is one it produced itself. A malformed value is
    # returned unchanged, and the skip above fires only when NEITHER field
    # changed — so a file with one normalizable field and one malformed one is
    # rewritten, and reprinting the malformed one puts issue-file text back
    # through the writer for no gain.
    #
    # The values reach awk through the environment rather than `awk -v`, which
    # processes its operand as a string literal and expands escape sequences: a
    # literal backslash-n in an untrusted created/updated would become a real
    # newline, and an issue's own field text would open a second frontmatter
    # pair. Two independent guards, because the first one rests on a contract
    # normalize_ts states and this loop cannot see.
    wr_c=""; wr_u=""
    [[ "$new_c" != "$cval" ]] && wr_c=1
    [[ "$new_u" != "$uval" ]] && wr_u=1
    if c="$new_c" u="$new_u" wr_c="$wr_c" wr_u="$wr_u" awk '
      /^---$/ { fm++; print; next }
      fm == 1 && /^created:/ && !cdone && ENVIRON["wr_c"] != "" {
        print "created: " ENVIRON["c"]; cdone = 1; next }
      fm == 1 && /^updated:/ && !udone && ENVIRON["wr_u"] != "" {
        print "updated: " ENVIRON["u"]; udone = 1; next }
      { print }
    ' "$f" > "$tmp"; then
      mv "$tmp" "$f" || {
        rm -f "$tmp"
        echo "error: atomic rename failed for '$f'" >&2
        return 1
      }
    else
      rm -f "$tmp"
      echo "error: rewrite failed for '$f'" >&2
      return 1
    fi
    normalized=$(( normalized + 1 ))
  done

  if (( normalized > 0 )); then
    printf 'Normalized %d issue(s) to canonical timestamps. Note: legacy date-only values were set to day-start (T00:00:00Z) — a format placeholder, not a recovered time.\n' "$normalized"
  fi
  return 0
}

usage() {
  printf '%s\n' \
    'backfill.sh — one-shot, opt-in migrations that fill in missing issue data.' \
    '' \
    '  bash backfill.sh num [<issues_dir>]' \
    '      Assign a display `num:` ordinal to every issue lacking one, in' \
    '      created-ascending order. Idempotent; announces a count iff any.' \
    '' \
    '  bash backfill.sh timestamp [<issues_dir>]' \
    '      Rewrite legacy date-only created/updated to a day-start UTC timestamp' \
    '      (YYYY-MM-DDT00:00:00Z placeholder). Idempotent; announces a count iff any.' \
    '' \
    '  issues_dir default: jimconf.sh get issues'
}

# route_placement <place-token> <args...>
#   Re-exec through place.sh when the project keeps its collection on a
#   designated branch, so a backfill rewrites the issues there rather than on
#   whatever branch the developer is standing on. An explicit directory argument
#   opts out, which is also what stops the re-exec recursing. Both subcommands
#   write, so there is no preview form to route read-only.
route_placement() {
  local token="$1"; shift
  local place="$HERE/place.sh" mode arg dir=""
  [[ -r "$place" ]] || return 0
  for arg in "$@"; do
    case "$arg" in
      num|timestamp|-*) ;;
      *)                dir="$arg" ;;
    esac
  done
  [[ -z "$dir" ]] || return 0
  mode="$(bash "$place" mode --place-token "$token")" || exit $?
  [[ "$mode" == "route" ]] || return 0
  exec bash "$place" run --verb backfill -- \
    bash "${BASH_SOURCE[0]}" --place-token '{token}' "$@" '{}'
}

main() {
  local place_token=""
  if [[ "${1:-}" == "--place-token" ]]; then
    place_token="${2:-}"
    shift 2
  fi
  case "${1:-}" in
    num|timestamp) route_placement "$place_token" "$@" ;;
  esac
  case "${1:-}" in
    num)               shift; cmd_assign_numbers "$@" ;;
    timestamp)         shift; cmd_timestamp "$@" ;;
    ""|-h|--help|help) usage ;;
    *)
      echo "error: unknown subcommand '$1' (expected: num | timestamp)" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
