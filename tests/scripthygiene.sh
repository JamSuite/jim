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
  assert_eq "top-level scripts enumerated" "yes" "$(yn "$(matches "$REPO_ROOT"/scripts/*.sh)")"
  # Both production roots, not just the skill one. The sibling locale case says
  # these roots need no per-command pin BECAUSE they export once at the top —
  # a claim that was true of scripts/ only by convention while this sweep
  # reached skills/*/scripts/ alone.
  for f in "$REPO_ROOT"/skills/*/scripts/*.sh "$REPO_ROOT"/scripts/*.sh; do
    [[ -e "$f" ]] || continue
    rel="${f#"$REPO_ROOT"/}"
    case "$rel" in
      skills/meta-test/scripts/testlib.sh|skills/meta-test/scripts/run.sh) continue ;;
    esac
    assert_eq "$rel exports LC_ALL=C" "yes" "$(exports_lc_all "$f")"
  done
}

# The locale rule's third root. The two above cannot apply here — run.sh sources
# every test file into one shell, so a top-level export in any of them would
# impose a collation on every other fixture, which is the regression the
# framework exemption exists to prevent. So the pin has to be per command, and
# this sweeps the one construct where a locale difference silently changes a
# RESULT rather than a match: `sort -u` merges lines that collate equal but
# differ bytewise, turning a genuine mismatch into a passing assertion. Files
# under skills/*/scripts/ and scripts/ are not swept because they export the
# locale once at the top, which the case above already requires.
case_scripthygiene_test_sorts_pin_the_locale() {
  local f rel n=0 unpinned
  for f in "$REPO_ROOT"/tests/*.sh; do
    [[ -e "$f" ]] || continue
    n=$((n + 1))
    rel="${f#"$REPO_ROOT"/}"
    # This file names the construct in order to sweep for it, so it matches
    # itself. Excluded the way provenance.sh excludes its own detector tokens —
    # a textual sweep cannot both spell a pattern and be blind to its own copy.
    [[ "$rel" == "tests/scripthygiene.sh" ]] && continue
    unpinned="$(grep -c 'sort -u' "$f" 2>/dev/null)"
    unpinned=$(( unpinned - $(grep -c 'LC_ALL=C sort -u' "$f" 2>/dev/null) ))
    assert_eq "$rel pins the locale on every 'sort -u'" "0" "$unpinned"
  done
  assert_eq "tests enumerated" "yes" "$(yn "$n")"
}

# Every name a `read` assigns into must be declared local in its function. An
# undeclared one is a global: harmless while the call sits in a pipeline (a
# subshell cannot write back), and a live clobber the moment a caller switches to
# a here-string — which is how the same variable name held by a caller mid-loop
# gets overwritten by its callee. The existing leak check is name-pinned to one
# function's variables, so it cannot see the class; this reads the declarations
# and the reads out of every function and compares them.
case_scripthygiene_read_targets_are_declared_local() {
  local f rel n=0 undeclared
  for f in "$REPO_ROOT"/skills/*/scripts/*.sh "$REPO_ROOT"/scripts/*.sh; do
    [[ -e "$f" ]] || continue
    n=$((n + 1))
    rel="${f#"$REPO_ROOT"/}"
    undeclared="$(awk '
      /^[a-zA-Z_][a-zA-Z0-9_]*\(\)[ \t]*\{/ { fn=$0; sub(/\(\).*/,"",fn); next }
      /^\}/ { fn=""; next }
      fn=="" { next }
      /[ \t]local[ \t]/ {
        line=$0; sub(/^.*[ \t]local[ \t]+/,"",line); sub(/[ \t]#.*/,"",line)
        k=split(line, p, /[ \t]+/)
        for (j=1;j<=k;j++) { v=p[j]; sub(/=.*/,"",v)
          if (v ~ /^[A-Za-z_][A-Za-z0-9_]*$/) decl[fn "|" v]=1 }
      }
      /read -r[a-zA-Z]*[ \t]/ {
        line=$0; sub(/^.*read -r[a-zA-Z]*[ \t]+/,"",line)
        sub(/<<.*/,"",line); sub(/;.*/,"",line)
        k=split(line, p, /[ \t]+/)
        for (j=1;j<=k;j++) { v=p[j]
          if (v == "_" || v == "") continue
          if (v !~ /^[A-Za-z_][A-Za-z0-9_]*$/) continue
          use[fn "|" v]=1 }
      }
      END { for (u in use) if (!(u in decl)) { split(u,a,"|"); printf "%s:%s ", a[1], a[2] } }
    ' "$f")"
    assert_eq "$rel declares every read target local" "" "${undeclared% }"
  done
  assert_eq "the sweep enumerated a corpus (>= 10, got $n)" "yes" \
    "$([[ "$n" -ge 10 ]] && echo yes || echo no)"
}

# A test file outside tests/ is silently NOT RUN: the runner's glob contains it
# out rather than reporting it, and the scaffold's own refusal only guards the
# create path. Nothing detected a file arriving by any other route — a hand
# authored one, or a scaffold invoked from the wrong directory, which lands it
# inside a Claude Code discovery root.
case_scripthygiene_no_test_file_outside_tests() {
  local f rel n=0 strays=""
  # Enumerated by find at ANY depth under both discovery roots, not by a fixed
  # set of globs. A depth-limited sweep cannot see `skills/<x>/tests/<name>.sh`
  # — which is precisely the path a scaffold run from inside a skill directory
  # would create, and therefore the one this case most needs to catch.
  while IFS= read -r f; do
    [[ -e "$f" ]] || continue
    n=$((n + 1))
    rel="${f#"$REPO_ROOT"/}"
    case "$rel" in
      skills/meta-test/scripts/testlib.sh|skills/meta-test/scripts/run.sh|skills/meta-test/scripts/metatest.sh) continue ;;
    esac
    grep -qE '^case_[a-zA-Z0-9_]+\(\)|/testlib\.sh"?$' "$f" && strays="$strays$rel "
  done < <(find "$REPO_ROOT/skills" "$REPO_ROOT/agents" "$REPO_ROOT/scripts" \
                -type f -name '*.sh' 2>/dev/null)
  assert_eq "no test-shaped file outside tests/" "" "${strays% }"
  assert_eq "the sweep enumerated a corpus (>= 10, got $n)" "yes" \
    "$([[ "$n" -ge 10 ]] && echo yes || echo no)"
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
