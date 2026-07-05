# Authoring invariant checks

How to fill the blueprint's **Invariants** table so `/jim:verify` can check the
group's code against it. Read this when generating or updating a group blueprint
(`/jim:blueprint <group>`); the verification engine (spec 035) consumes exactly
this shape.

## The table

```markdown
| Id | Invariant | Criticality | Check |
| :--- | :--- | :--- | :--- |
| path-resolver | Paths are resolved via jimfile.sh, never composed by hand | critical | pattern |
| skill-budget  | SKILL.md ≤ 500 lines                                      | medium   | registry:linecount |
| domain-bounds | Agents do not cross domain boundaries                    | high     | judge |
```

- **Id** — a stable kebab-case slug (`^[a-z0-9][a-z0-9-]*$`). It keys the check
  to its parameters and names the invariant in the run's report. Keep it stable
  across regens so trend history stays attributable.
- **Invariant** — the *rule*, stated once. Never a per-instance implementation
  detail; never an inline command.
- **Criticality** — `critical` / `high` / `medium` / `low` (the spec 029 enum,
  unchanged). Drives appetite gating and the priority of any filed violation.
- **Check** — one method from the closed vocabulary below. Anything the engine
  does not recognize (prose, blank) falls back to `judge` — a legacy blueprint
  with no structured check data still verifies, unchanged.

## The method vocabulary

A closed set of four. Choose the cheapest rung that *faithfully* checks the
rule; `judge` is always available as the fallback when no mechanical check
captures it honestly.

| Method | What it does | When to use |
| :--- | :--- | :--- |
| `pattern` | A regex must (or must-not) match within the group's territory | Textual rules: a banned construct, a required marker, a naming shape |
| `structure` | A path exists, or a glob matches nothing | Layout rules: a required file is present, a forbidden artifact is absent |
| `registry:<name>` | The engine runs the operator's configured `verify_command_<name>` | Project tooling: a linter, type checker, or test runner the operator wires up |
| `judge` | Read-only LLM judgment over the rule text and the relevant code | Semantic rules no mechanical check captures — the always-available fallback |

**Three-tier floor.** `pattern` and `structure` are jim-native primitives that
run out of the box with zero config. `registry:<name>` reaches project tooling
the operator configures. `judge` is the ceiling — reasoning, appetite-gated by
criticality. jim ships no AST parser: AST-grade checks enter only as
`registry:<name>` project tooling or `judge` reasoning.

**Prefer mechanical, but never fake it.** A `pattern`/`structure` check that
only approximates the rule is worse than an honest `judge`. If a grep would give
false confidence, record `judge` and let the ceiling reason about it.

## The `verify-checks` block

Inert parameters for `pattern` and `structure` methods live in an optional fenced
block, keyed by `Id`. They never go in a table cell — a regex `|` would collide
with the column separator. Omit the block entirely when every invariant is
`judge` or `registry:<name>`.

````markdown
```verify-checks
path-resolver polarity=must-not regex=docs/(specs|issues)/[^ ]*\.md scope=skills/
no-eval       polarity=must-not regex=\beval\b scope=skills/
has-shebang   polarity=must    regex=^#!/usr/bin/env\ bash count=0 scope=skills/broken/
tmp-clean     absent=skills/**/*.tmp
readme        exists=README.md
```
````

Grammar — one line per check, `<id> <key>=<value> ...`:

