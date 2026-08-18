#!/usr/bin/env bash
#
# skills/issue/scripts/transition.sh — move one issue through its lifecycle.
#   One script for every transition rather than one per verb: the door dance,
#   the id resolution, the last-modified refresh and the reindex are the same
#   work whichever field ends up changing, and five copies of them would be
#   five chances for them to drift.
#
#   This script mutates existing issue files. It creates none — new files come
#   from the emitter alone, which is a different contract with a different door
#   verb.
#
# SECURITY MODEL
#   - The id clears the validator before it composes any path, including the
#     stat that asks whether a file exists: answering a question about the
#     filesystem is the read the boundary governs.
#   - An id resolves only against issues the collection actually holds. An
#     ordinal is matched against recorded frontmatter, never turned into a
#     filename.
#   - Every mutation goes through the placement door, so a collection kept on
#     a designated branch is written there as one commit under a verb from a
#     fixed enum — no part of an issue reaches a commit message.
#   - Issue files are read line-orientedly and never sourced or evaluated.
#
# USAGE
#   bash transition.sh <verb> <id> [--as <outcome>] [--force] [--dir <path>]
#     verb ∈ claim | release | start | close | reopen
#     <id>   a display ordinal, an exact slug, or a unique slug prefix
#     --dir  operate on a named collection and skip the placement door; for
#            tests, mirroring the emitter's flag of the same name
#
# EXIT CODES
#   0  success
#   1  validation or IO failure (no identity, unknown or invalid id, write error)
#   2  usage error (unknown verb, missing id, unrecognized outcome)
#   3  placement conflict, forwarded from place.sh
#   5  the issue is held by someone else and --force was not given

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IDENTITY="$HERE/identity.sh"
PLACE="$HERE/place.sh"
INDEX_SCRIPT="$HERE/index.sh"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"

readonly TRANSITION_VERBS=(claim release start close reopen)
readonly INDEX_FILENAME="INDEX.md"

usage() {
  printf '%s\n' \
    'transition.sh — move one issue through its lifecycle.' \
    '' \
    '  bash transition.sh <verb> <id> [--as <outcome>] [--force] [--dir <path>]' \
    '' \
    "  verbs: ${TRANSITION_VERBS[*]}" >&2
}

# in_verbs <candidate> — exit 0 iff <candidate> is a transition verb.
in_verbs() {
  local v
  for v in "${TRANSITION_VERBS[@]}"; do
    [[ "$v" == "$1" ]] && return 0
  done
  return 1
}

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

