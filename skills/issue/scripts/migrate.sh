#!/usr/bin/env bash
#
# skills/issue/scripts/migrate.sh — one-shot, opt-in migrations that TRANSFORM
# existing issue data (vs backfill.sh, which fills in MISSING data). Subcommand:
#
#   prefix — re-derive every issue id to the active issue_id_prefix scheme
#            (spec 023), renaming files and rewriting inbound references behind
#            a read-only preview + explicit --apply gate.
#
# CLI SUMMARY
#   bash migrate.sh
#     No subcommand: print help/usage.
#   bash migrate.sh prefix [<issues_dir>]
#     PREVIEW (read-only): print the rename/skip/collision plan + summary.
#     Mutates nothing.
#   bash migrate.sh prefix [<issues_dir>] --apply [--expect <hash>]
#     APPLY: rename files + rewrite inbound refs + regenerate INDEX.
#   bash migrate.sh -c <config> <subcmd>
#     Forward -c to jimfile.sh / jimconf.sh (used by tests).
#   issues_dir default: jimconf.sh get issues
#
# EXIT CODES
#   0  Success (including the no-op and help cases).
#   1  IO failure (cannot write tmp, atomic rename failed).
#   2  Malformed invocation (unknown subcommand, empty issues_dir).
#   3  Drift (--expect mismatch).
#
# Line-oriented only; never source/evals an issue file.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
IDENTITY="$HERE/identity.sh"
readonly INDEX_FILENAME="INDEX.md"
CFG=""   # optional jimconf override path, forwarded to jimfile/jimconf

# jf / jc <args...> — invoke jimfile.sh / jimconf.sh, forwarding -c when set.
jf() { if [[ -n "$CFG" ]]; then bash "$JIMFILE" -c "$CFG" "$@"; else bash "$JIMFILE" "$@"; fi; }
jc() { if [[ -n "$CFG" ]]; then bash "$JIMCONF" -c "$CFG" "$@"; else bash "$JIMCONF" "$@"; fi; }

