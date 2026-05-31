#!/usr/bin/env bash
#
# skills/issues/scripts/index.sh — Generate INDEX.md for a jim issue collection.
#
# PURPOSE
#   Scan an issues directory, parse the markdown frontmatter and body for every
#   issue file, and write an auto-generated INDEX.md with four sections:
#     ## Summary             — Open/Closed counts
#     ## Issues              — one row per issue (slug, title, status, ...)
#     ## Graph               — typed edges from frontmatter relations and body
#                              wikilinks
#     ## Integrity Warnings  — bidirectional relation mismatches; malformed
#                              frontmatter; invalid wikilink content
#
#   Line-oriented parsing only — never `source` or `eval` issue files
#   (spec 017 AC-S1, CLAUDE.md → Bash scripts). Frontmatter is bounded by
#   the first two ^---$ lines; nested `relations:` is parsed via awk with
#   2-space indent tracking (DD #11). Atomic write via tmp + mv (DD #12).
#
#   Edge provenance is tracked via two parallel maps:
#     outgoing_fm[$slug]  — edges asserted in the frontmatter relations:
#                           block. The bidirectional integrity check walks
#                           this on both sides — wikilinks do not satisfy
#                           a frontmatter-asserted obligation.
#     outgoing_all[$slug] — frontmatter edges UNION body wikilink edges,
#                           deduped per (source, type, target). The Graph
#                           section renders from this so dual-channel
#                           authorship produces a single edge.
#   Frontmatter is the canonical structural channel; body wikilinks are a
#   one-way "see also" convenience that alias to related-to for graph
#   purposes.
#
# CLI SUMMARY
#   bash index.sh [<issues_dir>]
#     issues_dir default: jimconf.sh get issues
#     On success: exit 0, INDEX.md updated atomically.
#     On parse/IO failure: exit non-zero, previous INDEX.md untouched.
#
# EXIT CODES
#   0  Success.
#   1  IO failure (cannot read dir, cannot write tmp, atomic rename failed).
#   2  Malformed invocation (invalid issues_dir).
#

set -uo pipefail
export LC_ALL=C

# ─── Section: Globals ────────────────────────────────────────────────────────

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"

readonly INDEX_FILENAME="INDEX.md"

# Relation types and their inverses. Used for bidirectional integrity checks.
# blocks ↔ depends-on, related-to ↔ related-to, duplicates → (no inverse).
declare -A RELATION_INVERSE=(
  [blocks]="depends-on"
  [depends-on]="blocks"
  [related-to]="related-to"
)
readonly RELATION_TYPES=(blocks depends-on related-to duplicates)

# ─── Section: Slug validator (mirrors jimfile.sh is_valid_slug) ─────────────

