---
spec: "spec.md"
status: Active
date: "2026-05-20"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Security Agent and Skill

## Anchors

### 1. `/jim:spec` insertion point for Skill(jim:sec)

`skills/spec/SKILL.md:156–165` — Step 9 is the Socratic self-check via `Skill(jim:spec-check)`; Step 10 is the present-and-approval prompt. The sec review inserts between Step 9 (after all spec-check iterations complete) and Step 10's approval question. The current `allowed-tools` line is `skills/spec/SKILL.md:10`:

```
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *) Skill(jim:spec-check)
```

`Skill(jim:sec)` must be added to this line. The gate pattern mirrors `skills/build/SKILL.md:73–81` (sentinel + lean-IF): read `auto_sec_review` via jimconf.sh, branch on `"true"` vs. default. The conversational-offer branch is plain prose with no Skill tool call.

### 2. `/jim:plan` insertion point for Skill(jim:sec)

`skills/plan/SKILL.md:107–117` — Step 8 is present-and-stop. There is no Skill-invocation precedent in `/jim:plan` today; its `allowed-tools` line at `skills/plan/SKILL.md:11` is:

```
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)
```

The sec review inserts after Step 7 (DoD self-check) and before Step 8 (present and stop). Both `Skill(jim:sec)` and `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh *)` need to be added to `allowed-tools` (the latter for the flag read, following the pattern at `skills/build/SKILL.md:10`).

### 3. Skill-to-skill invocation — canonical shape

Three established precedents, all sharing the same shape:

- **`/jim:build` → `/jim:arch`**: `skills/build/SKILL.md:10` (`allowed-tools: ... Skill(jim:arch)`); invocation at L119–121. Target path injected from a `SET` result.
- **`/jim:spec` → `/jim:spec-check`**: `skills/spec/SKILL.md:10` (`allowed-tools: ... Skill(jim:spec-check)`); invocation described at L158–165. Path passed explicitly as `args`.
- **`/jim:meta-matrix` dispatcher**: `docs/specs/jim/014-meta-matrix/plan.md:18` — enumerates four explicit tokens in `allowed-tools`; no wildcard form.

The `$ARGUMENTS` non-auto-forward constraint is empirically confirmed: `docs/specs/jim/014-meta-matrix/plan.md:552` records that S3 probe observed `$ARGUMENTS` rendered as empty when invoked via the Skill tool. The spec dir path must be passed explicitly via the `args` parameter.

`ARCHITECTURE.md:244–245` is the canonical documentation of this pattern, including the first-invocation trust-prompt behavior (workspace-scoped acceptance on first use).

### 4. `resolve()` prefix-dispatch mechanics

`skills/conf/scripts/jimconf.sh:91–107` — the `resolve()` function. Key lines:

- L93: `if [[ "$cli_key" == require_* || "$cli_key" == auto_* ]]; then` — flag keys get `toml_key="$cli_key"` (no `_path` suffix).
- All other keys get `toml_key="${cli_key}_path"`.
- L42: `readonly KEYS=(...)` — the KEYS array where new keys must be registered.
- L48–63: `default_for()` — the case-statement that must receive a new arm for any new key.

To add `auto_sec_review` (or `require_sec_review`): add the new CLI key to `KEYS` at L42, add a `case` arm in `default_for()` at L48–63 returning `"false"`, and add a corresponding entry in `jimconf.toml.example`.

Test-case anchors: `tests/jimconf.sh:241–288` — four cases covering `require_pre_commit`, `require_pre_completion`, and `auto_arch_feedback` default/override pairs. New cases follow this exact shape: `case_<key>_default()` (empty dir, `cd "$dir" && bash "$SCRIPT" get <key>`, `assert_eq ... "false"`) and `case_<key>_overridden()` (fixture with `<key> = "true"`, run -c, assert_eq `"true"`).

`tests/jimconf.sh:109–128` — `case_list_outputs_all_keys` asserts line count = 11 and names every key. This test must be updated when a new key is added (line count becomes 12).