# resolve_dir <arg> — arg if non-empty, else jimconf default; strip trailing /.
resolve_dir() {
  local dir="${1:-}"
  [[ -z "$dir" ]] && dir="$(jc get issues 2>/dev/null)"
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

# Set together by split_row; the four fields of the plan row last read.
ROW_ACTION="" ROW_OLD="" ROW_NEW="" ROW_REASON=""

# split_row <row> — fill those four from one tab-separated plan row.
#
#   Not `IFS=$'\t' read -r action old new reason`: tab is IFS *whitespace*, so a
#   run of tabs collapses to a single delimiter. Every skip row carries an empty
#   new-id field, so reading one that way shifts its reason into the new-id slot
#   and drops it — which is why the preview announced "un-migratable:" with
#   nothing after it, for every skipped issue. The preview is what an operator
#   approves the migration on, so the row that cannot say why it was skipped is
#   the one that most needs to.
split_row() {
  local row="$1"
  ROW_ACTION="${row%%$'\t'*}"; row="${row#*$'\t'}"
  ROW_OLD="${row%%$'\t'*}";    row="${row#*$'\t'}"
  ROW_NEW="${row%%$'\t'*}";    ROW_REASON="${row#*$'\t'}"
}

# build_plan <dir> — emit one TAB row per issue (deterministic, sorted-glob
# order): <action>\t<old_id>\t<new_id>\t<reason>
#   action ∈ rename | collision-resolved | skip-conforming | skip-unmigratable
# Pure read: classifies and resolves collisions; mutates nothing. The slug is
# the id after its first '-' (every preset prefix is dash-free, DD 3); the new
# id and any -2/-3 discriminator pass jimfile's valid-id (the security boundary).
build_plan() {
  local dir="$1" f base id created num newpfx rc slug newid
  local -a rows=()
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    id="${base%.md}"
    if [[ "$id" != *-* ]]; then
      rows+=("skip-unmigratable"$'\t'"$id"$'\t'""$'\t'"id has no prefix delimiter")
      continue
    fi
    created="$(field_value "$f" created)"
    num="$(field_value "$f" num)"
    newpfx="$(jf prefix-from "$created" "$num" 2>&1)"; rc=$?
    if (( rc != 0 )); then
      rows+=("skip-unmigratable"$'\t'"$id"$'\t'""$'\t'"${newpfx#un-migratable: }")
      continue
    fi
    slug="${id#*-}"
    newid="${newpfx}-${slug}"
    if ! jf valid-id "$newid" >/dev/null 2>&1; then
      rows+=("skip-unmigratable"$'\t'"$id"$'\t'""$'\t'"re-derived id failed validation")
      continue
    fi
    if [[ "$newid" == "$id" ]]; then
      rows+=("skip-conforming"$'\t'"$id"$'\t'"$id"$'\t'"already in active scheme")
    else
      rows+=("rename"$'\t'"$id"$'\t'"$newid"$'\t'"")
    fi
  done
  (( ${#rows[@]} )) || return 0

  # Collision resolution. Reserve every unchanged id (skipped + conforming keep
  # their current id), then assign rename targets in order — a target already
  # taken gets the -2/-3 discriminator (spec 021 AC #6, reused not reinvented).
  local -A taken=()
  local row action old new reason
  for row in "${rows[@]}"; do
    split_row "$row"
    action="$ROW_ACTION" old="$ROW_OLD" new="$ROW_NEW" reason="$ROW_REASON"
    [[ "$action" == rename ]] || taken["$old"]=1
  done
  for row in "${rows[@]}"; do
    split_row "$row"
    action="$ROW_ACTION" old="$ROW_OLD" new="$ROW_NEW" reason="$ROW_REASON"
    if [[ "$action" == rename ]]; then
      if [[ -n "${taken[$new]:-}" ]]; then
        local n=2 cand
        while cand="${new}-${n}"; [[ -n "${taken[$cand]:-}" ]]; do n=$((n+1)); done
        new="$cand"; action="collision-resolved"
        # The discriminator makes a *new* id, and this one becomes a filename.
        # Its source cleared the boundary, but clearance does not transfer: the
        # charset cannot change and '..' cannot be introduced, yet the suffix
        # can carry a near-cap id past the length limit. So it clears the
        # boundary on its own account, which is what the header claims.
        if ! jf valid-id "$new" >/dev/null 2>&1; then
          # The reservation loop above leaves a rename's old id free, because a
          # renamed file moves away from it. This row entered as a rename and is
          # leaving as a skip, so it keeps its file — and must keep its name
          # with it. Without re-reserving, a later row is assigned the name of a
          # file still sitting there, both are moved into one path, and the
          # retire loop then removes the survivor's old name.
          taken["$old"]=1
          printf '%s\t%s\t%s\t%s\n' "skip-unmigratable" "$old" "" \
            "discriminated id failed validation"
          continue
        fi
      fi
      taken["$new"]=1
    fi
    printf '%s\t%s\t%s\t%s\n' "$action" "$old" "$new" "$reason"
  done
}

# render_plan <plan-rows> — human preview + summary counts.
render_plan() {
  local plan="$1" action old new reason renames=0 skips=0 collisions=0 __row
  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    split_row "$__row"
    action="$ROW_ACTION" old="$ROW_OLD" new="$ROW_NEW" reason="$ROW_REASON"
    case "$action" in
      rename)             printf '  rename     %s  ->  %s\n' "$old" "$new"; renames=$((renames+1)) ;;
      collision-resolved) printf '  collision  %s  ->  %s\n' "$old" "$new"; renames=$((renames+1)); collisions=$((collisions+1)) ;;
      skip-conforming)    printf '  skip       %s  (already in active scheme)\n' "$old"; skips=$((skips+1)) ;;
      skip-unmigratable)  printf '  skip       %s  (un-migratable: %s)\n' "$old" "$reason"; skips=$((skips+1)) ;;
    esac
  done <<<"$plan"
  printf '\n  %d to rename · %d to skip · %d collisions\n' "$renames" "$skips" "$collisions"
}

