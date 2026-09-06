#!/usr/bin/env bash
#
# skills/issue/scripts/new.sh — Write one issue file from fields. The single
#   issue-file emitter: every skill that files through the candidate-batch
#   contract and /jim:issue add file through here, so the issue template is
#   materialized in exactly one place. The consumer set is defined by the
#   grant, never by a count kept here — it accrues.
#
# SECURITY MODEL
#   - Untrusted body never reaches a shell command line. The caller writes the
#     body to a temp file with the Write tool and passes --body-file; this
#     script appends those bytes verbatim with `cat` (file→file copy) under a
#     `## Description` heading it writes itself. Body is never interpolated,
#     `source`d, or `eval`d.
#   - Scalar fields are YAML-encoded so an untrusted --title/--labels/--origin
#     cannot inject or alter frontmatter or cross the frontmatter/body
#     boundary: --title and --origin are each escaped into a double-quoted
#     scalar, each --labels token is reduced to the slug charset, newlines
#     are stripped.
#   - The target path is derived only through the validated id resolver: the id
#     is checked with `jimfile.sh valid-id` before any path is composed from it —
#     a stat included — so untrusted input cannot direct the write outside the
#     issues directory, nor use a composed path to answer a question about one.
#   - stdout is exactly "<slug>\t<path>"; failures go to stderr as fixed reason
#     codes — never raw --title/--body content.
#
# USAGE
#   bash new.sh --title <s> --priority <low|medium|high|critical> \
#               --labels <csv> --origin <s> --body-file <path> \
#               [--status open] [--type <issue|epic>] [--part-of <csv>] \
#               [--slug <id>] [--num <int>] \
#               [--created <ts>] [--updated <ts>] [--dir <issues_dir>] \
#               (--auto | --reviewed)
#
#   --body-file holds prose only. This script opens the body with its own
#   `## Description` heading, so a body file that repeats the heading produces
#   two, and one that opens with a heading of its own leaves the Description
#   section empty.
#
#   --auto and --reviewed are the caller's declaration about THIS batch:
#   --auto says no human has looked at it (the quiet auto-file path),
#   --reviewed says one has. Under a branch placement exactly one is required
#   and neither may be assumed — see the scrub gate below. Under the default
#   placement both are inert, so the zero-config path is unchanged.
#
#   --auto under a branch placement is refused at rc 4 unless the project has
#   acknowledged that auto-filed content publishes immediately.
#
#   An unset slug/num is resolved as a coordinated pair via jimalloc.sh
#   allocate issue (the durable id and display ordinal reserved together, one
#   CAS); an unset created/updated via jimfile.sh now. --slug/--num/--created/
#   --updated let a caller pin pre-resolved values (e.g. /jim:issue add's
#   confirm-or-edit display, or a test that wants the pure-write path with no
#   git repo required). --dir overrides the configured issues directory for
#   tests; production callers omit it.
#
# EXIT CODES
#   0  success
#   1  validation or IO failure (bad priority, invalid id, unreadable body, write error)
#   2  usage error (unknown/missing flag)
#   3  placement conflict, forwarded from place.sh. Nothing was filed at the
#      destination, and stdout carries no path — place.sh holds this script's
#      output until the publish lands and reports it on stderr otherwise. The
#      identity is spent either way: the allocator is append-only, so a re-run
#      files under a new ordinal rather than reclaiming this one.
#   4  --auto refused: the batch would publish to an unacknowledged placement.
#      The caller's remedy is to show the batch for review and file it with
#      --reviewed instead, so this is a redirection rather than a failure.
#      Distinct from the rc 2 a missing declaration gets: that one is a caller
#      defect with no remedy but to say which kind of batch this is.
#
# Conventions: set -uo pipefail; LC_ALL=C; BASH_SOURCE-relative jimfile/jimalloc paths.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"
JIMALLOC="$(dirname "$JIMFILE")/jimalloc.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
IDENTITY="$HERE/identity.sh"
RESOLVE="$HERE/resolve.sh"

# What kind of record a capture may create. Iterated rather than restated at
# the check below, so a kind added here reaches the validation without a second
# edit. index.sh declares the same vocabulary for the reading side.
readonly ISSUE_TYPES=(issue epic)

# ─── Parse flags ─────────────────────────────────────────────────────────────

title="" priority="" labels="" origin="" body_file=""
status="open" slug="" num="" created="" updated="" dir="" place_token=""
type="issue" part_of=""
auto=0 reviewed=0

