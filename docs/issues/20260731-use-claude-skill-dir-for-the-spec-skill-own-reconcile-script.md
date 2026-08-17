---
id: 20260731-use-claude-skill-dir-for-the-spec-skill-own-reconcile-script
num: 162
title: "Use CLAUDE_SKILL_DIR for the spec skill own reconcile script"
status: open
priority: low
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T11:48:47Z
updated: 2026-08-13T11:36:20Z
origin: docs/specs/sdlc/000-blueprint/spec.md
---

## Description

## Description

`/jim:verify sdlc` scored the `allowed-tools-exact` invariant (critical) a
partial. The first half holds across the whole territory — no in-scope skill
declares a bare `Bash(bash *)`, and every declared clause mirrors its body's
actual call sites.

The gap is the own-skill sigil. `spec` is the only in-scope skill that ships a
`scripts/` directory, and it grants and calls its own script with the cross-skill
sigil:

- `skills/spec/SKILL.md:10` — `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/spec/scripts/reconcile.sh *)`
- `skills/spec/SKILL.md:371` and `:384` — the two call sites, same sigil

`ARCHITECTURE.md:516` states the rule: `${CLAUDE_PLUGIN_ROOT}` for cross-skill
invocations, `${CLAUDE_SKILL_DIR}` for own-skill. Every other own-skill caller in
the repo uses the required sigil (`skills/conf`, `skills/file`, `skills/ledger`,
`skills/meta-test`, `skills/verify`) — including `meta-test`, which also invokes
from a fenced block, so the deferred-execution shape does not force the wider
form.

## Why it matters

Grant and body are internally consistent, so the permission still matches at
runtime — the risk is convention drift. `spec` is now the one counter-example a
future author can cite, and the divergence was baked in at plan time
(`docs/specs/sdlc/017-coordinated-spec-identity/plan.md:306` specifies this
form), so it will not self-correct. `${CLAUDE_SKILL_DIR}` also carries a narrower
blast radius: it cannot name a sibling skill's scripts, so the current form
silently widens what the clause's shape implies.

## Fix

Switch the grant and both call sites to `${CLAUDE_SKILL_DIR}`.

Related: issue #52 records the same invariant partial for `issue`, `partition`,
and `meta-matrix` — this is a distinct site not covered there.

Surfaced by a `/jim:verify sdlc` run during the `sdlc/018` build.

## Re-grade

**2026-08-13. `critical` → `low`.**

Inherited from the `allowed-tools-exact` invariant, not graded from this breach.

The description says it plainly: "Grant and body are internally consistent, so the
permission still matches at runtime — the risk is convention drift." Both sigils
resolve to the same file here. The real argument for fixing it is that
`${CLAUDE_SKILL_DIR}` cannot name a sibling skill's scripts, so the wider form
implies a blast radius the clause does not need — a narrowing worth taking, not a
critical exposure.

Being baked in at plan time is what makes it worth tracking at all: it will not
self-correct, and it is the counter-example a future author can cite.
