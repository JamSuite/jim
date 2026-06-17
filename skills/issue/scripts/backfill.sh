#!/usr/bin/env bash
#
# skills/issue/scripts/backfill.sh — one-shot display-ordinal migration.
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
#   bash backfill.sh [<issues_dir>]
#     issues_dir default: jimconf.sh get issues
#     Prints "Assigned display numbers to N issue(s)." iff N>0; otherwise
#     silent (idempotent no-op when every issue already has a num).
#
# EXIT CODES
#   0  Success (including the no-op case).
#   1  IO failure (cannot write tmp, atomic rename failed).
#   2  Malformed invocation (empty issues_dir).
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

main() {
  cmd_assign_numbers "$@"
}

main "$@"
