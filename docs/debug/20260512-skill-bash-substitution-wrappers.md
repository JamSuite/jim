---
title: "Bash substitution silently fails inside pseudocode wrappers in skill bodies"
date: "20260512"
spec: "docs/specs/jim/001-meta/spec.md"
plan: "docs/specs/jim/001-meta/plan.md"
---

# Debug Report: Bash substitution silently fails inside pseudocode wrappers in skill bodies

## Error Analysis

Claude Code's `!`-injection preprocessor does not recognize a `` !`…` `` slot as a substitution when the slot is wrapped on the same line by the jim BASIC-style pseudocode construct `IF (…) EXISTS THEN`. The literal text lands in the LLM's context with backticks intact, no permission prompt, no error, no log line. Downstream the LLM either hallucinates the script's output or asks the user for help.

```
Literal that landed in context during /jim:plan:
    IF (!`bash /workspaces/jim/skills/file/scripts/jimfile.sh get architecture`) EXISTS THEN
```

The two adjacent failure modes already documented in `ARCHITECTURE.md` → Substitution Conventions both produce visible errors at load time (parser "Unrecognized redirect shape" for angle brackets; permission halt for `$(…)` command-substitution). **This wrapper-suppression failure is the third mode and is silent.**

**Observed behavior:** `IF (!`bash …`) EXISTS THEN` lines arrive verbatim in skill bodies. The IF idiom looks like it gates on the resolved path, but the LLM is actually gating on the unresolved substitution string. Whatever the LLM does next is a guess.

**Expected behavior:** Either the slot fires and the gate runs against the real path, or the load fails loudly the way unquoted `<lower>` placeholders already do.

---

## Reproduction Steps

User's prior test, reproduced verbatim from the brief:

1. Author a minimal skill at `.claude/skills/subtest/SKILL.md` containing the five markers below.
2. Restart Claude Code so the skill is discovered.
3. Invoke `subtest` via the Skill tool.
4. Inspect the loaded body in Claude's context.

| Marker | Source line (in SKILL.md body) | Result in context | Substituted? |
| :--- | :--- | :--- | :--- |
| A_PLAIN   | `` !`echo plain-hello` `` on its own line | `plain-hello` | ✅ |
| B_BASH    | `` !`bash -c 'echo bash-hello'` `` on its own line | `bash-hello` | ✅ |
| C_WRAPPED | `` IF (!`echo wrapped-hello`) EXISTS THEN `` | literal | ❌ |
| D_FULL    | `` IF (!`bash -c 'echo full-hello'`) EXISTS THEN `` | literal | ❌ |
| E_JIMLIKE | a real `IF (!`bash …jimfile.sh get architecture`) EXISTS THEN` | literal | ❌ |

**Reproduction command (already known to fire the bug in production):**

```
claude
> /jim:plan docs/specs/jim/<any approved spec>/spec.md
# observe: line 53 of skills/plan/SKILL.md arrives in context as literal,
# bash never ran, the LLM hallucinates or asks for help
```

**Can reproduce:** Yes (deterministic) for `IF (…) EXISTS THEN`. The remaining wrapper patterns are characterized in §Expanded Test Matrix below — those need a fresh Claude Code session to fully verify and are flagged as hypotheses where not yet confirmed.

---

## Root Cause Hypothesis

**Most likely cause:** Claude Code's preprocessor recognizes a `!`-injection slot via a textual pattern that is sensitive to what precedes the `!`. The opening paren `(` immediately before `!` (the BASIC `IF (…) EXISTS THEN` shape) is not in the accepted prefix set, so the preprocessor leaves the run of characters untouched. There is no error path for "looked like a slot but I didn't recognize it" — only the angle-bracket parser failure and the command-substitution permission gate report visible errors.

**Evidence:**

