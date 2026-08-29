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
#   bash transition.sh <join|leave> <id> <umbrella> [--dir <path>]
#     verb ∈ claim | release | start | close | reopen | join | leave
#     <id>   a display ordinal, an exact slug, or a unique slug prefix
#     <umbrella>  the same reference forms <id> accepts; join and leave are
#            the only verbs that bind a second operand
#     --dir  operate on a named collection and skip the placement door; for
#            tests, mirroring the emitter's flag of the same name
#
# EXIT CODES
#   0  success
#   1  validation or IO failure (no identity, unknown or invalid id, a close
#      the record cannot carry, write error)
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
RESOLVE="$HERE/resolve.sh"

readonly TRANSITION_VERBS=(claim release start close reopen join leave)

# The verbs that bind a second positional. Every other verb keeps the arity it
# has always had, so a stray token stays an error rather than becoming an
# operand nothing reads.
readonly VERBS_WITH_UMBRELLA=(join leave)

# How an issue can have been finished. Checked before anything is written: the
# index reports an unrecognized outcome, but detecting one afterwards leaves a
# record the schema says cannot exist, where refusing keeps it from existing.
readonly ISSUE_OUTCOMES=(done wontfix duplicate obsolete)

usage() {
  printf '%s\n' \
    'transition.sh — move one issue through its lifecycle.' \
    '' \
    '  bash transition.sh <verb> <id> [--as <outcome>] [--force] [--dir <path>]' \
    '' \
    "  verbs: ${TRANSITION_VERBS[*]}" >&2
}

