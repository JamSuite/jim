---
spec: "docs/specs/blueprint/024-blueprint-provenance-guard/spec.md"
status: Needs PM Review
date: "2026-07-23"
---

# Research: Guard blueprints and maps against provenance references

## Anchors

- **`skills/blueprint/references/present-tense.md:1-82`** — the sibling doctrine
  to mirror. Four load-bearing `##` sections (`The rule`, `Normalize and
  disclose`, `Untrusted supplied text`, `Where it runs`); the "Where it runs"
  block (L68-82) enumerates every exit door and excludes retire/reconcile ("compose
  no supplied text"). A provenance companion clones this shape.
- **Composition (exit-door) sites — the citation surface.** present-tense is
  cited **10×** across three files; the provenance companion joins the same
  drafts:
  - `skills/blueprint/SKILL.md` — **5×**: L147-150 (group generate/update scan),
    L301-304 (update-mode U-step scan), L376-378 (map create/update scan),
    L384-390 (mint-new handoff), L508 (checklist item).
  - `skills/blueprint/references/map-methodology.md` — **2×**: L64-70 (map create
    converge/gate), L72-88 (map differential update).
  - `skills/blueprint/references/migrate-arms.md` — **3×**: rename L27-32, split
    L61-68, merge L104-111 (no-re-gate returns to `/jim:partition`).
- **`skills/blueprint/SKILL.md:147-150` and `:301-304`** — the two prose blocks a
  provenance-scan clause extends ("run the present-tense self-scan … per
  `…present-tense.md`"). Becomes "run the present-tense **and** provenance
  self-scans (per `…present-tense.md`, `…provenance.md`)".
- **`tests/presenttense.sh:1-86`** — the direct template to clone for the wiring
  test. `PT_`-prefixed globals (L29-30), `pt_token_count()` fixed-string helper
  (L35-37), `rows=("file\tmin")` (L47-51), `case_*_sites_reference_rule` +
  `case_*_rule_doc_structure`, standalone-runnable tail (L82-85). New file gets
  `PROV_`-prefixed globals (file-level identifier uniqueness — the aggregate
  runner sources all `tests/*.sh` into one shell).
- **`tests/jimpartition.sh:1977-1983`** (`case_jimpartition_prose_pin_…`) — the
  **fixed-count** grep-assert precedent (`assert_eq "…" "2" "$(grep -c '…' file)"`).
  The mechanical *absence* guard is its inverse: `assert_eq "<file> clean" "0"
  "$(grep -cE '<provenance-pattern>' file)"`.
- **`skills/meta-test/scripts/testlib.sh`** — `assert_eq`/`assert_match`/
  `assert_exit`/`assert_nonempty` (L101-149), `REPO_ROOT` (L73),
  `run_discovered_cases` (L187-214).
- **`BLUEPRINT.md:32-34`** — the **only live offender**: four boundary-rationale
  spec ranges (`017–025`, `026–028`, `029–034`, `035–037`). `docs/specs/jim/000-blueprint/spec.md`
  is already provenance-clean; no `vX.Y.Z` exists in either file today.
- **`docs/specs/jim/000-blueprint/spec.md:236`** — the `present-tense` verify
  invariant (high, judge). It is a **wiring** invariant ("composition sites
  reference the rule and run the self-scan"), not a content check.

## Local Patterns

- **Single-source doctrine + textual wiring test.** present-tense is defined once
  and cited by path; no script-under-test — a `tests/*.sh` asserts each site's
  citation count. The provenance rule follows this exactly: one `provenance.md`,
  path citations, one `tests/provenance.sh`.
- **Mechanical-absence idiom.** `grep -cE 'PATTERN' file` compared to `"0"` via
  `assert_eq` is used throughout `tests/jimpartition.sh` (e.g. L649-651). This is
  the self-hosting guard's shape.
- **Test file to use as template:** `tests/presenttense.sh` (framework = plain
  bash + `testlib.sh`, `set -uo pipefail`, cases auto-discovered, `PROV_`-prefixed
  globals, standalone tail).
- **Map edits ride the skill, via Edit not Write** (`map-methodology.md` L84-88
  gates per-item boundary-rationale changes; `map-template.md:28-30` defines the
  `Boundary rationale` field). Normalizing the map's ranges is a
  boundary-rationale rewrite through that flow.

## Security & Performance

- **No new trust boundary or input parsing.** The doctrine is prose; the guard is
  a read-only `grep` over two tracked files at test time. Supplied text stays
  inside the existing `<untrusted-*>` wrapping while scanned (present-tense
  L58-66) — an embedded directive is normalized as text, never followed; the
  provenance rule adds no injection path.
- **False-positive precision (the load-bearing risk).** The path pattern
  `docs/specs/<g>/0NN-` **matches the reserved `000-blueprint` path** — the guard
  MUST exclude it (a second `grep -v '000-blueprint'` or an anchored negation).
  Frontmatter/prose timestamps (`updated`, `last_full_generate`, `Last reconciled:
  2026-07-13…`) and criticality tiers are date/count numerics the three patterns
  do not match (`spec[ -]0NN`, `NNN–NNN`, `vX.Y.Z`) — confirmed date-safe. The
  mechanical guard covers only unambiguous forms; ambiguous prose falls to the
  judgment scan, whose disclose-and-revert recovers any false positive.

## Recommendations

**Alignment.** This work serves VISION.md's "living documents that support agile
iteration" and "not a black box" (every rewrite disclosed at a gate) — a
blueprint that rots silently on renumber is not a current-state living document.
It follows ARCHITECTURE.md's scripting-layer conventions (bash + POSIX,
`set -uo pipefail`, textual-invariant tests, no third-party deps) and the
single-source doctrine pattern, and reuses the `CLAUDE.md` script-comment
rationale ("no spec IDs … the reference rots") rather than re-legislating it. No
locked-constraint divergence.

*Options and trade-offs for the architect — not decisions.*

1. **Scan wiring: extend the prose, keep two docs cited.** At each exit door the
   line becomes "run the present-tense and provenance self-scans." The wiring
   test's min-count rows roughly double (each site now cites two rule docs). Weigh
   naming the provenance doc so its four-section structure test mirrors
   present-tense's `case_*_rule_doc_structure`.
2. **Migrate-arm scope may differ from present-tense's.** present-tense notes the
   rename arm "composes no supplied prose" (identity-only). Provenance is most
   dangerous *precisely* on the renumbering arms (split/merge mint fresh-child
   blueprints and re-point refs) — cite provenance at split/merge for sure;
   rename likely inherits the same "no supplied prose" exclusion. Confirm the
   per-arm min-counts at plan time.
3. **AC5 vs AC9 are genuinely distinct** — AC5 asserts *absence* in jim's real
   files (only the map's ranges are Red today; the version arm has no live
   fixture), AC9 asserts the detector actually *fires* on positive fixtures
   (spec-ID, range, version). Keep both.
4. **Verify invariant: fold, don't add.** The `present-tense` invariant is a
   wiring check; extending its text to "…reference the present-tense **and
   provenance** rules and run both scans" keeps the invariant set lean (aligns
   with the lean-tracking preference) over a parallel `no-provenance` invariant.
   AC8 is correctly bounded to *wiring* — `/jim:verify` cannot sense provenance in
   arbitrary blueprint *content* (see Peer Feedback).

## Peer Feedback

*For the PM / architect — feasibility signals, not blockers.*

- **AC7 (map normalization within a TDD build) needs a sequencing decision.** The
  map is skill-maintained and gated (`map-methodology.md` L84-88), but `/jim:build`
  runs TDD on scripts/docs, not an interactive `/jim:blueprint` map regen. Two
  viable paths: (a) the Green step edits `BLUEPRINT.md`'s boundary rationale
  directly (a doc edit the coder owns), documenting that it *would* ride the
  extended scan; or (b) a post-build `/jim:blueprint` map-update pass normalizes it
  through the surface. Open Question #2 already flags this — the plan should pick
  one so the guard-test Green step is unambiguous.
- **Coverage is intentionally asymmetric — state it so nobody over-expects.** The
  mechanical guard covers jim's **own** two artifacts (self-hosting regression).
  Consuming jim projects get the **judgment** exit-door scan only — identical to
  how present-tense already works. `/jim:verify` checks citation *wiring*, never
  blueprint *content*, so it will not mechanically flag a provenance ref in some
  consuming group's blueprint prose. This bounds what AC8 can promise and is worth
  one explicit sentence in the doctrine doc.
- **No external dependency.** The pattern (lint stale cross-references in living
  docs — docs-as-code freshness, ADR-immutability conventions) has external
  precedent, but the implementation is fully grounded in the local present-tense
  precedent; Phase 1 external research adds nothing actionable. Skipped.
