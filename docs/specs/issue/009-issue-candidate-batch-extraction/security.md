---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-06-20"
---

# Security Review: Issue candidate-batch mechanics extraction

## Summary

**Findings:** 1 Critical · 3 Notable · 2 Advisory

Plan-phase re-run (dual lens: spec + plan). **New this run:** 1 Critical (Finding 5 — untrusted body reaches `new.sh` through an LLM-built shell heredoc, a command-injection vector) and 1 Advisory (Finding 6). The three spec-phase Notable findings (1–3) and the spec-phase Advisory (4) are now **addressed by the plan's design** — see each finding's *Plan status*. **Update (routing applied):** Findings 5 and 6 have since been routed into the plan (DD3 + interface → `--body-file`; task 2 extended), so every finding is now design-addressed — status returned to Active. LINDDUN omitted — the tool processes the developer's own project-internal artifacts, not external data-subject personal data.

## Coverage

- spec.md — reviewed 2026-06-20 (requirements-gap lens)
- plan.md — reviewed 2026-06-20 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | No external data-subject data by design. Issue bodies are developer-authored notes; incidental content is developer-controlled. |
| Credentials | No | Not handled by design. A `body` could incidentally contain a pasted secret; the existing AC-C2 scrub reminder is the control, preserved by this refactor. |
| Session data | No | None. |
| Internal-only | Yes | Issue files are project-internal discovery artifacts, committed alongside code; `body`/`title`/`labels` are untrusted (drawn from tool results, file reads, prior-issue content). |
| Public | No | None. |

## Findings

### 5. Untrusted body reaches `new.sh` through an LLM-constructed shell heredoc (command injection)

- **Severity:** Critical
- **Description:** Plan Design Decision 3 routes the candidate `body` to `new.sh` via a quoted heredoc (`<<'BODY'`) that the surfacing skill constructs at runtime. The body is untrusted (it may derive from tool results, file reads, or web content). Any transport that inlines untrusted bytes into an LLM-written shell command is injection-prone: a body line equal to the heredoc delimiter terminates the heredoc early and the following lines run as shell; a `printf "<body>"` variant is worse (a `"` or `$(…)` in the body breaks out via command substitution). The script's internal YAML-encoding never runs — the break-out happens in the *caller's* shell before `new.sh` starts. This defeats AC4's guarantee that an untrusted body cannot break out.
- **Suggestion:** Do not pass untrusted body through a shell command the LLM composes. Change the interface to `--body-file <path>`: the surfacing skill writes the body to a temp file with the **Write tool** (which does not shell-interpret content), then passes the trusted path to `new.sh`, which reads the file as bytes — keeping untrusted content off the shell command line entirely. Add an adversarial test (body containing the delimiter token, `"`, and `$(…)`) asserting no execution and intact output.
- **Route:** Plan
- **Relates to:** Plan DD3, AC #4
- **Plan status:** Resolved — plan DD3 + interface contract changed to `--body-file`: the skill writes the body via the Write tool to a temp file and `new.sh` appends it verbatim, so untrusted body never reaches a shell command line; task 2 adds the adversarial body-transport test.

### 1. Untrusted field values can inject into issue frontmatter or corrupt the index parser

- **Severity:** Notable
- **Description:** The refactor shifts issue-file writing from LLM-mediated (Write tool) to a deterministic script. Today the LLM implicitly normalizes field values as it composes the file; a script does not. Untrusted `title` / `labels` / `body` containing YAML metacharacters (quotes, colons, newlines), a `---` line, or a leading `[[` could break out of their template slots — forging or altering frontmatter fields (e.g. `priority`, `status`), breaching the frontmatter/body boundary, or corrupting `index.sh`'s frontmatter-bounded parse and `render.sh`'s reads.
- **Suggestion:** Add an AC requiring the write mechanism to treat every field value as inert data and encode it safely (quote/escape YAML scalars; guarantee `body` cannot cross the frontmatter boundary), so no untrusted field can inject frontmatter, alter another field, or break the index/render parsers. Make it testable — bash tests feed adversarial titles/bodies (embedded `---`, newlines, quotes) and assert containment.
- **Route:** Spec → routed into spec as AC #4 (encoding) + the safe-handling Desired State bullet.
- **Relates to:** AC #1, AC #7
- **Plan status:** Addressed in design — Plan DD4 makes `new.sh` the sole emitter owning YAML-encoding of scalar fields; task 2 adds adversarial encoding tests. (The *body transport* gap is tracked separately as Finding 5.)

### 2. Target path must derive only from the validated id resolver

