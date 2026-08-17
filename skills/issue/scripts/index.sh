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

# row_safe <value> — a frontmatter scalar made safe to place in an INDEX.md row.
#
#   A row is ` · `-separated `key: value` pairs and every reader assigns by key
#   in the order it meets them, so a later pair overrides an earlier one. A value
#   able to reproduce the separator can therefore append its own pair and forge a
#   field the writer already emitted — a `status`, a `priority`, or the `num` that
#   `show <N>` resolves against. Removing the separator's own character makes the
#   row's shape a property of this writer rather than of its inputs.
#
#   The middle dot is removed rather than the three-character sequence, so no
#   arrangement of spaces around it can reconstitute a separator. A legitimate
#   `·` in a title is lost from the index row only; the issue file keeps it.
#   Byte-sequence safe under LC_ALL=C: sed matches the whole two-byte encoding,
#   where `tr -d` would delete each byte wherever it occurred and corrupt any
#   other character sharing one.
#
#   Control characters and the length cap are the corpus display-sanitizer form.
#
#   The stage order is load-bearing, not incidental. `tr` runs first because
#   deleting a control byte can bring the separator's own two bytes together —
#   `C2 01 B7` collapses to `C2 B7`, a reconstituted `·` — and `sed` removes it
#   only by running afterwards. `cut` runs last for the same reason in reverse:
#   the separator is already gone, so the cap can never bisect one and leave a
#   half. Reordering these three reopens separator forgery.
row_safe() {
  printf '%s' "$1" | tr -d '\000-\037\177' | sed 's/·//g' | cut -c1-512
}

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

# route_placement <arg> <place-token>
#   Re-exec this script through place.sh when the project keeps its collection
#   on a designated branch, so a reindex lands there rather than on whatever
#   branch the developer is standing on. An explicit directory argument opts
#   out — it is both what a caller naming a directory means and what stops the
#   re-exec from recursing.
route_placement() {
  local arg="$1" token="$2" place="$HERE/place.sh" mode
  [[ -z "$arg" && -r "$place" ]] || return 0
  mode="$(bash "$place" mode --place-token "$token")" || exit $?
  [[ "$mode" == "route" ]] || return 0
  exec bash "$place" run --verb reindex -- \
    bash "${BASH_SOURCE[0]}" --place-token '{token}' '{}'
}

