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
#   bash jimalloc.sh sweep                              read-only tree-vs-registry integrity report
#   bash jimalloc.sh catch-up [--apply]                 preview/apply the records a non-empty log lacks
#   bash jimalloc.sh -c <path> <subcmd>                 use <path> as jimconf.toml
#
# EXIT CODES
#   0  Success.
#   1  Hard failure (unreachable coordination point / erosion detected /
#      retries exhausted / a rejected registry or config token).
#   2  Malformed invocation (missing argument, unknown subcommand).
#   3  The verb's content outcome: drift found (sweep), or a partial repair
#      that left unrepairable drift behind (catch-up --apply).
#   4  Could not check (sweep): no coordination branch to read, or a tree the
#      derivation refuses. Distinct from both clean and drift, because a check
#      that could not run must never be read as a pass.
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
# Path to the ledger CLI. The lift's input is the specs-root ledger, and its
# grammar belongs to the ledger — this script asks for normalized pair events
# rather than learning to parse events of its own.
JIMLEDGER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ledger/scripts" 2>/dev/null && pwd)/jimledger.sh"

# Optional -c <path> override for jimconf.toml. Empty when not supplied;
# production consumers never pass it (tests and ad-hoc inspection do).
CONFIG_FILE=""

# Reserved provisional-ordinal prefix. A provisional identifier carries this in
# its ordinal slot, keeping it grammar-distinct from every allocated ordinal
# (allocated ordinals are ^[0-9]+$), so the two can never be confused and a
# provisional can never enter the registry high-water. Uppercase, so it cannot
# collide with a jimfile.sh slug (slugs are lowercase).
PROV_PREFIX="P-"

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
#   spec  rename   <group>/<NNN> <newgroup>/<newNNN> <date> <who>
#   group rename   <old-group> <new-group> <date> <who>
#   issue rename   <NNN> <newNNN> <date> <who>
#   spec  realize  <group>/P-<date>-<slug> <group>/<NNN> <date> <who>
#
# The realize kind is deliberately NOT a rename. A rename source is an ordinal
# the group consumed and can never reissue, and the high-water fold counts it as
# such; a provisional token is no ordinal at all. Giving realization its own verb
# is what keeps the reserved form out of the vacating fold entirely, rather than
# relying on every reader to special-case it.
#
# Every kind carries <who>. Field counts are EXACT for `rename` and `realize`: a
# record whose verb is one of those but whose shape is not — a field short, a
# field long, or a field failing its own gate — is not that record, and is
# degraded and skipped rather than half-parsed on the fields that did read.
# `allocate` is looser by history: it reads the fields it needs, so a record
# short its trailing fields still registers a live claim. A record whose VERB is unknown
# is skipped the same way and stays reportable as its own thing, which is what
# keeps the kind namespace open for a later record kind to be added without any
# reader here mistaking it for a neighbour.

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
#
# Each DISTINCT token crosses jimfile.sh once per process. Validity is a pure
# function of the token, so the cache cannot change an answer — it removes the
# repeat forks a whole-registry scan pays, where the same group, slug, or id is
# revalidated on both the tree side and the record side. The cache lives inside
# the boundary rather than beside it, so no call site has to remember to use a
# faster variant.
declare -A ALLOC_TOKEN_OK=()
alloc_valid_token() {
  local tok="$1"
  # The empty token is rejected here rather than by the boundary, because it is
  # not a usable array subscript and the cache would fault on it. Records are
  # parsed with `read`, so any line short a field yields one — and the registry
  # is push-writable, so a single truncated line must stay a skipped record, not
  # a broken read path for every clone.
  [[ -n "$tok" ]] || return 1
  if [[ -z "${ALLOC_TOKEN_OK[$tok]:-}" ]]; then
    if bash "$JIMFILE" valid-id "$tok" >/dev/null 2>&1; then
      ALLOC_TOKEN_OK[$tok]=y
    else
      ALLOC_TOKEN_OK[$tok]=n
    fi
  fi
  [[ "${ALLOC_TOKEN_OK[$tok]}" == y ]]
}

# alloc_is_prov_form <name> — exit 0 iff <name> is the reserved provisional
# ordinal form: the reserved prefix over a boundary-valid token, exactly what
# alloc_prov_ordinal builds. Narrow by construction — a name that merely starts
# with the prefix but carries a token the boundary rejects is not the reserved
# form, so nothing malformed can pass itself off as reserved.
alloc_is_prov_form() {
  local name="$1" tok
  [[ "$name" == "$PROV_PREFIX"* ]] || return 1
  tok="${name#"$PROV_PREFIX"}"
  [[ -n "$tok" ]] || return 1
  alloc_valid_token "$tok"
}

# prov_id_boundary <token> — the id boundary as is_prov_token's shared body
# reaches it. Local adapter: the allocator crosses the boundary through its
# memoized token check, so a repeated probe costs no extra subprocess.
prov_id_boundary() { alloc_valid_token "$1"; }

# is_prov_token <token>
#   Exit 0 iff <token> is the reserved provisional ordinal form the allocator
#   issues: the prefix, then an 8-digit issuance date, then a slug, with the
#   post-prefix body AND the slug alone each carried through the id boundary.
#   The token is the whole ordinal slot — a spec bound while the coordination
#   point was unreachable wears it as its directory name, so there is no
#   separate ordinal and slug to compose. Grammar-distinct from a real ordinal
#   by construction: no token satisfies both.
#
#   SYNC: the function body below is mirrored verbatim in
#   skills/file/scripts/jimfile.sh and skills/spec/scripts/reconcile.sh. A
#   tests/jimfile.sh case asserts the three copies are byte-identical — keep
#   them in lockstep when editing. Each script supplies its own PROV_PREFIX and
#   prov_id_boundary; the grammar itself lives entirely in the body.
is_prov_token() {
  local token="$1" body date slug
  [[ "$token" == "$PROV_PREFIX"* ]] || return 1
  body="${token#"$PROV_PREFIX"}"
  [[ -n "$body" ]] || return 1
  date="${body%%-*}"; slug="${body#*-}"
  [[ "$date" =~ ^[0-9]{8}$ ]] || return 1
  [[ -n "$slug" && "$slug" != "$body" ]] || return 1
  prov_id_boundary "$body" || return 1
  prov_id_boundary "$slug"
}

# alloc_valid_provid <id> — exit 0 iff <id> is "<group>/P-<date>-<slug>": exactly
# one '/', a boundary-valid group, and an ordinal slot in the reserved
# provisional form. Grammar-distinct from alloc_valid_specid by construction:
# no id satisfies both.
alloc_valid_provid() {
  local id="$1" grp tok
  [[ "$id" == */* ]] || return 1
  grp="${id%/*}"; tok="${id##*/}"
  [[ "$grp" == *"/"* ]] && return 1
  alloc_valid_token "$grp" || return 1
  is_prov_token "$tok"
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
#   reproduce. On a rename record each side is judged INDEPENDENTLY: an
#   unrepresentable source no longer drops its destination's establishing claim,
#   and a walk that stops at a side this function cannot represent discloses
#   that rather than reading as though the record were absent.
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

# alloc_encode_rename_spec   <old-specid> <new-specid> <date> <who>
# alloc_encode_rename_group  <old-group>  <new-group>  <date> <who>
# alloc_encode_rename_issue  <old-ord>    <new-ord>    <date> <who>
# alloc_encode_realize_spec  <provid>     <specid>     <date> <who>
#   The emission half of the grammar above. Same discipline as the allocate
#   encoders: fixed fields are pre-validated single tokens supplied by the
#   emitting path, and the trailing free-text <who> is sanitized here.
alloc_encode_rename_spec() {
  printf 'spec rename %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}
alloc_encode_rename_group() {
  printf 'group rename %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}
alloc_encode_rename_issue() {
  printf 'issue rename %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}
alloc_encode_realize_spec() {
  printf 'spec realize %s %s %s %s\n' "$1" "$2" "$3" "$(alloc_sanitize_who "${4:-}")"
}

# alloc_record_tail_ok <date> <who> <rest> — exit 0 iff a six-field record's
# trailing pair is present, alone, and inside its gates. `read` puts everything
# past the sixth field into <rest>, so a seventh field is as visible here as a
# missing one — which is what makes the field count exact rather than a floor.
alloc_record_tail_ok() {
  [[ -n "$2" && -z "${3:-}" ]] || return 1
  [[ "$1" =~ ^[0-9]{8}$ ]] || return 1
  [[ "$2" =~ ^[A-Za-z0-9._@-]{1,64}$ ]]
}

# alloc_rename_side <kind> <token> — print <token> in the comparable form its
# kind uses (spec ids canonicalized, issue ordinals base-10 normalized, group
# names as themselves); rc 1 when the token fails that kind's gate.
alloc_rename_side() {
  case "$1" in
    spec)  alloc_canon_specid "$2" ;;
    group) alloc_valid_token "$2" && printf '%s\n' "$2" ;;
    issue) alloc_valid_ord "$2" && printf '%s\n' "$((10#$2))" ;;
    *) return 1 ;;
  esac
}

# alloc_rename_scan <spec|group|issue>   (log on stdin)
#   THE rename-record reader. Every consumer of a rename record — both
#   resolvers, the alias map, both high-water folds, both integrity classifiers,
#   group coverage, and the sweep — folds this one output instead of carrying a
#   private parse. One structure read by many readers with many rules is the
#   drift this file has already paid for; one rule is how the shape change above
#   lands in a single place.
#
#   Emits one TAB-separated row per record of the requested selector:
#     <kind> <src> <src_ok> <dst> <dst_ok> <date> <who> <pos>
#   `spec` selects spec AND group renames, because every spec-side consumer
#   replays both and needs them interleaved in file order; `group` selects group
#   renames alone; `issue` selects issue renames. <pos> is the record's 1-based
#   line number, so a consumer that must interleave with allocate records — the
#   resolvers do — indexes back into the log it read.
#
#   SHAPE is decided here and only here: exactly six fields, a <date> of eight
#   digits, and a <who> inside the write side's own sanitized character set. A
#   record failing any of those never appears in the output at all.
#
#   CANONICALIZATION is reported PER SIDE rather than being a second shape gate.
#   A record whose source is an ordinal this system cannot represent still
#   establishes its destination, so dropping the whole row on either side's
#   failure would silence a claim that was really made. Consumers apply their own
#   semantics: the folds count each valid side independently, and the resolvers
#   anchor on a valid side while disclosing a dropped one. A side that failed
#   carries its raw token through the report sanitizer, so a row is safe to print
#   and can never break the row's own delimiter.
alloc_rename_scan() {
  local want="$1" line pos=0 c1 c2 c3 c4 c5 c6 c7
  local src dst src_ok dst_ok
  while IFS= read -r line; do
    pos=$((pos + 1))
    read -r c1 c2 c3 c4 c5 c6 c7 <<< "$line"
    [[ "$c2" == rename ]] || continue
    case "$want:$c1" in
      spec:spec|spec:group|group:group|issue:issue) ;;
      *) continue ;;
    esac
    alloc_record_tail_ok "$c5" "$c6" "$c7" || continue
    if src="$(alloc_rename_side "$c1" "$c3")"; then
      src_ok=y
    else
      src="$(alloc_sanitize_field "$c3")"; src_ok=n
    fi
    if dst="$(alloc_rename_side "$c1" "$c4")"; then
      dst_ok=y
    else
      dst="$(alloc_sanitize_field "$c4")"; dst_ok=n
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$c1" "$src" "$src_ok" "$dst" "$dst_ok" "$c5" "$c6" "$pos"
  done
}

# alloc_realize_scan <spec>   (log on stdin)
#   THE realize-record reader, the same discipline as alloc_rename_scan over the
#   other new kind. Emits one TAB-separated row per well-formed record:
#     <prov> <prov_ok> <real> <real_ok> <date> <who> <pos>
#   Takes the same selector argument as the rename scan so the two are
#   interchangeable to a caller that only wants a count; only `spec` yields rows,
#   because realization is a spec-side event.
alloc_realize_scan() {
  local want="$1" line pos=0 c1 c2 c3 c4 c5 c6 c7
  local prov real prov_ok real_ok
  [[ "$want" == spec ]] || { cat >/dev/null; return 0; }
  while IFS= read -r line; do
    pos=$((pos + 1))
    read -r c1 c2 c3 c4 c5 c6 c7 <<< "$line"
    [[ "$c1" == spec && "$c2" == realize ]] || continue
    alloc_record_tail_ok "$c5" "$c6" "$c7" || continue
    if alloc_valid_provid "$c3"; then
      prov="$c3"; prov_ok=y
    else
      prov="$(alloc_sanitize_field "$c3")"; prov_ok=n
    fi
    if real="$(alloc_canon_specid "$c4")"; then
      real_ok=y
    else
      real="$(alloc_sanitize_field "$c4")"; real_ok=n
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$prov" "$prov_ok" "$real" "$real_ok" "$c5" "$c6" "$pos"
  done
}

# alloc_known_verbs — the kind/verb pairs this build knows, one per line. The
# scan rules decide what a KNOWN record must look like; this decides which pairs
# are known at all, so the two answers cannot drift apart.
alloc_known_verbs() {
  printf '%s\n' 'spec allocate' 'spec rename' 'spec realize' \
                'group allocate' 'group rename' \
                'issue allocate' 'issue rename'
}

