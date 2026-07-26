#!/usr/bin/env bash
#
# tests/scripthygiene.sh — Textual-invariant test for the script-preamble rule.
#
# WHAT THIS FILE DOES
#   Sweeps every first-party shell script (skills/*/scripts/*.sh, tests/*.sh,
#   scripts/*.sh) and asserts each sets `set -uo pipefail` as its first
#   executable line — set directly, never reached only through `source`. There
#   is no single script under test; the invariant is a textual one over the
#   whole corpus.
#
#   Fail-closed: each globbed root must contribute at least one file, so an
#   empty sweep (a mis-resolved $REPO_ROOT, or a future reorg that strands a
#   root) fails loudly instead of vacuously passing.
#
# HOW TO RUN
#   bash tests/scripthygiene.sh            # standalone
#   bash skills/meta-test/scripts/run.sh   # via the aggregate runner
#
# CONVENTIONS: see skills/meta-test/scripts/testlib.sh header.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

# first_exec_line <file> — echo the first non-shebang, non-comment, non-blank line.
first_exec_line() {
  awk 'NR==1 && /^#!/ {next}
       /^[[:space:]]*#/ {next}
       /^[[:space:]]*$/ {next}
       {print; exit}' "$1"
}

# matches <globbed-args...> — echo how many of the passed paths exist. Callers
# expand the glob at the call site with the quoted-prefix idiom so the count
# stays safe against spaces and leading-dash filenames.
matches() { local n=0 f; for f in "$@"; do [[ -e "$f" ]] && n=$((n + 1)); done; printf '%s' "$n"; }

# yn <count> — "yes" when count >= 1, else "no".
yn() { [[ "$1" -ge 1 ]] && echo yes || echo no; }

# check_files <globbed-args...> — assert each existing path's first executable
# line sets the preamble; the failing path rides in the assert label.
check_files() {
  local f rel line ok
  for f in "$@"; do
    [[ -e "$f" ]] || continue
    rel="${f#"$REPO_ROOT"/}"
    line="$(first_exec_line "$f")"
    ok="no"; [[ "$line" =~ ^[[:space:]]*set\ -uo\ pipefail ]] && ok="yes"
    assert_eq "$rel first exec line sets 'set -uo pipefail'" "yes" "$ok"
  done
}

# AC: every first-party shell script sets `set -uo pipefail` as its first
# executable line, and each globbed root is non-empty (fail-closed).
case_scripthygiene_every_script_sets_pipefail() {
  assert_eq "skills/*/scripts enumerated"  "yes" "$(yn "$(matches "$REPO_ROOT"/skills/*/scripts/*.sh)")"
  assert_eq "tests enumerated"             "yes" "$(yn "$(matches "$REPO_ROOT"/tests/*.sh)")"
  assert_eq "top-level scripts enumerated" "yes" "$(yn "$(matches "$REPO_ROOT"/scripts/*.sh)")"
  check_files "$REPO_ROOT"/skills/*/scripts/*.sh "$REPO_ROOT"/tests/*.sh "$REPO_ROOT"/scripts/*.sh
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  FILTER="${1:-}"
  run_discovered_cases
fi
