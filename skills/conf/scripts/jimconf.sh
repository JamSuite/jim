#!/usr/bin/env bash
#
# skills/conf/scripts/jimconf.sh — jim's project-config path resolver.
#
# PURPOSE
#   Resolve project-level path overrides for jim's strategic and SDLC
#   documents. Skills consume this via Claude Code's `!`-injection
#   primitive so the resolved string lands in the prompt before the LLM
#   reads it. The /jim:conf user-facing skill is a thin wrapper.
#
# CLI SUMMARY
#   bash jimconf.sh get <key>             Resolve <key> via ./jimconf.toml
#                                         (or default if absent).
#   bash jimconf.sh list                  Print every key with resolved value
#                                         (one KEY=VALUE pair per line).
#   bash jimconf.sh path                  Absolute path of the active config,
#                                         or empty if none.
#   bash jimconf.sh keys                  Print the valid CLI key list, no I/O.
#   bash jimconf.sh -c <path> <subcmd>    Use <path> instead of ./jimconf.toml.
#                                         Falls through to defaults if the
#                                         path does not exist.
#
#   <subcmd> ∈ { get, list, path }
#
# CONVENTION
#   Production skills do NOT pass -c. The flag exists for tests and
#   ad-hoc inspection (e.g., `/jim:conf -c jimconf.toml.example list` to
#   view the shipped defaults).
#
# EXIT CODES
#   0  Success.
#   1  Unknown key (only `get <unknown_key>` triggers this; missing keys
#      inside an existing config silently fall through to defaults), or a
#      resolution that failed rather than being absent: a config that exists
#      but cannot be read, a key written in a value form this grammar does not
#      read, or a run started below a project root whose config it would
#      otherwise ignore in silence.
#   2  Malformed invocation (missing argument, unknown subcommand).
#

set -uo pipefail
# LC_ALL=C keeps the regex character classes below locale-independent. The
# dynamic-suffix key gate is an accept/reject boundary, and a collation range
# must not admit under one locale what it is written to refuse under another.
export LC_ALL=C

# ─── Section: Constants ──────────────────────────────────────────────────────

# Valid CLI keys (short names). `get <key>`, `keys`, and `list` use these.
readonly KEYS=(specs architecture vision roadmap brainstorms debug blueprint pre_commit pre_completion require_pre_commit require_pre_completion auto_arch_feedback auto_blueprint require_blueprint blueprint_regen_threshold group_axis group_territory require_security auto_security require_review auto_review review_depth review_model review_fanout_cap require_security_loop require_security_loop_sev auto_security_loop_limit security_adhoc issues issue_capture auto_issue_file issue_list_group issue_list_sort issue_list_cols issue_list_order issue_list_closed issue_id_prefix issue_id_project issue_placement issue_placement_ack verify_appetite verify_fanout_cap verify_model verify_registry_timeout require_health auto_health health_threshold_cycles health_threshold_fanin health_threshold_uncovered health_threshold_faces_max health_threshold_breaking_runs spec_migration id_coordination_mechanism id_coordination_branch id_coordination_unreachable)

