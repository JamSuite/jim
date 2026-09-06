#!/usr/bin/env bash
#
# skills/issue/scripts/backfill.sh — one-shot, opt-in migrations that fill in
# missing issue data: `num` display ordinals and `created`/`updated`
# second-resolution timestamps. Subcommands: `num`, `timestamp`.
#
# PURPOSE
#   Assign a `num:` display ordinal to every issue file that lacks one,
#   in `created:`-ascending order, continuing from the collection's current
#   max ordinal. This is a ONE-TIME migration for the `num:` field
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
# PREVIEW GATE
#   Both subcommands rewrite the whole collection, so both preview by default
#   and mutate only under --apply. The preview builds its plan read-only,
#   renders it, and prints a PLAN-HASH; passing that hash back as --expect
#   refuses the apply if the collection moved in between, so the plan that runs
#   is the plan that was read.
#
#   The plan is keyed by issue id rather than by path, which is what lets a
#   hash taken under one checkout still match the collection it named — a
#   placement-routed run materializes into a fresh directory each time.
#
# CLI SUMMARY
#   bash backfill.sh
#     No subcommand: print help/usage listing the subcommands.
#   bash backfill.sh num [--apply] [--expect <hash>] [<issues_dir>]
#     Assign a `num:` display ordinal to every issue lacking one, in
#     created-ascending order. Without --apply, previews and writes nothing.
#     With it, prints "Assigned display numbers to N issue(s)." iff N>0;
#     otherwise silent (idempotent no-op).
#   bash backfill.sh timestamp [--apply] [--expect <hash>] [<issues_dir>]
#     Rewrite date-only created/updated to YYYY-MM-DDT00:00:00Z (a day-start
#     placeholder, not a recovered time), atomically per file. Without --apply,
#     previews and writes nothing. Idempotent — already-timestamped values
#     untouched; malformed values named in the preview and left alone. With
#     --apply, prints "Normalized N issue(s) ..." iff N>0; else silent.
#   issues_dir default: jimconf.sh get issues
#
# EXIT CODES
#   0  Success (including the no-op, preview and help cases).
#   1  IO failure (cannot write tmp, atomic rename failed).
#   2  Malformed invocation (unknown subcommand, empty issues_dir, --expect
#      with no operand).
#   3  Drift (--expect mismatch).
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

# need_operand <flag> <argc> <operand> — the value <flag> requires, or refuse.
# A flag that silently takes the next token would read a following directory
# argument as its operand; one that silently takes an empty value would read a
# missing hash as "no hash given", which is the gate declining to gate.
need_operand() {
  local flag="$1" argc="$2" operand="${3:-}"
  if (( argc < 2 )) || [[ -z "$operand" ]]; then
    echo "error: $flag requires a value" >&2
    return 2
  fi
  printf '%s' "$operand"
}

# plan_hash <plan-rows> — a stable fingerprint of the plan for drift detection.
# cksum is POSIX/portable; we only need to catch accidental drift between the
# preview and a later --apply, not adversarial tampering.
plan_hash() {
  printf '%s' "$1" | cksum | cut -d' ' -f1
}

# gate_apply <expect> <plan-rows> — refuse an apply whose preview has gone
# stale. When the caller passed the preview's PLAN-HASH and the freshly
# recomputed plan no longer matches, the collection changed in between, so the
# plan the developer read is not the plan about to run.
#
#   Both subcommands call this one copy, for the reason migrate.sh states about
#   its own: two implementations of the same refusal can disagree about when it
#   is safe to write, and only one of them would be covered by the case that
#   proves the refusal works.
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

# git_note <dir> — read-only VCS recoverability note for the preview. The
# rewrite is destructive and recovery is via the developer's version control
# (git ops stay out of scope). Flags an uncommitted collection when
# detectable, via a read-only `git status` — never a write.
git_note() {
  local dir="$1" st
  printf '\nThis rewrite is destructive — recovery is via your version control.\n'
  if st="$(git -C "$dir" status --porcelain -- . 2>/dev/null)" && [[ -n "$st" ]]; then
    printf 'Note: the issues collection has uncommitted changes; commit a clean checkpoint before --apply.\n'
  fi
}

# frontmatter <file> — the lines between the first two fences.
#   Scoped deliberately: a whole-file match for a field also hits a body that
#   quotes one. A record that lacks the field is this script's own operating
#   condition, so a body line is exactly where a stray match comes from — and
#   answering from one makes the record look already-done and skips it.
frontmatter() {
  awk '/^---$/{c++; if(c==2) exit; if(c==1) next} c==1{print}' "$1"
}

