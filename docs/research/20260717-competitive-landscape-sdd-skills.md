---
spec: "standalone"
status: Active
date: "2026-07-17"
---

<!-- Word budget deliberately exceeded per explicit user direction ("THIS RESEARCH DOC WILL BE LONG… GO DEEP"). The DoD <1500-word rule is overridden for this landscape survey. -->

# Research: Competitive Landscape Refresh — SDD Skills & Frameworks (2026-07)

A capture of all URL's from this file is in 20260717-competitive-landscape.csv 

## Scope & Method

**Goal:** refresh jim's competitive-landscape picture (some references drifted since our last survey) and produce a *per-skill study guide* — Tier 1/2/3 external implementations we can study to evolve each core jim capability: **brainstorm, spec, research, plan, build, security** (plus a cross-cutting **meta / skill-authoring** lane, since jim itself is a Claude Code skills project).

**Method:** 11 parallel research agents, each verifying *current* status (renames / archives / activity) via WebFetch + WebSearch, all **verified as of 2026-07-17**. A local pass extracted every external source our 6 prior research docs (`002-pm-core`, `004-researcher`, `005-architect`, `006-coder`, `016-sec`, `015-spec-refinement`) had cited, so this is a genuine *refresh* of known sources plus a sweep for new ones.

**Fetch gap (mostly closed):** `https://www.claudepluginhub.com/` returned **HTTP 403** twice; per our WebFetch guardrail we did not work around it. Substantive data came through `claudemarketplaces.com` and `skills.sh` (both fetched fine). Its **security topic page alone lists 961 plugins** — the developer surfaced three specific ones from it (two `wshobson/agents` plugins + the Anthropic-official `security-guidance`), now studied and folded into the Security lane below. The remaining 958 are left un-swept by design: at that scale the page is overwhelmingly aggregation of repos already catalogued here, and hand-scraping it is very low expected signal. No other fetch was blocked; the 404s the research-lane agents hit were stale paths that *are themselves findings* (see refresh table).

---

## Landscape Status Refresh (currency deltas since our prior citations)

The headline of this refresh: **several prior Tier-1 sources moved, went dormant, or reorganized.** Fix these across our docs.

| Tool | Prior citation | Current status (2026-07-17) | Action |
|------|----------------|------------------------------|--------|
| **GSD** | `gsd-build/get-shit-done` (cited in 002, 004, 005, 006) | **Archived 2026-06-26** → **`open-gsd/gsd-core`** (6.8k★, v1.7.0 2026-07-15, very active) | **Fix 4 research docs**; refresh VISION.md landscape row |
| **Pimzino/claude-code-spec-workflow** | Tier 1 (005, 006) | **Dormant ~10mo**; maintainer moved to MCP successor **`Pimzino/spec-workflow-mcp`** | Redirect study to successor |
| **zhsama/claude-sub-agent** | Tier 1 (005) | **Dormant ~11mo**, no successor | Downgrade to Tier 3 pattern-mine |
| **cc-sdd** (`gotalab/cc-sdd`) | Tier 3 reference (005, 006) | **v3.0 rework** (Apr 2026): Agent Skills primary, autonomous `kiro-impl`, boundary-first File Structure Plan, `/kiro-spec-batch` (~3.6k★) | **Upgrade to Tier 2** |
| **GitHub Spec Kit** | (004, 005, 006, 015) | ~122k★, **commands namespaced `/speckit.*`**, `--ai*` flags removed v0.10, new `/speckit.analyze` + `/speckit.converge` | Update command syntax in our notes |
| **autonomous-dev** | `agents/researcher-{local,web}.md` (004) | Files moved to `plugins/autonomous-dev/agents/`; **`researcher-web.md` merged into `researcher.md`** (~30★, active) | Fix paths in 004 |
| **research-kit** | `/research.principles` (004) | Command is **`/principles`**; v1.0.20 (Feb 2026, active) | Fix command name in 004 |
| **SuperClaude_Framework** | (004, 005, 006) | v4.3.0; confidence-check now an installable `skills/confidence-check/` (~23.6k★) | Update; extract the gate only |
| **015 sources never cleanly fetched** | Haberlah Medium PRD article; spec-kit `specify.md` (obtained via paste after a prompt-injected fetch) | Still need **first-hand re-pull** | Re-verify before relying on |