- The user's A/B/C/D test isolates the variable: identical inner expression (`` `echo wrapped-hello` ``), wrapping with `IF (` + `) EXISTS THEN` is the only change, and substitution flips off.
- `ARCHITECTURE.md:326–342` documents three sigils and two known failure modes (angle-bracket parser, command-substitution gate). It does **not** mention wrapper sensitivity — the convention assumes that any well-formed `!`-injection` substitutes regardless of surrounding text.
- `git log` confirms recent fixes (24f4193, f6d1b7b) for two other `!`-injection failure modes; neither addressed wrapper context.

**Alternative hypotheses (less likely, listed for completeness):**

- The preprocessor parses only lines where the slot starts at column 0 (or column 0 after stripping list/bullet markers). The user's bare-line A/B controls both substituted and they do start at column 0, so this remains possible — but every mid-sentence `!`-injection` in jim's production skills (`spec/SKILL.md:47`, `vision/SKILL.md:79`, `meta-skill/SKILL.md:25`, …) has been in service through multiple successful runs of /jim:spec etc., which is weak indirect evidence that mid-sentence slots do fire. **The expanded test matrix below resolves this directly.**
- Markdown rendering quirk — but `!`-injection runs *before* the LLM sees the body, so markdown-level interpretation should not be involved. Discarded.

**Affected code locations:**

- `skills/plan/SKILL.md:53` — the exact line in the user's repro
- `skills/spec/SKILL.md:33, 37` — vision + architecture locked-constraint reads
- `skills/research/SKILL.md:99, 103` — Phase 2 Alignment Validation reads
- `skills/build/SKILL.md:92` — pre-commit completion gate
- `skills/vision/SKILL.md:27, 35` — architecture upstream + differential-update gate
- `skills/arch/SKILL.md:37` — vision upstream context read
- `skills/roadmap/SKILL.md:27, 41` — vision context + differential-update gate
- `skills/brainstorm/SKILL.md:30, 34` — vision + roadmap context
- `ARCHITECTURE.md:326–342` — Substitution Conventions section that currently does not warn about this failure mode

---

## Inventory of `!`-injection Sigils

Source: `grep -rn '!\`' skills/ agents/ references/ assets/` plus contextual reading of every hit. Twenty-seven of the thirty-five raw hits are intended substitution slots (production); the remaining eight are documentation references wrapped in inline-code backticks (intentional literals — see §Other Findings).

Wrapper-context labels:

- **BARE** — alone on its line
- **IF-WRAP** — `IF (!\`…\`) EXISTS THEN` BASIC pseudocode
- **NUM-IF** — `1. IF (!\`…\`) EXISTS THEN DO:` (numbered list + IF)
- **IND-IF** — IF wrapper indented under a numbered step (3-space continuation indent)
- **MID-SENT** — embedded mid-paragraph between words
- **MID-BOLD** — mid-sentence after a bold lead-in (`**Gate 1 — Spec:**`)
- **MID-END** — mid-sentence with the slot at end, sentence-terminator period after
- **TABLE** — inside a markdown table cell
- **BULLET** — list item, slot at end of bullet body