# Kept whole for the placement re-exec below, which has to hand this script its
# own invocation back.
original_argv=( "$@" )

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)     title="${2-}";     shift 2 || break ;;
    --priority)  priority="${2-}";  shift 2 || break ;;
    --labels)    labels="${2-}";    shift 2 || break ;;
    --origin)    origin="${2-}";    shift 2 || break ;;
    --body-file) body_file="${2-}"; shift 2 || break ;;
    --status)    status="${2-}";    shift 2 || break ;;
    --type)      type="${2-}";      shift 2 || break ;;
    --part-of)   part_of="${2-}";   shift 2 || break ;;
    --slug)      slug="${2-}";      shift 2 || break ;;
    --num)       num="${2-}";       shift 2 || break ;;
    --created)   created="${2-}";   shift 2 || break ;;
    --updated)   updated="${2-}";   shift 2 || break ;;
    --dir)       dir="${2-}";       shift 2 || break ;;
    --place-token) place_token="${2-}"; shift 2 || break ;;
    --auto)      auto=1;            shift ;;
    --reviewed)  reviewed=1;        shift ;;
    *) echo "error: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

# ─── Placement routing ───────────────────────────────────────────────────────

# When the project keeps its issue collection on a designated branch, this
# script re-execs itself through place.sh, which materializes that branch's
# collection, runs this same invocation against it, and publishes the result.
# Routing lives behind the emitter rather than in each calling skill because the
# emitter is the single write door: every candidate batch in every group already
# comes through here, so they inherit placement without a line of change.
#
# An explicit --dir opts out. A caller that named a directory means that
# directory, and it is also what stops the re-exec from recursing.
#
# The appended --place-token is what place.sh matches against the value it
# exports; the trailing position makes it win over any stale copy already in
# the forwarded arguments.
PLACE="$HERE/place.sh"
if [[ -z "$dir" && -r "$PLACE" ]]; then
  place_mode="$(bash "$PLACE" mode --place-token "$place_token")" || exit $?
  if [[ "$place_mode" == "route" ]]; then
    # The scrub gate. `route` is exactly the condition that makes auto-filing a
    # different bargain than the one it was weighed against: the batch is
    # published to a branch the whole team reads, as it is filed, and candidate
    # text drawn from tool output or a fetched page is shared the moment it is
    # accumulated — unpublishing it means rewriting a shared branch.
    #
    # It is decided here rather than in each skill that auto-files because here
    # it is mechanical: a skill can only carry the rule as prose for an agent to
    # remember.
    #
    # What the emitter cannot do is observe whether a human looked. That makes
    # it the caller's declaration — and a declaration with a default is not one.
    # Requiring the caller to state which kind of batch this is means a
    # forgotten flag is a loud refusal at the one moment it matters, rather than
    # a silent publish to a branch the whole team reads. Both directions are
    # closed: reading the absence of --auto as "reviewed" published an
    # unreviewed batch, and inverting that to read the absence of --reviewed as
    # "unreviewed" would merely move the silent default, redirecting a genuinely
    # reviewed batch to a second review it does not need.
    #
    # Scoped to `route`, which is what makes it inert for every project without
    # a placement — the entire installed base today, and the path the
    # default-unchanged criterion protects.
    #
    # Reading auto_issue_file here instead is neither necessary nor sufficient:
    # it would refuse the legitimately degraded interactive filing, which is a
    # batch that HAS been reviewed.
    if (( auto == reviewed )); then
      if (( auto )); then
        echo "error: --auto and --reviewed contradict each other; pass exactly" \
             "one — --auto for a batch no human has reviewed, --reviewed for one" \
             "that has" >&2
      else
        echo "error: issue placement publishes to" \
             "'$(bash "$JIMCONF" get issue_placement 2>/dev/null)', so this filing" \
             "must declare whether the batch was reviewed: pass --reviewed if a" \
             "human looked at it, or --auto if none did" >&2
      fi
      exit 2
    fi
    if (( auto )) && [[ "$(bash "$JIMCONF" get issue_placement_ack 2>/dev/null)" != "true" ]]; then
      echo "error: auto-file refused — issue placement publishes to" \
           "'$(bash "$JIMCONF" get issue_placement 2>/dev/null)', so this batch" \
           "needs a look before it is shared. Show the batch for review, or set" \
           "issue_placement_ack = \"true\" to accept auto-filing to that branch." >&2
      exit 4
    fi
    # This line appends --dir {} --place-token {token}, so {} is third from the
    # end and {token} last. The forwarded argv ahead of them is user text and is
    # never examined — a --title of exactly {} is a title.
    exec bash "$PLACE" run --verb file --dir-at -3 --token-at -1 -- \
      bash "${BASH_SOURCE[0]}" "${original_argv[@]}" --dir '{}' --place-token '{token}'
  fi
