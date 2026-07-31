#!/usr/bin/env bash
#
# skills/issue/scripts/index.sh — Generate INDEX.md for a jim issue collection.
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
#   Typed-relation absorption: when a typed frontmatter relation (blocks /
#   depends-on / duplicates) and a body wikilink both point to the same
#   target, the wikilink is absorbed — the typed edge already implies the
#   related-to relationship more precisely, so emitting a related-to
#   shadow alongside the typed edge carries no additional information. To
#   express both a typed relation AND an explicit related-to to the same
#   target, populate both frontmatter buckets — explicit structured
#   author intent is never absorbed.
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

# ─── Section: Id validator (mirrors jimfile.sh is_valid_id) ─────────────────

# is_valid_id <id>
#   Bounded allowlist for a full issue id / prefix (spec 021 AC #7, AC #11).
#   SYNC: the function body below is byte-identical to the copies in
#   skills/file/scripts/jimfile.sh and skills/issue/scripts/render.sh — a
#   tests/jimfile.sh case asserts the three agree. Keep them in lockstep.
#   Callers here suppress its stderr (2>/dev/null) and add their own warning.
is_valid_id() {
  local id="$1"
  if [[ -z "$id" ]]; then
    echo "error: id rejected — empty" >&2
    return 1
  fi
  if (( ${#id} > 128 )); then
    echo "error: id rejected — exceeds 128 characters" >&2
    return 1
  fi
  if [[ "$id" == *..* ]]; then
    echo "error: id rejected — '$id' contains '..'" >&2
    return 1
  fi
  if [[ ! "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "error: id rejected — '$id' (allowed: ^[A-Za-z0-9][A-Za-z0-9._-]*$)" >&2
    return 1
  fi
  return 0
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

# parse_scalar_fields <frontmatter-content>
#   Extract every top-level scalar field we care about in a SINGLE awk pass and
#   emit them ONE PER LINE in a fixed order:
#     status, priority, title, origin, labels, created, num
#   This replaces seven per-field `grep|head|sed` pipelines (~28 forks per
#   issue) with one awk invocation. One field per line (not TAB-joined) so the
#   caller can read empty fields back without IFS-whitespace collapsing
#   consecutive delimiters. Semantics match the prior parse_simple_field: only
#   top-level keys (no leading indent) match, the first occurrence wins,
#   leading `key:` and surrounding whitespace are stripped, and a single leading
#   and trailing double quote are removed independently (so `"Foo: bar"` →
#   `Foo: bar` and an unquoted `[a, b]` is preserved verbatim). Indented
#   `relations:` children never match the no-indent key pattern.
parse_scalar_fields() {
  printf '%s\n' "$1" | awk '
    /^[a-z_-]+:/ {
      key = $0
      sub(/:.*$/, "", key)
      if (key != "status" && key != "priority" && key != "title" &&
          key != "origin" && key != "labels" && key != "created" &&
          key != "num") next
      if (key in seen) next
      seen[key] = 1
      val = $0
      sub(/^[^:]*:[[:space:]]*/, "", val)   # strip "key:" + leading whitespace
      sub(/[[:space:]]+$/, "", val)         # strip trailing whitespace
      sub(/^"/, "", val); sub(/"$/, "", val) # strip one leading + trailing quote
      f[key] = val
    }
    END {
      print f["status"]; print f["priority"]; print f["title"]
      print f["origin"]; print f["labels"]; print f["created"]; print f["num"]
    }
  '
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
#
#   Fenced code blocks are excluded from extraction — tokens like `[[B]]` in
#   a ```bash example or shell conditionals like `[[ "$x" != "y" ]]` are
#   code, not prose cross-references, and must not produce edges or
#   malformed-wikilink warnings. Fence delimiters are runs of ≥3 backticks
#   or ≥3 tildes (per CommonMark). A close requires a run of the same
#   character ≥ the opening run length, allowing quad-backtick wrappers
#   to nest triple-backtick examples without false toggling.
#
#   Inline code spans (single-backtick `…`) are also stripped before
#   wikilink matching. Tokens like the prose `[[B]]` (inside `…`) and
#   shell conditionals like `[[ "$x" != "y" ]]` quoted inline are code,
#   not graph claims.
parse_wikilinks_from_body() {
  local file="$1"
  awk '
    /^---$/ {
      count++
      if (count >= 2) { in_body = 1; next }
    }
    !in_body { next }
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      if (!in_fence) {
        # Opening fence: leading whitespace + run of ≥3 backticks or tildes.
        if (length(line) >= 3) {
          first = substr(line, 1, 1)
          if (first == "`" || first == "~") {
            n = 0
            while (substr(line, n + 1, 1) == first) n++
            if (n >= 3) {
              in_fence = 1
              fence_char = first
              fence_len = n
              next
            }
          }
        }
        print
        next
      }
      # In fence: close requires same char repeated ≥ fence_len with only
      # whitespace after (per CommonMark). Otherwise skip.
      n = 0
      while (substr(line, n + 1, 1) == fence_char) n++
      if (n >= fence_len) {
        rest = substr(line, n + 1)
        sub(/[[:space:]]*$/, "", rest)
        if (rest == "") {
          in_fence = 0
          next
        }
      }
      next
    }
  ' "$file" \
    | sed -E 's/`[^`]*`//g' \
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
  declare -A meta_status meta_priority meta_title meta_origin meta_labels meta_created meta_num
  # Adjacency maps: slug → "<type>:<target> <type>:<target> ..." (space-separated).
  #   outgoing_fm  — frontmatter relations only (drives bidirectional check).
  #   outgoing_all — frontmatter + body wikilinks, deduped per
  #                  (source, type, target) (drives Graph render).
  declare -A outgoing_fm outgoing_all
  # Dedup key for outgoing_all: "<slug>|<type>|<target>".
  declare -A seen_all
  seen_all[__sentinel__]=1; unset 'seen_all[__sentinel__]'
  # Typed-target coverage: "<slug>|<target>" → 1 when a non-related-to
  # frontmatter edge from <slug> covers <target>. Body wikilinks to a
  # covered target are absorbed (no related-to shadow emitted).
  declare -A typed_target_for
  typed_target_for[__sentinel__]=1; unset 'typed_target_for[__sentinel__]'

  for f in "${files_sorted[@]}"; do
    local slug
    slug="$(basename "$f" .md)"
    if ! is_valid_id "$slug" 2>/dev/null; then
      warnings_section+="- Skipped \`$slug\`: filename is not a valid id.\n"
      continue
    fi
    slugs_seen+=("$slug")

    local fm
    fm="$(extract_frontmatter "$f")"
    if [[ -z "$fm" ]]; then
      warnings_section+="- \`$slug\`: missing or malformed frontmatter.\n"
      continue
    fi

    local status priority title origin labels created num
    {
      IFS= read -r status
      IFS= read -r priority
      IFS= read -r title
      IFS= read -r origin
      IFS= read -r labels
      IFS= read -r created
      IFS= read -r num
    } < <(parse_scalar_fields "$fm")
    [[ -z "$status" ]] && status="open"

    # SYNC(ts-shape): ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$
    # Degrade a non-conforming created so a malformed value never lands raw in an
    # INDEX.md row (tab/garbage): keep the day-start date prefix when present,
    # else empty, and surface an Integrity Warning. Spec 022 AC #8 / Finding F6.
    if [[ -n "$created" && ! "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$ ]]; then
      if [[ "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        created="${BASH_REMATCH[0]}"
      else
        created=""
      fi
      warnings_section+="- \`$slug\` created is not a valid date or timestamp; degraded.\n"
    fi

    meta_status[$slug]="$status"
    meta_priority[$slug]="$priority"
    meta_title[$slug]="$title"
    meta_origin[$slug]="$origin"
    meta_labels[$slug]="$labels"
    meta_created[$slug]="$created"
    meta_num[$slug]="$num"

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
      if ! is_valid_id "$target" 2>/dev/null; then
        warnings_section+="- \`$slug\`: invalid relation target \`$target\` (type $type).\n"
        continue
      fi
      edges_fm+="$type:$target "
      key="$slug|$type|$target"
      if [[ -z "${seen_all[$key]:-}" ]]; then
        seen_all[$key]=1
        edges_all+="$type:$target "
      fi
      # Typed (non-related-to) frontmatter edges absorb same-target
      # wikilinks: the typed relation already implies related-to.
      if [[ "$type" != "related-to" ]]; then
        typed_target_for["$slug|$target"]=1
      fi
    done < <(parse_relations "$fm")

    local wl
    while IFS= read -r wl; do
      [[ -z "$wl" ]] && continue
      if ! is_valid_id "$wl" 2>/dev/null; then
        warnings_section+="- \`$slug\`: malformed wikilink \`[[${wl}]]\` ignored.\n"
        continue
      fi
      # Absorption: a typed frontmatter edge to this target already
      # implies related-to — skip the wikilink-derived shadow.
      [[ -n "${typed_target_for[$slug|$wl]:-}" ]] && continue
      key="$slug|related-to|$wl"
      if [[ -z "${seen_all[$key]:-}" ]]; then
        seen_all[$key]=1
        edges_all+="related-to:$wl "
      fi
    done < <(parse_wikilinks_from_body "$f")

    outgoing_fm[$slug]="${edges_fm% }"
    outgoing_all[$slug]="${edges_all% }"
  done

  # Origin-lint second pass (spec 018 OL-1, OL-2, OL-3).
  # For each indexed slug whose origin field is path-shaped (contains '/'),
  # validate that the path resolves against the script's invoking CWD (PWD-
  # relative resolution; matches the rest of jim's bash conventions and
  # Claude Code's project-root-as-CWD invariant). Non-path-shaped tokens
  # (e.g., `conversation`, `external`) are silently exempt. Broken paths
  # produce an integrity warning naming slug, path, and created date — the
  # warning never blocks the file from being indexed or rendered.
  #
  # Under `set -u`, access meta_origin via ${meta_origin[$slug]-} and
  # continue when the value is empty — issues without an `origin:` field
  # are common (early adoption, hand-authored fixtures) and the lint pass
  # must not crash on them. (Spec 018 security review Finding 9.)
  local origin_value origin_created
  for s in "${slugs_seen[@]}"; do
    origin_value="${meta_origin[$s]-}"
    [[ -z "$origin_value" ]] && continue
    case "$origin_value" in
      */*)
        if [[ ! -e "$origin_value" ]]; then
          origin_created="${meta_created[$s]-}"
          warnings_section+="- \`$s\` origin path does not resolve: $origin_value (created $origin_created)\n"
        fi
        ;;
    esac
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
    [[ -n "${meta_num[$s]:-}" ]]      && row+=" · num: ${meta_num[$s]}"
    [[ -n "${meta_priority[$s]:-}" ]] && row+=" · priority: ${meta_priority[$s]}"
    [[ -n "${meta_created[$s]:-}" ]]  && row+=" · created: ${meta_created[$s]}"
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
  # The trap body runs at shell exit, which can be after this function has
  # returned and its `local` has gone out of scope. Expanding it defensively
  # keeps that from being fatal under `set -u` — an abort there would take the
  # cleanup down with it and report a shell-internal error over the real cause.
  trap 'rm -f "${tmpfile:-}"' EXIT INT TERM

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
    # Clean up here, while the path is still in scope, rather than leaving it to
    # a trap that fires after this frame is gone.
    rm -f "$tmpfile"
    trap - EXIT INT TERM
    return 1
  }
  trap - EXIT INT TERM
  # The mv preserves the tmp file's (earlier) mtime, so the directory entry it
  # just rewrote is left newer than INDEX.md. Bump INDEX.md to now so it is the
  # newest entry in the dir — render.sh's staleness gate relies on this to tell
  # a freshly built index from one invalidated by an added/removed/edited file.
  touch "$dir/$INDEX_FILENAME"
  return 0
}

main "$@"
