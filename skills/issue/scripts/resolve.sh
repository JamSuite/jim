#!/usr/bin/env bash
#
# skills/issue/scripts/resolve.sh — Resolve one issue reference to the record
#   it names, and report that record's kind. The single definition of what an
#   ordinal, an exact slug or a slug prefix resolves to on a write path, so a
#   capture and a lifecycle verb cannot disagree about which record a
#   reference points at — the role identity.sh plays for a recorded identity.
#
#   Resolution here is against the collection directory rather than the
#   generated index, because a write path cannot assume an index exists or is
#   current: a batch files an umbrella and then files members into it before
#   anything regenerates one. The read views resolve against the indexed set
#   instead, which is their own guarantee and a different substrate.
#
# SECURITY MODEL
#   - The reference clears jimfile.sh valid-id before any path is composed from
#     it, a stat included. The resolved slug clears it again: an ordinal or a
#     prefix answers with a basename read off the directory, whose bytes
#     nothing here chose, and a collection can arrive from a destination branch
#     whose entry gate admits names this one refuses.
#   - Issue files are read line-oriented and frontmatter-scoped — never
#     sourced, never evaluated. A body that quotes a field is not that field.
#   - stdout is exactly "<slug><TAB><kind>". Failures are fixed reasons on
#     stderr carrying neither the rejected reference nor any issue content.
#
# USAGE
#   bash resolve.sh <dir> <ref>
#
#   <ref> is an exact slug, a display ordinal, or a unique slug prefix — the
#   grammar the read views document for naming one record.
#
#   <kind> is the record's own type field, or empty for a record written
#   before the schema carried one. A caller deciding whether the target is an
#   umbrella compares against it rather than asking this script to judge, so
#   the refusal it raises can name what the record actually is.
#
# EXIT CODES
#   0  resolved; stdout is "<slug><TAB><kind>"
#   1  the reference is invalid, names no record, or names more than one
#   2  usage error
#
# Conventions: set -uo pipefail; LC_ALL=C; BASH_SOURCE-relative jimfile path.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"

readonly INDEX_FILENAME="INDEX.md"

# frontmatter <file> — the lines between the first two fences.
#   Scoped deliberately: a whole-file match for a field also hits a body that
#   quotes one.
frontmatter() {
  awk '/^---$/{c++; if(c==2) exit; if(c==1) next} c==1{print}' "$1"
}

# fm_field <frontmatter> <field> — top-level scalar, quotes stripped, or empty.
fm_field() {
  printf '%s\n' "$1" | grep -E "^$2:" | head -n 1 \
    | sed -E "s/^$2:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"
}

dir="${1-}"
ref="${2-}"

if [[ $# -ne 2 || -z "$dir" || -z "$ref" ]]; then
  echo "usage: resolve.sh <dir> <ref>" >&2
  exit 2
fi
dir="${dir%/}"
[[ -d "$dir" ]] || { echo "error: no such collection directory" >&2; exit 1; }

# Before any path is composed from it, including the stat below.
bash "$JIMFILE" valid-id "$ref" >/dev/null 2>&1 || {
  echo "error: invalid issue reference" >&2
  exit 1
}

hits=()
if [[ -f "$dir/$ref.md" ]]; then
  hits=("$ref")
elif [[ "$ref" =~ ^[0-9]+$ ]]; then
  # An ordinal narrows to candidates with one pass, then each is confirmed
  # fence-scoped — the grep is a filter, not the decision, so a body line
  # reading like an ordinal cannot claim to be that record.
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ "$(fm_field "$(frontmatter "$f")" num)" == "$ref" ]] || continue
    base="$(basename "$f")"
    hits+=("${base%.md}")
  done < <(grep -l -E "^num: $ref\$" "$dir"/*.md 2>/dev/null)
else
  for f in "$dir/$ref"*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    hits+=("${base%.md}")
  done
fi

if (( ${#hits[@]} == 0 )); then
  echo "error: no issue matches that reference" >&2
  exit 1
fi
if (( ${#hits[@]} > 1 )); then
  echo "error: that reference matches more than one issue" >&2
  exit 1
fi

slug="${hits[0]}"

# The caller's reference cleared the validator above, but only the exact-slug
# branch answers with that reference. An ordinal or a prefix answers with a
# name read off the directory, so the value that actually composes the path is
# checked at the site composing it.
bash "$JIMFILE" valid-id "$slug" >/dev/null 2>&1 || {
  echo "error: invalid issue id" >&2
  exit 1
}

printf '%s\t%s\n' "$slug" "$(fm_field "$(frontmatter "$dir/$slug.md")" type)"