fi

# ─── Validate required inputs ────────────────────────────────────────────────

[[ -n "$title"     ]] || { echo "error: --title is required" >&2; exit 2; }
[[ -n "$priority"  ]] || { echo "error: --priority is required" >&2; exit 2; }
[[ -n "$origin"    ]] || { echo "error: --origin is required" >&2; exit 2; }
[[ -n "$body_file" ]] || { echo "error: --body-file is required" >&2; exit 2; }
[[ -r "$body_file" ]] || { echo "error: --body-file is not readable" >&2; exit 1; }

case "$priority" in
  low|medium|high|critical) ;;
  *) echo "error: invalid priority (expected low|medium|high|critical)" >&2; exit 1 ;;
esac

case "$status" in
  open|closed) ;;
  *) echo "error: invalid status (expected open|closed)" >&2; exit 1 ;;
esac

# Iterated rather than pattern-matched, so the declaration above is the single
# statement of what a kind may be and a kind added there needs no edit here.
# The refusal names the field and the accepted set, never the rejected value —
# a kind arrives as the same model-produced text a title does. Above the
# allocator with the other enum checks, so refusing costs no ordinal.
type_ok=0
for _t in "${ISSUE_TYPES[@]}"; do
  [[ "$type" == "$_t" ]] && { type_ok=1; break; }
done
if (( ! type_ok )); then
  _types_expected="$(printf '%s|' "${ISSUE_TYPES[@]}")"
  echo "error: invalid type (expected ${_types_expected%|})" >&2
  exit 1
fi

# ─── Resolve the filer ───────────────────────────────────────────────────────

# Ahead of the allocator on purpose: the allocator is append-only, so a filing
# refused after it runs spends an ordinal no file will ever carry. Refusing here
# costs nothing and leaves the collection exactly as it was.
#
# identity.sh has already reported which way it failed; this line says what that
# cost. Both are fixed strings — neither carries a field of this filing.
filed_by="$(bash "$IDENTITY" resolve)" || {
  echo "error: refusing to file without a recordable identity" >&2
  exit 1
}

# ─── Resolve the issues directory ────────────────────────────────────────────

# Above the allocator, not beside its first use. The validations that refuse a
# filing need a collection to resolve a reference against, and the allocator is
# append-only — so a check that runs below it burns an ordinal no later run
# reclaims, whether or not the filing then succeeds. This resolution depends on
# nothing the allocation produces, which is what makes the ordering free.
#
# Used by the pre-spend reference checks, the local-collision handling further
# down, and the final write path.
if [[ -n "$dir" ]]; then
  issues_dir="$dir"
else
  issues_dir="$(bash "$JIMFILE" path issue)" || {
    echo "error: could not resolve issues directory" >&2; exit 1; }
fi
issues_dir="${issues_dir%/}"

# ─── Resolve the umbrellas this filing joins ─────────────────────────────────

