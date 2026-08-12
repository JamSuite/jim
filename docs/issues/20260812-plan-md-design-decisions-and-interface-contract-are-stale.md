---
id: 20260812-plan-md-design-decisions-and-interface-contract-are-stale
num: P-20260812-plan-md-design-decisions-and-interface-contract-are-stale
title: "plan.md design decisions and interface contract are stale"
status: open
priority: medium
labels: [docs, plan]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:59Z
updated: 2026-08-12T21:53:59Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`plan.md` has never been amended since the build. A reader taking it as current is
misled on four design decisions and on most of the `place.sh` interface contract.

## Design decisions that are now false

- **DD 2 (`plan.md:27`) and DD 9 (`:70`)** — their load-bearing claims are "zero
  edits to the eight surfacing skills' batch blocks", "no §7a contract change for
  callers", "one edit, eight inheritors; no cross-group SKILL.md changes". Shipped:
  **11 SKILL.md files plus 3 reference files** edited outside the emitter
  (`brainstorm`, `build`, `debug`, `issue`, `partition`, `plan`, `research`,
  `review`, `sec`, `spec`, `verify`; plus `partition/references/`,
  `blueprint/references/fork-grounding.md`,
  `blueprint/references/reconcile-methodology.md`). §7a's canonical snippet is now
  `new.sh (--auto | --reviewed) …` and callers must handle rc 2 and rc 4.
- **DD 5 (`:45`)** — "the destination's index is always current — **reads never
  regenerate**". Every routed read reindexes (`place.sh:1740`, `:1039`). The code
  and `ARCHITECTURE.md` both now say so and explain why; the plan does not.
- **DD 8 (`:63`)** — specifies `commit <token> --msg <verb> [--msg-id <slug>]`.
  The contract block at `:137` and the code use `--verb`/`--id`. The plan
  contradicts itself; the code follows the contract block.

## Interface-contract divergences (`plan.md:121-156`)

| Planned | Shipped |
| :--- | :--- |
| `JIM_PLACE_ACTIVE=1` in the wrapped command's env | does not exist anywhere; shipped pair is `JIM_PLACE_TOKEN` + an unplanned `JIM_PLACE_PREFIX` |
| `run … --verb <enum>` mandatory | optional on a `--read` run |
| `{}` only | `{}` **and** `{token}`, matched by position |
| exit codes `0 / 2 / 3` | also **1** — live and reachable on a success path: `begin --read` returns 1 *with* a usable handle when the index cannot be regenerated |
| — | the `mode` verb is absent entirely, though every entry script calls it and `/jim:partition` holds a grant for it |
| `new.sh` stdout under placement | now publish-conditional; on failure the same bytes go to stderr under a marker |
| — | `new.sh` rc **3** and rc **4** unlisted |

## Two more

- **Task 13's verify (`:223-233`)** is self-contradictory with task 1: it demands a
  deletion-free `tests/` numstat while task 1 requires editing a pre-existing
  assertion (`tests/jimconf.sh:495`). The remediation widened it by rewriting three
  more existing cases.
- **The File Manifest under-scopes `jimconf.sh` (`:109`)** to "KEYS, defaults, the
  bare-name arm". The round changed the **shared resolver's contract** for every
  consumer in the repo — a value-form refusal and a locate-and-refuse that make a
  run from a subdirectory fail. Issue-backed, but plan-unsanctioned.

## Action

Amend `plan.md`'s DD 2, DD 5, DD 8, DD 9 and the Interface Contracts block to
record what shipped — or, if the project prefers plans to stay as-written, add a
single dated **Divergences** section at the end naming each and pointing at the
issue that decided it. Either is fine; leaving it as-is is not, because `plan.md`
is what a resuming reader opens for the CLI contract.

Restate task 13's property as "no pre-existing *fixture* is weakened", verified by
neutering rather than by a deletion-free numstat.

Add rc 1 to the contract, and add a line to `skills/issue/SKILL.md:266-278`
telling the insights step that `begin --read` may exit 1 with a usable
`<token>\t<dir>` — today §8 documents only the stdout shape, so an agent treating
non-zero as failure abandons the verb on a degraded-but-serviceable view *and*
strands the handle.

One item with no task, AC or issue behind it at all: `place.sh:83-89` asserts the
script "raises the corpus's bash floor from 4.0 to 4.3". Neither the new floor nor
the prior 4.0 is recorded in `ARCHITECTURE.md`, `README.md`, `WORKFLOW.md`,
`CLAUDE.md` or `BLUEPRINT.md`, and nothing checks it.
