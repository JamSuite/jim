#!/usr/bin/env bash
#
# skills/file/scripts/jimfile.sh — jim's file/path operation surface.
#
# PURPOSE
#   Resolve deterministic file/path operations for jim's skills and agents:
#   existence checks, slug normalization, today's date, next spec ID,
#   canonical artifact paths, and glob discovery. Skills consume this via
#   Claude Code's `!`-injection primitive so the resolved string lands in
#   the prompt before the LLM reads it. The /jim:file user-facing skill
#   is a thin wrapper.
#
#   Configurable directories (specs, debug, brainstorms) are resolved by
#   shelling out to the sibling jimconf.sh — that script is the single
#   source of truth for path overrides via jimconf.toml. The relative
#   path is computed from BASH_SOURCE so the composition is portable
#   across plugin install scopes.
#
# CLI SUMMARY
#   bash jimfile.sh exists <path>                     "yes" | "no" on stdout
#   bash jimfile.sh get <key>                         configured path *if it exists*
#                                                     on disk, else the literal
#                                                     string "NOT_FOUND" (delegates
#                                                     to jimconf.sh, then
#                                                     existence-checks)
#   bash jimfile.sh slug <topic>                      kebab-case slug
#   bash jimfile.sh date                              today as YYYYMMDD
#   bash jimfile.sh next-id <group>                   next zero-padded spec id
#   bash jimfile.sh mv-spec <group> <id> <new-name>   rename {id}-* spec dir to
#                                                     {id}-{new-name} (wip rename)
#   bash jimfile.sh mv-spec-id <group> <old-basename> <new-id> <name>
#                                                     rename a spec dir onto a
#                                                     different id (shift/realize)
#   bash jimfile.sh path <key>                        configured path for <key>,
#                                                     regardless of existence
#                                                     (D3 — single-arg form)
#   bash jimfile.sh path spec      <group> <id> <name>
#   bash jimfile.sh path plan      <group> <id> <name>
#   bash jimfile.sh path research  <group> <id> <name>
#   bash jimfile.sh path debug     <topic>            collision-resolved
#   bash jimfile.sh path brainstorm <topic>           collision-resolved
#   bash jimfile.sh glob specs [<group>]              one path per line
#   bash jimfile.sh glob debug                        one path per line
#   bash jimfile.sh glob brainstorms                  one path per line
#   bash jimfile.sh kinds                             valid kinds, no I/O
#   bash jimfile.sh valid-relpath <path>              exit 0 iff safe repo-relative
#   bash jimfile.sh -c <path> <subcmd>                use <path> as jimconf.toml
#
# KIND-VS-KEY: `blueprint`
#   `blueprint` is both a config KEY (the project-tier map, default
#   BLUEPRINT.md at the project root) and a per-group KIND (the reserved
#   000-blueprint slot). Verb + arity disambiguate:
#     get blueprint            → map path, existence-gated (NOT_FOUND if absent)
#     path blueprint           → map path from config, regardless of existence
#     path blueprint <group>   → {specs}/<group>/000-blueprint/spec.md (kind)
#
# CONVENTION
#   Production skills do NOT pass -c. The flag exists for tests and ad-hoc
#   inspection; it is forwarded to jimconf.sh.
#
# EXIT CODES
#   0  Success.
#   1  Validation failure (invalid slug result, unknown kind, etc.).
#   2  Malformed invocation (missing argument, unknown subcommand).
#

set -uo pipefail
# LC_ALL=C ensures locale-independent behavior for `tr` case folding, regex
# character class matching, and date formatting. Without this, locales like
# Turkish produce non-deterministic slugs (dotless ı / dotted İ are not ASCII
# i/I).
export LC_ALL=C

# ─── Section: Globals ────────────────────────────────────────────────────────

# Path to the sibling jimconf.sh. BASH_SOURCE-relative so the composition
# travels with the plugin tree (skills/file/scripts/ → skills/conf/scripts/).
JIMCONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../conf/scripts" && pwd)/jimconf.sh"

# Path to the sibling jimledger.sh (the vacated-id floor source). BASH_SOURCE-relative
# like JIMCONF (skills/file/scripts/ → skills/ledger/scripts/). Consulted
# best-effort by next-id — an older checkout without the ledger skill resolves to
# a non-existent path and degrades to directory-only id derivation.
JIMLEDGER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ledger/scripts" 2>/dev/null && pwd)/jimledger.sh"

# Valid artifact kinds. Drives `path <kind>` validation and `kinds` output.
readonly KINDS=(spec plan research debug brainstorm issue blueprint)

# The reserved per-group blueprint directory name. Sorts ahead of `001`, parses
# to id `0`, and is skipped by next-id. The single definition of this literal in
# code — consumed by the blueprint slot resolver and emitted by `blueprint-dirname`
# for sibling scripts that compose the directory path on their own base.
readonly BLUEPRINT_DIRNAME="000-blueprint"

# Optional -c <path> override for jimconf.toml. Empty when not supplied.
CONFIG_FILE=""

# ─── Section: Validation ─────────────────────────────────────────────────────

