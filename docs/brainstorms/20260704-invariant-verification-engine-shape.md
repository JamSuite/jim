# Brainstorm: Invariant verification engine shape

*2026-07-04*

Origin: issue #22 (`20260630-build-the-invariant-verification-engine`), the
deferred verification slice of the `000-blueprint` initiative (spec 029's
"records but runs nothing" gap). Inputs accumulated since filing: spec 033
(territory declarations, `group_territory` mode strength), spec 034 (contract
graph, blast radius, LLM-judged detectors awaiting mechanical hardening),
spec 031 (violation fork awaiting hardening).

## The engine's inbox (mandates routed here by other specs)

1. **Core job** (029): execute the recorded verification methods — check a
   group's code against its blueprint's invariant table. Fixed cheap floor +
   tunable expensive ceiling; invariant type picks the rung; criticality keys
   the appetite (global default + per-group override).
2. **Territory enforcement** (033 AC #8): territory declarations are data-only
   today; the engine is the consumption-time backstop (`valid-relpath` at use;
   floor checks scoped by territory).
3. **Map-tier checking** (033): BLUEPRINT.md roles/relations/territories are
   invariant-class content; `group_territory` mode sets floor strength.
4. **Detector hardening** (031 violation fork; 034 leak/dead/breaking) — both
   LLM-judged today, awaiting mechanical hardening here.
5. **Blast-radius-scoped fan-out** (034): the graph picks *where* the ceiling
   spends; criticality picks *how hard*.
6. **Review as sensor**: `/jim:review` verifying against the *living*
   invariant set, not only the point-in-time spec.
7. **Retirement direction**: load-bearing sources run in reverse — flag
   invariants no source justifies.

## Design tensions (frame)

- **A. Data → execution across the trust boundary** — the 026–034 lineage
  says artifact content is data, never instruction; the engine's job is to
  act on methods recorded in a markdown artifact.
- **B. What "mechanical floor" portably means** — bash+POSIX, no third-party
  deps, language-agnostic: no portable AST tool exists.
- **C. Where it lives** — new skill vs. `/jim:blueprint` mode (line budget
  exhausted) vs. `/jim:review` capability. Four trigger points want it.
- **D. Slicing** — plainly multiple specs.

## A. The data→execution boundary (discussion)

jrko's framing: jim has been developed security-conscious for the untrusted
3rd-party-repo case, but its primary function is trusted 1st-party repos. If
data-only genuinely cripples trusted abilities, relax and delegate to the
operator via config/documentation.

Analysis — where the risk actually sits:

- **The method enum itself costs ~nothing.** Every plausible method falls
  into a small taxonomy (shape/grep, command, test, judge, swarm). A closed
  enum constrains nothing real.
- **The fault line is the *parameters*, split by risk class:**
  - *Inert parameters* — grep patterns, globs, judge prompts, criticality:
    safely consumable from the blueprint (invoked with `--` guards, no eval,
    no shell interpolation). Zero constraint.
  - *LLM rungs* (judge/swarm): no execution; existing untrusted-content
    wrapping discipline covers prompt-injection steering. Zero constraint.
  - *Executable parameters* — "run this command/script": the only class
    where data→execution is real. This is the entire battleground.
- **The laundering path that makes even 1st-party repos interesting:** code
  content flows into blueprints at generation (amalgamated *from* code), and
  `auto_blueprint` writes additive changes unattended. So: adversarial (or
  merely careless) code comment → additive invariant with a `verification:
  run scripts/x.sh` → engine executes it. 031 closed this laundering path
  for *intent*; the engine would reopen it as *RCE* unless commands get a
  provenance gate.
- **Two existing backstops soften everything:**
  1. jim already executes repo toolchains — `/jim:build` runs project tests.
     The engine adds no *new* capability class, only a new *provenance* for
     command strings.
  2. jim rides Claude Code's own permission system — every Bash call the
     engine makes hits the harness permission model unless the operator
     allowlisted it. The engine need not rebuild a permission layer; the
     design question is provenance hygiene + unattended-mode cleanliness.

Candidate designs for the executable class:

- **(a) Operator-owned command registry.** Blueprint records `method:
  command, ref: <name>`; jimconf (or a `verify_commands` table) maps name →
  command string. The blueprint *proposes*, the operator's config channel
  *activates*. Fits "decisions → map; dials → jimconf" doctrine; auto mode
  can never mint new executable surface. Cost: one config entry per command.
- **(b) Blueprint-inline + first-run confirm.** Commands live in the
  blueprint; engine prompts before first execution (optionally hash-pinned
  approvals). More friction at run time, less at authoring time.
- **(c) Trust knob.** `verify_exec = true`-style relaxation documented as
  trusted-repo-only; engine runs blueprint-recorded commands directly.

**Resolved: (a), the operator-owned registry.** Closed method enum; inert
parameters consumable from the blueprint; executable commands referenced by
name and activated only through the operator's config channel. Rationale
(jrko): jim is usable out of the box without config, but advanced features
and repo-specific tooling are *expected* to require setup — jim can't know a
repo's toolchain beforehand anyway. `auto_*` settings are never default, and
enabling one means accepting its trade-offs. The goal posture: a reasonably
sane and secure baseline, with the user configuring jim to their preferences
and risk appetite. No `verify_exec` relaxation knob; revisit only if the
registry proves annoying in practice.

## B. What the mechanical floor can portably be

Constraint recap: jim's own scripts are bash + POSIX, no third-party deps,
language-agnostic host projects. There is no portable AST/type/lint tool jim
can ship. So the issue body's "lint / type / AST" floor decomposes honestly
into three provenance tiers:

1. **jim-native floor** — zero config, out of the box. A small closed set of
   deterministic check primitives jim implements once (a `jimverify.sh`-class
   script), parameterized by inert data from the blueprint and scoped by the
   group's territory:
   - *pattern* checks — grep must-match / must-not-match within a scope
     (polarity + optional count bound);
   - *structure* checks — file/dir existence, naming conventions, containment
     (this is where 033's territory enforcement lands: "group A's code stays
     in its territory" is a containment primitive);
   - cross-boundary variants — e.g. "no file outside <territory> matches
     <pattern>" (import-leak approximation without an AST).
2. **Registry floor** — setup expected. Project lint/type/format/test
   commands via the `verify_commands` registry. Still floor-priced (cheap,
   deterministic) but gated on operator setup, because only the operator
   knows the toolchain.
3. **LLM rungs (the ceiling)** — judge (one invariant, one focused read) and
   swarm (adversarial fan-out), criticality-gated. Also the *fallback* for
   everything inexpressible below: true AST-grade structural claims,
   semantic/behavioral invariants without tests.

Progressive-upgrade model falling out of this: every invariant is at minimum
judge-able (its prose + the code is enough for the LLM rung); adding
structured inert check data upgrades it to the jim-native floor; wiring a
registry command upgrades it to project-grade mechanical. Degradation
mirrors `group_territory`'s mode-strength framing — the blueprint records
what the check *is*, and the engine runs the strongest rung the recorded
data + config afford.

Implication for 029's format (a nudge, same class as 034 Insight 2's
matchable-faces nudge): the invariant table's "verification method" column
likely needs to become a structured `check:` annotation — method from the
closed enum + inert params or a registry ref — optional per invariant, with
absent = judge-rung fallback.

**Resolved: three-tier floor + progressive upgrade adopted.** The blueprint
`check:` format change ships *inside* the engine spec (not a separate
precursor spec); existing blueprints degrade gracefully to the judge rung
until regenerated. AST is explicitly not a jim capability — jim provides
only the optional hook into project-specific tooling (the registry).

## C. Where the engine lives (command surface)

Inputs to the decision:

- `skills/blueprint/SKILL.md` is at/over its line budget (462/500 before
  034 landed; issue #43 tracks reclaiming headroom) — no room for a fifth
  arm, and dispatch there is already crowded.
- The engine is a **reader/checker, never a writer of blueprints** — the
  blueprint surface's single-writer authority is about *writing* the
  artifacts; verification consumes them. Different identity, different tool
  grants (Bash for the native floor + registry commands; Agent fan-out for
  the ceiling).
- Four trigger points: on-demand; `/jim:review` (living-invariant sensor);
  031's violation fork (hardening); 034's reconcile detectors (hardening).
  All reachable via the established inline `Skill()` composition pattern
  (`/jim:build` → `/jim:arch` lineage).
- One-level subagent nesting: the engine fans out judges/swarm, so it must
  always run inline in the main thread — same constraint 027 navigated for
  review. Inline skill-to-skill calls preserve this (caller inline → engine
  inline → engine's fan-out is the single level).

Direction: a **new skill** (working name `/jim:verify`), composed of:

- **`jimverify.sh`** — the deterministic core: executes native-floor
  primitives (pattern/structure/containment) and registry commands, scoped
  by territory (`valid-relpath` re-validation at use), emits structured
  grep-parseable results. Belt-testable in `tests/`.
- **The skill body** — orchestration judgment: parse the invariant table,
  dispatch the floor via the script, decide ceiling spend (criticality ×
  appetite config × blast radius when 034's graph names affected groups),
  fan out the LLM rungs, synthesize the report, offer issues, record ledger
  outcomes (the 031 guard-outcome convention).
- **The judge subagent** — read-only, no write/execute, capability-backed
  (the 027 `jim:investigator` shape). Open: reuse `investigator` if its
  prompt generalizes vs. mint a sibling `verifier` agent — plan-level.

Results doctrine (mirrors 034 AC #3): **no persisted verdict artifact** — a
verification verdict rots into misplaced trust. Report at run time; findings
offered as issues; outcomes durably counted on the ledger. When invoked from
`/jim:review`, results land in review.md's evidence like investigator output.

**Resolved: new skill, named `/jim:verify`; no-persisted-verdict doctrine
confirmed** — "is this group verified?" has no standing answer, only run-time
reports plus the ledger's last-run counters.

## D. Slicing

The seven inbox mandates don't fit one spec. Natural seams:

- **Spec A — engine core** (`/jim:verify`, on-demand, one group per run):
  - closed method enum + the blueprint `check:` format change (029
    reach-back; absent annotation = judge fallback; existing blueprints
    degrade gracefully);
  - `jimverify.sh` native floor (pattern / structure / containment —
    containment *is* 033's deferred territory enforcement, so that mandate
    lands here);
  - `verify_commands` registry (the operator-owned executable channel);
  - judge rung: one read-only agent per invariant needing it (reuse-vs-mint
    investigator decided at plan);
  - criticality-keyed appetite knob, global default + per-group override;
  - report + offered issues + ledger outcome counters.
  - *Deferred out of A:* the full adversarial swarm (judge fan-out is
    enough to start); blast-radius-scoped ceiling spend (needs multi-group
    practice; degrade = fan out per invariant table order).
- **Spec B — pipeline integration**: `/jim:review` as living-invariant
  sensor (drift = divergence from living intent, resolutions fix-code /
  fold-intent wired to the 030/031 fork); 031 violation-fork hardening
  (update mode calls the engine); 034 detector hardening (contract edges as
  checkable invariants); blast-radius-scoped ceiling spend. Could split at
  scoping if it balloons — review-sensor vs detector-hardening is the seam.
- **Spec C — retirement direction**: the load-bearing sources run in
  reverse (verification asserts it, no intent or usage backs it → flag for
  retirement). Deferred until the engine has real-world mileage; depends on
  A (and B for usage evidence via the graph).

Sequencing note: A is exercisable on jim's own single-group repo (native
floor + judge against jim's real 000-blueprint); B's blast-radius and
detector-hardening pieces need multi-group fixtures (034 Insight 5 pattern)
or a real multi-group project — consistent with the roadmap's "begin active
testing with real-world projects."