| # | File:Line | Wrapper | Author intent | Substitution result |
| :--- | :--- | :--- | :--- | :--- |
| 1  | `skills/file/SKILL.md:18`           | BARE     | slot | ✅ confirmed |
| 2  | `skills/conf/SKILL.md:33`           | BARE     | slot | ✅ confirmed |
| 3  | `skills/plan/SKILL.md:53`           | IF-WRAP  | slot | ❌ confirmed (original repro) |
| 4  | `skills/spec/SKILL.md:33`           | IF-WRAP  | slot | ❌ matches C/D/E |
| 5  | `skills/spec/SKILL.md:37`           | IF-WRAP  | slot | ❌ matches C/D/E |
| 6  | `skills/brainstorm/SKILL.md:30`     | IF-WRAP  | slot | ❌ matches C/D/E |
| 7  | `skills/brainstorm/SKILL.md:34`     | IF-WRAP  | slot | ❌ matches C/D/E |
| 8  | `skills/vision/SKILL.md:27`         | IF-WRAP  | slot | ❌ matches C/D/E |
| 9  | `skills/vision/SKILL.md:35`         | IF-WRAP  | slot | ❌ matches C/D/E |
| 10 | `skills/roadmap/SKILL.md:27`        | IF-WRAP  | slot | ❌ matches C/D/E |
| 11 | `skills/roadmap/SKILL.md:41`        | IF-WRAP  | slot | ❌ matches C/D/E |
| 12 | `skills/arch/SKILL.md:37`           | IF-WRAP  | slot | ❌ matches C/D/E |
| 13 | `skills/build/SKILL.md:92`          | NUM-IF   | slot | ❌ likely (compound) — needs matrix |
| 14 | `skills/research/SKILL.md:99`       | IND-IF   | slot | ❌ likely (indented IF wrapper) — needs matrix |
| 15 | `skills/research/SKILL.md:103`      | IND-IF   | slot | ❌ likely (indented IF wrapper) — needs matrix |
| 16 | `skills/arch/SKILL.md:24`           | TABLE    | slot | ❓ unconfirmed — needs matrix |
| 17 | `skills/arch/SKILL.md:31`           | MID-END  | slot | ❓ unconfirmed — needs matrix |
| 18 | `skills/vision/SKILL.md:79`         | MID-END  | slot | ❓ unconfirmed — needs matrix |
| 19 | `skills/roadmap/SKILL.md:75`        | MID-END  | slot | ❓ unconfirmed — needs matrix |
| 20 | `skills/spec/SKILL.md:47`           | MID-SENT | slot | ❓ unconfirmed — needs matrix |
| 21 | `skills/roadmap/SKILL.md:35`        | MID-SENT | slot | ❓ unconfirmed — needs matrix |
| 22 | `skills/meta-test/SKILL.md:47`      | MID-BOLD | slot | ❓ unconfirmed — needs matrix |
| 23 | `skills/meta-agent/SKILL.md:23`     | MID-SENT | slot | ❓ unconfirmed — needs matrix |
| 24 | `skills/meta-agent/SKILL.md:25`     | MID-BOLD | slot | ❓ unconfirmed — needs matrix |
| 25 | `skills/meta-skill/SKILL.md:23`     | MID-SENT | slot | ❓ unconfirmed — needs matrix |
| 26 | `skills/meta-skill/SKILL.md:25`     | MID-BOLD | slot | ❓ unconfirmed — needs matrix |
| 27 | `skills/debug/SKILL.md:35`          | BULLET   | slot | ❓ unconfirmed — needs matrix |

Documentation references (intentionally literal, NOT slots — wrapped in inline-code backticks so the preprocessor leaves them alone):

| # | File:Line | Construct | Note |
| :--- | :--- | :--- | :--- |
| D1 | `skills/meta-skill/SKILL.md:104` | `` `!`-injected paths` ``        | checklist line, inline-code wrapper |
| D2 | `skills/meta-skill/SKILL.md:105` | `` `!`-injection integrity` `` + `` `!`bash …` `` | checklist line |
| D3 | `skills/meta-skill/SKILL.md:106` | `` `!`-injection inputs` ``      | checklist line |
| D4 | `skills/meta-agent/SKILL.md:125` | `` `!`-injected paths` ``        | checklist line |
| D5 | `agents/meta.md:66`              | `` `!`-injected paths` ``        | prose in agent body |
| D6 | `skills/conf/SKILL.md:19`        | `` `!`-injection primitive` ``   | prose in skill body |
| D7 | `skills/file/scripts/jimfile.sh:9` | bash comment                   | not LLM-visible |
| D8 | `skills/conf/scripts/jimconf.sh:7` | bash comment                   | not LLM-visible |

The documentation references depend on inline-code (`` ` ``) wrapping suppressing substitution — if pattern P in the test matrix below comes back ✅ instead of ❌, these docs will silently fire at load time too. **Verifying P is therefore important even though it would not normally be a "defect."**

---

## Expanded Test Matrix

A scaffold to characterize every wrapper pattern has been written to
`.claude/skills/subtest/SKILL.md`. It contains 20 patterns (A–T), each
with a unique sentinel marker. To run:

1. Quit and relaunch Claude Code from this repo so the new skill is discovered.
2. Invoke it via the Skill tool (or any mechanism that loads the body into context).
3. For each pattern, check whether the sentinel (e.g. `SUBST_E_BULLET_TAIL`) appears in the loaded body. Sentinel visible → ✅. Literal `` !`echo SUBST_…` `` visible → ❌.