# alloc_malformed_count <selector> <verb> <scan-fn>  (log on stdin) → integer
#   How many records carry <verb> under the selector's kinds but not that verb's
#   one shape. These name no identity to compare a tree against, so they are
#   non-coverage in the strictest sense — a log full of them must not report like
#   a clean one. Counted by subtraction from the scan rule's own output, so the
#   count and the parse can never disagree about what "the one shape" is.
alloc_malformed_count() {
  local want="$1" verb="$2" scan="$3" c1 c2 all=0 good=0
  local -a lines=(); mapfile -t lines
  local i n=${#lines[@]}
  for ((i=0; i<n; i++)); do
    read -r c1 c2 _ <<< "${lines[i]}"
    [[ "$c2" == "$verb" ]] || continue
    case "$want:$c1" in
      spec:spec|spec:group|group:group|issue:issue) all=$((all + 1)) ;;
    esac
  done
  if (( n )); then
    good="$(printf '%s\n' "${lines[@]}" | "$scan" "$want" | grep -c . || true)"
  fi
  printf '%d' "$(( all - good ))"
}

# alloc_unknown_verb_count  (log on stdin) → integer
#   How many records name a kind/verb pair this build does not know. Reported
#   apart from the malformed count on purpose: an unknown verb is how a later
#   record kind arrives, and a reader that folded it into "malformed" would be
#   claiming the log is broken when it is merely newer. Blank lines are not
#   records and do not count.
alloc_unknown_verb_count() {
  local line c1 c2 n=0 pair
  local -A known=()
  while IFS= read -r pair; do known["$pair"]=1; done < <(alloc_known_verbs)
  while IFS= read -r line; do
    read -r c1 c2 _ <<< "$line"
    [[ -n "$c1" ]] || continue
    [[ -n "${known[$c1 $c2]:-}" ]] || n=$((n + 1))
  done
  printf '%d' "$n"
}