# gate_apply <expect> <plan-rows> — refuse an apply whose preview has gone
# stale. When the caller passed the preview's PLAN-HASH and the freshly
# recomputed plan no longer matches, the collection changed in between, so the
# plan the developer read is not the plan about to run.
#
#   Every migration here calls this one copy. A second implementation of the
#   same refusal is the one duplication worth avoiding outright: two copies can
#   disagree about when it is safe to write, and only one of them would be
#   covered by the case that proves the refusal works.
gate_apply() {
  local expect="$1" plan="$2" cur
  [[ -n "$expect" ]] || return 0
  cur="$(plan_hash "$plan")"
  if [[ "$cur" != "$expect" ]]; then
    echo "error: collection changed since preview (expected PLAN-HASH $expect, got $cur) — re-run the preview" >&2
    return 1
  fi
  return 0
}

# plan_hash <plan-rows> — a stable fingerprint of the plan for drift detection.
# cksum is POSIX/portable; we only need to catch accidental drift between the
# preview and a later --apply, not adversarial tampering.
plan_hash() {
  printf '%s' "$1" | cksum | cut -d' ' -f1
}

# git_note <dir> — read-only VCS recoverability note for the preview. The
# migration is destructive and recovery is via the developer's version control
# (git ops stay out of scope, spec 023). Flags an uncommitted collection when
# detectable, via a read-only `git status` — never a write.
git_note() {
  local dir="$1" st
  printf '\nThis migration is destructive — recovery is via your version control.\n'
  if st="$(git -C "$dir" status --porcelain -- . 2>/dev/null)" && [[ -n "$st" ]]; then
    printf 'Note: the issues collection has uncommitted changes; commit a clean checkpoint before --apply.\n'
  fi
}

