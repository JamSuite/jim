We took a look at all the urls in docs/research/20260717-competitive-landscape.csv we already dug deep into each repo look at the skills in each repo and try to find any references where the skill is instructing claude code on its use of language looking for examples where the skill is asking claude to be concicse, efficient, use literal language; no metaphor or analogy; short sentences; say the thing directly; define new terms. This is what we found:

# Findings

I searched the 31 GitHub repositories in your attached list. I examined formal SKILL.md files, Claude Code command prompts, shared rules loaded by skills, and repository-level skill-authoring instructions. I excluded the reference websites, blogs, documentation sites, and directories that were also present in the CSV.

I kept the categories separate:

- **Skill:** an actual SKILL.md.
- **Shared rule:** a prompt fragment incorporated into multiple skills.
- **Command:** a Claude Code command template rather than an Agent Skill.
- **Authoring guidance:** instructions for people or Claude writing new skills.

## Strongest explicit language instructions

| Repository | File and type | Relevant instruction | What it controls |
| --- | --- | --- | --- |
| getsentry/skills | skills/brand-guidelines/SKILL.md — Skill | "Be concise - Use the fewest words needed" and "Be direct - Tell users what to do" | Concision, directness, plain language |
| getsentry/skills | skills/agents-md/SKILL.md — Skill | "Write the smallest useful file. Keep one rule per bullet. Keep rationale out unless it prevents a likely mistake." | Minimal prose, short independent rules |
| getsentry/skills | skills/blog-writing-guide/SKILL.md — Skill | "Be technically precise, opinionated, and direct." "One idea per paragraph." "Numbers over adjectives." | Precision, directness, short focused paragraphs |
| anthropics/claude-plugins-official | plugins/plugin-dev/skills/skill-development/SKILL.md — Skill | "Use objective, instructional language." "Be concrete and specific." "Focus on what to do, not who should do it." | Literal, impersonal, action-oriented language |
| anthropics/claude-plugins-official | plugins/skill-creator/skills/skill-creator/SKILL.md — Skill | "clarify terms with a short definition" | Defining unfamiliar terminology |
| anthropics/claude-plugins-official | plugins/claude-md-management/skills/claude-md-improver/SKILL.md — Skill | Avoid "Verbose explanations when a one-liner suffices"; "dense is better than verbose." | Dense, compact instructions |
| deanpeters/Product-Manager-Skills | CLAUDE.md — Authoring guidance | "Use short sentences and active voice." "Define any PM jargon that might confuse an agent." | Short sentences, active voice, definitions |
| deanpeters/Product-Manager-Skills | CLAUDE.md — Authoring guidance | "Zero fluff: Did you cut every word that doesn't earn its keep?" | Aggressive editing and efficiency |
| deanpeters/Product-Manager-Skills | skills/autonomous-investigation/SKILL.md — Skill | "default output is the strongest findings in short bullets, sized to the decision"; "Verbose Mode exists only on request." | Concise-by-default output |
| deanpeters/Product-Manager-Skills | skills/prd-development/SKILL.md — Skill | "one-question turns with plain-language prompts." | Plain language and limited conversational scope |
| deanpeters/Product-Manager-Skills | skills/user-story/SKILL.md — Skill | "Create clear, concise user stories" and use a "Brief, memorable title." | Concise product requirements |
| mattpocock/skills | skills/productivity/writing-great-skills/SKILL.md — Skill | "Every word increases context load." When meaning is duplicated, "delete the whole sentence rather than trim words." | Token efficiency and removal of duplication |
| mattpocock/skills | skills/engineering/domain-modeling/SKILL.md — Skill | "When the user uses vague or overloaded terms, propose a precise canonical term." | Precise vocabulary and terminology normalization |
| mattpocock/skills | skills/productivity/handoff/SKILL.md — Skill | "Do not duplicate content already captured… Reference them by path or URL instead." | Context economy and single-source-of-truth writing |
| addyosmani/agent-skills | skills/using-agent-skills/SKILL.md — Skill | "Point out the issue directly." "Explain the concrete downside." | Direct, concrete criticism rather than hedging |
| addyosmani/agent-skills | docs/skill-anatomy.md — Authoring guidance | Skill overviews should be "One-two sentences" and "specific/actionable, not vague." | Short descriptions and explicit actions |
| gotalab/cc-sdd | .kiro/settings/rules/design-principles.md — Shared rule | "Precise: Specific technical terms over vague descriptions. Concise: Essential information only. Consistent: Uniform terminology throughout." | Precision, concision, consistent terminology |
| gotalab/cc-sdd | .kiro/settings/rules/design-principles.md — Shared rule | Use declarative wording: "The system authenticates users," not "The system should authenticate." | Declarative rather than tentative language |
| gotalab/cc-sdd | .kiro/settings/rules/design-review.md — Shared rule | Limit the summary to two or three sentences and each critical issue to five to seven lines. | Hard size limits on review output |
| gotalab/cc-sdd | .kiro/settings/rules/tasks-generation.md — Shared rule | "keep the checkbox description concise and avoid duplicating detailed bullets" | Concise task descriptions without repetition |
| github/spec-kit | templates/commands/specify.md — Command template | "Keep it concise but descriptive enough to understand the feature at a glance." | Concise feature descriptions |
| github/spec-kit | templates/commands/clarify.md — Command template | "Answer in <=5 words." "Present EXACTLY ONE question at a time." | Extremely short answers and single-focus questions |
| github/spec-kit | templates/commands/analyze.md — Command template | "Focus on actionable findings, not exhaustive documentation." | High-signal, decision-oriented output |
| obra/superpowers | skills/brainstorming/SKILL.md — Skill | Use "a few sentences if straightforward" and ask "One question at a time." | Short explanations and focused interaction |
| affaan-m/ecc | .agents/skills/investor-outreach/SKILL.md — Skill | "Write investor communication that is short, personalized, and easy to act on." "Use proof, not adjectives." | Concise, concrete, evidence-based language |
| akaszubski/autonomous-dev | plugins/autonomous-dev/skills/skill-integration/SKILL.md — Skill | "Keep descriptions concise (one line)." | One-line skill descriptions |
| anthropics/claude-code-security-review | .claude/commands/security-review.md — Command | "AVOID NOISE: Skip theoretical issues, style concerns, or low-impact findings." | High-signal reporting and suppression of speculative prose |

