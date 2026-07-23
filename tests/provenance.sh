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

# prov_token_count <abs-file>
#   Print how many times the reference token appears in the file (0 if absent).
#   Fixed-string match so the path's dots are literal.
prov_token_count() {
  grep -oF "$PROV_TOKEN" "$1" 2>/dev/null | wc -l | tr -d ' '
}

# prov_scan_file <abs-file>
#   Print the count of provenance hits (0 == clean) — a stable-looking reference
#   to a mutable identifier. Union of the flagged forms, after masking the
#   reserved 000-blueprint path (legitimate current state — 000 never moves).
#   Date/timestamp numerics (4-2-2) do not match the 3–3 spec-range form, so a
#   frontmatter `updated:`/`Last reconciled:` stamp is not flagged.
prov_scan_file() {
  sed 's#docs/specs/[a-z0-9-]*/000-blueprint#__RESERVED__#g' "$1" 2>/dev/null \
    | grep -oiE 'spec[ -][0-9]{3}|[0-9]{3}[–—-][0-9]{3}|v[0-9]+\.[0-9]+\.[0-9]+|docs/specs/[a-z0-9-]+/[0-9]{3}-' \
    | wc -l | tr -d ' '
}

# AC: the discipline is single-sourced and referenced (not restated) at each
# composition site that ingests supplied text, and a dropped or missing citation
# is caught mechanically. Each file carries one pointer per exit door it wires
# alongside the present-tense sibling, so a single dropped pointer drops the
# count below its minimum and fails this case.
case_provenance_sites_reference_rule() {
  # "<repo-relative file>\t<minimum expected count>"
  local rows=(
    "skills/blueprint/SKILL.md	5"
    "skills/blueprint/references/map-methodology.md	2"
    "skills/blueprint/references/migrate-arms.md	3"
  )
  local row rel min cnt ok
  for row in "${rows[@]}"; do
    rel="${row%%$'\t'*}"
    min="${row##*$'\t'}"
    cnt="$(prov_token_count "$REPO_ROOT/$rel")"
    ok="no"; [[ "$cnt" -ge "$min" ]] && ok="yes"
    assert_eq "$rel references rule (need >= $min, got $cnt)" "yes" "$ok"
  done
}

# AC: the guard's detection patterns fire on the provenance forms that shipped in
# the original violation (spec id, spec range, version pin) and spare legitimate
# current-state content (the reserved 000-blueprint path, a functional grouping,
# a date). prov_scan_file is the single home of the patterns, shared with the
# self-hosting case below.
case_provenance_detect_forms() {
  local dirty clean dcount ccount dirty_ok
  dirty="$(fixture prov_dirty.md 'The spec-047 split verbs; issue tracking (017–025); pinned v2.0.0.')"
  clean="$(fixture prov_clean.md 'Blueprint at docs/specs/jim/000-blueprint/; the issue-tracking cluster, reconciled 2026-07-13.')"

  dcount="$(prov_scan_file "$dirty")"
  ccount="$(prov_scan_file "$clean")"

  dirty_ok="no"; [[ "${dcount:-0}" -ge 3 ]] && dirty_ok="yes"
  assert_eq "positive fixture flags the shipped forms (>=3, got $dcount)" "yes" "$dirty_ok"
  assert_eq "negative fixture is provenance-free" "0" "$ccount"
}

# AC: jim's own current-state artifacts — the group blueprint spec and the
# project map — carry no provenance form. The blueprint spec is authored clean;
# the map is normalized through /jim:blueprint. A reintroduced spec id / range /
# path / version regresses this case (mirrors the prose-pin precedent).
case_provenance_self_hosting_clean() {
  local bp map bpc mapc
  bp="$REPO_ROOT/docs/specs/jim/000-blueprint/spec.md"
  map="$REPO_ROOT/BLUEPRINT.md"
  bpc="$(prov_scan_file "$bp")"
  mapc="$(prov_scan_file "$map")"
  assert_eq "group blueprint spec is provenance-free (got $bpc)" "0" "$bpc"
  assert_eq "project map is provenance-free (got $mapc)" "0" "$mapc"
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