# default_for <cli-key>
#   Print the documented default for <cli-key>, or return 1 if the key is
#   not in the valid set. Used both as the fallback when no override is
#   present and as the validity check for `get <key>`.
default_for() {
  case "$1" in
    specs)        echo "docs/specs" ;;
    architecture) echo "ARCHITECTURE.md" ;;
    vision)       echo "VISION.md" ;;
    roadmap)      echo "ROADMAP.md" ;;
    brainstorms)  echo "docs/brainstorms" ;;
    debug)        echo "docs/debug" ;;
    blueprint)    echo "BLUEPRINT.md" ;;
    pre_commit)             echo "./pre-commit.sh" ;;
    pre_completion)         echo "./pre-completion.sh" ;;
    require_pre_commit)     echo "false" ;;
    require_pre_completion) echo "false" ;;
    auto_arch_feedback)     echo "false" ;;
    auto_blueprint)         echo "false" ;;
    require_blueprint)      echo "false" ;;
    blueprint_regen_threshold)   echo "0" ;;
    group_axis)                  echo "vertical" ;;
    group_territory)             echo "declared-paths" ;;
    require_security)            echo "false" ;;
    auto_security)               echo "false" ;;
    require_review)              echo "false" ;;
    auto_review)                 echo "false" ;;
    review_depth)                echo "thorough" ;;
    review_model)                echo "inherit" ;;
    review_fanout_cap)           echo "10" ;;
    require_security_loop)       echo "false" ;;
    require_security_loop_sev)   echo "critical" ;;
    auto_security_loop_limit)    echo "5" ;;
    security_adhoc)              echo "docs/security" ;;
    issues)                      echo "./docs/issues/" ;;
    issue_capture)               echo "true" ;;
    auto_issue_file)             echo "false" ;;
    issue_list_group)            echo "status" ;;
    issue_list_sort)             echo "date" ;;
    issue_list_cols)             echo "num,date,priority,title" ;;
    issue_list_order)            echo "desc" ;;
    issue_list_closed)           echo "false" ;;
    issue_id_prefix)             echo "date" ;;
    issue_id_project)            echo "" ;;
    issue_placement)             echo "branch" ;;
    issue_placement_ack)         echo "false" ;;
    verify_appetite)             echo "low" ;;
    verify_fanout_cap)           echo "10" ;;
    verify_model)                echo "inherit" ;;
    verify_registry_timeout)     echo "120" ;;
    require_health)              echo "false" ;;
    auto_health)                 echo "false" ;;
    health_threshold_cycles)        echo "0" ;;
    health_threshold_fanin)         echo "0" ;;
    health_threshold_uncovered)     echo "0" ;;
    health_threshold_faces_max)     echo "0" ;;
    health_threshold_breaking_runs) echo "0" ;;
    spec_migration)                 echo "rewrite" ;;
    id_coordination_mechanism)      echo "git" ;;
    id_coordination_branch)         echo "jim/registry" ;;
    id_coordination_unreachable)    echo "fail" ;;
    *) return 1 ;;
  esac
}

# is_dynamic_family <cli-key>
#   Return 0 iff <cli-key> is a dynamic-suffix key — verify_command_<name> (the
#   verify operator registry), verify_appetite_<group> (per-group appetite
#   override), or deps_command_<name> (the partition extractor registry, spec
#   038) — recognized by prefix + a non-empty suffix, regardless of whether the
#   suffix is slug-valid. Suffix charset validation happens in resolve() (a bad
#   suffix resolves empty, never a TOML lookup — spec 035 Finding 1); this check
#   only decides that the key SHAPE is a known dynamic family so `get` treats it
#   as valid rather than unknown.
is_dynamic_family() {
  case "$1" in
    verify_command_?*|verify_appetite_?*|deps_command_?*) return 0 ;;
    *) return 1 ;;
  esac
}

# ─── Section: Parsing ────────────────────────────────────────────────────────