# apply_plan <dir> <plan> — stage every file with its inbound refs rewritten,
# then commit: remove rename sources first (so a target held by a renamed-away
# file is free), atomically mv each staged tmp to its final name, regenerate
# INDEX. Per-file atomic mv; the op is idempotent so an interrupted run is
# completed by a retry (Tasks 7/8). Mutates the collection.
apply_plan() {
  local dir="$1" plan="$2" expect="${3:-}"
  gate_apply "$expect" "$plan" || return 3

  local mapfile
  mapfile="$(mktemp "$dir/.migrate.map.XXXXXX")" || {
    echo "error: cannot create tmp in $dir" >&2; return 1; }
  local action old new reason __row
  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    split_row "$__row"
    action="$ROW_ACTION" old="$ROW_OLD" new="$ROW_NEW" reason="$ROW_REASON"
    case "$action" in
      rename|collision-resolved) printf '%s\t%s\n' "$old" "$new" >> "$mapfile" ;;
    esac
  done <<<"$plan"

  # Idempotent no-op: nothing to rename means the collection already matches
  # the active scheme, so touch nothing (AC #5).
  if [[ ! -s "$mapfile" ]]; then
    rm -f "$mapfile"
    printf 'Nothing to migrate — every issue already matches the active scheme.\n'
    return 0
  fi

  local -a s_tmp=() s_old=() s_new=()
  local f base id finalid tmp
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    id="${base%.md}"
    finalid="$(awk -F'\t' -v k="$id" '$1==k{print $2; exit}' "$mapfile")"
    [[ -n "$finalid" ]] || finalid="$id"
    tmp="$(mktemp "$dir/.migrate.tmp.XXXXXX")" || {
      rm -f ${s_tmp[@]+"${s_tmp[@]}"} "$mapfile"
      echo "error: cannot create tmp in $dir — no changes made; safe to re-run" >&2; return 1; }
    if ! rewrite_refs "$mapfile" "$f" > "$tmp"; then
      rm -f ${s_tmp[@]+"${s_tmp[@]}"} "$tmp" "$mapfile"
      echo "error: rewrite failed for $f — no changes made; safe to re-run" >&2; return 1
    fi
    s_tmp+=("$tmp"); s_old+=("$f"); s_new+=("$dir/$finalid.md")
    # Test seam: simulate a mid-staging crash. Staging is non-destructive, so
    # this leaves the collection untouched and a retry converges (AC #10).
    # Never set in production.
    if [[ -n "${MIGRATE_FAIL_STAGING:-}" ]]; then
      rm -f "${s_tmp[@]}" "$mapfile"
      echo "error: staging aborted (fault injection) — no changes made; safe to re-run" >&2
      return 1
    fi
  done

  # Commit. Every staged file is put in place before any old name is retired:
  # retiring first opens a window where a failure has taken the old name away
  # and not yet supplied the new one, leaving every issue past the failure point
  # with neither — its only copy a tmp nothing removes. Renaming first means the
  # worst failure leaves a duplicate rather than a hole.
  local i j held
  local -A new_names=() landed=()
  for i in "${!s_new[@]}"; do new_names["${s_new[$i]}"]=1; done
  for i in "${!s_tmp[@]}"; do
    # Test seam: simulate a mid-commit failure, after one rename has landed.
    # Never set in production.
    if [[ -n "${MIGRATE_FAIL_COMMIT:-}" && "$i" -eq 1 ]] \
       || ! mv "${s_tmp[$i]}" "${s_new[$i]}"; then
      # No old name has been RETIRED yet, so every issue still has a copy under
      # one name or the other — except where a rename chain or a swap made one
      # file's old name another's new one, the same shape the retire loop below
      # guards. There a completed rename has written over a still-pending
      # issue's only on-disk copy, and its staged file is what is left of it, so
      # that one is kept and named. The rest never landed and are discarded
      # rather than left in the collection for a later run to publish.
      held=""
      for (( j=i; j<${#s_tmp[@]}; j++ )); do
        if [[ -n "${landed[${s_old[$j]}]:-}" ]]; then
          held+="  ${s_new[$j]} is staged at ${s_tmp[$j]}"$'\n'
        else
          rm -f "${s_tmp[$j]}"
        fi
      done
      rm -f "$mapfile"
      {
        printf 'error: commit failed at %s — the collection is PARTIALLY migrated.\n' "${s_new[$i]}"
        if [[ -n "$held" ]]; then
          printf '%s\n' "The issues committed before this point now exist under both names, except those below: a completed rename has already taken the old name, so the staged file named beside each is its only copy on disk and has been kept."
          printf '%s' "$held"
        else
          printf '%s\n' "The issues committed before this point now exist under both names, and none has been lost."
        fi
        printf '%s\n' "Recover via your version control (e.g. git checkout) and re-run"
      } >&2
      return 1
    fi
    landed["${s_new[$i]}"]=1
  done
  # Retire the old names, skipping any that another issue has just been renamed
  # *onto* — a rename chain or a swap makes one file's old name another's new
  # one, and removing it would delete the content just written there.
  for i in "${!s_old[@]}"; do
    [[ "${s_old[$i]}" == "${s_new[$i]}" ]] && continue
    [[ -n "${new_names[${s_old[$i]}]:-}" ]] && continue
    rm -f "${s_old[$i]}"
  done
  rm -f "$mapfile"

  bash "$HERE/index.sh" "$dir" >/dev/null 2>&1

  local renamed=0 skipped=0 collisions=0 __row
  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    split_row "$__row"
    action="$ROW_ACTION" old="$ROW_OLD" new="$ROW_NEW" reason="$ROW_REASON"
    case "$action" in
      rename)             renamed=$((renamed+1)) ;;
      collision-resolved) renamed=$((renamed+1)); collisions=$((collisions+1)) ;;
      skip-conforming|skip-unmigratable) skipped=$((skipped+1)) ;;
    esac
  done <<<"$plan"
  printf 'Re-derived to the active scheme: %d renamed (%d collision-resolved), %d skipped.\n' \
    "$renamed" "$collisions" "$skipped"
}

