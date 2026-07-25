---
spec: "docs/specs/blueprint/002-blueprint-update/spec.md"
status: Active
date: "2026-07-01"
---

# Research: Blueprint update from review

Local-first scan of jim's own skills/scripts (Phase 0). Phase 1 (external
intelligence) skipped — this is an internal wiring feature over existing jim
surfaces, no external APIs or libraries. Phase 2 alignment below.

## Anchors

### Caller — `/jim:review` (where the new step lands)
| Anchor | Why |
|---|---|
| `skills/review/SKILL.md:184-186` (Step 10 terminal "Present and stop") | The blueprint update slots in here — after commit-review (Step 8), before the terminal stop. |
| `skills/review/SKILL.md:134-140` (Step 8 `commit-review`) | Last durable write of the review; the update runs after it. |
| `skills/review/SKILL.md:96-110` (Step 4d verdict) | The `aligned`/`minor-drift`/`major-drift` verdict is the update's primary evidence signal. |
| `skills/review/SKILL.md:13` (`allowed-tools`) | Must add `Skill(jim:blueprint)` — currently absent. |
| `skills/review/SKILL.md:132`, `:33-35` (group from `spec.md` `group:`) | The reviewed group is read here and passed to `jimfile.sh path blueprint`. |

### Exemplar — `/jim:build` (the gate pattern to copy)
| Anchor | Why |
|---|---|
| `skills/build/SKILL.md:212-223` (Step 6 `require_review`/`auto_review` gate) | The exact `SET`/`IF … THEN Skill(jim:review) ELSE offer` block to mirror for the two blueprint knobs. |
| `skills/build/SKILL.md:224-226` (Step 7 completion held) | How a `require_*` flag holds a completion gate — the model for "review not complete until update runs". |
| `skills/build/SKILL.md:136-140` (Step 6.2 `/jim:arch` via Skill tool) | Second skill→skill invocation exemplar (existence-gated). |
| `skills/build/SKILL.md:10` (`allowed-tools` enumerates Skill callees) | Frontmatter must list each Skill callee — mirror for review. |

### Reused generator — `/jim:blueprint` (spec 029)
| Anchor | Why |
|---|---|
| `skills/blueprint/SKILL.md:39-44` (`path blueprint <group>`) | Path resolution — never hand-composed; validates group via `is_valid_slug`. |
| `skills/blueprint/SKILL.md:79-84` (Step 4 generate-vs-diff branch) | Already branches new-vs-update, so AC #8 (no blueprint → generate) is satisfied by reuse. |
| `skills/blueprint/SKILL.md:87-95` (Step 5 `auto_blueprint` gate) | Existing diff-and-confirm + `auto_blueprint` write — the update reuses this verbatim. |
| `skills/blueprint/SKILL.md:14` (`allowed-tools`) | Lists only `jimfile.sh`/`jimconf.sh`; no `Read`/`Write`/`Edit`/`Glob`/`Grep` (see Security). |

### Config + ledger + tests
| Anchor | Why |
|---|---|
| `skills/conf/scripts/jimconf.sh:42` (`KEYS`) + `:60-65` (`default_for`) | Two edits: add `require_blueprint` to `KEYS` and a `require_blueprint) echo "false"` arm. |
| `skills/conf/scripts/jimconf.sh:112-126` (`resolve()` prefix dispatch) | `require_*` is already dispatched — no change; `require_blueprint` resolves automatically. |
| `skills/review/scripts/jimledger.sh:196` (`LEDGER_STAGES`) | `"spec research plan sec build review"` — `blueprint` is NOT a stage; extend only if instrumenting the update. |
| `skills/review/scripts/jimledger.sh:103-113` (`commit-review`) | Path-scoped to `review.md`+`ledger.md` in the *spec* dir — the blueprint lands elsewhere (see Security). |
| `tests/jimconf.sh:385-403` (`require_security` default+override) | Template for a new `case_require_blueprint_*` pair. |
| `tests/jimconf.sh:82-92` (`auto_blueprint`), aggregate cases `:57-58`, `:144-145`, `~:184`, `:230` | The four aggregate cases (defaults/full-override/list/keys) must also gain `require_blueprint`. |