# is_kind <name>
#   Return 0 if <name> is in $KINDS, 1 otherwise.
is_kind() {
  local needle="$1" k
  for k in "${KINDS[@]}"; do
    if [[ "$k" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

# jimconf_get <cli-key>
#   Resolve a configurable directory by shelling out to jimconf.sh. Forwards
#   any -c override the user supplied. Output is the raw string from
#   jimconf.sh (path, no trailing newline by command substitution).
jimconf_get() {
  local cli_key="$1"
  if [[ -n "$CONFIG_FILE" ]]; then
    bash "$JIMCONF" -c "$CONFIG_FILE" get "$cli_key"
  else
    bash "$JIMCONF" get "$cli_key"
  fi
}

# ─── Section: Slug / date helpers ────────────────────────────────────────────

# normalize_slug <topic>
#   Apply the documented slug pipeline:
#     lowercase → non-alnum→'-' → collapse runs → strip leading/trailing → cap 64
#   Reject empty result, "." literal, ".." literal (exit 1, stderr).
#   This is the security boundary — never delegate to the LLM.
normalize_slug() {
  local topic="$1"
  if [[ "$topic" == "." || "$topic" == ".." ]]; then
    echo "error: slug rejected — literal '.' and '..' are not allowed" >&2
    return 1
  fi
  local slug
  slug=$(printf '%s' "$topic" \
    | tr 'A-Z' 'a-z' \
    | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//; s/-$//' \
    | cut -c1-64)
  if [[ -z "$slug" ]]; then
    echo "error: slug rejected — input '$topic' produced an empty result" >&2
    return 1
  fi
  printf '%s\n' "$slug"
}

# today_yyyymmdd
#   Print today's date as YYYYMMDD. Single source of truth for date
#   prefixes on debug and brainstorm filenames.
today_yyyymmdd() {
  date +%Y%m%d
}

# now_utc_iso8601
#   Print the current second-resolution UTC timestamp as ISO 8601 with a Z
#   suffix (e.g. 2026-06-13T14:45:30Z). Single source of truth for issue
#   created/updated stamping. The format is a hardcoded literal — it takes no
#   argument and is never config-driven.
now_utc_iso8601() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# is_valid_slug <slug>
#   Slug must be lowercase alnum + dash only, alnum-start,
#   non-empty. Rejects path separators (/, \), '..', leading dot, control
#   characters, and any other non-conforming input. Errors go to stderr;
#   stdout stays empty.
is_valid_slug() {
  local slug="$1"
  if [[ -z "$slug" ]]; then
    echo "error: slug rejected — empty" >&2
    return 1
  fi
  if [[ ! "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "error: slug rejected — '$slug' (allowed: ^[a-z0-9][a-z0-9-]*$)" >&2
    return 1
  fi
  return 0
}

# is_valid_id <id>
#   Bounded allowlist for a resolved prefix or a full issue id. Broader than
#   is_valid_slug — uppercase and '.' are allowed — but
#   still a positive allowlist, never a denylist, so it cannot escape the
#   issues directory or be parsed as a flag by downstream tooling.
#
#   SYNC: the function body below is mirrored verbatim in
#   skills/issue/scripts/index.sh and skills/issue/scripts/render.sh. A
#   tests/jimfile.sh case asserts the three copies are byte-identical — keep
#   them in lockstep when editing.
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

# ─── Section: Subcommand handlers ────────────────────────────────────────────

# cmd_valid_id <id> — exit 0 if <id> passes is_valid_id, else 1. Lets callers
# (e.g. skills/issue/scripts/migrate.sh) validate a full re-derived id through
# the single security boundary without copying is_valid_id a fourth time.
cmd_valid_id() {
  is_valid_id "${1:-}"
}

# cmd_valid_relpath <path> — exit 0 iff <path> is a safe repo-relative path:
# non-empty, not absolute, no '..' path segment. The deterministic shape gate
# for territory declarations recorded in the project map. Shape-only:
# existence is deliberately not checked — a
# declared territory may predate its code. Segment-precise: 'a..b/x' passes
# ('..' inside a name), 'a/../b' is rejected ('..' as a segment).
cmd_valid_relpath() {
  local p="${1:-}"
  if [[ -z "$p" ]]; then
    echo "error: relpath rejected — empty" >&2
    return 1
  fi
  if [[ "$p" == /* ]]; then
    echo "error: relpath rejected — absolute: '$p'" >&2
    return 1
  fi
  case "/$p/" in
    */../*)
      echo "error: relpath rejected — contains '..' segment: '$p'" >&2
      return 1
      ;;
  esac
  return 0
}

cmd_exists() {
  local path="${1:-}"
  if [[ -z "$path" ]]; then
    echo "error: 'exists' requires a path argument" >&2
    return 2
  fi
  if [[ -e "$path" ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

cmd_get() {
  local cli_key="${1:-}"
  if [[ -z "$cli_key" ]]; then
    echo "error: 'get' requires a key argument" >&2
    return 2
  fi
  local resolved rc
  resolved="$(jimconf_get "$cli_key")"
  rc=$?
  if (( rc != 0 )); then
    return $rc
  fi
  if [[ -n "$resolved" && -e "$resolved" ]]; then
    printf '%s\n' "$resolved"
  else
    printf '%s\n' "NOT_FOUND"
  fi
}

cmd_slug() {
  local topic="${1:-}"
  if [[ -z "$topic" ]]; then
    echo "error: 'slug' requires a topic argument" >&2
    return 2
  fi
  normalize_slug "$topic"
}

cmd_date() {
  today_yyyymmdd
}

cmd_now() {
  now_utc_iso8601
}

cmd_next_id() {
  local first="${1:-}"
  if [[ -z "$first" ]]; then
    echo "error: 'next-id' requires an argument" >&2
    return 2
  fi
  # Dispatch by first arg: 'issue' takes a subject and returns a
  # date-prefixed slug; everything else is treated as a spec group name
  # (existing numeric-id behavior).
  if [[ "$first" == "issue" ]]; then
    local subject="${2:-}"
    if [[ -z "$subject" ]]; then
      echo "error: 'next-id issue' requires <subject>" >&2
      return 2
    fi
    local slug prefix
    slug="$(normalize_slug "$subject")" || return 1
    is_valid_slug "$slug" || return 1
    prefix="$(resolve_issue_prefix)"
    printf '%s-%s\n' "$prefix" "$slug"
    return 0
  fi
  local group="$first"
  local specs_root group_dir max=0
  specs_root="$(jimconf_get specs)"
  group_dir="$specs_root/$group"
  if [[ -d "$group_dir" ]]; then
    local entry name id_part id_clean
    for entry in "$group_dir"/*/; do
      [[ -d "$entry" ]] || continue
      name="$(basename "$entry")"
      # Match leading 3-digit prefix followed by '-' or end.
      id_part="${name%%-*}"
      # Strip leading zeros for arithmetic (but guard '000' → 0).
      id_clean="$(printf '%s' "$id_part" | sed 's/^0*//')"
      [[ -z "$id_clean" ]] && id_clean=0
      if [[ "$id_clean" =~ ^[0-9]+$ ]]; then
        if (( id_clean > max )); then
          max=$id_clean
        fi
      fi
    done
  fi
  # Vacated-id floor: consult the specs-root ledger's op=split and op=merge
  # remaps so the group never re-mints an id a split or merge moved out — the
  # tail-move, split retired-group, and merge retired-source re-mint cases.
  # Best-effort and monotonic: an absent script, a non-zero rc, or empty output
  # leaves the floor unset, and the floor only ever raises max, never lowers it
  # (older checkouts degrade to directory-only).
  if [[ -f "$JIMLEDGER" ]]; then
    local floor floor_clean
    floor="$(bash "$JIMLEDGER" vacated-max "$specs_root" "$group" 2>/dev/null)" || floor=""
    if [[ "$floor" =~ ^[0-9]{3}$ ]]; then
      floor_clean="$(printf '%s' "$floor" | sed 's/^0*//')"
      [[ -z "$floor_clean" ]] && floor_clean=0
      if (( floor_clean > max )); then
        max=$floor_clean
      fi
    fi
  fi
  local next=$(( max + 1 ))
  if (( next > 999 )); then
    echo "error: id space exhausted for $group (next id would exceed 999)" >&2
    return 1
  fi
  printf '%03d\n' "$next"
}

# cmd_mv_spec <group> <id> <new-name>
#   Rename the spec directory {specs}/{group}/{id}-* to {id}-{new-name}. Used by
#   /jim:spec to rename the `wip` placeholder dir (created at interview start so
#   the jim ledger has a home) once the spec's slug is settled. Validates
#   group/id/new-name before any move, resolves the single {id}-* dir, no-ops if
#   already named, and refuses to clobber a different target. Prints the
#   resolved target dir on success.
cmd_mv_spec() {
  local group="${1:-}" id="${2:-}" new_name="${3:-}"
  if [[ -z "$group" || -z "$id" || -z "$new_name" ]]; then
    echo "error: 'mv-spec' requires <group> <id> <new-name>" >&2
    return 2
  fi
  # group: the broad path-safe allowlist (forecloses '/', '..', leading dash).
  if ! is_valid_id "$group"; then
    echo "error: mv-spec group rejected — '$group'" >&2
    return 1
  fi
  # id: a zero-padded 3-digit spec id.
  if [[ ! "$id" =~ ^[0-9]{3}$ ]]; then
    echo "error: mv-spec id rejected — '$id' (allowed: ^[0-9]{3}\$)" >&2
    return 1
  fi
  # new-name: the spec dir slug (lowercase alnum + dash, alnum-start).
  if ! is_valid_slug "$new_name"; then
    echo "error: mv-spec new-name rejected — '$new_name'" >&2
    return 1
  fi
  local specs_root group_dir
  specs_root="$(jimconf_get specs)"
  group_dir="$specs_root/$group"
  if [[ ! -d "$group_dir" ]]; then
    echo "error: mv-spec group dir not found — '$group_dir'" >&2
    return 1
  fi
  local target="$group_dir/$id-$new_name"
  # Resolve the single existing {id}-* source dir.
  local entry src="" count=0
  for entry in "$group_dir/$id"-*/; do
    [[ -d "$entry" ]] || continue
    src="${entry%/}"
    count=$(( count + 1 ))
  done
  if (( count == 0 )); then
    echo "error: mv-spec no dir matching '$id-*' in '$group_dir'" >&2
    return 1
  fi
  if (( count > 1 )); then
    echo "error: mv-spec multiple dirs match '$id-*' in '$group_dir'" >&2
    return 1
  fi
  # Already at the target name → no-op success (idempotent).
  if [[ "$src" == "$target" ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  # Another directory on the same ordinal is registry-vs-tree drift; renaming
  # the slug would carry it forward. Same numeric predicate the cross-id rename
  # enforces, with the source excluded so an ordinary slug rename is unaffected.
  local held held_rc
  held="$(spec_ordinal_holder "$specs_root" "$group" "$id" "$(basename -- "$src")")"
  held_rc=$?
  if (( held_rc == 0 )); then
    echo "error: mv-spec ordinal $id is already held by '$held'" \
         "(registry-vs-tree drift); nothing renamed" >&2
    return 1
  fi
  if (( held_rc != 1 )); then
    echo "error: mv-spec could not decide occupancy of ordinal '$id'" >&2
    return 1
  fi
  # Refuse to clobber a different existing target.
  if [[ -e "$target" ]]; then
    echo "error: mv-spec target already exists — '$target'" >&2
    return 1
  fi
  local src_ino
  src_ino="$(dir_inode "$src")"
  if ! mv -- "$src" "$target"; then
    echo "error: mv-spec failed to rename '$src' -> '$target'" >&2
    return 1
  fi
  undo_nested_rename "$src" "$target" "$src_ino" || return 1
  printf '%s\n' "$target"
}

# The reserved prefix a provisional identity's ordinal slot carries. The grammar
# is the allocator's; it is named here because a spec dir bound offline wears it
# as a directory name and this boundary has to recognize one.
SPEC_PROV_PREFIX="P-"

# is_spec_dir_basename <name>
#   Exit 0 iff <name> is a basename a spec directory can carry: a real ordinal
#   (bare or slugged) or the reserved provisional form over a token the id
#   boundary accepts. Nothing else — an arbitrary directory, a path separator,
#   '..', or a prefixed name whose token is unusable is refused, so the rename
#   verbs cannot be pointed at a directory that is not a spec.
is_spec_dir_basename() {
  local name="$1" tok
  [[ -n "$name" ]]        || return 1
  [[ "$name" == *"/"* ]]  && return 1
  [[ "$name" == *".."* ]] && return 1
  [[ "$name" =~ ^[0-9]{3,15}(-.+)?$ ]] && return 0
  if [[ "$name" == "$SPEC_PROV_PREFIX"* ]]; then
    tok="${name#"$SPEC_PROV_PREFIX"}"
    [[ -n "$tok" ]] || return 1
    is_valid_id "$tok" >/dev/null 2>&1 && return 0
  fi
  return 1
}

# is_prov_basename <name>
#   Exit 0 iff <name> is the reserved provisional ordinal form: the prefix, then
#   an 8-digit issuance date, then a slug, the whole token through the id
#   boundary. A spec bound while the coordination point was unreachable wears
#   this as its directory name, and the token is the entire basename — there is
#   no separate ordinal and slug to compose.
is_prov_basename() {
  local name="$1" body date slug
  [[ "$name" == "$SPEC_PROV_PREFIX"* ]] || return 1
  body="${name#"$SPEC_PROV_PREFIX"}"
  [[ -n "$body" ]] || return 1
  date="${body%%-*}"; slug="${body#*-}"
  [[ "$date" =~ ^[0-9]{8}$ ]] || return 1
  [[ -n "$slug" && "$slug" != "$body" ]] || return 1
  is_valid_id "$body" >/dev/null 2>&1
}

# spec_ordinal_holder <specs_dir> <group> <ordinal> [<exclude_basename>]
#   Print the basename of the sibling directory already holding <ordinal> in
#   <group>. rc 0 held (holder printed) · rc 1 free · rc 2 unusable argument.
#
#   Occupancy is decided NUMERICALLY: a spec ordinal is a number that happens to
#   be written zero-padded, so '18' and '018' are one ordinal, and a bare-ordinal
#   directory holds it as surely as a slugged one. Deciding it by string match is
#   what lets a differently-spelled ordinal read as free space and land a second
#   directory on an ordinal already taken.
#
#   A sibling whose leading token is not a usable ordinal — a plain name, a
#   pending provisional dir, or a token wider than the registry could be rebuilt
#   from — is skipped: never counted as a holder, never an error. The tree is
#   branch-writable, so one unusable sibling must decide nothing and stop
#   nothing. An unusable ARGUMENT is the opposite: rc 2, because reading a
#   rejected ordinal as "free" is exactly how a bad token gets through.
#
#   <exclude_basename> names a directory to ignore, so a rename whose source
#   already sits on the target ordinal does not collide with itself.
spec_ordinal_holder() {
  local root="$1" group="$2" ord="$3" exclude="${4:-}"
  [[ -n "$root" ]] || return 2
  is_valid_id "$group" >/dev/null 2>&1 || return 2
  [[ "$ord" =~ ^[0-9]{1,15}$ ]] || return 2
  if [[ -n "$exclude" ]]; then
    is_spec_dir_basename "$exclude" || return 2
  fi
  local group_dir="$root/$group"
  [[ -d "$group_dir" ]] || return 1
  local entry name tok
  for entry in "$group_dir"/*/; do
    [[ -d "$entry" ]] || continue
    name="${entry%/}"; name="${name##*/}"
    [[ -n "$exclude" && "$name" == "$exclude" ]] && continue
    tok="${name%%-*}"
    [[ "$tok" =~ ^[0-9]{1,15}$ ]] || continue
    if (( 10#$tok == 10#$ord )); then
      printf '%s\n' "$name"
      return 0
    fi
  done
  return 1
}

# dir_inode <path> — the inode number of <path> itself, empty if unreadable.
# `ls -di` is the portable spelling; `stat` differs between GNU and BSD.
dir_inode() {
  ls -di -- "$1" 2>/dev/null | awk 'NR==1{print $1}'
}

# undo_nested_rename <src> <target> <src-inode-before>
#   A directory that appears at <target> between the existence check and the move
#   turns `mv <src> <target>` into a move INSIDE it, leaving the source nested
#   under a directory this command never created — a realized-but-wrong spec
#   directory, exactly the silent wrong state a rename must not produce.
#
#   Detected by identity, not by name: the rename landed only if <target> IS the
#   directory that was at <src>. Comparing inodes rather than looking for a
#   nested basename keeps a spec directory that legitimately contains an entry of
#   that name from reading as the artifact.
#
#   rc 0 the rename landed · rc 1 it did not; the source is restored where
#   possible and the caller must fail rather than report a rename that did not
#   happen. `mv -T` would foreclose the race outright, but it is GNU-only and
#   this layer is bash plus POSIX tools.
undo_nested_rename() {
  local src="$1" target="$2" src_ino="$3"
  local base="${src##*/}" nested
  [[ -n "$src_ino" ]] || return 0
  [[ "$(dir_inode "$target")" == "$src_ino" ]] && return 0
  nested="$target/$base"
  if [[ "$(dir_inode "$nested")" == "$src_ino" ]] && [[ ! -e "$src" ]] \
     && mv -- "$nested" "$src"; then
    echo "error: '$target' appeared as a directory during the rename and '$src'" \
         "was moved inside it; restored — nothing was renamed" >&2
  else
    echo "error: '$target' appeared as a directory during the rename and '$src'" \
         "did not land there; it could not be restored — repair '$target' by hand" >&2
  fi
  return 1
}

# cmd_spec_ordinal_holder <group> <ordinal> [--exclude <basename>]
#   The verb form of spec_ordinal_holder over the configured specs dir, so the
#   realizer decides occupancy through the same predicate the rename verbs
#   enforce rather than keeping a second copy in agreement by convention.
cmd_spec_ordinal_holder() {
  local group="" ord="" exclude="" seen=0
  while (( $# )); do
    case "$1" in
      --exclude)
        if [[ -z "${2:-}" ]]; then
          echo "error: spec-ordinal-holder: --exclude requires a basename" >&2
          return 2
        fi
        exclude="$2"; shift 2 ;;
      -*)
        echo "error: spec-ordinal-holder: unknown option '$1'" >&2
        return 2 ;;
      *)
        case "$seen" in
          0) group="$1" ;;
          1) ord="$1" ;;
          *) echo "error: spec-ordinal-holder: unexpected argument '$1'" >&2; return 2 ;;
        esac
        seen=$(( seen + 1 )); shift ;;
    esac
  done
  if [[ -z "$group" || -z "$ord" ]]; then
    echo "error: 'spec-ordinal-holder' requires <group> <ordinal> [--exclude <basename>]" >&2
    return 2
  fi
  local specs_root rc
  specs_root="$(jimconf_get specs)"
  spec_ordinal_holder "$specs_root" "$group" "$ord" "$exclude"
  rc=$?
  if (( rc == 2 )); then
    echo "error: spec-ordinal-holder rejected its arguments — group '$group'," \
         "ordinal '$ord'${exclude:+, exclude '$exclude'}" >&2
  fi
  return "$rc"
}

# cmd_mv_spec_id <group> <old-basename> <new-id> <name>
#                <group> <old-basename> <provisional-token>
#   Rename {specs}/{group}/{old-basename}/ onto a different identity — the
#   cross-id rename mv-spec cannot express, since its single {id} drives both the
#   source glob and the target name. Three callers need it: an advisory ordinal
#   that shifted before binding, a placeholder binding to a provisional identity
#   offline, and a pending provisional identity being realized onto its real
#   ordinal.
#
#   The four-argument form composes {new-id}-{name}: {new-id} is digits between
#   the padded floor and the width the registry can be rebuilt from (so an
#   unpadded id never becomes a directory name) and {name} clears the slug
#   boundary. The three-argument form takes the target basename whole, and ONLY
#   for the reserved provisional form, whose token is the entire basename; every
#   other target must go through the four-argument form, so this is not a general
#   rename-to-anything escape hatch.
#
#   {group} clears the id boundary and {old-basename} the spec-dir basename gate
#   in both forms. Same parent only; the source must exist, an ordinal another
#   directory already holds is refused, and an existing target is refused rather
#   than clobbered — a spec ordinal is path identity, so a collision halts
#   instead of overwriting or suffixing. A target that appears only after that
#   check is caught after the move and undone. Prints the target dir. The
#   uncommitted-case twin of jimledger.sh's rename-tracked.
cmd_mv_spec_id() {
  local group="${1:-}" old="${2:-}" new_id="${3:-}" new_name="${4:-}"
  if [[ -z "$group" || -z "$old" || -z "$new_id" ]]; then
    echo "error: 'mv-spec-id' requires <group> <old-basename> <new-id> <name>" \
         "(or <group> <old-basename> <provisional-token>)" >&2
    return 2
  fi
  if ! is_valid_id "$group"; then
    echo "error: mv-spec-id group rejected — '$group'" >&2
    return 1
  fi
  if ! is_spec_dir_basename "$old"; then
    echo "error: mv-spec-id source rejected — '$old'" >&2
    return 1
  fi
  local new_base
  if [[ -z "$new_name" ]]; then
    # Three-argument form: the provisional token IS the basename.
    if ! is_prov_basename "$new_id"; then
      echo "error: mv-spec-id target rejected — '$new_id' (the 3-argument form takes" \
           "a provisional token only; use <new-id> <name> for a real ordinal)" >&2
      return 1
    fi
    new_base="$new_id"
  else
    if [[ ! "$new_id" =~ ^[0-9]{3,15}$ ]]; then
      echo "error: mv-spec-id new-id rejected — '$new_id' (allowed: ^[0-9]{3,15}\$)" >&2
      return 1
    fi
    if ! is_valid_slug "$new_name"; then
      echo "error: mv-spec-id name rejected — '$new_name'" >&2
      return 1
    fi
    new_base="$new_id-$new_name"
  fi
  local specs_root group_dir
  specs_root="$(jimconf_get specs)"
  group_dir="$specs_root/$group"
  if [[ ! -d "$group_dir" ]]; then
    echo "error: mv-spec-id group dir not found — '$group_dir'" >&2
    return 1
  fi
  local src="$group_dir/$old" target="$group_dir/$new_base"
  if [[ ! -d "$src" ]]; then
    echo "error: mv-spec-id source dir not found — '$src'" >&2
    return 1
  fi
  # A spec ordinal is path identity, so ANOTHER directory already holding the
  # target ordinal is registry-vs-tree drift — refuse rather than land a second
  # directory on it. Numeric, so a differently-padded occupant still collides;
  # the source excludes itself, since a placeholder already sitting on the
  # ordinal it is being named within is not a collision. The provisional target
  # form carries no ordinal, so only the numeric form is checked.
  local held held_rc
  if [[ -n "$new_name" ]]; then
    held="$(spec_ordinal_holder "$specs_root" "$group" "$new_id" "$old")"
    held_rc=$?
    if (( held_rc == 0 )); then
      echo "error: mv-spec-id ordinal $new_id is already held by '$held'" \
           "(registry-vs-tree drift); nothing renamed" >&2
      return 1
    fi
    if (( held_rc != 1 )); then
      echo "error: mv-spec-id could not decide occupancy of ordinal '$new_id'" >&2
      return 1
    fi
  fi
  if [[ -e "$target" ]]; then
    echo "error: mv-spec-id target already exists — '$target'" >&2
    return 1
  fi
  local src_ino
  src_ino="$(dir_inode "$src")"
  if ! mv -- "$src" "$target"; then
    echo "error: mv-spec-id failed to rename '$src' -> '$target'" >&2
    return 1
  fi
  undo_nested_rename "$src" "$target" "$src_ino" || return 1
  printf '%s\n' "$target"
}

# issue_next_num <issues_dir>
#   Scan <issues_dir>/*.md for top-level `num:` frontmatter and print max+1
#   (or 1 when none carry a num). Shared by cmd_next_num and the `{seq}`
#   prefix token. Reads num: only; never mutates. The display
#   ordinal is decentralized — duplicates across branches are accepted as
#   non-fatal.
issue_next_num() {
  local dir="${1:-}" max=0 f n
  dir="${dir%/}"
  if [[ -d "$dir" ]]; then
    for f in "$dir"/*.md; do
      [[ -f "$f" ]] || continue
      n="$(grep -E '^num:[[:space:]]*[0-9]+' "$f" 2>/dev/null \
        | head -n 1 \
        | sed -E 's/^num:[[:space:]]*([0-9]+).*/\1/')"
      [[ "$n" =~ ^[0-9]+$ ]] || continue
      if (( n > max )); then
        max=$n
      fi
    done
  fi
  printf '%d\n' $(( max + 1 ))
}

# cmd_next_num <kind>
#   For 'issue': resolve the configured issues directory and print the next
#   display ordinal via issue_next_num.
cmd_next_num() {
  local kind="${1:-}"
  if [[ "$kind" != "issue" ]]; then
    echo "error: 'next-num' requires the 'issue' kind" >&2
    return 2
  fi
  local dir
  dir="$(jimconf_get issues)"
  issue_next_num "$dir"
}

# render_template <template> <ordinal>
#   Expand a prefix template to stdout. Recognized tokens:
#     {date:FMT}      -> date +"FMT"  (single quoted arg; rc 1 on date failure)
#     {seq} | {seq:W} -> <ordinal>, zero-padded to width W when W is given
#   Any other text passes through verbatim. Returns rc 1 when a {date:...}
#   render fails or an unknown / malformed token is encountered. The format
#   string is passed as a single quoted argument to `date` — never eval'd or
#   word-split; LC_ALL=C from the preamble
#   keeps output deterministic. Charset validation is the caller's job.
render_template() {
  local tmpl="$1" ordinal="$2"
  local out="" rest="$tmpl" lit token inner
  while [[ -n "$rest" ]]; do
    if [[ "$rest" != *'{'* ]]; then
      out+="$rest"
      break
    fi
    lit="${rest%%\{*}"
    out+="$lit"
    rest="${rest#"$lit"}"          # rest now starts with '{'
    token="${rest%%\}*}"           # up to (not including) the next '}'
    if [[ "$token" == "$rest" ]]; then
      out+="$rest"                 # no closing brace — emit remainder literally
      break
    fi
    token="${token}}"             # restore the closing brace -> '{...}'
    rest="${rest#"$token"}"
    inner="${token#\{}"; inner="${inner%\}}"
    case "$inner" in
      date:*)
        local fmt rendered
        fmt="${inner#date:}"
        rendered="$(date +"$fmt")" || return 1
        out+="$rendered"
        ;;
      seq)
        out+="$ordinal"
        ;;
      seq:*)
        local width="${inner#seq:}"
        [[ "$width" =~ ^[0-9]+$ ]] || return 1
        out+="$(printf "%0*d" "$((10#$width))" "$ordinal")"
        ;;
      *)
        return 1
        ;;
    esac
  done
  printf '%s' "$out"
}

# resolve_issue_prefix
#   Resolve the configured issue-id prefix. Maps the preset name in
#   issue_id_prefix to a template, renders it (projecting the next ordinal for
#   {seq}), and validates the result with is_valid_id. Prints the
#   resolved prefix on success. Falls back to the YYYYMMDD- date prefix when
#   the scheme is unknown, the project tag is empty, or rendering/validation
#   fails — emitting a one-line notice to stderr in those malformed cases
#   while a blank/absent config resolves silently to date.
#   Resolution stays entirely in bash — never delegated to the caller.
resolve_issue_prefix() {
  local scheme project tmpl ordinal prefix default_prefix
  scheme="$(jimconf_get issue_id_prefix)"
  default_prefix="$(today_yyyymmdd)"
  case "$scheme" in
    date)       tmpl='{date:%Y%m%d}' ;;
    timestamp)  tmpl='{date:%Y%m%dT%H%M%S}' ;;
    sequential) tmpl='{seq:04}' ;;
    project)
      project="$(jimconf_get issue_id_project)"
      if [[ -z "$project" ]]; then
        echo "warning: issue_id_prefix=\"project\" but issue_id_project is empty — using the default date prefix" >&2
        printf '%s' "$default_prefix"; return 0
      fi
      tmpl="$project" ;;
    *'{'*)      tmpl="$scheme" ;;   # template escape hatch (contains a token)
    *)
      echo "warning: issue_id_prefix=\"$scheme\" is not a known preset or template — using the default date prefix" >&2
      printf '%s' "$default_prefix"; return 0 ;;
  esac
  ordinal="$(issue_next_num "$(jimconf_get issues)")"
  if prefix="$(render_template "$tmpl" "$ordinal")" && is_valid_id "$prefix" 2>/dev/null; then
    printf '%s' "$prefix"
  else
    echo "warning: issue_id_prefix=\"$scheme\" produced an invalid prefix — using the default date prefix" >&2
    printf '%s' "$default_prefix"
  fi
}