# takes_umbrella <verb> — exit 0 iff <verb> binds a second positional operand.
takes_umbrella() {
  local v
  for v in "${VERBS_WITH_UMBRELLA[@]}"; do
    [[ "$1" == "$v" ]] && return 0
  done
  return 1
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

# relation_targets <frontmatter> <type> — the slugs listed under one relations
# child, or empty. Children are indented, so the top-level field reader above
# never sees them.
relation_targets() {
  printf '%s\n' "$1" | awk -v type="$2" '
    /^relations:[[:space:]]*$/ { in_rel = 1; next }
    in_rel && /^[^[:space:]]/  { in_rel = 0 }
    in_rel && $0 ~ "^  " type ":[[:space:]]*\\[" {
      line = $0
      sub(/^[^[]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      gsub(/[[:space:]]/, "", line)
      print line
      exit
    }
  '
}

# csv_has <csv> <needle> — exit 0 iff <needle> is one of <csv>'s members.
csv_has() {
  local IFS=',' t
  for t in $1; do [[ "$t" == "$2" ]] && return 0; done
  return 1
}

# csv_without <csv> <needle> — <csv> with every occurrence of <needle> dropped.
csv_without() {
  local IFS=',' t out=""
  for t in $1; do
    [[ "$t" == "$2" ]] && continue
    if [[ -z "$out" ]]; then out="$t"; else out="$out,$t"; fi
  done
  printf '%s' "$out"
}

# drop_unchanged <file> <pairs> — <pairs> minus every pair the record already
# satisfies.
#
#   The comparison is between COMPOSED LINES, not between values, and that is
#   the load-bearing detail. set_fields writes `field: value`, while the pairs
#   arrive in file form — claimed-by carrying its literal quotes, status and
#   outcome bare. Comparing a pair's value against a quote-stripping reader
#   would match for the bare fields and never for the quoted one, so the rule
#   would look implemented while every claim and release kept rewriting the
#   record. Asking whether `field: value` already IS the record's line is
#   quote-agnostic, needs no per-field knowledge, and cannot drift when a
#   field with a different convention is added.
#
#   It reaches an indented relations child for the same reason set_fields
#   does: the field name carries its own indentation.
drop_unchanged() {
  local file="$1" pairs="$2" fm line field value current kept=""
  fm="$(frontmatter "$file")"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    field="${line%%$'\t'*}"
    value="${line#*$'\t'}"
    current="$(printf '%s\n' "$fm" | grep -m1 -E "^$field:" | sed 's/[[:space:]]*$//')"
    [[ "$current" == "$field: $value" ]] && continue
    kept+="$line"$'\n'
  done <<< "$pairs"
  printf '%s' "$kept"
}

# set_fields <file> <pairs> — replace top-level frontmatter scalars, where
# <pairs> is newline-separated `field<TAB>value`.
#
#   A field name may carry its own leading indentation, which is how a
#   relations child such as `  part-of` is addressed: the match, the
#   presence check and the rewritten line all use the name as given, so an
#   indented field needs no second writer.
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
    # Both halves reach awk through the environment rather than `-v`, which
    # processes its operand as a string literal and expands escape sequences: a
    # backslash-n in a value would become a real newline and open a second
    # frontmatter pair, which a reader resolves ahead of the file's own. The
    # values that arrive here are gated — an identity clears the recordable
    # character set, an outcome clears its vocabulary — but this function reads
    # both halves out of its <pairs> argument and cannot see which caller built
    # them, so the channel holds the guarantee rather than the caller.
    field="$field" value="$value" awk '
      /^---$/ { fence++ }
      fence == 1 && !done && $0 ~ "^" ENVIRON["field"] ":" {
        print ENVIRON["field"] ": " ENVIRON["value"]
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

  local id="" umbrella="" outcome="" force=0 dir=""
  while (( $# )); do
    case "$1" in
      --as)    outcome="${2-}"; shift 2 || break ;;
      --force) force=1; shift ;;
      --dir)   dir="${2-}"; shift 2 || break ;;
      -*)      echo "error: unknown flag '$1'" >&2; usage; return 2 ;;
      *)       if [[ -z "$id" ]]; then id="$1"; shift
               elif [[ -z "$umbrella" ]] && takes_umbrella "$verb"; then
                 umbrella="$1"; shift
               else
                 echo "error: unexpected argument '$1'" >&2; return 2; fi ;;
    esac
  done

  if [[ -z "$id" ]]; then
    echo "error: '$verb' requires an issue id" >&2
    usage
    return 2
  fi

  if takes_umbrella "$verb" && [[ -z "$umbrella" ]]; then
    echo "error: '$verb' requires an umbrella" >&2
    usage
    return 2
  fi

  if [[ -n "$outcome" ]]; then
    local o known=0
    for o in "${ISSUE_OUTCOMES[@]}"; do
      [[ "$o" == "$outcome" ]] && { known=1; break; }
    done
    if (( ! known )); then
      echo "error: unrecognized outcome; expected one of: ${ISSUE_OUTCOMES[*]}" >&2
      return 2
    fi
  fi

  # Every transition acts under a recorded identity: claim and start write one
  # into the issue, and the rest publish a commit as somebody. Resolving once,
  # here, keeps that a single rule rather than a per-verb matrix.
  local actor
  actor="$(bash "$IDENTITY" resolve)" || {
    echo "error: refusing to transition without a recordable identity" >&2
    return 1
  }

  # A fail-fast ahead of the door, not a second definition of resolution: an
  # id that cannot name a record at all should not cost a materialized
  # collection first. resolve.sh gates the same bytes again on its own side,
  # which is what makes this one an optimization rather than a guard.
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

  # From here every exit unwinds the door rather than leaving a handle open —
  # every exit but the publish itself, which the door keeps on purpose.
  #
  # Both operands resolve through the same script, so a reference that names a
  # record on this path names the same record on the capture path, and neither
  # can drift from the other by being edited alone. It also performs both
  # validations a reference needs — the supplied bytes before any path is
  # composed from them, and the resolved name again, because an ordinal or a
  # prefix answers with a basename read off the directory rather than with
  # anything the caller chose, and a collection can arrive from a destination
  # branch whose entry gate admits names this one refuses.
  #
  # Its stderr is left to reach the developer. The reasons it gives are fixed
  # strings carrying neither the reference nor any issue content, and they
  # separate a reference matching nothing from one matching several — a
  # distinction the line below cannot draw, and one worth having when a verb
  # takes two references and only one of them is wrong.
  local slug kind rc=0 res
  if ! res="$(bash "$RESOLVE" "$work" "$id")"; then
    echo "error: cannot resolve the issue reference" >&2
    [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
    return 1
  fi
  slug="${res%%$'\t'*}"
  kind="${res##*$'\t'}"

  local file="$work/$slug.md"

  # The umbrella operand goes through the same script, for the same reasons,
  # and its stderr reaches the developer on the same terms. The line below
  # only names which of a two-reference verb's operands failed, which is the
  # one thing resolve.sh cannot know.
  #
  # `leave` consults the record's own memberships first. An umbrella is a
  # record like any other and can stop existing, while membership lives on the
  # member alone — so a record can hold an entry nothing resolves, and the
  # index reports it on every regeneration until a verb clears it. Leaving a
  # set does not require the set to exist, and an entry the record literally
  # holds has one unambiguous meaning, so it never reaches the resolver:
  # asking first also stops a dead entry that happens to prefix some live
  # record from resolving away to that record and reporting success while the
  # entry survives. The operand is only ever compared — the new list is
  # composed from the record's own entries — so nothing unresolved reaches the
  # file. `join` is deliberately not given this: entering a set does require
  # the set to exist.
  local umbrella_slug="" umbrella_kind=""
  if [[ -n "$umbrella" ]]; then
    local ures
    if [[ "$verb" == leave ]] \
       && csv_has "$(relation_targets "$(frontmatter "$file")" part-of)" "$umbrella"; then
      umbrella_slug="$umbrella"
    elif ! ures="$(bash "$RESOLVE" "$work" "$umbrella")"; then
      echo "error: cannot resolve the umbrella reference" >&2
      [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
      return 1
    else
      umbrella_slug="${ures%%$'\t'*}"
      umbrella_kind="${ures##*$'\t'}"
    fi
  fi

  # Containment is enforced on the way in only. A record that reached a
  # forbidden membership by hand-edit is reported by the index, and `leave`
  # stays available to repair it — refusing there would make the violation
  # permanent through the very verb that undoes it.
  if [[ "$verb" == join ]]; then
    if [[ "$umbrella_kind" != "epic" ]]; then
      # The kind is displayed only when its shape is inert. It is read from a
      # record that may have been hand-edited, and a refusal is not the place
      # to render arbitrary file content.
      if [[ "$umbrella_kind" =~ ^[a-z][a-z-]{0,30}$ ]]; then
        echo "error: that record is an $umbrella_kind, not an epic" >&2
      else
        echo "error: that record is not an epic" >&2
      fi
      [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
      return 1
    fi
    # The member's own kind came back from the same resolution, so the two
    # records in this refusal are read the same way rather than one being
    # resolved and the other re-read.
    if [[ "$kind" == "epic" ]]; then
      echo "error: an epic cannot belong to an epic" >&2
      [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
      return 1
    fi
  fi

  local changes
  changes="$(apply_verb "$verb" "$file" "$actor" "$outcome" "$force" "$umbrella_slug")"
  rc=$?
  if (( rc != 0 )); then
    [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
    return $rc
  fi

  # Drop everything the record already satisfies, BEFORE the stamp is composed.
  # The order is the whole point: the stamp is a fresh timestamp and so is
  # never equal to the record's, and appending it first would make every run a
  # change. Deciding on the semantic fields alone is also what lets the
  # placement door's own empty-diff guard finally reach a transition — the
  # stamp is exactly what has been defeating it.
  changes="$(drop_unchanged "$file" "$changes")"

  if [[ -z "$changes" ]]; then
    # Nothing to do is a success, not a refusal: grouping several issues at
    # once must not fail on the one already grouped. Nothing is written, no
    # stamp moves, the index is not regenerated, and the door is released
    # rather than asked to publish an empty commit.
    [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
    printf '%s\t%s\tunchanged\n' "$slug" "$verb"
    return 0
  fi

  # The stamp rides with the verb's own changes so the whole transition is one
  # publish rather than a field change followed by a separate stamp. A stamp
  # that cannot be resolved refuses the move: `updated` is the one field a
  # transition guarantees is wrong afterwards, so recording the move without it
  # publishes a record stale in exactly the respect the run was for. The
  # refusal lands before any write, leaving the issue as it was.
  local now
  if ! now="$(bash "$JIMFILE" now)" || [[ -z "$now" ]]; then
    echo "error: could not resolve the transition timestamp" >&2
    [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
    return 1
  fi
  changes+=$'\n'"updated"$'\t'"$now"

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
    # The one exit that does not unwind the door, and deliberately: a refused
    # publish keeps the handle and the edits inside it, so a destination that
    # moved underneath is re-applied and committed again rather than retyped.
    # Aborting here would discard the developer's work to tidy up state the
    # door is holding on purpose.
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
  local umbrella="${6:-}"
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
      # A superseded issue identifies what supersedes it. That is stated as a
      # property of the record, so a record that would contradict it is refused
      # here rather than written and reported by the index afterwards.
      if [[ "$outcome" == duplicate && -z "$(relation_targets "$fm" duplicates)" ]]; then
        echo "error: closing as duplicate needs the superseding issue in duplicates" >&2
        return 1
      fi
      printf 'status\tclosed\n'
      printf 'outcome\t%s\n' "$outcome"
      ;;
    reopen)
      # The outcome is deliberately left alone. An open issue carrying one is
      # how a reopen is recorded: it names how the issue was finished last
      # time, and discarding it would throw away the reason.
      printf 'status\topen\n'
      ;;
    join|leave)
      # Membership is a set, and the field is a list — so an append is the
      # wrong default. The existing order is preserved and the umbrella is
      # added only when absent, which makes a repeated join produce the line
      # the record already has; the shared filter then drops it and the run
      # writes nothing.
      #
      # Read through relation_targets, not the top-level scalar reader: this
      # field is indented under `relations:` and a reader anchored at the
      # start of a line cannot see it at all.
      local targets next
      targets="$(relation_targets "$fm" part-of)"
      if [[ "$verb" == join ]]; then
        next="$targets"
        if ! csv_has "$targets" "$umbrella"; then
          if [[ -z "$targets" ]]; then next="$umbrella"
          else next="$targets,$umbrella"; fi
        fi
      else
        next="$(csv_without "$targets" "$umbrella")"
      fi
      # The field name carries its indentation, which is how set_fields
      # addresses a relations child. Every member is a resolved, twice
      # validated id, so none can close the array or open a field of its own.
      printf '  part-of\t[%s]\n' "${next//,/, }"
      ;;
  esac
  return 0
}

main "$@"