Matrix rerun dated 2026-05-12. The `Confirmed` column below reflects the actual observed results from that rerun; the table is a results-recording surface and is updated in place per spec 011's "annotate, not rewrite" history policy. The surrounding analysis prose (§Inventory, §Root Cause Hypothesis, §Affected Skills, §Other Findings, §Appendix) is preserved verbatim — those sections remain forensically accurate.

| Pattern | Description | Expected | Confirmed |
| :--- | :--- | :--- | :--- |
| A | bare on its own line | ✅ | ✅ confirmed (2026-05-12) |
| B | bare with `bash -c` | ✅ | ✅ confirmed (2026-05-12) |
| C | `IF (…) EXISTS THEN` wrapper | ❌ | ❌ confirmed (2026-05-12) |
| D | `IF (bash -c …) EXISTS THEN` wrapper | ❌ | ❌ confirmed (2026-05-12) |
| E | bullet, slot at tail | ? | ✅ confirmed (2026-05-12) |
| F | numbered list, slot at tail | ? | ✅ confirmed (2026-05-12) |
| G | numbered + IF wrapper (`build/SKILL.md:92` shape) | ? | ❌ confirmed (2026-05-12) |
| H | indented IF wrapper under numbered step (`research/SKILL.md:99` shape) | ? | ❌ confirmed (2026-05-12) |
| I | mid-sentence between words | ? | ✅ confirmed (2026-05-12) |
| J | mid-sentence after bold lead-in (`meta-skill/SKILL.md:25` shape) | ? | ✅ confirmed (2026-05-12) |
| K | slot then trailing period (`vision/SKILL.md:79` shape) | ? | ✅ confirmed (2026-05-12) |
| L | inside table cell (`arch/SKILL.md:24` shape) | ? | ✅ confirmed (2026-05-12) |
| M | inside blockquote | ? | ✅ confirmed (2026-05-12) |
| **N** | inside fenced code block | ❌ (expected) | **✅ observed (2026-05-12) — fences DO NOT suppress** |
| **O** | inside indented code block | ❌ (expected) | **✅ observed (2026-05-12) — indented code DOES NOT suppress** |
| **P** | inside inline backticks (relied on by D1–D6) | ❌ (expected) | **❌ confirmed (2026-05-12) — inline-code is the only literal-quoting wrapper** |
| Q | inside HTML comment | ? | ✅ confirmed (2026-05-12) |
| R | slot at line start, no leading space | ✅ (sibling of A) | ✅ confirmed (2026-05-12) |
| S | leading space then slot | ? | ✅ confirmed (2026-05-12) |
| T | parens NOT in IF construct | ? | ✅ confirmed (2026-05-12) |
| U | `READ_IF_EXISTS <slot> — note` | ✅ (target) | ✅ confirmed (2026-05-12) |
| V | `RUN_IF_EXISTS <slot> — note` | ✅ (target) | ✅ confirmed (2026-05-12) |
| W | `SET <name> = <slot>` | ✅ (target) | ✅ confirmed (2026-05-12) |
| X | `DO_IF_EXISTS <slot>:` + numbered list | ✅ (target) | ✅ confirmed (2026-05-12) |
| Y | `1. READ_IF_EXISTS <slot> — note` (numbered + directive) | ✅ (target) | ✅ confirmed (2026-05-12) |
| Z | indented directive under numbered step | ✅ (target) | ✅ confirmed (2026-05-12) |
| **AA** | SET + lean IF with indented numbered body, no `DO:`/`DONE`, `ENDIF` terminator | ✅ (target) | ✅ confirmed (2026-05-12) |
| **BB** | SET + `IF … THEN` / `ELSE IF X == "value" THEN` / `ENDIF` chained form | ✅ (target) | ✅ confirmed (2026-05-12) |