# cmd_prefix_from <created_iso> <num>
#   Re-derive the active issue_id_prefix from an issue's OWN stored data (spec
#   023): `created` -> date/timestamp prefix, `num` -> sequential, the configured
#   tag -> project. Renders only from stored inputs (never the run clock) and
#   validates the result via is_valid_id. Prints the prefix on success. rc 1 +
#   "un-migratable: <reason>" when the active scheme needs an input the issue
#   lacks (missing/non-conforming `created`, absent `num`/tag) or for a custom
#   {date:...} template that can't be reshaped without `date -d` (non-POSIX).
# SYNC(ts-shape): ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$
cmd_prefix_from() {
  local created="${1:-}" num="${2:-}" scheme project prefix date_part
  scheme="$(jimconf_get issue_id_prefix)"
  case "$scheme" in
    date|timestamp)
      if [[ ! "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$ ]]; then
        echo "un-migratable: created \"$created\" is not a valid date or timestamp" >&2
        return 1
      fi
      date_part="${created:0:4}${created:5:2}${created:8:2}"
      if [[ "$scheme" == date ]]; then
        prefix="$date_part"
      elif [[ "$created" == *T*Z ]]; then
        prefix="${date_part}T${created:11:2}${created:14:2}${created:17:2}"
      else
        prefix="${date_part}T000000"        # date-only -> day-start
      fi
      ;;
    sequential)
      [[ "$num" =~ ^[0-9]+$ ]] || {
        echo "un-migratable: num \"$num\" is not a display ordinal" >&2; return 1; }
      prefix="$(render_template '{seq:04}' "$num")" || {
        echo "un-migratable: sequential render failed" >&2; return 1; }
      ;;
    project)
      project="$(jimconf_get issue_id_project)"
      [[ -n "$project" ]] || {
        echo "un-migratable: issue_id_prefix=project but issue_id_project is empty" >&2; return 1; }
      prefix="$project"
      ;;
    *'{date:'*)
      echo "un-migratable: custom {date:...} template can't be re-derived without date -d (POSIX)" >&2
      return 1
      ;;
    *'{'*)
      [[ "$num" =~ ^[0-9]+$ ]] || num=0
      prefix="$(render_template "$scheme" "$num")" || {
        echo "un-migratable: custom template render failed" >&2; return 1; }
      ;;
    *)
      echo "un-migratable: unknown issue_id_prefix scheme \"$scheme\"" >&2
      return 1
      ;;
  esac
  if is_valid_id "$prefix" 2>/dev/null; then
    printf '%s\n' "$prefix"
  else
    echo "un-migratable: re-derived prefix \"$prefix\" failed id validation" >&2
    return 1
  fi
}