## The clearest overall examples

### 1. getsentry/skills/brand-guidelines

This is the closest match to the full style you described. It explicitly asks for:

- The fewest words needed.
- Direct commands rather than descriptions of possibilities.
- Simple words instead of jargon.
- Specific wording.
- Short labels and messages.
- An explanation of what happened, why, and what to do next.
- Removal of phrases such as "in order to," hedging, and marketing language.

It does not merely ask Claude to "be concise." It supplies transformations and output limits.

### 2. anthropics/claude-plugins-official/.../skill-development/SKILL.md

This is the strongest skill-authoring guidance. It tells authors to use:

- Imperative, verb-first instructions.
- Objective and instructional language.
- Concrete and specific statements.
- Instructions about what to do rather than second-person narration.
- A lean SKILL.md, with supporting detail moved elsewhere.
- No duplicated information.

This is particularly relevant when designing a common language policy for a whole skill collection.

### 3. deanpeters/Product-Manager-Skills/CLAUDE.md

This is the strongest short-sentence and terminology guidance:

- Short sentences.
- Active voice.
- Definitions for unfamiliar PM terminology.
- Plain declarative skill names rather than clever names.
- Every word must justify its presence.

### 4. gotalab/cc-sdd/design-principles.md

This is the strongest compact style rubric:

- Declarative.
- Precise.
- Concise.
- Formal.
- Terminologically consistent.

Unlike many general requests to "write clearly," each adjective is accompanied by an operational meaning.

## Metaphor and analogy

I did not find a confirmed skill that explicitly says never to use metaphors or analogies.

The nearest examples take a softer approach:

- Sentry's blog skill rejects dramatic fragments, slogan-like aphorisms, canned rhetorical openings, and other prose that sounds clever but carries little information.
- Product-Manager-Skills actually permits "one vivid metaphor or label when it clarifies," so it is not a literal-language-only system.
- Matt Pocock's writing-great-skills is highly compressed, but the skill itself uses metaphors such as ladders and sediment to explain skill structure.

The pattern across these repositories is therefore closer to:

> Use literal and concrete language by default. Use figurative language only when it reduces explanation rather than decorating it.

That is an inference from the collected examples, not an instruction quoted from one repository.

## Skills whose own writing models the style

These stood out independently of whether they explicitly instruct Claude to write that way.