- **`pattern` keys:** `polarity=must|must-not`, `regex=<ERE>` (required),
  optional `scope=<relpath>` (default: the group's declared territory), optional
  `count=<n>` (holds iff exactly `n` matches; overrides polarity).
- **`structure` keys:** `exists=<relpath>` (holds iff the path exists) **or**
  `absent=<glob>` (holds iff nothing matches).
- Values carry no spaces *between* tokens, but an ERE character class may contain
  a space (`[^ ]`) — the engine parses keys, not raw whitespace. To match a
  literal space inside a value, use `\ ` or a class like `[[:space:]]`.

### Parameter safety

- Every path-bearing value (`scope`, `exists`, `absent`) is re-validated at use:
  it must be repo-relative, with no `..` segment and no leading `-`. An unsafe
  value degrades that one check to *check failed to run* — it is never handed to
  grep/find.
- A `pattern` row with no `regex`, a bad `polarity`, or a non-numeric `count`
  degrades to *check failed to run*, not a silent pass.
- Regexes are POSIX extended (`grep -E`). A backslash is literal in the file;
  write `\.` for a literal dot, `\b` for a word boundary where supported.

## Registry checks are inert until the operator activates them

`registry:<name>` is the one bridge to running project tooling, and it is
deliberately powerless on its own:

- The blueprint only *names* a registry entry (`registry:linecount`). The
  `<name>` must be a slug (`^[a-z0-9][a-z0-9-]*$`); a non-slug name reports
  *check failed to run* and is never looked up.
- The command that runs comes solely from the operator's
  `verify_command_<name>` config key. Nothing recorded in a blueprint, code, or
  any scanned artifact can introduce, alter, or activate a command. An
  unregistered name reports *not configured* and executes nothing.
- Registry entries receive **no** blueprint-derived arguments — each is a
  complete, self-contained invocation; any scoping lives in the operator's own
  command string.

This is the trust boundary the engine is built around: blueprint content is
data the engine reasons over, never executable surface it can be tricked into
minting. Propose the registry name in the blueprint; the operator decides
whether — and what — to wire up.

## Cross-group contracts: the `contract-checks` block

On a multi-group project the contract graph's *edges* are verified too — the
provides/requires faces checked against the code on both sides (spec 037,
`/jim:verify --contracts`). Faces are prose, so the inert check data for an edge
lives in an optional `contract-checks` fenced block — the faces analog of
`verify-checks`, keyed by a **Provides** entry's backticked surface name
slugified (`identity lookup` → `identity-lookup`). Keep those surface names
slug-friendly and stable across regens so an edge's trend history stays
attributable.

````markdown
```contract-checks
identity-lookup criticality=high provider-ref=function getIdentity consumer-ref=getIdentity\( scope=accounts/session.ts
```
````

Grammar — one line per Provides entry, `<entry-slug> <key>=<value> ...`, every
key optional:

- **`criticality=critical|high|medium|low`** — how load-bearing the entry is.
  See *Declaring criticality* below.
- **`provider-ref=<ERE>`** — locates the declared surface in the provider's own
  code. Checked must-find: a match ⇒ the provider still honors the guarantee
  (holds); no match ⇒ a **code-level breaking** (the surface is gone).
- **`consumer-ref=<ERE>`** — identifies a consumer's usage of the surface. A
  match ⇒ the usage is present and within the declared surface (holds); no match
  abstains (a consumer not exercising the surface is not itself a violation — it
  falls to the judge and the cross-reference floor).
- **`scope=<relpath>`** — narrows the **provider-side** search base (where the
  surface lives); the consumer side always scans the consumer's own territory.

An edge with no `contract-checks` line for its entry falls back to read-only
`judge` over the two faces and the relevant code — legacy faces predating this
feature verify unchanged, no migration.

### Parameter safety

- `provider-ref` / `consumer-ref` are POSIX-extended regexes (`grep -E`), handed
  to grep behind `-e` and never as a command — the same inert-data boundary as
  `verify-checks` `regex=`. A backslash is literal in the file.
- The `scope` path is re-validated at use (repo-relative, no `..` segment, no
  leading `-`); an unsafe value degrades that edge's check to *check failed to
  run*, never handed to grep.
- Evidence is always location-only: a matched line's `file:line` is reported,
  never its content, so a crafted surface can never exfiltrate code through the
  result channel.

### Declaring criticality

An edge's criticality defaults to `high` — a broken contract is a broken app.
Declaring `criticality=` on a Provides entry sets **one** value that drives both
the edge's verification appetite (how hard `/jim:verify` checks it) and the
Step-4a autonomy grading of edits to that entry (how cautiously the blueprint
surface folds a change to it). Declare `critical` for a load-bearing boundary
(auth, billing identity); declare `medium`/`low` for a nice-to-have surface that
is cheap to check and cheap to evolve.

**The one-way ratchet.** The declaration itself is graded content, and it
ratchets in one direction only:

- *Introducing* a declaration **below** the default, or *lowering* an existing
  one, grades as a **weakening** — it always prompts under `auto_blueprint`,
  with the blast radius attached. A relaxation is confirmed by a human at the
  moment it is introduced.
- *Raising* a declaration, or *removing* it back toward the default, is
  **additive** — it needs no prompt.

So a `medium`/`low` label can never be laundered in as an unattended additive
write to escape the always-prompt grading its weakening deserves.

## Worked examples

**A banned construct (pattern, must-not):**

```
| no-eval | Scripts never eval scanned content | critical | pattern |
```
```verify-checks
no-eval polarity=must-not regex=\beval\b scope=skills/
```

**A required layout element (structure, exists):**

```
| has-readme | Every published group ships a README | medium | structure |
```
```verify-checks
has-readme exists=README.md
```

**Project tooling (registry) — blueprint names it, operator wires it:**

```
| types-sound | The type checker passes | high | registry:typecheck |
```
Then the operator adds to `jimconf.toml`: `verify_command_typecheck = "npm run typecheck"`.

**A semantic rule with no honest mechanical check (judge):**

```
| domain-bounds | Agents do not cross domain boundaries (PM ≠ code) | high | judge |
```
No `verify-checks` entry — the judge rung reads the rule and the relevant code.