# is_valid_slug <slug>
#   AC-C7 / AC-I4 validation. Quiet — returns 0/1, no output.
is_valid_slug() {
  local slug="$1"
  [[ -z "$slug" ]] && return 1
  [[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

# ─── Section: Frontmatter parsing ────────────────────────────────────────────

# extract_frontmatter <file>
#   Print the block between the first two ^---$ lines (exclusive). Empty
#   if no frontmatter or malformed (missing closing delimiter).
extract_frontmatter() {
  local file="$1"
  awk '
    /^---$/ {
      count++
      if (count == 1) { in_fm = 1; next }
      if (count == 2) { exit }
    }
    in_fm { print }
  ' "$file"
}

# parse_simple_field <frontmatter-content> <field-name>
#   Print the value of a top-level scalar field like `title: "..."` or
#   `status: open`. Strips surrounding double quotes. Empty if missing.
parse_simple_field() {
  local fm="$1" field="$2"
  printf '%s\n' "$fm" \
    | grep -E "^${field}:" \
    | head -n 1 \
    | sed -E "s/^${field}:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"
}

# parse_relations <frontmatter-content>
#   Emit lines: <type>\t<slug>  for each entry inside the `relations:` block.
#   DD #11 parser: scan top-level `relations:`; child lines at exactly 2-space
#   indent and matching `<type>: [<slugs>]`. Anything deeper or non-conforming
#   is ignored (the caller surfaces malformed-relations as Integrity Warnings).
parse_relations() {
  local fm="$1"
  printf '%s\n' "$fm" | awk '
    /^relations:[[:space:]]*$/ { in_rel = 1; next }
    in_rel {
      # Top-level non-blank line ends relations:
      if (/^[^[:space:]]/) { in_rel = 0; next }
      # 2-space indent: parse "  <type>: [<slugs>]"
      if (/^  [a-z][a-z-]*:[[:space:]]*\[/) {
        line = $0
        sub(/^  /, "", line)
        # Extract type
        type = line
        sub(/:.*$/, "", type)
        # Extract bracket contents
        sub(/^[a-z][a-z-]*:[[:space:]]*\[/, "", line)
        sub(/\][[:space:]]*$/, "", line)
        # Split by comma; trim each slug
        n = split(line, slugs, ",")
        for (i = 1; i <= n; i++) {
          slug = slugs[i]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", slug)
          if (slug != "") {
            print type "\t" slug
          }
        }
      }
    }
  '
}

# parse_wikilinks_from_body <file>
#   Read the body (everything after the second ^---$ line); extract candidate
#   wikilinks via grep regex; emit one slug per line for each VALID candidate.
#   Invalid candidates are silently dropped (treated as prose per AC-I4).
parse_wikilinks_from_body() {
  local file="$1"
  awk '
    /^---$/ {
      count++
      if (count >= 2) { in_body = 1; next }
    }
    in_body { print }
  ' "$file" \
    | grep -oE '\[\[[^][]+\]\]' \
    | sed -E 's/^\[\[|\]\]$//g'
}

# ─── Section: Main pipeline ──────────────────────────────────────────────────

# resolve_dir <arg>
#   Determine the issues directory: arg if non-empty, else jimconf default.
#   Errors with rc=2 if the result is empty or whitespace-only.
resolve_dir() {
  local arg="$1"
  local dir="$arg"
  if [[ -z "$dir" ]]; then
    dir="$(bash "$JIMCONF" get issues 2>/dev/null)"
  fi
  dir="${dir%/}"
  if [[ -z "$dir" ]]; then
    echo "error: issues_dir is empty" >&2
    return 2
  fi
  printf '%s\n' "$dir"
}

main() {
  local arg="${1:-}"
  local dir
  dir="$(resolve_dir "$arg")" || return $?
  mkdir -p "$dir" || { echo "error: cannot mkdir '$dir'" >&2; return 1; }

  # Collect issue files (exclude INDEX.md and hidden files).
  local files=()
  local f
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    local base
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    files+=("$f")
  done

  # First pass: collect per-issue metadata into parallel arrays.
  # Sorted in declare order; we sort the file list lexicographically by slug.
  IFS=$'\n' files_sorted=($(printf '%s\n' "${files[@]}" | sort))
  unset IFS

  local open_count=0 closed_count=0
  local issues_section="" graph_section="" warnings_section=""
  local slugs_seen=()

  # Build per-issue map: slug → "<status>\t<priority>\t<title>\t<origin>".
  declare -A meta_status meta_priority meta_title meta_origin meta_labels
  # Adjacency maps: slug → "<type>:<target> <type>:<target> ..." (space-separated).
  #   outgoing_fm  — frontmatter relations only (drives bidirectional check).
  #   outgoing_all — frontmatter + body wikilinks, deduped per
  #                  (source, type, target) (drives Graph render).
  declare -A outgoing_fm outgoing_all
  # Dedup key for outgoing_all: "<slug>|<type>|<target>".
  declare -A seen_all
  seen_all[__sentinel__]=1; unset 'seen_all[__sentinel__]'

  for f in "${files_sorted[@]}"; do
    local slug
    slug="$(basename "$f" .md)"
    if ! is_valid_slug "$slug"; then
      warnings_section+="- Skipped \`$slug\`: filename is not a valid slug.\n"
      continue
    fi
    slugs_seen+=("$slug")

    local fm
    fm="$(extract_frontmatter "$f")"
    if [[ -z "$fm" ]]; then
      warnings_section+="- \`$slug\`: missing or malformed frontmatter.\n"
      continue
    fi

    local status priority title origin labels
    status="$(parse_simple_field "$fm" status)"
    priority="$(parse_simple_field "$fm" priority)"
    title="$(parse_simple_field "$fm" title)"
    origin="$(parse_simple_field "$fm" origin)"
    labels="$(parse_simple_field "$fm" labels)"
    [[ -z "$status" ]] && status="open"

    meta_status[$slug]="$status"
    meta_priority[$slug]="$priority"
    meta_title[$slug]="$title"
    meta_origin[$slug]="$origin"
    meta_labels[$slug]="$labels"

    if [[ "$status" == "closed" ]]; then
      closed_count=$((closed_count + 1))
    else
      open_count=$((open_count + 1))
    fi

    # Build outgoing edges.
    #   Frontmatter relations populate BOTH outgoing_fm and outgoing_all
    #   (the bidirectional check walks fm; render walks all).
    #   Body wikilinks populate ONLY outgoing_all — they are one-way
    #   "see also" pointers per the design call (handoff:
    #   docs/notes/jim-issue-relations-handoff.md), so they do not
    #   trigger or satisfy bidirectional integrity warnings.
    local edges_fm="" edges_all=""
    local type target key
    while IFS=$'\t' read -r type target; do
      [[ -z "$type" || -z "$target" ]] && continue
      if ! is_valid_slug "$target"; then
        warnings_section+="- \`$slug\`: invalid relation target \`$target\` (type $type).\n"
        continue
      fi
      edges_fm+="$type:$target "
      key="$slug|$type|$target"
      if [[ -z "${seen_all[$key]:-}" ]]; then
        seen_all[$key]=1
        edges_all+="$type:$target "
      fi
    done < <(parse_relations "$fm")

    local wl
    while IFS= read -r wl; do
      [[ -z "$wl" ]] && continue
      if ! is_valid_slug "$wl"; then
        warnings_section+="- \`$slug\`: malformed wikilink \`[[${wl}]]\` ignored.\n"
        continue
      fi
      key="$slug|related-to|$wl"
      if [[ -z "${seen_all[$key]:-}" ]]; then
        seen_all[$key]=1
        edges_all+="related-to:$wl "
      fi
    done < <(parse_wikilinks_from_body "$f")

    outgoing_fm[$slug]="${edges_fm% }"
    outgoing_all[$slug]="${edges_all% }"
  done

  # Bidirectional integrity check (DD #7).
  # For each FRONTMATTER outgoing edge A --type--> B, if type has an inverse,
  # check that B has an inverse FRONTMATTER edge back to A. Wikilinks do not
  # participate on either side: a wikilink does not trigger a warning, and a
  # wikilink in B does not satisfy a frontmatter assertion in A.
  local s edge etype etarget inverse
  for s in "${slugs_seen[@]}"; do
    for edge in ${outgoing_fm[$s]:-}; do
      etype="${edge%%:*}"
      etarget="${edge#*:}"
      inverse="${RELATION_INVERSE[$etype]:-}"
      [[ -z "$inverse" ]] && continue
      local found=0
      for back in ${outgoing_fm[$etarget]:-}; do
        if [[ "$back" == "$inverse:$s" ]]; then
          found=1
          break
        fi
      done
      if (( found == 0 )); then
        warnings_section+="- \`$s\` --$etype--> \`$etarget\` has no inverse \`$inverse\` back-edge.\n"
      fi
    done
  done

  # Render Issues section
  for s in "${slugs_seen[@]}"; do
    local row
    row="- \`$s\` — ${meta_title[$s]:-(untitled)} · status: ${meta_status[$s]:-open}"
    [[ -n "${meta_priority[$s]:-}" ]] && row+=" · priority: ${meta_priority[$s]}"
    [[ -n "${meta_labels[$s]:-}" ]]   && row+=" · labels: ${meta_labels[$s]}"
    [[ -n "${meta_origin[$s]:-}" ]]   && row+=" · origin: ${meta_origin[$s]}"
    issues_section+="$row"$'\n'
  done

  # Render Graph section (from deduped union of frontmatter + wikilink edges).
  for s in "${slugs_seen[@]}"; do
    for edge in ${outgoing_all[$s]:-}; do
      local etype etarget
      etype="${edge%%:*}"
      etarget="${edge#*:}"
      graph_section+="- \`$s\` --$etype--> \`$etarget\`"$'\n'
    done
  done

  # Atomic write via tmp + mv (DD #12).
  local tmpfile
  tmpfile="$(mktemp "$dir/.${INDEX_FILENAME}.tmp.XXXXXX")" || {
    echo "error: cannot create tmp file in '$dir'" >&2
    return 1
  }
  trap 'rm -f "$tmpfile"' EXIT INT TERM

  {
    printf '# Issue Index\n\n'
    printf '## Summary\n\n'
    printf -- '- Open: %d\n' "$open_count"
    printf -- '- Closed: %d\n' "$closed_count"
    printf '\n## Issues\n\n'
    if [[ -n "$issues_section" ]]; then
      printf '%s' "$issues_section"
    else
      printf '_No issues._\n'
    fi
    printf '\n## Graph\n\n'
    if [[ -n "$graph_section" ]]; then
      printf '%s' "$graph_section"
    else
      printf '_No graph edges._\n'
    fi
    printf '\n## Integrity Warnings\n\n'
    if [[ -n "$warnings_section" ]]; then
      printf '%b' "$warnings_section"
    else
      printf '_None._\n'
    fi
  } > "$tmpfile"

  mv "$tmpfile" "$dir/$INDEX_FILENAME" || {
    echo "error: atomic rename failed; previous INDEX.md untouched" >&2
    return 1
  }
  trap - EXIT INT TERM
  return 0
}

main "$@"