# cmd_path <kind> <args...>  |  cmd_path <key>
#   Two forms, dispatched by arity:
#     Single-arg form (D3): `path <key>` returns the configured path for a
#     jimconf key (delegates to jimconf.sh, regardless of disk existence).
#     KINDS∩KEYS overlaps are `debug` and `blueprint`: `path debug`
#     / `path blueprint` (no further args) take the key form and return the
#     configured `debug` directory / project-tier map path respectively.
#     Multi-arg form: `path <kind> <args...>` resolves a derived artifact path:
#       spec     <group> <id> <name>
#       plan     <group> <id> <name>
#       research <group> <id> <name>
#       debug      <topic>
#       brainstorm <topic>
#       blueprint  <group>            (reserved 000-blueprint/spec.md slot)
cmd_path() {
  local first="${1:-}"
  if [[ -z "$first" ]]; then
    echo "error: 'path' requires a kind or key argument" >&2
    return 2
  fi
  if [[ $# -eq 1 ]]; then
    # Single-arg form: caller wants the configured path for the named key.
    # Translate kind→cli_key for the 'issue' kind whose jimconf key is
    # 'issues' (singular kind → plural collection). Mirrors the existing
    # multi-arg path-issue handler; analogous to path debug (no topic).
    if [[ "$first" == "issue" ]]; then
      jimconf_get issues
    else
      jimconf_get "$first"
    fi
    return $?
  fi
  local kind="$first"
  shift
  if ! is_kind "$kind"; then
    echo "error: unknown kind '$kind' (valid: ${KINDS[*]})" >&2
    return 1
  fi
  case "$kind" in
    spec|plan|research)
      # Two arities, one per identity state a bound spec can hold. The numeric
      # form composes {id}-{name}; the two-argument form takes a provisional
      # token as the WHOLE basename, because that is what the allocator issues —
      # composing a second slug onto it would name a directory that does not
      # exist. Every token clears its boundary here, the way the blueprint and
      # issue arms do, so this helper cannot hand back a path built from a token
      # the rest of the flow would refuse.
      local group="${1:-}" id="${2:-}" name="${3:-}"
      if [[ -z "$group" || -z "$id" ]]; then
        echo "error: 'path $kind' requires <group> <id> <name>" \
             "(or <group> <provisional-token>)" >&2
        return 2
      fi
      is_valid_slug "$group" || return 1
      local base
      if [[ -z "$name" ]]; then
        if ! is_prov_basename "$id"; then
          echo "error: path $kind target rejected — '$id' (the 2-argument form takes" \
               "a provisional token only; use <id> <name> for a real ordinal)" >&2
          return 1
        fi
        base="$id"
      else
        if [[ ! "$id" =~ ^[0-9]{3,15}$ ]]; then
          echo "error: path $kind id rejected — '$id' (allowed: ^[0-9]{3,15}\$)" >&2
          return 1
        fi
        is_valid_slug "$name" || return 1
        base="$id-$name"
      fi
      local specs_root
      specs_root="$(jimconf_get specs)"
      printf '%s/%s/%s/%s.md\n' "$specs_root" "$group" "$base" "$kind"
      ;;
    blueprint)
      # Reserved per-group slot: {specs}/<group>/000-blueprint/spec.md. The
      # group is validated through the single is_valid_slug boundary so a
      # malformed group cannot direct a write outside the specs tree. No
      # id/name — the slot is fixed, not allocated.
      local group="${1:-}"
      if [[ -z "$group" ]]; then
        echo "error: 'path blueprint' requires <group>" >&2
        return 2
      fi
      is_valid_slug "$group" || return 1
      local specs_root
      specs_root="$(jimconf_get specs)"
      printf '%s/%s/%s/spec.md\n' "$specs_root" "$group" "$BLUEPRINT_DIRNAME"
      ;;
    issue)
      local slug="${1:-}"
      if [[ -z "$slug" ]]; then
        echo "error: 'path issue' requires <slug>" >&2
        return 2
      fi
      is_valid_id "$slug" || return 1
      local dir
      dir="$(jimconf_get issues)"
      dir="${dir%/}"
      printf '%s/%s.md\n' "$dir" "$slug"
      ;;
    debug|brainstorm)
      local topic="${1:-}"
      if [[ -z "$topic" ]]; then
        echo "error: 'path $kind' requires <topic>" >&2
        return 2
      fi
      local slug
      slug="$(normalize_slug "$topic")" || return 1
      local cli_key dir today candidate suffix
      if [[ "$kind" == "debug" ]]; then
        cli_key="debug"
      else
        cli_key="brainstorms"
      fi
      dir="$(jimconf_get "$cli_key")"
      today="$(today_yyyymmdd)"
      candidate="$dir/$today-$slug.md"
      if [[ ! -e "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
      suffix=2
      while :; do
        candidate="$dir/$today-$slug-$suffix.md"
        if [[ ! -e "$candidate" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
        suffix=$(( suffix + 1 ))
      done
      ;;
  esac
}

# cmd_glob <kind> [<group>]
#   List existing canonical artifacts under the configured directory:
#     glob specs [<group>]   — every <specs>/<group>/<id>-<name> dir
#                              (filtered to one group when <group> given)
#     glob debug             — every file under <debug>/
#     glob brainstorms       — every file under <brainstorms>/
cmd_glob() {
  local kind="${1:-}"
  if [[ -z "$kind" ]]; then
    echo "error: 'glob' requires a kind argument (specs|debug|brainstorms)" >&2
    return 2
  fi
  case "$kind" in
    specs)
      local group="${2:-}"
      local specs_root
      specs_root="$(jimconf_get specs)"
      [[ -d "$specs_root" ]] || return 0
      if [[ -n "$group" ]]; then
        local group_dir="$specs_root/$group"
        [[ -d "$group_dir" ]] || return 0
        local entry
        for entry in "$group_dir"/*/; do
          [[ -d "$entry" ]] || continue
          printf '%s\n' "${entry%/}"
        done | sort
      else
        local g_entry s_entry
        for g_entry in "$specs_root"/*/; do
          [[ -d "$g_entry" ]] || continue
          for s_entry in "$g_entry"*/; do
            [[ -d "$s_entry" ]] || continue
            printf '%s\n' "${s_entry%/}"
          done
        done | sort
      fi
      ;;
    debug)
      local debug_dir
      debug_dir="$(jimconf_get debug)"
      [[ -d "$debug_dir" ]] || return 0
      local f
      for f in "$debug_dir"/*; do
        [[ -e "$f" ]] || continue
        [[ -f "$f" ]] || continue
        printf '%s\n' "$f"
      done | sort
      ;;
    brainstorms)
      local brain_dir
      brain_dir="$(jimconf_get brainstorms)"
      [[ -d "$brain_dir" ]] || return 0
      local f
      for f in "$brain_dir"/*; do
        [[ -e "$f" ]] || continue
        [[ -f "$f" ]] || continue
        printf '%s\n' "$f"
      done | sort
      ;;
    *)
      echo "error: unknown glob kind '$kind' (valid: specs debug brainstorms)" >&2
      return 1
      ;;
  esac
}

cmd_kinds() {
  local k
  for k in "${KINDS[@]}"; do
    printf '%s\n' "$k"
  done
}

# cmd_blueprint_dirname
#   Echo the reserved per-group blueprint directory name. Lets sibling scripts
#   single-source the literal instead of hand-composing it. No I/O.
cmd_blueprint_dirname() {
  printf '%s\n' "$BLUEPRINT_DIRNAME"
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

usage() {
  cat >&2 <<'USAGE'
usage:
  jimfile.sh exists <path>                      "yes" or "no"
  jimfile.sh get <key>                          configured path if it exists,
                                                else literal "NOT_FOUND"
  jimfile.sh slug <topic>                       kebab-case slug
  jimfile.sh date                               today as YYYYMMDD
  jimfile.sh now                                now as YYYY-MM-DDThh:mm:ssZ (UTC)
  jimfile.sh next-id <group>                    next zero-padded spec id
  jimfile.sh mv-spec <group> <id> <new-name>    rename {id}-* spec dir to {id}-{new-name}
  jimfile.sh mv-spec-id <group> <old-basename> <new-id> <name>
                                                rename a spec dir onto a different id
  jimfile.sh spec-ordinal-holder <group> <ordinal> [--exclude <basename>]
                                                dir holding <ordinal> numerically;
                                                exit 0 held · 1 free · 2 bad input
  jimfile.sh next-num issue                     next display ordinal (max+1)
  jimfile.sh path <key>                         configured path for <key>
  jimfile.sh path spec      <group> <id> <name>
  jimfile.sh path plan      <group> <id> <name>
  jimfile.sh path research  <group> <id> <name>
  jimfile.sh path debug     <topic>             collision-resolved
  jimfile.sh path brainstorm <topic>            collision-resolved
  jimfile.sh glob specs [<group>]               one path per line
  jimfile.sh glob debug                         one path per line
  jimfile.sh glob brainstorms                   one path per line
  jimfile.sh kinds                              valid kinds, no I/O
  jimfile.sh blueprint-dirname                  reserved group blueprint dir name
  jimfile.sh valid-id <id>                      exit 0 if id passes is_valid_id
  jimfile.sh valid-relpath <path>               exit 0 iff safe repo-relative
                                                (no abs, no '..' segment)
  jimfile.sh prefix-from <created> <num>        re-derive active prefix
  jimfile.sh -c <path> <subcmd>                 forward -c to jimconf.sh
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
    exists)  cmd_exists  "$@" ;;
    get)     cmd_get     "$@" ;;
    slug)    cmd_slug    "$@" ;;
    date)    cmd_date ;;
    now)     cmd_now ;;
    next-id)  cmd_next_id  "$@" ;;
    next-num) cmd_next_num "$@" ;;
    mv-spec)  cmd_mv_spec  "$@" ;;
    mv-spec-id) cmd_mv_spec_id "$@" ;;
    spec-ordinal-holder) cmd_spec_ordinal_holder "$@" ;;
    path)    cmd_path    "$@" ;;
    glob)    cmd_glob    "$@" ;;
    kinds)   cmd_kinds ;;
    blueprint-dirname) cmd_blueprint_dirname ;;
    valid-id) cmd_valid_id "$@" ;;
    valid-relpath) cmd_valid_relpath "$@" ;;
    prefix-from) cmd_prefix_from "$@" ;;
    *)
      echo "error: unknown subcommand '$subcmd'" >&2
      usage
      return 2
      ;;
  esac
}

main "$@"

# ─── Section: Implementation notes ───────────────────────────────────────────
#
# ## Implementation notes
#
# 1. Slug pipeline is the security boundary. Path traversal ('../../etc/passwd')
#    is naturally safe because non-alnum collapses to '-' and leading '-' is
#    stripped — but the explicit reject of '.' and '..' literals plus the
#    empty-result reject is defense in depth. Any future change to the pipeline
#    must keep these guarantees.
#
# 2. jimconf composition uses BASH_SOURCE, not ${CLAUDE_PLUGIN_ROOT}. The
#    relative resolution holds in any layout where skills/file/scripts/ and
#    skills/conf/scripts/ keep their relative position — including .agents/
#    or other cross-agent install scopes. Claude-Code-only substitutions
#    stay at skill-side call sites.
#
# 3. next-id parses the directory basename's leading numeric prefix only.
#    Non-numeric prefixes (e.g., a stray "draft-foo/") are skipped — they
#    cannot collide with the 3-digit sequence.
#
# 4. Collision resolution for date-prefixed paths is read-only. The script
#    never creates the directory or the resolved file. The calling skill is
#    responsible for mkdir -p before writing. Spec OoS line: "missing target
#    directory — return path anyway."
#
# 5. set -e is intentionally OFF; the dispatch wraps each handler so that a
#    handler returning non-zero propagates as the script's exit code without
#    short-circuiting the cleanup code paths (there are none today, but the
#    discipline mirrors jimconf.sh).
#
# 6. The script never sources any user-supplied file. jimconf.toml is parsed
#    by jimconf.sh via grep+sed. User input flows in only as CLI arguments
#    and is treated as data.
#