### 5. Path-key registration for `security_adhoc_path`

`skills/file/scripts/jimfile.sh:61` — `readonly KINDS=(spec plan research debug brainstorm)` — does NOT need updating for a path-typed config key (KINDS controls artifact kinds, not config keys).

For a new path-typed key (`security_adhoc_path` or similar): add to `jimconf.sh:42` KEYS array, add `security_adhoc) echo "docs/security" ;;` (or equivalent) in `default_for()`, add to `jimconf.toml.example`. This mirrors how `debug` and `brainstorms` are registered (`jimconf.sh:55–56`).

`jimfile.sh` only needs changes if a new `path <kind>` subcommand is introduced (e.g., `jimfile.sh path security <topic>` for collision-resolved output paths). Following the `debug` pattern at `jimfile.sh:241–272`, a `security` kind would add an entry to `KINDS` at L61 and a `case` arm in `cmd_path()` at L230. This is optional — the spec only requires a configurable location; the skill can construct the path itself.

### 6. Agent persona conventions

`agents/pm.md:1–41` and `agents/architect.md:1–41` — both follow this shape:

- **Frontmatter (≤10 lines):** `name`, multi-paragraph `description` with 3 `<example>` blocks (context, user/assistant, commentary), `skills` list, `tools` list, `model: sonnet`.
- **Body (≤84 lines):** H2 sections — "You are the [role] for jim — [tagline]" (one sentence), `## Context` (reference paths, no inherited context), `## Core Principles` (3–5 bullets, active voice), `## Process` (delegates to active skill), `## Constraints` (bullets, negative form).
- `agents/pm.md:39` — `tools: [Read, Write, Edit, Glob, Grep, Agent(researcher)]`; `agents/architect.md:39` — same plus no Agent in current list.

`@jim:security` will declare `skills: [sec]`, `tools: [Read, Write, Edit, Glob, Grep]` (no code writes, no agent spawning), `model: sonnet`. The `## Engineering Standards` section in `pm.md:63–69` is PM-specific; the security agent equivalent is a `## Analysis Standards` section (freeform review first, systematic sweeps second, never auto-modify artifacts).

`ARCHITECTURE.md:147` — "Agent body ≤ 800 tokens."

### 7. STRIDE categories — authoritative source

Microsoft's canonical six: **Spoofing / Tampering / Repudiation / Information Disclosure / Denial of Service / Elevation of Privilege**.

Authoritative source: Microsoft Learn, "Threats — Microsoft Threat Modeling Tool" — `https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats` (last updated 2026-03-04). The table at that URL names all six with descriptions. This is the Microsoft SDL tool's official documentation — cite it in the skill body and `references/security-dod.md` to close any re-derivation risk.

### 8. LINDDUN categories — authoritative source and naming-version note

**Current (linddun.org v2):** Linking / Identifying / Non-repudiation / Detecting / Data Disclosure / Unawareness & Unintervenability / Non-compliance.

Authoritative source: `https://linddun.org/threat-types/` — maintained by the DistriNet Research Unit, KU Leuven. NIST references LINDDUN at `https://www.nist.gov/privacy-framework/linddun-privacy-threat-modeling-framework`.

**Naming-version divergence (flag for architect):** The spec (Insight 8) lists the older names — Linkability / Identifiability / Non-repudiation / Detectability / Disclosure of information / Unawareness / Non-compliance — which come from the 2010-era academic publications. The current linddun.org uses the abbreviated names above (L=Linking, not Linkability; D=Detecting, not Detectability; D=Data Disclosure, not Disclosure of information). The seventh category is now "Unawareness & Unintervenability" not just "Unawareness." The architect should pick one naming version for the skill body and cite the source — using current linddun.org names is recommended for longevity.

### 9. Existing security boundary references