# fm_field <frontmatter> <field> — top-level scalar, quotes stripped, or empty.
fm_field() {
  printf '%s\n' "$1" | grep -E "^$2:" | head -n 1 \
    | sed -E "s/^$2:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/"
}

# num_of <frontmatter> — the num: display ordinal, or empty when the field is
# absent or does not lead with digits.
num_of() {
  printf '%s\n' "$1" | grep -E '^num:[[:space:]]*[0-9]+' \
    | head -n 1 | sed -E 's/^num:[[:space:]]*([0-9]+).*/\1/'
}

# classify_ts <value> — judge one created/updated value, printing
# "<action>\t<canonical>":
#   - date-only YYYY-MM-DD      -> normalize \t YYYY-MM-DDT00:00:00Z (day-start
#                                  placeholder, not a recovered time)
#   - already a full timestamp  -> same      \t <value>  (idempotent)
#   - empty                     -> same      \t
#   - malformed (anything else) -> malformed \t <value>
# Pure: classifies and mints, warns about nothing and writes nothing. The
# warning a malformed value earns is the plan's to report, so that a preview
# names it before the rewrite rather than only while running.
# SYNC(ts-shape): ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$
classify_ts() {
  local v="$1"
  if [[ -z "$v" ]]; then printf 'same\t%s' "$v"
  elif [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf 'normalize\t%sT00:00:00Z' "$v"
  elif [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    printf 'same\t%s' "$v"
  else
    printf 'malformed\t%s' "$v"
  fi
}

# build_num_plan <dir> — emit one TAB row per issue that will be numbered:
#   <slug>\t<ordinal>
# Assignment is created-ascending with the slug as tie-break, continuing from
# the collection's current max ordinal. Pure read: decides everything, writes
# nothing, so the preview and the apply derive the same answer from the same
# input. Keyed by slug rather than path so the plan is checkout-independent.
build_num_plan() {
  local dir="$1"

  # Current max ordinal across the collection.
  local max=0 f n base fm
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" == "$INDEX_FILENAME" ]] && continue
    n="$(num_of "$(frontmatter "$f")")"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( n > max )) && max=$n
  done

  # Collect un-numbered issues as "<created>\t<slug>" for stable ordering.
  local list="" created slug
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    fm="$(frontmatter "$f")"
    [[ -n "$(num_of "$fm")" ]] && continue
    created="$(fm_field "$fm" created)"
    list+="$created"$'\t'"${base%.md}"$'\n'
  done
  [[ -z "$list" ]] && return 0

  local next=$(( max + 1 )) createdkey
  while IFS=$'\t' read -r createdkey slug; do
    [[ -z "$slug" ]] && continue
    printf '%s\t%s\n' "$slug" "$next"
    next=$(( next + 1 ))
  done < <(printf '%s' "$list" | sort -t$'\t' -k1,1 -k2,2)
}

# render_num_plan <plan-rows> — human preview + summary count.
render_num_plan() {
  local plan="$1" slug num assigns=0 __row
  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    IFS=$'\t' read -r slug num <<<"$__row"
    printf '  assign     %s  ->  num: %s\n' "$slug" "$num"
    assigns=$((assigns+1))
  done <<<"$plan"
  printf '\n  %d to number\n' "$assigns"
}

# apply_num_plan <dir> <plan> [<expect>] — insert each planned ordinal as the
# first frontmatter field. Per-file atomic tmp + mv; idempotent, so a retry
# completes an interrupted run. Mutates the collection.
apply_num_plan() {
  local dir="$1" plan="$2" expect="${3:-}"
  gate_apply "$expect" "$plan" || return 3

  local assigned=0 slug num file tmp __row
  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    IFS=$'\t' read -r slug num <<<"$__row"
    file="$dir/$slug.md"
    [[ -f "$file" ]] || continue
    tmp="$(mktemp "$dir/.backfill.tmp.XXXXXX")" || {
      echo "error: cannot create tmp file in '$dir'" >&2
      return 1
    }
    if awk -v n="$num" '
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
    assigned=$(( assigned + 1 ))
  done <<<"$plan"

  if (( assigned > 0 )); then
    printf 'Assigned display numbers to %d issue(s).\n' "$assigned"
  fi
  return 0
}

# build_ts_plan <dir> — emit TAB rows in glob order, created before updated
# within a file, so consecutive rows for one issue arrive together:
#   normalize\t<slug>\t<field>\t<old>\t<new>
#   malformed\t<slug>\t<field>
# Pure read: classifies and mints, writes nothing.
#
# A normalize row's values are safe to embed by construction, not by scrubbing:
# classify_ts mints them only from a value matching the date-only shape, so both
# are digits and dashes and neither can carry the TAB that would re-split the
# row. A malformed value is exactly the one that can, so a malformed row carries
# no value at all — the field name is what the operator needs, and it is what
# the warning already names.
build_ts_plan() {
  local dir="$1" f base slug fm field val action new
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "$INDEX_FILENAME" ]] && continue
    [[ "$base" == .* ]] && continue
    slug="${base%.md}"
    fm="$(frontmatter "$f")"
    for field in created updated; do
      val="$(fm_field "$fm" "$field")"
      IFS=$'\t' read -r action new <<<"$(classify_ts "$val")"
      case "$action" in
        normalize) printf 'normalize\t%s\t%s\t%s\t%s\n' "$slug" "$field" "$val" "$new" ;;
        malformed) printf 'malformed\t%s\t%s\n' "$slug" "$field" ;;
      esac
    done
  done
}

