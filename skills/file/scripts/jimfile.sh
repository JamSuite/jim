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
#   bash jimfile.sh -c <path> <subcmd>                use <path> as jimconf.toml
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
# i/I). Spec 017 security.md Finding 11.
export LC_ALL=C

# ─── Section: Globals ────────────────────────────────────────────────────────

# Path to the sibling jimconf.sh. BASH_SOURCE-relative so the composition
# travels with the plugin tree (skills/file/scripts/ → skills/conf/scripts/).
JIMCONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../conf/scripts" && pwd)/jimconf.sh"

# Valid artifact kinds. Drives `path <kind>` validation and `kinds` output.
readonly KINDS=(spec plan research debug brainstorm issue)

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

# is_valid_slug <slug>
#   AC-C7 validation: slug must be lowercase alnum + dash only, alnum-start,
#   non-empty. Rejects path separators (/, \), '..', leading dot, control
#   characters, and any other non-conforming input. Errors go to stderr;
#   stdout stays empty. Spec 017 security.md Finding 1 + Finding 2.
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

# ─── Section: Subcommand handlers ────────────────────────────────────────────

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

cmd_next_id() {
  local group="${1:-}"
  if [[ -z "$group" ]]; then
    echo "error: 'next-id' requires a group argument" >&2
    return 2
  fi
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
  printf '%03d\n' $(( max + 1 ))
}

# cmd_path <kind> <args...>  |  cmd_path <key>
#   Two forms, dispatched by arity:
#     Single-arg form (D3): `path <key>` returns the configured path for a
#     jimconf key (delegates to jimconf.sh, regardless of disk existence).
#     The only KINDS∩KEYS overlap is `debug`: `path debug` (no further args)
#     takes the key form and returns the configured `debug` directory.
#     Multi-arg form: `path <kind> <args...>` resolves a derived artifact path:
#       spec     <group> <id> <name>
#       plan     <group> <id> <name>
#       research <group> <id> <name>
#       debug      <topic>
#       brainstorm <topic>
cmd_path() {
  local first="${1:-}"
  if [[ -z "$first" ]]; then
    echo "error: 'path' requires a kind or key argument" >&2
    return 2
  fi
  if [[ $# -eq 1 ]]; then
    jimconf_get "$first"
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
      local group="${1:-}" id="${2:-}" name="${3:-}"
      if [[ -z "$group" || -z "$id" || -z "$name" ]]; then
        echo "error: 'path $kind' requires <group> <id> <name>" >&2
        return 2
      fi
      local specs_root
      specs_root="$(jimconf_get specs)"
      printf '%s/%s/%s-%s/%s.md\n' "$specs_root" "$group" "$id" "$name" "$kind"
      ;;
    issue)
      local slug="${1:-}"
      if [[ -z "$slug" ]]; then
        echo "error: 'path issue' requires <slug>" >&2
        return 2
      fi
      is_valid_slug "$slug" || return 1
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

# ─── Section: Argument dispatch ──────────────────────────────────────────────

usage() {
  cat >&2 <<'USAGE'
usage:
  jimfile.sh exists <path>                      "yes" or "no"
  jimfile.sh get <key>                          configured path if it exists,
                                                else literal "NOT_FOUND"
  jimfile.sh slug <topic>                       kebab-case slug
  jimfile.sh date                               today as YYYYMMDD
  jimfile.sh next-id <group>                    next zero-padded spec id
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
    next-id) cmd_next_id "$@" ;;
    path)    cmd_path    "$@" ;;
    glob)    cmd_glob    "$@" ;;
    kinds)   cmd_kinds ;;
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
