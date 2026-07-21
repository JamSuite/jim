---
spec: "spec.md"
status: Active
date: "2026-07-21"
---

# Research: Spec identity on group move

Grounds spec 046 against jim's shipped rename engine (spec 043). Headline: the
preference is **largely a classification gate on machinery that already exists**,
not new subsystems.

## Anchors

- **Occurrences enumeration** — `skills/partition/scripts/jimpartition.sh:1000-1048`
  (awk kinds at `:1037-1041`: dotted-key / config-key / config-value / path /
  prose; line content never emitted, `:1005-1007`). `rewrite` reuses this verbatim.
- **The classification flip (the load-bearing edit)** —
  `skills/partition/references/partition-methodology.md:237-257`, mechanical rule
  `:246` "*numbered-spec (`NNN-*`) body text → historical*". Under `rewrite`,
  numbered-body identity occurrences flip `historical`→`identity`. This one rule is
  the core of the feature.
- **Gatherer judgment layer** — `agents/gatherer.md` (Read/Glob/Grep only; the
  rename branch classifies identity/code-surface/historical, `:24-27`). Mechanical
  rules are fail-closed authoritative; only undecidable prose rows fan out to the
  gatherer, before any `Skill(jim:blueprint)`, batched under `verify_fanout_cap`
  (methodology `:250-257`). This *is* the spec's "scripted floor + judgment prose."
- **Config resolution** — `skills/conf/scripts/jimconf.sh` `get`/`resolve`
  (`:144-223`); bare-selector enum precedents `group_axis`/`group_territory`
  (`:65-66`); per-group dynamic family `verify_appetite_<group>` (`:112-117`,
  `:157-173`, slug-charset-validated suffix). Grounds a new bare key
  `spec_identity_on_move` (default `rewrite`).
- **Skill-side value validation** — `skills/verify/SKILL.md:161` (degrade to safe
  default + note fallback in the report). The template for validating
  `rewrite|forward|immutable` → fall back to `rewrite`, note it.
- **Commit choreography** — `skills/review/scripts/jimledger.sh` `commit-rename`
  (`:308-366`; the `docs` stage auto-stages the moved spec-dir pair, `:338`) +
  `commit-map` (`:187-230`); three-commit sequence at methodology `:276-306`.
- **Doctrine homes (two — must stay consistent)** — `skills/partition/SKILL.md:384-387`
  (the Freeze-history invariant) + checklist `:409`, **and**
  `partition-methodology.md:237-257` (the classification rule). AC 2/8/9's
  reconciled doctrine + composition rule physically land here.
- **Test surface** — `tests/jimpartition.sh` `rename_repo()` fixture (`:109-233`)
  already builds a ≥3-group git repo containing a frozen numbered
  `cart/001-initial/spec.md` with historical old-name body text (`:150-156`) —
  exactly the surface AC 11 exercises. Representative case: `:829-835`.

## Local Patterns

- **Mechanical-first, gatherer-residue, fail-closed** (methodology `:242-257`):
  kind+location decide identity/code-surface/historical authoritatively, never
  overridable by a gatherer verdict; only undecidable prose fans out to the
  read-only gatherer. Reuse verbatim, extended with the mode gate — do not invent
  a rewrite-specific classification path.
- **Config: read-then-validate-skill-side.** jimconf returns the trimmed value or
  the default-on-empty and never enum-validates; the consuming skill validates and
  degrades (`verify/SKILL.md:161`). Follow it for `spec_identity_on_move`.
- **Commit staging: literal-path, moved-pair auto-staged.** `commit-rename docs`
  stages `<specs-dir>/<old>` + `<specs-dir>/<new>` (`:338`). Because the whole
  moved pair is staged, `rewrite`'s edited numbered bodies under
  `<specs-dir>/<new>/**` appear to ride the existing docs commit with **no
  choreography change** (architect to confirm — see Peer Feedback).