# parse_value <config-file> <toml-key>
#   Read the value of `<toml-key> = "..."` from <config-file>. Print the
#   raw inner string (no quotes) on stdout, or nothing if the key is
#   missing or the file is unreadable.
#
#   - Top-level scalar lines only — `KEY = "value"` with arbitrary leading
#     whitespace.
#   - Comments (#), blank lines, and nested-table lines are ignored.
#   - First match wins for duplicate keys.
#   - Pure grep+sed; never `source`s the file.
#   - A config that is genuinely absent means "no override", and resolving to
#     the documented default is the zero-config path. Anything else is a
#     resolver *failure* and says so: a directory, a dangling symlink, or a file
#     this process may not read all produced empty output before, which every
#     caller reads as an unset key. On `issue_placement` the fabricated default
#     is "do not centralize", so a team's collection silently stops being
#     centralized on an infrastructure fault — and the placement gate, hardened
#     to refuse exactly that, never sees it.
parse_value() {
  local file="$1" key="$2"
  if [[ -L "$file" && ! -e "$file" ]]; then
    echo "error: config path '$file' is a dangling symlink" >&2
    return 1
  fi
  if [[ ! -e "$file" ]]; then
    return 0
  fi
  if [[ ! -f "$file" ]]; then
    echo "error: config path '$file' is not a regular file" >&2
    return 1
  fi
  if [[ ! -r "$file" ]]; then
    echo "error: config file '$file' exists but could not be read" >&2
    return 1
  fi
  # A key written in a form this grammar does not read is a resolver failure,
  # not an unset key. Only `KEY = "value"` is recognized, so `key = 'v'` and
  # `key = 3` — both legal TOML — would otherwise resolve to the documented
  # default with no message: the same fabricated-default class an unreadable
  # file is, and indistinguishable from a real value at every caller.
  #
  # Refused rather than parsed. Widening the grammar means a bare `true`
  # resolves to a value every consumer compares against the *string* "true",
  # trading a silent default for a silent type mismatch. Refusing states the
  # problem where the user can fix it, and the remedy is to add quotes.
  #
  # Judged on the FIRST line naming the key, which is the one first-match-wins
  # would have taken.
  local first=""
  first="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | head -n 1)"
  if [[ -n "$first" ]] \
     && ! printf '%s\n' "$first" \
        | grep -qE "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\""; then
    echo "error: config key '$key' in '$file' is not a double-quoted string;" \
         "jim reads only KEY = \"value\"" >&2
    return 1
  fi
  # A key that is simply not in the file is the "no override" case, not a
  # failure: grep's rc 1 for "no match" must not reach the caller as one, or
  # every unset key would refuse. The file-level failures above are the only
  # non-zero returns this function makes.
  local out=""
  out="$(grep -E "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"" "$file" 2>/dev/null \
    | head -n 1 \
    | sed -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/")" || true
  printf '%s\n' "$out"
  return 0
}

# resolve <config-file> <cli-key>
#   Print the resolved value for <cli-key>: configured override if present,
#   otherwise the documented default.
resolve() {
  local file="$1" cli_key="$2"
  local toml_key
  # verify_command_<name> / verify_appetite_<group> / deps_command_<name>:
  # dynamic-suffix keys. The suffix is validated against the slug charset BEFORE
  # any lookup, so a map/blueprint-recorded name can never inject regex
  # metacharacters into the grep pattern parse_value builds (spec 035 security
  # Finding 1). A non-conforming suffix resolves empty (inert) — never a TOML
  # read. There is no static default: unset means unconfigured (the verify /
  # partition registries) or no-override (group appetite), which the consuming
  # skill interprets. The bare fixed key `verify_appetite` lacks the trailing
  # `_`, so it does not match these globs and falls through to the normal
  # bare-name path below.
  case "$cli_key" in
    verify_command_*|verify_appetite_*|deps_command_*)
      local suffix
      case "$cli_key" in
        verify_command_*)  suffix="${cli_key#verify_command_}" ;;
        verify_appetite_*) suffix="${cli_key#verify_appetite_}" ;;
        deps_command_*)    suffix="${cli_key#deps_command_}" ;;
      esac
      local dyn_value=""
      if [[ "$suffix" =~ ^[a-z0-9][a-z0-9-]*$ && -f "$file" ]]; then
        dyn_value="$(parse_value "$file" "$cli_key")"
        dyn_value="$(printf '%s' "$dyn_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      fi
      printf '%s\n' "$dyn_value"
      return 0
      ;;
  esac
  if [[ "$cli_key" == require_* || "$cli_key" == auto_* || "$cli_key" == "issue_capture" || "$cli_key" == issue_list_* || "$cli_key" == issue_id_* || "$cli_key" == "issue_placement" || "$cli_key" == "issue_placement_ack" || "$cli_key" == review_* || "$cli_key" == group_* || "$cli_key" == verify_* || "$cli_key" == health_* || "$cli_key" == "blueprint_regen_threshold" || "$cli_key" == "spec_migration" || "$cli_key" == id_coordination_* ]]; then
    # Bare-name keys (no _path suffix). The auto_*/require_* prefixes signal
    # automated/mandatory behaviors; issue_capture is a human-in-the-loop
    # feature flag (spec 018 DD #1); the issue_list_* family configures the
    # default `/jim:issue list` view (group/sort/cols/order plus the
    # issue_list_closed visibility toggle) and is not a path; issue_placement
    # names the branch the issue collection lives on (the reserved sentinel
    # `branch` meaning the current working branch) and issue_placement_ack is
    # its auto-file acknowledgement flag — both bare, neither a path; the review_*
    # family (review_depth / review_model / review_fanout_cap, spec 027) are
    # bare behavior selectors; the group_* family (group_axis /
    # group_territory, spec 033) are bare partition-doctrine knobs;
    # blueprint_regen_threshold (spec 032) is a bare-name integer knob; the
    # verify_* family (verify_appetite / verify_fanout_cap / verify_model /
    # verify_registry_timeout, spec 035) are bare verification knobs (the
    # dynamic verify_command_* / verify_appetite_* suffixes are handled above,
    # before this point); the health_* family (require_health / auto_health via
    # the require_/auto_ arms, plus the five bare-name health_threshold_* integer
    # knobs, spec 044) are the partition-health sensor knobs; spec_migration
    # (spec 046) is the bare identity-on-move preference knob
    # (rewrite|forward|immutable); the id_coordination_* family (mechanism /
    # branch / unreachable) are the bare ID-allocator coordination knobs read
    # from the current branch so a team's scheme is versioned. All resolve to
    # their bare TOML name.
    toml_key="$cli_key"
  else
    toml_key="${cli_key}_path"
  fi
  # parse_value decides for itself what an absent file means, and reports a
  # resolver failure rather than returning empty — so its status is forwarded
  # instead of being flattened into "no override".
  local value=""
  value="$(parse_value "$file" "$toml_key")" || return 1
  # Trim leading/trailing whitespace; treat all-whitespace as empty so
  # configured-empty values fall through to the documented default
  # (Finding 13 / spec 017 — defense against silent empty-path writes).
  value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [[ -z "$value" ]]; then
    default_for "$cli_key"
  else
    printf '%s\n' "$value"
  fi
}

