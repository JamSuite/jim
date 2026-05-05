#!/usr/bin/env bash
#
# skills/meta-test/scripts/metatest.sh — Dispatcher for /jim:meta-test.
#
# WHAT THIS FILE DOES
#   Three subcommands for authoring and running jim's bash-script tests:
#     scaffold <name>           Create tests/<name>.sh from the asset template.
#     add <name> <case>         Append case_<name>_<case>() stub to tests/<name>.sh.
#     run [<name>]              Run all tests, or just one file.
#
# CONVENTIONS
#   - Production callers: <name> never starts with `-` (positional only).
#   - <name> must be a valid bash identifier: ^[a-zA-Z_][a-zA-Z0-9_]*$.
#     Hyphens, dots, slashes, leading digits, and empty are rejected — the
#     same regex protects the filesystem (no path traversal) and bash function
#     definitions (case_<name>_* must be a valid identifier).
#   - All file resolution (template path, runner path) uses BASH_SOURCE-relative
#     paths so the script works regardless of cwd or whether ${CLAUDE_PLUGIN_ROOT}
#     is defined (cross-agent portability — see ARCHITECTURE.md → Scripting Layer).
#   - PWD-relative `tests/<name>.sh` for read/write — assumes invocation from
#     the project root (matches jimconf.sh / jimfile.sh convention).
#   - Never source/eval user-supplied content.
#   - `set -uo pipefail`, NOT `set -e` (interferes with assertion-style checks).
#
# EXIT CODES
#   0   Success (or runner exit code propagated by `run`).
#   1   Validation/conflict error (bad name, file missing for add, file present for scaffold).
#   2   Add-case duplicate-case-name conflict, OR malformed invocation (missing/unknown subcommand).
#
# OUTPUT
#   Confirmation/diagnostic messages to stdout. Errors to stderr. Output is
#   sized to be readable when !-injected into a skill body.
#

set -uo pipefail

# ─── Section: Globals ────────────────────────────────────────────────────────

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$(cd "$HERE/../assets" && pwd)/test-file.sh.tmpl"
RUNNER="$HERE/run.sh"

# Bash-identifier-safe regex. See CONVENTIONS above.
NAME_REGEX='^[a-zA-Z_][a-zA-Z0-9_]*$'

# ─── Section: Validation ─────────────────────────────────────────────────────

# validate_name <name>
#   Print the name on stdout if valid; print error to stderr and exit 1 if not.
validate_name() {
  local name=$1
  if [[ -z "$name" ]]; then
    echo "Error: name is required and must be a valid bash identifier (^[a-zA-Z_][a-zA-Z0-9_]*$)." >&2
    exit 1
  fi
  if ! [[ "$name" =~ $NAME_REGEX ]]; then
    echo "Error: '$name' is not a valid name. Must match ^[a-zA-Z_][a-zA-Z0-9_]*\$ (no hyphens, dots, slashes, or leading digits)." >&2
    exit 1
  fi
  printf '%s' "$name"
}

# ─── Section: Scaffold action ────────────────────────────────────────────────

# scaffold <name>
#   Create tests/<name>.sh from the template, substituting __NAME__ and
#   __SCRIPT_PATH__. Refuse if tests/<name>.sh already exists.
scaffold_action() {
  local name=$1
  validate_name "$name" >/dev/null

  local target="tests/$name.sh"

  if [[ -e "$target" ]]; then
    echo "Error: $target already exists. Delete it or use 'add' to append a new case." >&2
    exit 1
  fi

  if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: scaffold template not found at $TEMPLATE" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target")"
  # Use pipe-as-delimiter for __SCRIPT_PATH__ (contains slashes); slash for __NAME__.
  sed -e "s/__NAME__/$name/g" \
      -e "s|__SCRIPT_PATH__|skills/CHANGEME/scripts/$name.sh|g" \
      "$TEMPLATE" > "$target"
  chmod +x "$target"

  echo "Scaffolded $target"
  echo "  - Header docblock cites skills/meta-test/scripts/testlib.sh conventions"
  echo "  - Source pattern uses BASH_SOURCE-relative resolution"
  echo "  - Invoker stub: run_$name ()"
  echo "  - Starter case: case_${name}_smoke ()"
  echo "  - Standalone-runnable tail (with explanatory comments)"
  echo "Next: edit $target to set SCRIPT_$name to your real script-under-test path"
  echo "      (replace 'skills/CHANGEME/scripts/$name.sh'), then write your TDD red."
}