# ─── Section: schema conversion ──────────────────────────────────────────────

# Set together by split_schema_row; the four fields of the conversion row last
# read. Separate from the rename row's fields because they mean different
# things — a conversion has no old-to-new, it has a slug and the values that
# slug gains.
SCHEMA_ACTION="" SCHEMA_SLUG="" SCHEMA_FILER="" SCHEMA_OUTCOME=""

split_schema_row() {
  local row="$1"
  SCHEMA_ACTION="${row%%$'\t'*}"; row="${row#*$'\t'}"
  SCHEMA_SLUG="${row%%$'\t'*}";   row="${row#*$'\t'}"
  SCHEMA_FILER="${row%%$'\t'*}";  SCHEMA_OUTCOME="${row#*$'\t'}"
}

# frontmatter <file> — the lines between the first two fences.
#   Scoped deliberately: a whole-file read for `^status:` also matches a body
#   that quotes one, and at least one issue in a real collection does.
frontmatter() {
  awk '/^---$/{c++; if(c==2) exit; if(c==1) next} c==1{print}' "$1"
}

# fm_field <frontmatter> <field> — top-level scalar, quotes stripped, or empty.
fm_field() {
  printf '%s\n' "$1" | grep -E "^$2:" | head -n 1 \
    | sed -E "s/^$2:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"
}

# derive_filer <file> — the address of the commit that ADDED <file>, resolved
# through the project's alias mapping where it has one, empty where the file
# has no creating commit in reach.
#
#   --follow so a file renamed since its creation still reports the commit that
#   created it rather than the one that moved it. The mapping-aware spelling of
#   the author field costs one character over the raw one and keeps a
#   contributor's several addresses from splitting every by-person view.
derive_filer() {
  git log --diff-filter=A --follow -1 --format='%aE' -- "$1" 2>/dev/null
}

# build_schema_plan <dir> — emit one TAB row per issue, in sorted-glob order:
#   <action>\t<slug>\t<filer>\t<outcome>
#     action ∈ convert | skip-converted | unresolved
# Pure read: derives and classifies, mutates nothing.
build_schema_plan() {
  local dir="$1" f base slug fm type status filer outcome
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    slug="${base%.md}"
    fm="$(frontmatter "$f")"

    # An issue already carrying the kind field has been through this once.
    if [[ -n "$(fm_field "$fm" type)" ]]; then
      printf 'skip-converted\t%s\t\t\n' "$slug"
      continue
    fi

    status="$(fm_field "$fm" status)"
    outcome=""
    [[ "$status" == "closed" ]] && outcome="done"

    # A filer recovered from history is a recorded identity like any other, so
    # it clears the same gate the emitter's does. One that cannot is not
    # recoverable — reported, never replaced with a placeholder.
    filer="$(bash "$IDENTITY" validate "$(derive_filer "$f")" 2>/dev/null)" || filer=""
    if [[ -z "$filer" ]]; then
      printf 'unresolved\t%s\t\t\n' "$slug"
      continue
    fi

    printf 'convert\t%s\t%s\t%s\n' "$slug" "$filer" "$outcome"
  done
}