# nearest_ignored_config
#   Print the path of a jimconf.toml that exists ABOVE the current directory
#   inside this repository, or nothing. Reached only when ./jimconf.toml is
#   absent, and used only to refuse: the file is located, never read.
#
#   Locating rather than honouring is the whole point. Config values reach
#   bash — pre_commit and pre_completion name scripts jim runs, and the
#   deps_command_ / verify_command_ families are command strings run verbatim —
#   so reading a config from above the directory the session was started in
#   would run a command from outside that boundary. jim reads ./jimconf.toml
#   and no other; this is what stops a run started elsewhere resolving every
#   key to a documented default with nothing said.
#
#   The repository is the bound. The walk stops at the directory holding .git
#   and reports nothing at all when it finds none, so a config belonging to an
#   unrelated project — a home directory's, say — is never named. Pure path
#   arithmetic and stats; no forks.
nearest_ignored_config() {
  local d="$PWD" found=""
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -e "$d/.git" ]] && { printf '%s' "$found"; return 0; }
    d="${d%/*}"; [[ -z "$d" ]] && d="/"
    [[ -z "$found" && -f "$d/jimconf.toml" ]] && found="$d/jimconf.toml"
  done
  return 0
}

# ─── Section: Subcommand handlers ────────────────────────────────────────────

cmd_get() {
  local file="$1" cli_key="${2:-}"
  if [[ -z "$cli_key" ]]; then
    echo "error: 'get' requires a key argument" >&2
    return 2
  fi
  if ! default_for "$cli_key" >/dev/null && ! is_dynamic_family "$cli_key"; then
    echo "error: unknown key '$cli_key' (valid: ${KEYS[*]})" >&2
    return 1
  fi
  resolve "$file" "$cli_key"
}

cmd_list() {
  local file="$1" key value
  for key in "${KEYS[@]}"; do
    value="$(resolve "$file" "$key")"
    printf '%s=%s\n' "$key" "$value"
  done
}

cmd_path() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local dir base
    dir="$(cd "$(dirname "$file")" && pwd)"
    base="$(basename "$file")"
    printf '%s/%s' "$dir" "$base"
  fi
}