# render_ts_plan <plan-rows> — human preview + summary counts.
render_ts_plan() {
  local plan="$1" action slug field old new norms=0 bad=0 __row
  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    IFS=$'\t' read -r action slug field old new <<<"$__row"
    case "$action" in
      normalize) printf '  normalize  %s  %s: %s  ->  %s\n' "$slug" "$field" "$old" "$new"
                 norms=$((norms+1)) ;;
      malformed) printf '  skip       %s  %s  (not a valid date or timestamp)\n' "$slug" "$field"
                 bad=$((bad+1)) ;;
    esac
  done <<<"$plan"
  printf '\n  %d field(s) to normalize · %d malformed, left alone\n' "$norms" "$bad"
}

# rewrite_ts_file <dir> <slug> <new-created> <new-updated> — write one file's
# planned values, atomically. An empty value means "this field is not planned",
# so the sole values this writes are ones classify_ts minted itself; a malformed
# value is never planned and so is never reprinted through the writer.
#
# The values reach awk through the environment rather than `awk -v`, which
# processes its operand as a string literal and expands escape sequences: a
# literal backslash-n in an untrusted created/updated would become a real
# newline, and an issue's own field text would open a second frontmatter pair.
# Two independent guards, because the first rests on a contract classify_ts
# states and this function cannot see.
rewrite_ts_file() {
  local dir="$1" slug="$2" new_c="$3" new_u="$4"
  local f="$dir/$slug.md" tmp
  [[ -f "$f" ]] || return 0
  tmp="$(mktemp "$dir/.normalize.tmp.XXXXXX")" || {
    echo "error: cannot create tmp file in '$dir'" >&2
    return 1
  }
  if c="$new_c" u="$new_u" awk '
    /^---$/ { fm++; print; next }
    fm == 1 && /^created:/ && !cdone && ENVIRON["c"] != "" {
      print "created: " ENVIRON["c"]; cdone = 1; next }
    fm == 1 && /^updated:/ && !udone && ENVIRON["u"] != "" {
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
  return 0
}

# apply_ts_plan <dir> <plan> [<expect>] — write the plan. Rows for one issue are
# consecutive, so they are batched into a single atomic rewrite per file rather
# than one per field. Idempotent; mutates the collection.
apply_ts_plan() {
  local dir="$1" plan="$2" expect="${3:-}"
  gate_apply "$expect" "$plan" || return 3

  local normalized=0 cur="" new_c="" new_u="" pending=0
  local action slug field old new __row
  while IFS= read -r __row; do
    [[ -n "$__row" ]] || continue
    IFS=$'\t' read -r action slug field old new <<<"$__row"
    if [[ "$slug" != "$cur" ]]; then
      if (( pending )); then
        rewrite_ts_file "$dir" "$cur" "$new_c" "$new_u" || return 1
        normalized=$(( normalized + 1 ))
      fi
      cur="$slug"; new_c=""; new_u=""; pending=0
    fi
    case "$action" in
      malformed)
        echo "warning: $slug.md $field is not a valid date or timestamp; left unchanged" >&2 ;;
      normalize)
        if [[ "$field" == created ]]; then new_c="$new"; else new_u="$new"; fi
        pending=1 ;;
    esac
  done <<<"$plan"
  if (( pending )); then
    rewrite_ts_file "$dir" "$cur" "$new_c" "$new_u" || return 1
    normalized=$(( normalized + 1 ))
  fi

  if (( normalized > 0 )); then
    printf 'Normalized %d issue(s) to canonical timestamps. Note: legacy date-only values were set to day-start (T00:00:00Z) — a format placeholder, not a recovered time.\n' "$normalized"
  fi
  return 0
}