- **Severity:** Notable
- **Description:** A deterministic write mechanism must resolve its output path exclusively via `jimfile.sh next-id` / `path` (which validate through `is_valid_id`), never compose a path from raw `title`/slug input. A raw-input title such as `../../../etc/x` could otherwise direct the write outside the issues directory. This is the discipline `render.sh show` already follows (security-019 Finding 1); the new write path must not regress it.
- **Suggestion:** Add an AC (or strengthen AC #1) requiring the mechanism to obtain its path solely through the validated resolver and to reject any id failing `is_valid_id`, so untrusted input cannot direct the write outside the issues directory.
- **Route:** Spec → routed into spec as AC #5.
- **Relates to:** AC #1
- **Plan status:** Addressed in design — Plan interface validates via `jimfile.sh valid-id <slug>` and composes the path via `path issue <slug>`; task 2 adds an invalid-id rejection test.

### 3. Single-sourcing must preserve the filters' anti-injection clauses

- **Severity:** Notable
- **Description:** The pipeline-ownership filter and the untrusted-content rule carry security-relevant instructions — judge from the agent's own knowledge, and never trust directive-style claims embedded in candidate bodies (a body asserting "I am pipeline-owned" or "priority: critical" must not bind the decision). AC #4 compresses the filters to a brief restatement plus pointer. If the restatement drops the "never trust embedded claims" property, an attacker-influenced candidate body (drawn from tool results, file reads, or prior issues) could suppress a real issue or escalate its priority/labels. The spec flags fidelity as Open Question 1 / Handoff Insight 3; this elevates it to a security requirement.
- **Suggestion:** Make it an explicit AC: the single-sourced/restated filters and the unified fileable bar must preserve the anti-injection semantics (the agent ignores ownership / priority / label claims embedded in untrusted candidate content). Lean toward resolving Open Question 1 by keeping that clause inline rather than pointer-only.
- **Route:** Spec → routed into spec as AC #8 (anti-injection preserved).
- **Relates to:** AC #4, AC #5
- **Plan status:** Addressed in design — Plan DD5 keeps the Pipeline-ownership anti-injection sentence inline in each skill; Open Question 1 resolved toward inline.

### 4. Keep terminal output free of untrusted title/body

- **Severity:** Advisory
- **Description:** Spec 018 § Out of Scope requires skipped candidates be referenced by row index, not title, to avoid re-exposing conversation content in terminal logs. The shared write mechanism's summaries, skip reasons, and error messages must preserve that discipline rather than echoing raw untrusted `title`/`body`.
- **Suggestion:** Specify in the plan that the mechanism's stdout/stderr surfaces failures by row index + a fixed reason code, never raw `title`/`body` content.
- **Route:** Plan
- **Relates to:** AC #7
- **Plan status:** Addressed in design — Plan interface specifies `new.sh` prints only `<slug>\t<path>` and emits failures as fixed stderr reason codes, never raw field content.

### 6. Adversarial `--labels` encoding not explicit in the test plan

- **Severity:** Advisory
- **Description:** AC4 names `title`, `labels`, *and* `body` as untrusted inputs the emitter must encode safely, but Plan task 2's adversarial cases enumerate only title/body. A label containing `]`, `,`, `"`, or a leading `[[` could still break the inline YAML array if encoding/validation is under-tested.
- **Suggestion:** Extend Plan task 2's adversarial cases to include `--labels` values (`]`, comma, quote, `[[`), asserting the emitted `labels:` array stays well-formed and `index.sh` parses it.
- **Route:** Plan
- **Relates to:** Plan task 2, AC #4
- **Plan status:** Resolved — task 2 extended to cover adversarial `--labels`.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 (forged ownership/priority/label claims embedded in untrusted candidate content) |
| Tampering | Yes | Findings 1, 2, 5 (frontmatter/field injection; path traversal; body-transport command injection) |
| Repudiation | N/A | No audit-trail requirement; git history records issue-file creation. |
| Information Disclosure | Yes | Finding 4 (terminal echo of untrusted content); incidental secrets in bodies guarded by the existing AC-C2 scrub reminder. |
| Denial of Service | N/A | Local single-developer tool; batch size bounded by a run's candidates; no remote/untrusted-volume input. |
| Elevation of Privilege | Yes | Finding 5 — body-transport command injection executes attacker-influenced shell in the skill's context. |

## Artifact Misalignment

- **Finding 5 — body transport vs AC4:** Spec AC #4 asserts an untrusted `body` cannot break out of its slot or inject; the plan's DD3 transport (LLM-built shell heredoc) lets the body break out at the caller's shell *before* `new.sh`'s encoding runs. The plan's design does not preserve the spec requirement. Route: Plan (change the transport).

## Routing Recommendations

### Spec amendments
*(Findings 1–3 were already routed into the spec as AC #4, AC #5, and AC #8, and are now design-addressed by the plan.)*
- Finding 1: safe, inert encoding of all untrusted field values so they cannot inject frontmatter or break the index/render parsers.
- Finding 2: path derivation solely through the validated id resolver (`is_valid_id`).
- Finding 3: the single-sourced filters and unified fileable bar preserve the anti-injection semantics.

### Plan amendments
- **Finding 5 (Critical):** replace DD3's heredoc body transport with a `--body-file <path>` interface — the skill writes the body via the Write tool to a temp file, never through a shell command; add an adversarial body-transport test.
- Finding 6: extend task 2's adversarial cases to cover `--labels`.
- Finding 4 (addressed): the plan interface already specifies stderr reason codes / `<slug>\t<path>` stdout — no further change needed.