# ─── Section: Add-case action ────────────────────────────────────────────────

# add_action <name> <case_name>
#   Append a case_<name>_<case_name>() stub to tests/<name>.sh.
#   Refuse if the file does not exist or the case already exists.
add_action() {
  local name=$1 case_name=$2
  validate_name "$name" >/dev/null
  validate_name "$case_name" >/dev/null

  local target="tests/$name.sh"
  local fn="case_${name}_${case_name}"

  if [[ ! -f "$target" ]]; then
    echo "Error: $target does not exist. Run 'metatest.sh scaffold $name' first." >&2
    exit 1
  fi

  if grep -Eq "^${fn}\(\)" "$target"; then
    echo "Error: $fn already exists in $target" >&2
    exit 2
  fi

  # Append the stub via heredoc (no template asset needed for ~5 lines).
  cat >> "$target" <<EOF

# AC: TODO — describe the spec acceptance criterion this case verifies.
${fn}() {
  # TODO: invoke the script and assert on its output/exit/stderr.
  assert_eq "${case_name} placeholder" "0" "0"
}
EOF

  echo "Appended $fn() to $target"
}

# ─── Section: Run action ─────────────────────────────────────────────────────

# run_action [<name>]
#   With <name>: prefer standalone path (bash tests/<name>.sh) if file exists,
#   else fall back to filter mode (bash $RUNNER <name>).
#   Without <name>: invoke the aggregate runner.
#   Exit code propagates from the underlying invocation.
run_action() {
  if [[ $# -eq 0 ]]; then
    bash "$RUNNER"
    exit $?
  fi

  local name=$1
  validate_name "$name" >/dev/null

  local target="tests/$name.sh"
  if [[ -f "$target" ]]; then
    bash "$target"
    exit $?
  fi

  bash "$RUNNER" "$name"
  exit $?
}

# ─── Section: Argument dispatch ──────────────────────────────────────────────

usage() {
  cat <<'EOF' >&2
Usage:
  metatest.sh scaffold <name>            Create tests/<name>.sh from template.
  metatest.sh add <name> <case_name>     Append case_<name>_<case_name>() stub.
  metatest.sh run [<name>]               Run all tests, or just one file.

<name> and <case_name> must be valid bash identifiers (^[a-zA-Z_][a-zA-Z0-9_]*$).
See file header for conventions and exit-code semantics.
EOF
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 2
  fi

  local subcmd=$1; shift
  case "$subcmd" in
    scaffold)
      if [[ $# -ne 1 ]]; then
        echo "Error: scaffold requires exactly one argument: <name>" >&2
        usage
        exit 2
      fi
      scaffold_action "$1"
      ;;
    add)
      if [[ $# -ne 2 ]]; then
        echo "Error: add requires exactly two arguments: <name> <case_name>" >&2
        usage
        exit 2
      fi
      add_action "$1" "$2"
      ;;
    run)
      run_action "$@"
      ;;
    *)
      echo "Error: unknown subcommand '$subcmd'" >&2
      usage
      exit 2
      ;;
  esac
}

main "$@"

# ─── Section: Implementation notes ───────────────────────────────────────────
#
# 1. Template substitution uses sed with two delimiters:
#    -e 's/__NAME__/<name>/g'         (slash delimiter — name has no slashes)
#    -e 's|__SCRIPT_PATH__|...|g'     (pipe delimiter — path has slashes)
#    The pipe avoids escaping every `/` in the script path.
#
# 2. Add-case uses an inline heredoc instead of a separate template asset
#    because the case stub is ~5 lines — a separate file would be ceremony.
#    The scaffold asset is templated because the per-script test file is
#    ~50 lines with multiple sections.
#
# 3. Validation runs once per name argument. validate_name prints the name
#    on stdout (for capture by callers that want it) and exits 1 on failure.
#    Both scaffold and add validate every <name> argument they receive.
#
# 4. The run action uses `exit $?` after each branch rather than `return`
#    so the script's exit code matches the underlying runner exactly.
#    `bash <file>` propagates the file's exit code; `exit` propagates that
#    to the caller.
#
# 5. PWD-relative `tests/<name>.sh` is intentional. Same convention as
#    jimconf.sh / jimfile.sh — the script assumes invocation from the
#    project root. Tests sandbox via subshell `cd` (see tests/metatest.sh).
#