## Local Patterns
- **`require_*`/`auto_*` gate idiom** (build Step 6): `SET x = !\`…jimconf.sh get x\``, then paren-free `IF x == "true" … ENDIF`; fall-through = offer conversationally. Reuse for `auto_blueprint` (auto-write) + `require_blueprint` (blocking).
- **Skill→skill call**: `Skill(jim:blueprint)` with the group as `args`, run **inline** in review's main thread — no subagent nesting (review's investigators are its only fan-out; blueprint runs inline, so the one-level nesting limit is not stressed). `$ARGUMENTS` does not auto-forward — pass args explicitly.
- **Group resolution**: no group variable exists; read `group:` from the reviewed `spec.md` (already loaded in review Step 1) and pass it through.
- **Test framework** (hand-rolled bash, `skills/meta-test/scripts/testlib.sh`): `case_*` fns auto-discovered; `run -c <cfg> get <key>` + `assert_eq`, `empty_dir`/`fixture` helpers. Mirror the `require_security` pair.

## Security & Performance
- **Untrusted evidence (spec AC #9)**: the verdict/ledger/diff/commit content the update reads is attacker-influenceable — treat as data, never instruction. `jimledger.sh metrics` is the only trusted channel and never echoes commit/diff text. Carries the 026/028/029 boundary; no new external surface.
- **Commit-scope mismatch (architect input)**: `commit-review` (`jimledger.sh:103-113`) is path-scoped to `review.md`+`ledger.md` *inside the spec dir* (`--` guard, never `git add -A`). The refreshed blueprint lands in `<group>/000-blueprint/spec.md` — a **different** directory — so it cannot ride the existing commit.
- **Pre-existing gap (noted here, not filed — pipeline-owned)**: `blueprint/SKILL.md:14` `allowed-tools` lists only the two Bash script grants — no `Read`/`Write`/`Edit`/`Glob`/`Grep`, though Steps 2–5 use all of them inline. Latent permission-prompt friction in the reused generator. Recorded at its point of encounter rather than as a separate issue: `/jim:meta-skill`'s `allowed-tools` validation checklist owns this and will catch it when 030's implementation touches `blueprint/SKILL.md` (Rec 2a).
- **Cost**: a full-regeneration per review (re-running 029's whole-group amalgamation) is the expensive path; the spec's **targeted diff** is the cheaper choice and avoids re-scanning the whole group each build. No new deps (bash + POSIX only).

## Recommendations (options for the architect — not decisions)
1. **Where it slots**: a new step in `/jim:review` after `commit-review` (Step 8), before the terminal "Present and stop" (Step 10); add `Skill(jim:blueprint)` to review's `allowed-tools` (`:13`).
2. **Targeted-diff mode (Insight 2 crux)**: `/jim:blueprint` today does a *whole-blueprint* generate/diff-and-confirm. Either (a) extend it with an "update from review" mode that scopes the diff to affected sections using the verdict+diff as the fold source (matches AC #3), or (b) invoke it as-is and accept broader diffs at MVP (cheaper to build).
3. **Commit ownership (open question)**: (a) add a path-scoped `commit-blueprint` verb to `jimledger.sh` mirroring `commit-review`, committed by the update step — durable, fits `require_blueprint`; or (b) leave the blueprint in the working tree for the developer (matches 029, where `auto_blueprint` gates the *write*, not a commit). Lean (a) if `require_blueprint` must guarantee a durable record.
4. **Ledger instrumentation**: optionally add a `blueprint` stage to `LEDGER_STAGES` (`:196`) so the update reports its own runs/duration; skip if it rides silently under review. Touching the fixed allowlist is a deliberate, tested change.
5. **`require_blueprint` wiring**: two `jimconf.sh` edits (`KEYS` `:42`, `default_for` `:60-65`) + the review gate mirroring build Step 6/7. Since review is terminal, the "held completion" is review's own stop, not a downstream phase.

## Alignment
Aligns with VISION.md ("living documents that support agile iteration"; documenting the how/why as code is built) and ARCHITECTURE.md's established patterns: the `require_*`/`auto_*` bare-name convention (human-in-the-loop default), the single-authority scripting layer, skill→skill invocation via the Skill tool, and the untrusted-content trust boundary. No divergence from a locked constraint. `require_blueprint` confirmed net-new (present only in `jimconf.toml.example:51` comment, issue #20, and this spec).
