#!/usr/bin/env bash
#
# tests/provenance.sh — Tests for the provenance discipline (companion to the
# present-tense rule): blueprint/map prose references a group's surface by its
# stable current-state name, never by the mutable spec id / range / path or
# pinned version that introduced it.
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# HOW TO RUN
#   bash tests/provenance.sh                     # every case in this file
#   bash tests/provenance.sh rule_doc            # only cases matching "rule_doc"
#   bash skills/meta-test/scripts/run.sh         # this file alongside every other tests/*.sh
#
# Like tests/presenttense.sh, part of this file is a *textual* invariant over
# jim's blueprint skill/reference prose — every composition site that ingests
# supplied text must reference the one canonical provenance rule, single-sourced.
# The remaining cases exercise the deterministic guard: the pattern helper the
# self-hosting check uses, run against fixtures and against jim's own
# current-state artifacts (the group blueprint spec and the project map).
#
# The aggregate runner sources every tests/*.sh into one shell, so file-level
# identifiers must be unique across files (testlib.sh header, "Design contract").
# These globals and helpers carry a PROV_ / prov_ prefix so they never collide
# with a sibling file's own TOKEN / RULE_DOC (e.g. tests/presenttense.sh).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

PROV_RULE_DOC="$REPO_ROOT/skills/blueprint/references/provenance.md"
PROV_TOKEN="skills/blueprint/references/provenance.md"

# ─── Section: Test cases ─────────────────────────────────────────────────────

# AC: the rule, the flagged forms, the normalization, the over-constraint guard,
# and the safety discipline (untrusted-supplied-text + secret-scrubbed
# disclosure) live in a single canonical doc carrying the same four load-bearing
# sections as the present-tense sibling, so the doc-structure test generalizes.
case_provenance_rule_doc_structure() {
  local exists="no"; [[ -f "$PROV_RULE_DOC" ]] && exists="yes"
  assert_eq "rule doc exists" "yes" "$exists"
  [[ "$exists" == "yes" ]] || return

  local body; body="$(cat "$PROV_RULE_DOC")"
  assert_match "has '## The rule' section"                '^## The rule'                "$body"
  assert_match "has '## Normalize and disclose' section"  '^## Normalize and disclose'  "$body"
  assert_match "has '## Untrusted supplied text' section" '^## Untrusted supplied text' "$body"
  assert_match "has '## Where it runs' section"           '^## Where it runs'           "$body"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# Runs this file's cases only on direct invocation; when the aggregate runner
# sources us, BASH_SOURCE[0] != $0 and this stays silent. See the sibling test
# files' tail for why this shape must not be "tidied".
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  FILTER="${1:-}"
  run_discovered_cases
fi