# render_schema_plan <plan-rows> — human preview + summary counts.
render_schema_plan() {
  local plan="$1" converts=0 skips=0 unresolved=0 __row
  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    split_schema_row "$__row"
    case "$SCHEMA_ACTION" in
      convert)
        printf '  convert     %s  filed-by %s%s\n' "$SCHEMA_SLUG" "$SCHEMA_FILER" \
          "${SCHEMA_OUTCOME:+  outcome $SCHEMA_OUTCOME}"
        converts=$((converts+1)) ;;
      skip-converted)
        printf '  skip        %s  (already carries the fields)\n' "$SCHEMA_SLUG"
        skips=$((skips+1)) ;;
      unresolved)
        printf '  unresolved  %s  (no recordable filer in history)\n' "$SCHEMA_SLUG"
        unresolved=$((unresolved+1)) ;;
    esac
  done <<<"$plan"
  printf '\n  %d to convert · %d to skip · %d unresolved\n' \
    "$converts" "$skips" "$unresolved"
}

# apply_schema_plan <dir> <plan> [<expect>] — write the new fields into every
# issue the plan converts. Per-file atomic tmp+mv, so an interrupted run leaves
# each file either untouched or wholly converted; a retry finishes the rest,
# because a converted issue is skipped rather than converted again.
apply_schema_plan() {
  local dir="$1" plan="$2" expect="${3:-}" converted=0 skipped=0 __row f tmp outcome
  gate_apply "$expect" "$plan" || return 3

  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    split_schema_row "$__row"
    if [[ "$SCHEMA_ACTION" != convert ]]; then
      skipped=$((skipped+1))
      continue
    fi
    f="$dir/$SCHEMA_SLUG.md"
    # An outcome is written bare when set and as an empty scalar when not,
    # matching how the emitter and the transition verbs write the same field.
    outcome='""'
    [[ -n "$SCHEMA_OUTCOME" ]] && outcome="$SCHEMA_OUTCOME"

    tmp="$(mktemp "$dir/.schema.tmp.XXXXXX")" || {
      echo "error: cannot create tmp in $dir" >&2; return 1; }
    awk -v filer="$SCHEMA_FILER" -v outcome="$outcome" '
      /^---$/ { fence++ }
      # The four scalars sit where the template puts them, ahead of labels.
      fence == 1 && !scalars && /^labels:/ {
        print "type: issue"
        print "filed-by: \"" filer "\""
        print "claimed-by: \"\""
        print "outcome: " outcome
        scalars = 1
      }
      # Membership is a relations child, and the member is the only side that
      # records it.
      fence == 1 && !member && /^  duplicates:/ {
        print
        print "  part-of: []"
        member = 1
        next
      }
      { print }
      END { exit (scalars && member) ? 0 : 1 }
    ' "$f" > "$tmp" || {
      rm -f "$tmp"
      echo "error: $SCHEMA_SLUG has no place to put the new fields; nothing written for it" >&2
      return 1
    }
    mv "$tmp" "$f" || {
      rm -f "$tmp"; echo "error: atomic rename failed for $SCHEMA_SLUG" >&2; return 1; }
    converted=$((converted+1))
  done <<<"$plan"

  bash "$HERE/index.sh" "$dir" >/dev/null 2>&1

  printf 'Converted %d issue(s); %d already carried the fields.\n' "$converted" "$skipped"
}

cmd_schema() {
  local dir="" apply=0 expect=""
  while (( $# )); do
    case "$1" in
      --apply)  apply=1; shift ;;
      --expect) expect="${2:-}"; shift 2 2>/dev/null || shift $# ;;
      *)        dir="$1"; shift ;;
    esac
  done
  dir="$(resolve_dir "$dir")" || return $?
  [[ -d "$dir" ]] || { echo "error: not a directory: $dir" >&2; return 1; }

  # The filer is recovered from the collection's own history, so a collection
  # with no history to read is refused here — once, naming the cause — rather
  # than reported as every issue being individually unrecoverable.
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: $dir is not inside a work tree; the filer is recovered from its history" >&2
    return 1
  fi

  local plan; plan="$(build_schema_plan "$dir")"
  if (( apply )); then
    apply_schema_plan "$dir" "$plan" "$expect"
  else
    printf 'Schema conversion plan — %s\n\n' "$dir"
    render_schema_plan "$plan"
    printf '\nPLAN-HASH: %s\n' "$(plan_hash "$plan")"
    git_note "$dir"
  fi
}