| Repository and skill | Assessment |
| --- | --- |
| open-gsd/gsd-core — skills/gsd-ns-workflow/SKILL.md | Excellent model. A compact routing table with short commands and almost no explanatory prose. It is probably the most structurally efficient skill in the set. |
| open-gsd/gsd-core — skills/gsd-new-project/SKILL.md | Excellent model. States the workflow, artifacts, and execution rule directly. Little duplication or motivational prose. |
| mattpocock/skills — skills/productivity/handoff/SKILL.md | Excellent model. Very short, narrowly scoped, and centered on a single rule: preserve state without duplicating it. |
| mattpocock/skills — skills/engineering/grill-with-docs/SKILL.md | Excellent model. A minimal router that delegates to the full skill rather than repeating instructions. |
| getsentry/skills — skills/agents-md/SKILL.md | Strong model. It follows its own advice: headings, bullets, one rule at a time, and limited rationale. |
| affaan-m/ecc — .agents/skills/investor-outreach/SKILL.md | Strong model. Compact procedures, explicit word limits, concrete examples, and a short quality gate. |
| Fission-AI/OpenSpec — skills/openspec-new-change/SKILL.md | Strong procedural model. Short numbered actions, direct commands, and little narrative explanation. |
| Fission-AI/OpenSpec — skills/openspec-apply-change/SKILL.md | Strong procedural model. Focused execution instructions, although its explicit "minimal" rule applies to code changes rather than language. |
| addyosmani/agent-skills — skills/using-agent-skills/SKILL.md | Mostly strong. Direct and concrete, but longer and more explanatory than the most compressed examples. |
| mattpocock/skills — skills/productivity/writing-great-skills/SKILL.md | Efficient but not wholly literal. It eliminates duplication effectively, but uses figurative vocabulary to explain its model. |

## Adjacent findings I did not count as language rules

A few repositories use "concise" or "minimal," but mean the size of the implementation rather than the wording:

- OpenSpec says to keep code changes minimal and focused.
- CCPM's generated CLAUDE.md asks for "the most concise solution that changes as little code as possible."
- GSD uses one-line summaries and context-efficiency requirements for particular generated artifacts.
- Trail of Bits' repository guidance discourages skills from duplicating reference material, but I did not find a direct prose-style instruction inside the examined skills.
- wshobson/agents requests clear, concise documentation in contribution guidance, but I did not find that converted into a reusable skill-level language rule.

These support efficiency, but they are weaker evidence for the language behavior you are looking for.

## Repository coverage

A "no direct hit" below means no relevant language instruction surfaced in the currently indexed skill, command, agent, or authoring files I examined. It is not proof that no historical branch or deeply nested generated file contains one.

| Result | Repositories |
| --- | --- |
| Explicit language or prompt-efficiency instruction found | github/spec-kit; obra/superpowers; mattpocock/skills; addyosmani/agent-skills; gotalab/cc-sdd; deanpeters/Product-Manager-Skills; akaszubski/autonomous-dev; affaan-m/ecc; anthropics/claude-code-security-review; anthropics/claude-plugins-official; getsentry/skills |
| Adjacent instruction or strong style model, but no clear general language rule | Fission-AI/OpenSpec; open-gsd/gsd-core; automazeio/ccpm; trailofbits/skills; wshobson/agents |
| No direct relevant instruction surfaced | marcusgoll/Spec-Flow; SuperClaude-Org/SuperClaude_Framework; PabloLION/bmad-plugin; VoltAgent/awesome-claude-code-subagents; nguyenvanduocit/research-kit; Weizhena/Deep-Research-skills; fr33d3m0n/threat-modeling; Security-Phoenix-demo/security-skills-claude-code; danielrosehill/Claude-Ideation-Planning-Plugin; MadeByTokens/claude-brainstorm; Jamie-BitFlight/claude_skills; Pimzino/claude-code-spec-workflow; Pimzino/spec-workflow-mcp; zhsama/claude-sub-agent; dralgorithm/claude-agentic-framework |

## The reusable pattern

The most effective repositories convert "be concise" into testable rules:

> Use short, declarative sentences and active voice. State the action directly. Use concrete terms instead of vague descriptions. Define unfamiliar terms briefly. Keep one idea or rule per paragraph or bullet. Remove repeated meaning rather than rephrasing it. Prefer evidence and numbers to adjectives. Use figurative language only when it replaces a longer explanation.