cmd_keys() {
  local key
  for key in "${KEYS[@]}"; do
    printf '%s\n' "$key"
  done
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

usage() {
  cat >&2 <<'USAGE'
usage:
  jimconf.sh get <key>             resolve <key> via ./jimconf.toml or default
  jimconf.sh list                  list all keys as KEY=VALUE
  jimconf.sh path                  absolute path of active config, or empty
  jimconf.sh keys                  print valid CLI keys, no I/O
  jimconf.sh -c <path> <subcmd>    use <path> instead of ./jimconf.toml
USAGE
}

main() {
  local config_file="./jimconf.toml" explicit=0
  if [[ "${1:-}" == "-c" ]]; then
    if [[ -z "${2:-}" ]]; then
      echo "error: -c requires a path argument" >&2
      return 2
    fi
    config_file="$2"
    explicit=1
    shift 2
  fi
  local subcmd="${1:-}"
  if [[ -z "$subcmd" ]]; then
    usage
    return 2
  fi
  shift
  # A run started somewhere other than the project root reads ./jimconf.toml,
  # finds nothing, and resolves every key to its documented default — a value
  # the caller cannot tell from a configured one. Refuse instead, naming where
  # the config actually is. Scoped to the two resolving verbs: `path` answers
  # "is there an active config here" and has to stay able to say no, and `keys`
  # does no I/O. An explicit -c named a file, so it is left alone.
  if (( explicit == 0 )) && [[ "$subcmd" == "get" || "$subcmd" == "list" ]] \
     && [[ ! -e "$config_file" ]]; then
    local ignored
    ignored="$(nearest_ignored_config)"
    if [[ -n "$ignored" ]]; then
      echo "error: no ./jimconf.toml here, but one exists at '$ignored'." \
           "jim reads ./jimconf.toml only — run from the project root." >&2
      return 1
    fi
  fi
  case "$subcmd" in
    get)  cmd_get  "$config_file" "$@" ;;
    list) cmd_list "$config_file" ;;
    path) cmd_path "$config_file" ;;
    keys) cmd_keys ;;
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
# 1. Parse strategy. `grep -E ... | head -n1 | sed -E ...` — first match
#    wins on duplicates. The pattern matches only flat top-level lines
#    (`KEY = "value"` with arbitrary leading whitespace). Nested tables
#    and arrays are NOT supported; they are silently ignored.
#
# 2. Quoting. Only double-quoted scalar values are recognized. Bare
#    values and single-quoted values are intentionally not parsed —
#    keeps the grammar simple and matches the documented config format.
#    They are, however, REFUSED rather than skipped: both are legal TOML,
#    so skipping them resolved the key to its documented default at rc 0,
#    which the caller cannot tell from a configured value. Widening the
#    grammar instead would let a bare `true` resolve to a value every
#    consumer compares against the string "true" — a silent type mismatch
#    in place of a silent default.
#
# 3. Never source. The file is data, not code. `source jimconf.toml`
#    would execute arbitrary bash from a project file; the security
#    model is explicitly that user config never executes.
#
# 4. Default-PWD lookup is non-recursive. The script reads
#    `./jimconf.toml` relative to PWD only — no walk-up. Users are
#    expected to launch `claude` at the project root. Walking up would
#    conflict with Claude Code's "trust this folder" sandbox boundary,
#    and the conflict is sharper than mere reading: pre_commit,
#    pre_completion, deps_command_* and verify_command_* are values jim
#    hands to bash, so honouring a config from above that boundary runs a
#    command from outside it.
#
#    What is NOT tolerated is doing this silently. `get` and `list`
#    locate — never read — a jimconf.toml above PWD within the same
#    repository, and refuse rather than resolving every key to its
#    documented default. Zero-config is untouched: no config anywhere
#    still resolves to defaults at rc 0.
#
# 5. -c with a missing path is silent. Same behavior as a missing
#    default file. The spec's "no strict mode" decision applies.
#
# 6. cmd_path emits the absolute path without a trailing newline; the
#    empty branch emits nothing at all. Lets callers distinguish "active
#    config" from "no config" with `[ -z "$(jimconf.sh path)" ]`.
