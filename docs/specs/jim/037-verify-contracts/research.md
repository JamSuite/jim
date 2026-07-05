---
spec: "docs/specs/jim/037-verify-contracts/spec.md"
status: Active
date: "2026-07-05"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Contract-graph verification

## Anchors

- `skills/verify/SKILL.md:21-33` — the argument-routing table (`--from-review` /
  `--since` / `--appetite`, flag-strip convention); a `--contracts` mode slots
  here. Budget 257/500 — headroom, but the mode's methodology likely warrants
  the skill's first `references/` doc.
- `skills/verify/SKILL.md:77-89` — the VERIFY-OUTCOME record grammar
  (fixed keys, location-only evidence, keyed untrusted blocks). Edge records
  need identity (consumer/provider/entry), a `side` marker, and a finding-class
  mapping (AC #3, Insight 3).
- `skills/verify/SKILL.md:104-110` — appetite precedence chain;
  `verify_appetite_<group>` already resolves per group, so per-side appetite
  (consumer-side check → consumer group's override) works with zero config
  changes (AC #7).
- `skills/verify/scripts/jimverify.sh:147-185` (`cmd_territory`) — extracts one
  group's validated territory from the map; the cross-reference floor needs all
  groups' territories → a new verb (e.g. `edges` / `crossref`), same
  validation discipline.
- `skills/verify/scripts/jimverify.sh:387-418` (`check_conformance`) — **the
  key structural precedent**: the script emits raw set-difference facts
  (`TERRITORY-CONFORMANCE\t<file>`), the skill owns attribution. The
  cross-reference floor should mirror this split (see Recommendations 1).
- `skills/verify/scripts/jimverify.sh:288-350` (`check_pattern`) — grep
  mechanics to reuse: `-e`/`--` guards, `safe_path_param`, sanitized TSV
  emission (`emit_outcome`, L249-256).
- `skills/blueprint/references/reconcile-methodology.md:38-52, 154-166` — edge
  derivation from the dotted `{other-group}.{surface}` key; blast radius read
  from the **persisted pre-write** `## Contract Graph` ("do not re-derive") —
  the boundary-change trigger's affected-edge source (AC #9).
- `skills/blueprint/SKILL.md:93-121` (Step 4a) — the shared grading rule where
  declared provides-entry criticality must be read (AC #8) and where the
  trigger's engine evidence lands; `blueprint/SKILL.md` is 455/500 — additions
  must route to `references/` (fork-grounding.md absorbs the edge clause).
- `skills/blueprint/references/fork-grounding.md:37-44` — "which violations
  reach the fork"; gains the provider-side-edge clause (AC #11).
- `skills/review/SKILL.md:112-126` (Step 4e) + `:202-217` (Step 10) — the
  sensor invocation and VERIFY-OUTCOME hand-off 037 extends; the cross-group
  arm rides the existing `--from-review` invocation (no new invocation site),
  its records simply joining the block.
- `skills/review/scripts/jimledger.sh:222-228` (`cmd_commit_verify`) — takes
  any dir and commits `ledger.md` alone; **passing the specs root works
  unchanged** for the on-demand contract run's self-commit (AC #15). Events:
  `cmd_event` (L230-243) already carries arbitrary `tier=project op=…` kv —
  the 034 reconcile precedent — so no script change for durability.
- `skills/blueprint/assets/blueprint-template.md:20-35` — the Provides/Requires
  entry shapes the check-data annotation must key into;
  `references/check-authoring.md:53-90` — the `verify-checks` grammar +
  `parse_params` (jimverify.sh:258-282) it should mirror.
- `agents/judge.md` — single-invariant, territory-scoped, read-only; an edge
  side is structurally identical input (rule text = the provides entry +
  guarantee; scope = that side's territory). Extend wording vs mint a sibling
  (035 Insight 5's reuse-vs-mint, now for edges).
- Tests: `tests/jimverify.sh` (546 lines, temp-dir fixtures over
  `testlib.sh`) — the template for new-verb belt tests; multi-group map +
  two-blueprint fixtures follow the `cmd_territory` cases' shape.

## Local Patterns

- **Facts-vs-attribution split** (Bash-vs-Prompt rule, ARCHITECTURE.md):
  deterministic set logic in the script, classification judgment in the skill —
  `check_conformance` is the in-file exemplar.
- **Trusted-channel hand-off**: VERIFY-OUTCOME + Finding-9 provenance; channel
  tags from trusted inputs only (`jimledger.sh files` / `files-range`).
- **Dynamic-suffix config**: `jimconf.sh:96-164` — `verify_appetite_<group>` /
  `verify_command_<name>` resolve with slug-gated suffixes; confirms AC #7's
  "no new knobs" is real (both sides of an edge already have resolvable
  appetites).
- **Test template**: `tests/jimverify.sh` — `run_jimverify` invoker,
  `case_jimverify_*` functions, inline heredoc fixtures, `mktemp` sandbox
  (framework: `skills/meta-test/scripts/testlib.sh`; no mocks — real temp
  dirs/git repos).
- Cross-boundary references in jim itself are literal path strings
  (`${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/…`, `BASH_SOURCE`-relative
  `../../file/scripts`) — exactly the shape a territory-prefix grep catches.

## Prior Art

Conceptual only — no fetches, no version claims. Boundary-enforcement tooling
is an established category ("fitness functions"): import-linter (Python
layer/independence contracts), dependency-cruiser (JS/TS rule-based dependency
validation), ArchUnit (JVM architecture tests), deptrac (PHP layers), Go's
compiler-enforced `internal/` packages, Nx module-boundary tags. Two lessons:
(1) every one of them resolves *language-level imports*, which jim (no AST, no
per-language runtime) cannot honestly replicate — textual territory-prefix
scanning is the honest floor, and these tools are exactly what the **operator
registry** exists for (`verify_command_<name>` wiring a real import checker
gives a mechanical rung jim doesn't fake); (2) their rule configs are
declarative allowlists — the same shape as face check-data (Recommendation 3).

## Security & Performance

- **False-positive risk on the cross-ref floor** (the mechanical-depth risk,
  Insight 1): a territory-prefix grep matches comments, docs, and strings. If
  the floor autonomously emitted `violated`, fail-closed precedence (AC #14)
  would make noise authoritative. Mitigate structurally: the floor emits
  *reference facts*; classification stays judgment (Recommendation 1). The
  deterministic *fact* is what precedence protects.
- **Grep-pattern injection from faces**: face-declared ref patterns are
  untrusted EREs handed to grep — same exposure as `verify-checks` `regex=`;
  reuse `parse_params` + `-e`/`--` guards + `safe_path_param`; suffix-slug
  validation for entry keys (jimconf.sh Finding-1 pattern).
- **Cost containment**: whole-graph judge fan-out is edges × 2 sides;
  `verify_fanout_cap` bounds totals, appetite gates by edge criticality
  (default high ⇒ most edges judge-eligible — the cap is the real bound; the
  report must name the capped remainder, AC #7).
- **Unattended path runs full grounding** (AC #9, revised at scoping):
  floor and judges alike under the existing appetite/fan-out config — the
  036 `auto_review` sensor precedent shows config-controlled judge fan-out
  with narration + durable record satisfies "not a black box"; cost is
  bounded by affected edges × appetite × `verify_fanout_cap`.
- **Cross-repo reality check**: this VM mounts no sibling projects
  (`/mnt/src/` holds only `jim`), and jim itself is single-group — end-to-end
  multi-group exercise happens on the developer's other machines/projects
  (spec Insight 6); CI-able coverage is fixture-only.

## Recommendations

1. **Model the cross-ref floor on `check_conformance`, not `check_pattern`.**
   New jimverify verb(s): parse the persisted `## Contract Graph` table +
   per-group territories, emit `CROSS-REF\t<consumer>\t<file:line>\t<provider>`
   facts (sanitized, capped). The skill classifies each fact against declared
   edges/faces: matching a declared edge → supporting evidence; no edge →
   code-level-leak candidate for judge/report. Deterministic facts stay
   authoritative; noisy classification never does.
2. **Ride the existing scoped adapters end-to-end.** The review-sensor
   extension is edge-record enrichment of the existing `--from-review` run;
   the boundary-change trigger is a scoped engine call whose affected-edge set
   comes from the pre-write graph. Both return one VERIFY-OUTCOME block —
   Insight 3's extension is additive keys (`side=`, edge identity,
   `class=`), never a second protocol.
3. **Face check-data as a keyed fenced block** mirroring `verify-checks`
   (e.g. `contract-checks`, keyed by the backticked surface name slugified):
   optional `criticality=`, `provider-ref=<ERE>`, `consumer-ref=<ERE>`,
   optional `scope=`. One declaration read by both the engine (appetite) and
   Step 4a (grading) satisfies AC #8's single-concept requirement. Grammar
   reuses `parse_params`; template + `check-authoring.md` reach-back mirrors
   035 Insight 2.
4. **Ledger/commit shape is already sufficient**: events via
   `event <specs-root> verify … tier=project op=contracts …`;
   self-commit via `commit-verify <specs-root>` unchanged — verify is already
   in `LEDGER_STAGES`. Zero jimledger.sh change anticipated for the on-demand
   run; counters (`edges=`, per-class) follow the 034 seven-counter pattern.
5. **Extend `agents/judge.md` rather than minting a sibling** — the input
   contract (one rule, one scope, structured verdict) fits an edge side;
   wording generalizes ("one invariant — or one side of one contract edge").
   Revisit only if the prompt bloats past the ~800-token agent budget.
6. **Dead-surface scan = inverted cross-ref facts**: a provides entry with no
   declared edge and no `CROSS-REF` fact from any mapped consumer territory —
   pure set logic over Recommendation 1's output, no extra scan pass; runs
   only in the whole-graph grain (AC #4), degrading to informational under
   partial coverage.

**Alignment:** This approach aligns with VISION's human-in-the-loop and
"transparency over automation" principles (floor-only unattended writes; judge
fan-out only under human eyes; no new knobs) and follows ARCHITECTURE.md's
locked patterns: the Bash-vs-Prompt split (deterministic facts in
`jimverify.sh`, classification in the skill), one-level subagent nesting
(verify stays inline), the never-execute-config/data boundary (the floor only
greps; registry commands remain the sole tooling bridge), and the
`valid-relpath`/slug validation discipline at every untrusted-input seam. No
divergence from locked constraints identified.

## Peer Feedback

*For the Architect (no plan exists yet — forward guidance, not invalidation):*
AC #14's "deterministic floor evidence is never overridden" must be
interpreted per Recommendation 1 — the protected floor output is the
*reference fact*, not an autonomous violated-verdict; classification of a
fact into leak/holds stays with the skill/judge layer. This keeps fail-closed
precedence sound despite the floor's inherent textual false-positive rate.
