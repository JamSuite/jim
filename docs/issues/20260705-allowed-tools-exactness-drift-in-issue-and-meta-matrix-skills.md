---
id: 20260705-allowed-tools-exactness-drift-in-issue-and-meta-matrix-skills
num: 52
title: "allowed-tools exactness drift in issue, partition, and meta-matrix skills"
status: open
priority: critical
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T00:28:45Z
updated: 2026-07-09T02:47:40Z
origin: docs/specs/jim/000-blueprint/spec.md
---

## Description

Verify (`/jim:verify jim`) found blueprint invariant **inv-3** violated (judge verdict `partial`).

**Invariant:** `allowed-tools` names the exact script path(s) a skill injects/runs — never a bare `Bash(bash *)` wildcard; own-skill uses `${CLAUDE_SKILL_DIR}`, cross-skill uses `${CLAUDE_PLUGIN_ROOT}`.

The security core holds — there is **no** bare `Bash(bash *)` / `Bash(bash:*)` wildcard anywhere under `skills/`, and every workflow-script grant names an exact path. Two literal divergences keep it from a clean `holds`:

**Gap 1 — `issue` and `partition` skills use `${CLAUDE_PLUGIN_ROOT}` for their own scripts.** `issue`'s `index.sh`, `new.sh`, and `render.sh` and `partition`'s `jimpartition.sh` are owned by their respective skills (under `skills/issue/scripts/` and `skills/partition/scripts/`), so per the "own-skill uses `${CLAUDE_SKILL_DIR}`" clause they should be referenced via `${CLAUDE_SKILL_DIR}/scripts/...`. In both, the frontmatter grant and the body call sites use `${CLAUDE_PLUGIN_ROOT}` instead. `issue` and `partition` are the own-script skills doing this; the other five (`file`, `conf`, `review`, `verify`, `meta-test`) use `${CLAUDE_SKILL_DIR}`.

<untrusted-content>
skills/issue/SKILL.md:6    Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/index.sh *),
                           Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/new.sh *),
                           Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/render.sh *)
skills/issue/SKILL.md:147  bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/new.sh   (body call site, own script)
skills/issue/SKILL.md:155  bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/index.sh (body call site, own script)
skills/partition/SKILL.md:18       Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/partition/scripts/jimpartition.sh *)
skills/partition/SKILL.md:101,102  bash ${CLAUDE_PLUGIN_ROOT}/skills/partition/scripts/jimpartition.sh (body call sites, own script)
</untrusted-content>

Risk is low, not nil: the frontmatter mirrors the body (self-consistent), the grant is still script-specific (not a bare wildcard), and both sigils resolve to the same file when `issue` runs — so no permission-scope hole. But it is a literal divergence from the invariant's sigil convention, and `issue` also uses `${CLAUDE_SKILL_DIR}` for its own asset reads (`:9`, `:77`), so it is not that `${CLAUDE_SKILL_DIR}` fails to resolve in-context.

**Gap 2 — meta-matrix probe family grants a broad `Bash(bash -c *)`.** This grant names no script path and permits arbitrary inline shell (`bash -c '<anything>'`) — the exact least-privilege concern the invariant guards. Three of the four sub-skills carry it with **no matching `bash -c` call site** in their bodies (an over-grant even by the "grep allowed-tools vs call sites" check):

<untrusted-content>
skills/meta-matrix-variable-setting/SKILL.md:8         Bash(bash -c *)  — body uses only !`echo …`, no bash -c
skills/meta-matrix-conditional-evaluation/SKILL.md:12  Bash(bash -c *)  — body uses only !`echo …`, no bash -c
skills/meta-matrix-skill-invocation/SKILL.md:10        Bash(bash -c *)  — body uses only !`echo …`, no bash -c
(only skills/meta-matrix-bash-invocation actually uses bash -c, at rows :32,:40; no documented exemption in ARCHITECTURE.md Permission Conventions)
</untrusted-content>

The meta-matrix family are documented internal test-harness skills (ARCHITECTURE.md:466), but the invariant/ARCHITECTURE rule is phrased "Every `skills/*/SKILL.md`" with no carve-out. Suggested remedies: (a) switch `issue`'s and `partition`'s own-script references to `${CLAUDE_SKILL_DIR}`, or record an explicit convention exception; (b) drop `Bash(bash -c *)` from the three sub-skills that never invoke it, and either scope or document-exempt the one that does.

Origin: `docs/specs/jim/000-blueprint/spec.md` (inv-3, criticality critical). Reported by `/jim:verify jim`; not yet fixed. The `partition/SKILL.md:18` instance was re-surfaced by the spec-042 `/jim:review` living-intent sensor (2026-07-09) and folded into this issue rather than filed separately.
