# Brainstorm: File-resolver conventions audit across skills & agents

*2026-05-05*

## Topic

Now that `008-jimconf` (path resolver) and `009-jimfile` (file/path
operations) have shipped, audit every skill and agent to make sure
file/path prose is correct, concise, and using the *right* script for
the job — and decide whether a shorthand convention for "if file exists
→ do X" gates is worth introducing.

## Problem

1. **Wrong script in some places.** `skills/spec/SKILL.md:35-36` reads
   strategic context with `jimconf.sh get vision` /
   `jimconf.sh get architecture`. `jimconf.sh get` resolves a *path*; it
   does not check existence and does not read content. The phrasing
   "from the project root if they exist" is misleading on both counts.
2. **`jimconf.sh` used where `jimfile.sh` fits.**
   `skills/spec/SKILL.md:44` globs via the jimconf path. `jimfile.sh
   glob specs` is the deterministic surface for exactly this.
3. **Hardcoded `./pre-commit.sh` in `skills/build/SKILL.md:92`.** Most
   projects don't have one. Needs a configurable key plus an existence
   gate.
4. **The "if exists" pattern is verbose and inconsistent.** ~10 sites
   express it as English prose with no mechanism behind the check. A
   shorthand convention would tighten tokens, reduce ambiguity, and
   make cross-skill audits scannable — *if* it doesn't degrade LLM
   reliability.

## Options weighed

| Question | Options | Picked |
| --- | --- | --- |
| Shorthand for existence gates | A. Custom mini-language. B. Sharper bash primitives + plain English. C. BASIC-flavored keyword set | **C** — keywords are English the LLM already knows; control flow is shorthand, actions stay natural |
| New jimfile subcommand shape | `get` only / `get-if-exists` only / both | **`get` only** — gate idiom (C) makes `get-if-exists` redundant |
| `pre_commit` default value | Empty (opt-in) / `./pre-commit.sh` | **`./pre-commit.sh`** — same "path-where-it-would-live" semantics as `vision` / `architecture`; existence gate handles missing case |
| PR shape | New feature spec / amend in place / refactor spec | **Refactor spec** (`type: refactor`) — sweeps existing skills/agents/specs; no new product surface |
| Where the gate idiom lives | `skills/file/SKILL.md` / `ARCHITECTURE.md` / 001-meta | **`ARCHITECTURE.md` → Plugin Conventions**, with 001-meta acknowledgment — the idiom is cross-cutting, not file-specific. Shared with the sibling brainstorm |
| Where "always-call-jimfile" lives | `skills/file/SKILL.md` / `ARCHITECTURE.md` | **`skills/file/SKILL.md`** — it *is* file-specific; belongs at the surface |

## Decisions

- **D1.** Adopt the BASIC-flavored gate idiom: `IF (…) EXISTS THEN …
  END IF`, with `ELSE` and `THEN DO: 1. … DONE` variants. See §"Gate
  convention" for the keyword table.
- **D2.** Add `jimfile.sh get <key>` subcommand; it delegates to
  `jimconf.sh get <key>` internally. Skills and agents always call
  jimfile, never jimconf directly.
- **D3.** Drop `get-if-exists` — redundant under D1.
- **D4.** Add `pre_commit` key to `jimconf.sh`; default
  `./pre-commit.sh` (path-where-it-would-live, not "exists" claim).
  Skills wrap calls in the D1 gate.
- **D5.** Land as a refactor spec (`type: refactor`); no new product
  spec. Amend `008-jimconf` and `009-jimfile` in place for the new
  key/subcommand.
- **D6.** Convention split: file-specific "always call jimfile" rule
  goes in `skills/file/SKILL.md`; the cross-cutting gate idiom (D1)
  goes in `ARCHITECTURE.md` → Plugin Conventions; 001-meta gets a
  short acknowledgment amendment (shared deliverable with the sibling
  brainstorm).
- **D7.** Inline gate form needs no code-fencing. Only fence the
  multi-step `THEN DO: … DONE` variant (its numbered list needs
  predictable indentation).

## Gate convention

Required keyword set — small on purpose. Anything fancier reverts to
English.