usage() {
  printf '%s\n' \
    'backfill.sh — one-shot, opt-in migrations that fill in missing issue data.' \
    '' \
    '  bash backfill.sh num [--apply] [--expect <hash>] [<issues_dir>]' \
    '      Assign a display `num:` ordinal to every issue lacking one, in' \
    '      created-ascending order. Idempotent; announces a count iff any.' \
    '' \
    '  bash backfill.sh timestamp [--apply] [--expect <hash>] [<issues_dir>]' \
    '      Rewrite legacy date-only created/updated to a day-start UTC timestamp' \
    '      (YYYY-MM-DDT00:00:00Z placeholder). Idempotent; announces a count iff any.' \
    '' \
    '  Both subcommands preview by default and write only under --apply. The' \
    '  preview prints a PLAN-HASH; passing it back as --expect refuses the apply' \
    '  if the collection changed in between (exit 3).' \
    '' \
    '  issues_dir default: jimconf.sh get issues'
}

# cmd_backfill <verb> <args...> — the one gate both subcommands pass through.
# Flags are parsed here rather than inside each: the two take the same pair, and
# a second parse is a second place for the preview default to be got wrong.
cmd_backfill() {
  local verb="$1"; shift
  local dir="" apply=0 expect=""
  while (( $# )); do
    case "$1" in
      --apply)  apply=1; shift ;;
      --expect) expect="$(need_operand --expect $# "${2:-}")" || return 2; shift 2 ;;
      *)        dir="$1"; shift ;;
    esac
  done
  dir="$(resolve_dir "$dir")" || return $?
  [[ -d "$dir" ]] || return 0

  local plan title
  case "$verb" in
    num)       plan="$(build_num_plan "$dir")"; title="Display-ordinal plan" ;;
    timestamp) plan="$(build_ts_plan "$dir")";  title="Timestamp normalization plan" ;;
  esac

  if (( apply )); then
    case "$verb" in
      num)       apply_num_plan "$dir" "$plan" "$expect" ;;
      timestamp) apply_ts_plan  "$dir" "$plan" "$expect" ;;
    esac
    return $?
  fi

  printf '%s — %s\n\n' "$title" "$dir"
  case "$verb" in
    num)       render_num_plan "$plan" ;;
    timestamp) render_ts_plan  "$plan" ;;
  esac
  printf '\nPLAN-HASH: %s\n' "$(plan_hash "$plan")"
  git_note "$dir"
}

# route_placement <place-token> <args...>
#   Re-exec through place.sh when the project keeps its collection on a
#   designated branch, so a backfill rewrites the issues there rather than on
#   whatever branch the developer is standing on. An explicit directory argument
#   opts out, which is also what stops the re-exec recursing.
#
#   A preview routes read-only. Previewing is the default here, and a preview
#   that published would make "writes nothing" untrue.
route_placement() {
  local token="$1"; shift
  local place="$HERE/place.sh" mode arg dir="" apply=0 skip_next=0
  [[ -r "$place" ]] || return 0
  for arg in "$@"; do
    # A flag's *value* is not a directory argument. Without skipping it, an
    # --expect hash reads as "the caller named a collection", routing is
    # declined, and the rewrite lands on the working tree instead of the
    # destination — with the gate pointed at the wrong collection besides.
    if (( skip_next )); then skip_next=0; continue; fi
    case "$arg" in
      --apply)          apply=1 ;;
      --expect)         skip_next=1 ;;
      num|timestamp|-*) ;;
      *)                dir="$arg" ;;
    esac
  done
  [[ -z "$dir" ]] || return 0
  mode="$(bash "$place" mode --place-token "$token")" || exit $?
  [[ "$mode" == "route" ]] || return 0
  local -a run=(run)
  if (( apply )); then run+=(--verb backfill); else run+=(--read); fi
  # The markers this line builds, by offset into the command below: {token} is
  # the fourth word and {} the last. The wrapper substitutes where it is told
  # and nowhere else, so forwarded text carrying either shape stays text.
  exec bash "$place" "${run[@]}" --token-at 3 --dir-at -1 -- \
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
    num|timestamp)     cmd_backfill "$@" ;;
    ""|-h|--help|help) usage ;;
    *)
      echo "error: unknown subcommand '$1' (expected: num | timestamp)" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