- **Test template** — `tests/jimpartition.sh` + `skills/meta-test/scripts/testlib.sh`:
  `set -uo pipefail`, `case_*` name-discovery (no registry), `assert_match` /
  `assert_exit`, `fixture` / `rename_repo` setup. AC 11 extends `rename_repo` with a
  rewrite-vs-forward assertion pair over the frozen `cart/001-initial` body. Author
  via `/jim:meta-test scaffold` / append.

## Security & Performance

- **AC 10's injection boundary is satisfied by construction, not discipline.**
  Rewrite classification derives from `occurrences` structural position (content
  never emitted, `jimpartition.sh:1005-1007`), and the residue judge is the
  Read/Glob/Grep-only gatherer — an embedded directive inside a scanned numbered
  body is un-actionable by capability absence (extends 043 AC #20). The mechanical
  rule is fail-closed over any gatherer verdict.
- **Blast radius widens under `rewrite`.** Numbered `NNN-*` bodies become edit
  targets (they never were under freeze). Keep the *mechanical* edit to identity
  fields (`group:` frontmatter, dotted/typed refs); route free-prose group-mentions
  through the gatherer — prose can't be safely `sed`'d (cart-the-group vs
  cart-the-noun). Secret-scrub any presented/persisted evidence (043 AC #19).
- **Perf negligible.** One extra classification branch plus a bounded
  (`verify_fanout_cap`) gatherer fan-out over one group's numbered specs; the
  enumeration already runs.
- **No new dependencies** — bash + existing jim scripts only; no library sprawl.

## Recommendations

*Options and trade-offs for the architect — not decisions.*

1. **Build the knob as a classification gate on the existing rename engine**, not
   new machinery: `spec_identity_on_move` selects whether numbered-body identity
   occurrences classify `identity` (rewrite) or `historical` (forward/immutable).
   Confirms the spec's "largely a classification flip" framing.
2. **Rewrite = mechanical floor + gatherer residue**, reusing the methodology split
   (`:242-257`) rather than a bespoke rewrite path.
3. **Record the reconciled doctrine in both homes**, mode-conditional
   (`SKILL.md:384-387` invariant + methodology `:237-257`) — the AC 2/8/9 target.
4. **forward** = today's move + frozen bodies + the existing `op=rename` ledger
   event as the alias (no new artifact); **immutable** is N/A to rename (AC 6),
   surfaced at the spec-040 gate.
5. **Validate the config value skill-side** (`verify/SKILL.md:161` pattern),
   default `rewrite`, fallback noted in the run's report.

**Alignment.** Serves VISION's "the spec/research/plan archive becomes a go-to
reference" (rewrite → coherent archive; immutable → point-in-time-faithful) and
jim's living-document instinct (present-tense blueprints). Respects
ARCHITECTURE.md's path-derived group binding — the home-indirection alternative was
explicitly rejected. The only doctrine touched is freeze-history, and touching it
is the deliverable, not a divergence.

## Peer Feedback

*For the Architect (no plan exists yet — forward-looking, not plan-invalidating):*

- **Doctrine spans two homes.** The reconciled freeze-history doctrine + composition
  rule must land consistently in **both** `skills/partition/SKILL.md:384-387` (+
  checklist `:409`) and `partition-methodology.md:237-257`; editing one leaves the
  invariant and the mechanical rule disagreeing. ARCHITECTURE.md's prose (`264-266`)
  also states the current doctrine and regenerates via `/jim:arch` post-build.
- **Commit fold-in to confirm.** Because `commit-rename docs` auto-stages the whole
  moved spec-dir pair (`:338`), rewrite's edited numbered bodies appear to ride the
  existing docs commit with no choreography change — confirm the auto-stage covers
  them (vs needing them in the explicit `<touched>` set) so an edited body can't be
  left uncommitted.
- **Intentional doctrine change.** This spec deliberately supersedes 038 AC #14 /
  SKILL.md's current "no mode edits a numbered spec's content." The reconciliation
  is the deliverable — flagged so the change is recorded, not silent.