# Each reference is resolved through resolve.sh, the same definition the
# lifecycle verbs resolve through, so a reference that works on `join` works
# here and the two paths cannot disagree about what exists. Resolution runs
# above the allocator: an umbrella that does not resolve refuses a filing that
# has not yet spent an ordinal.
#
# The RESOLVED id is what gets written, verbatim. It has already cleared
# valid-id twice and named a real record, so it is not put through the label
# encoder below — that encoder is a lossy normalizer for free text and reduces
# anything outside [a-z0-9-], while an id may legitimately carry uppercase and
# a dot. Encoding one would write a membership naming a record that does not
# exist.
part_of_enc=""
if [[ -n "$part_of" ]]; then
  IFS=',' read -ra _pref_parts <<< "$(printf '%s' "$part_of" | tr '\n\r' '  ')"
  for _raw in "${_pref_parts[@]}"; do
    _ref="$(printf '%s' "$_raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "$_ref" ]] || continue
    if ! _res="$(bash "$RESOLVE" "$issues_dir" "$_ref" 2>/dev/null)"; then
      echo "error: --part-of names no issue in the collection" >&2
      exit 1
    fi
    _rslug="${_res%%$'\t'*}"
    _rkind="${_res##*$'\t'}"
    if [[ "$_rkind" != "epic" ]]; then
      # Name the kind only when it is one the schema declares. A hand-edited
      # record can carry anything in that field, and a refusal is not the place
      # to render arbitrary file content.
      _named=""
      for _t in "${ISSUE_TYPES[@]}"; do
        [[ "$_rkind" == "$_t" ]] && { _named="$_rkind"; break; }
      done
      if [[ -n "$_named" ]]; then
        echo "error: --part-of names a record of type '$_named', not an epic" >&2
      else
        echo "error: --part-of names a record that is not an epic" >&2
      fi
      exit 1
    fi
    # An umbrella groups work, so it may not itself be grouped. Checked after
    # the target's kind, in the order the lifecycle verb checks the same pair,
    # so the two write paths refuse the same state for the same stated reason.
    # Without it the capture path writes exactly what `join` refuses, which
    # makes the containment a property of the route rather than of the record.
    if [[ "$type" == "epic" ]]; then
      echo "error: an epic cannot belong to an epic" >&2
      exit 1
    fi
    if [[ -z "$part_of_enc" ]]; then part_of_enc="$_rslug"
    else part_of_enc="$part_of_enc, $_rslug"; fi
  done
fi

# ─── Resolve identity (overrides win; else compose via jimalloc.sh) ──────────

# Unset slug/num are resolved together, through the coordination allocator —
# one call returns both the durable id and the display ordinal in the same
# reservation, so a caller that pins neither gets a coordinated pair rather
# than two independently-derived values.
slug_via_alloc=0
if [[ -z "$slug" || -z "$num" ]]; then
  alloc_out="$(bash "$JIMALLOC" allocate issue "$title")" || {
    echo "error: could not allocate issue identity" >&2; exit 1; }
  alloc_fullid="${alloc_out%%$'\t'*}"
  alloc_num="${alloc_out##*$'\t'}"
  if [[ -z "$slug" ]]; then
    slug="$alloc_fullid"
    slug_via_alloc=1
  fi
  [[ -n "$num"  ]] || num="$alloc_num"
fi
[[ -n "$created" ]] || created="$(bash "$JIMFILE" now)"
[[ -n "$updated" ]] || updated="$created"

# num guard: a real ordinal (all-digits) or a provisional ordinal — the
# reserved "P-" prefix over a token that itself passes the id boundary.
# Applies to both an unset num's fallback and a caller-supplied --num, so
# neither path can smuggle free text into stored/rendered frontmatter.
num_valid=0
if [[ "$num" =~ ^[0-9]+$ ]]; then
  num_valid=1
elif [[ "$num" == P-* ]] && bash "$JIMFILE" valid-id "${num#P-}" >/dev/null 2>&1; then
  num_valid=1
fi
(( num_valid )) || { echo "error: --num must be a positive integer or a P-<id> provisional ordinal" >&2; exit 1; }

# Provisional local disambiguation / real-mode drift guard: only the id this
# call resolved itself is eligible — a caller-pinned --slug is never altered.
# A provisional durable id is computed over an empty log (no registry to
# disambiguate against), so the local clone suffixes it against the on-disk
# collection instead, mirroring the suffix into the stored provisional
# ordinal. A real ordinal is already registry-disambiguated, so a local
# filename collision here is tree/registry drift — refused, never overwritten.
# Always validate the id through the single security boundary before composing a
# path — even a caller-supplied --slug, and even an allocator-derived one.
#
# Before, not after: a stat composes a path too. It answers a question about the
# filesystem, which is exactly the read the boundary governs, and an
# allocator-derived id is not exempt — the sanitization that produced it lives
# in another group, so the value is not provably validator-clean here.
bash "$JIMFILE" valid-id "$slug" || { echo "error: invalid issue id" >&2; exit 1; }

if (( slug_via_alloc )); then
  if [[ "$num" == P-* ]]; then
    base_slug="$slug"
    suffix=1
    while [[ -e "$issues_dir/$slug.md" ]]; do
      suffix=$((suffix + 1))
      slug="${base_slug}-${suffix}"
      # A derived id is a new id, and it composes the next iteration's path.
      # The suffix can also push a slug already near the cap past it, which is
      # a refusal rather than something to discover after the loop.
      bash "$JIMFILE" valid-id "$slug" || { echo "error: invalid issue id" >&2; exit 1; }
    done
    num="P-${slug}"
  elif [[ -e "$issues_dir/$slug.md" ]]; then
    echo "error: local issue file already exists for allocator-issued id '$slug' (registry drift)" >&2
    exit 1
  fi