**The two consequential surprises** are N ✅ and O ✅: prior to the 2026-05-12 rerun, both were expected to suppress (the original report drafted ❌ as the expectation row). They do not. Only matrix P (inline backticks) literal-quotes a slot. This means fences and indented code blocks are *visual-rendering* surfaces, not substitution surfaces — a documentation author wanting to display a literal `!`-injection slot must use inline-code, never a fence. The premise underpinning spec 011 plan Decision 4 ("fences must go because they doubly suppress") was disproven by this rerun and is reframed in `docs/specs/jim/011-directive-vocabulary/plan.md` → Decision 4 reframe.

---

## Affected Skills/Agents — Severity Ranking

Twelve `IF-WRAP` slots are confirmed-defective by the C/D/E controls. Eight more (NUM-IF, IND-IF, MID-*, TABLE, BULLET) are uncharacterized pending the matrix. Severity ranking below assumes the confirmed defects only.

### Tier 1 — Locked-constraint violations (silently skipped invariants)

1. **`skills/plan/SKILL.md`** — line 53 (architecture). Original repro. Every /jim:plan run silently fails to read ARCHITECTURE.md and proceeds against an imagined path.
2. **`skills/spec/SKILL.md`** — lines 33, 37 (vision, architecture). Both locked constraints documented as "not negotiable" silently skipped on every /jim:spec.
3. **`skills/research/SKILL.md`** — lines 99, 103 (vision, architecture) inside Phase 2 Alignment Validation. The alignment statement the skill is required to produce is fabricated rather than grounded. (These are IND-IF — slightly different wrapper, but inside the same IF construct so the same suppression almost certainly applies. Confirm via pattern H.)
4. **`skills/arch/SKILL.md`** — line 37 (vision upstream context). New architecture documents miss vision-tension flags.

### Tier 2 — Workflow gates degraded (state-detection broken)

5. **`skills/build/SKILL.md`** — line 92 (pre-commit completion gate). Every /jim:build's final step. If the IF body doesn't run, the test suite is never verified before the human is asked to mark plan `complete`. (NUM-IF wrapper — confirm via pattern G; high prior probability given the `(!` substring is identical.)
6. **`skills/vision/SKILL.md`** — lines 27 (architecture read), 35 (differential-update gate). Line 35 is the gate that decides "this is a differential update" vs "fresh creation." If it fails, the skill always thinks no VISION.md exists and overwrites blindly. **Data-loss risk** on re-runs.
7. **`skills/roadmap/SKILL.md`** — lines 27 (vision read), 41 (differential-update gate). Same data-loss-on-re-run risk as vision.

### Tier 3 — Soft context skipped (degrades quality, not correctness)

8. **`skills/brainstorm/SKILL.md`** — lines 30, 34 (vision + roadmap for end-of-session routing). End-of-session routing suggestions become un-grounded; no other behavior broken.

### No defects — bare-line slots only

- `skills/file/SKILL.md` (line 18 BARE)
- `skills/conf/SKILL.md` (line 33 BARE)

### Pending matrix verification (not classified as defects yet)

- `skills/arch/SKILL.md:24` (TABLE), `:31` (MID-END)
- `skills/vision/SKILL.md:79` (MID-END)
- `skills/roadmap/SKILL.md:35` (MID-SENT), `:75` (MID-END)
- `skills/spec/SKILL.md:47` (MID-SENT)
- `skills/meta-test/SKILL.md:47` (MID-BOLD)
- `skills/meta-agent/SKILL.md:23` (MID-SENT), `:25` (MID-BOLD)
- `skills/meta-skill/SKILL.md:23` (MID-SENT), `:25` (MID-BOLD)
- `skills/debug/SKILL.md:35` (BULLET)

---

## Other Relevant Findings

1. **`ARCHITECTURE.md` does not document this failure mode.** The Substitution Conventions section (lines 326–342) lists two known failure paths (angle-bracket parser, missing script integrity) and the eager-vs-deferred timing rule. It does not warn that pseudocode wrappers suppress substitution. The fix-recipe spec should add a third bullet to the Rules list.