| Keyword              | Meaning                                  |
| -------------------- | ---------------------------------------- |
| `IF (X) EXISTS THEN` | path X is on disk                        |
| `IF (X) ABSENT THEN` | path X is not on disk                    |
| `THEN` …             | inline single-action form                |
| `THEN DO:` … `DONE`  | block form for multi-step actions        |
| `ELSE` …             | optional alternative branch              |
| `END IF`             | closes the block                         |

No loops, no variables, no `WHILE`, no `RETURN`.

**Rewrite — single-action, inline (`skills/spec/SKILL.md:34-38`):**

```
READ_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision` — locked constraint. Do not re-litigate strategic decisions.
```

**Rewrite — multi-step + ELSE (`skills/build/SKILL.md:92`, after D4):**

```
DO_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get pre_commit`:
  1. Run it via Bash.
  2. Show the full output.
```

## Audit — file:line map

Status flags: 🚩 = wrong script or misleading prose. 🔧 = could use
`jimfile.sh` for a deterministic operation. ✅ = already correct.

### `skills/spec/SKILL.md`

- 🚩 L34-38 "Read these files from the project root if they exist" with
  `jimconf get vision` / `jimconf get architecture`.
  - "from the project root" is misleading once paths are configurable.
  - No existence check mechanism — purely English.
  - **Fix:** drop "from the project root"; gate with `jimfile.sh exists`.
- 🔧 L40 `references/spec-types.md` — fine, that's a skill-internal asset.
- 🚩 L44 "Glob `jimconf get specs` to identify existing groups and specs."
  - Should be `jimfile.sh glob specs` (or `glob specs <group>`).
- ✅ L116-119 `jimfile.sh next-id <group>` — correct.
- ✅ L134-138 `jimfile.sh path spec <group> <id> <name>` — correct.

### `skills/build/SKILL.md`

- 🚩 L92 `Run ./pre-commit.sh via Bash.`
  - Hardcoded; not configurable; often missing.
  - **Fix:** new jimconf key + `jimfile.sh exists` gate; skip if absent.

### `skills/research/SKILL.md`

- 🔧 L36 `jimconf get specs/{group}/{id}-{name}/research.md` — could use
  `jimfile.sh path research <group> <id> <name>` to mirror how the spec
  skill resolves its own canonical paths.
- 🚩 L93 "Read `jimconf get vision` and `jimconf get architecture` if they
  exist." Same pattern as spec — needs existence-aware composition.

### `skills/plan/SKILL.md`

- 🚩 L53 "Look for `jimconf get architecture` at the project root (and at
  the target directory if planning a subdirectory)."
  - "at the project root" is misleading.
  - No existence check mechanism.
  - **Fix:** `jimfile.sh exists` gate + drop locational prose.
- 🔧 L97 `jimconf get specs/{group}/{id}-{name}/plan.md` — could use
  `jimfile.sh path plan <group> <id> <name>`.

### `skills/arch/SKILL.md`

- 🚩 L24-25 "Create or update `jimconf get architecture` at the project
  root." — wording leaks the historical default.
- 🚩 L31 "Set the target file as `{directory}/{jimconf get architecture}`."
  - Composing a path from a path is fragile; the resolved value already
    encodes its location.
- 🚩 L35 "Check for `jimconf get vision` at the project root."
  - Existence check is English-only; should be `jimfile.sh exists`.
- 🚩 L42 "Look for `jimconf get architecture` at the target path."
  - Same — should be `jimfile.sh exists`.

### `skills/vision/SKILL.md`

- 🚩 L27 "Read `jimconf get architecture` from the project root if it
  exists." Same superfluous "project root" + missing existence gate.
- 🚩 L33 "Read `jimconf get vision` from the project root."
  - "project root" is incorrect once configurable; just say "Read the
    resolved vision path."
- ✅ L76 "Write to `jimconf get vision` …" — write side is fine.

### `skills/roadmap/SKILL.md`

- 🚩 L27 "Read `jimconf get vision` from the project root if it exists."
- 🔧 L33 "Glob `jimconf get specs/**/*.md` to find existing specs."
  - Should be `jimfile.sh glob specs` (no group filter). Then grep
    frontmatter `title:` separately if needed.