fi

path="$issues_dir/$slug.md"

# ─── Encode untrusted scalar fields ──────────────────────────────────────────

# --title: collapse newlines, escape backslash then double-quote for a YAML
# double-quoted scalar. Order matters (backslash first).
title_enc="$(printf '%s' "$title" | tr '\n\r' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"

# --origin: the same encoding --title gets, and for the same reason. The
# convention is a source path or the `conversation` sentinel, but nothing
# mechanical enforces either — it is composed by a skill's prompt, which makes
# it model-produced text of the same trust class as a title. Emitted bare, a
# value like `foo: bar`, `[a, b]` or `!!tag` changes the parsed type or leaves
# the frontmatter unparseable for a real YAML consumer.
origin_enc="$(printf '%s' "$origin" | tr '\n\r' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"

# --labels: csv → slug tokens. Any character outside [a-z0-9-] is reduced, so a
# label containing ] , " or [[ cannot break the inline YAML array.
labels_enc=""
labels="$(printf '%s' "$labels" | tr '\n\r' '  ')"
IFS=',' read -ra _label_parts <<< "$labels"
for _raw in "${_label_parts[@]}"; do
  _tok="$(printf '%s' "$_raw" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9-]/-/g; s/-\+/-/g; s/^-//; s/-$//')"
  [[ -n "$_tok" ]] || continue
  if [[ -z "$labels_enc" ]]; then labels_enc="$_tok"; else labels_enc="$labels_enc, $_tok"; fi
done

# ─── Atomic write (tmp + mv) ─────────────────────────────────────────────────

mkdir -p "$(dirname "$path")" || { echo "error: cannot create issues directory" >&2; exit 1; }

tmpfile="$(mktemp "$(dirname "$path")/.new.tmp.XXXXXX")" || {
  echo "error: cannot create tmp file" >&2; exit 1; }
trap 'rm -f "$tmpfile"' EXIT INT TERM

{
  printf -- '---\n'
  printf 'id: %s\n' "$slug"
  printf 'num: %s\n' "$num"
  printf 'title: "%s"\n' "$title_enc"
  printf 'status: %s\n' "$status"
  printf 'priority: %s\n' "$priority"
  # Cleared the kind enum above, so it is one of the declared vocabulary's
  # members and can neither close this scalar nor open a field of its own.
  printf 'type: %s\n' "$type"
  # The filer cleared a positive character gate, so it cannot close this scalar
  # or open a field of its own. A new issue is unheld and has never been
  # finished, so the holder and outcome start empty.
  printf 'filed-by: "%s"\n' "$filed_by"
  printf 'claimed-by: ""\n'
  printf 'outcome: ""\n'
  printf 'labels: [%s]\n' "$labels_enc"
  # Every part-of entry resolved to a record of kind epic above, so each is a
  # validated id and none can close the array or open a field of its own.
  printf 'relations:\n  blocks: []\n  depends-on: []\n  related-to: []\n  duplicates: []\n'
  printf '  part-of: [%s]\n' "$part_of_enc"
  printf 'created: %s\n' "$created"
  printf 'updated: %s\n' "$updated"
  printf 'origin: "%s"\n' "$origin_enc"
  printf -- '---\n'
  printf '\n## Description\n\n'
  cat "$body_file"
  # Guarantee a trailing newline regardless of the body file's last byte.
  [[ -z "$(tail -c1 "$body_file")" ]] || printf '\n'
} > "$tmpfile" || { echo "error: write failed" >&2; exit 1; }

mv "$tmpfile" "$path" || { echo "error: atomic rename failed" >&2; exit 1; }
trap - EXIT INT TERM

# Inside a placement run the file was composed in a temp directory that will not
# exist a moment from now, so report where it actually lives on the destination
# branch. The prefix is trusted only when this invocation's token matches the
# one place.sh exported — the same pairing that governs routing.
out_path="$path"
if [[ -n "$place_token" && "$place_token" == "${JIM_PLACE_TOKEN:-}" \
      && -n "${JIM_PLACE_PREFIX:-}" ]]; then
  out_path="${JIM_PLACE_PREFIX%/}/$slug.md"
fi
printf '%s\t%s\n' "$slug" "$out_path"