2. **The BASIC-style IF idiom (`ARCHITECTURE.md:316–322`) is the source of the bug.** The convention says inline `IF (X) EXISTS THEN ... END IF` is "safe outside fences" and `meta-skill`/`meta-agent` validate against invented variants. Both validation checklists (`meta-skill/SKILL.md:125`, `meta-agent/SKILL.md:104`) explicitly tell authors to wrap `!`-injected paths in this idiom. **The convention as written produces the bug.** Fix recipes hoist the substitution onto its own line above the IF, which is incompatible with the documented idiom and will need a convention update too.

3. **Documentation references (D1–D8) depend on inline-code suppressing substitution.** Six of the eight literal `\`!\`-injection\`` references in the docs are wrapped in inline-code backticks; the other two are inside `.sh` files that the LLM never sees as substitution candidates. If pattern P in the matrix is unexpectedly ✅, the documentation will quietly start firing `bash …` at load time — confirm P early.

4. **Fenced bash blocks (e.g. `brainstorm/SKILL.md:42–44`) are not affected.** They use a different mechanism — the LLM substitutes `<placeholder>` values and runs the block via the Bash tool *after* reading the body. They are the "deferred timing" path and behave correctly. No defect there.

5. **`skills/build/SKILL.md:92` compounds two suppressing wrappers** (numbered list prefix + IF construct). The matrix patterns G (numbered + IF) and F (numbered alone) tell you whether the numbered prefix alone would already suppress; that information matters if the fix is to drop the IF wrapper but keep the numbered list.

6. **No `assets/` or `references/` files contain `!`-injection slots.** Confirmed by recursive grep — these directories are LLM-rendered after the parent skill has loaded, so the absence of slots is correct.

7. **No "orphaned bash invocations" in pseudocode.** I checked for lines that contain a `bash ...` invocation but no leading `!` sigil and that look like the author intended a substitution. None found. Every intended slot uses the sigil.

---

## Appendix — Proposed Convention to Scope into the Bug Spec

The BASIC IF idiom is part of the bug surface (it wraps `!`-injection` in parens, which the preprocessor rejects) and is heavier than the dominant use case needs (~20 tokens of scaffolding around 1 bit of semantic content). A smaller, more declarative vocabulary — closer in spirit to TCL/Tk one-liners than to BASIC structured pseudocode — would:

- Cut tokens by ~3-4× on the common case.
- Move `!`-injection slots to end-of-line, after benign text — sidestepping the wrapper bug class entirely (subject to test matrix verification, see §Test Plan below).
- Stay trivially regex-validatable by `meta-skill` / `meta-agent`.
- Reserve BASIC `IF / ELSE / END IF` for cases that *actually* branch.

### Proposed directive vocabulary

| Directive | Shape | When to use |
| :--- | :--- | :--- |
| `READ_IF_EXISTS <slot> — note`     | one line | conditional read of a single path |
| `RUN_IF_EXISTS <slot> — note`      | one line | conditional run of an executable gate |
| `SET <name> = <slot>`              | one line | bind a `!`-injection` result for reuse |
| `DO_IF_EXISTS <slot>:` + numbered list | block | rare multi-step gate |
| `IF <bound-name> EXISTS THEN … ELSE … END IF` | block | genuine branching prose (paren-free; the slot lives in a preceding `SET`) |

Hard rules:

1. `!`-injection slots must live at end-of-line, preceded only by an allowed prefix (`SET … = `, `READ_IF_EXISTS `, `RUN_IF_EXISTS `, `DO_IF_EXISTS `) or by nothing at all (bare line). Never wrapped in `(…)`.
2. `IF … THEN … ELSE … END IF` may not contain a `!`-injection inside its expression — bind via `SET` first, then reference the bound name.
3. The note suffix (`— note`) is plain prose explaining the *why* of the gate, for the LLM's benefit.

### Concrete migration examples

**Example 1 — `skills/spec/SKILL.md:33-39` (two stacked locked-constraint reads).**

Before:

```markdown
IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`) EXISTS THEN
  READ FILE — locked constraint. Do not re-litigate strategic decisions.
END IF

IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`) EXISTS THEN
  READ FILE — locked constraint. Technical invariants are not negotiable.
END IF
```

After:

```markdown
READ_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision` — locked constraint, do not re-litigate strategic decisions.
READ_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture` — locked constraint, technical invariants are not negotiable.
```