# alloc_rename_index  (log on stdin)  → fills the caller's `rn` associative array
#   Load alloc_rename_scan's rows keyed by record position, for a consumer that
#   must walk the log in file order and meet each rename where it sits. The
#   caller declares `rn` and passes the selector; each value is the row minus its
#   position column.
alloc_rename_index() {
  local rk rsrc rsok rdst rdok rdate rwho rpos
  while IFS=$'\t' read -r rk rsrc rsok rdst rdok rdate rwho rpos; do
    rn[$rpos]="$rk"$'\t'"$rsrc"$'\t'"$rsok"$'\t'"$rdst"$'\t'"$rdok"$'\t'"$rdate"$'\t'"$rwho"
  done < <(alloc_rename_scan "$1")
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
#
#   A PROVISIONAL identity is answerable here too: its realization record names
#   the ordinal it became, and the walk continues from that ordinal, so an
#   offline-frozen citation dereferences through whatever happened afterwards.
#   Unrealized, it is not a claim on anything and does not resolve.
alloc_resolve_spec() {
  local queried="$1"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3
  if alloc_valid_provid "$queried"; then
    local zprov zpok zreal zrok realized=0
    while IFS=$'\t' read -r zprov zpok zreal zrok _ _ _; do
      [[ "$zpok" == y && "$zrok" == y && "$zprov" == "$queried" ]] || continue
      queried="$zreal"; realized=1
    done < <(printf '%s\n' ${lines[@]+"${lines[@]}"} | alloc_realize_scan spec)
    if (( ! realized )); then
      echo "error: provisional spec id '$queried' has not been realized" >&2
      return 1
    fi
  elif ! alloc_valid_specid "$queried"; then
    echo "error: invalid spec id '$queried'" >&2
    return 1
  fi
  # Past the shape guard the only way canonicalization fails is the width bound,
  # so the message names it rather than repeating "invalid".
  queried="$(alloc_canon_specid "$queried")" \
    || { echo "error: spec id '$1' exceeds the ordinal width the registry can be rebuilt from (max $ALLOC_MAX_ORD_DIGITS digits)" >&2; return 1; }
  local qgroup="${queried%/*}"
  local anchor=-1 known=0
  # Rename records come from the one scan rule, keyed by position so they still
  # apply exactly where they sit among the allocate records.
  local -A rn=()
  local rk rsrc rsok rdst rdok
  (( n )) && alloc_rename_index spec < <(printf '%s\n' "${lines[@]}")
  # Two allocate records claiming one identity CONCURRENTLY is a contradiction
  # the registry's uniqueness cannot represent. Answering from the later one
  # hands back a confidently wrong referent, so both claimants are remembered and
  # the answer becomes a refusal naming them.
  #
  # Concurrently is the load-bearing word: a name this replay already treats as
  # reusable — vacated by a rename that moved its holder away, then claimed again
  # — legitimately carries two allocate records, and only one of them is live.
  # So a vacating event clears the live claims rather than adding to them, which
  # keeps the refusal aimed at contradictions and off the reuse path.
  local dup_a=-1 dup_b=-1
  # Record ids are canonicalized before every comparison, so a record spelling
  # an ordinal unpadded still anchors and still replays.
  # Positions where the queried id is named as a rename SOURCE and nothing
  # establishes it. One such record makes the id dereferenceable-with-disclosure;
  # two make it incoherent, since a claim that was never made cannot have been
  # moved twice.
  local -a src_at=()
  for ((i=0; i<n; i++)); do
    if [[ -n "${rn[$((i + 1))]:-}" ]]; then
      IFS=$'\t' read -r rk rsrc rsok rdst rdok _ _ <<< "${rn[$((i + 1))]}"
      if [[ "$rk" == spec ]]; then
        [[ "$rdok" == y && "$rdst" == "$queried" ]] && { anchor=$i; known=1; }
        # A vacating rename clears the claim it moved — but only when there is
        # one claim to move. With two already live, a rename takes one of them
        # and leaves the other, so which one this id now names is exactly the
        # question the refusal exists to refuse; clearing here would answer it
        # arbitrarily.
        if [[ "$rsok" == y && "$rsrc" == "$queried" ]]; then
          src_at+=( "$((i + 1))" )
          (( dup_b < 0 )) && { dup_a=-1; dup_b=-1; }
        fi
      else
        [[ "$rdok" == y && "$rdst" == "$qgroup" ]] && known=1
        [[ "$rsok" == y && "$rsrc" == "$qgroup" ]] && (( dup_b < 0 )) && { dup_a=-1; dup_b=-1; }
      fi
      continue
    fi
    read -r c1 c2 c3 _ <<< "${lines[i]}"
    if [[ "$c1" == spec && "$c2" == allocate ]]; then
      c3="$(alloc_canon_specid "$c3")" || continue
      if [[ "$c3" == "$queried" ]]; then
        if (( dup_a < 0 )); then dup_a=$i; elif (( dup_b < 0 )); then dup_b=$i; fi
        anchor=$i; known=1
      fi
    fi
  done
  if (( dup_b >= 0 )); then
    echo "error: duplicate spec identity '$queried' in the registry — claimed by records $((dup_a + 1)) and $((dup_b + 1)); refusing to answer" >&2
    return 1
  fi
  local disclose_src=0 disclose_dst=0
  if (( ! known )) && (( ${#src_at[@]} )); then
    if (( ${#src_at[@]} > 1 )); then
      echo "error: spec id '$queried' is vacated by more than one rename record and allocated by none — records ${src_at[0]} and ${src_at[1]}; refusing to answer" >&2
      return 1
    fi
    known=1; disclose_src="${src_at[0]}"
  fi
  local current="$queried"
  for ((i=0; i<n; i++)); do
    (( anchor >= 0 && i <= anchor )) && continue
    [[ -n "${rn[$((i + 1))]:-}" ]] || continue
    IFS=$'\t' read -r rk rsrc rsok rdst rdok _ _ <<< "${rn[$((i + 1))]}"
    [[ "$rsok" == y ]] || continue
    if [[ "$rk" == spec ]]; then
      [[ "$rsrc" == "$current" ]] || continue
    else
      [[ "$current" == "$rsrc"/* ]] || continue
    fi
    # The record applies to this id but names a destination the registry cannot
    # represent. Reporting the pre-rename name as though the record said nothing
    # is the confidently-wrong answer; the walk stays put and discloses instead.
    if [[ "$rdok" != y ]]; then
      disclose_dst=$((i + 1))
      continue
    fi
    if [[ "$rk" == spec ]]; then
      current="$rdst"
    else
      current="$rdst/${current#*/}"
    fi
  done
  (( known )) || { echo "error: spec id '$queried' not allocated" >&2; return 1; }
  printf '%s\n' "$current"
  (( disclose_src )) && \
    echo "note: $queried derives from an unallocated rename source (record $disclose_src)" >&2
  (( disclose_dst )) && \
    echo "note: $queried stops at a rename whose destination the registry cannot represent (record $disclose_dst)" >&2
  return 0
}

# alloc_valid_ord <tok> — exit 0 iff <tok> is an ordinal this allocator can
# compute with: all digits, no wider than the width the registry can be rebuilt
# from. The issue side's counterpart to alloc_valid_specid's numeric half, so
# the resolver, the fold, and the classifier all admit the same set.
alloc_valid_ord() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
  (( ${#1} <= ALLOC_MAX_ORD_DIGITS ))
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
  local n=${#lines[@]} i c1 c2 c3 c4
  local target=""
  local -A rn=()
  local rsrc rsok rdst rdok
  (( n )) && alloc_rename_index issue < <(printf '%s\n' "${lines[@]}")
  # Both claim shapes are contradictions the same way the spec resolver's is: a
  # durable id claimed twice, and an ordinal claimed twice. Each is remembered
  # with its claimants' positions and refused rather than answered from the last
  # record. The ordinal comparison is the one this function already replays with,
  # so detection and resolution always agree on what "the same ordinal" means.
  #
  # An issue ordinal is a NUMBER written without padding, so every comparison
  # here is numeric — the reading the fold and the integrity classifier already
  # use. Comparing as strings let a registry spelling an ordinal `007` and a file
  # spelling it `7` be one identity to the sweep and two to this function, so a
  # clean report could sit over a citation that resolves as never allocated.
  local dup_a=-1 dup_b=-1
  if alloc_valid_ord "$queried"; then
    target=$((10#$queried))
  else
    alloc_valid_token "$queried" || { echo "error: invalid issue id '$queried'" >&2; return 1; }
    for ((i=0; i<n; i++)); do
      read -r c1 c2 c3 c4 _ <<< "${lines[i]}"
      [[ "$c1" == issue && "$c2" == allocate ]] || continue
      alloc_valid_ord "$c3" || continue
      alloc_valid_token "$c4" || continue
      if [[ "$c4" == "$queried" ]]; then
        if (( dup_a < 0 )); then dup_a=$i; elif (( dup_b < 0 )); then dup_b=$i; fi
        target=$((10#$c3))
      fi
    done
    if (( dup_b >= 0 )); then
      echo "error: duplicate durable issue id '$queried' in the registry — claimed by records $((dup_a + 1)) and $((dup_b + 1)); refusing to answer" >&2
      return 1
    fi
    [[ -n "$target" ]] || { echo "error: issue id '$queried' not allocated" >&2; return 1; }
  fi
  local anchor=-1 known=0
  dup_a=-1; dup_b=-1
  local -a src_at=()
  for ((i=0; i<n; i++)); do
    if [[ -n "${rn[$((i + 1))]:-}" ]]; then
      IFS=$'\t' read -r _ rsrc rsok rdst rdok _ _ <<< "${rn[$((i + 1))]}"
      [[ "$rdok" == y ]] && (( rdst == target )) && { anchor=$i; known=1; }
      # A rename vacates the ordinal — but only when there is a single holder to
      # move. Two live claims cannot be told apart by a rename that moves one of
      # them, so the contradiction stands rather than being cleared.
      if [[ "$rsok" == y ]] && (( rsrc == target )); then
        src_at+=( "$((i + 1))" )
        (( dup_b < 0 )) && { dup_a=-1; dup_b=-1; }
      fi
      continue
    fi
    read -r c1 c2 c3 _ <<< "${lines[i]}"
    if [[ "$c1" == issue && "$c2" == allocate ]]; then
      alloc_valid_ord "$c3" || continue
      if (( 10#$c3 == target )); then
        if (( dup_a < 0 )); then dup_a=$i; elif (( dup_b < 0 )); then dup_b=$i; fi
        anchor=$i; known=1
      fi
    fi
  done
  if (( dup_b >= 0 )); then
    echo "error: duplicate issue ordinal '$target' in the registry — claimed by records $((dup_a + 1)) and $((dup_b + 1)); refusing to answer" >&2
    return 1
  fi
  local disclose_src=0 disclose_dst=0
  if (( ! known )) && (( ${#src_at[@]} )); then
    if (( ${#src_at[@]} > 1 )); then
      echo "error: issue ordinal '$target' is vacated by more than one rename record and allocated by none — records ${src_at[0]} and ${src_at[1]}; refusing to answer" >&2
      return 1
    fi
    known=1; disclose_src="${src_at[0]}"
  fi
  local current="$target"
  for ((i=0; i<n; i++)); do
    (( anchor >= 0 && i <= anchor )) && continue
    [[ -n "${rn[$((i + 1))]:-}" ]] || continue
    IFS=$'\t' read -r _ rsrc rsok rdst rdok _ _ <<< "${rn[$((i + 1))]}"
    [[ "$rsok" == y ]] || continue
    (( rsrc == current )) || continue
    if [[ "$rdok" != y ]]; then
      disclose_dst=$((i + 1))
      continue
    fi
    current="$rdst"
  done
  (( known )) || { echo "error: issue '$queried' not allocated" >&2; return 1; }
  printf '%s\n' "$current"
  (( disclose_src )) && \
    echo "note: $target derives from an unallocated rename source (record $disclose_src)" >&2
  (( disclose_dst )) && \
    echo "note: $target stops at a rename whose destination the registry cannot represent (record $disclose_dst)" >&2
  return 0
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
  local -a src=() dst=()
  local m=0 rsrc rsok rdst rdok
  while IFS=$'\t' read -r _ rsrc rsok rdst rdok _ _ _; do
    [[ "$rsok" == y && "$rdok" == y ]] || continue
    src[m]="$rsrc"; dst[m]="$rdst"; m=$((m + 1))
  done < <(alloc_rename_scan group)
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
  local n=${#lines[@]} i c1 c2 c3 max=0 g num cand
  local -A alias=()
  local k v rk rsrc rsok rdst rdok
  if (( n )); then
    while IFS=$'\t' read -r k v; do
      [[ -n "$k" ]] && alias["$k"]="$v"
    done < <(printf '%s\n' "${lines[@]}" | alloc_group_alias_map)
  fi
  local -a cands=()
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 _ <<< "${lines[i]}"
    [[ "$c1" == spec && "$c2" == allocate ]] && cands+=("$c3")
  done
  # Each side of a rename is judged on its own, so a source this system cannot
  # represent does not take its destination's claim down with it.
  if (( n )); then
    while IFS=$'\t' read -r rk rsrc rsok rdst rdok _ _ _; do
      [[ "$rk" == spec ]] || continue
      [[ "$rsok" == y ]] && cands+=("$rsrc")
      [[ "$rdok" == y ]] && cands+=("$rdst")
    done < <(printf '%s\n' "${lines[@]}" | alloc_rename_scan spec)
  fi
  for cand in ${cands[@]+"${cands[@]}"}; do
    cand="$(alloc_canon_specid "$cand")" || continue
    num="${cand##*/}"
    g="${cand%/*}"
    g="${alias[$g]:-$g}"
    [[ "$g" == "$group" ]] || continue
    num=$((10#$num))            # base-10 — never octal on leading zeros
    (( num > max )) && max=$num
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
  local n=${#lines[@]} i c1 c2 c3 max=0 cand
  local rsrc rsok rdst rdok
  local -a cands=()
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 _ <<< "${lines[i]}"
    [[ "$c1" == issue && "$c2" == allocate ]] && cands+=("$c3")
  done
  if (( n )); then
    while IFS=$'\t' read -r _ rsrc rsok rdst rdok _ _ _; do
      [[ "$rsok" == y ]] && cands+=("$rsrc")
      [[ "$rdok" == y ]] && cands+=("$rdst")
    done < <(printf '%s\n' "${lines[@]}" | alloc_rename_scan issue)
  fi
  for cand in ${cands[@]+"${cands[@]}"}; do
    alloc_valid_ord "$cand" || continue
    cand=$((10#$cand))
    (( cand > max )) && max=$cand
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
#   which realizations need a new record). A pending id whose durable id the
#   registry claims twice is refused alone: its row is "<full-id>\t-\tblocked"
#   (no ordinal — the consumer leaves it provisional) with the claimants named
#   on stderr, while the rest of the batch still realizes. Pure — reads the
#   log, touches no git. Halts (rc 1) on a within-batch duplicate identity
#   (defense-in-depth against a buggy or hostile consumer surfacing one identity
#   twice) or a pending id that fails the id boundary. Cross-batch uniqueness
#   stays the consumer's obligation.
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
  local -A claim_at=()   # durable full-id -> the record position that claimed it
  local -A dup_at=()     # durable full-id -> "<first> and <second>" when claimed twice
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 c4 _ <<< "${lines[i]}"
    [[ "$c1" == issue && "$c2" == allocate ]] || continue
    [[ "$c3" =~ ^[0-9]+$ ]] || continue
    alloc_valid_token "$c4" || continue
    if [[ -z "${claim_at[$c4]:-}" ]]; then
      claim_at["$c4"]=$((i + 1))
    elif [[ -z "${dup_at[$c4]:-}" ]]; then
      dup_at["$c4"]="${claim_at[$c4]} and $((i + 1))"
    fi
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
  # Pass 2: emit the mapping in pending (allocation) order. A registry that
  # claims one durable id twice cannot say which ordinal that marker already
  # holds, and answering from the later record is how a marker gets realized
  # onto the wrong one — so the refusal is per-identity: a blocked row with no
  # ordinal, claimants on stderr, and the rest of the batch still lands. The
  # contradiction is that identity's, not the batch's; the sweep reports it as
  # duplicate-id drift, and repairing it is the operator's move.
  local ord next=$((max + 1))
  for pend in "$@"; do
    if [[ -n "${dup_at[$pend]:-}" ]]; then
      echo "error: duplicate durable issue id '$pend' in the registry — claimed by records ${dup_at[$pend]}; refusing to realize this identity" >&2
      printf '%s\t-\tblocked\n' "$pend"
    elif [[ -n "${existing[$pend]:-}" ]]; then
      printf '%s\t%s\thave\n' "$pend" "${existing[$pend]}"
    else
      ord=$next; next=$((next + 1))
      printf '%s\t%s\tnew\n' "$pend" "$ord"
    fi
  done
}

# alloc_spec_claim_keys   (specs log on stdin)
#   Emit one row per allocate record that establishes a spec realize claim:
#   "<group>/<slug>/<date>\t<canonical-id>\t<record-position>", the group
#   resolved through the alias map and every field revalidated at its own
#   boundary — one malformed field cannot smuggle in another, and a record the
#   fold counts is still not an identity to match against unless all three key
#   fields are well-formed. THE one rule for what claims a realize key: the
#   realize path folds these rows into its find-or-allocate map and the sweep
#   counts them to name ambiguous keys, so the two readers cannot disagree
#   about what blocks a realization.
alloc_spec_claim_keys() {
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 c5 g num canon k v
  local -A alias=()
  if (( n )); then
    while IFS=$'\t' read -r k v; do
      [[ -n "$k" ]] && alias["$k"]="$v"
    done < <(printf '%s\n' "${lines[@]}" | alloc_group_alias_map)
  fi
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
    printf '%s/%s/%s\t%s\t%d\n' "$g" "$c4" "$c5" "$canon" "$((i + 1))"
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
#   A pending identity whose (group, slug, date) triple the registry claims
#   twice is refused alone: its row is "<pending-id>\t-\tblocked" (no ordinal —
#   the consumer applies nothing for it) with the claimants named on stderr,
#   while the rest of the batch still realizes. Pure — reads the log, touches
#   no git. Halts (rc 1) before emitting anything on a pending id that fails
#   the reserved-form boundary, on a within-batch duplicate, or on a group
#   whose next ordinal would be wider than the registry could be rebuilt from.
#   Cross-batch uniqueness stays the consumer's obligation.
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
  # Already-realized map, keyed (current group, slug, date), folded from the
  # shared claim-key reader so this path and the sweep's ambiguity report
  # cannot disagree about what claims a key.
  local -A existing=()
  local -A claim_at=()   # key -> the record position that claimed it
  local -A dup_at=()     # key -> "<first> and <second>" when the key is claimed twice
  local g num ckey canon cpos
  if (( n )); then
    while IFS=$'\t' read -r ckey canon cpos; do
      [[ -n "$ckey" ]] || continue
      if [[ -z "${claim_at[$ckey]:-}" ]]; then
        claim_at["$ckey"]="$cpos"
      elif [[ -z "${dup_at[$ckey]:-}" ]]; then
        dup_at["$ckey"]="${claim_at[$ckey]} and $cpos"
      fi
      existing["$ckey"]="$canon"
    done < <(printf '%s\n' "${lines[@]}" | alloc_spec_claim_keys)
  fi
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
    body="${tok#"$PROV_PREFIX"}"
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
    # Two records claiming this triple leave the readback ambiguous — reporting
    # `have` from the later one is how a resumed realization adopts the wrong
    # ordinal. Two specs sharing a title-slug in one group on one day is a state
    # the allocator itself can mint, so the refusal is per-identity: a blocked
    # row with no ordinal, claimants on stderr, and the rest of the batch still
    # lands — one ambiguous key must not strand neighbours whose ordinals are
    # safe.
    if [[ -n "${dup_at[$k]:-}" ]]; then
      echo "error: duplicate spec claim '$k' in the registry — claimed by records ${dup_at[$k]}; refusing to realize '${p_id[i]}'" >&2
      rows+=( "$(printf '%s\t-\tblocked' "${p_id[i]}")" )
      continue
    fi
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

# alloc_emit_conflicts <accumulated> — write the derivation's conflict block to
# stderr, one sanitized line at a time. These lines name artifacts BECAUSE they
# failed a boundary, so they are the one report channel carrying tokens that are
# known-invalid by construction — and both integrity verbs route this block into
# the report an operator reads. Sanitizing at emission covers every conflict the
# derivation can raise, including ones added later.
alloc_emit_conflicts() {
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    printf '%s\n' "$(alloc_sanitize_field "$line")" >&2
  done <<< "${1%$'\n'}"
}

# alloc_is_reserved_ord <ord> — exit 0 iff <ord> is the reserved blueprint slot:
# a zero-VALUED ordinal, not one spelling of it, so `0`, `00` and `000` are one
# rule. Deriving a record for any of them would mint the `<group>/000` identity
# the registry treats as drift, and the sweep counts the same dirs as
# non-coverage — one predicate, so the two can never disagree about which dirs
# are reserved. The digits guard must precede the arithmetic: `10#` on a
# non-numeric token is a fatal arithmetic error.
alloc_is_reserved_ord() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
  (( 10#$1 == 0 ))
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
      alloc_is_reserved_ord "$ord" && continue
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
    printf 'error: cannot seed — spec artifacts have conflicts:\n' >&2
    alloc_emit_conflicts "$conflicts"
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
    # A pending provisional issue holds a reserved ordinal that never entered the
    # registry — the file's twin of a pending provisional spec dir, and passed
    # over for the same reason. Without this, deriving over a tree that has one
    # halts, which is exactly the offline state that produces them.
    alloc_is_prov_form "$num" && continue
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
    printf 'error: cannot seed — issue artifacts have conflicts:\n' >&2
    alloc_emit_conflicts "$conflicts"
    return 1
  fi
  (( ${#rows[@]} )) || return 0
  local rnum rid rdate
  while IFS=$'\t' read -r rnum rid rdate; do
    out+="issue allocate $rnum $rid $rdate $marker"$'\n'
  done < <(printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t$'\t' -k1,1n)
  printf '%s' "$out"
}

# ─── Section: integrity classification (pure — tree-derived vs registry) ─────
#
# ONE comparison, three consumers: the sweep report, the catch-up preview, and
# the catch-up builder all read these rows and nothing else, so what the sweep
# calls missing and what the catch-up appends cannot drift apart. Both sides are
# canonicalized before any comparison, and every field is revalidated at the id
# boundary — the registry is push-writable, so a record whose fields do not pass
# is degraded and skipped rather than classified or echoed.
#
# Row grammar (TAB-separated), one per finding:
#   MISSING       <kind> <identity> <detail>   tree identity with no record
#   MISMATCH      <kind> <identity> <detail>   both sides present, disagreeing
#   DUP-ORD       <kind> <identity> <detail>   one ordinal claimed twice, live
#   DUP-ID        issue  <full-id>  <detail>   one durable id claimed twice
#   RESERVED      spec   <identity> <detail>   a record for the reserved slot
#   INFO-NO-TREE  <kind> <identity> <detail>   record with no tree counterpart
#   RENAME-SRC    <kind> <identity> <detail>   id known only as a rename source
#   CHECKED       <kind> <tree-n>   <record-n> coverage denominators
#
# A record with no tree counterpart is INFORMATIONAL, not drift: another clone
# allocating first and an ordinal burned by an abandoned binding are both
# legitimate, and calling them drift would leave every multi-clone project
# permanently dirty.
#
# Group records are not classified. A group whose `group allocate` record is
# absent while its spec records are present raises no finding, matching the
# catch-up rule that appends a group record only alongside a spec record for it.

# alloc_classify_emit <class> <kind> <identity> <detail> — one finding row.
alloc_classify_emit() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
}

# alloc_spec_replay   (specs log on stdin)
#   THE spec-claim replay: what the registry claims right now, and every
#   contradiction met on the way there. An allocate record claims an identity, a
#   rename record moves that claim to its destination, and a group rename moves
#   every claim under that group; a rename onto its own name says nothing and is
#   skipped as the no-op it reads as.
#
#   Rows, TAB-separated:
#     DUP  <id> <pos-a> <pos-b>   two live claims on one identity
#     SLUG <id> <pos>             a claim whose slug field is unusable
#     LIVE <id> <pos> <slug>      claimed now, and the record that made the claim
#     SRC  <id>                   an identity some rename moved away from
#     BAD  <n>                    records naming no identity at all
#   DUP and SLUG appear in encounter order; LIVE and SRC are sorted, after.
#
#   ONE replay, because the integrity report and the emission refusals must not
#   be able to disagree about what "already claimed" means — the report would
#   name a duplicate the emitter had just written, or the emitter would refuse a
#   destination the report calls free. A claim moved by a rename carries the
#   MOVING record's position: citing the allocate position forward would name a
#   record about a different identity by the time anything collides with this one.
alloc_spec_replay() {
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4 canon key dst bad=0
  local -A live_at=() live_slug=() src_only=()
  local -A rn=()
  local rk rsrc rsok rdst rdok
  if (( n )); then
    alloc_rename_index spec < <(printf '%s\n' "${lines[@]}")
    # A record that cannot even name an identity is counted, never silently
    # dropped: a registry full of unreadable records must not report like a
    # clean one.
    bad=$(( bad + $(printf '%s\n' "${lines[@]}" | alloc_malformed_count spec rename alloc_rename_scan) ))
    bad=$(( bad + $(printf '%s\n' "${lines[@]}" | alloc_malformed_count spec realize alloc_realize_scan) ))
  fi
  for ((i=0; i<n; i++)); do
    if [[ -n "${rn[$((i + 1))]:-}" ]]; then
      IFS=$'\t' read -r rk rsrc rsok rdst rdok _ _ <<< "${rn[$((i + 1))]}"
      [[ "$rsok" == y && "$rdok" == y && "$rsrc" != "$rdst" ]] || continue
      if [[ "$rk" == spec ]]; then
        src_only["$rsrc"]=1
        [[ -n "${live_at[$rsrc]:-}" ]] || continue
        if [[ -n "${live_at[$rdst]:-}" ]]; then
          printf 'DUP\t%s\t%s\t%s\n' "$rdst" "${live_at[$rdst]}" "$((i + 1))"
        else
          live_at["$rdst"]=$((i + 1)); live_slug["$rdst"]="${live_slug[$rsrc]}"
        fi
        unset 'live_at[$rsrc]' 'live_slug[$rsrc]'
      else
        for key in "${!live_at[@]}"; do
          [[ "$key" == "$rsrc"/* ]] || continue
          src_only["$key"]=1
          dst="$rdst/${key##*/}"
          if [[ -n "${live_at[$dst]:-}" ]]; then
            printf 'DUP\t%s\t%s\t%s\n' "$dst" "${live_at[$dst]}" "$((i + 1))"
          else
            live_at["$dst"]=$((i + 1)); live_slug["$dst"]="${live_slug[$key]}"
          fi
          unset 'live_at[$key]' 'live_slug[$key]'
        done
      fi
      continue
    fi
    read -r c1 c2 c3 c4 _ <<< "${lines[i]}"
    [[ "$c1" == spec && "$c2" == allocate ]] || continue
    canon="$(alloc_canon_specid "$c3")" || { bad=$((bad + 1)); continue; }
    if [[ -n "${live_at[$canon]:-}" ]]; then
      printf 'DUP\t%s\t%s\t%s\n' "$canon" "${live_at[$canon]}" "$((i + 1))"
      continue
    fi
    alloc_valid_token "$c4" || printf 'SLUG\t%s\t%s\n' "$canon" "$((i + 1))"
    live_at["$canon"]=$((i + 1)); live_slug["$canon"]="$c4"
  done
  local id
  for id in $(printf '%s\n' "${!live_at[@]}" | LC_ALL=C sort); do
    [[ -n "$id" ]] && printf 'LIVE\t%s\t%s\t%s\n' "$id" "${live_at[$id]}" "${live_slug[$id]}"
  done
  for id in $(printf '%s\n' "${!src_only[@]}" | LC_ALL=C sort); do
    [[ -n "$id" ]] && printf 'SRC\t%s\n' "$id"
  done
  printf 'BAD\t%d\n' "$bad"
}

# alloc_classify_spec <derived-records-file>   (specs log on stdin)
#   Compare the spec identities derived from the working tree against the
#   registry's live claims and print one row per finding, plus the CHECKED
#   denominators for specs and groups.
#
#   Live claims are computed by replaying the log the way the resolver does:
#   an allocate record claims an identity, a rename record moves that claim to
#   its destination, and a group rename moves every claim under that group. So a
#   vacated id is not a phantom record-without-tree, and an id known only as a
#   rename source is named as non-coverage rather than as drift.
alloc_classify_spec() {
  local derived="$1"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3
  local -A live_at=() live_slug=() src_only=() reg_groups=() unreadable=()
  local g unreadable_n=0 tag ra rb rc
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 _ <<< "${lines[i]}"
    [[ "$c1" == group && "$c2" == allocate ]] || continue
    alloc_valid_token "$c3" || continue
    reg_groups["$c3"]=1
  done
  while IFS=$'\t' read -r tag ra rb rc; do
    case "$tag" in
      LIVE) live_at["$ra"]="$rb"; live_slug["$ra"]="$rc" ;;
      DUP)  alloc_classify_emit DUP-ORD spec "$ra" "records $rb and $rc" ;;
      # An unusable sibling field does not vacate the claim. The identity IS
      # taken — the resolvers count it — so calling it missing is what let the
      # repair path append a second record and turn a degraded record into a
      # refused citation. It is claimed, and reported under its own class.
      SLUG) unreadable["$ra"]=1
            alloc_classify_emit UNREADABLE spec "$ra" "record $rb has an unusable slug" ;;
      SRC)  src_only["$ra"]=1 ;;
      BAD)  unreadable_n="$ra" ;;
    esac
  done < <(printf '%s\n' ${lines[@]+"${lines[@]}"} | alloc_spec_replay)
  # Tree side: the seed derivation's own output, so the sweep and the bootstrap
  # enumerate one artifact set (reserved slots and pending provisionals are
  # already excluded there — the sweep counts those separately as non-coverage).
  local -A tree_slug=() tree_groups=()
  if [[ -n "$derived" && -r "$derived" ]]; then
    while read -r c1 c2 c3 c4 _; do
      if [[ "$c1" == spec && "$c2" == allocate ]]; then
        canon="$(alloc_canon_specid "$c3")" || continue
        alloc_valid_token "$c4" || continue
        tree_slug["$canon"]="$c4"
      elif [[ "$c1" == group && "$c2" == allocate ]]; then
        alloc_valid_token "$c3" || continue
        tree_groups["$c3"]=1
      fi
    done < "$derived"
  fi
  local id
  for id in $(printf '%s\n' "${!tree_slug[@]}" | LC_ALL=C sort); do
    # An identity whose record is unreadable is already reported under that
    # class; comparing an unusable slug against the tree's would only add noise.
    [[ -n "${unreadable[$id]:-}" ]] && continue
    if [[ -z "${live_at[$id]:-}" ]]; then
      alloc_classify_emit MISSING spec "$id" "${tree_slug[$id]}"
    elif [[ "${live_slug[$id]}" != "${tree_slug[$id]}" ]]; then
      alloc_classify_emit MISMATCH spec "$id" "tree ${tree_slug[$id]}, registry ${live_slug[$id]}"
    fi
  done
  for id in $(printf '%s\n' "${!live_at[@]}" | LC_ALL=C sort); do
    [[ -n "${unreadable[$id]:-}" ]] && continue
    if alloc_is_reserved_ord "${id##*/}"; then
      alloc_classify_emit RESERVED spec "$id" "record ${live_at[$id]}"
    elif [[ -z "${tree_slug[$id]:-}" ]]; then
      alloc_classify_emit INFO-NO-TREE spec "$id" "${live_slug[$id]}"
    fi
  done
  for id in $(printf '%s\n' "${!src_only[@]}" | LC_ALL=C sort); do
    [[ -n "${live_at[$id]:-}" ]] && continue
    alloc_classify_emit RENAME-SRC spec "$id" "vacated by a rename"
  done
  alloc_classify_emit CHECKED spec "${#tree_slug[@]}" "${#live_at[@]}"
  alloc_classify_emit CHECKED group "${#tree_groups[@]}" "${#reg_groups[@]}"
  alloc_classify_emit CHECKED unreadable spec "$unreadable_n"
  return 0
}

# alloc_classify_issue <derived-records-file>   (issues log on stdin)
#   The issue-side twin. Issues carry two unique dimensions — the display ordinal
#   and the durable id — so a contradiction can appear on either, and a tree file
#   whose ordinal and durable id land on different records is a mismatch rather
#   than two separate findings. Issue renames move ordinals, never durable ids.
alloc_classify_issue() {
  local derived="$1"
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]} i c1 c2 c3 c4
  local -A live_at=() live_id=() id_at=() id_ord=() src_only=() unreadable=()
  local ord unreadable_n=0
  local -A rn=()
  local rsrc rsok rdst rdok
  if (( n )); then
    alloc_rename_index issue < <(printf '%s\n' "${lines[@]}")
    unreadable_n=$(( unreadable_n + $(printf '%s\n' "${lines[@]}" | alloc_malformed_count issue rename alloc_rename_scan) ))
  fi
  for ((i=0; i<n; i++)); do
    if [[ -n "${rn[$((i + 1))]:-}" ]]; then
      IFS=$'\t' read -r _ rsrc rsok rdst rdok _ _ <<< "${rn[$((i + 1))]}"
      [[ "$rsok" == y && "$rdok" == y ]] || continue
      (( rsrc == rdst )) && continue     # inert: a rename onto its own ordinal
      src_only["$rsrc"]=1
      [[ -n "${live_at[$rsrc]:-}" ]] || continue
      if [[ -n "${live_at[$rdst]:-}" ]]; then
        alloc_classify_emit DUP-ORD issue "$rdst" "records ${live_at[$rdst]} and $((i + 1))"
      else
        live_at["$rdst"]=$((i + 1)); live_id["$rdst"]="${live_id[$rsrc]}"
        id_ord["${live_id[$rsrc]}"]="$rdst"
      fi
      unset 'live_at[$rsrc]' 'live_id[$rsrc]'
      continue
    fi
    read -r c1 c2 c3 c4 _ <<< "${lines[i]}"
    if [[ "$c1" == issue && "$c2" == allocate ]]; then
      { [[ "$c3" =~ ^[0-9]+$ ]] && (( ${#c3} <= ALLOC_MAX_ORD_DIGITS )); } \
        || { unreadable_n=$((unreadable_n + 1)); continue; }
      ord=$((10#$c3))
      # The ordinal is claimed even when the durable id beside it is unusable —
      # same rule as the spec side, and the reason the repair path cannot append
      # a second record over it.
      if ! alloc_valid_token "$c4"; then
        unreadable["$ord"]=1
        [[ -n "${live_at[$ord]:-}" ]] || live_at["$ord"]=$((i + 1))
        [[ -n "${live_id[$ord]:-}" ]] || live_id["$ord"]="$c4"
        alloc_classify_emit UNREADABLE issue "$ord" "record $((i + 1)) has an unusable durable id"
        continue
      fi
      if [[ -n "${id_at[$c4]:-}" ]]; then
        alloc_classify_emit DUP-ID issue "$c4" "records ${id_at[$c4]} and $((i + 1))"
      else
        id_at["$c4"]=$((i + 1)); id_ord["$c4"]="$ord"
      fi
      if [[ -n "${live_at[$ord]:-}" ]]; then
        alloc_classify_emit DUP-ORD issue "$ord" "records ${live_at[$ord]} and $((i + 1))"
        continue
      fi
      live_at["$ord"]=$((i + 1)); live_id["$ord"]="$c4"
    fi
  done
  local -A tree_id=()
  if [[ -n "$derived" && -r "$derived" ]]; then
    while read -r c1 c2 c3 c4 _; do
      [[ "$c1" == issue && "$c2" == allocate ]] || continue
      [[ "$c3" =~ ^[0-9]+$ ]] || continue
      alloc_valid_token "$c4" || continue
      tree_id["$((10#$c3))"]="$c4"
    done < "$derived"
  fi
  for ord in $(printf '%s\n' "${!tree_id[@]}" | LC_ALL=C sort -n); do
    [[ -n "${unreadable[$ord]:-}" ]] && continue
    if [[ -n "${live_at[$ord]:-}" ]]; then
      [[ "${live_id[$ord]}" == "${tree_id[$ord]}" ]] && continue
      alloc_classify_emit MISMATCH issue "$ord" \
        "tree ${tree_id[$ord]}, registry ${live_id[$ord]}"
    elif [[ -n "${id_ord[${tree_id[$ord]}]:-}" ]]; then
      alloc_classify_emit MISMATCH issue "${tree_id[$ord]}" \
        "tree ordinal $ord, registry ordinal ${id_ord[${tree_id[$ord]}]}"
    else
      alloc_classify_emit MISSING issue "$ord" "${tree_id[$ord]}"
    fi
  done
  for ord in $(printf '%s\n' "${!live_at[@]}" | LC_ALL=C sort -n); do
    [[ -n "${tree_id[$ord]:-}" || -n "${unreadable[$ord]:-}" ]] && continue
    alloc_classify_emit INFO-NO-TREE issue "$ord" "${live_id[$ord]}"
  done
  for ord in $(printf '%s\n' "${!src_only[@]}" | LC_ALL=C sort -n); do
    [[ -n "${live_at[$ord]:-}" ]] && continue
    alloc_classify_emit RENAME-SRC issue "$ord" "vacated by a rename"
  done
  alloc_classify_emit CHECKED issue "${#tree_id[@]}" "${#live_at[@]}"
  alloc_classify_emit CHECKED unreadable issue "$unreadable_n"
  return 0
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
  printf '%s%s' "$PROV_PREFIX" "$1"
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
  alloc_seed_report_skipped
  return 0
}

# alloc_seed_report_skipped — name the identities the derivation passed over, so
# an operator approving a bootstrap knows what it will NOT record. Reserved
# slots and pending provisionals are deliberately recordless, but "deliberately"
# is only true if it is said out loud; a silent omission reads as complete
# coverage.
alloc_seed_report_skipped() {
  local specs_root issues_dir reserved pending
  specs_root="$(alloc_seed_tree_root specs docs/specs)"   || return 0
  issues_dir="$(alloc_seed_tree_root issues docs/issues)" || return 0
  reserved="$(alloc_sweep_reserved_count "$specs_root")"
  pending="$(alloc_sweep_pending_count "$specs_root" "$issues_dir")"
  (( reserved == 0 && pending == 0 )) && return 0
  printf '  not recorded: %d reserved blueprint slot(s), %d pending provisional identity(ies)\n' \
    "$reserved" "$pending"
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
  alloc_seed_report_skipped
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

# ─── Section: sweep (read-only integrity report) ─────────────────────────────
#
# A read-only comparison of the working tree against the registry, reporting
# every finding under a named class and — as loudly — everything it did NOT
# cover. It mutates nothing: the coordination ref is refreshed the way `peek`
# refreshes it (best-effort, never binding), and no other state is touched.
#
# Exit codes are the contract's load-bearing half, because the report has two
# consumers that read it differently. A CI consumer reads all four; the verify
# rung maps exit 0 → holds and any clean non-zero → violated:
#   0  clean            — checked, and tree and registry agree
#   3  drift found      — maps to `violated`, which is exactly right
#   4  could-not-check  — also maps to `violated`, which is wrong but LOUD; the
#                         report names the degradation, and a check that cannot
#                         run must never read as a pass
#   1/2 hard failure / usage, the house convention

# The per-class listing cap. A partition accident or a hostile push can produce
# thousands of findings, and an unbounded listing floods CI logs and the verify
# evidence channel. The full count is always printed, so a cap is never a silent
# drop.
ALLOC_SWEEP_CAP=100

# alloc_sanitize_field <raw> — one report-safe field: tabs/newlines/CRs become
# spaces so a crafted value cannot forge a row or shift a column, length capped.
# Applied on emission to every field, including those that already crossed the id
# boundary — the boundary decides what is CLASSIFIED, this decides what is
# PRINTED, and the report must be safe even where a future field is not an id.
alloc_sanitize_field() {
  printf '%s' "${1:-}" \
    | tr '\t\n\r' '   ' \
    | tr -d '\000-\037\177' \
    | cut -c1-256
}

# alloc_display_field <raw> — a registry- or ledger-sourced token as it is safe
# to print: the sanitizer's output, marked when that output is not the whole
# value. A token silently shortened or stripped reads as a DIFFERENT token, and
# a reader comparing a report against a log would be chasing a value neither
# side holds — so the report says when what it shows was altered.
alloc_display_field() {
  local raw="${1:-}" safe
  safe="$(alloc_sanitize_field "$raw")"
  if [[ "$safe" != "$raw" ]]; then
    printf '%s … (sanitized for display)' "$safe"
  else
    printf '%s' "$safe"
  fi
}

# alloc_group_has_records <group>   (specs log on stdin) — exit 0 iff the
# registry holds any valid record for <group>: its group-allocate record, or a
# spec-allocate record under it. A group with neither is invisible to a
# tree-vs-registry comparison, which is what makes it non-coverage rather than
# clean.
alloc_group_has_records() {
  local group="$1" i c1 c2 c3 rk rsrc rsok
  local -a lines=(); mapfile -t lines
  local n=${#lines[@]}
  for ((i=0; i<n; i++)); do
    read -r c1 c2 c3 _ <<< "${lines[i]}"
    if [[ "$c1" == group && "$c2" == allocate ]]; then
      alloc_valid_token "$c3" || continue
      [[ "$c3" == "$group" ]] && return 0
    elif [[ "$c1" == spec && "$c2" == allocate ]]; then
      alloc_valid_specid "$c3" || continue
      [[ "${c3%/*}" == "$group" ]] && return 0
    fi
  done
  # A group the registry only ever recorded VACATING ordinals is still a group
  # the registry knows: the rename source is its coverage, which is what a
  # retired group's records amount to after every id has moved away.
  if (( n )); then
    while IFS=$'\t' read -r rk rsrc rsok _ _ _ _ _; do
      [[ "$rk" == spec && "$rsok" == y ]] || continue
      [[ "${rsrc%/*}" == "$group" ]] && return 0
    done < <(printf '%s\n' "${lines[@]}" | alloc_rename_scan spec)
  fi
  return 1
}

# alloc_sweep_reserved_count <specs_root> — how many reserved blueprint slots the
# comparison passed over, using the same predicate the derivation uses.
alloc_sweep_reserved_count() {
  local root="$1" g entry name n=0
  [[ -d "$root" ]] || { printf '0'; return 0; }
  for g in "$root"/*/; do
    [[ -d "$g" ]] || continue
    for entry in "$g"*/; do
      [[ -d "$entry" ]] || continue
      name="$(basename "$entry")"
      alloc_is_reserved_ord "${name%%-*}" && n=$((n + 1))
    done
  done
  printf '%d' "$n"
}

# alloc_sweep_pending_count <specs_root> <issues_dir> — how many pending
# provisional identities the comparison passed over: spec dirs in the reserved
# form, plus issue files whose display ordinal is one. Both are identities that
# never entered the registry, so their absence from it is not drift.
alloc_sweep_pending_count() {
  local root="$1" dir="$2" g entry name f num n=0
  if [[ -d "$root" ]]; then
    for g in "$root"/*/; do
      [[ -d "$g" ]] || continue
      for entry in "$g"*/; do
        [[ -d "$entry" ]] || continue
        name="$(basename "$entry")"
        alloc_is_prov_form "$name" && n=$((n + 1))
      done
    done
  fi
  if [[ -d "$dir" ]]; then
    # Narrow with one grep before reading anything: an issue collection runs to
    # hundreds of files and a per-file frontmatter read costs a fork each, while
    # pending provisionals are typically none. The grep only proposes candidates
    # — the reserved-form predicate still decides, so a crafted `num` cannot
    # inflate the count.
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      [[ "$(basename "$f")" == "INDEX.md" ]] && continue
      num="$(alloc_seed_field "$f" num)"
      alloc_is_prov_form "$num" && n=$((n + 1))
    done < <(grep -l -- "^num:[[:space:]]*['\"]\{0,1\}$PROV_PREFIX" "$dir"/*.md 2>/dev/null)
  fi
  printf '%d' "$n"
}

# alloc_sweep_uncovered_groups <specs_root> <spec-records>   (specs log on stdin)
#   Print the names of groups a tree-vs-registry comparison cannot see at all: a
#   specs-tree group directory that derives no rows (only a reserved slot, or
#   nothing) AND holds no registry record. That is the retired / partition-source
#   signature — nothing to derive, nothing to match — so without naming it here,
#   the one class of group that is entirely outside coordination would read as
#   clean.
alloc_sweep_uncovered_groups() {
  local root="$1" records="$2" log g name out=""
  log="$(cat)"
  [[ -d "$root" ]] || return 0
  for g in "$root"/*/; do
    [[ -d "$g" ]] || continue
    name="$(basename "$g")"
    alloc_valid_token "$name" || continue
    # Fixed-string matched: the boundary admits '.', which as a regex would let
    # a group named `a.b` match a record for `axb` and read as covered.
    printf '%s\n' "$records" | grep -qF "spec allocate $name/" && continue
    printf '%s\n' "$log" | alloc_group_has_records "$name" && continue
    out+="$name "
  done
  printf '%s' "${out% }"
}

# alloc_class_label <CLASS> — the operator-facing name for a classifier class.
# One vocabulary, so the sweep's report and the catch-up's unrepairable listing
# cannot call the same finding two different things.
alloc_class_label() {
  case "$1" in
    MISSING)      printf 'missing-record' ;;
    MISMATCH)     printf 'mismatch' ;;
    DUP-ORD)      printf 'duplicate-ordinal' ;;
    DUP-ID)       printf 'duplicate-id' ;;
    RESERVED)     printf 'reserved-slot' ;;
    UNREADABLE)   printf 'unreadable-record' ;;
    INFO-NO-TREE) printf 'record-without-tree' ;;
    *)            printf 'unclassified' ;;
  esac
}

# alloc_sweep_list <class> <rows> — print the findings of one class under the
# report's indent, capped, with the remainder named. Every field is sanitized on
# the way out.
alloc_sweep_list() {
  local class="$1" rows="$2" label line kind ident detail n=0 shown=0
  label="$(alloc_class_label "$class")"
  [[ -n "$rows" ]] || return 0
  n="$(printf '%s\n' "$rows" | grep -c .)"
  while IFS=$'\t' read -r _ kind ident detail; do
    [[ -n "$kind" ]] || continue
    (( shown >= ALLOC_SWEEP_CAP )) && break
    printf '    %s\t%s\t%s\t%s\n' "$label" \
      "$(alloc_sanitize_field "$kind")" \
      "$(alloc_sanitize_field "$ident")" \
      "$(alloc_sanitize_field "$detail")"
    shown=$((shown + 1))
  done <<< "$rows"
  (( n > shown )) && printf '    ... and %d more %s findings\n' "$((n - shown))" "$label"
  return 0
}

# cmd_sweep — the read-only integrity verb.
cmd_sweep() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      *) echo "error: unknown option '$1' for sweep (usage: sweep)" >&2; return 2 ;;
    esac
  done
  alloc_in_repo || return 1
  alloc_preflight || return 1
  local specs_root issues_dir branch remote tip freshness
  specs_root="$(alloc_seed_tree_root specs docs/specs)"   || return 1
  issues_dir="$(alloc_seed_tree_root issues docs/issues)" || return 1
  branch="$(alloc_coord_branch)" || return 1
  remote="$(alloc_coord_remote)"
  freshness="local"
  if [[ -n "$remote" ]]; then
    if git fetch --quiet "$remote" "$branch:refs/heads/$branch" 2>/dev/null; then
      freshness="refreshed"
    else
      freshness="last-seen; refresh failed"
    fi
  fi
  tip="$(git rev-parse --verify --quiet --end-of-options "refs/heads/$branch" 2>/dev/null || true)"
  if [[ -z "$tip" && -z "${JIMALLOC_REGISTRY_DIR:-}" ]]; then
    echo "error: cannot check — no coordination branch '$branch' here and none could be fetched" >&2
    return 4
  fi
  # A tree root that is not there is a tree this comparison never read. Deriving
  # zero identities from it would reclassify every record as informational and
  # exit clean — a check that did not look, reading as a pass.
  local root
  for root in "$specs_root" "$issues_dir"; do
    if [[ ! -d "$root" ]]; then
      echo "error: cannot check — '$(alloc_sanitize_field "$root")' is not a directory; nothing to compare the registry against" >&2
      return 4
    fi
  done
  # A tree the derivation refuses is a tree this comparison cannot read. That is
  # could-not-check, not clean and not drift: the offenders are already named on
  # stderr by the derivation itself.
  local spec_rec issue_rec
  spec_rec="$(alloc_seed_derive_specs "$specs_root")" || return 4
  issue_rec="$(alloc_seed_derive_issues "$issues_dir")" || return 4
  local spec_log issue_log
  spec_log="$(alloc_read_log spec)"; issue_log="$(alloc_read_log issue)"
  # Derived records reach the classifier through a process substitution, never a
  # temp file — the allocator's only filesystem write stays the erosion baseline.
  local spec_rows issue_rows
  spec_rows="$(printf '%s\n' "$spec_log" | alloc_classify_spec <(printf '%s\n' "$spec_rec"))"
  issue_rows="$(printf '%s\n' "$issue_log" | alloc_classify_issue <(printf '%s\n' "$issue_rec"))"
  local all_rows
  all_rows="$(printf '%s\n%s\n' "$spec_rows" "$issue_rows" | grep -v '^$' || true)"
  local spec_checked group_checked issue_checked
  spec_checked="$(printf '%s\n' "$spec_rows" | grep '^CHECKED	spec	' | head -n1)"
  group_checked="$(printf '%s\n' "$spec_rows" | grep '^CHECKED	group	' | head -n1)"
  issue_checked="$(printf '%s\n' "$issue_rows" | grep '^CHECKED	issue	' | head -n1)"
  local s_tree s_reg g_tree g_reg i_tree i_reg
  IFS=$'\t' read -r _ _ s_tree s_reg <<< "$spec_checked"
  IFS=$'\t' read -r _ _ g_tree g_reg <<< "$group_checked"
  IFS=$'\t' read -r _ _ i_tree i_reg <<< "$issue_checked"
  printf 'sweep: registry @ %s (%s)\n' \
    "$(alloc_sanitize_field "${tip:0:12}")" "$freshness"
  printf '  specs:  %d records vs %d tree dirs; %d group records vs %d tree groups\n' \
    "${s_reg:-0}" "${s_tree:-0}" "${g_reg:-0}" "${g_tree:-0}"
  printf '  issues: %d records vs %d files checked\n' "${i_reg:-0}" "${i_tree:-0}"
  local drift_rows info_rows
  drift_rows="$(printf '%s\n' "$all_rows" | grep -E '^(MISSING|MISMATCH|DUP-ORD|DUP-ID|RESERVED|UNREADABLE)	' || true)"
  info_rows="$(printf '%s\n' "$all_rows" | grep '^INFO-NO-TREE	' || true)"
  if [[ -n "$drift_rows" ]]; then
    printf '  drift:\n'
    alloc_sweep_list MISSING  "$(printf '%s\n' "$drift_rows" | grep '^MISSING	'  || true)"
    alloc_sweep_list MISMATCH "$(printf '%s\n' "$drift_rows" | grep '^MISMATCH	' || true)"
    alloc_sweep_list DUP-ORD  "$(printf '%s\n' "$drift_rows" | grep '^DUP-ORD	'  || true)"
    alloc_sweep_list DUP-ID   "$(printf '%s\n' "$drift_rows" | grep '^DUP-ID	'   || true)"
    alloc_sweep_list RESERVED "$(printf '%s\n' "$drift_rows" | grep '^RESERVED	' || true)"
    alloc_sweep_list UNREADABLE "$(printf '%s\n' "$drift_rows" | grep '^UNREADABLE	' || true)"
  fi
  if [[ -n "$info_rows" ]]; then
    printf '  info:\n'
    alloc_sweep_list INFO-NO-TREE "$info_rows"
  fi
  local reserved pending uncovered src_ids
  reserved="$(alloc_sweep_reserved_count "$specs_root")"
  pending="$(alloc_sweep_pending_count "$specs_root" "$issues_dir")"
  uncovered="$(printf '%s\n' "$spec_log" | alloc_sweep_uncovered_groups "$specs_root" "$spec_rec")"
  src_ids="$(printf '%s\n' "$all_rows" | grep -c '^RENAME-SRC	' || true)"
  printf '  not covered:\n'
  printf '    reserved-slots\t%d\n'       "$reserved"
  printf '    pending-provisionals\t%d\n' "$pending"
  if [[ -n "$uncovered" ]]; then
    local ug_n ug_shown
    ug_n="$(printf '%s\n' "$uncovered" | wc -w | tr -d ' ')"
    ug_shown="$(alloc_sanitize_field "$uncovered")"
    # The sanitizer caps length, so say when the list was cut rather than
    # letting a count and a shorter list silently disagree.
    if [[ "$ug_shown" != "$uncovered" ]]; then
      printf '    uncovered-groups\t%d\t%s … (list truncated)\n' "$ug_n" "$ug_shown"
    else
      printf '    uncovered-groups\t%d\t%s\n' "$ug_n" "$ug_shown"
    fi
  else
    printf '    uncovered-groups\t0\n'
  fi
  printf '    rename-source-ids\t%d\n' "$src_ids"
  # Records too malformed to name an identity are compared against nothing, so
  # they are non-coverage in the strictest sense: without this line a registry
  # full of them reports exactly like a clean one.
  local unreadable_n=0 cu
  while IFS=$'\t' read -r _ _ _ cu; do
    [[ "$cu" =~ ^[0-9]+$ ]] && unreadable_n=$((unreadable_n + cu))
  done < <(printf '%s\n' "$all_rows" | grep '^CHECKED	unreadable	' || true)
  printf '    unidentifiable-records\t%d\n' "$unreadable_n"
  # A verb this build does not know is not a broken record — it is how a later
  # record kind arrives. Counted on its own so the grammar can grow without
  # every older clone reporting the newer log as damaged.
  local unknown_n
  unknown_n=$(( $(printf '%s\n' "$spec_log"  | alloc_unknown_verb_count) +
                $(printf '%s\n' "$issue_log" | alloc_unknown_verb_count) ))
  printf '    unknown-verb-records\t%d\n' "$unknown_n"
  # Two records legitimately claiming one (group, slug, date) triple are not
  # drift — both are individually valid, and the allocator itself can mint the
  # pair — but the realize path refuses any pending identity keyed onto that
  # triple, so the ambiguity is named here before someone hits it. Counted by
  # the same claim-key reader the realize path folds, so the report and the
  # refusal cannot disagree.
  local dup_keys dk_n dk_shown
  dup_keys="$(printf '%s\n' "$spec_log" | alloc_spec_claim_keys | cut -f1 | sort | uniq -d | tr '\n' ' ')"
  dup_keys="${dup_keys% }"
  printf '  realize hazards:\n'
  if [[ -n "$dup_keys" ]]; then
    dk_n="$(printf '%s\n' "$dup_keys" | wc -w | tr -d ' ')"
    dk_shown="$(alloc_sanitize_field "$dup_keys")"
    # The sanitizer caps length, so say when the list was cut rather than
    # letting a count and a shorter list silently disagree.
    if [[ "$dk_shown" != "$dup_keys" ]]; then
      printf '    duplicate-realize-keys\t%d\t%s … (list truncated)\n' "$dk_n" "$dk_shown"
    else
      printf '    duplicate-realize-keys\t%d\t%s\n' "$dk_n" "$dk_shown"
    fi
  else
    printf '    duplicate-realize-keys\t0\n'
  fi
  [[ -n "$drift_rows" ]] && return 3
  return 0
}

# ─── Section: catch-up (incremental repair of a non-empty registry) ──────────
#
# The bootstrap refuses a log that already has records, which is why both live
# instances of tree-vs-registry drift were repaired by hand-editing the shared
# coordination branch. This verb is the sanctioned path: it appends exactly the
# records the sweep classifies as MISSING, under the same CAS and erosion
# discipline as an allocation, and repairs nothing else.
#
# Preview-then-apply, and the preview renders each record verbatim — an operator
# approving a count is approving nothing, since working-tree content in a team
# setting includes other people's merged contributions.

# The provenance marker for a catch-up append. The erosion guard's accepted
# residual is that a WELL-FORMED append is undetectable, and a catch-up append
# is exactly that shape — so the marker is the only forensic distinguisher
# between this verb, the bootstrap, and a live allocation.
ALLOC_CATCHUP_MARKER="jim-catchup"

# alloc_catchup_compute <spec-derived> <issue-derived> <spec-log> <issue-log>
#   The single decision behind both the preview and the apply: what would be
#   appended, and what cannot be repaired. Sets, through dynamic scope (the
#   alloc_publish builder convention — assign, never re-declare):
#     CU_SPEC     — the spec records to append, in derivation order
#     CU_ISSUE    — the issue records to append
#     CU_BLOCKED  — the classifier rows that name unrepairable drift
#   Both append sets are drawn from the classifier's MISSING class and nowhere
#   else, so what the sweep reports missing and what this appends are the same
#   set by construction rather than by agreement.
#
#   A group record rides along only when the group is absent from the log AND
#   this batch carries a spec record for it — the rule an allocation follows.
alloc_catchup_compute() {
  local spec_rec="$1" issue_rec="$2" spec_log="$3" issue_log="$4"
  local rows id line c1 c2 c3
  CU_SPEC=""; CU_ISSUE=""; CU_BLOCKED=""
  local -A want_spec=() want_issue=() want_group=()
  rows="$(printf '%s\n' "$spec_log" | alloc_classify_spec <(printf '%s\n' "$spec_rec"))"
  while IFS=$'\t' read -r c1 c2 c3 _; do
    [[ "$c1" == MISSING && "$c2" == spec ]] && want_spec["$c3"]=1
  done <<< "$rows"
  # Everything this verb cannot repair, not the mismatch class alone: a registry
  # that contradicts itself is a finding the operator must see, and an exit 0
  # after a sweep exited 3 reads as "done" when nothing was resolved.
  CU_BLOCKED="$(printf '%s\n' "$rows" | grep -E '^(MISMATCH|DUP-ORD|DUP-ID|RESERVED|UNREADABLE)	' || true)"
  rows="$(printf '%s\n' "$issue_log" | alloc_classify_issue <(printf '%s\n' "$issue_rec"))"
  while IFS=$'\t' read -r c1 c2 c3 _; do
    [[ "$c1" == MISSING && "$c2" == issue ]] && want_issue["$c3"]=1
  done <<< "$rows"
  local blocked_issue
  blocked_issue="$(printf '%s\n' "$rows" | grep -E '^(MISMATCH|DUP-ORD|DUP-ID|UNREADABLE)	' || true)"
  [[ -n "$blocked_issue" ]] && CU_BLOCKED="${CU_BLOCKED:+$CU_BLOCKED$'\n'}$blocked_issue"
  # Spec side: the derivation's own ordering within each kind, with the group
  # records this batch needs hoisted ahead of the spec records. Group records
  # are order-independent for both the fold and the resolver, so the hoist costs
  # nothing and keeps the two passes below simple.
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    read -r c1 c2 c3 _ <<< "$line"
    if [[ "$c1" == spec && "$c2" == allocate ]]; then
      id="$(alloc_canon_specid "$c3")" || continue
      [[ -n "${want_spec[$id]:-}" ]] || continue
      want_group["${id%/*}"]=1
      CU_SPEC="${CU_SPEC}$line"$'\n'
    fi
  done <<< "$spec_rec"
  local group_recs=""
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    read -r c1 c2 c3 _ <<< "$line"
    [[ "$c1" == group && "$c2" == allocate ]] || continue
    [[ -n "${want_group[$c3]:-}" ]] || continue
    printf '%s\n' "$spec_log" | alloc_group_present "$c3" && continue
    group_recs="${group_recs}$line"$'\n'
  done <<< "$spec_rec"
  [[ -n "$group_recs" ]] && CU_SPEC="${group_recs}${CU_SPEC}"
  CU_SPEC="${CU_SPEC%$'\n'}"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    read -r c1 c2 c3 _ <<< "$line"
    [[ "$c1" == issue && "$c2" == allocate ]] || continue
    [[ "$c3" =~ ^[0-9]+$ ]] || continue
    [[ -n "${want_issue[$((10#$c3))]:-}" ]] || continue
    CU_ISSUE="${CU_ISSUE}$line"$'\n'
  done <<< "$issue_rec"
  CU_ISSUE="${CU_ISSUE%$'\n'}"
  return 0
}

# alloc_catchup_render_blocked <rows> — the findings this verb cannot repair,
# rendered under the report's indent in the same vocabulary the sweep uses.
alloc_catchup_render_blocked() {
  local line class rest
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    class="${line%%$'\t'*}"; rest="${line#*$'\t'}"
    printf '    %s\t%s\n' "$(alloc_class_label "$class")" "$rest"
  done <<< "$1"
}

# alloc_catchup_render_set <label> <records> — the preview's per-log section:
# every record verbatim, never a count on its own.
alloc_catchup_render_set() {
  local label="$1" records="$2" n
  [[ -n "$records" ]] || return 0
  n="$(printf '%s\n' "$records" | grep -c .)"
  printf '  %s: would append %d record(s):\n' "$label" "$n"
  printf '%s\n' "$records" | sed 's/^/    /'
}

# alloc_catchup_publish_builder <cur_specs> <cur_issues> <who> <spec-derived> <issue-derived>
#   The catch-up publish decision (an alloc_publish builder). The append set is
#   recomputed against THIS attempt's logs, not against the preview's read, so a
#   record that landed in between is seen as present and never appended twice.
#   Sets the PUB_* locals alloc_publish reads back through dynamic scope, and
#   the CATCHUP_BLOCKED global the caller reads for its exit code.
alloc_catchup_publish_builder() {
  local cur_specs="$1" cur_issues="$2" _who="$3" spec_rec="$4" issue_rec="$5"
  local CU_SPEC CU_ISSUE CU_BLOCKED
  alloc_catchup_compute "$spec_rec" "$issue_rec" "$cur_specs" "$cur_issues" || return 1
  CATCHUP_BLOCKED="$CU_BLOCKED"
  PUB_SPEC=""; PUB_ISSUE=""
  local ns=0 ni=0 payload=""
  if [[ -n "$CU_SPEC" ]]; then
    ns="$(printf '%s\n' "$CU_SPEC" | grep -c .)"
    PUB_SPEC="${cur_specs:+$cur_specs$'\n'}$CU_SPEC"
  fi
  if [[ -n "$CU_ISSUE" ]]; then
    ni="$(printf '%s\n' "$CU_ISSUE" | grep -c .)"
    PUB_ISSUE="${cur_issues:+$cur_issues$'\n'}$CU_ISSUE"
  fi
  # The payload names the records THIS attempt appends — the preview may have
  # been computed against an earlier tip, so echoing it back would report work
  # that never happened.
  if (( ns == 0 && ni == 0 )); then
    payload="catch-up: nothing to append — every tree identity already has a record"
  else
    payload="$(printf 'catch-up: appended %d record(s) to specs.log, %d to issues.log' "$ns" "$ni")"
    [[ -n "$CU_SPEC"  ]] && payload+=$'\n'"$(printf '%s\n' "$CU_SPEC"  | sed 's/^/    /')"
    [[ -n "$CU_ISSUE" ]] && payload+=$'\n'"$(printf '%s\n' "$CU_ISSUE" | sed 's/^/    /')"
  fi
  if [[ -n "$CU_BLOCKED" ]]; then
    payload+=$'\n'"  cannot repair (an operator decides which side is right):"
    payload+=$'\n'"$(alloc_catchup_render_blocked "$CU_BLOCKED")"
  fi
  PUB_PAYLOAD="$payload"
  return 0
}

# alloc_catchup_land <spec-derived> <issue-derived> — land the missing records
# through the shared batch-publish (tier selection, erosion re-check, CAS retry),
# then map the outcome onto the verb's exit contract: drift this verb cannot
# repair leaves the run non-zero, so a partial repair never reads as clean.
alloc_catchup_land() {
  CATCHUP_BLOCKED=""
  alloc_publish alloc_catchup_publish_builder "$1" "$2" || return 1
  [[ -n "$CATCHUP_BLOCKED" ]] && return 3
  return 0
}

# cmd_catchup [--apply] — preview (default) or land the missing records.
cmd_catchup() {
  local apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) apply=1; shift ;;
      *) echo "error: unknown option '$1' for catch-up (usage: catch-up [--apply])" >&2; return 2 ;;
    esac
  done
  alloc_in_repo || return 1
  alloc_preflight || return 1
  local specs_root issues_dir
  specs_root="$(alloc_seed_tree_root specs docs/specs)"   || return 1
  issues_dir="$(alloc_seed_tree_root issues docs/issues)" || return 1
  # This verb repairs a NON-EMPTY registry. With no coordination branch there is
  # nothing to catch up to, and creating one here would bootstrap the whole
  # collection behind this verb's provenance marker and without the bootstrap's
  # own preview — then leave `seed` refusing as already-seeded.
  local branch
  branch="$(alloc_coord_branch)" || return 1
  if [[ -z "$(git rev-parse --verify --quiet --end-of-options "refs/heads/$branch" 2>/dev/null || true)" \
        && -z "${JIMALLOC_REGISTRY_DIR:-}" ]]; then
    echo "error: no coordination branch '$branch' to catch up to — bootstrap it with 'seed --apply' first" >&2
    return 1
  fi
  local spec_rec issue_rec
  spec_rec="$(alloc_seed_derive_specs "$specs_root" "$ALLOC_CATCHUP_MARKER")"   || return 1
  issue_rec="$(alloc_seed_derive_issues "$issues_dir" "$ALLOC_CATCHUP_MARKER")" || return 1
  if (( apply )); then
    alloc_catchup_land "$spec_rec" "$issue_rec"
    return $?
  fi
  # Preview reads the last-seen state through the peek model: refresh
  # best-effort, never bind, never mutate.
  alloc_peek_refresh
  local CU_SPEC CU_ISSUE CU_BLOCKED
  alloc_catchup_compute "$spec_rec" "$issue_rec" \
    "$(alloc_read_log spec)" "$(alloc_read_log issue)" || return 1
  printf 'catch-up preview (no changes written):\n'
  if [[ -z "$CU_SPEC" && -z "$CU_ISSUE" ]]; then
    printf '  nothing to append — every tree identity already has a record\n'
  else
    alloc_catchup_render_set "specs.log"  "$CU_SPEC"
    alloc_catchup_render_set "issues.log" "$CU_ISSUE"
  fi
  if [[ -n "$CU_BLOCKED" ]]; then
    printf '  cannot repair (an operator decides which side is right):\n'
    alloc_catchup_render_blocked "$CU_BLOCKED"
  fi
  return 0
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
    # same provisional→real mapping apply would (dropping the internal
    # new/have/blocked column; a blocked identity shows its '-' ordinal). A stop
    # condition surfaces on stderr with no mapping.
    alloc_peek_refresh
    alloc_read_log issue | alloc_reconcile_realize "${pending[@]}" | cut -f1,2
  fi
}

# alloc_group_redirect <group>   (specs log on stdin) — print the name <group>
# now answers to, which is <group> itself when nothing renamed it away.
alloc_group_redirect() {
  local group="$1" current="$1" k v
  while IFS=$'\t' read -r k v; do
    [[ "$k" == "$group" ]] && current="$v"
  done < <(alloc_group_alias_map)
  printf '%s\n' "$current"
}

# alloc_live_claim_set   (specs log on stdin) → fills the caller's `live` array
#   The replay's LIVE rows as a set, for a corroborating writer that only needs
#   to know what is claimed right now.
alloc_live_claim_set() {
  local tag ra
  while IFS=$'\t' read -r tag ra _; do
    [[ "$tag" == LIVE ]] && live["$ra"]=1
  done < <(alloc_spec_replay)
}

# alloc_partition_spec_publish_builder <cur_specs> <cur_issues> <who> <date> <pair...>
#   The spec-renumber emission decision (an alloc_publish builder). Each pair is
#   "<old-id>\t<new-id>\t<slug>"; per pair it appends a `spec allocate` for the
#   destination and a `spec rename` moving the source onto it, preceded by a
#   `group allocate` for any destination group the registry does not hold.
#
#   CORROBORATION RUNS HERE, not at the call site, because here is inside the CAS
#   window: alloc_publish re-invokes this builder on every attempt against freshly
#   read logs, so a destination claimed by a concurrent clone between the check and
#   the commit is caught by the attempt that would have overwritten it. A refusal
#   returns 1 with the conflict named, and nothing is published at all — the batch
#   is all-or-none in the failure direction too.
alloc_partition_spec_publish_builder() {
  local cur_specs="$1" who="$3"; shift 3
  local date="$1"; shift
  local -A live=()
  alloc_live_claim_set < <(printf '%s\n' "$cur_specs")
  local pair old new slug oldc newc grp newrecs="" payload=""
  local -A seen_new=() seen_old=() claimed=()
  for pair in "$@"; do
    IFS=$'\t' read -r old new slug <<< "$pair"
    oldc="$(alloc_canon_specid "$old")" || {
      echo "error: partition-batch refuses source '$(alloc_display_field "$old")' — not a spec id the registry can represent" >&2; return 1; }
    newc="$(alloc_canon_specid "$new")" || {
      echo "error: partition-batch refuses destination '$(alloc_display_field "$new")' — not a spec id the registry can represent" >&2; return 1; }
    alloc_valid_token "$slug" || {
      echo "error: partition-batch refuses slug '$(alloc_display_field "$slug")' for '$newc'" >&2; return 1; }
    if [[ "$oldc" == "$newc" ]]; then
      echo "error: partition-batch refuses '$oldc' — a rename onto its own name records nothing" >&2
      return 1
    fi
    if [[ -z "${live[$oldc]:-}" ]]; then
      echo "error: partition-batch refuses '$oldc' — the registry holds no live claim on it (never allocated, or already moved away)" >&2
      return 1
    fi
    if [[ -n "${live[$newc]:-}" ]]; then
      echo "error: partition-batch refuses '$newc' — destination already claimed in the registry" >&2
      return 1
    fi
    if [[ -n "${seen_old[$oldc]:-}" || -n "${seen_new[$newc]:-}" ]]; then
      echo "error: partition-batch refuses the pair set — '$oldc → $newc' repeats an identity named earlier in the same batch" >&2
      return 1
    fi
    seen_old["$oldc"]=1; seen_new["$newc"]=1
    grp="${newc%/*}"
    if [[ -z "${claimed[$grp]:-}" ]]; then
      local redirect
      redirect="$(printf '%s\n' "$cur_specs" | alloc_group_redirect "$grp")"
      if [[ "$redirect" != "$grp" ]]; then
        echo "error: group renamed — '$grp' is now '$redirect'; re-run the batch against that name" >&2
        return 1
      fi
      printf '%s' "$cur_specs" | alloc_group_present "$grp" \
        || newrecs+="$(alloc_encode_allocate_group "$grp" "$date" "$who")"$'\n'
      claimed["$grp"]=1
    fi
    newrecs+="$(alloc_encode_allocate_spec "$newc" "$slug" "$date" "$who")"$'\n'
    newrecs+="$(alloc_encode_rename_spec "$oldc" "$newc" "$date" "$who")"$'\n'
    payload+="${oldc}"$'\t'"${newc}"$'\n'
  done
  PUB_PAYLOAD="${payload%$'\n'}"
  if [[ -n "$cur_specs" ]]; then
    PUB_SPEC="${cur_specs}"$'\n'"${newrecs%$'\n'}"
  else
    PUB_SPEC="${newrecs%$'\n'}"
  fi
  return 0
}

# alloc_partition_group_publish_builder <cur_specs> <cur_issues> <who> <old> <new> <date>
#   The group-rename emission decision. One record moves every claim under <old>
#   at once, so corroboration is per moved claim: the destination name must hold
#   none of the ordinals that are about to land on it — the exact shape the
#   integrity classifier reports as a duplicate, refused here before it can be
#   written. Same in-CAS placement as the spec builder.
alloc_partition_group_publish_builder() {
  local cur_specs="$1" who="$3"; shift 3
  local old="$1" new="$2" date="$3"
  if [[ "$old" == "$new" ]]; then
    echo "error: partition-batch refuses '$old' — a group rename onto its own name records nothing" >&2
    return 1
  fi
  local redirect
  redirect="$(printf '%s\n' "$cur_specs" | alloc_group_redirect "$old")"
  if [[ "$redirect" != "$old" ]]; then
    echo "error: group renamed — '$old' is now '$redirect'; re-run the batch against that name" >&2
    return 1
  fi
  if ! printf '%s\n' "$cur_specs" | alloc_group_has_records "$old"; then
    echo "error: partition-batch refuses '$old' — the registry holds no record for it" >&2
    return 1
  fi
  local -A live=()
  alloc_live_claim_set < <(printf '%s\n' "$cur_specs")
  local key
  for key in "${!live[@]}"; do
    [[ "$key" == "$old"/* ]] || continue
    if [[ -n "${live[$new/${key##*/}]:-}" ]]; then
      echo "error: partition-batch refuses '$old → $new' — '$new/${key##*/}' is already claimed" >&2
      return 1
    fi
  done
  PUB_PAYLOAD="${old}"$'\t'"${new}"
  if [[ -n "$cur_specs" ]]; then
    PUB_SPEC="${cur_specs}"$'\n'"$(alloc_encode_rename_group "$old" "$new" "$date" "$who")"
  else
    PUB_SPEC="$(alloc_encode_rename_group "$old" "$new" "$date" "$who")"
  fi
  return 0
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
    tok="${pend##*/}"; body="${tok#"$PROV_PREFIX"}"
    date="${body%%-*}"; slug="${body#*-}"
    if [[ -z "${claimed[$grp]:-}" ]] && ! printf '%s' "$cur_specs" | alloc_group_present "$grp"; then
      newrecs+="$(alloc_encode_allocate_group "$grp" "$gdate" "$who")"$'\n'
    fi
    claimed["$grp"]=1
    newrecs+="$(alloc_encode_allocate_spec "$id" "$slug" "$date" "$who")"$'\n'
    # The mapping rides the same CAS as the ordinal it names, in that order, so
    # the destination is established by the time anything reads the record that
    # points at it — and there is never a commit where the ordinal exists but
    # the citation that became it does not resolve. The realization's own date
    # is today's; the issuance date belongs to the allocate record beside it.
    newrecs+="$(alloc_encode_realize_spec "$pend" "$id" "$gdate" "$who")"$'\n'
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
#   alike, so whether an identity was found, freshly allocated, or refused
#   (blocked) is the developer's tell before anything is applied, and dropping
#   it would hide the one signal that separates a resumed run from a collision.
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

# The provenance marker every lifted record carries, so retroactive repair is
# distinguishable from live emission in the log itself — the same role
# jim-seed and jim-catchup play for their appends. It is an audit HINT, not
# authentication: anyone who can push the branch can write any <who>, and the
# append-only branch history remains the authoritative trail.
ALLOC_LIFT_MARKER="jim-lift"

# alloc_lift_state <kind> <src> <dst>   — decide one row against the caller's
#   corroboration state (`live`, `have_rn`, `have_rz`, `rz_of`, `log`, all
#   supplied by alloc_lift_states through dynamic scope, the same way an
#   alloc_publish builder reaches its caller's locals). Prints one of:
#     emit | have | refused:<reason>
#
#   CORROBORATION, stated once here because both the preview and the publish
#   call it: a pair is recordable only when the registry ALREADY establishes its
#   destination and holds no live claim on its source. The lift's input is the
#   specs-root ledger, which lives on ordinary content branches — anyone who can
#   commit can write a pair into it. Without corroboration, an operator's lift
#   run would convert that content into registry records under the operator's
#   own authority, and a crafted pair would mint a redirect pointing a real
#   citation at a destination of the writer's choosing. Requiring the
#   destination to be independently established is what makes the ledger a
#   witness rather than an instruction.
alloc_lift_state() {
  local kind="$1" src="$2" dst="$3" key
  case "$kind" in
    realize)
      [[ -n "${have_rz[$src	$dst]:-}" ]] && { printf 'have\n'; return 0; }
      if [[ -n "${rz_of[$src]:-}" ]]; then
        printf 'refused:source-conflict\n'; return 0
      fi
      [[ -n "${live[$dst]:-}" ]] || { printf 'refused:destination-not-established\n'; return 0; }
      ;;
    spec)
      [[ "$src" != "$dst" ]] || { printf 'refused:self-rename\n'; return 0; }
      [[ -n "${have_rn[spec	$src	$dst]:-}" ]] && { printf 'have\n'; return 0; }
      [[ -n "${live[$dst]:-}" ]] || { printf 'refused:destination-not-established\n'; return 0; }
      [[ -z "${live[$src]:-}" ]] || { printf 'refused:source-claimed\n'; return 0; }
      ;;
    group)
      [[ "$src" != "$dst" ]] || { printf 'refused:self-rename\n'; return 0; }
      [[ -n "${have_rn[group	$src	$dst]:-}" ]] && { printf 'have\n'; return 0; }
      printf '%s\n' "$log" | alloc_group_has_records "$dst" \
        || { printf 'refused:destination-not-established\n'; return 0; }
      for key in "${!live[@]}"; do
        [[ "$key" == "$src"/* ]] || continue
        printf 'refused:source-claimed\n'; return 0
      done
      ;;
    *) printf 'refused:unknown-event\n'; return 0 ;;
  esac
  printf 'emit\n'
}

# alloc_lift_states <row...>   (specs log on stdin)
#   Decide every row against the log on stdin and print the state table:
#     <kind> <src> <dst> <date> <emit|have|refused:...>
#   Each row in is "<kind>\t<src>\t<dst>\t<date>" as jimledger.sh pair-events
#   emits it. Both the preview and the publish builder go through here, so what
#   an operator reads and what the CAS attempt decides are the same computation
#   over different logs — never the same answer replayed.
alloc_lift_states() {
  local -a lines=(); mapfile -t lines
  local log=""; (( ${#lines[@]} )) && log="$(printf '%s\n' "${lines[@]}")"
  local -A live=() have_rn=() have_rz=() rz_of=()
  alloc_live_claim_set < <(printf '%s\n' "$log")
  local rk rsrc rsok rdst rdok zp zpok zr zrok
  while IFS=$'\t' read -r rk rsrc rsok rdst rdok _ _ _; do
    [[ "$rsok" == y && "$rdok" == y ]] || continue
    have_rn["$rk"$'\t'"$rsrc"$'\t'"$rdst"]=1
  done < <(printf '%s\n' "$log" | alloc_rename_scan spec)
  while IFS=$'\t' read -r zp zpok zr zrok _ _ _; do
    [[ "$zpok" == y && "$zrok" == y ]] || continue
    have_rz["$zp"$'\t'"$zr"]=1
    rz_of["$zp"]="$zr"
  done < <(printf '%s\n' "$log" | alloc_realize_scan spec)
  local row kind src dst date canon state
  for row in "$@"; do
    IFS=$'\t' read -r kind src dst date <<< "$row"
    # Second gate on the date, independent of the ledger reader's. It becomes a
    # record field, so it is checked where it is used and not only where it was
    # read — the discipline every other field on this path already follows.
    if [[ ! "$date" =~ ^[0-9]{8}$ ]]; then
      printf '%s\t%s\t%s\t%s\trefused:unrepresentable-date\n' \
        "$(alloc_display_field "$kind")" "$(alloc_display_field "$src")" \
        "$(alloc_display_field "$dst")" "$(alloc_display_field "$date")"
      continue
    fi
    # Normalize both sides the way the registry will spell them, so a row whose
    # ordinal is written unpadded still meets its own record on a re-run.
    case "$kind" in
      realize)
        if ! alloc_valid_provid "$src" || ! canon="$(alloc_canon_specid "$dst")"; then
          printf '%s\t%s\t%s\t%s\trefused:unrepresentable\n' \
            "$kind" "$(alloc_sanitize_field "$src")" "$(alloc_sanitize_field "$dst")" "$date"
          continue
        fi
        dst="$canon"
        ;;
      spec)
        if ! canon="$(alloc_canon_specid "$src")"; then
          printf '%s\t%s\t%s\t%s\trefused:unrepresentable\n' \
            "$kind" "$(alloc_sanitize_field "$src")" "$(alloc_sanitize_field "$dst")" "$date"
          continue
        fi
        src="$canon"
        if ! canon="$(alloc_canon_specid "$dst")"; then
          printf '%s\t%s\t%s\t%s\trefused:unrepresentable\n' \
            "$kind" "$src" "$(alloc_sanitize_field "$dst")" "$date"
          continue
        fi
        dst="$canon"
        ;;
      group)
        if ! alloc_valid_token "$src" || ! alloc_valid_token "$dst"; then
          printf '%s\t%s\t%s\t%s\trefused:unrepresentable\n' \
            "$kind" "$(alloc_sanitize_field "$src")" "$(alloc_sanitize_field "$dst")" "$date"
          continue
        fi
        ;;
    esac
    state="$(alloc_lift_state "$kind" "$src" "$dst")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$src" "$dst" "$date" "$state"
  done
}

# alloc_lift_publish_builder <cur_specs> <cur_issues> <who> <row...>
#   The lift's publish decision (an alloc_publish builder). Recomputes the whole
#   state table against THIS attempt's log and appends only the rows that come
#   back `emit` — so a destination claimed between the preview and the commit is
#   refused by the attempt that would have overwritten it. The preview is
#   advisory; nothing it decided is carried in here.
#
#   <who> is ignored: every lifted record carries the repair marker instead, and
#   the record's date is the day the identity moved, not today.
alloc_lift_publish_builder() {
  local cur_specs="$1"; shift 3
  local newrecs="" table row kind src dst date state
  table="$(printf '%s\n' "$cur_specs" | alloc_lift_states "$@")"
  local -A batch_dst=()
  while IFS=$'\t' read -r kind src dst date state; do
    [[ "$state" == emit ]] || continue
    # Two emit rows landing on one destination corroborate individually and
    # contradict together; the batch refuses the second rather than writing it.
    if [[ -n "${batch_dst[$kind	$dst]:-}" ]]; then
      table="$(printf '%s\n' "$table" | awk -F'\t' -v k="$kind" -v s="$src" -v d="$dst" \
        'BEGIN{OFS="\t"} $1==k && $2==s && $3==d {$5="refused:duplicate-in-batch"} {print}')"
      continue
    fi
    batch_dst["$kind"$'\t'"$dst"]=1
    case "$kind" in
      realize) newrecs+="$(alloc_encode_realize_spec "$src" "$dst" "$date" "$ALLOC_LIFT_MARKER")"$'\n' ;;
      spec)    newrecs+="$(alloc_encode_rename_spec  "$src" "$dst" "$date" "$ALLOC_LIFT_MARKER")"$'\n' ;;
      group)   newrecs+="$(alloc_encode_rename_group "$src" "$dst" "$date" "$ALLOC_LIFT_MARKER")"$'\n' ;;
    esac
  done <<< "$table"
  PUB_PAYLOAD="$table"
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

# cmd_lift [--apply]
#   Turn the specs-root ledger's durable identity-pair events into registry
#   records. Preview by default, in the operator-verb family beside sweep and
#   catch-up: it reports the state of every pair and writes nothing until asked.
#
#   The lift covers only history that predates emission — every realization and
#   every partition operation from here on records itself as it happens. That
#   makes idempotency its whole contract: a re-run reports `have` for everything
#   already recorded and publishes nothing.
#
#   rc 0 clean · rc 1 at least one pair refused (or the publish failed).
cmd_lift() {
  local apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) apply=1; shift ;;
      *) echo "error: unknown option '$1' for lift (usage: lift [--apply])" >&2; return 2 ;;
    esac
  done
  alloc_in_repo || return 1
  local specs_root
  specs_root="$(alloc_seed_tree_root specs docs/specs)" || return 1
  local -a rows=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && rows+=( "$line" )
  done < <(bash "$JIMLEDGER" pair-events "$specs_root" 2>/dev/null || true)
  if (( ! ${#rows[@]} )); then
    echo "lift: no identity-pair events in ${specs_root%/}/ledger.md — nothing to record"
    return 0
  fi
  local table
  if (( apply )); then
    alloc_preflight || return 1
    table="$(alloc_publish alloc_lift_publish_builder "${rows[@]}")" || return 1
  else
    table="$(alloc_read_log spec | alloc_lift_states "${rows[@]}")"
  fi
  [[ -n "$table" ]] && printf '%s\n' "$table"
  printf '%s\n' "$table" | grep -q '	refused:' && return 1
  return 0
}

# cmd_partition_batch spec  <date>            (renumber pairs on stdin)
# cmd_partition_batch group <old> <new> <date>
#   The partition lifecycle's emission surface. Spec mode reads TAB-separated
#   "<old-id>\t<new-id>\t<slug>" rows and publishes the whole set as one
#   all-or-none commit; group mode publishes the single record that moves a whole
#   group. Prints the pairs it published, so a caller can echo what landed.
#
#   Every corroboration decision lives in the builder, which alloc_publish
#   re-invokes per CAS attempt, so each refusal is recomputed against the log
#   that attempt is about to overwrite. Freshness comes from the existing retry
#   loop rather than from a second pre-flight that could go stale between the
#   check and the commit.
cmd_partition_batch() {
  local mode="${1:-}"
  case "$mode" in
    spec)
      local date="${2:-}"
      if [[ -z "$date" ]]; then
        echo "error: 'partition-batch spec' requires <date> (renumber pairs on stdin)" >&2
        return 2
      fi
      [[ "$date" =~ ^[0-9]{8}$ ]] || { echo "error: partition-batch date must be YYYYMMDD" >&2; return 2; }
      local -a pairs=()
      local old new slug
      # `|| [[ -n "$old" ]]` keeps a final row that arrived without its newline —
      # a caller piping a here-string or a command substitution is the normal
      # case, and silently dropping its last pair would publish half a split.
      while IFS=$'\t' read -r old new slug || [[ -n "$old" ]]; do
        [[ -n "$old" ]] || continue
        pairs+=( "${old}"$'\t'"${new}"$'\t'"${slug}" )
      done
      if (( ! ${#pairs[@]} )); then
        echo "error: partition-batch read no renumber pairs on stdin" >&2
        return 2
      fi
      alloc_in_repo || return 1
      alloc_preflight || return 1
      alloc_publish alloc_partition_spec_publish_builder "$date" "${pairs[@]}"
      ;;
    group)
      local old="${2:-}" new="${3:-}" date="${4:-}"
      if [[ -z "$old" || -z "$new" || -z "$date" ]]; then
        echo "error: 'partition-batch group' requires <old> <new> <date>" >&2
        return 2
      fi
      alloc_valid_token "$old" || { echo "error: invalid group '$(alloc_display_field "$old")'" >&2; return 1; }
      alloc_valid_token "$new" || { echo "error: invalid group '$(alloc_display_field "$new")'" >&2; return 1; }
      [[ "$date" =~ ^[0-9]{8}$ ]] || { echo "error: partition-batch date must be YYYYMMDD" >&2; return 2; }
      alloc_in_repo || return 1
      alloc_preflight || return 1
      alloc_publish alloc_partition_group_publish_builder "$old" "$new" "$date"
      ;;
    *)
      echo "error: partition-batch mode must be 'spec' or 'group'" >&2
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
  jimalloc.sh partition-batch spec  <date>       publish a renumber pair set (stdin: old<TAB>new<TAB>slug)
  jimalloc.sh partition-batch group <old> <new> <date>
                                                 publish one group rename
  jimalloc.sh lift [--apply]                     preview (or --apply) ledger pair events as registry records
  jimalloc.sh sweep                              read-only: report tree-vs-registry drift + non-coverage
  jimalloc.sh catch-up [--apply]                 preview (or --apply) the records a non-empty registry is missing
  jimalloc.sh -c <path> <subcmd>                 use <path> instead of ./jimconf.toml

  sweep exits 0 clean, 3 drift found, 4 could-not-check — so a check that could
  not run is never read as a pass. catch-up exits 3 when it lands the records it
  could and leaves unrepairable drift (a mismatch) behind.
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
    sweep)     cmd_sweep     "$@" ;;
    catch-up)  cmd_catchup   "$@" ;;
    reconcile) cmd_reconcile "$@" ;;
    partition-batch) cmd_partition_batch "$@" ;;
    lift)      cmd_lift      "$@" ;;
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