`ARCHITECTURE.md:214–219` — Security Considerations section. Documents: (a) all input comes from human developer via Claude Code (no external input accepted by agents); (b) no secrets stored; (c) file system write prohibition list (`.git/`, `~/.ssh/`, `node_modules/`, `.venv/`, `.env`, `.env-*`); (d) `.gitignore` exclusions for `docs/prior-art/` and `Z_*` files; (e) no automated tool-boundary enforcement (depends on Claude Code's agent declarations and model instruction-following).

These are the "already-documented trust boundaries" the architecture-grounded AC refers to. The sec skill should read ARCHITECTURE.md before analysis and treat the existing trust model as baseline context, not re-derive it.

### 10. Test framework anchors

`skills/meta-test/scripts/testlib.sh:1–61` — canonical conventions header: `case_` prefix discovery, `OUT`/`ERR`/`RC` globals, `fixture()` and `empty_dir()` helpers, standalone-runnable tail pattern (`BASH_SOURCE[0]` guard + `FILTER="${1:-}"` + `run_discovered_cases`).

New test file `tests/jimconf.sh` (update) or `tests/sec.sh` (new) follows: source testlib via BASH_SOURCE-relative path; define `run()` invoker; define `case_auto_sec_review_default()` and `case_auto_sec_review_overridden()` following `tests/jimconf.sh:272–288` shape exactly.

If `security_adhoc_path` is added as a path-typed key, follow `tests/jimconf.sh:62–98` (full/partial override cases) for the path-override test shape.

## Local Patterns

**Skill-to-skill gate pattern** — `skills/build/SKILL.md:73–81` is the canonical sentinel form for a boolean config flag branching behavior. The `auto_sec_review` gate in `/jim:spec` and `/jim:plan` uses the same shape: `SET auto_sec_review = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get auto_sec_review`` + lean-IF branch. The conversational-offer branch is plain English prose (no Skill tool call).

**Ad-hoc path pattern** — `jimconf.toml.example:17–22` shows `debug_path` and `brainstorms_path` as the template for an `security_adhoc_path` key. Default should follow the `docs/debug` / `docs/brainstorms` convention (e.g., `docs/security`).

**Differential update for re-runs** — `skills/spec/SKILL.md:188–196` (differential update path) is the precedent for "read existing, summarize, Edit not Write." The re-run AC reuses this pattern within the security skill.

**Findings-in-conversation default** — no existing skill delivers findings purely in conversation without writing a file; the ad-hoc default is a new pattern. The closest analog is `/jim:spec`'s "present and stop" — deliver the review as conversational markdown, offer to write.

**Test shape** — `tests/jimconf.sh:39–288` — the complete test file with 19 cases is the template for new bash script tests. `/jim:meta-test scaffold sec` would generate a starter file following the same shape.

## Prior Art

### Tier 1 — Study Closely

**Fork PR #5 design (fork/sec-skill branch)**

| File | What It Is | Why It Matters |
|------|------------|----------------|
| `fork/sec-skill:docs/brainstorms/20260411-sec-skill.md` | Framework comparison rationale; STRIDE/LINDDUN/CIA selection grounding | Framework selection logic; rationale for rejecting OWASP/DREAD/ATT&CK is load-bearing |
| `fork/sec-skill:docs/specs/jim/010-sec/spec.md` | Original spec for /jim:sec | Prior user-story set; acceptance criteria shape; delta to current spec 016 is the adaptation surface |
| `fork/sec-skill:docs/specs/jim/010-sec/plan.md` | Original implementation plan | File manifest, design decisions, interface contracts — concrete architecture decisions made before current idioms existed |
| `fork/sec-skill:agents/security.md` | @jim:security agent persona | Starting point for the new agent — needs adapting to current agent body conventions |
| `fork/sec-skill:skills/sec/SKILL.md` | /jim:sec skill body | Main adaptation target — rewrites needed for sentinel-form directives, allowed-tools narrowing, Skill(jim:*) invocation pattern |
| `fork/sec-skill:skills/sec/assets/security-template.md` | Output format for security.md artifacts | Finding structure, severity vocabulary, sweep coverage shape — carries over with minimal changes |
| `fork/sec-skill:skills/sec/references/security-dod.md` | DoD checklist for security reviews | Completeness checklist — adapt to current `references/` conventions |

Note: These files must be read via `git show fork/sec-skill:<path>` at plan/build time. They predate the sentinel-form directive vocabulary (spec 011), allowed-tools narrowing (spec 012), and `Skill(jim:*)` invocation pattern (spec 013/015). Every directive in the fork skill body will need rewriting.

### Tier 2 — Study for Specific Patterns

**`docs/notes/gate-aware-security-review.md`** — The fork's note that surfaced the gate-aware branching requirement. Documents the precise failure mode of "always-offer" text in skill bodies and establishes the `auto_sec_review` flag's design rationale. The "auto-run vs halt-and-instruct" analysis at L33–39 is directly relevant to Insight 1 Option B vs Option A. The precedent it cites (`plan/SKILL.md` Step 2 research gate) is now at `skills/plan/SKILL.md:42–46`.

**`docs/notes/fork-porting-roadmap.md:36–43`** — Security sequencing context; confirms that `/jim:backlog` is sequenced after `/jim:sec` specifically so security.md scanning can be native, validating the Out of Scope deferral of backlog routing.

## Security & Performance

**No `source`/`eval` in any new bash.** `jimconf.sh:205–221` (implementation notes §3) documents the "never source" security model — the new flag and path keys follow the same parse-only pattern.

**Skill reads ARCHITECTURE.md and target files.** The security skill may read sensitive files if the user points it at config files, `.env.example`, or similar. The existing prohibition (`ARCHITECTURE.md:217`) against writing to `.env`, `.env-*` is an existing boundary — the sec skill must not write to any file the user did not explicitly opt into.

**Ad-hoc mode: no write by default.** The spec AC is that ad-hoc mode delivers findings in conversation by default, with write as opt-in. Violating this (writing a file unsolicited) would be a trust boundary violation — the developer did not ask for a file.

**Findings are advisory-only.** The spec is explicit: the workflow must never hard-block on findings. If the skill ever STOPs approval unconditionally (rather than surfacing findings and asking), that is a spec violation with UX impact on every auto-invoke path.

**Skill-to-skill invocation trust prompt.** `ARCHITECTURE.md:245` documents that the first invocation of a new plugin skill in a workspace triggers a consent prompt ("Use skill 'X'?"). `@jim:security` and `/jim:sec` will each require this first-use acceptance. Not a security risk but a UX friction point to document for users in README.

## Recommendations

1. **Flag naming (Insight 1):** Architect must choose between `require_sec_review` and `auto_sec_review`. The evidence favors `auto_sec_review` — the semantic is "auto-invoke vs. offer," matching `auto_arch_feedback` exactly (`jimconf.sh:60`). `require_sec_review` stretches the established "halt if missing" semantic (`require_pre_commit`, L58). The gate-aware-security-review note (`docs/notes/gate-aware-security-review.md`) already frames the behavior as "auto-run vs. offer" — the `auto_*` family is the right home.

2. **Lens-selection mechanism (Insight 2):** Auto-detect via artifact presence is the lowest-friction option and matches the fork design. Caller-passed mode (Option B) is viable only if `/jim:spec` and `/jim:plan` always pass a mode string — any invocation path that skips the mode arg would silently fall back to auto-detect anyway, making Option B a hybrid regardless. Recommend auto-detect; the architect should confirm.

3. **LINDDUN category names:** Use current `linddun.org` names (Linking, Identifying, Non-repudiation, Detecting, Data Disclosure, Unawareness & Unintervenability, Non-compliance) in the skill body and `security-template.md`. Cite `https://linddun.org/threat-types/` as source. The older names from academic papers are still found in secondary sources but linddun.org is the maintained authoritative reference.

4. **ARCHITECTURE.md additions (Open Question 2):** The plan should explicitly allocate tasks to add `@jim:security` and `/jim:sec` to the Core Components section and update the Scripting Layer section to document any new config keys. The open question in the spec is not rhetorical — it is a plan-time deliverable.

5. **`security_adhoc_path` key scope:** The simplest registration is a path-only key (`security_adhoc_path`, default `"docs/security"`) following the `debug` and `brainstorms` pattern. The two-stage knob (boolean flag + path, Insight 5 Option C) introduces a second config surface for a marginal UX benefit — the skill can check the flag and only write when `"true"`. If that extra gate is desired, the flag family should be `auto_sec_adhoc_write` (matching the `auto_*` prefix convention). Architect to decide.

6. **`jimfile.sh path security <topic>` subcommand:** Optional. The spec does not require collision-resolved path generation; the skill can construct the path inline using `jimfile.sh date` + `jimfile.sh slug`. Only add the `path security` subcommand if the plan determines the skill needs the collision-resolution guarantee.

## Peer Feedback

**For Architect — Insights 1, 2, 3, 5, 9 are unresolved mechanism choices.** The spec deliberately deflected these to the plan phase. All five need an explicit Design Decision block in the plan. The research provides anchoring evidence for each:

- **Insight 1 (flag family):** `auto_*` is the right semantic (`jimconf.sh:60`, `gate-aware-security-review.md`). Architect should confirm with the developer before committing to `require_sec_review` if that language was stated explicitly — the note at `docs/notes/gate-aware-security-review.md` uses "require" language but the analysis confirms `auto_*` semantics.
- **Insight 2 (lens-selection):** Auto-detect is lower surface; caller-passed is only needed if the plan wants to make the lens selection testable without file presence.
- **Insight 3 (Advisory routes):** Option A (Advisory routes to Spec or Plan like others) is simplest and produces a consistent schema that `/jim:backlog` can later refactor. The `route: backlog` forward-compat field (Option C) is premature scaffolding.
- **Insight 5 (adhoc path config):** `security_adhoc_path` mirrors `debug_path`; add `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh *)` to `/jim:sec`'s `allowed-tools` if the flag read goes through `jimconf.sh` directly (per ARCHITECTURE.md Scripting Layer class boundary: value-typed keys route to jimconf.sh, path-typed keys route to jimfile.sh).
- **Insight 9 (framework-selection mechanism):** Option A (skill-prose) is consistent with the existing jimconf.toml philosophy (paths + behavioral gates only, no LLM steering). The spec explicitly recommends it.

**For Architect — LINDDUN category naming version.** The spec's Insight 8 names categories using older academic terminology (Linkability, Identifiability, Detectability, "Disclosure of information", "Unawareness"). The current linddun.org uses shorter names and the seventh category is now "Unawareness & Unintervenability" — a meaningful extension beyond "Unawareness" alone. The architect should align on the current names and cite `https://linddun.org/threat-types/` as the source rather than the older papers, to prevent the skill body from drifting out of sync with the maintained framework.

**For Architect — `/jim:plan` has no prior Skill-to-skill call site.** Adding `Skill(jim:sec)` to `/jim:plan` requires both adding the permission token and adding `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh *)` for the flag read — two `allowed-tools` additions, not one. The plan's file manifest must list `skills/plan/SKILL.md` as modified.

**For PM — Open Question (workflow halt vs advisory).** The spec's first Open Question flags a potential future enhancement where Critical findings halt approval. The current architecture (advisory-only, never blocking) is clean and unambiguous. If the developer ever asks for hard-blocking, that is a spec-level change that reopens this spec or creates a follow-on. The current spec is correct as written — no action needed, but the PM should be aware the question is live.

Sources:
- [LINDDUN threat types — linddun.org](https://linddun.org/threat-types/)
- [NIST LINDDUN reference](https://www.nist.gov/privacy-framework/linddun-privacy-threat-modeling-framework)
- [Microsoft STRIDE — Threat Modeling Tool threats (Azure Learn)](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [LINDDUN — KU Leuven/DistriNet](https://linddun.org/)
