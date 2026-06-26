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
#      inside an existing config silently fall through to defaults).
#   2  Malformed invocation (missing argument, unknown subcommand).
#

set -uo pipefail

# ─── Section: Constants ──────────────────────────────────────────────────────

# Valid CLI keys (short names). `get <key>`, `keys`, and `list` use these.
readonly KEYS=(specs architecture vision roadmap brainstorms debug pre_commit pre_completion require_pre_commit require_pre_completion auto_arch_feedback require_security auto_security require_review auto_review review_depth review_model review_fanout_cap require_security_loop require_security_loop_sev auto_security_loop_limit security_adhoc issues issue_capture auto_issue_file issue_list_group issue_list_sort issue_list_cols issue_list_order issue_list_closed issue_id_prefix issue_id_project)

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
    pre_commit)             echo "./pre-commit.sh" ;;
    pre_completion)         echo "./pre-completion.sh" ;;
    require_pre_commit)     echo "false" ;;
    require_pre_completion) echo "false" ;;
    auto_arch_feedback)     echo "false" ;;
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
parse_value() {
  local file="$1" key="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  grep -E "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"" "$file" 2>/dev/null \
    | head -n 1 \
    | sed -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/"
}

# resolve <config-file> <cli-key>
#   Print the resolved value for <cli-key>: configured override if present,
#   otherwise the documented default.
resolve() {
  local file="$1" cli_key="$2"
  local toml_key
  if [[ "$cli_key" == require_* || "$cli_key" == auto_* || "$cli_key" == "issue_capture" || "$cli_key" == issue_list_* || "$cli_key" == issue_id_* || "$cli_key" == review_* ]]; then
    # Bare-name keys (no _path suffix). The auto_*/require_* prefixes signal
    # automated/mandatory behaviors; issue_capture is a human-in-the-loop
    # feature flag (spec 018 DD #1); the issue_list_* family configures the
    # default `/jim:issue list` view (group/sort/cols/order plus the
    # issue_list_closed visibility toggle) and is not a path; the review_*
    # family (review_depth / review_model / review_fanout_cap, spec 027) are
    # bare behavior selectors. All resolve to their bare TOML name.
    toml_key="$cli_key"
  else
    toml_key="${cli_key}_path"
  fi
  local value=""
  if [[ -f "$file" ]]; then
    value="$(parse_value "$file" "$toml_key")"
  fi
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

# ─── Section: Subcommand handlers ────────────────────────────────────────────

cmd_get() {
  local file="$1" cli_key="${2:-}"
  if [[ -z "$cli_key" ]]; then
    echo "error: 'get' requires a key argument" >&2
    return 2
  fi
  if ! default_for "$cli_key" >/dev/null; then
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
  local config_file="./jimconf.toml"
  if [[ "${1:-}" == "-c" ]]; then
    if [[ -z "${2:-}" ]]; then
      echo "error: -c requires a path argument" >&2
      return 2
    fi
    config_file="$2"
    shift 2
  fi
  local subcmd="${1:-}"
  if [[ -z "$subcmd" ]]; then
    usage
    return 2
  fi
  shift
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
#
# 3. Never source. The file is data, not code. `source jimconf.toml`
#    would execute arbitrary bash from a project file; the security
#    model is explicitly that user config never executes.
#
# 4. Default-PWD lookup is non-recursive. The script reads
#    `./jimconf.toml` relative to PWD only — no walk-up. Users are
#    expected to launch `claude` at the project root. Walking up would
#    conflict with Claude Code's "trust this folder" sandbox boundary.
#
# 5. -c with a missing path is silent. Same behavior as a missing
#    default file. The spec's "no strict mode" decision applies.
#
# 6. cmd_path emits the absolute path without a trailing newline; the
#    empty branch emits nothing at all. Lets callers distinguish "active
#    config" from "no config" with `[ -z "$(jimconf.sh path)" ]`.
