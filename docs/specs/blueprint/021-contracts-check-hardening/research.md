---
spec: "spec.md"
status: Active
date: "2026-07-23"
---

# Research: Harden contracts-check

Local archaeology over `skills/verify/scripts/jimverify.sh` and
`tests/jimverify.sh`. No external phase — internal Bash, no new dependencies.
Provenance: `cmd_edges` and `cmd_contracts_check` are spec 037
(`037-verify-contracts`); `cmd_health` is spec 039 (`039-graph-health`).

## Anchors

**Item 1 — blueprint-slot resolver**
- `jimverify.sh:912` — coverage loop hand-composes `bp="$specs_root/$g/000-blueprint/spec.md"`.
- `jimverify.sh:958` — edge-outcome loop hand-composes `pbp="$specs_root/$P/000-blueprint/spec.md"`.
- `jimverify.sh:1167` — **third copy**, in `cmd_faces_aggregate` (not named in the spec's Affected Systems — see Peer Feedback).
- `jimfile.sh:662-676` — the resolver: `path blueprint <group>` prints `{specs}/<group>/000-blueprint/spec.md`, slug-validates (`is_valid_slug`, `:672`), does **not** existence-gate, rc 2 on missing group / rc 1 on invalid slug.
- `jimverify.sh:132,263,287` — the script already holds a `JIMFILE` handle and routes path *validation* (`valid-relpath`) through it; routing path *construction* through `path blueprint` is the same move.

**Item 2/3 — self-edge guard + health self-loop**
- `jimverify.sh:786` — `cmd_edges` emits an edge iff `is_slug(c1) && is_slug(c3)`; **no** `c1==c3` check, so `| a | x | a |` becomes a real edge `a\tx\ta`.
- `jimverify.sh:787` — the HYGIENE-emit branch (`else printf "HYGIENE\t..."`) the guard would extend to valid-slug self-pairs.
- `jimverify.sh:929` — precedent: CROSS-REF loop already skips self-pairs (`[[ "$P" == "$C" ]] && continue`).
- `jimverify.sh:955` — edge-outcome loop skips HYGIENE rows (`[[ "$C" == "HYGIENE" ]] && continue`) but has **no** self-pair skip.
- `jimverify.sh:1008` — `cmd_health` awk skips HYGIENE rows (`$1=="HYGIENE"{next}`).
- `jimverify.sh:1032-1033` — the peel: a self-loop increments **both** `ind[a]` and `outd[a]` (`:1032`), so the degree-0 peel (`:1033`) never removes it → survives as a 1-node CYCLE cluster; `:1020` also counts it in EDGES.

**Test anchors (templates to mirror)**
- `tests/jimverify.sh:1020-1034` — `hmap <name> <groups> <rows>`, the Contract-Graph fixture builder (edges/health tests).
- `tests/jimverify.sh:791-811` — `case_jimverify_edges_crafted_cell_hygiene`, the template for a "self-pair → HYGIENE, never a plain edge" edges test.
- `tests/jimverify.sh:1044-1055,1154-1162` — health CYCLE/EDGES assertion patterns for a "self-loop must NOT read as a 1-node cycle" test.
- `tests/jimverify.sh:819-866` — `contracts_repo <name>`, the accounts/billing fixture with `provider-ref`/`consumer-ref` params (`:831-833`); reuse for the consumer-abstain test.
- `tests/jimverify.sh:872-881` — `case_jimverify_contracts_coverage_crossref_locationonly`, the exfiltration-guard template (`grep -c 'require' == 0` at `:879-880`) the new **edge-outcome** location-only test must mirror.
- `tests/jimverify.sh:901-927` — existing provider/consumer outcome tests; the abstain test reuses their `awk '$1=="billing>accounts#identity-lookup" && $2=="consumer"'` keying, asserting the row is **absent**.

## Local Patterns

- **Test harness:** `run_jimverify` (`:31-36`) / `run_jimverify_in <dir>` (`:303-309`, cd's into a fixture repo); accessors `tsv_field` (`:45-47`), `hcycle` (`:1038-1040`). Conventions in `skills/meta-test/scripts/testlib.sh` header; `set -uo pipefail`, `assert_eq` append-and-continue.
- **HYGIENE inheritance chain:** because both the edge-outcome loop (`:955`) and health (`:1008`) already drop HYGIENE rows, a self-pair guard emitting HYGIENE at the `cmd_edges` root propagates to *both* consumers with no per-consumer edit — the mechanism that satisfies the self-edge ACs at one site.
- **Evidence is already location-only:** `emit_edge` (`:834-836`) sanitizes and the `holds` path emits `cut -d: -f1,2` (`:866`); item 7 is a *characterization* test pinning existing behavior, not a code change. Likewise the consumer-abstain branch (`:867-869`, no emit on no-match) already exists — item 6 pins it. Both are zero-production-risk.

## Security & Performance

- No new attack surface. Untrusted map/blueprint/code content stays behind the existing `san()`/`emit_edge` sanitization and location-only construction; the self-pair guard must route dropped rows through the **same** HYGIENE sanitization (`:787`), never a raw echo.
- Performance is a non-issue — graphs are small (per-project group counts) and the guard is an O(1) string compare per row.

## Alignment

Aligns with locked constraints — this refactor tightens conformance to existing
doctrines rather than diverging from them:

- **ARCHITECTURE.md:385** records contracts-check's guarantees that these ACs
  directly serve: *"matched content never emitted — the Finding-2 exfiltration
  guard"* (AC #7 pins exactly this for `holds`/`violated` edge-outcome
  evidence), *"a bad row → HYGIENE"* (AC #4 extends the same drop-and-name rule
  to valid-slug self-pairs), and *"consumer-ref holds-or-abstain"* (AC #6 pins
  the abstain branch).
- **ARCHITECTURE.md:262** frames health as *"measurement-only (no verdicts /
  thresholds — the 034 no-standing-verdict doctrine)"*. AC #5 corrects a
  *mismeasurement* (a self-loop miscounted as a cycle) without adding any
  verdict, and Out of Scope explicitly bars new metrics/thresholds — so the
  doctrine holds.
