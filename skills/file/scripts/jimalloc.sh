#!/usr/bin/env bash
#
# skills/file/scripts/jimalloc.sh — jim's ID-coordination allocator.
#
# PURPOSE
#   Hand out jim's IDs (spec ordinals, issue ordinals + durable issue ids, and
#   group names) through a shared, append-only registry so separate users on
#   separate clones never claim the same ID. Allocation appends a
#   compare-and-swap (CAS)-guarded record to a per-kind log on a dedicated
#   coordination branch, using git plumbing so the developer's working tree is
#   never disturbed mid-flow.
#
#   This is jim's first script to fetch/push and write a shared ref. The
#   coordination branch is writable by anyone who can push it, so every value
#   read back from the registry or from config is revalidated through
#   jimfile.sh's id/slug/path boundary before it reaches a git command, a ref,
#   or a filesystem path (the single security boundary — no fourth copy).
#
# CLI SUMMARY
#   bash jimalloc.sh allocate spec  <group> <subject>   → "<group>/<NNN>"
#   bash jimalloc.sh allocate issue <subject>           → "<full-id>\t<num>"
#   bash jimalloc.sh peek     spec  <group>             → advisory "<group>/<NNN>"
#     `allocate spec` / `peek spec` refuse a group that has been renamed away and
#     name the redirect; add --follow-redirect to accept it. The group they
#     answer with is authoritative and may differ from the one asked about.
#   bash jimalloc.sh peek     issue                     → advisory "<num>"
#   bash jimalloc.sh resolve  spec  <group>/<NNN>       → current "<group>/<NNN>"
#   bash jimalloc.sh resolve  issue <num|full-id>       → current id
#   bash jimalloc.sh seed     [--apply]                 preview/apply a one-time bootstrap
#   bash jimalloc.sh -c <path> <subcmd>                 use <path> as jimconf.toml
#
# EXIT CODES
#   0  Success.
#   1  Hard failure (unreachable coordination point / erosion detected /
#      retries exhausted / a rejected registry or config token).
#   2  Malformed invocation (missing argument, unknown subcommand).
#

set -uo pipefail
# LC_ALL=C — locale-independent text handling (matches jimfile.sh / jimconf.sh).
export LC_ALL=C
# Non-interactive git: a mid-flow credential prompt must never hang a consumer;
# an unreachable coordination point surfaces as a failed command, not a stall.
export GIT_TERMINAL_PROMPT=0

# ─── Section: Globals ────────────────────────────────────────────────────────

# Sibling platform CLIs, resolved BASH_SOURCE-relative so the composition
# travels with the plugin tree regardless of install scope. jimfile.sh is the
# id/slug/date/path boundary; jimconf.sh resolves the id_coordination_* keys.
JIMFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jimfile.sh"
JIMCONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../conf/scripts" && pwd)/jimconf.sh"

# Optional -c <path> override for jimconf.toml. Empty when not supplied;
# production consumers never pass it (tests and ad-hoc inspection do).
CONFIG_FILE=""

# Reserved provisional-ordinal prefix. A provisional identifier carries this in
# its ordinal slot, keeping it grammar-distinct from every allocated ordinal
# (allocated ordinals are ^[0-9]+$), so the two can never be confused and a
# provisional can never enter the registry high-water. Uppercase, so it cannot
# collide with a jimfile.sh slug (slugs are lowercase).
ALLOC_PROV_PREFIX="P-"

# ─── Section: Record layer (pure — operates on a log, no git) ────────────────
#
# The registry is one append-only, space-separated, newline-delimited log per
# kind, file-order authoritative. It is writable by anyone who can push the
# coordination branch, so it is untrusted data: every id/group/slug token read
# back is revalidated through jimfile.sh's boundary before use, and a malformed
# record is degraded and skipped — never executed (parsed as data; never sourced).
#
# Record grammar (fields after `<kind> <verb>`):
#   spec  allocate <group>/<NNN> <slug> <date> <who>
#   group allocate <group> <date> <who>
#   issue allocate <NNN> <full-id> <date> <who>
#   spec  rename   <group>/<NNN> <newgroup>/<newNNN> <date>
#   group rename   <old-group> <new-group> <date>
#   issue rename   <NNN> <newNNN> <date>
# Only allocate records are emitted by this build; rename/group-rename are parsed
# and resolved (format frozen) so a later spec can begin emitting them unchanged.

# alloc_log_file <kind> — the log file name for <kind>. Group records ride the
# spec log so resolving a spec id replays a single file.
alloc_log_file() {
  case "$1" in
    spec|group) printf 'specs.log' ;;
    issue)      printf 'issues.log' ;;
    *) return 1 ;;
  esac
}

# alloc_read_log <kind> — print the current registry log for <kind> to stdout
# (empty if none). Source precedence:
#   1. $JIMALLOC_REGISTRY_DIR (offline/local staging + test seam), if set.
#   2. the coordination branch via git plumbing (wired in a later task).
alloc_read_log() {
  local kind="$1" file
  file="$(alloc_log_file "$kind")" || { echo "error: no log for kind '$kind'" >&2; return 1; }
  if [[ -n "${JIMALLOC_REGISTRY_DIR:-}" ]]; then
    local p="$JIMALLOC_REGISTRY_DIR/$file"
    [[ -f "$p" ]] && cat -- "$p"
    return 0
  fi
  # Read the local coordination-branch ref (kept in sync by allocate on both
  # tiers). peek refreshes it from the remote first; resolve reads as-is.
  local branch
  branch="$(alloc_coord_branch)" || return 1
  git cat-file -p "refs/heads/$branch:$file" 2>/dev/null || true
  return 0
}

# alloc_valid_token <tok> — exit 0 iff <tok> passes jimfile.sh's id boundary
# (is_valid_id). THE single security boundary — no fourth copy. Forecloses
# option-injection (leading '-'), path traversal ('..'), and ref metacharacters,
# all of which fall outside the ^[A-Za-z0-9][A-Za-z0-9._-]*$ allowlist.
alloc_valid_token() {
  bash "$JIMFILE" valid-id "$1" >/dev/null 2>&1
}

# alloc_is_prov_form <name> — exit 0 iff <name> is the reserved provisional
# ordinal form: the reserved prefix over a boundary-valid token, exactly what
# alloc_prov_ordinal builds. Narrow by construction — a name that merely starts
# with the prefix but carries a token the boundary rejects is not the reserved
# form, so nothing malformed can pass itself off as reserved.
alloc_is_prov_form() {
  local name="$1" tok
  [[ "$name" == "$ALLOC_PROV_PREFIX"* ]] || return 1
  tok="${name#"$ALLOC_PROV_PREFIX"}"
  [[ -n "$tok" ]] || return 1
  alloc_valid_token "$tok"
}