# resolve_slug <dir> <id> — the single issue <id> names, or empty.
#   Accepts an exact slug, a display ordinal, or a unique slug prefix, matching
#   how the read views resolve one. Every candidate is confirmed against the
#   file's own frontmatter before it is accepted, so a body that happens to
#   contain an ordinal line cannot claim to be that issue.
resolve_slug() {
  local dir="$1" id="$2" f base cand fm hits=()

  [[ -f "$dir/$id.md" ]] && { printf '%s' "$id"; return 0; }

  # An ordinal narrows to candidates with one pass, then each is confirmed
  # fence-scoped — the grep is a filter, not the decision.
  if [[ "$id" =~ ^[0-9]+$ ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      fm="$(frontmatter "$f")"
      [[ "$(fm_field "$fm" num)" == "$id" ]] || continue
      base="$(basename "$f")"
      hits+=("${base%.md}")
    done < <(grep -l -E "^num: $id\$" "$dir"/*.md 2>/dev/null)
  else
    for f in "$dir/$id"*.md; do
      [[ -f "$f" ]] || continue
      base="$(basename "$f")"
      [[ "$base" == "$INDEX_FILENAME" ]] && continue
      hits+=("${base%.md}")
    done
  fi

  (( ${#hits[@]} == 1 )) || return 1
  printf '%s' "${hits[0]}"
}

# set_fields <file> <pairs> — replace top-level frontmatter scalars, where
# <pairs> is newline-separated `field<TAB>value`.
#
#   Every change lands in ONE atomic publish. A transition that wrote each
#   field separately could be interrupted between them and leave, say, a
#   finished issue carrying no outcome — precisely the contradiction the index
#   reports as an integrity failure. Staging the whole edit and moving once
#   makes that state unreachable rather than merely detectable.
#
#   A field that is not there cannot be replaced. Refusing beats rewriting the
#   file unchanged and reporting success — a stamp that silently fails to move
#   is indistinguishable from one that never needed to.
set_fields() {
  local file="$1" pairs="$2" tmp next line field value
  tmp="$(mktemp "$(dirname "$file")/.transition.tmp.XXXXXX")" || {
    echo "error: cannot create tmp file" >&2; return 1; }
  cp "$file" "$tmp" || { rm -f "$tmp"; echo "error: cannot stage the edit" >&2; return 1; }

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    field="${line%%$'\t'*}"
    value="${line#*$'\t'}"
    if ! frontmatter "$tmp" | grep -qE "^$field:"; then
      rm -f "$tmp"
      echo "error: '$field' is missing from the record" >&2
      return 1
    fi
    next="$tmp.next"
    awk -v field="$field" -v value="$value" '
      /^---$/ { fence++ }
      fence == 1 && !done && $0 ~ "^" field ":" {
        print field ": " value
        done = 1
        next
      }
      { print }
    ' "$tmp" > "$next" || {
      rm -f "$tmp" "$next"; echo "error: rewrite failed" >&2; return 1; }
    mv "$next" "$tmp" || {
      rm -f "$tmp" "$next"; echo "error: staging failed" >&2; return 1; }
  done <<< "$pairs"

  mv "$tmp" "$file" || { rm -f "$tmp"; echo "error: atomic rename failed" >&2; return 1; }
}

main() {
  local verb="${1:-}"
  if [[ -z "$verb" || "$verb" == -h || "$verb" == --help ]]; then usage; return 2; fi
  if ! in_verbs "$verb"; then
    echo "error: unknown verb '$verb'" >&2
    usage
    return 2
  fi
  shift

  local id="" outcome="" force=0 dir=""
  while (( $# )); do
    case "$1" in
      --as)    outcome="${2-}"; shift 2 || break ;;
      --force) force=1; shift ;;
      --dir)   dir="${2-}"; shift 2 || break ;;
      -*)      echo "error: unknown flag '$1'" >&2; usage; return 2 ;;
      *)       if [[ -z "$id" ]]; then id="$1"; shift; else
                 echo "error: unexpected argument '$1'" >&2; return 2; fi ;;
    esac
  done

  if [[ -z "$id" ]]; then
    echo "error: '$verb' requires an issue id" >&2
    usage
    return 2
  fi

  # Every transition acts under a recorded identity: claim and start write one
  # into the issue, and the rest publish a commit as somebody. Resolving once,
  # here, keeps that a single rule rather than a per-verb matrix.
  local actor
  actor="$(bash "$IDENTITY" resolve)" || {
    echo "error: refusing to transition without a recordable identity" >&2
    return 1
  }

  # Before any path is composed from it, including the stat inside resolve_slug.
  bash "$JIMFILE" valid-id "$id" >/dev/null 2>&1 || {
    echo "error: invalid issue id" >&2
    return 1
  }

  # Open the collection. An explicit --dir names one directly and skips the
  # door, which is also what keeps a test from needing a configured placement.
  local token="" work="$dir"
  if [[ -z "$dir" ]]; then
    local handle
    handle="$(bash "$PLACE" begin)" || return $?
    token="${handle%%$'\t'*}"
    work="${handle#*$'\t'}"
  fi

  # From here every exit unwinds the door rather than leaving a handle open.
  local slug rc=0
  if ! slug="$(resolve_slug "$work" "$id")" || [[ -z "$slug" ]]; then
    echo "error: no single issue matches '$id'" >&2
    [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
    return 1
  fi

  local file="$work/$slug.md"

  local changes
  changes="$(apply_verb "$verb" "$file" "$actor" "$outcome" "$force")"
  rc=$?
  if (( rc != 0 )); then
    [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
    return $rc
  fi

  # The stamp rides with the verb's own changes so the whole transition is one
  # publish rather than a field change followed by a separate stamp.
  local now
  now="$(bash "$JIMFILE" now)" || now=""
  [[ -n "$now" ]] && changes+=$'\n'"updated"$'\t'"$now"

  if [[ -n "$changes" ]]; then
    set_fields "$file" "$changes" || {
      [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
      return 1
    }
  fi

  bash "$INDEX_SCRIPT" "$work" >/dev/null 2>&1 || {
    echo "error: could not regenerate the index" >&2
    [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
    return 1
  }

  if [[ -n "$token" ]]; then
    bash "$PLACE" commit "$token" --verb "$verb" --id "$slug" >/dev/null || return $?
  fi

  printf '%s\t%s\n' "$slug" "$verb"
}

# takeable <holder> <actor> <force> — exit 0 when the holder record is this
# developer's to change: unheld, already theirs, or deliberately overridden.
#
#   Release is gated the same way claim is. Releasing an issue someone else
#   holds reaches the same end as taking it from them, so leaving it ungated
#   would make release-then-claim a takeover with no override anywhere in it.
takeable() {
  local holder="$1" actor="$2" force="$3"
  [[ -z "$holder" || "$holder" == "$actor" ]] && return 0
  (( force )) && return 0
  echo "error: held by $holder; re-run with --force to take it over" >&2
  return 1
}

# apply_verb <verb> <file> <actor> <outcome> <force> — emit the field changes
# this verb makes, as `field<TAB>value` lines. Writes nothing itself; the
# shared path collects these, adds the stamp, and publishes them together.
#
#   Enumerated values are written bare and free-form ones quoted, matching how
#   the emitter writes the same fields.
apply_verb() {
  local verb="$1" file="$2" actor="$3" outcome="$4" force="$5"
  local fm holder
  fm="$(frontmatter "$file")"
  holder="$(fm_field "$fm" claimed-by)"

  case "$verb" in
    claim)
      takeable "$holder" "$actor" "$force" || return 5
      printf 'claimed-by\t"%s"\n' "$actor"
      ;;
    release)
      takeable "$holder" "$actor" "$force" || return 5
      printf 'claimed-by\t""\n'
      ;;
    start)
      # Starting an unheld issue claims it, so that a developer picking work up
      # says so in one command rather than two.
      takeable "$holder" "$actor" "$force" || return 5
      printf 'claimed-by\t"%s"\n' "$actor"
      printf 'status\tactive\n'
      ;;
    close)
      # Anyone may close any issue, held or not, and the holder record is left
      # exactly as it was — it says who held the issue, not who finished it.
      [[ -n "$outcome" ]] || outcome="done"
      printf 'status\tclosed\n'
      printf 'outcome\t%s\n' "$outcome"
      ;;
    reopen)
      # The outcome is deliberately left alone. An open issue carrying one is
      # how a reopen is recorded: it names how the issue was finished last
      # time, and discarding it would throw away the reason.
      printf 'status\topen\n'
      ;;
  esac
  return 0
}

main "$@"