- **VISION.md** north star (architectural integrity via living documents): AC #1
  restores the `blueprint-slot-reserved` invariant, keeping the slot convention
  single-sourced.

No recommendation contradicts a locked constraint.

## Recommendations

*Options and trade-offs for the architect — not decisions.*

1. **Guard placement (spec Insight 1).** Archaeology confirms the shared-root option is clean: emit HYGIENE for a valid-slug self-pair at `cmd_edges:786-787`, and both the edge-outcome loop and `cmd_health` inherit the exclusion (they already skip HYGIENE). This likely makes any per-loop self-pair `continue` redundant; the `:929` CROSS-REF skip can stay (it runs before `cmd_edges`).
2. **Resolver routing has an interface ripple.** `$specs_root` (the `$2` arg) is used *only* at `:912` and `:958`. Routing both through `path blueprint` (config-sourced) makes the arg **vestigial** in `cmd_contracts_check`. In production the two coincide (SKILL.md:122 passes `jimfile.sh get specs`), so output is unchanged — but the architect should choose among: (a) drop the `<specs-root>` param (interface change → SKILL.md:87/122 + every test), (b) keep it unused, or (c) extend the resolver to accept an optional specs-root override so the arg stays authoritative *and* the slot layout is single-sourced. Option (c) is the only one that also cleanly covers the third site (`:1167`, which takes its own specs-root) — see Peer Feedback.
3. **New tests mirror existing templates** (anchors above) — no new harness needed.

## Peer Feedback

**For the PM (scope) — RESOLVED 2026-07-23: widen.** The `blueprint-slot-reserved` invariant is about the *whole script*, and archaeology found **three** hand-derived copies (`:912`, `:958`, and `:1167` in `cmd_faces_aggregate`), not the two originally named. The PM chose to **widen** scope: `cmd_faces_aggregate:1167` is now in the spec's Current State and Affected Systems, and AC #1 obliges all three sites, so the invariant actually holds after the change. No follow-on issue filed (absorbed into 049).

**For the Architect (carry into planning):** Recommendation 2 — the vestigial-`$specs_root` decision — and its coupling to the third site under option (c). If (c) is chosen, jimfile.sh enters the blast radius (outside the spec's current Affected Systems); confirm that's acceptable or keep the resolver config-only and handle `:1167` separately.