Token delta: ~50 → ~22 (roughly halved). Six lines collapse to two.

**Example 2 — `skills/build/SKILL.md:92-95` (multi-step pre-commit gate, numbered-list + IF).**

Before:

```markdown
1. IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get pre_commit`) EXISTS THEN DO:
   1. Run it via Bash.
   2. Show the full output.
   DONE
```

After:

```markdown
1. DO_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get pre_commit`:
   1. Run it via Bash.
   2. Show the full output.
```

The outer numbered step keeps its number; the `DO_IF_EXISTS` replaces `IF (…) EXISTS THEN DO:` and `DONE`. Inner steps unchanged.

**Example 3 — `skills/vision/SKILL.md:35-39` (genuine branching with ELSE).**

Before:

```markdown
IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`) EXISTS THEN
  This is a differential update. Read the content. Tell the user: "I see an existing VISION.md. I'll walk through each section …". Identify which sections are well-defined vs. which need work.
ELSE
  Fresh creation. Proceed to interview.
END IF
```

After:

```markdown
SET vision_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`

IF vision_doc EXISTS THEN
  This is a differential update. Read the content. Tell the user: "I see an existing VISION.md. I'll walk through each section …". Identify which sections are well-defined vs. which need work.
ELSE
  Fresh creation. Proceed to interview.
END IF
```

The `SET` hoists the `!`-injection` onto a paren-free, end-of-line surface; the IF/ELSE shape is preserved because this case actually has two branches. `IF X EXISTS THEN` is paren-free — note this is a convention change from the current `IF (X) EXISTS THEN`.

**Example 4 — `skills/research/SKILL.md:99-105` (indented under a numbered step).**

Before:

```markdown
1. Read strategic constraints, if present:

   IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`) EXISTS THEN
     READ FILE — locked constraint.
   END IF

   IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`) EXISTS THEN
     READ FILE — locked constraint.
   END IF
```

After:

```markdown
1. Read strategic constraints, if present:

   READ_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision` — locked constraint.
   READ_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture` — locked constraint.
```

### Test Plan — verify the directives before betting on them

**Do not commit to this convention until the test matrix confirms the directives substitute.** The cost of converting ~12 production slots is wasted if the preprocessor rejects the directive prefix.

The test scaffold at `.claude/skills/subtest/SKILL.md` has been extended with patterns **U through Z** covering the proposed directives:

| Pattern | Shape | Expected | What a ❌ here means |
| :--- | :--- | :--- | :--- |
| U | `READ_IF_EXISTS <slot> — note`         | ✅ | the dominant migration target fails — pick a different prefix shape |
| V | `RUN_IF_EXISTS <slot> — note`          | ✅ | the run-flavor target fails — same |
| W | `SET <name> = <slot>`                  | ✅ | the bind-then-IF/ELSE escape route fails — must inline `!`-injection` slots and lose the IF/ELSE shape |
| X | `DO_IF_EXISTS <slot>:` + numbered list | ✅ | multi-step gates can't be directive-shaped — must fall back to `SET` + `DO:` BASIC |
| Y | `1. READ_IF_EXISTS <slot> — note`      | ✅ | numbered-list compound directives fail — must hoist directive out of the list |
| Z | indented directive under numbered step | ✅ | indented directives fail — must un-indent or wrap differently |

**How to run:**