# alloc_valid_provid <id> — exit 0 iff <id> is "<group>/P-<date>-<slug>": exactly
# one '/', a boundary-valid group, and an ordinal slot in the reserved
# provisional form whose body splits into an 8-digit issuance date and a
# boundary-valid slug. Grammar-distinct from alloc_valid_specid by construction:
# no id satisfies both.
alloc_valid_provid() {
  local id="$1" grp tok body date slug
  [[ "$id" == */* ]] || return 1
  grp="${id%/*}"; tok="${id##*/}"
  [[ "$grp" == *"/"* ]] && return 1
  alloc_valid_token "$grp" || return 1
  alloc_is_prov_form "$tok" || return 1
  body="${tok#"$ALLOC_PROV_PREFIX"}"
  date="${body%%-*}"; slug="${body#*-}"
  [[ "$date" =~ ^[0-9]{8}$ ]] || return 1
  [[ -n "$slug" && "$slug" != "$body" ]] || return 1
  alloc_valid_token "$slug"
}

# alloc_valid_specid <id> — exit 0 iff <id> is "<group>/<NNN>": exactly one '/',
# a boundary-valid group, and an all-digits ordinal.
alloc_valid_specid() {
  local id="$1" grp num
  [[ "$id" == */* ]] || return 1
  grp="${id%/*}"; num="${id##*/}"
  [[ "$grp" == *"/"* ]] && return 1
  [[ "$num" =~ ^[0-9]+$ ]] || return 1
  alloc_valid_token "$grp"
}

# alloc_canon_specid <group>/<ord> — print the id with its ordinal in canonical
# form: the documented 3-digit zero-padded width, or its own width when wider.
# rc 1 if the id is not a spec id, or its ordinal is wider than the registry
# could be rebuilt from.
#
#   A spec ordinal is a NUMBER written zero-padded, so 'core/18' and 'core/018'
#   name one identity. The log is append-only and push-writable, so both
#   spellings can be present in it; comparing them as strings would let a
#   resumed realization miss its own prior record, or let resolve and the fold
#   disagree about which ordinals are taken. Every site that compares or reports
#   an ordinal passes it through here first, so there is one spelling to compare.
#
#   The WIDTH bound is deliberate and applies at every one of those sites,
#   `resolve` included: ALLOC_MAX_ORD_DIGITS is the width the registry can be
#   rebuilt from, so an ordinal wider than it is not one this system can
#   represent — and resolve must not hand back an id the seed could not
#   reproduce. Note the consequence on a rename record, where both sides pass
#   through here: the record is dropped when EITHER side fails, so an over-wide
#   source also drops its destination's establishing claim.
alloc_canon_specid() {
  local id="$1" grp num
  alloc_valid_specid "$id" || return 1
  grp="${id%/*}"; num="${id##*/}"
  (( ${#num} > ALLOC_MAX_ORD_DIGITS )) && return 1
  printf '%s/%03d\n' "$grp" "$((10#$num))"
}

# alloc_sanitize_who <raw> — reduce a free-text provenance value to a single safe
# token: every character outside [A-Za-z0-9._@-] (space, tab, NEWLINE, CR, and
# ref/shell metacharacters) becomes '-', runs collapse, ends trim, cap 64. A
# newline here would otherwise forge a second record on a plain grep/replay; it
# is advisory provenance only, so lossy normalization is acceptable.
alloc_sanitize_who() {
  printf '%s' "${1:-}" \
    | tr -c 'A-Za-z0-9._@-' '-' \
    | sed 's/-\+/-/g; s/^-//; s/-$//' \
    | cut -c1-64
}

# alloc_encode_allocate_spec  <specid> <slug> <date> <who>
# alloc_encode_allocate_group <group> <date> <who>
# alloc_encode_allocate_issue <num> <full-id> <date> <who>
#   Build exactly one record line. Fixed fields are pre-validated single tokens
#   supplied by the allocate path; the trailing free-text <who> is sanitized
#   here (write-side complement to read-side revalidation).
alloc_encode_allocate_spec() {
  printf 'spec allocate %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}
alloc_encode_allocate_group() {
  printf 'group allocate %s %s %s\n' "$1" "$2" "$(alloc_sanitize_who "${3:-}")"
}
alloc_encode_allocate_issue() {
  printf 'issue allocate %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}

# alloc_resolve_spec <queried>  (log on stdin)
#   Forward-replay a spec id to its current name. Replay is anchored at the
#   queried id's last *establishing* record — an allocate record naming it, or a
#   rename record naming it as the destination, whichever comes later — so a
#   string reused by either route does not inherit an earlier referent's rename
#   history. A rename *source* is a vacating event, not an establishing one, and
#   does not anchor. If the queried id has no establishing record of its own (it
#   may be a member of a renamed-into group), replay runs from the top. Each
#   record applies at most once in file order, so a reverted rename cycle
#   terminates. rc 1 if the id is invalid or never
#   appears in the registry (as an allocate id, a rename target, or a member of
#   a renamed-into group).
alloc_resolve_spec() {
  local queried="$1"
  alloc_valid_specid "$queried" || { echo "error: invalid spec id '$queried'" >&2; return 1; }
  # Past the shape guard the only way canonicalization fails is the width bound,
  # so the message names it rather than repeating "invalid".
  queried="$(alloc_canon_specid "$queried")" \
    || { echo "error: spec id '$1' exceeds the ordinal width the registry can be rebuilt from (max $ALLOC_MAX_ORD_DIGITS digits)" >&2; return 1; }
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6
  local qgroup="${queried%/*}"
  local anchor=-1 known=0
  # Record ids are canonicalized before every comparison, so a record spelling
  # an ordinal unpadded still anchors and still replays.
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == allocate ]]; then
      c3="$(alloc_canon_specid "$c3")" || continue
      [[ "$c3" == "$queried" ]] && { anchor=$i; known=1; }
    elif [[ "$c1" == spec && "$c2" == rename ]]; then
      c3="$(alloc_canon_specid "$c3")" && c4="$(alloc_canon_specid "$c4")" || continue
      [[ "$c4" == "$queried" ]] && { anchor=$i; known=1; }
    elif [[ "$c1" == group && "$c2" == rename ]]; then
      alloc_valid_token "$c3" && alloc_valid_token "$c4" || continue
      [[ "$c4" == "$qgroup" ]] && known=1
    fi
  done
  local current="$queried"
  for ((i=0; i<n; i++)); do
    (( anchor >= 0 && i <= anchor )) && continue
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == rename ]]; then
      c3="$(alloc_canon_specid "$c3")" && c4="$(alloc_canon_specid "$c4")" || continue
      [[ "$c3" == "$current" ]] && current="$c4"
    elif [[ "$c1" == group && "$c2" == rename ]]; then
      alloc_valid_token "$c3" && alloc_valid_token "$c4" || continue
      [[ "$current" == "$c3"/* ]] && current="$c4/${current#*/}"
    fi
  done
  (( known )) || { echo "error: spec id '$queried' not allocated" >&2; return 1; }
  printf '%s\n' "$current"
}

# alloc_resolve_issue <queried>  (log on stdin)
#   Resolve an issue citation (an ordinal or a durable full-id) to its current
#   ordinal, following issue-rename records. A full-id is first mapped to its
#   ordinal via its allocate record. Same anchoring / cycle-safety discipline as
#   the spec resolver — the anchor is the ordinal's last establishing record,
#   allocate or rename destination; issues have no group dimension.
alloc_resolve_issue() {
  local queried="$1"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6
  local target=""
  if [[ "$queried" =~ ^[0-9]+$ ]]; then
    target="$queried"
  else
    alloc_valid_token "$queried" || { echo "error: invalid issue id '$queried'" >&2; return 1; }
    for ((i=0; i<n; i++)); do
      read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
      [[ "$c1" == issue && "$c2" == allocate ]] || continue
      [[ "$c3" =~ ^[0-9]+$ ]] || continue
      alloc_valid_token "$c4" || continue
      [[ "$c4" == "$queried" ]] && target="$c3"
    done
    [[ -n "$target" ]] || { echo "error: issue id '$queried' not allocated" >&2; return 1; }
  fi
  local anchor=-1 known=0
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    if [[ "$c1" == issue && "$c2" == allocate ]]; then
      [[ "$c3" =~ ^[0-9]+$ ]] || continue
      [[ "$c3" == "$target" ]] && { anchor=$i; known=1; }
    elif [[ "$c1" == issue && "$c2" == rename ]]; then
      [[ "$c3" =~ ^[0-9]+$ && "$c4" =~ ^[0-9]+$ ]] || continue
      [[ "$c4" == "$target" ]] && { anchor=$i; known=1; }
    fi
  done
  local current="$target"
  for ((i=0; i<n; i++)); do
    (( anchor >= 0 && i <= anchor )) && continue
    read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
    [[ "$c1" == issue && "$c2" == rename ]] || continue
    [[ "$c3" =~ ^[0-9]+$ && "$c4" =~ ^[0-9]+$ ]] || continue
    [[ "$c3" == "$current" ]] && current="$c4"
  done
  (( known )) || { echo "error: issue '$queried' not allocated" >&2; return 1; }
  printf '%s\n' "$current"
}

# The widest ordinal this allocator will compute with, in digits. One value
# decides legality for spec ids and issue ordinals, on the read path and in the
# bootstrap alike: an ordinal the fold skips as malformed must also be one the
# seed refuses, or the allocator could mint a repository that can never be
# rebuilt into a registry from its own tree. 15 digits stays well inside 64-bit
# arithmetic, and no plausible ordinal comes near it.
ALLOC_MAX_ORD_DIGITS=15

# alloc_group_alias_map  (log on stdin)
#   Print one TAB-separated "<old>\t<current>" line per group named as the source
#   of a group-rename record, with the chain fully followed: dashboard→ui→surface
#   yields both "dashboard<TAB>surface" and "ui<TAB>surface". Empty output when
#   the log holds no group rename. Both tokens of a record are validated; a
#   malformed record is skipped.
#
#   The walk each line reports is the resolver's own: records apply in file
#   order, each at most once, so the map and forward-replay resolution always
#   agree on where a group went. That ordering also means a group renamed away
#   and later reused keeps the two answers distinct — with `a→b` before `c→a`,
#   `a` maps to `b` while `c` maps to `a`, because `a→b` is already spent by the
#   time `c` becomes `a`.
#
#   Resolved bottom-up so no chain is ever re-walked: scanning the records in
#   reverse, each one's answer is either its destination or the already-computed
#   answer of the next record that renames that destination. Every record is
#   resolved exactly once, and a crafted cycle cannot spin because a record only
#   ever defers to a strictly later one. Building the map forward instead would
#   cost a re-point of every entry per record — quadratic on input any pusher can
#   grow.
alloc_group_alias_map() {
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4
  local -a src=() dst=()
  local m=0
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 _ <<< "${lines[i]}"
    [[ "$c1" == group && "$c2" == rename ]] || continue
    alloc_valid_token "$c3" && alloc_valid_token "$c4" || continue
    src[m]="$c3"; dst[m]="$c4"; m=$((m + 1))
  done
  (( m )) || return 0
  local -A nextsrc=() landing=()
  local j jn
  for ((j=m-1; j>=0; j--)); do
    jn="${nextsrc[${dst[j]}]:-}"
    if [[ -n "$jn" ]]; then
      landing[$j]="${landing[$jn]}"
    else
      landing[$j]="${dst[j]}"
    fi
    nextsrc[${src[j]}]=$j
  done
  # nextsrc now holds each group's *first* record, which is where its walk starts.
  local g
  for g in "${!nextsrc[@]}"; do
    printf '%s\t%s\n' "$g" "${landing[${nextsrc[$g]}]}"
  done
}

# alloc_fold_max_spec <group>  (log on stdin) → integer
#   The highest ordinal <group> holds under its current or any former name: the
#   high-water. Folds allocate ids, rename destinations, and rename *sources* —
#   a source is an ordinal the group held and can never reissue, so counting it
#   makes the permanent gap unconditional instead of resting on every source
#   having its own allocate record. RECORD-side group membership is decided
#   through alloc_group_alias_map, so a record filed under a former name still
#   counts.
#
#   CONTRACT: <group> is the caller-RESOLVED current group name. This fold never
#   resolves its own argument. Both production callers must resolve anyway — for
#   their output and their redirect refusal — and resolving in two layers is how
#   a caller's already-current name gets aliased a second time onto a DIFFERENT
#   group's high-water when a freed name has been taken over. Asking under a name
#   the group no longer answers to therefore yields 0, not that group's ordinals.
#
#   Every candidate is revalidated at the id boundary and skipped if it fails,
#   independently of its sibling field. An ordinal wider than
#   ALLOC_MAX_ORD_DIGITS is skipped as malformed. Prints 0 when the group holds
#   nothing. Only ever raises: a crafted record can waste an ordinal, never make
#   a consumed one available again.
alloc_fold_max_spec() {
  local group="$1"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 max=0 g num cand
  local -A alias=()
  local k v
  if (( n )); then
    while IFS=$'\t' read -r k v; do
      [[ -n "$k" ]] && alias["$k"]="$v"
    done < <(printf '%s\n' "${lines[@]}" | alloc_group_alias_map)
  fi
  local -a cands=()
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 _ <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == allocate ]]; then
      cands=("$c3")
    elif [[ "$c1" == spec && "$c2" == rename ]]; then
      cands=("$c3" "$c4")
    else
      continue
    fi
    for cand in "${cands[@]}"; do
      alloc_valid_specid "$cand" || continue
      num="${cand##*/}"
      (( ${#num} > ALLOC_MAX_ORD_DIGITS )) && continue
      g="${cand%/*}"
      g="${alias[$g]:-$g}"
      [[ "$g" == "$group" ]] || continue
      num=$((10#$num))          # base-10 — never octal on leading zeros
      (( num > max )) && max=$num
    done
  done
  printf '%s\n' "$max"
}

# alloc_fold_max_issue  (issues log on stdin) → integer
#   The highest issue ordinal the registry has ever handed out. Same fold as the
#   spec side — allocate ids, rename destinations, and rename sources — minus the
#   group dimension. An ordinal that is not pure digits, or wider than
#   ALLOC_MAX_ORD_DIGITS, is skipped as malformed. Prints 0 for an empty log.
#
#   The ordinal is judged on its own: a record whose durable id fails the id
#   boundary still counts its ordinal, because the ordinal was consumed whether
#   or not its sibling field is readable. Callers needing a trustworthy durable
#   id gate that separately.
alloc_fold_max_issue() {
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 max=0 cand
  local -a cands=()
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 _ <<< "${lines[i]}"
    if [[ "$c1" == issue && "$c2" == allocate ]]; then
      cands=("$c3")
    elif [[ "$c1" == issue && "$c2" == rename ]]; then
      cands=("$c3" "$c4")
    else
      continue
    fi
    for cand in "${cands[@]}"; do
      [[ "$cand" =~ ^[0-9]+$ ]] || continue
      (( ${#cand} > ALLOC_MAX_ORD_DIGITS )) && continue
      cand=$((10#$cand))
      (( cand > max )) && max=$cand
    done
  done
  printf '%s\n' "$max"
}

# alloc_next_id_spec <group> [--follow-redirect]  (log on stdin)
#   The next spec id for <group>: the group's high-water + 1, zero-padded to
#   three digits (a wider ordinal prints at its natural width). Ids are never
#   reused, so a vacated ordinal is a permanent gap — see alloc_fold_max_spec for
#   what the high-water counts and how a renamed group's former names are folded
#   in.
#
#   THE RETURNED GROUP IS AUTHORITATIVE AND MAY DIFFER FROM <group>. Comparing
#   the two is how a caller detects that a redirect was applied; nothing else
#   promises they match.
#
#   Two failure modes a consumer must tell apart:
#     rc 1, "group renamed"   — <group> has been renamed away and the redirect
#                               was not acknowledged; stderr names the target.
#                               RETRYABLE: pass --follow-redirect, or ask under
#                               the current name. Refusing rather than
#                               substituting is what keeps a crafted group-rename
#                               record from silently redirecting a namespace: a
#                               notice on stderr informs only whoever reads
#                               stderr, while a non-zero exit is not discardable.
#     rc 1, "group exhausted" — the next ordinal would be wider than
#                               ALLOC_MAX_ORD_DIGITS, so the bootstrap could
#                               never read it back. Unreachable for plausible
#                               ordinals; in practice it means a crafted record
#                               sits at the width limit. TERMINAL: acknowledging
#                               changes nothing.
alloc_next_id_spec() {
  local group="${1:-}" follow=0
  shift || true
  local a
  for a in "$@"; do
    case "$a" in
      --follow-redirect) follow=1 ;;
      *) echo "error: unknown option '$a'" >&2; return 2 ;;
    esac
  done
  alloc_valid_token "$group" || { echo "error: invalid group '$group'" >&2; return 1; }
  local -a lines=(); mapfile -t lines
  local log=""
  (( ${#lines[@]} )) && log="$(printf '%s\n' "${lines[@]}")"
  local current="$group" k v
  while IFS=$'\t' read -r k v; do
    [[ "$k" == "$group" ]] && current="$v"
  done < <(printf '%s\n' "$log" | alloc_group_alias_map)
  if [[ "$current" != "$group" ]] && (( ! follow )); then
    echo "error: group renamed — '$group' is now '$current'; ask under that name, or pass --follow-redirect to accept the redirect" >&2
    return 1
  fi
  local max next
  max="$(printf '%s\n' "$log" | alloc_fold_max_spec "$current")" || return 1
  next=$((max + 1))
  if (( ${#next} > ALLOC_MAX_ORD_DIGITS )); then
    echo "error: group exhausted — '$current' has no ordinal left that the registry could be rebuilt from" >&2
    return 1
  fi
  printf '%s/%03d\n' "$current" "$next"
}

# alloc_next_num_issue  (log on stdin)
#   The next issue display ordinal: the high-water + 1, unpadded (issue ordinals
#   render as #N). Empty registry → 1. See alloc_fold_max_issue for what counts.
alloc_next_num_issue() {
  local max
  max="$(alloc_fold_max_issue)" || return 1
  printf '%s\n' $((max + 1))
}

# alloc_durable_issue_id <subject> [num]  (issues log on stdin)
#   Compute the durable issue id — the configured issue_id_prefix scheme's prefix
#   (re-derived via jimfile.sh prefix-from from an ISO `now` and the coordinated
#   ordinal <num>) plus the slug — and disambiguate it with a -2 / -3 … suffix
#   when the computed form already appears as a full-id in the registry. The
#   ordinal and the durable form are guarded by the same append-only registry.
#
#   Degrades to the date-slug form whenever the scheme can't be minted: a
#   provisional allocation (empty <num>) under an ordinal-bearing scheme
#   (sequential preset or a {seq…} template) can't render its ordinal, and any
#   prefix-from failure (empty project tag, un-derivable {date:…} template) is a
#   uniform fallback. prefix-from's stderr is never interpolated, and the final
#   composed base is re-checked at the id boundary — a config-supplied prefix
#   can never reach a filename, registry token, or git argument malformed.
alloc_durable_issue_id() {
  local subject="$1" num="${2:-}" date slug base scheme now prefix
  date="$(bash "$JIMFILE" date)" || return 1
  slug="$(bash "$JIMFILE" slug "$subject")" || return 1
  base="${date}-${slug}"
  scheme="$(alloc_config issue_id_prefix)"
  # Attempt the scheme prefix unless this is a provisional allocation (no
  # coordinated ordinal) under an ordinal-bearing scheme, which must degrade
  # uniformly rather than render an arbitrary ordinal.
  if [[ -n "$num" ]] || { [[ "$scheme" != sequential ]] && [[ "$scheme" != *'{seq'* ]]; }; then
    now="$(bash "$JIMFILE" now)" || return 1
    if prefix="$(bash "$JIMFILE" prefix-from "$now" "$num" 2>/dev/null)"; then
      base="${prefix}-${slug}"
    fi
  fi
  alloc_valid_token "$base" || base="${date}-${slug}"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 c6
  local candidate="$base" suffix=1 taken
  while :; do
    taken=0
    for ((i=0; i<n; i++)); do
      read -r c1 c2 c3 c4 c5 c6 <<< "${lines[i]}"
      [[ "$c1" == issue && "$c2" == allocate ]] || continue
      [[ "$c4" == "$candidate" ]] && { taken=1; break; }
    done
    (( taken )) || break
    suffix=$((suffix + 1))
    candidate="${base}-${suffix}"
  done
  printf '%s\n' "$candidate"
}

# alloc_reconcile_realize <pending-id>...   (issues log on stdin)
#   Compute the realized mapping for a batch of unique pending provisional issue
#   identities (durable full-ids). For each, keyed find-or-allocate: if the log
#   already carries an `issue allocate <num> <full-id>` record the provisional is
#   already realized (idempotent — its existing ordinal, no new allocation);
#   otherwise it draws a real ordinal from the shared high-water (max existing
#   ordinal, incremented per newly-realized id in pending order). Assignment
#   order follows pending (allocation) order, and the ordinal derives solely from
#   the high-water — never from any field of the marker, so a crafted marker in a
#   branch-writable artifact can neither force a target ordinal nor a collision.
#
#   Prints one line per pending id: "<full-id>\t<ordinal>\t<new|have>" (the first
#   two fields are the provisional→real mapping; the third tells the publish step
#   which realizations need a new record). Pure — reads the log, touches no git.
#   Halts (rc 1) on a within-batch duplicate identity (defense-in-depth against a
#   buggy or hostile consumer surfacing one identity twice) or a pending id that
#   fails the id boundary. Cross-batch uniqueness stays the consumer's obligation.
alloc_reconcile_realize() {
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4
  local log=""
  (( n )) && log="$(printf '%s\n' "${lines[@]}")"
  # The high-water comes from the shared fold, so reconcile and a normal
  # allocation cannot answer differently for any log shape. The already-realized
  # map is a separate pass with a stricter gate: an ordinal counts once it is
  # consumed, whatever its sibling field looks like, but only a boundary-valid
  # durable id may be treated as an identity to match a pending marker against.
  local max
  max="$(printf '%s\n' "$log" | alloc_fold_max_issue)" || return 1
  local -A existing=()   # durable full-id -> its allocated ordinal
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 _ <<< "${lines[i]}"
    [[ "$c1" == issue && "$c2" == allocate ]] || continue
    [[ "$c3" =~ ^[0-9]+$ ]] || continue
    alloc_valid_token "$c4" || continue
    existing["$c4"]="$c3"
  done
  # Pass 1: validate the whole pending batch before emitting anything, so a halt
  # (boundary-invalid id / within-batch duplicate) produces no partial mapping —
  # the preview reports only a clean mapping or only a stop condition.
  local -A seen=()
  local pend
  for pend in "$@"; do
    if ! alloc_valid_token "$pend"; then
      echo "error: invalid pending provisional id '$pend'" >&2
      return 1
    fi
    if [[ -n "${seen[$pend]:-}" ]]; then
      echo "error: duplicate provisional identity within the pending batch: '$pend'" >&2
      return 1
    fi
    seen["$pend"]=1
  done
  # Pass 2: emit the mapping in pending (allocation) order.
  local ord next=$((max + 1))
  for pend in "$@"; do
    if [[ -n "${existing[$pend]:-}" ]]; then
      printf '%s\t%s\thave\n' "$pend" "${existing[$pend]}"
    else
      ord=$next; next=$((next + 1))
      printf '%s\t%s\tnew\n' "$pend" "$ord"
    fi
  done
}

# alloc_reconcile_realize_spec <pending-id>...   (specs log on stdin)
#   Compute the realized mapping for a batch of unique pending provisional spec
#   identities, each "<group>/P-<date>-<slug>". A spec carries no durable
#   registry identity of its own — only the ordinal it does not yet have — so
#   realization is keyed find-or-allocate on the strongest triple the record
#   grammar can express: (group, slug, issuance-date). A `spec allocate` record
#   whose group (after alias resolution), slug, and date field all match maps to
#   "have" — its ordinal, no new allocation; otherwise the identity draws a fresh
#   ordinal from the shared high-water (alloc_fold_max_spec, asked under the
#   group name this function already resolved — record-side aliased and
#   source-counting), incremented per newly-realized identity in pending order.
#   The publish step stamps each new record's date from the pending token rather
#   than from the day it runs, which is what keeps the key stable: a re-run after
#   a crash between publish and rename finds its own record and converges.
#
#   Two identities can collide on that triple — same group, same title-slug, same
#   day — and no corroboration separates them, so the residual is surfaced rather
#   than prevented: the "have" state travels in the third field for the consumer
#   to show, and the consumer's rename halts on an occupied target directory.
#
#   THE RETURNED GROUP IS AUTHORITATIVE AND MAY DIFFER from the one the
#   provisional was issued under: a group renamed in the meantime resolves to its
#   current name, so realization never mints into a retired namespace. The same
#   contract alloc_next_id_spec carries.
#
#   Prints one line per pending id: "<pending-id>\t<group>/<NNN>\t<new|have>".
#   Pure — reads the log, touches no git. Halts (rc 1) before emitting anything
#   on a pending id that fails the reserved-form boundary, on a within-batch
#   duplicate, or on a group whose next ordinal would be wider than the registry
#   could be rebuilt from. Cross-batch uniqueness stays the consumer's obligation.
alloc_reconcile_realize_spec() {
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5
  local log=""
  (( n )) && log="$(printf '%s\n' "${lines[@]}")"
  local -A alias=()
  local k v
  if (( n )); then
    while IFS=$'\t' read -r k v; do
      [[ -n "$k" ]] && alias["$k"]="$v"
    done < <(printf '%s\n' "${lines[@]}" | alloc_group_alias_map)
  fi
  # Already-realized map, keyed (current group, slug, date). Every element is
  # revalidated at its own boundary, so one malformed field cannot smuggle in
  # another, and a record the fold counts is still not an identity to match
  # against unless all three key fields are well-formed.
  local -A existing=()
  local g num canon
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 c5 _ <<< "${lines[i]}"
    [[ "$c1" == spec && "$c2" == allocate ]] || continue
    alloc_valid_specid "$c3" || continue
    num="${c3##*/}"
    (( ${#num} > ALLOC_MAX_ORD_DIGITS )) && continue
    alloc_valid_token "$c4" || continue
    [[ "$c5" =~ ^[0-9]{8}$ ]] || continue
    g="${c3%/*}"
    g="${alias[$g]:-$g}"
    # Canonical, so a record spelling its ordinal unpadded is the same identity
    # a `new` answer would report — the have/new asymmetry is closed at the
    # source rather than left for each consumer to normalize.
    canon="$(alloc_canon_specid "$g/$num")" || continue
    existing["$g/$c4/$c5"]="$canon"
  done
  # Pass 1: validate and parse the whole pending batch before emitting anything,
  # so a halt leaves no partial mapping — a preview shows a clean mapping or only
  # the stop condition.
  local -A seen=()
  local pend tok body
  local -a p_id=() p_group=() p_slug=() p_date=()
  for pend in "$@"; do
    if ! alloc_valid_provid "$pend"; then
      echo "error: invalid pending provisional spec id '$pend'" >&2
      return 1
    fi
    if [[ -n "${seen[$pend]:-}" ]]; then
      echo "error: duplicate provisional identity within the pending batch: '$pend'" >&2
      return 1
    fi
    seen["$pend"]=1
    g="${pend%/*}"; tok="${pend##*/}"
    body="${tok#"$ALLOC_PROV_PREFIX"}"
    p_id+=( "$pend" )
    p_group+=( "${alias[$g]:-$g}" )
    p_date+=( "${body%%-*}" )
    p_slug+=( "${body#*-}" )
  done
  # Pass 2: compute the mapping in pending (issuance) order, one high-water read
  # per group touched, buffering every row. Nothing is emitted until the whole
  # batch computes, so a halt leaves stdout empty rather than a partial mapping
  # the preview would show the developer as if it were a plan.
  local -A next=()
  local cur ord
  local -a rows=()
  for ((i=0; i<${#p_group[@]}; i++)); do
    cur="${p_group[i]}"
    k="$cur/${p_slug[i]}/${p_date[i]}"
    if [[ -n "${existing[$k]:-}" ]]; then
      rows+=( "$(printf '%s\t%s\thave' "${p_id[i]}" "${existing[$k]}")" )
      continue
    fi
    if [[ -z "${next[$cur]:-}" ]]; then
      num="$(printf '%s\n' "$log" | alloc_fold_max_spec "$cur")" || return 1
      next["$cur"]=$((num + 1))
    fi
    ord="${next[$cur]}"
    next["$cur"]=$((ord + 1))
    if (( ${#ord} > ALLOC_MAX_ORD_DIGITS )); then
      echo "error: group exhausted — '$cur' has no ordinal left that the registry could be rebuilt from" >&2
      return 1
    fi
    rows+=( "$(printf '%s\t%s/%03d\tnew' "${p_id[i]}" "$cur" "$ord")" )
  done
  (( ${#rows[@]} )) && printf '%s\n' "${rows[@]}"
  return 0
}

# ─── Section: seed derivation (pure — reads the tree, no git) ─────────────────
#
# The one-time bootstrap reconstructs the per-kind logs from the repo's existing
# artifacts: specs from directory names (spec identity is path-derived), issues
# from each file's frontmatter (the durable per-issue source, not INDEX.md). The
# derived records use the same allocate grammar as an allocation; provenance is
# the synthetic marker jim-seed and dates are informational only (issue `created`
# for issues, today for specs).

# alloc_seed_field <file> <key> — print the first `<key>: value` frontmatter
# scalar (surrounding quotes stripped). Parsed as data; never sourced.
alloc_seed_field() {
  sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -n1 | sed 's/^"//; s/"$//'
}

# alloc_seed_norm_date <raw> — reduce an ISO-ish timestamp to YYYYMMDD; fall back
# to today when absent or unparseable (the date field is informational only).
alloc_seed_norm_date() {
  local d
  d="$(printf '%s' "${1:-}" | sed -n 's/^\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\).*/\1\2\3/p')"
  if [[ -n "$d" ]]; then printf '%s' "$d"; else bash "$JIMFILE" date; fi
}

# alloc_seed_derive_specs <specs_root> [<marker>] — print the specs.log record
# set derived from <specs_root>/<group>/<NNN>-<slug>/ dirs: one `group allocate`
# per group that holds a non-blueprint spec, one `spec allocate` per dir,
# skipping the reserved blueprint slot. Groups sorted; specs ascending by
# ordinal. Empty output when the tree is absent or holds no non-blueprint specs.
#
# <marker> is the provenance value stamped into each record, defaulting to the
# bootstrap's `jim-seed`. It is a parameter because more than one writer derives
# from the same tree, and which writer produced a record is the only forensic
# distinction between them — the record content is otherwise identical.
alloc_seed_derive_specs() {
  local root="$1" marker="${2:-jim-seed}" date
  [[ -d "$root" ]] || return 0
  date="$(bash "$JIMFILE" date)" || return 1
  local -a groups=()
  local g
  for g in "$root"/*/; do
    [[ -d "$g" ]] || continue
    groups+=("$(basename "$g")")
  done
  (( ${#groups[@]} )) || return 0
  mapfile -t groups < <(printf '%s\n' "${groups[@]}" | LC_ALL=C sort)
  local out="" conflicts=""
  local gname gdir entry name ord slug key
  local -A seen_ord=()
  for gname in "${groups[@]}"; do
    gdir="$root/$gname"
    if ! alloc_valid_token "$gname"; then
      conflicts+="  invalid group name: $gname"$'\n'; continue
    fi
    local -a rows=()
    for entry in "$gdir"/*/; do
      [[ -d "$entry" ]] || continue
      name="$(basename "$entry")"
      ord="${name%%-*}"
      # The reserved blueprint slot is a zero-VALUED ordinal, not one spelling of
      # it: `0-`, `00-` and `000-` name the same reserved dir, and deriving a
      # record for any of them would mint the `<group>/000` identity the registry
      # treats as drift. The digits guard has to precede the arithmetic — `10#`
      # on a non-numeric token is a fatal arithmetic error, and this runs before
      # the ordinal class check below.
      [[ "$ord" =~ ^[0-9]+$ ]] && (( 10#$ord == 0 )) && continue
      # A pending provisional dir holds a reserved identity that never entered
      # the registry, so the bootstrap passes over it like the blueprint slot:
      # no record to derive, and nothing to call a conflict.
      alloc_is_prov_form "$name" && continue
      if [[ "$name" != *-* ]]; then
        conflicts+="  spec dir has no slug: $gname/$name"$'\n'; continue
      fi
      slug="${name#*-}"
      # ordinal: pure digits, no wider than the allocator's own legality value —
      # a numeric class check beyond the id boundary, which admits e.g. 007x.
      # Reading the same constant the fold reads is what keeps the bootstrap from
      # refusing an ordinal the allocator can mint.
      if [[ ! "$ord" =~ ^[0-9]+$ ]] || (( ${#ord} > ALLOC_MAX_ORD_DIGITS )); then
        conflicts+="  spec dir has an invalid ordinal: $gname/$name"$'\n'; continue
      fi
      if ! alloc_valid_token "$slug"; then
        conflicts+="  spec dir has an invalid slug: $gname/$name"$'\n'; continue
      fi
      key="$gname/$((10#$ord))"
      if [[ -n "${seen_ord[$key]:-}" ]]; then
        conflicts+="  duplicate spec ordinal: $gname/$(printf '%03d' "$((10#$ord))") ($gname/$name)"$'\n'; continue
      fi
      seen_ord[$key]=1
      rows+=("$ord"$'\t'"$slug")
    done
    (( ${#rows[@]} )) || continue
    out+="group allocate $gname $date $marker"$'\n'
    while IFS=$'\t' read -r ord slug; do
      out+="$(printf 'spec allocate %s/%03d %s %s %s' "$gname" "$((10#$ord))" "$slug" "$date" "$marker")"$'\n'
    done < <(printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t$'\t' -k1,1n)
  done
  if [[ -n "$conflicts" ]]; then
    printf 'error: cannot seed — spec artifacts have conflicts:\n%s' "$conflicts" >&2
    return 1
  fi
  printf '%s' "$out"
}

# alloc_seed_derive_issues <issues_dir> [<marker>] — print the issues.log record
# set derived from <issues_dir>/*.md frontmatter (num, id, created), excluding
# INDEX.md; ascending by ordinal. Empty output when the dir is absent or holds no
# issues. <marker> carries the same provenance contract as the spec derivation's.
alloc_seed_derive_issues() {
  local dir="$1" marker="${2:-jim-seed}"
  [[ -d "$dir" ]] || return 0
  local out="" conflicts=""
  local -a rows=()
  local -A seen_num=() seen_id=()
  local f base num id created cdate
  for f in "$dir"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == "INDEX.md" ]] && continue
    num="$(alloc_seed_field "$f" num)"
    id="$(alloc_seed_field "$f" id)"
    created="$(alloc_seed_field "$f" created)"
    if [[ -z "$num" ]]; then
      conflicts+="  issue file has no display ordinal (num): $base"$'\n'; continue
    fi
    # ordinal: pure digits, no wider than the allocator's own legality value.
    if [[ ! "$num" =~ ^[0-9]+$ ]] || (( ${#num} > ALLOC_MAX_ORD_DIGITS )); then
      conflicts+="  issue file has an invalid display ordinal: $base ($num)"$'\n'; continue
    fi
    if [[ -z "$id" ]]; then
      conflicts+="  issue file has no durable id: $base"$'\n'; continue
    fi
    if ! alloc_valid_token "$id"; then
      conflicts+="  issue file has an invalid durable id: $base ($id)"$'\n'; continue
    fi
    if [[ -n "${seen_num[$((10#$num))]:-}" ]]; then
      conflicts+="  duplicate display ordinal: $num ($base)"$'\n'; continue
    fi
    if [[ -n "${seen_id[$id]:-}" ]]; then
      conflicts+="  duplicate durable id: $id ($base)"$'\n'; continue
    fi
    seen_num[$((10#$num))]=1; seen_id[$id]=1
    cdate="$(alloc_seed_norm_date "$created")"
    # Seed the CANONICAL spelling, not the frontmatter's. An issue ordinal is a
    # number written without padding, and a hand-authored '007' seeded verbatim
    # splits the registry against itself: the fold and this dedupe read it
    # numerically while the resolver compares as a string, so the ordinal would
    # count toward the high-water and still resolve as never allocated. The spec
    # seed normalizes for the same reason.
    rows+=("$((10#$num))"$'\t'"$id"$'\t'"$cdate")
  done
  if [[ -n "$conflicts" ]]; then
    printf 'error: cannot seed — issue artifacts have conflicts:\n%s' "$conflicts" >&2
    return 1
  fi
  (( ${#rows[@]} )) || return 0
  local rnum rid rdate
  while IFS=$'\t' read -r rnum rid rdate; do
    out+="issue allocate $rnum $rid $rdate $marker"$'\n'
  done < <(printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t$'\t' -k1,1n)
  printf '%s' "$out"
}

# ─── Section: Coordination point + CAS (git plumbing) ────────────────────────

# alloc_in_repo — exit 0 iff CWD is inside a git repository.
alloc_in_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "error: not inside a git repository" >&2
    return 1
  }
}

# alloc_config <cli-key> — resolve a config key via jimconf.sh, forwarding any
# -c override. The id_coordination_* family is read from the current branch, so
# a team's coordination scheme is versioned with the repo.
alloc_config() {
  if [[ -n "$CONFIG_FILE" ]]; then
    bash "$JIMCONF" -c "$CONFIG_FILE" get "$1"
  else
    bash "$JIMCONF" get "$1"
  fi
}

# alloc_preflight — validate the config-governed mechanism and unreachable mode
# before any allocation. The git mechanism and the 'fail' / 'provisional'
# unreachable-modes are accepted; a still-reserved value (the 'service'
# mechanism, an unknown unreachable value) fails loudly rather than silently
# misbehaving.
alloc_preflight() {
  local mech unreachable
  mech="$(alloc_config id_coordination_mechanism)"; [[ -n "$mech" ]] || mech="git"
  if [[ "$mech" != "git" ]]; then
    echo "error: id_coordination_mechanism '$mech' is not implemented (only 'git' is supported)" >&2
    return 1
  fi
  unreachable="$(alloc_config id_coordination_unreachable)"; [[ -n "$unreachable" ]] || unreachable="fail"
  case "$unreachable" in
    fail|provisional) ;;
    *)
      echo "error: id_coordination_unreachable '$unreachable' is not implemented (only 'fail' and 'provisional' are supported)" >&2
      return 1
      ;;
  esac
  return 0
}

# alloc_backoff <attempt> — sleep a short, rising, jittered interval between CAS
# retries so racing allocations de-synchronize instead of colliding in lockstep.
# Bounded well under a second; jitter comes from $RANDOM.
alloc_backoff() {
  local n="$1" ms
  ms=$(( n * 40 + RANDOM % 50 ))
  sleep "0.$(printf '%03d' "$ms")" 2>/dev/null || true
}

# alloc_valid_branch <branch> — exit 0 iff <branch> is a safe branch name for
# refs/heads/<branch>: no leading '-' (option injection) and accepted by git's
# own ref-name policy (rejects '..', control chars, ~^:?*[, .lock, etc.). The
# coordination branch is config-supplied, so it is validated before it ever
# reaches a git command.
alloc_valid_branch() {
  local b="${1:-}"
  [[ -n "$b" ]] || return 1
  case "$b" in -*) return 1 ;; esac
  git check-ref-format "refs/heads/$b" >/dev/null 2>&1
}

# alloc_coord_branch — resolve the coordination branch from config (default
# jim/registry), validated as a git branch name. Prints the branch; rc 1 if the
# configured value is not a valid branch name.
alloc_coord_branch() {
  local b
  b="$(alloc_config id_coordination_branch)"
  [[ -n "$b" ]] || b="jim/registry"
  if ! alloc_valid_branch "$b"; then
    echo "error: id_coordination_branch '$b' is not a valid git branch name" >&2
    return 1
  fi
  printf '%s' "$b"
}

# alloc_coord_remote — print a usable coordination remote (prefer 'origin',
# else the first configured remote), or nothing when the clone has no remote.
# An empty result selects the local tier; a non-empty one selects the origin
# tier (the guarantee follows reachability).
alloc_coord_remote() {
  local r
  if git remote 2>/dev/null | grep -qx origin; then
    r=origin
  else
    r="$(git remote 2>/dev/null | head -n1)"
  fi
  [[ -n "$r" ]] && printf '%s' "$r"
}

# alloc_origin_tip <remote> <branch>  — print the coordination branch's tip sha
# on <remote> (empty when the branch does not exist yet), having fetched its
# objects locally so the log can be read and a commit built atop it. rc 1 if the
# remote is unreachable — the origin tier hard-fails rather than silently
# falling back to an unpublished local allocation.
#
# The advertised tip is remote-supplied text, and every consumer interpolates it
# into a later git argument (a `<tip>:<file>` cat-file spelling, a commit parent,
# a CAS old-value), so it crosses the id boundary here before it is returned —
# the one gate that covers every call site. An option-shaped or otherwise
# rejected advertisement is a hard failure, not a degraded read.
alloc_origin_tip() {
  local remote="$1" branch="$2" line tip
  if ! line="$(git ls-remote --heads "$remote" "$branch" 2>/dev/null)"; then
    echo "error: coordination remote '$remote' is unreachable" >&2
    return 1
  fi
  tip="$(printf '%s' "$line" | awk 'NR==1{print $1}')"
  if [[ -n "$tip" ]] && ! alloc_valid_token "$tip"; then
    echo "error: coordination remote '$remote' advertised an unusable tip for '$branch'" >&2
    return 1
  fi
  if [[ -n "$tip" ]]; then
    if ! git fetch --quiet "$remote" "$branch" 2>/dev/null; then
      echo "error: failed to fetch '$branch' from '$remote'" >&2
      return 1
    fi
  fi
  printf '%s' "$tip"
}

# ── Erosion guard: a local, per-clone baseline of the last-seen registry.
# It lives under the git dir — never on any branch, never fetched or pushed — so
# an attacker who force-pushes a rewritten history cannot also rewrite the
# baseline. The append-only log may only grow, so the baseline must remain a
# byte-prefix of the current content; if it does not, the history was truncated
# or rewritten and the next allocation must hard-fail rather than reissue an
# already-consumed id. A first-time clone has no baseline and cannot
# detect erosion that predates its first fetch — denying force-push on the
# coordination branch is the primary control; this is defense-in-depth.

# alloc_baseline_dir — the local baseline directory (under the git dir).
alloc_baseline_dir() {
  local gd
  gd="$(git rev-parse --git-dir 2>/dev/null)" || return 1
  printf '%s/jimalloc' "$gd"
}

# alloc_baseline_file <logfile> — path to the last-seen baseline for <logfile>.
alloc_baseline_file() {
  local d
  d="$(alloc_baseline_dir)" || return 1
  printf '%s/seen-%s' "$d" "$1"
}

# alloc_check_erosion <logfile> <current_raw> — rc 0 if the stored baseline is a
# byte-prefix of <current_raw> (clean growth) or no baseline exists yet; rc 1 if
# the baseline is no longer a prefix (erosion).
alloc_check_erosion() {
  local logfile="$1" current="$2" base seen
  base="$(alloc_baseline_file "$logfile")" || return 0
  [[ -f "$base" ]] || return 0
  seen="$(cat -- "$base"; printf X)"; seen="${seen%X}"
  [[ -z "$seen" ]] && return 0
  [[ "$current" == "$seen"* ]] && return 0
  return 1
}

# alloc_update_baseline <logfile>   (content on stdin) — record the content just
# committed as the new last-seen baseline for <logfile>. Best-effort: a failure
# to persist the baseline never fails an allocation that already committed.
alloc_update_baseline() {
  local logfile="$1" d base
  d="$(alloc_baseline_dir)" || { cat >/dev/null; return 0; }
  mkdir -p "$d" 2>/dev/null || { cat >/dev/null; return 0; }
  base="$(alloc_baseline_file "$logfile")" || { cat >/dev/null; return 0; }
  cat > "$base" 2>/dev/null || true
}

# alloc_write_contained — verify the allocator's only local write target (the
# erosion baseline dir, under the git dir) resolves inside the git dir, refusing
# a symlink that escapes it. Runs before any git object write or ref update so a
# rejected target leaves no side effect. The git dir is the right anchor
# rather than the working-tree top: the baseline is untracked local state, and
# in a worktree the git dir legitimately sits outside the working tree. The
# allocator writes no other filesystem artifact — record content flows through
# pipes, never a temp file — so this is the complete write surface.
alloc_write_contained() {
  local gd gd_real b_real
  gd="$(git rev-parse --git-dir 2>/dev/null)" || {
    echo "error: not inside a git repository" >&2
    return 1
  }
  gd_real="$(realpath -m -- "$gd" 2>/dev/null)" || return 1
  b_real="$(realpath -m -- "$gd/jimalloc" 2>/dev/null)" || return 1
  if [[ "$b_real" != "$gd_real" && "$b_real" != "$gd_real"/* ]]; then
    echo "error: refusing to write the erosion baseline outside the git dir" \
         "(symlink escape): $gd/jimalloc" >&2
    return 1
  fi
  return 0
}

# alloc_group_present <group>  (log on stdin) — exit 0 iff a valid
# `group allocate <group>` record already exists.
alloc_group_present() {
  local group="$1" line c1 c2 c3
  while IFS= read -r line; do
    read -r c1 c2 c3 _ <<< "$line"
    [[ "$c1" == group && "$c2" == allocate ]] || continue
    alloc_valid_token "$c3" || continue
    [[ "$c3" == "$group" ]] && return 0
  done
  return 1
}

# alloc_build_commit <parent_sha> <logfile> <who> <email>   (content on stdin)
#   Build — with git plumbing only, so the working tree is never touched — a
#   commit that sets <logfile> to the piped content atop <parent_sha> (empty =
#   root commit), preserving every sibling log entry, and print the new commit
#   sha. The identity is passed per-invocation (already sanitized) so a hostile
#   user.name cannot corrupt the commit object.
alloc_build_commit() {
  local parent="$1" logfile="$2" who="$3" email="$4"
  local blob tree
  blob="$(git hash-object -w --stdin)" || return 1
  if [[ -n "$parent" ]]; then
    tree="$( { git ls-tree "$parent^{tree}" | awk -F'\t' -v f="$logfile" '$2 != f'; \
               printf '100644 blob %s\t%s\n' "$blob" "$logfile"; } | git mktree )" || return 1
    git -c "user.name=$who" -c "user.email=$email" \
        commit-tree "$tree" -p "$parent" -m "jim: append $logfile"
  else
    tree="$( printf '100644 blob %s\t%s\n' "$blob" "$logfile" | git mktree )" || return 1
    git -c "user.name=$who" -c "user.email=$email" \
        commit-tree "$tree" -m "jim: create $logfile"
  fi
}

# alloc_local_cas <ref> <old_sha> <logfile> <who> <email>   (content on stdin)
#   Local tier: build the commit and land it with an old-value compare-and-swap
#   (git update-ref; old_sha="" ⇒ the ref must not yet exist). Non-zero if the
#   CAS is rejected (a concurrent session advanced the ref) or a step fails.
alloc_local_cas() {
  local ref="$1" old_sha="$2" logfile="$3" who="$4" email="$5" commit
  commit="$(alloc_build_commit "$old_sha" "$logfile" "$who" "$email")" || return 1
  git update-ref "$ref" "$commit" "$old_sha" 2>/dev/null
}

# alloc_origin_cas <remote> <ref> <parent> <logfile> <who> <email>  (content on stdin)
#   Origin tier: build the commit atop the fetched remote tip <parent>, then
#   push it. The default non-fast-forward rejection is the compare-and-swap —
#   the push lands only if the remote branch is still at <parent>; if a
#   concurrent allocation advanced it, the push is rejected and the caller
#   refetches and retries. On success the local ref is synced so reads see it.
alloc_origin_cas() {
  local remote="$1" ref="$2" parent="$3" logfile="$4" who="$5" email="$6" commit
  commit="$(alloc_build_commit "$parent" "$logfile" "$who" "$email")" || return 1
  if git push --quiet "$remote" "$commit:$ref" 2>/dev/null; then
    git update-ref "$ref" "$commit" 2>/dev/null || true
    return 0
  fi
  return 1
}

# alloc_cas_append <logfile> <builder_fn> <builder_args...>
#   The allocation retry loop. Each attempt re-reads the coordination branch tip
#   and its log, invokes <builder_fn> "<current_log>" <args...> <who> to compute
#   the id to return (its first output line) and the record line(s) to append
#   (the rest), then attempts the CAS. A rejected CAS (a concurrent allocation
#   advanced the ref) re-reads and retries; exhausting the attempts hard-fails
#   loudly rather than issuing a duplicate. <who>/<email> are read once from
#   git config, sanitized, and used for both the record and the commit identity.
alloc_cas_append() {
  local logfile="$1"; shift
  local builder="$1"; shift
  alloc_preflight || return 1
  alloc_write_contained || return 1
  local branch ref remote
  branch="$(alloc_coord_branch)" || return 1
  ref="refs/heads/$branch"
  remote="$(alloc_coord_remote)"   # empty ⇒ local tier; set ⇒ origin tier
  local who email
  who="$(alloc_sanitize_who "$(git config user.name 2>/dev/null || printf '')")"
  email="$(alloc_sanitize_who "$(git config user.email 2>/dev/null || printf '')")"
  [[ -n "$who" ]]   || who="jim-allocator"
  [[ -n "$email" ]] || email="jim-allocator@localhost"
  local attempts=5 attempt tip current_log current_raw return_id
  local builder_out builder_rc
  local -a cur=() built=() records=() all=()
  for ((attempt=1; attempt<=attempts; attempt++)); do
    # Current tip of the coordination branch for this tier (origin fetches it).
    if [[ -n "$remote" ]]; then
      tip="$(alloc_origin_tip "$remote" "$branch")" || return 1
    else
      tip="$(git rev-parse --verify --quiet --end-of-options "$ref" 2>/dev/null || true)"
    fi
    # Erosion guard: the seen-baseline must remain a byte-prefix of the current
    # registry, else the history was truncated or rewritten — hard-fail loudly.
    # The trailing-X trick preserves the blob's final newline through capture so
    # the byte-prefix check is line-boundary precise.
    if [[ -n "$tip" ]]; then
      current_raw="$(git cat-file -p "$tip:$logfile" 2>/dev/null; printf X)"
      current_raw="${current_raw%X}"
    else
      current_raw=""
    fi
    if ! alloc_check_erosion "$logfile" "$current_raw"; then
      echo "error: coordination branch '$branch' shows registry erosion for $logfile" \
           "(history truncated or rewritten); refusing to allocate" >&2
      return 1
    fi
    cur=()
    [[ -n "$tip" ]] && mapfile -t cur < <(git cat-file -p "$tip:$logfile" 2>/dev/null)
    if (( ${#cur[@]} > 0 )); then
      current_log="$(printf '%s\n' "${cur[@]}")"
    else
      current_log=""
    fi
    # The builder's own exit status is kept: a builder that refuses (rc != 0)
    # has already written its specific reason to stderr, so nothing generic is
    # added after it — a consumer classifying the refusal by the last line it
    # reads sees that reason. The generic line covers only the other failure,
    # a builder that succeeds but returns output the loop cannot use.
    builder_out="$("$builder" "$current_log" "$@" "$who")"
    builder_rc=$?
    (( builder_rc == 0 )) || return 1
    built=()
    [[ -n "$builder_out" ]] && mapfile -t built <<< "$builder_out"
    if (( ${#built[@]} < 2 )); then
      echo "error: allocator failed to compute a record" >&2
      return 1
    fi
    return_id="${built[0]}"
    records=( "${built[@]:1}" )
    all=( "${cur[@]}" "${records[@]}" )
    # Attempt the tier's compare-and-swap; a rejection re-reads and retries.
    if [[ -n "$remote" ]]; then
      if printf '%s\n' "${all[@]}" \
           | alloc_origin_cas "$remote" "$ref" "$tip" "$logfile" "$who" "$email"; then
        printf '%s\n' "${all[@]}" | alloc_update_baseline "$logfile"
        printf '%s\n' "$return_id"
        return 0
      fi
    else
      if printf '%s\n' "${all[@]}" \
           | alloc_local_cas "$ref" "$tip" "$logfile" "$who" "$email"; then
        printf '%s\n' "${all[@]}" | alloc_update_baseline "$logfile"
        printf '%s\n' "$return_id"
        return 0
      fi
    fi
    # CAS lost — back off (jittered) before refetching and retrying.
    (( attempt < attempts )) && alloc_backoff "$attempt"
  done
  echo "error: allocation failed after $attempts attempts (contention on $branch)" >&2
  return 1
}

# alloc_build_spec <current_log> <group> <subject> <follow> <who>
#   Emit (stdout) the id to return, then the record line(s) to append: a
#   group-allocate record when this allocation first claims the group, followed
#   by the spec-allocate record. The slug and date are derived through jimfile.sh.
#
#   <follow> is 1 when the caller has acknowledged a group redirect. The redirect
#   check runs here, against the log this attempt is about to land on, so a rename
#   that arrives mid-retry is caught rather than missed by an earlier read. The
#   group the id is claimed under comes from the id itself, which may name the
#   group's current name rather than the one requested.
alloc_build_spec() {
  local current_log="$1" group="$2" subject="$3" follow="$4" who="$5"
  local id slug date
  local -a follow_arg=()
  (( follow )) && follow_arg=(--follow-redirect)
  id="$(printf '%s' "$current_log" | alloc_next_id_spec "$group" "${follow_arg[@]}")" || return 1
  group="${id%/*}"
  slug="$(bash "$JIMFILE" slug "$subject")" || return 1
  date="$(bash "$JIMFILE" date)" || return 1
  printf '%s\n' "$id"
  if ! printf '%s' "$current_log" | alloc_group_present "$group"; then
    alloc_encode_allocate_group "$group" "$date" "$who"
  fi
  alloc_encode_allocate_spec "$id" "$slug" "$date" "$who"
}

# alloc_build_issue <current_log> <subject> <who>
#   Emit (stdout) the return value "<full-id><TAB><num>", then the issue-allocate
#   record. The ordinal and the durable id are computed from the same log.
alloc_build_issue() {
  local current_log="$1" subject="$2" who="$3"
  local num fullid date
  num="$(printf '%s' "$current_log" | alloc_next_num_issue)" || return 1
  fullid="$(printf '%s' "$current_log" | alloc_durable_issue_id "$subject" "$num")" || return 1
  date="$(bash "$JIMFILE" date)" || return 1
  printf '%s\t%s\n' "$fullid" "$num"
  alloc_encode_allocate_issue "$num" "$fullid" "$date" "$who"
}

# ─── Section: Provisional issuance (unreachable-origin mode) ─────────────────
#
# When the coordination point is unreachable and id_coordination_unreachable is
# 'provisional', an allocation hands back a structurally distinct, local-only
# provisional identifier instead of hard-failing — coordinated work continues
# offline and settles later via reconcile. Issuance is strictly local: it reads
# no shared registry, runs no compare-and-swap, and never blocks on or fails for
# the network. A provisional identifier never enters the registry, the next-id
# computation, or the read-only preview.

# alloc_origin_reachable — exit 0 iff the coordination point is reachable: the
# local tier (no remote) is always reachable; the origin tier is reachable iff a
# quiet ls-remote succeeds. No fetch, no stderr, no ref or filesystem mutation —
# a decision probe, never a mutation.
alloc_origin_reachable() {
  local remote branch
  remote="$(alloc_coord_remote)"; [[ -n "$remote" ]] || return 0
  branch="$(alloc_coord_branch)" || return 1
  git ls-remote --heads "$remote" "$branch" >/dev/null 2>&1
}

# alloc_defer_to_provisional — exit 0 iff this allocation must defer to a local
# provisional id: the git mechanism is in force, id_coordination_unreachable is
# 'provisional', a coordination remote is configured, and that remote is
# currently unreachable. Every other combination (local tier, reachable origin,
# 'fail' mode, non-git mechanism) exits non-zero so the caller runs the normal
# CAS allocation — which itself hard-fails an unreachable 'fail'-mode origin,
# byte-identical to the fail path.
alloc_defer_to_provisional() {
  local mech mode remote
  mech="$(alloc_config id_coordination_mechanism)"; [[ -n "$mech" ]] || mech="git"
  [[ "$mech" == git ]] || return 1
  mode="$(alloc_config id_coordination_unreachable)"; [[ -n "$mode" ]] || mode="fail"
  [[ "$mode" == provisional ]] || return 1
  remote="$(alloc_coord_remote)"; [[ -n "$remote" ]] || return 1
  alloc_origin_reachable && return 1
  return 0
}

# alloc_prov_ordinal <token> — the grammar-distinct provisional ordinal for a
# pre-validated <token>: the reserved prefix over the token. Non-numeric by
# construction (prefix over a boundary-valid token stays a valid token), so it
# can never equal an allocated ordinal.
alloc_prov_ordinal() {
  printf '%s%s' "$ALLOC_PROV_PREFIX" "$1"
}

# alloc_provisional_issue <subject> — issue a provisional issue identifier
# locally and print "<full-id>\t<provisional-ordinal>". The durable id is the
# offline date-slug (jimfile.sh, no registry read — the empty log defers any
# collision suffix to the consumer's uniqueness obligation); only the display
# ordinal is deferred. Contacts no remote and writes no registry. The durable
# id — the field that enters the registry at reconcile — is revalidated at
# jimfile.sh's boundary before it is returned; the provisional ordinal is a
# valid token by construction (prefix over the validated durable id).
alloc_provisional_issue() {
  local subject="$1" fullid ord
  fullid="$(printf '' | alloc_durable_issue_id "$subject" "")" || return 1
  alloc_valid_token "$fullid" || { echo "error: computed provisional issue id '$fullid' is invalid" >&2; return 1; }
  ord="$(alloc_prov_ordinal "$fullid")"
  printf '%s\t%s\n' "$fullid" "$ord"
}

# alloc_provisional_spec <group> <subject> — issue a whole-identity provisional
# spec id and print "<group>/<provisional-ordinal>". The ordinal slot carries
# the reserved prefix over the offline date-slug, so the id is grammar-distinct
# from every real <group>/<NNN> and can never be mistaken for one. Contacts no
# remote and writes no registry. <group> is pre-validated by the caller; the
# derived date-slug token is revalidated before use. This defines the spec
# provisional grammar only — spec-side reconcile (a directory rename) is deferred.
alloc_provisional_spec() {
  local group="$1" subject="$2" date slug tok ord
  date="$(bash "$JIMFILE" date)" || return 1
  slug="$(bash "$JIMFILE" slug "$subject")" || return 1
  tok="${date}-${slug}"
  alloc_valid_token "$tok" || { echo "error: computed provisional spec token '$tok' is invalid" >&2; return 1; }
  ord="$(alloc_prov_ordinal "$tok")"
  printf '%s/%s\n' "$group" "$ord"
}

# ─── Section: Subcommand handlers ────────────────────────────────────────────

alloc_allocate_spec() {
  local group="" subject="" follow=0 a
  for a in "$@"; do
    case "$a" in
      --follow-redirect) follow=1 ;;
      *)
        if   [[ -z "$group"   ]]; then group="$a"
        elif [[ -z "$subject" ]]; then subject="$a"
        else echo "error: unexpected argument '$a'" >&2; return 2
        fi
        ;;
    esac
  done
  if [[ -z "$group" || -z "$subject" ]]; then
    echo "error: 'allocate spec' requires <group> <subject>" >&2
    return 2
  fi
  alloc_valid_token "$group" || { echo "error: invalid group '$group'" >&2; return 1; }
  alloc_in_repo || return 1
  if alloc_defer_to_provisional; then
    alloc_provisional_spec "$group" "$subject"
    return $?
  fi
  alloc_cas_append "specs.log" alloc_build_spec "$group" "$subject" "$follow"
}

alloc_allocate_issue() {
  local subject="${1:-}"
  if [[ -z "$subject" ]]; then
    echo "error: 'allocate issue' requires <subject>" >&2
    return 2
  fi
  alloc_in_repo || return 1
  if alloc_defer_to_provisional; then
    alloc_provisional_issue "$subject"
    return $?
  fi
  alloc_cas_append "issues.log" alloc_build_issue "$subject"
}

cmd_allocate() {
  local kind="${1:-}"
  shift || true
  case "$kind" in
    spec)  alloc_allocate_spec  "$@" ;;
    issue) alloc_allocate_issue "$@" ;;
    *)
      echo "error: allocate kind must be 'spec' or 'issue'" >&2
      return 2
      ;;
  esac
}

# alloc_peek_refresh — best-effort fast-forward of the local coordination ref
# from the remote so peek previews the latest state. Non-fatal by design: an
# unreachable remote or a refused update is ignored — peek degrades to the
# last-seen local state, never binds, and never mutates the registry.
alloc_peek_refresh() {
  local remote branch
  remote="$(alloc_coord_remote)"
  [[ -n "$remote" ]] || return 0
  branch="$(alloc_coord_branch)" || return 0
  git fetch --quiet "$remote" "$branch:refs/heads/$branch" 2>/dev/null || true
  return 0
}

cmd_peek() {
  local kind="${1:-}"
  case "$kind" in
    spec)
      local group="${2:-}"
      if [[ -z "$group" ]]; then
        echo "error: 'peek spec' requires <group>" >&2
        return 2
      fi
      alloc_valid_token "$group" || { echo "error: invalid group '$group'" >&2; return 1; }
      alloc_peek_refresh
      shift 2
      alloc_read_log spec | alloc_next_id_spec "$group" "$@"
      ;;
    issue)
      alloc_peek_refresh
      alloc_read_log issue | alloc_next_num_issue
      ;;
    *)
      echo "error: peek kind must be 'spec' or 'issue'" >&2
      return 2
      ;;
  esac
}

# alloc_seed_tree_root <config-key> <default> — resolve a tree root (specs /
# issues) from config, anchored at the worktree top so the scan is CWD-robust.
alloc_seed_tree_root() {
  local key="$1" def="$2" top raw
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "error: not inside a git repository" >&2; return 1; }
  raw="$(alloc_config "$key")"; [[ -n "$raw" ]] || raw="$def"
  raw="${raw#./}"; raw="${raw%/}"
  case "$raw" in /*) printf '%s' "$raw" ;; *) printf '%s/%s' "$top" "$raw" ;; esac
}

# alloc_seed_preview_kind <label> <records> <current> — report, for one log, what
# the seed would do: nothing (no artifacts), skip (already has records), or write.
alloc_seed_preview_kind() {
  local label="$1" records="$2" current="$3" n
  if [[ -z "$records" ]]; then
    printf '  %s: no artifacts to seed\n' "$label"; return 0
  fi
  n="$(printf '%s\n' "$records" | grep -c .)"
  if [[ -n "$current" ]]; then
    printf '  %s: already has records — would skip (%d derived)\n' "$label" "$n"
  else
    printf '  %s: would write %d records:\n' "$label" "$n"
    printf '%s\n' "$records" | sed 's/^/    /'
  fi
}

# alloc_seed_preview <spec-records> <issue-records> — read-only report of what an
# --apply would write; mutates nothing.
alloc_seed_preview() {
  local spec_records="$1" issue_records="$2"
  printf 'seed preview (no changes written):\n'
  alloc_seed_preview_kind "specs.log"  "$spec_records"  "$(alloc_read_log spec)"
  alloc_seed_preview_kind "issues.log" "$issue_records" "$(alloc_read_log issue)"
  return 0
}

# cmd_seed [--apply]
#   One-time registry bootstrap: reconstruct the per-kind logs from the repo's
#   existing spec directories and issue files. Bare `seed` is a read-only preview
#   (derive + validate + report, mutate nothing); `--apply` lands the derived
#   records via the same CAS as an allocation. Preview-then-apply mirrors jim's
#   one-time-migration doctrine.
cmd_seed() {
  local apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) apply=1; shift ;;
      *)
        echo "error: unknown option '$1' for seed (usage: seed [--apply])" >&2
        return 2
        ;;
    esac
  done
  alloc_in_repo || return 1
  alloc_preflight || return 1
  local specs_root issues_dir
  specs_root="$(alloc_seed_tree_root specs docs/specs)"   || return 1
  issues_dir="$(alloc_seed_tree_root issues docs/issues)" || return 1
  # Derive both kinds; a conflict in either halts the whole seed (offenders on
  # stderr, no records), per AC 6.
  local spec_records issue_records
  spec_records="$(alloc_seed_derive_specs "$specs_root")"   || return 1
  issue_records="$(alloc_seed_derive_issues "$issues_dir")" || return 1
  if (( apply )); then
    alloc_seed_land "$spec_records" "$issue_records"
  else
    alloc_seed_preview "$spec_records" "$issue_records"
  fi
}

# alloc_seed_commit <parent> <who> <email> <spec-content> <issue-content>
#   Build — with git plumbing only, so the working tree is never touched — ONE
#   commit atop <parent> ("" = root) that sets specs.log to <spec-content> and/or
#   issues.log to <issue-content> (an empty content leaves that log untouched,
#   preserving any existing blob), keeping every other tree entry. Print the sha.
#   Each written blob is newline-terminated so the log stays line-clean.
alloc_seed_commit() {
  local parent="$1" who="$2" email="$3" spec_content="$4" issue_content="$5"
  local specs_file issues_file blob
  specs_file="$(alloc_log_file spec)"; issues_file="$(alloc_log_file issue)"
  local -a add=()
  if [[ -n "$spec_content" ]]; then
    blob="$(printf '%s\n' "$spec_content" | git hash-object -w --stdin)" || return 1
    add+=("$(printf '100644 blob %s\t%s' "$blob" "$specs_file")")
  fi
  if [[ -n "$issue_content" ]]; then
    blob="$(printf '%s\n' "$issue_content" | git hash-object -w --stdin)" || return 1
    add+=("$(printf '100644 blob %s\t%s' "$blob" "$issues_file")")
  fi
  (( ${#add[@]} )) || return 1
  local keep="" tree
  if [[ -n "$parent" ]]; then
    keep="$(git ls-tree "$parent^{tree}" 2>/dev/null)"
    [[ -n "$spec_content"  ]] && keep="$(printf '%s\n' "$keep" | awk -F'\t' -v f="$specs_file"  '$0!="" && $2!=f')"
    [[ -n "$issue_content" ]] && keep="$(printf '%s\n' "$keep" | awk -F'\t' -v f="$issues_file" '$0!="" && $2!=f')"
  fi
  tree="$( { [[ -n "$keep" ]] && printf '%s\n' "$keep"; printf '%s\n' "${add[@]}"; } | git mktree )" || return 1
  if [[ -n "$parent" ]]; then
    git -c "user.name=$who" -c "user.email=$email" commit-tree "$tree" -p "$parent" -m "jim: seed registry"
  else
    git -c "user.name=$who" -c "user.email=$email" commit-tree "$tree" -m "jim: seed registry"
  fi
}

# alloc_seed_report <spec-content> <issue-content> [<skip-spec>] [<skip-issue>]
#   One-line summary of a seed, noting any kind skipped because it already had
#   records.
alloc_seed_report() {
  local ws="$1" wi="$2" skip_spec="${3:-0}" skip_issue="${4:-0}" ns=0 ni=0
  [[ -n "$ws" ]] && ns="$(printf '%s\n' "$ws" | grep -c .)"
  [[ -n "$wi" ]] && ni="$(printf '%s\n' "$wi" | grep -c .)"
  printf 'seeded: %d spec record(s), %d issue record(s)\n' "$ns" "$ni"
  (( skip_spec ))  && printf '  specs.log already had records — skipped\n'
  (( skip_issue )) && printf '  issues.log already had records — skipped\n'
  return 0
}

# alloc_seed_arm_baselines <spec-content> <issue-content> — after a successful
# seed commit, record each written log as the local erosion baseline (byte-
# identical to the committed blob), so the first post-seed allocation's growth
# guard compares against the seeded state, not an empty one (security F4).
alloc_seed_arm_baselines() {
  local ws="$1" wi="$2"
  [[ -n "$ws" ]] && printf '%s\n' "$ws" | alloc_update_baseline "$(alloc_log_file spec)"
  [[ -n "$wi" ]] && printf '%s\n' "$wi" | alloc_update_baseline "$(alloc_log_file issue)"
  return 0
}

# alloc_publish <builder> [builder-args...]
#   The shared batch-publish step behind every N-record registry writer (seed,
#   reconcile). Runs the bounded CAS retry loop with the in-loop erosion re-check
#   each writer must apply, then delegates the "what to write, given the current
#   logs" decision to <builder>. Each attempt re-reads the coordination tip,
#   verifies neither writable log has eroded (the local baseline must remain a
#   byte-prefix of the current blob), invokes <builder> to compute the new
#   per-log content and the success payload, builds ONE commit
#   (alloc_seed_commit), and lands it with the tier's compare-and-swap. On
#   success it arms the erosion baseline for each written log and prints the
#   payload; a lost CAS re-reads and retries.
#
#   Builder contract — called in-scope so it sets alloc_publish's locals through
#   bash dynamic scope (it must assign, never re-declare, these names):
#     "$builder" <cur_specs> <cur_issues> <who> [builder-args...]
#       sets PUB_SPEC    — new specs.log content  ("" leaves that log untouched)
#       sets PUB_ISSUE   — new issues.log content ("" leaves that log untouched)
#       sets PUB_PAYLOAD — text printed to stdout on a successful commit
#       returns 0 to proceed, 1 to abort the publish (its error already on stderr)
alloc_publish() {
  local builder="$1"; shift
  alloc_write_contained || return 1
  local branch ref remote
  branch="$(alloc_coord_branch)" || return 1
  ref="refs/heads/$branch"
  remote="$(alloc_coord_remote)"
  local who email
  who="$(alloc_sanitize_who "$(git config user.name 2>/dev/null || printf '')")"
  email="$(alloc_sanitize_who "$(git config user.email 2>/dev/null || printf '')")"
  [[ -n "$who" ]]   || who="jim-allocator"
  [[ -n "$email" ]] || email="jim-allocator@localhost"
  local specs_file issues_file
  specs_file="$(alloc_log_file spec)"; issues_file="$(alloc_log_file issue)"
  local attempts=5 attempt tip commit
  local raw_specs raw_issues cur_specs cur_issues
  local PUB_SPEC PUB_ISSUE PUB_PAYLOAD
  for ((attempt=1; attempt<=attempts; attempt++)); do
    if [[ -n "$remote" ]]; then
      tip="$(alloc_origin_tip "$remote" "$branch")" || return 1
    else
      tip="$(git rev-parse --verify --quiet --end-of-options "$ref" 2>/dev/null || true)"
    fi
    # In-loop erosion re-check on BOTH writable logs: the seen baseline for each
    # must remain a byte-prefix of the current registry, else the history was
    # truncated or rewritten — hard-fail rather than publish onto an eroded log.
    # The trailing-X capture preserves the blob's final newline so the prefix
    # check is line-boundary precise; cur_* drops that newline for content use.
    raw_specs=""; raw_issues=""
    if [[ -n "$tip" ]]; then
      raw_specs="$(git cat-file -p "$tip:$specs_file" 2>/dev/null; printf X)";   raw_specs="${raw_specs%X}"
      raw_issues="$(git cat-file -p "$tip:$issues_file" 2>/dev/null; printf X)"; raw_issues="${raw_issues%X}"
    fi
    if ! alloc_check_erosion "$specs_file" "$raw_specs"; then
      echo "error: coordination branch '$branch' shows registry erosion for $specs_file" \
           "(history truncated or rewritten); refusing to publish" >&2
      return 1
    fi
    if ! alloc_check_erosion "$issues_file" "$raw_issues"; then
      echo "error: coordination branch '$branch' shows registry erosion for $issues_file" \
           "(history truncated or rewritten); refusing to publish" >&2
      return 1
    fi
    cur_specs="${raw_specs%$'\n'}"; cur_issues="${raw_issues%$'\n'}"
    PUB_SPEC=""; PUB_ISSUE=""; PUB_PAYLOAD=""
    "$builder" "$cur_specs" "$cur_issues" "$who" "$@" || return 1
    if [[ -z "$PUB_SPEC" && -z "$PUB_ISSUE" ]]; then
      # The builder succeeded with nothing to write — a legitimate no-op (e.g.
      # every pending realization already landed on a concurrent pass). Report
      # the payload and stop; the seed builder never reaches here (it aborts).
      [[ -n "$PUB_PAYLOAD" ]] && printf '%s\n' "$PUB_PAYLOAD"
      return 0
    fi
    commit="$(alloc_seed_commit "$tip" "$who" "$email" "$PUB_SPEC" "$PUB_ISSUE")" || return 1
    if [[ -n "$remote" ]]; then
      if git push --quiet "$remote" "$commit:$ref" 2>/dev/null; then
        git update-ref "$ref" "$commit" 2>/dev/null || true
        alloc_seed_arm_baselines "$PUB_SPEC" "$PUB_ISSUE"
        [[ -n "$PUB_PAYLOAD" ]] && printf '%s\n' "$PUB_PAYLOAD"
        return 0
      fi
    else
      if git update-ref "$ref" "$commit" "$tip" 2>/dev/null; then
        alloc_seed_arm_baselines "$PUB_SPEC" "$PUB_ISSUE"
        [[ -n "$PUB_PAYLOAD" ]] && printf '%s\n' "$PUB_PAYLOAD"
        return 0
      fi
    fi
    (( attempt < attempts )) && alloc_backoff "$attempt"
  done
  echo "error: publish failed after $attempts attempts (contention on $branch)" >&2
  return 1
}

# alloc_seed_publish_builder <cur_specs> <cur_issues> <who> <spec-records> <issue-records>
#   The seed's publish decision (an alloc_publish builder): write a kind only
#   when its log is still empty at this attempt's tip (empty-precondition — a
#   kind populated by a concurrent allocation is refused, never clobbered);
#   abort when nothing is writable (already seeded). Sets the PUB_* locals
#   alloc_publish reads back through dynamic scope.
alloc_seed_publish_builder() {
  local cur_specs="$1" cur_issues="$2" _who="$3" spec_records="$4" issue_records="$5"
  local skip_spec=0 skip_issue=0
  PUB_SPEC=""; PUB_ISSUE=""
  if [[ -n "$spec_records" ]]; then
    if [[ -z "$cur_specs" ]]; then PUB_SPEC="$spec_records"; else skip_spec=1; fi
  fi
  if [[ -n "$issue_records" ]]; then
    if [[ -z "$cur_issues" ]]; then PUB_ISSUE="$issue_records"; else skip_issue=1; fi
  fi
  if [[ -z "$PUB_SPEC" && -z "$PUB_ISSUE" ]]; then
    # Nothing writable: every kind with artifacts is already seeded.
    echo "error: registry already seeded (specs.log/issues.log already have records); refusing to re-seed" >&2
    return 1
  fi
  PUB_PAYLOAD="$(alloc_seed_report "$PUB_SPEC" "$PUB_ISSUE" "$skip_spec" "$skip_issue")"
  return 0
}

# alloc_seed_land <spec-records> <issue-records> — land the derived records via
# the shared batch-publish (same tier selection, plumbing, erosion guard, and
# retry as an allocation), as ONE commit setting the writable logs.
alloc_seed_land() {
  local spec_records="$1" issue_records="$2"
  if [[ -z "$spec_records" && -z "$issue_records" ]]; then
    echo "error: nothing to seed — no spec or issue artifacts found" >&2
    return 1
  fi
  alloc_publish alloc_seed_publish_builder "$spec_records" "$issue_records"
}

# ─── Section: reconcile (realize pending provisionals into real ids) ─────────

# alloc_reconcile_publish_builder <cur_specs> <cur_issues> <who> <pending...>
#   The reconcile publish decision (an alloc_publish builder): realize the
#   pending provisionals against THIS attempt's issues.log, append one real
#   `issue allocate` record per newly-realized id, and set PUB_ISSUE to the grown
#   log plus PUB_PAYLOAD to the provisional→real mapping. Leaves specs.log
#   untouched. When every pending id is already realized (nothing new — e.g. a
#   concurrent pass landed them, or a resumed run), it writes nothing and
#   alloc_publish reports the mapping as a clean no-op. Aborts (rc 1) if realize
#   halts (within-batch duplicate / boundary-invalid pending id).
alloc_reconcile_publish_builder() {
  local cur_issues="$2" who="$3"; shift 3
  local realized date fid ord state mapping="" newrecs=""
  realized="$(printf '%s\n' "$cur_issues" | alloc_reconcile_realize "$@")" || return 1
  date="$(bash "$JIMFILE" date)" || return 1
  while IFS=$'\t' read -r fid ord state; do
    [[ -n "$fid" ]] || continue
    mapping+="${fid}"$'\t'"${ord}"$'\n'
    [[ "$state" == new ]] && newrecs+="$(alloc_encode_allocate_issue "$ord" "$fid" "$date" "$who")"$'\n'
  done <<< "$realized"
  PUB_PAYLOAD="${mapping%$'\n'}"
  if [[ -n "$newrecs" ]]; then
    if [[ -n "$cur_issues" ]]; then
      PUB_ISSUE="${cur_issues}"$'\n'"${newrecs%$'\n'}"
    else
      PUB_ISSUE="${newrecs%$'\n'}"
    fi
  else
    PUB_ISSUE=""
  fi
  return 0
}

# alloc_reconcile_issue <apply>  (pending set on stdin, one id per line)
#   Realize the consumer's pending provisional issue identities. Reads the set
#   from stdin (blank lines ignored). An empty set is a clean no-op. The
#   coordination point must be reachable — a still-unreachable origin realizes
#   nothing, reports it is still offline, and changes nothing (rc 0), distinct
#   from the allocation-time hard fail. With apply=1 it publishes the new reals
#   through the shared, erosion-guarded batch publish (one CAS commit,
#   all-or-none, baseline-armed) and prints the provisional→real mapping. The
#   mapping goes to stdout; status notes (nothing pending / still offline) go to
#   stderr so stdout stays parseable. The read-only preview (apply=0) is added
#   alongside apply so it computes the identical mapping without publishing.
alloc_reconcile_issue() {
  local apply="$1"
  local -a raw=(); mapfile -t raw
  local -a pending=(); local p
  for p in "${raw[@]}"; do [[ -n "$p" ]] && pending+=("$p"); done
  if (( ${#pending[@]} == 0 )); then
    echo "reconcile: nothing pending — nothing to realize" >&2
    return 0
  fi
  if ! alloc_origin_reachable; then
    echo "reconcile: coordination point unreachable — still offline, nothing changed" >&2
    return 0
  fi
  if (( apply )); then
    alloc_publish alloc_reconcile_publish_builder "${pending[@]}"
  else
    # Preview: refresh the last-seen coordination ref (best-effort, non-mutating
    # to the shared branch — the peek model), realize read-only, and print the
    # same provisional→real mapping apply would (dropping the internal new/have
    # column). A stop condition surfaces on stderr with no mapping.
    alloc_peek_refresh
    alloc_read_log issue | alloc_reconcile_realize "${pending[@]}" | cut -f1,2
  fi
}

# alloc_reconcile_spec_publish_builder <cur_specs> <cur_issues> <who> <pending...>
#   The spec-reconcile publish decision (an alloc_publish builder): realize the
#   pending provisional identities against THIS attempt's specs.log, append one
#   real `spec allocate` record per newly-realized identity — preceded by a
#   `group allocate` record for any group the registry does not already hold, so
#   realizing into a never-seen group claims it exactly once — and set PUB_SPEC
#   to the grown log plus PUB_PAYLOAD to the mapping. Leaves issues.log
#   untouched. Each spec record's date is the identity's issuance date, taken
#   from the pending token, because that field is what the idempotency key reads
#   back; the group record's date is the day the group was claimed, which is
#   provenance only. When nothing is new it writes nothing and alloc_publish
#   reports the mapping as a clean no-op. Aborts (rc 1) if realize halts.
alloc_reconcile_spec_publish_builder() {
  local cur_specs="$1" who="$3"; shift 3
  local realized gdate pend id state grp tok body date slug
  local mapping="" newrecs=""
  local -A claimed=()
  realized="$(printf '%s\n' "$cur_specs" | alloc_reconcile_realize_spec "$@")" || return 1
  gdate="$(bash "$JIMFILE" date)" || return 1
  while IFS=$'\t' read -r pend id state; do
    [[ -n "$pend" ]] || continue
    mapping+="${pend}"$'\t'"${id}"$'\t'"${state}"$'\n'
    [[ "$state" == new ]] || continue
    grp="${id%/*}"
    tok="${pend##*/}"; body="${tok#"$ALLOC_PROV_PREFIX"}"
    date="${body%%-*}"; slug="${body#*-}"
    if [[ -z "${claimed[$grp]:-}" ]] && ! printf '%s' "$cur_specs" | alloc_group_present "$grp"; then
      newrecs+="$(alloc_encode_allocate_group "$grp" "$gdate" "$who")"$'\n'
    fi
    claimed["$grp"]=1
    newrecs+="$(alloc_encode_allocate_spec "$id" "$slug" "$date" "$who")"$'\n'
  done <<< "$realized"
  PUB_PAYLOAD="${mapping%$'\n'}"
  if [[ -n "$newrecs" ]]; then
    if [[ -n "$cur_specs" ]]; then
      PUB_SPEC="${cur_specs}"$'\n'"${newrecs%$'\n'}"
    else
      PUB_SPEC="${newrecs%$'\n'}"
    fi
  else
    PUB_SPEC=""
  fi
  return 0
}

# alloc_reconcile_spec <apply>  (pending set on stdin, one id per line)
#   Realize the consumer's pending provisional spec identities. Reads the set
#   from stdin (blank lines ignored). An empty set is a clean no-op. The
#   coordination point must be reachable — a still-unreachable origin realizes
#   nothing, reports it is still offline, and changes nothing (rc 0), distinct
#   from the allocation-time hard fail. With apply=1 it publishes the new reals
#   through the shared, erosion-guarded batch publish (one CAS commit,
#   all-or-none, baseline-armed) and prints the mapping.
#
#   Both paths print all three fields, preview included: two identities can key
#   alike, so whether an identity was found rather than freshly allocated is the
#   developer's tell before anything is applied, and dropping it would hide the
#   one signal that separates a resumed run from a collision.
alloc_reconcile_spec() {
  local apply="$1"
  local -a raw=(); mapfile -t raw
  local -a pending=(); local p
  for p in "${raw[@]}"; do [[ -n "$p" ]] && pending+=("$p"); done
  if (( ${#pending[@]} == 0 )); then
    echo "reconcile: nothing pending — nothing to realize" >&2
    return 0
  fi
  if ! alloc_origin_reachable; then
    echo "reconcile: coordination point unreachable — still offline, nothing changed" >&2
    return 0
  fi
  if (( apply )); then
    alloc_publish alloc_reconcile_spec_publish_builder "${pending[@]}"
  else
    # Preview: refresh the last-seen coordination ref (best-effort, non-mutating
    # to the shared branch — the peek model) and realize read-only.
    alloc_peek_refresh
    alloc_read_log spec | alloc_reconcile_realize_spec "${pending[@]}"
  fi
}

cmd_reconcile() {
  local kind="${1:-}"; shift || true
  local apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) apply=1; shift ;;
      *)
        echo "error: unknown option '$1' for reconcile (usage: reconcile <issue|spec> [--apply])" >&2
        return 2
        ;;
    esac
  done
  case "$kind" in
    issue)
      alloc_in_repo || return 1
      alloc_preflight || return 1
      alloc_reconcile_issue "$apply"
      ;;
    spec)
      alloc_in_repo || return 1
      alloc_preflight || return 1
      alloc_reconcile_spec "$apply"
      ;;
    *)
      echo "error: reconcile kind must be 'issue' or 'spec'" >&2
      return 2
      ;;
  esac
}

cmd_resolve() {
  local kind="${1:-}" queried="${2:-}"
  if [[ -z "$kind" || -z "$queried" ]]; then
    echo "error: 'resolve' requires <kind> and <id>" >&2
    return 2
  fi
  case "$kind" in
    spec)  alloc_read_log spec  | alloc_resolve_spec  "$queried" ;;
    issue) alloc_read_log issue | alloc_resolve_issue "$queried" ;;
    *)
      echo "error: resolve kind must be 'spec' or 'issue'" >&2
      return 2
      ;;
  esac
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

usage() {
  cat >&2 <<'USAGE'
usage:
  jimalloc.sh allocate spec  <group> <subject>   allocate a spec id
  jimalloc.sh allocate issue <subject>           allocate an issue id
  jimalloc.sh peek     spec  <group>             advisory next spec id (no commit)
  jimalloc.sh peek     issue                     advisory next issue num (no commit)

  allocate spec / peek spec accept --follow-redirect to accept a group redirect;
  without it a group renamed away is refused, with the redirect named.
  jimalloc.sh resolve  spec  <group>/<NNN>       resolve a spec id to its current name
  jimalloc.sh resolve  issue <num|full-id>       resolve an issue id to its current name
  jimalloc.sh seed     [--apply]                 preview (or --apply) a one-time registry bootstrap
  jimalloc.sh reconcile issue [--apply]          realize pending provisionals (stdin) into real ids
  jimalloc.sh reconcile spec  [--apply]          realize pending provisional spec identities (stdin)
  jimalloc.sh -c <path> <subcmd>                 use <path> instead of ./jimconf.toml
USAGE
}

main() {
  if [[ "${1:-}" == "-c" ]]; then
    if [[ -z "${2:-}" ]]; then
      echo "error: -c requires a path argument" >&2
      return 2
    fi
    CONFIG_FILE="$2"
    shift 2
  fi
  local subcmd="${1:-}"
  if [[ -z "$subcmd" ]]; then
    usage
    return 2
  fi
  shift
  case "$subcmd" in
    allocate)  cmd_allocate  "$@" ;;
    peek)      cmd_peek      "$@" ;;
    resolve)   cmd_resolve   "$@" ;;
    seed)      cmd_seed      "$@" ;;
    reconcile) cmd_reconcile "$@" ;;
    *)
      echo "error: unknown subcommand '$subcmd'" >&2
      usage
      return 2
      ;;
  esac
}

# Guarded so the pure record-layer functions can be sourced and unit-tested
# without executing the CLI (BASH_SOURCE[0] != $0 when sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