New entrants not previously catalogued: **obra/superpowers** (256k★), **Matt Pocock skills** (175k★), **Addy Osmani agent-skills** (78k★), **OpenSpec** (61k★), **Amazon Kiro** (GA), **Spec-Flow**, **BMAD-METHOD** (46k★), **ECC** (`affaan-m/ecc`, formerly everything-claude-code, 230k★), and a rich **security lane** (Trail of Bits, Anthropic's official review action, `fr33d3m0n/threat-modeling`).

---

## Per-Skill Study Guide

For each lane: **look-for** (what we're trying to evolve) → **Tier 1 (study closely)** → **Tier 2 (mine for specific patterns)** → **Tier 3 (reference only)**. Each entry names the *specific artifact/technique*, not just the repo.

### 1. `/jim:brainstorm`
*Look for: elicitation discipline, the ideation→commitment boundary, capture-without-evaluation.*

**Tier 1**
- **obra/superpowers → `skills/brainstorming/SKILL.md`** — hard gate: "do NOT take any implementation action until you present a design and the user approves"; explicitly rejects "too simple to need a design." One question at a time; visuals introduced only just-in-time. Reinforces jim's no-premature-commit posture with quotable rules.
- **Matt Pocock → `grilling`** — the reusable interview primitive: ask one question *with your own hypothesized answer attached*; "look it up rather than asking" when discoverable; never act before confirmed shared understanding.
- **Addy Osmani → `interview-me`** — hypothesis + explicit confidence score; the "should-want" probe ("if you didn't have to justify this, what would you actually want?"); a *falsifiable* stop condition ("can I predict reactions to the next three questions?").

**Tier 2**
- **danielrosehill/Claude-Ideation-Planning-Plugin** — most feature-complete ideation tool found; 6 workspace variants + ICEC/council/debate simulation agents.
- **MadeByTokens/claude-brainstorm** — structurally novel: `UserPromptSubmit`/`PreToolUse` **hooks literally block file creation** during ideation (enforced, not advised); SCAMPER / Six Hats / Reverse-Brainstorm techniques.

**Tier 3**
- **Jamie-BitFlight/claude_skills → brainstorming-skill** — 30+ prompt patterns across 14 categories (grab-bag reference).

### 2. `/jim:spec`
*Look for: testable-AC grammar, ambiguity detection, the spec/design boundary, interview mechanics.*

**Tier 1**
- **GitHub Spec Kit → `templates/commands/clarify.md`** — a **9-category ambiguity taxonomy** (functional scope, data model, UX flow, NFRs, integration, edge cases, constraints, terminology, completion signals), each scored Clear/Partial/Missing; **caps at 5 questions per clarify session**, one at a time, and **writes each answer back into the spec immediately** with a closing coverage matrix. Plus `spec-template.md`: independently-testable P1/P2/P3 user stories and FR-### functional requirements. *(Verified 2026-07-17: the **"Maximum 3 [NEEDS CLARIFICATION] markers total"** cap is real but lives in `templates/commands/specify.md` — the generation command — not in `spec-template.md` (which has no cap); `clarify.md` separately caps at 5 questions/session. The 9-article constitution lives in `spec-driven.md` as illustration, not in the blank `constitution-template.md` skeleton.)*
- **Amazon Kiro → requirements-first / EARS notation** — `WHEN [condition] THE SYSTEM SHALL [action]`: a tight, test-translatable AC grammar, plus a **non-regression clause** idiom for bug specs (`…SHALL CONTINUE TO…`).
- **OpenSpec → `docs/concepts.md` + delta templates** — **canonical-spec vs. delta-change separation**; the `### Requirement:` → `#### Scenario:` **WHEN/THEN** block *is* template-enforced, while **RFC-2119 (MUST/SHALL) is convention-only** (expected in requirement prose per `docs/concepts.md`, not enforced by the template file). Testability is structural, not audited after.
- **Addy Osmani → `spec-driven-development` + `interview-me`** — the **Always / Ask-first / Never** tri-level boundary format (more actionable than free-prose constraints).
- **deanpeters/Product-Manager-Skills** — interview bounding ("3-5 Qs, each option genuinely different"); **inline gap-tagging** (🔶 Assumption / 🔵 Open Question *at the point the gap appears*); post-draft self-assessment diagnostic.
- **Matt Pocock → `to-spec`** — compact user-story template + **seam-minimization heuristic** (touch as few testing seams as possible, ideally one).

**Tier 2**
- **cc-sdd** — EARS ACs, explicit **Boundary Context** (in/out/adjacent), "spec-as-contract" (human-reviewed boundaries vs. agent-driven internals).
- **automazeio/ccpm** — **pre-save quality gate** (no placeholders / unmeasurable metrics / unbounded scope can be saved); brainstorm-before-write discovery questions.
- **BMAD-METHOD** (46k★, v6 native-skills) — heavyweight role-driven spec pipeline; study for structure, not adoption.

**Tier 3**
- **n8n `spec-driven-development` skill** — drift-detection loop reading `.claude/specs/` (reference for the concept).

### 3. `/jim:research`
*Look for: local-vs-web tiering, tool-use enforcement, source-quality discipline, a pre-handoff self-check. (Underserved lane — few strong analogues.)*

**Tier 1**
- **akaszubski/autonomous-dev → `plugins/autonomous-dev/agents/{researcher-local,researcher}.md`** — the closest structural analogue to jim's Phase 0/Phase 1 split: **Haiku-tier local** (≥3 grep patterns, JSON out, must justify empty results) + **Sonnet-tier web** (coordinator *verifies WebSearch was actually invoked* — can't fake "found nothing"); 30-day result cache.
- **SuperClaude → `skills/confidence-check/SKILL.md`** — a **weighted 5-criterion confidence score** (no-duplicate 25% / architecture 25% / official-docs 20% / OSS-refs 15% / root-cause 15%) with **proceed / ask / stop** action bands. Adoptable as a self-check at the end of `/jim:research` before `/jim:plan` handoff.
- **Matt Pocock → `research`** — runs async; **primary sources only** (official docs, source, specs — not secondary interpretation); **cite every claim** to source.

**Tier 2**
- **nguyenvanduocit/research-kit → `/principles`** — a **versioned, self-governing principles doc** (methodology treated as a semver'd spec) + explicit source-quality dimensions (peer-review, currency, bias, citation) + a **Sync Impact Report** flagging stale downstream templates.
- **Weizhena/Deep-Research-skills** — two-phase outline → parallel deep-dive agents → synthesis, with a **human checkpoint before the expensive fan-out**.
- **open-gsd/gsd-core** — cheap-iteration flags (`--view`, `--skip-research`) and the fresh-context researcher subagent (`RESEARCH.md`), validating jim's Explore-delegation.

**Tier 3**
- **VoltAgent → `categories/10-research-analysis/project-idea-validator.md`** — adversarial "pressure-test the idea" framing for a research stress-test mode.

### 4. `/jim:plan`
*Look for: task atomicity, dependency parallelism, cross-artifact consistency, constitution/architecture gating.*

**Tier 1**
- **open-gsd/gsd-core → `commands/gsd/plan-phase.md`** (branch `next`) — an automated **plan-critique loop** (`agents/gsd-plan-checker.md`, adversarial "assume flawed") that blocks on a **task-count heuristic** (2-3/plan target · 4 = warning · **5+ = must split**); **dependency-wave parallelism** (`execute-phase.md`); **SPIDR** six-axis scope-splitting (`mvp-phase.md`). *(Verified correction: the earlier "plan fits one 200k window" phrasing was a paraphrase — the real gate is task-count; `200000` is the orchestrator's own `token_budget`. No "Walking Skeleton" exists in the file.)*
- **GitHub Spec Kit → `plan-template.md` + `commands/analyze.md`** — **Constitution Check as a gate** (pre- and post-design) with a **Complexity-Tracking justification table** for violations; **`/speckit.analyze`** = a read-only cross-artifact linter (spec↔plan↔tasks↔constitution, bidirectional coverage gaps, severities).
- **OpenSpec → `schemas/spec-driven/schema.yaml`** — a **declarative artifact-dependency graph** (tasks depend on specs+design; design on proposal only) computing the next-needed artifact — a data-driven alternative to jim's hardcoded phase gates.

**Tier 2**
- **affaan-m/ECC → `agents/architect.md` + `agents/planner.md`** — **ADR format + 8 named anti-patterns** (Big Ball of Mud, Golden Hammer, God Object…) as a plan-review gate; 4-phase risk-rated planner. Near-verbatim lift candidates.
- **cc-sdd** — **Requirements Coverage traceability** (every requirement → task IDs); **pre/postcondition + invariant** annotations on interface contracts; P0/P1 parallel-wave notation.
- **Addy Osmani → `planning-and-task-breakdown`** — **numeric task-sizing thresholds** (1-2 files small, >8 must decompose) + verification checkpoint every 2-3 tasks.
- **obra/superpowers → `writing-plans`** — 2-5 min task atomicity, **file-map-before-tasks**, hard ban on placeholders ("TBD", "add error handling").
- **Spec-Flow → `/validate --constitution`** — cross-artifact (spec/plan/tasks) consistency pass.

**Tier 3**
- **zhsama/claude-sub-agent** *(dormant)* — **scored % quality gates** (95/85/95) as a contrast to jim's boolean gates; architect/planner artifact split. Pattern-mine only.
- **Pimzino** *(dormant)* — product/tech/structure **steering docs**; study via successor `spec-workflow-mcp`.

### 5. `/jim:build`
*Look for: TDD discipline, per-task context isolation, verification-before-completion, debug loops.*

**Tier 1**
- **obra/superpowers** — the richest build material: **`subagent-driven-development`** (fresh subagent per task, **context-isolation via file paths not pasted text**, dual-verdict spec+quality review, whole-branch review on the *most capable* model); **`verification-before-completion`** (IDENTIFY→RUN→READ→VERIFY→claim; bans "should/probably/seems" before proof); **`systematic-debugging`** (4-phase, **"3 failed fixes → question the architecture"** circuit breaker → feeds `/jim:debug`).
- **Matt Pocock → `tdd`** — the **"seam"** vocabulary (public boundary observed without internals); "**refactoring is not part of red-green — it belongs to code-review**"; named anti-patterns (implementation-coupled, tautological, horizontal-slicing).

**Tier 2**
- **Spec-Flow** — **3-agent temperature-varied voting** (0.5/0.7/0.9, "to decorrelate errors") for review gates; **disk-based worker state** (implement→test→write-to-disk→exit) to avoid context bloat; **auto-regression-test on `/debug`**.
- **open-gsd/gsd-core** — **conversational UAT** gate distinct from unit tests; **milestone-level integration audit** across phases; `add-tests` post-hoc TDD/E2E/Skip classification.
- **cc-sdd → `kiro-impl`** — autonomous fresh-implementer + independent reviewer + auto-debug (a *contrast* case to jim's stricter stop-and-escalate default).
- **Addy Osmani → `doubt-driven-development`** — CLAIM→EXTRACT→**DOUBT**→RECONCILE→STOP adversarial second-opinion, **strips original reasoning before handing to the reviewer** (bias prevention).

**Tier 3**
- **Ralph / bmalph** — autonomous iterate-until-done execution loop; paradigm reference, deliberately *counter* to jim's human-in-loop stance.

### 6. `/jim:sec`
*Look for: STRIDE/LINDDUN rigor, false-positive suppression, LLM-specific threats, auto-fire triggers. (Best-served lane in the ecosystem.)*

**Tier 1**
- **fr33d3m0n/threat-modeling** — the closest analogue to jim:sec's ambitions: **8-phase pipeline** (DFD → trust boundaries → STRIDE → DREAD/CVSS risk validation → mitigation → report), backed by an 8MB SQLite KB of 1,900+ CAPEC/CWE/ATT&CK/ASVS patterns. Actively maintained (v3.2.0).
- **anthropics/claude-code-security-review** — **official Anthropic** GitHub Action; diff-scoped vuln-class analysis (injection, authZ, crypto, XSS, RCE). The vuln-scanning complement to jim's design-time threat modeling.
- **trailofbits/skills** — professional audit suite (`semgrep-rule-creator`, `variant-analysis`, `constant-time-analysis`, `supply-chain-risk-auditor`) — the quality bar for secure-coding depth.
- **Addy Osmani → `security-and-hardening`** — 5-minute STRIDE-lite pre-check (boundaries → assets → STRIDE); **LLM-output-as-untrusted-input** framing (never into SQL/shell/eval/innerHTML; cap tokens vs. cost exploits) — jim:sec's STRIDE sweep should cross-check itself against this.

**Tier 2**
- **getsentry/skills → security-review** — confidence-tiered (HIGH/MED/LOW), **investigates before reporting to avoid false positives** (independently rated best-of-5).
- **Security-Phoenix-demo/security-skills-claude-code** — **STRIDE-integrated "Secure PRD Generator"** (abuse cases + RFC2119) + `/threatmodel`.
- **affaan-m/ECC → `agents/security-reviewer.md`** — **proactive-trigger taxonomy** (auth changes, new endpoints, user input, DB queries…) — could sharpen when jim's `auto_security` gate fires.
- **Spec-Flow → `/gate-sec`** — SAST/secrets/dependency scanning + multi-agent voting.

**Tier 3**
- `dralgorhythm/claude-agentic-framework` (`/threat-modeling`), `alirezarezvani senior-security`, `sergiodxa owasp-security-check` — reference variants.
- **Canonical sources to keep:** Microsoft STRIDE (`learn.microsoft.com/.../threat-modeling-tool-threats`), LINDDUN (`linddun.org/threat-types/`) — already jim's authoritative refs; unchanged.

### 7. Meta / skill-authoring craft (cross-cutting — jim *is* a skills project)
*Look for: SKILL.md description hygiene, progressive disclosure, authoring QA.*

**Tier 1**
- **obra/superpowers → `skills/writing-skills/SKILL.md`** — the meta bible: **"description = WHEN to use, NOT what it does"** (empirically, what-descriptions make agents skip the body); progressive-disclosure template; ~200-word budgets for hot skills; **RED/GREEN/REFACTOR applied to skills themselves** (fail an agent without the skill, write the minimal fix, verify).
- **Matt Pocock → `writing-great-skills`** — root virtue is **predictability of process**; named failure modes (premature completion, duplication, sediment, sprawl, no-ops, negation); the split-a-skill heuristic (by invocation word or by sequence).
- **Addy Osmani** — the **anti-rationalization table** (named excuse → rebuttal) + **evidence-requirement footer**, applied *identically across every skill* — a mechanical authoring template jim could adopt.
- **deanpeters/Product-Manager-Skills → `CLAUDE.md`** — 9 named authoring anti-patterns each with why-it-fails + fix; "**explanation is load-bearing, not decorative**" (counter-pressure against over-terse review passes).

**Tier 2**
- **VoltAgent/awesome-claude-code-subagents** — tool-scoping-by-role, model-routing, numeric DoD gates, fixed-shape completion-notification string.
- **Addy Osmani `code-review-and-quality` + Pocock `code-review`** — the most complete external **blueprint for a future `/jim:review`** skill (five-axis review, severity vocabulary, change-sizing/splitting strategies).

---

## Study Anchors — Verified Files (by project)

Every file below was **re-fetched and confirmed 2026-07-17** (branch noted where non-`main`). This is the "open these exact files" map. Paths corrected from first-pass notes are flagged.

### SDD pipelines

**GitHub Spec Kit** (`github/spec-kit`, `templates/`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `templates/commands/clarify.md` | 9-category ambiguity scan → ≤5 Qs, answer written back atomically + coverage matrix | spec / spec-check | Interview ambiguity taxonomy + save-per-answer |
| `templates/commands/analyze.md` | Read-only cross-artifact linter (spec+plan+tasks+constitution), severity-ranked, ≤50 findings | plan | A consistency pass jim lacks |
| `templates/commands/converge.md` | Post-implement drift detector; classifies gaps missing/partial/contradicts/**unrequested**; append-only | build | Post-build spec↔code convergence |
| `templates/spec-template.md` | P1/P2/P3 independently-testable stories; FR-### reqs | spec | Story-as-shippable-slice discipline |
| `templates/checklist-template.md` + `commands/checklist.md` | "Unit tests for requirements"; ≥80% items must carry a traceability tag | spec-check | Requirements-quality ≠ test checklist |
| `templates/plan-template.md` | Constitution Check gate fires **twice** (pre-research + post-design) + Complexity Tracking table | plan | Two-pass gate + justification escape hatch |
| `spec-driven.md` | Philosophy + the illustrative 9-article constitution (NOT in the template) | all | SDD manifesto |

**OpenSpec** (`Fission-AI/OpenSpec`, branch `main`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `docs/concepts.md` | Canonical `specs/` vs delta `changes/`; archive = merge ADDED/MODIFIED/REMOVED + date-prefix | spec | Post-ship spec lifecycle (jim's biggest gap) |
| `docs/workflows.md` | "Actions, not phases — commands are things you can do, not stages you're stuck in" | spec/plan | Non-linear command model |
| `schemas/spec-driven/schema.yaml` | Declarative artifact dependency graph (proposal→specs→design→tasks→apply) | plan | Data-driven gates vs hardcoded phase order |
| `schemas/spec-driven/templates/{proposal,spec,tasks}.md` | Proposal (why/impact), delta-spec (Scenario WHEN/THEN template-enforced; RFC-2119 convention-only), grouped checklist | spec/plan | Machine-mergeable delta grammar |

**Amazon Kiro** (`kiro.dev/docs`)
| Page | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `/docs/specs/feature-specs/requirements-first/` | EARS: `WHEN [event] THE SYSTEM SHALL [behavior]` | spec | Testable-AC grammar |
| `/docs/specs/best-practices/` | Non-regression clause `…SHALL CONTINUE TO…` for bug specs | spec | Bug-spec regression guard |
| `/docs/steering/` | Four context-inclusion modes (Always/Conditional/Manual/Auto) | (CLAUDE.md/conf) | Tiered standing-context loading |

**cc-sdd** (`gotalab/cc-sdd`, v3.0.2, branch `main`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `.kiro/specs/photo-albums-en/design.md` | Per-component "Contract Definition": Preconditions/Postconditions/Invariants (verbatim on AlbumService) | plan | Behavioral contracts beyond type shapes |
| `.kiro/specs/photo-albums-en/tasks.md` | `_Requirements:_` tags + Requirements Coverage Summary | plan | Traceability rollup |
| `docs/guides/spec-driven.md` | Current v3 conceptual doc: **P0/P1 waves + `_Boundary:_`/`_Depends:_`** live *here*, not in the older example | plan | Parallel-wave task grammar |
| `docs/guides/why-cc-sdd.md` | "Spec as contract, not master command"; human-reviewed boundaries vs agent-driven internals | spec | Spec/design split |
| `docs/guides/skill-reference.md` | Current v3 (Skills) interface; `command-reference.md` is now legacy-scoped `/kiro:*` | — | (path currency) |

**open-gsd/gsd-core** (**branch `next`**)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `commands/gsd/plan-phase.md` + `agents/gsd-plan-checker.md` | Plan-critique loop; task-count blocker (5+ = split); `--view`/`--skip-research`/`--skip-verify` cheap-iteration flags | plan/research | Automated plan QA + partial-refresh |
| `commands/gsd/execute-phase.md` | Dependency-wave parallel executor subagents; flag active only if literal token in `$ARGUMENTS` | build ⚠️ | Parallel execution *(conflicts w/ human-in-loop)* |
| `commands/gsd/verify-work.md` | Conversational UAT, one question at a time, distinct from unit tests | build | Additive acceptance gate |
| `commands/gsd/audit-milestone.md` | Cross-phase integration/e2e audit before archive | build | Cross-spec integration check |
| `commands/gsd/mvp-phase.md` | SPIDR six-axis scope-splitting (Spike/Paths/Interfaces/Data/Rules) | plan | Scope-creep gate *(no "Walking Skeleton" — that was a hallucination)* |
| `docs/explanation/context-engineering.md` | Thin-orchestrator / fresh-full-subagent doctrine — **prose only, no % figures** | research | Context-rot budgeting |
| `commands/gsd/autonomous.md` | Runs discuss→plan→execute across all phases, pauses only on grey areas ⚠️ | — | *Direct conflict with jim's per-task human gate* |

**Spec-Flow** (`marcusgoll/Spec-Flow`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `.claude/commands/phases/optimize.md` | Temperature-varied (0.5/0.7/0.9) 3-agent voting per gate; `unanimous`/`first_to_ahead_by_k`; cites MAKER paper | (sec/spec-check) | Ensemble voting *(only if `voting.yaml` present)* |
| `.claude/commands/quality/gate.md` | Unified `/gate ci|sec`; "secrets detection NEVER skipped"; zero CRIT+HIGH deps | sec | Hard-fail gate composition *(real path; `/gate-sec` is dead)* |
| `docs/commands.md` | Six-phase overview + `/validate` severity-tiered consistency | plan | Pipeline shape |

### Skill collections (workflow + meta-authoring)

**obra/superpowers** (`skills/*/SKILL.md`, `main`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `writing-skills/SKILL.md` | Description=when-only; RED/GREEN/REFACTOR for skills; frequency-tiered word budgets; rationalization-bulletproofing | meta-skill | The authoring bible |
| `brainstorming/SKILL.md` | Hard gate: no implementation until a design is approved; one-Q-per-message | brainstorm | Pre-implementation gate |
| `writing-plans/SKILL.md` | 2-5min task atomicity; file-map-before-tasks *step*; placeholder ban | plan | Task-granularity lint |
| `subagent-driven-development/SKILL.md` | Fresh subagent per task; file-based handoff (`task-brief`/`review-package`); dual-verdict review | build | Independent review + context isolation |
| `verification-before-completion/SKILL.md` | IDENTIFY→RUN→READ→VERIFY→CLAIM; bans "should/probably/seems" | build (none yet) | Evidence-before-claim gate |
| `test-driven-development/SKILL.md` | "Iron Law"; verify-RED/verify-GREEN; rationalization catalog | build | TDD discipline framing |
| `systematic-debugging/SKILL.md` | 4-phase; ≥3 failed fixes → "question the architecture" | debug | Circuit breaker framing |

**Matt Pocock skills** (`mattpocock/skills`, `main`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `productivity/writing-great-skills/SKILL.md` | Predictability-of-process; failure modes (sediment/sprawl/no-op); split heuristic; 3-tier info hierarchy | meta-skill | Authoring craft |
| `productivity/grilling/SKILL.md` | One-Q-with-a-hypothesis; look-it-up-not-ask (facts researched, decisions asked) — *cite this, not the `grill-me` stub* | spec | Interview primitive |
| `engineering/tdd/SKILL.md` | "Seam" vocabulary; refactor belongs to `code-review`, not red-green | build | Seam pre-agreement |
| `engineering/domain-modeling/SKILL.md` | CONTEXT.md as pure glossary; 3-condition ADR gate | arch | ADR-sprawl prevention |
| `engineering/to-spec/SKILL.md` | Spec section list; minimize testing seams (ideal = 1) | spec | Seam-minimization |
| `engineering/research/SKILL.md` | Primary sources only; cite every claim; runs async | research | Source discipline |
| `engineering/ask-matt/SKILL.md` | Situational router (idea/bugs/broken/foggy → skill) | (none) | Entry-situation routing |

**Addy Osmani agent-skills** (`addyosmani/agent-skills`, `main`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `skills/interview-me/SKILL.md` | Hypothesis+confidence; should-want probe; predict-next-3 stop test | spec | Falsifiable interview stop |
| `skills/spec-driven-development/SKILL.md` | Always/Ask-first/Never tri-level boundaries | spec | Scannable constraint format |
| `skills/planning-and-task-breakdown/SKILL.md` | Numeric file-count sizing (XS…XL, 8+ = too large); checkpoint every 2-3 tasks | plan | Mechanical task-sizing |
| `skills/code-review-and-quality/SKILL.md` | 5-axis review; severity prefixes; change-size table; splitting strategies | (review) | **Blueprint for jim:review** |
| `skills/security-and-hardening/SKILL.md` | STRIDE-lite pre-check; **LLM05 output-as-untrusted-input**; supply-chain rules | sec | LLM threat class + supply-chain |
| `skills/doubt-driven-development/SKILL.md` | CLAIM→EXTRACT→DOUBT→RECONCILE→STOP; strips reasoning before fresh-context review | (sec/build) | Bias-free second opinion |
| `references/{definition-of-done,security-checklist,testing-patterns}.md` | Central shared checklists (OWASP Top-10-for-LLMs; mock-at-boundaries-only) | meta/sec/build | Central-vs-per-skill references |

### Research lane

**akaszubski/autonomous-dev** (**branch `master`**, `plugins/autonomous-dev/`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `agents/researcher-local.md` | Haiku; ≥3 grep patterns; **empty result must ship `empty_justification`**; JSON out; 30-day TTL cache | research | Enforced-effort local gate |
| `agents/researcher.md` | Sonnet web; **coordinator verifies WebSearch was actually invoked**; source hierarchy *(this is where `researcher-web.md` was merged)* | research | Anti-hallucination tool-use gate |
| `commands/align.md` (v3.1.0) | `/align` is a **command** calling `hybrid_validator.py` etc.; the agent-form validator is **archived 2026-02-14** | (research/plan) | *(path currency — prior citation was a decommissioned file)* |

**nguyenvanduocit/research-kit** (`main`, templates flat at repo root)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `templates/commands/principles.md` | Semver'd methodology doc (MAJOR/MINOR/PATCH); 6 coverage dimensions; **Sync Impact Report** | research | Methodology-as-versioned-artifact |
| `templates/{methodology,analysis,synthesis}-template.md` | Phase-separated templates; `file:line` citation discipline; design/results/interpretation firewall | research | Phase separation |

**SuperClaude_Framework** (**branch `master`**)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `skills/confidence-check/SKILL.md` | Weighted 5-criterion score (25/25/20/15/15); **≥0.90 proceed / 0.70-0.89 ask / <0.70 stop** | research | Pre-handoff confidence gate |
| `src/superclaude/agents/deep-research.md` | Multi-hop web search + per-source credibility scoring *(cite this one, not `deep-research-agent.md`)* | research | Depth-adaptive web tier |

### PM / catalog

**deanpeters/Product-Manager-Skills** (`main`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `CLAUDE.md` | **7** named authoring anti-patterns (Metrics Theater, Feature Factory, Stripped Pedagogic Content, Excessive Hedging, Generic Best Practices, Dumping All Questions, Endless Back-and-Forth) + "explanation is load-bearing" + 7-part skill anatomy | meta-skill | Authoring rubric *(7, not 9)* |
| `skills/prd-development/SKILL.md` | 8-phase PRD, per-phase time-boxes | spec | Heavier PRD mode |

**automazeio/ccpm** (`skill/ccpm/`, portable Agent Skill)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `skill/ccpm/SKILL.md` | Intent router (delivery-context gating; explicit skip list) | spec/plan | In/out-of-scope framing |
| `skill/ccpm/references/plan.md` | 5 brainstorm Qs; read-full-PRD priming; **≤10 tasks** | spec/plan | Context-priming + task ceiling |
| `skill/ccpm/references/structure.md` | Epic **decomposition** (size-tiered parallelization) *(not a layout doc)* | plan | Decomposition strategy |

**ECC** (`affaan-m/ecc` — repo renamed from `affaan-m/everything-claude-code`, which now redirects; `main`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `agents/architect.md` | ADR template + 8 named anti-patterns; **structurally read-only** (`tools: [Read,Grep,Glob]`) | architect/plan | Anti-pattern watchlist + read-only scope *(jim:architect has Write/Edit)* |
| `agents/planner.md` | 4-phase MVP→Core→Edge→Optimize; per-step Risk + Dependencies | plan | Risk-rated phasing |
| `agents/security-reviewer.md` | Two-tier ALWAYS/IMMEDIATELY autofire trigger taxonomy | sec | Concrete auto_security triggers |

**VoltAgent/awesome-claude-code-subagents** (`main`)
| File | What it is | jim skill | Study for |
|------|-----------|-----------|-----------|
| `categories/04-quality-security/architect-reviewer.md` | 8-axis macro-design review gate | plan | Structured design review |
| `categories/04-quality-security/code-reviewer.md` | Numeric DoD (coverage >80%, complexity <10) + fixed completion string | meta-agent/coder | DoD gates + notification convention |
| `categories/10-research-analysis/project-idea-validator.md` | YC-style adversarial default-skeptic validator | (vision) | Red-team-your-own-idea |

### Security lane

| Repo | Key files | Design-time? | jim skill | Study for |
|------|-----------|-------------|-----------|-----------|
| `fr33d3m0n/threat-modeling` | `SKILL.md`, `WORKFLOW.md`, `knowledge/security_kb.sqlite` (~8MB, CWE/CAPEC/ATT&CK + `llm-threats.yaml`/`agentic-threats.yaml`), `scripts/unified_kb_query.py` | **Hybrid** (fwd design-time; backward does binary RE/code audit) | sec | KB-backed findings; DFD; P6 **validation-status triage** *(NOT DREAD)* |
| `Security-Phoenix-demo/security-skills-claude-code` | `feature-descriptor/security-engineer.skill`; `/threatmodel` | **Design-time** | sec | STRIDE embedded into PRD; `/threatmodel` = STRIDE+**DREAD**+attack trees |
| `getsentry/skills` | `skills/security-review/SKILL.md` | Code-level (SAST-adjacent) | (review) | Confidence tiering + investigate-before-report |
| `anthropics/claude-code-security-review` | `claudecode/prompts.py`, `findings_filter.py`, `.claude/commands/security-review.md` | **Runtime/PR** | (review) | Diff-scoped scan + FP filtering |
| `trailofbits/skills` | `plugins/{semgrep-rule-creator,variant-analysis,supply-chain-risk-auditor,...}` (19 plugins) | **Runtime/code-audit** | (review) | Pro static-analysis composition *(`constant-time-analysis` unconfirmed)* |
| `wshobson/agents` → `plugins/security-scanning` (38k★ monorepo) | `agents/threat-modeling-expert.md` + `skills/{stride-analysis-patterns,attack-tree-construction,security-requirement-extraction,threat-mitigation-mapping}/SKILL.md` (design-time slice); `commands/security-{sast,dependencies,hardening}.md` (runtime slice) | **Mixed** — design-time skills + runtime SAST bundle | **sec** (design slice) | **Attack-tree construction** (AND/OR, quantified cost/time/skill), threat→testable-requirement extraction, layered mitigation matrix — real jim:sec gap-fillers *(does NOT close the CWE/CAPEC/ATT&CK gap either — verified)* |
| `wshobson/agents` → `plugins/comprehensive-review` | `commands/full-review.md`, `commands/pr-enhance.md`, `agents/{architect-review,code-reviewer,security-auditor}.md` | **Runtime/post-hoc** | (review) | Checkpoint-gated multi-lens pipeline (`.full-review/` state); PR risk-score (size×complexity×coverage×deps×security) + split heuristic (>20 files/1000 LOC) |
| `anthropics/claude-plugins-official` → `plugins/security-guidance` (**official**, 32k★ repo, v2.0.6) | `hooks/{hooks.json,patterns.py,llm.py,security_reminder_hook.py}` — **100% hook-driven, no commands/skills/agents** | **Runtime, hook-driven** | (review) | 3-tier escalation (regex → LLM diff review on `Stop` → agentic multi-file trace on commit); baseline-SHA session diffing; named agent threat classes **Agent/Subprocess Permission Bypass** + **Orchestrator Template Injection** |

---

## Gap Analysis — What They Have vs. What jim Has (by skill)

Format: **their capability** *(source)* → **what jim lacks**. Closes each lane with where **jim is ahead**.

### jim:brainstorm
- Hard pre-implementation gate *(superpowers/brainstorming)* → jim:brainstorm only *offers* routing at Step 7; nothing blocks jumping to `/jim:build` without an approved design.
- One-question-per-message discipline *(superpowers, Pocock grilling)* → jim:brainstorm Step 4 says "ask light clarifying questions" with no cap.
- **jim ahead:** deliberate no-framework, no-evaluation freeform capture; end-of-run candidate-issue batch has no analogue.

### jim:spec
- 9-category ambiguity taxonomy + closing coverage matrix *(Spec Kit clarify)* → jim's 6 gray-area dimensions drive branching but produce no Resolved/Deferred/Outstanding report.
- EARS / WHEN-THEN testable-AC grammar *(Kiro, OpenSpec, cc-sdd)* → jim ACs are free-prose.
- Delta-vs-canonical spec lifecycle + archive-as-merge *(OpenSpec)* → jim spec.md is a mutable single doc; no amendment format, no audit trail, no concurrent-change model.
- Tri-level Always/Ask-first/Never boundaries *(Osmani)* → jim has Out-of-Scope + free-prose constraints.
- One-Q-with-hypothesis + look-it-up-vs-ask triage *(Pocock grilling, Osmani interview-me)* → jim interview lacks both.
- Fixed discovery question set + inline pre-save quality gate *(ccpm)* → jim validates via a separate spec-check pass, no save-block; Boundary-Context in/out/adjacent *(cc-sdd)* vs jim's Out-of-Scope-only.
- **jim ahead:** spec-check's *named* Socratic Probes (Razor/Delegation/Story-Link/Constraint-Sourcing) + three-tier AC classification beat every tool's unnamed "quality checklist"; the Level-Up Method structurally deflects premature tech; the structural "can I fill the template?" stop is *more* falsifiable than a self-reported confidence %.

### jim:research
- Enforced empty-result justification *(autonomous-dev researcher-local)* → jim's Explore phase can return "nothing found" with no audit trail.
- Coordinator-verified WebSearch invocation *(autonomous-dev researcher)* → jim can't tell a real search from claimed training-data knowledge.
- Weighted confidence gate w/ proceed/ask/stop *(SuperClaude confidence-check)* → jim's research-dod is a checklist, not a scored stop/go before handoff. **(By design — jim routes concerns via `status:` + Peer Feedback, never a numeric gate, per `skills/spec/SKILL.md:125`. NOT a gap to close; recorded as a deliberate no-go in `004-researcher/research.md`, 2026-07-17.)**
- 30-day TTL result cache *(autonomous-dev)* → jim redoes archaeology every run.
- Semver'd methodology + Sync Impact Report *(research-kit principles)*; phase-separated citation-disciplined templates → jim's methodology lives in prompt text; research.md conflates phases.
- Primary-sources-only + cite-every-claim *(Pocock research)* → jim has the 20-line rule but no per-claim source-attribution mandate.
- **jim ahead:** Phase-2 VISION/ARCHITECTURE alignment and codebase-anchoring-first structure have **no analogue** in any of the three research tools.

### jim:plan
- Cross-artifact consistency linter *(Spec Kit analyze)* → jim has a coverage summary but no duplication/ambiguity/terminology-drift detection with severities.
- Two-pass Constitution gate + Complexity Tracking table *(Spec Kit)* → jim's Constitution Check is single-pass, no justification table.
- Declarative artifact dependency graph *(OpenSpec schema.yaml)* → jim's phase/task order is hardcoded prose, not inspectable data.
- Pre/postcondition/invariant interface contracts *(cc-sdd design.md)* → jim's Interface Contracts capture types/shapes only.
- Dependency-wave parallelism *(GSD, Kiro)* → jim's task list is linear. ⚠️ default GSD execution runs subagents unattended — adopt the *wave-grouping*, not the unattended execution.
- Plan-critique loop w/ 5+-task split blocker *(GSD gsd-plan-checker)*; numeric file-count task-sizing + 2-3-task checkpoints *(Osmani)*; 2-5min atomicity + placeholder ban *(superpowers)* → jim leaves task granularity to judgment. *(Correction: jim **does** have a File Manifest — what's missing is a file-map-first process step + a time/size budget + a placeholder ban.)*
- Read-full-spec context-priming + ≤10-task ceiling *(ccpm)*; 8-axis macro-design gate *(VoltAgent)*; ADR + named anti-patterns + read-only architect scope *(ECC)* → jim:plan review is narrative; **jim:architect is not read-only** (has Write/Edit).
- **jim ahead:** Requirements Coverage Summary is consistently produced (cc-sdd's docs/example have drifted apart); every task carries a shell-executable `Verify:` command.

### jim:build
- Fresh-subagent-per-task + file-based context isolation + **dual-verdict (spec+quality) review** *(superpowers subagent-driven-development; cc-sdd kiro-impl)* → jim runs the whole loop in one continuous coder session with **no independent review step** — only the task's `Verify:` command + optional pre-commit/pre-completion scripts.
- Standalone verification-before-completion evidence gate + hedge-word ban *(superpowers)* → jim shows output inline but has no uniform IDENTIFY→RUN→READ→VERIFY skill.
- Named "Iron Law" + rationalization catalog + seam pre-agreement *(superpowers tdd, Pocock tdd)* → jim's `tdd-guide.md` has the mechanics but no named law / rationalization table / seam contract.
- Conversational UAT gate *(GSD verify-work)*; cross-phase integration audit *(GSD audit-milestone)*; post-build spec↔code convergence *(Spec Kit converge)* → jim has none of the three.
- Temperature-varied multi-agent voting on gates *(Spec-Flow optimize)*; adversarial doubt-driven second-opinion *(Osmani)* → jim's gates are single-agent, single-pass.
- Numeric DoD gates + fixed completion string *(VoltAgent code-reviewer)* → jim uses qualitative tiers.
- *(Corrections: jim **does** have a 3-strikes stop — in `build/SKILL.md` Green phase, framed "update plan / /jim:debug / adjust" rather than superpowers' "question the architecture"; **jim:debug** is the one with no attempt-counting. jim keeping refactor in-loop as a Tidy phase is a deliberate divergence from Pocock's refactor-in-review.)*
- **jim ahead:** STOP-on-every-failure is a *stronger* human-in-loop guarantee than GSD's executor (which deviates "without permission"); tests-always-first avoids GSD's need for an `add-tests.md` retrofit ceremony; end-of-build candidate capture has no analogue.

### jim:sec
- KB/pattern DB (CWE/CAPEC/ATT&CK) with programmatic query *(fr33d3m0n `security_kb.sqlite`)* → jim has no pattern DB or citation mechanism.
- Explicit DFD extraction + trust-boundary artifact *(fr33d3m0n P2/P3)* → jim's STRIDE is a checklist over spec/plan text, never derives a DFD.
- LLM/agentic threat class *(fr33d3m0n `llm-threats.yaml`; Osmani LLM05 output-as-untrusted-input; **Anthropic-official `security-guidance`** names two canonical categories: **Agent/Subprocess Permission Bypass** and **Orchestrator Template Injection**)* → jim's Data Classification flags PII/creds/session but has no LLM/agent-specific threat category. *(Signal: even Anthropic's own tool scopes prompt-injection/jailbreaks **out** — open ground.)*
- Attack-tree construction as a distinct artifact *(wshobson `security-scanning/skills/attack-tree-construction`)* → AND/OR decomposition with quantified cost/time/skill/detection-risk per leaf + Mermaid/PlantUML export → jim:sec enumerates threats flatly, never chains them into critical attack paths.
- Threat→testable-requirement extraction *(wshobson `security-requirement-extraction`)* → business→security→technical requirement with traceability/testability/priority fields → jim:sec findings stop at severity + route (Spec/Plan/Issue), never a checkable requirement.
- Layered mitigation matrix *(wshobson `threat-mitigation-mapping`)* → preventive/detective/corrective × 5 architectural layers with a "no single point of failure" check → jim:sec mitigation suggestions are unstructured prose.
- STRIDE embedded into PRD authoring *(Security-Phoenix)* → jim is a separate downstream pass, not co-authored into requirements.
- Exploitability/attack-path validation gate *(fr33d3m0n P6 validation-status triage; getsentry investigate-before-report)* → jim severities aren't gated by a confirm-exploitable step.
- Two-tier proactive autofire taxonomy *(ECC security-reviewer)* → jim has boolean gate flags, no concrete-condition trigger list; supply-chain rule set *(Osmani)* → jim names the risk, has no operational rules.
- **jim ahead:** dual-lens spec+plan review with machine-readable `reviewed_phases` state; the conditional **LINDDUN** privacy sweep (no other tool surveyed runs it — wshobson `security-scanning` has no privacy skill at all); native `route: Spec/Plan/Issue` feeding jim's own pipeline instead of a standalone report/tracker. wshobson's `security-hardening.md` *blurs* design-time and runtime in one 13-step pipeline — a scope-boundary weakness jim's clean sec/review split avoids.
- *(Runtime lane — validates the future `/jim:review`, doesn't threaten jim:sec: **Anthropic's own `security-guidance`** separates design-time from post-build exactly as jim does (jim:sec vs planned jim:review), and is a strong reference architecture for it — 3-tier escalation, baseline-SHA session diffing, `asyncRewake` to force the agent to act on findings; plus wshobson `comprehensive-review` (checkpoint-gated multi-lens) and PR-diff scanning (Anthropic `claude-code-security-review`) + Semgrep/CodeQL composition (Trail of Bits/Sentry). jim:sec is deliberately design-time and rejected DREAD per spec 016; Security-Phoenix + wshobson `threat-modeling-expert` are the DREAD/attack-tree counter-examples.)*

### meta / skill-authoring (jim:meta-skill / jim:meta-agent)
- **Description = when-to-use ONLY** *(superpowers, Pocock)* → jim:meta-skill mandates "what the skill does AND when to trigger" — the **inverted** emphasis, the exact failure mode superpowers found makes agents skip the body.
- RED/GREEN/REFACTOR QA of the skill artifact itself *(superpowers, Pocock)* → jim:meta-skill "Validate" is a static structural checklist, no behavioral pressure-test.
- Named failure-mode taxonomy *(superpowers sediment/sprawl/no-op; Pocock; deanpeters' 7)* + split-a-skill heuristic + 3-tier info hierarchy → jim has none named.
- Anti-rationalization tables + evidence footer + frequency-tiered word budgets *(Osmani, superpowers)* → jim's budgets are flat (≤500 lines / ≤800 tokens); and jim's writing-style guidance ("avoid ALL-CAPS MUSTs, use rationale") is the **opposite** of superpowers' hard-line style for discipline-enforcing skills — a genuine philosophy tension to resolve, not just a gap.
- **jim ahead:** meta-authoring is gated on the full SDLC (approved spec → research spot-check → approved plan) — superpowers treats skills in isolation; and jim's deterministic-scripts-with-a-bash-test-suite (`meta-test`, `testlib.sh`) has **no counterpart** in any repo surveyed.

---

## Verification Corrections & Stale-Path Fixes (this pass)

Caught while re-verifying anchors — worth recording so we don't re-inherit bad facts:

- **Fabrications from first-pass agent reports:** GSD's "~15% orchestrator / ~100% subagent" percentages (prose only, no numbers); GSD's "plan fits one 200k window" (real gate = task-count 5+split); GSD "Walking Skeleton / SKELETON.md" (does not exist); `fr33d3m0n` "DREAD scoring" (it's validation-status triage; DREAD is Security-Phoenix); Trail of Bits `constant-time-analysis` (unconfirmed).
- **Overstated jim gaps, corrected:** jim:plan *has* a File Manifest; jim:build *has* a 3-strikes stop; jim:meta length budgets *exist* (flat); jim:meta description rule is *inverted*, not absent.
- **Default-branch / path drift:** GSD = `next`; autonomous-dev & SuperClaude = `master`; autonomous-dev `researcher-web.md` → merged into `researcher.md`; `/align` is a command (agent-form validator archived 2026-02-14); research-kit `/principles` (not `/research.principles`), templates flat at root; Spec-Flow voting in `.claude/commands/phases/optimize.md`, `/gate-sec` → `.claude/commands/quality/gate.md`; cc-sdd `command-reference.md` legacy → `skill-reference.md` current; Spec Kit commands namespaced `/speckit.*`.
- **Count/fact fixes:** Spec Kit's "max 3 `[NEEDS CLARIFICATION]` markers" cap **does** exist — in `templates/commands/specify.md` (generation command), not in `spec-template.md`; `clarify.md` separately caps at 5 questions/session (both re-verified first-hand 2026-07-17). deanpeters anti-patterns = 7 (not 9); OpenSpec RFC-2119 is convention-only (WHEN/THEN is template-enforced); SuperClaude has two `deep-research*` agents.

---

## Cross-Cutting Patterns Worth Stealing

1. **Testable-AC grammar** — EARS `WHEN…THE SYSTEM SHALL…` (Kiro/cc-sdd) and per-requirement `#### Scenario:` WHEN/THEN (OpenSpec) bake testability into authoring. → candidate for jim:spec + spec-check's testability tier.
2. **Delta-spec vs. canonical-spec lifecycle** (OpenSpec) — jim has *no* model for what happens to a spec after it ships or how to amend it without a full rewrite. Biggest structural gap surfaced.
3. **Drift / convergence phase** (Spec Kit `/analyze` + `/converge`, Spec-Flow `/validate`, n8n) — a code-vs-intent closing pass jim's pipeline lacks.
4. **Adversarial verification / second-opinion** (Osmani doubt-driven, Spec-Flow 3-agent voting, superpowers dual-verdict) — could harden spec-check and sec beyond single-pass audits.
5. **Verification-before-completion evidence gate** (superpowers) — directly portable language for jim:build's completion gate and spec-check/sec audit phrasing.
6. **Context-isolation via file paths + fresh-subagent-per-task** (superpowers, GSD, cc-sdd) — validates jim's Explore-delegation; extend the pattern into `/jim:build`.
7. **Scored/weighted gates vs. boolean** (SuperClaude, zhsama) — a design *option* for jim's gates, in explicit tension with our transparency non-goals (below).
8. **Anti-rationalization tables + evidence footers** (Osmani) — a reusable authoring device for every jim SKILL.md.
9. **Numeric task-atomicity + dependency waves** (superpowers, Osmani, GSD, Kiro, cc-sdd) — mechanize jim:plan's task-sizing instead of judgment-only.
10. **Template-once / render-many portability** (cc-sdd, ccpm→Agent Skill, Osmani, `agentskills.io`, `skills.sh`) — relevant to VISION Phase 3's cross-agent goal.

---

## Security & Alignment Notes

**Adoption tensions (do NOT copy wholesale).** Several high-signal mechanisms conflict with jim's locked non-goals in `VISION.md`:
- Autonomous execution loops (cc-sdd `kiro-impl`, Ralph/bmalph, Spec-Flow auto-ship) vs. **"human-in-the-loop approval at every phase gate"** and **"not for hands-off vibe coding."**
- Scored auto-gates that silently proceed (SuperClaude ≥90% → proceed) vs. **"not a black box / transparency over automation."**
- Deployment/CI/staging surface (Spec-Flow, ECC) is **out of jim's remit** (not a PM/ops tool).

These are worth *studying as patterns* but must be re-shaped to jim's human-in-loop, transparent posture before any adoption.

**Alignment statement.** This research aligns with **VISION.md → Roadmap Phase 2 (Research & Refinement)** and the **North Star** ("the spec/research/plan archive becomes a go-to reference"). It follows `ARCHITECTURE.md`'s skill/agent conventions (no new tooling proposed here). It also **directly refreshes VISION.md's own "Competitive Landscape" table**, whose SuperClaude and GSD rows now have current data (GSD renamed; SuperClaude at v4.3.0).

---

## Peer Feedback (for PM / Architect)

- **PM:** VISION.md's Competitive Landscape table is stale — the GSD row should point to `open-gsd/gsd-core`, and new heavyweight entrants (superpowers, OpenSpec, Kiro, BMAD) change the differentiation story. Recommend a `/jim:vision` refresh pass.
- **PM/Architect:** Two genuinely new capability gaps have strong external blueprints and may warrant their own specs: (a) a **`/jim:review`** skill (Osmani `code-review-and-quality` is a near-complete blueprint), and (b) a **spec-lifecycle / post-ship amendment** model (OpenSpec delta-vs-canonical). Both are out of scope here → filed as candidates below.
- **Housekeeping:** 4 research docs cite the dead GSD path; `004` cites dead autonomous-dev/research-kit paths; `015` has two never-cleanly-fetched sources. Low-effort corrections.

---

## Prior-Source Currency Audit — every external source across the 7 skill research docs

Scope: `002-pm-core`, `003-pm-strategy`, `004-researcher`, `005-architect`, `006-coder`, `015-spec-refinement`, `016-sec`. Every external URL (52 distinct) re-checked **2026-07-17**. **Bottom line: nothing was abandoned or content-killed — every cited source is still live and still relevant.** The only changes are moves / renames / retitles / branch-drift, handled per rule: *pure move → URL refreshed at origin; retitle (same URL) → noted here only; moved-and-changed → annotated at origin, not silently swapped.*

### Non-repo sources (official docs · blogs · standards)

| Source | Type | Cited in | Status 2026-07-17 | Handling |
|--------|------|----------|-------------------|----------|
| `code.claude.com/docs/en/skills` | official docs | 002, 003 | LIVE; **evolved** (custom commands merged into skills; cites `agentskills.io` standard) | Annotated in 002/003 (same URL) |
| `code.claude.com/docs/en/sub-agents` | official docs | 002, 003 | LIVE, current | No change |
| Kent Beck, "Augmented Coding" | blog | 006 | **MOVED** — `tidyfirst.substack.com` 301→ `newsletter.kentbeck.com` (content unchanged, free) | URL refreshed in 006 |
| `alexop.dev/...custom-tdd-workflow` | blog | 006 | LIVE; retitled "A Claude Code TDD Skill…" | Note only (same URL) |
| `nathanfox.net/...taming-genai-agents` | blog | 006 | LIVE | No change |
| `abstracta.us/...requirements` | blog | 015 | LIVE; retitled "…for Enterprise Software" | Note only |
| `perforce.com/...non-functional-requirements` | blog | 015 | LIVE; retitled "…Tips, Tools, and Examples" | Note only |
| `isoform.ai/...limits-of-spec-driven-development` | blog | 015 | LIVE (external validation of jim's thesis) | No change |
| `medium.com/@haberlah/...` | blog | 015 | LIVE (re-pulled first-hand this session) | No change |
| `learn.microsoft.com/...threat-modeling-tool-threats` | standards | 016 | LIVE, updated 2026-03-04; six STRIDE categories intact | Authoritative; keep |
| `linddun.org/threat-types/` | standards | 016 | LIVE; names match 016's current usage | Authoritative; keep |
| `linddun.org/` · `nist.gov/...linddun` | standards | 016 | LIVE (KU Leuven DistriNet · NIST, upd. Mar 2025) | Keep |

### GitHub deep-link drift (repos were repo-level-verified above; individual file paths re-checked here)

| Deep-link | Cited in | Status | Handling |
|-----------|----------|--------|----------|
| spec-kit `templates/plan.md` | 004 | **404** — renamed → `templates/plan-template.md` | URL refreshed in 004 |
| spec-kit `extensions/claude-code/commands/speckit.implement.md` | 006 | **404** — moved → `templates/commands/implement.md` | URL refreshed in 006 |
| SuperClaude `blob/main/personas/technical-analyst.md` | 004 | **DEAD** — `personas/` removed in v4; no `main` branch | Annotated in 004 (nearest successor: `src/superclaude/agents/deep-research.md`) |
| SuperClaude `blob/main/PLANNING.md` | 005 | Broken branch — exists on **`master`** | `main`→`master` refreshed in 005 |
| SuperClaude `tree/main/skills/confidence-check` | 005 | Broken branch — exists on **`master`** (`SKILL.md` + `confidence.ts`) | `main`→`master` refreshed in 005 |
| `everything-claude-code/blob/main/agents/architect.md` | 005 | Repo **renamed** → `affaan-m/ecc` (same id `1136590548`, ~230k★); file present, now leads with a "Prompt Defense Baseline" preamble | URL refreshed to `ecc` in 005 |
| Live/unchanged | 004/005/006/015 | spec-kit `plan-template.md`/`constitution-template.md`/`spec-driven.md`/`templates/commands/specify.md`; VoltAgent `ux-researcher.md` + `architect-reviewer.md`; Pimzino `spec-create`/`spec-execute`/`steering/structure` *(repo dormant, links resolve)*; zhsama `spec-agents/` *(dormant)*; cc-sdd `design.md`/`tasks.md`/`claude-subagents.md`; research-kit `methodology-template.md`; addyosmani `spec-driven-development/SKILL.md` | No change (GSD + autonomous-dev already refreshed earlier this session) |

### Named standards (no URL — 015/016)

IEEE 830 → **superseded** by ISO/IEC/IEEE 29148:2018 (already flagged in 015); Volere (`volere.co.uk`, active); **AGENTS.md** now an established multi-vendor standard; OWASP / DREAD / MITRE ATT&CK cited in 016 **only as rejected frameworks** — still valid as such; Wiegers & Beatty and Hayakawa (books, current). No action beyond cataloguing.

### Summary

- **Abandoned / dead content:** none. One dead *file path* (SuperClaude `personas/technical-analyst.md`, removed in the v4 restructure) — annotated, not swapped.
- **Moved (URL refreshed at origin):** Kent Beck Substack→newsletter.kentbeck.com; spec-kit `plan.md`→`plan-template.md` and implement path; SuperClaude `main`→`master` ×2; `everything-claude-code`→`ecc`.
- **Retitled (same URL/content, note only):** alexop.dev, abstracta, perforce.
- **Evolved (same URL, content changed):** `code.claude.com/docs/en/skills` — annotated in 002/003.

---

## Refreshed Source List (verified 2026-07-17)

**Tier-1 SDD frameworks:** github.com/github/spec-kit · github.com/Fission-AI/OpenSpec · kiro.dev/docs/specs · github.com/open-gsd/gsd-core *(was gsd-build/get-shit-done)* · github.com/obra/superpowers · github.com/mattpocock/skills · github.com/addyosmani/agent-skills
**Tier-2:** github.com/marcusgoll/Spec-Flow · github.com/gotalab/cc-sdd · github.com/deanpeters/Product-Manager-Skills · github.com/automazeio/ccpm · github.com/SuperClaude-Org/SuperClaude_Framework · github.com/akaszubski/autonomous-dev · github.com/PabloLION/bmad-plugin (BMAD-METHOD) · github.com/VoltAgent/awesome-claude-code-subagents · github.com/affaan-m/ecc (formerly everything-claude-code)
**Research lane:** github.com/nguyenvanduocit/research-kit · github.com/Weizhena/Deep-Research-skills
**Security lane:** github.com/trailofbits/skills · github.com/anthropics/claude-code-security-review · github.com/anthropics/claude-plugins-official (`plugins/security-guidance`) · github.com/wshobson/agents (`plugins/security-scanning`, `plugins/comprehensive-review`) · github.com/fr33d3m0n/threat-modeling · github.com/getsentry/skills · github.com/Security-Phoenix-demo/security-skills-claude-code · learn.microsoft.com/.../threat-modeling-tool-threats · linddun.org/threat-types
**Brainstorm lane:** github.com/danielrosehill/Claude-Ideation-Planning-Plugin · github.com/MadeByTokens/claude-brainstorm
**Dormant / redirect:** github.com/Pimzino/claude-code-spec-workflow → **spec-workflow-mcp** · github.com/zhsama/claude-sub-agent
**Directories:** claudemarketplaces.com · skills.sh · claudepluginhub.com *(403 — homepage un-swept; its 961-plugin security topic sampled via 3 developer-provided plugins)*

## Audit Trail / Open Items

- **`claudepluginhub.com` — 403 on homepage (not worked around).** Its security topic page (961 plugins) was sampled via 3 developer-provided plugins, now incorporated; the full listing is intentionally left un-swept (aggregation of already-catalogued repos). Considered closed unless a specific lane is worth a targeted look.
- **`015` re-verification:** re-pull the Haberlah PRD article and spec-kit `specify.md` first-hand.
- **Path fixes:** now captured in *Verification Corrections & Stale-Path Fixes* above — every anchor path was re-verified 2026-07-17 (branches noted). The stale citations in our own `002/004/005/006` docs still need editing to match (tracked as a candidate issue).
- **Anchor pass:** complete — every project's study files verified file-by-file with a per-skill gap analysis (see *Study Anchors* + *Gap Analysis*).

---

## Takeaways

*One-screen recap — evidence is in the sections above.*

**New discoveries that matter most.** None of these were in jim's prior research docs; they're the highest-signal finds of this survey:
- **obra/superpowers** (256k★) — the standout on two fronts: a skill-authoring bible (`writing-skills`) *and* battle-tested brainstorm/plan/build/debug skills.
- **OpenSpec** (61k★) — delta-vs-canonical spec lifecycle; addresses jim's single biggest structural gap (what happens to a spec after it ships).
- **Amazon Kiro** (+ **cc-sdd**) — EARS `WHEN…THE SYSTEM SHALL…` testable-AC grammar.
- **Matt Pocock skills** (175k★) — high-craft authoring + the `tdd` "seam" discipline.
- **jim:sec depth:** **fr33d3m0n/threat-modeling** (KB-backed STRIDE + attack trees), **wshobson `security-scanning`** (attack-tree construction), and **Anthropic-official `security-guidance`** (independently validates jim's design-time-vs-post-build split).

**Biggest opportunities for jim** — four strong, **co-equal** candidates (no single winner; all pass the "aligned with our values" filter):
- **Skill-authoring craft (meta).** jim's `meta-skill` guidance mandates "what + when" in descriptions; superpowers/Pocock found the winning rule is **when-to-use only**. Add RED/GREEN/REFACTOR-for-skills + anti-rationalization tables. Cheapest to do, and because jim *is* a skills project it lifts every skill at once.
- **jim:spec — testability + lifecycle.** Offer an EARS/WHEN-THEN option for acceptance criteria (spec + spec-check), and design a post-ship spec-amendment model (OpenSpec delta/canonical) — jim's most novel *missing capability*.
- **jim:build — an evidence/review gate.** A verification-before-completion pass (superpowers) + an independent review step; complements the planned `/jim:review`.
- **jim:research (thinnest lane).** Enforced tool-use + source discipline (verify a web search actually ran; justify empty results) — anti-hallucination rigor, **not** a scored confidence gate (jim deliberately rejects that — see the "not pursuing" list below and `004-researcher/research.md` design note, 2026-07-17).

**Deliberately NOT pursuing — the "don't jump off the bridge" list.** The ecosystem's flashiest features optimize for autonomy at the cost of control, counter to jim's locked non-goals. We are **not** adopting: unattended multi-phase autonomous runners (GSD `autonomous`, cc-sdd `kiro-impl`, Ralph/bmalph), silently-proceeding scored gates (SuperClaude ≥90%→proceed), executors that deviate "without permission," or deployment/CI/ops surface. We mine their *patterns*, not their *posture*.

**Where jim is already ahead — don't churn these.** Named Socratic Probes + three-tier AC classification (spec-check); conditional LINDDUN privacy sweep; `reviewed_phases` gate integration; STOP-on-every-failure discipline; bash-tested scripts; end-of-phase candidate-issue capture. Several have no match anywhere surveyed.

**The one-liner.** The spec-driven + skills ecosystem exploded in 2026 and mostly optimizes for autonomy and template generation — jim's edge (integrated, human-in-the-loop, transparent, compounding institutional memory) sharpened rather than blurred. The biggest wins are craft-level (authoring) and structural (spec testability + lifecycle), **not** adopting anyone's autopilot.