1. Quit Claude Code and relaunch from the repo root so `.claude/skills/subtest/SKILL.md` is discovered at session start (`!`-injection` is resolved at skill-load time only).
2. Invoke `subtest` via the Skill tool (or as a slash command if registered).
3. For each of A–Z, scan the loaded body for the `SUBST_*` sentinel. Sentinel visible → ✅. Literal `` !`echo SUBST_*` `` visible → ❌.
4. Update the cross-reference table in §Inventory above with the actual results for E–T (currently ❓), and use the U–Z results as the go/no-go signal on the directive vocabulary.

**Success criteria for the bug spec:**

- All of U, V, W, X, Y, Z must come back ✅ for the proposed vocabulary to be viable.
- If U, V come back ✅ but X (multi-step) fails, the vocabulary survives — but `DO_IF_EXISTS` is dropped and multi-step gates fall back to `SET` + a BASIC `IF X EXISTS THEN DO:` block.
- If U fails, the prefix-text hypothesis is wrong and the convention has to use a different shape entirely (e.g. the bare-line A1 hoist from earlier discussion).

**Validation hook:**

Once the matrix confirms the vocabulary works, `meta-skill` / `meta-agent` validation checklists update to:

- [ ] No `!`-injection` slot is inside `(…)`.
- [ ] Every `!`-injection` slot is bare-line, preceded by an allowed directive prefix, or preceded by an allowed `SET … = ` assignment.
- [ ] Existence gates use a directive (`READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS`) or a `SET` + paren-free `IF X EXISTS THEN … ELSE … END IF` block. No invented variants.

---

## Affected Specs/Plans

| Artifact | Path | Relationship |
| :--- | :--- | :--- |
| Spec | `docs/specs/jim/001-meta/spec.md` | Defines the substitution + idiom conventions that produce this bug. A new spec must amend §Substitution Conventions and §Logic-Flow Conventions, OR be filed as a follow-up bug spec with `origin:` pointing at this report. |
| Plan | `docs/specs/jim/001-meta/plan.md` | Same scope as the spec — the BASIC idiom and the substitution rules were both implemented under this plan. |
| Plan | `docs/specs/jim/009-jimfile/plan.md` | All eight `IF-WRAP` slots reference `jimfile.sh get …`. Plan does not need editing, but its consumers (the eight production skills) need rework. |

---

## Recommended Next Step

**Recommendation: Option C — Spec update needed (open a bug spec via `/jim:spec`).**

**Option A — Direct fix:** Not appropriate. The fix touches ~12 confirmed defective lines across 8 production skill files and requires a convention change in `ARCHITECTURE.md` (Substitution Conventions + the BASIC IF idiom). A direct edit would also need to revise `meta-skill` and `meta-agent` validation checklists, which currently *require* the broken idiom. Too much surface area for a non-spec fix.

**Option B — Plan update:** Not appropriate. No single plan task introduced the defect; the BASIC IF idiom and the `!`-injection convention were both encoded under the original 001-meta plan and have been reproduced by every skill author since.

**Option C — Spec update via `/jim:spec`:** This is the right path. The bug spec should capture:

1. The convention currently published in `ARCHITECTURE.md` produces a silent-failure pattern in skill bodies.
2. The proposed replacement is the directive vocabulary in §Appendix — `READ_IF_EXISTS` / `RUN_IF_EXISTS` / `SET` / `DO_IF_EXISTS`, paren-free `IF X EXISTS THEN … ELSE … END IF` for genuine branching. Migration examples for the four representative production shapes are in the appendix.
3. The matrix run on `.claude/skills/subtest/SKILL.md` (patterns E–Z) is a **hard prerequisite**. Patterns U–Z must come back ✅ for the directive vocabulary to be viable; patterns E–T characterize which legacy production hits are defects vs. working-as-is. The spec must not commit to the new convention until the matrix has been run.
4. The `meta-skill` and `meta-agent` validation checklists must be updated in lockstep with the convention — the current checklists *require* the broken `IF (X) EXISTS THEN` shape. Replacement checklist items are sketched at the end of the appendix.
5. `ARCHITECTURE.md` → Substitution Conventions and → Logic-Flow Conventions both need editing in the same PR.
6. Migration of the ~12 confirmed `IF-WRAP` slots (plus any E–T hits that come back ❌) is part of the plan derived from this spec.
7. This report should be referenced via the bug spec's `origin:` frontmatter field.

**Chosen recommendation: C** — the defect is convention-level and crosses spec, plan, and validation-checklist surfaces. Funneling through `/jim:spec` ensures the convention, validation, ARCHITECTURE.md, and the production migrations all land together rather than drifting apart again. The test matrix gates the spec — no convention change is committed until U–Z verify.

---

**Resolved by spec 011** — see `ARCHITECTURE.md` → Substitution Conventions and `ARCHITECTURE.md` → Logic-Flow Conventions.