- 🚩 L39 "Read `jimconf get roadmap` from the project root."

### `skills/brainstorm/SKILL.md`

- 🚩 L28 "Quickly read `jimconf get vision` and `jimconf get roadmap` if
  they exist."

### `skills/debug/SKILL.md`

- ✅ L35 `jimfile.sh glob debug` — correct.
- ✅ L49 `jimfile.sh path debug "$ARGUMENTS"` — correct.

### `skills/meta-skill/SKILL.md`

- 🔧 L23/L25 `jimconf get specs/jim/` for spec-by-frontmatter search.
  - Could be `jimfile.sh glob specs jim`, then filter by frontmatter
    grep.

### `skills/meta-agent/SKILL.md`

- 🔧 L23/L25 — same pattern as meta-skill.

### `skills/meta-test/SKILL.md`

- 🔧 L47 — same pattern.

### Agents (`agents/*.md`)

Static prose loaded into agent contexts; no `!`-substitution. They
reference default paths as *example shapes*, not resolved locations
— defensible, but worth flagging that they encode the historical
default and won't reflect a project's overrides.

- `agents/pm.md:48-51` — example paths.
- `agents/architect.md:49-52` — example paths.
- `agents/researcher.md:50-52` — example paths.
- `agents/coder.md:49-50, 82` — example paths + `./pre-commit.sh`.
- `agents/meta.md:14, 51-52` — example paths.

`coder.md:82`'s `./pre-commit.sh` reference must track whatever fix
lands in `skills/build/SKILL.md`.

## Tasks

The refactor spec ships these, in roughly this order:

1. **Extend `jimfile.sh`** — add `get <key>` subcommand that delegates
   to `jimconf.sh get <key>`. New `case_jimfile_*` test cases per the
   meta-test convention. (D2)
2. **Extend `jimconf.sh`** — add `pre_commit` to the key set with
   default `./pre-commit.sh`. New `case_jimconf_*` test cases. (D4)
3. **Skill prose sweep** — every 🚩 / 🔧 site in the audit. Migrate
   `jimconf.sh get …` calls to `jimfile.sh get …`; wrap existence-gated
   reads in the D1 gate; replace prose globs with `jimfile.sh glob …`.
4. **Agent prose sweep** — `agents/coder.md:82` (pre-commit reference).
   Re-read example-path lists in the other four agents; amend only if
   they cause confusion.
5. **`skills/file/SKILL.md`** — add the "always call jimfile, never
   jimconf" rule (D6) and a `get vision` example. (D2 + D6)
6. **Doc cross-check sweep** — read each and amend if drift exists:
   `CLAUDE.md`, `WORKFLOW.md`, `ARCHITECTURE.md`, `VISION.md`. The
   `ARCHITECTURE.md` Plugin Conventions update is the cross-cutting
   piece — see §"Cross-link" below.
7. **Spec amendments** — `008-jimconf` (new `pre_commit` key) and
   `009-jimfile` (new `get` subcommand). Amend in place; spec
   frontmatter stays approved. (D5)

## Cross-link

Sibling brainstorm:
[`20260505-bash-scripts-in-meta.md`](20260505-bash-scripts-in-meta.md).

Two **shared deliverables** belong to a separate, smaller conventions
spec coordinated with that brainstorm — not bundled with this
refactor:

- New `ARCHITECTURE.md` → Plugin Conventions → **Logic-Flow
  Conventions** subsection covering the D1 gate idiom (this
  brainstorm) **and** the bash-script decision rule (sibling).
- `001-meta` amendment acknowledging both conventions and pointing
  at the canonical doc.

Order: conventions spec lands first (it produces the doc this
refactor cites). The two can plan in parallel.

## Out of scope

- No new feature work — purely mechanical sweep.
- No retroactive changes to the `jimconf.sh` ↔ `jimfile.sh` boundary.
- No Codex/Gemini/Cursor portability research (sibling brainstorm
  owns that).
- Most-recent / staleness lookup helpers (already deferred by the
  009 plan).