cmd_prefix() {
  local dir="" apply=0 expect=""
  while (( $# )); do
    case "$1" in
      --apply)  apply=1; shift ;;
      --expect) expect="${2:-}"; shift 2 2>/dev/null || shift $# ;;
      *)        dir="$1"; shift ;;
    esac
  done
  dir="$(resolve_dir "$dir")" || return $?
  [[ -d "$dir" ]] || { echo "error: not a directory: $dir" >&2; return 1; }
  local plan; plan="$(build_plan "$dir")"
  if (( apply )); then
    apply_plan "$dir" "$plan" "$expect"
  else
    printf 'Re-derivation plan — %s\n\n' "$dir"
    render_plan "$plan"
    printf '\nPLAN-HASH: %s\n' "$(plan_hash "$plan")"
    git_note "$dir"
  fi
}

# rewrite_refs <mapfile> <file> — print <file> with every reference whose id is
# a key in <mapfile> (TAB old\tnew per line) rewritten to its new id. Rewrites
# ONLY the structured reference sites index.sh recognizes — the four relations:
# buckets and body [[wikilinks]] outside fenced code / inline backticks — by
# EXACT id match. Never a substring/global replace: origin: paths, prose
# mentions, code-fenced links, and prefix-overlapping ids are left untouched
# (security F2; mirrors index.sh parse_relations + parse_wikilinks_from_body).
rewrite_refs() {
  local mapfile="$1" file="$2"
  awk -v MAP="$mapfile" '
    function rewrite_bucket(line,   lb, rb, pre, inner, post, parts, n, i, t, out) {
      lb = index(line, "["); rb = index(line, "]")
      if (lb == 0 || rb == 0 || rb < lb) return line
      pre = substr(line, 1, lb); inner = substr(line, lb+1, rb-lb-1); post = substr(line, rb)
      if (inner ~ /^[ \t]*$/) return line
      n = split(inner, parts, ",")
      out = ""
      for (i = 1; i <= n; i++) {
        t = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", t)
        if (t in M) t = M[t]
        out = (i == 1) ? t : out ", " t
      }
      return pre out post
    }
    function rewrite_wikilinks(seg,   res, rest, p, link, id) {
      res = ""; rest = seg
      while (match(rest, /\[\[[^][]*\]\]/)) {
        p = substr(rest, 1, RSTART-1)
        link = substr(rest, RSTART, RLENGTH)
        id = substr(link, 3, RLENGTH-4)
        if (id in M) link = "[[" M[id] "]]"
        res = res p link
        rest = substr(rest, RSTART+RLENGTH)
      }
      return res rest
    }
    function rewrite_body(line,   parts, np, i, seg, res) {
      np = split(line, parts, "`")
      res = ""
      for (i = 1; i <= np; i++) {
        seg = parts[i]
        if (i % 2 == 1) seg = rewrite_wikilinks(seg)
        res = (i == 1) ? seg : res "`" seg
      }
      return res
    }
    BEGIN {
      while ((getline ml < MAP) > 0) {
        k = index(ml, "\t")
        if (k > 0) M[substr(ml, 1, k-1)] = substr(ml, k+1)
      }
      close(MAP)
      fmcount = 0; infm = 0; inrel = 0; fence = ""
    }
    /^---$/ { fmcount++; print; infm = (fmcount == 1) ? 1 : 0; next }
    (infm == 1) {
      if ($0 ~ /^relations:[[:space:]]*$/) { inrel = 1; print; next }
      if (inrel && $0 !~ /^  /) inrel = 0
      if (inrel && $0 ~ /^  [a-z-]+:[[:space:]]*\[/) { print rewrite_bucket($0); next }
      print; next
    }
    (fmcount < 2) { print; next }
    {
      stripped = $0; sub(/^[ \t]+/, "", stripped)
      if (fence == "") {
        if (match(stripped, /^(`{3,}|~{3,})/)) { fence = substr(stripped, RSTART, RLENGTH); print; next }
        print rewrite_body($0); next
      } else {
        fchar = substr(fence, 1, 1); flen = length(fence)
        if (match(stripped, "^[" fchar "]{" flen ",}[ \t]*$")) fence = ""
        print; next
      }
    }
  ' "$file"
}

# cmd_rewrite <mapfile> <file> — internal primitive: print <file> with refs
# rewritten per <mapfile>. Used by --apply (into a tmp + mv) and exercised
# directly by the tests; deliberately omitted from usage().
cmd_rewrite() {
  local mapfile="${1:-}" file="${2:-}"
  [[ -f "$mapfile" && -f "$file" ]] || {
    echo "error: rewrite requires <mapfile> <file>" >&2; return 2; }
  rewrite_refs "$mapfile" "$file"
}

usage() {
  printf '%s\n' \
    'migrate.sh — one-shot, opt-in migrations that transform existing issue data.' \
    '' \
    '  bash migrate.sh prefix [<issues_dir>]' \
    '      Preview (read-only): re-derive every issue id to the active' \
    '      issue_id_prefix scheme; print the rename/skip/collision plan.' \
    '' \
    '  bash migrate.sh prefix [<issues_dir>] --apply [--expect <hash>]' \
    '      Apply the plan: rename files + rewrite inbound refs + regenerate INDEX.' \
    '' \
    '  bash migrate.sh schema [<issues_dir>]' \
    '      Preview (read-only): give every issue the identity, kind and outcome' \
    '      fields, recovering each filer from the commit that created its file.' \
    '' \
    '  bash migrate.sh schema [<issues_dir>] --apply [--expect <hash>]' \
    '      Apply the conversion: write the fields + regenerate INDEX.' \
    '' \
    '  issues_dir default: jimconf.sh get issues'
}

# route_placement <place-token> <args...>
#   Re-exec through place.sh when the project keeps its collection on a
#   designated branch, so renames land there as one commit. An explicit
#   directory argument opts out, which is also what stops the re-exec
#   recursing; a preview routes read-only, since previewing mutates nothing.
route_placement() {
  local token="$1"; shift
  local place="$HERE/place.sh" mode arg dir="" apply=0 skip_next=0
  [[ -r "$place" ]] || return 0
  for arg in "$@"; do
    if (( skip_next )); then skip_next=0; continue; fi
    case "$arg" in
      --apply)          apply=1 ;;
      --expect|-c)      skip_next=1 ;;
      prefix|schema|rewrite|-*) ;;
      *)                dir="$arg" ;;
    esac
  done
  [[ -z "$dir" ]] || return 0
  mode="$(bash "$place" mode --place-token "$token")" || exit $?
  [[ "$mode" == "route" ]] || return 0
  local -a run=(run)
  if (( apply )); then run+=(--verb migrate); else run+=(--read); fi
  exec bash "$place" "${run[@]}" -- \
    bash "${BASH_SOURCE[0]}" --place-token '{token}' "$@" '{}'
}

main() {
  local place_token=""
  if [[ "${1:-}" == "--place-token" ]]; then
    place_token="${2:-}"
    shift 2
  fi
  case "${1:-}" in
    ""|-h|--help|help) ;;
    *) route_placement "$place_token" "$@" ;;
  esac
  if [[ "${1:-}" == "-c" ]]; then
    [[ -n "${2:-}" ]] || { echo "error: -c requires a path argument" >&2; return 2; }
    CFG="$2"; shift 2
  fi
  case "${1:-}" in
    prefix)            shift; cmd_prefix "$@" ;;
    schema)            shift; cmd_schema "$@" ;;
    rewrite)           shift; cmd_rewrite "$@" ;;
    ""|-h|--help|help) usage ;;
    *)
      echo "error: unknown subcommand '$1' (expected: prefix, schema)" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