main() {
  local place_token=""
  if [[ "${1:-}" == "--place-token" ]]; then
    place_token="${2:-}"
    shift 2
  fi
  local arg="${1:-}"
  route_placement "$arg" "$place_token"
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
  #
  # The glob above already produced this list in order: bash sorts pathname
  # expansion, and LC_ALL=C makes that byte order — byte-for-byte the order a
  # `sort` of the same full paths yields, since they share a directory prefix.
  # So the order needs no second pass, and it is taken from the glob's own
  # array rather than round-tripped through a word-split array assignment.
  #
  # That shape is load-bearing, not stylistic. An entry name is untrusted input
  # from a shared branch and may carry any byte but NUL and `/`, so a
  # line-oriented round trip cannot represent one that carries a newline: the
  # sort reads a single name as two records, and the split assignment reifies
  # two elements — one of them a fragment that has lost its directory prefix.
  # `IFS=$'\n'` closes space-splitting but not pathname expansion, and `set -f`
  # appears nowhere in this corpus, so that fragment re-globs against the
  # invoking checkout rather than the collection: a fragment of `*.md`
  # enumerates a project root and renders its frontmatter as issue rows.
  # Iterating the array keeps every name one word whatever bytes it holds.

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

  for f in "${files[@]}"; do
    local slug
    slug="$(basename "$f" .md)"
    if ! is_valid_id "$slug" 2>/dev/null; then
      # The value quoted here is precisely the one that failed the id gate, so
      # it is arbitrary bytes from a shared branch reaching the artifact every
      # reader parses. It clears the display sanitizer first — control
      # characters out, so a name cannot close this line and open a second
      # `## Issues` section for readers to take rows from, and the backticks
      # that would close the code span it sits in.
      warnings_section+="- Skipped \`$(row_safe "$slug" | tr -d '`')\`: filename is not a valid id."$'\n'
      continue
    fi

    local fm
    fm="$(extract_frontmatter "$f")"
    if [[ -z "$fm" ]]; then
      warnings_section+="- \`$slug\`: missing or malformed frontmatter."$'\n'
      continue
    fi
    # Recorded only past both gates, so the row set and the Summary counts below
    # derive from one population. A slug recorded ahead of the frontmatter gate
    # renders an `(untitled)` row while contributing to neither count — an index
    # asserting a row its own Summary denies.
    slugs_seen+=("$slug")

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
      warnings_section+="- \`$slug\` created is not a valid date or timestamp; degraded."$'\n'
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
        warnings_section+="- \`$slug\`: invalid relation target \`$(row_safe "$target" | tr -d '`')\` (type $type)."$'\n'
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
        warnings_section+="- \`$slug\`: malformed wikilink \`[[$(row_safe "$wl" | tr -d '`')]]\` ignored."$'\n'
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
  #
  # The pass is skipped when the collection lives on a designated branch. An
  # origin resolves or not according to the checkout the run happens to be
  # standing in, while the index being written belongs to every reader — so a
  # warning set derived that way is a fact about one developer's tree published
  # as a fact about the collection, flipping with whoever wrote last and making
  # a real diff each time. The condition is read from configuration rather than
  # from whether this run materialized anything, because a destination that is
  # checked out is linted from its own branch and one that is not is linted from
  # somebody else's; keying on the arm would keep the flapping and only move the
  # seam. The skip is stated rather than silent: a check that cannot be grounded
  # says so.
  local placement placement_shown origin_value origin_created prc
  # The resolver's own status decides this, not its output. An empty result read
  # as `branch` means a failed resolve *runs* the lint and the index then claims
  # the check was performed — while `place.sh` takes the explicitly opposite
  # stance on the same key. A failed resolve is not an unset key.
  placement="$(bash "$JIMCONF" get issue_placement 2>/dev/null)"; prc=$?
  if (( prc != 0 )); then
    echo "error: could not resolve issue_placement; refusing to write an index" \
         "that would claim the origin lint was performed" >&2
    return 2
  fi
  [[ -n "$placement" ]] || placement="branch"
  if [[ "$placement" != "branch" ]]; then
    # The name is config-supplied and this is the index every reader parses, so
    # it clears the same display sanitizer every row value clears — control
    # characters out, the row separator out, length capped — plus the backticks
    # that would close the code span it is quoted into.
    placement_shown="$(row_safe "$placement" | tr -d '`')"
    warnings_section+="- origin paths not checked: the collection is placed on \`$placement_shown\`, so a path resolves against whichever checkout wrote last rather than against the collection."$'\n'
  else
    for s in "${slugs_seen[@]}"; do
      origin_value="${meta_origin[$s]-}"
      [[ -z "$origin_value" ]] && continue
      case "$origin_value" in
        */*)
          if [[ ! -e "$origin_value" ]]; then
            origin_created="${meta_created[$s]-}"
            # A raw frontmatter scalar, and the one warning value that lands
            # outside a code span — so an unbalanced backtick would open one
            # over the rest of the block. Same sanitizer as a row value: the
            # length cap is what keeps an unbounded origin from landing whole
            # in a committed artifact, and the control-character strip is what
            # keeps ESC and CR out of every reader that cats this file.
            warnings_section+="- \`$s\` origin path does not resolve: $(row_safe "$origin_value" | tr -d '`') (created $origin_created)"$'\n'
          fi
          ;;
      esac
    done
  fi

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
        warnings_section+="- \`$s\` --$etype--> \`$etarget\` has no inverse \`$inverse\` back-edge."$'\n'
      fi
    done
  done

  # Render Issues section
  for s in "${slugs_seen[@]}"; do
    local row
    row="- \`$s\` — $(row_safe "${meta_title[$s]:-(untitled)}") · status: $(row_safe "${meta_status[$s]:-open}")"
    [[ -n "${meta_num[$s]:-}" ]]      && row+=" · num: $(row_safe "${meta_num[$s]}")"
    [[ -n "${meta_priority[$s]:-}" ]] && row+=" · priority: $(row_safe "${meta_priority[$s]}")"
    [[ -n "${meta_created[$s]:-}" ]]  && row+=" · created: $(row_safe "${meta_created[$s]}")"
    [[ -n "${meta_labels[$s]:-}" ]]   && row+=" · labels: $(row_safe "${meta_labels[$s]}")"
    [[ -n "${meta_origin[$s]:-}" ]]   && row+=" · origin: $(row_safe "${meta_origin[$s]}")"
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
      # %s, not %b. The section is concatenated from untrusted values — a
      # body-derived wikilink, a frontmatter relation target, an origin path, a
      # filename-derived slug — and %b expands backslash escapes in them, so a
      # value carrying a literal \n could inject lines into the index. Every
      # reader re-opens the issues section on a later `## Issues`, which is how
      # injected lines become served rows. The line breaks are real newlines in
      # the accumulator instead.
      printf '%s' "$warnings_section"
    else
      printf '_None._\n'
    fi
  # The rename below is atomic, which makes an unchecked compose actively
  # dangerous rather than merely unguarded: a short write would publish a
  # TRUNCATED index over a good one and return 0. Both reconcilers key their
  # "index failed to regenerate" error off this exit code, so that truncation
  # would reach them as a clean result. Guarded the way every sibling emitter
  # guards its write — a filled disk fails the block's last write too, so the
  # group's status is what catches exhaustion.
  } > "$tmpfile" || {
    echo "error: failed to compose INDEX.md; previous INDEX.md untouched" >&2
    rm -f "$tmpfile"
    trap - EXIT INT TERM
    return 1
  }

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
