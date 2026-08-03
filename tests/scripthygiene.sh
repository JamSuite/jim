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
#   The production scripts under skills/*/scripts/ carry a second clause:
#   `export LC_ALL=C`. Every one of them parses untrusted text through regex
#   character classes, and several use one as an accept/reject gate, so a
#   collation range that shifts with the locale would change what a boundary
#   admits. The rule is uniform over that root rather than per-file judgment —
#   whether a given script is "locale-sensitive" is exactly the question a
#   mechanical check cannot answer, and the answer drifted once already.
#
#   Two framework files are exempt, and the exemption is load-bearing rather
#   than cosmetic: testlib.sh and run.sh SOURCE the test files, so a locale they
#   export becomes the locale every fixture is matched under. Test fixtures
#   legitimately carry non-ASCII content — the provenance detector's range form
#   uses en/em dashes — and forcing C collation there changes what a
#   multibyte-aware pattern matches, turning a passing detector into a silent
#   miss. A harness must not impose a collation on what it runs.
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

# exports_lc_all <file> — "yes" when the file exports LC_ALL=C at top level.
exports_lc_all() {
  grep -qE '^[[:space:]]*export LC_ALL=C[[:space:]]*$' "$1" && echo yes || echo no
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

# AC: every production script under skills/*/scripts/ exports LC_ALL=C, so a
# regex character class used as an accept/reject gate admits the same set under
# every locale. The two framework files that source test files are exempt (see
# the header). Fail-closed on an empty root, like the sibling case above.
case_scripthygiene_production_scripts_export_lc_all() {
  local f rel
  assert_eq "skills/*/scripts enumerated" "yes" "$(yn "$(matches "$REPO_ROOT"/skills/*/scripts/*.sh)")"
  for f in "$REPO_ROOT"/skills/*/scripts/*.sh; do
    [[ -e "$f" ]] || continue
    rel="${f#"$REPO_ROOT"/}"
    case "$rel" in
      skills/meta-test/scripts/testlib.sh|skills/meta-test/scripts/run.sh) continue ;;
    esac
    assert_eq "$rel exports LC_ALL=C" "yes" "$(exports_lc_all "$f")"
  done
}

# AC: the two exempt framework files do NOT export a locale, so a test's own
# fixtures are matched under the developer's locale rather than one the harness
# imposed. Pinned as its own case: silently gaining the export is the exact
# regression that turns a multibyte detector into a passing no-op.
case_scripthygiene_framework_imposes_no_locale() {
  local f rel
  for f in "$REPO_ROOT"/skills/meta-test/scripts/testlib.sh "$REPO_ROOT"/skills/meta-test/scripts/run.sh; do
    [[ -e "$f" ]] || continue
    rel="${f#"$REPO_ROOT"/}"
    assert_eq "$rel exports no locale" "no" "$(exports_lc_all "$f")"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  FILTER="${1:-}"
  run_discovered_cases
fi
