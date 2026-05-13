# Brainstorm: File-resolver conventions audit across skills & agents

*2026-05-05*

## Topic

Now that `008-jimconf` (path resolver) and `009-jimfile` (file/path
operations) have shipped, audit every skill and agent to make sure
file/path prose is correct, concise, and using the *right* script for
the job — settle a shorthand convention for "if file exists → do X"
gates, and align `jimfile.sh`'s return shapes with how callers
actually use them.

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
5. **`jimfile.sh get` returns a defaulted path for every known key**,
   so it's mismatched with the dominant caller pattern. The shorthand
   convention (D1, below) treats `IF <name> EXISTS THEN` as "variable
   non-empty"; if `get` always returns a non-empty path, every
   existence gate silently takes the first branch. Verified
   empirically on 2026-05-12: a live `/jim:build` run improvised a raw
   `test -e .../pre-completion.sh` outside the canonical surface to
   escape the broken semantics.

## Options weighed

| Question | Options | Picked |
| --- | --- | --- |
| Shorthand for existence gates | A. Custom mini-language. B. Sharper bash primitives + plain English. C. Directive vocabulary (`READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS`, `SET`) + lean paren-free `IF X EXISTS THEN … ELSE … ENDIF` block for branching | **C** — directives sit at end-of-line so `!`-injection substitutes; the lean `IF` block carries genuine branching; no `!`-injection slot inside `(…)` |
| `jimfile.sh get` return shape for path keys | Always return configured path / Return path-or-empty (exists-check inside `get`) / Split into `get` (raw) + new `find` verb | **Path-or-empty for path keys** — dominant caller pattern (12 of 19 sites); matches user mental model; makes the existence gates work |
| Write-target callers (4 sites) | Keep on `get` / New sibling verb (`target` / `where` / `resolve`) / Overload `path` with a single-arg key form | **Overload `path`** — `path <key>` returns the configured path regardless of existence; reuses an existing verb (`path <kind> <args>` already returns derived canonical paths); reads naturally in skill prose; frees `get` to be path-or-empty |
| Non-path config keys (3 sites — `require_*`, `auto_arch_feedback`) | Same verb as paths / Separate verb / Key-type dispatch inside `jimconf` | **Defer to planning** — viable shapes are (a) keep on `get` with key-type dispatch in jimconf, (b) dedicated `value`/`cfg` verb |
| `pre_commit` default value | Empty (opt-in) / `./pre-commit.sh` | **`./pre-commit.sh`** — same "path-where-it-would-live" semantics as `vision` / `architecture`; existence check is handled inside `get` under the new semantics |
| PR shape | New feature spec / amend in place / refactor spec | **Refactor spec** (`type: refactor`) — sweeps existing skills/agents/specs; no new product surface |
| Where the gate idiom lives | `skills/file/SKILL.md` / `ARCHITECTURE.md` / 001-meta | **`ARCHITECTURE.md` → Plugin Conventions → Logic-Flow Conventions**, with 001-meta acknowledgment |
| Where "always-call-jimfile" lives | `skills/file/SKILL.md` / `ARCHITECTURE.md` | **`skills/file/SKILL.md`** — it *is* file-specific; belongs at the surface |

## Decisions

> **Superseded by 2026-05-13 amendment to spec 011** (see `docs/brainstorms/20260513-directive-vocab-exists-trap.md`). The EXISTS-family directive vocabulary in D1 is retired in favor of a sentinel-based form: `SET <name> = !\`bash …\`` + `IF <name> != "NOT_FOUND" THEN`. D2's path-or-empty resolver shape is replaced with path-or-`NOT_FOUND` for path-typed keys. D8's empty-slot no-op contract is no longer load-bearing. D3, D4, D5, D6, D7(c) still apply. Bodies below preserved verbatim for forensic record.

- **D1.** Adopt the directive vocabulary for existence gates:
  `READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS` for single-action
  gates; `SET <name> = !\`bash …\`` + lean paren-free `IF <name>
  EXISTS THEN … ELSE IF <name> == "value" THEN … ELSE … ENDIF` block
  for genuine branching. Markdown indentation is the block delimiter;
  `ENDIF` is one word; implicit fall-through replaces explicit
  "Otherwise, skip silently" prose. Lives in `ARCHITECTURE.md` →
  Plugin Conventions → Logic-Flow Conventions. No `!`-injection slot
  inside `(…)` on the same line — the Claude Code preprocessor
  silently leaves the literal text in place.
- **D2.** `jimfile.sh get <key>` delegates to `jimconf.sh get <key>`
  internally. For **path keys**, `get` returns the configured path
  *if it exists on disk*, else empty string. Skills and agents
  always call jimfile, never jimconf directly.
- **D3.** Extend `jimfile.sh path` with a single-arg key form:
  `path <key>` returns the configured path *regardless of existence*
  (raw config lookup). The existing multi-arg form (`path <kind>
  <args>` for `spec` / `plan` / `research` / `debug` / `brainstorm`)
  stays untouched; `cmd_path` dispatches by arity. The only overlap
  between `KINDS` and `KEYS` is `debug` — `path debug` (no further
  args) returns the configured `debug` directory; `path debug
  <topic>` returns the derived topic path. Used by `arch` / `vision`
  / `roadmap` write sites (4 call sites).
- **D4.** Add `pre_commit` (and `pre_completion`) keys to
  `jimconf.sh`; default `./pre-commit.sh` /
  `./pre-completion.sh` (path-where-it-would-live, not "exists"
  claim). Existence handling lives inside `get` under D2.
- **D5.** Land as a refactor spec (`type: refactor`); no new product
  spec. Amend `008-jimconf` and `009-jimfile` in place for the new
  key/subcommand.
- **D6.** Convention split: file-specific "call `jimfile.sh` for file
  operations (existence checks, path resolution, glob discovery)"
  rule goes in `skills/file/SKILL.md`; the cross-cutting gate idiom
  (D1) goes in `ARCHITECTURE.md` → Plugin Conventions; 001-meta gets
  a short acknowledgment amendment. *Revised 2026-05-12 during 013
  planning: the original wording said "always call jimfile, never
  jimconf directly". D7(c) supersedes for value keys — they go to
  `jimconf.sh` directly because they're flags, not paths, and
  existence-checking them is meaningless.*
- **D7.** Non-path config keys (`require_*`, `auto_arch_feedback`):
  **Resolved 2026-05-12 as D7(c)** — value keys go to `jimconf.sh`
  directly from skill bodies (`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh
  get <key>`); `jimfile.sh get` stays strictly path-or-empty for
  path keys. Cleanest separation: jimconf is the raw-config layer,
  jimfile is the file-ops layer. Three caller renames (build:74,
  build:107, arch:82). No key-type dispatch needed inside either
  script. Earlier options weighed: (a) key-type dispatch inside
  jimfile with `VALUE_KEYS` metadata on jimconf — kept the "always
  call jimfile" rule but added an internal dispatch layer; (b)
  dedicated `value`/`cfg` verb on jimfile — same rule preserved but
  added a new verb. (c) won on the strength of the path/value
  distinction being a real semantic split, not an internal-plumbing
  detail.

  Followup flagged during planning: `agents/coder.md:82` references
  "the configured `pre_commit` script if it exists" in semantic
  prose — already correct under D7(c), but a future 011-adjacent
  cleanup pass could tighten the language.
- **D8.** Empty-slot behavior is no-op across the directive family:
  `READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS:` (skip the
  indented block), and `SET <name> = …` consumed by a subsequent
  `IF <name> EXISTS THEN` block (where `<name>` evaluates false).
  Matches the directive's intent ("skip silently if absent") and the
  matrix evidence for substituted values. Add a `meta-matrix` row
  that substitutes to *empty* (rather than a literal path) so the
  no-op behavior has a regression probe.

**Recommendation (next step):** Land D2 + D3 + D7 + D8 as a fresh
refactor spec. D1 is already in place via spec 011; the convention
won't work end-to-end until `get` returns path-or-empty. Run
claude code plan mode with this brainstorm as origin.

## Gate convention

> **Superseded** — see the head-of-Decisions annotation above. The post-amendment gate convention lives in `ARCHITECTURE.md` → Plugin Conventions → Logic-Flow Conventions and uses the sentinel form `SET … = !\`bash …\`` + `IF … != "NOT_FOUND" THEN … ENDIF`. Table below preserved as forensic record of the interim shape that ran from spec 011 land (2026-05-12) through the 2026-05-13 amendment.

Directive vocabulary covers single-action gates. The lean paren-free
`IF` block carries genuine branching.

| Form                                                                                                                                            | Meaning                                                                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| ``READ_IF_EXISTS !`bash …` ``                                                                                                                   | Read the resolved path if non-empty; skip silently otherwise                                           |
| ``RUN_IF_EXISTS !`bash …` ``                                                                                                                    | Run the resolved path via Bash if non-empty; skip silently otherwise                                   |
| ``DO_IF_EXISTS !`bash …`:`` *(followed by indented numbered steps)*                                                                             | Multi-step action gated on existence                                                                   |
| ``SET <name> = !`bash …` ``                                                                                                                     | Hoist a substitution onto a paren-free surface for a subsequent `IF` block                             |
| `IF <name> EXISTS THEN` *(indented body)* `ELSE IF <name> == "value" THEN` … `ELSE` … `ENDIF`                                                   | Genuine branching; markdown indentation is the block delimiter; `ENDIF` (one word) closes the chain    |

No loops, no variables beyond `SET` for hoisting, no `WHILE`, no
`RETURN`. No `!`-injection slot inside `(…)` on the same line.

**Example — single-action, inline (`skills/spec/SKILL.md`):**

```
READ_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision` — locked constraint. Do not re-litigate strategic decisions.
```

**Example — multi-step (`skills/build/SKILL.md`):**

```
DO_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get pre_commit`:
  1. Run it via Bash.
  2. Show the full output.
```

**Example — genuine branching (`skills/build/SKILL.md`, pre-completion gate):**

```
SET pre_completion = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get pre_completion`
SET require_pre_completion = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get require_pre_completion`

IF pre_completion EXISTS THEN
  Run it via Bash. Halt on non-zero exit.
ELSE IF require_pre_completion == "true" THEN
  Halt — caller declared pre-completion required but the script is missing.
ENDIF
```

## Audit — `jimfile.sh get` callers

Three semantic classes today, one verb (`get`) serving all three.
Under D2/D3 the surface splits cleanly: class 1 stays on `get` (now
path-or-empty), class 2 moves to `path <key>` (single-arg form),
class 3 is decided in planning (D7).

### Class 1 — find-on-disk (path-or-empty under D2). 12 sites

- `skills/plan/SKILL.md:53` (`READ_IF_EXISTS architecture`)
- `skills/spec/SKILL.md:33,35` (`READ_IF_EXISTS vision, architecture`)
- `skills/brainstorm/SKILL.md:30,32` (`READ_IF_EXISTS vision, roadmap`)
- `skills/research/SKILL.md:99,101` (`READ_IF_EXISTS vision, architecture`)
- `skills/vision/SKILL.md:27` (`READ_IF_EXISTS architecture`)
- `skills/arch/SKILL.md:37` (`READ_IF_EXISTS vision`)
- `skills/roadmap/SKILL.md:27` (`READ_IF_EXISTS vision`)
- `skills/build/SKILL.md:73,106` (pre-commit / pre-completion gates)
- `skills/build/SKILL.md:117` (arch refresh gate)
- `skills/vision/SKILL.md:33` (differential update)
- `skills/arch/SKILL.md:43` (differential update)
- `skills/roadmap/SKILL.md:39` (differential update)

Six of these are visibly broken today (the `SET … EXISTS THEN` form):
`skills/build/SKILL.md:73,106,117`, `skills/vision/SKILL.md:33`,
`skills/arch/SKILL.md:43`, `skills/roadmap/SKILL.md:39`. The other
six use `READ_IF_EXISTS` directly; the failure mode there is the LLM
attempting to Read a missing path rather than a silently-wrong
branch, but they still produce noise.

### Class 2 — write-target (move to `path <key>` under D3). 4 sites

- `skills/arch/SKILL.md:24` (argument-hint default)
- `skills/arch/SKILL.md:31` (resolve target for Write)
- `skills/vision/SKILL.md:79` (Write to …)
- `skills/roadmap/SKILL.md:75` (Write to …)

### Class 3 — non-path config values. 3 sites

- `skills/build/SKILL.md:74,107` (`require_pre_commit`, `require_pre_completion` booleans)
- `skills/arch/SKILL.md:82` (`auto_arch_feedback` boolean)

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

`coder.md:82`'s `./pre-commit.sh` reference must track whatever the
build skill resolves under D2.

## Migration table

Site-by-site action under the recommended shape (D2 + D3 + D7(a) + D8). "No change" rows still need a one-glance review during Task 4 to confirm nothing relies on the old "always returns a path" behavior; in practice that review should be a no-op.

| Site                              | Class | Action under D2 + D3 + D7(a)                                                |
| --------------------------------- | :---: | --------------------------------------------------------------------------- |
| `skills/plan/SKILL.md:53`         |   1   | No change                                                                   |
| `skills/spec/SKILL.md:33`         |   1   | No change                                                                   |
| `skills/spec/SKILL.md:35`         |   1   | No change                                                                   |
| `skills/brainstorm/SKILL.md:30`   |   1   | No change                                                                   |
| `skills/brainstorm/SKILL.md:32`   |   1   | No change                                                                   |
| `skills/research/SKILL.md:99`     |   1   | No change                                                                   |
| `skills/research/SKILL.md:101`    |   1   | No change                                                                   |
| `skills/vision/SKILL.md:27`       |   1   | No change                                                                   |
| `skills/arch/SKILL.md:37`         |   1   | No change (drop redundant L39 fallback prose if present)                    |
| `skills/roadmap/SKILL.md:27`      |   1   | No change                                                                   |
| `skills/build/SKILL.md:73`        |   1   | No change; broken gate becomes correct                                      |
| `skills/build/SKILL.md:106`       |   1   | No change; broken gate becomes correct                                      |
| `skills/build/SKILL.md:117`       |   1   | No change; broken gate becomes correct                                      |
| `skills/vision/SKILL.md:33`       |   1   | No change; broken gate becomes correct                                      |
| `skills/arch/SKILL.md:43`         |   1   | No change; broken gate becomes correct                                      |
| `skills/roadmap/SKILL.md:39`      |   1   | No change; broken gate becomes correct                                      |
| `skills/arch/SKILL.md:24`         |   2   | `get architecture` → `path architecture`                                    |
| `skills/arch/SKILL.md:31`         |   2   | `get architecture` → `path architecture`                                    |
| `skills/vision/SKILL.md:79`       |   2   | `get vision` → `path vision`                                                |
| `skills/roadmap/SKILL.md:75`      |   2   | `get roadmap` → `path roadmap`                                              |
| `skills/build/SKILL.md:74`        |   3   | No change under D7(a); rename `get` → `value` under D7(b)                   |
| `skills/build/SKILL.md:107`       |   3   | No change under D7(a); rename `get` → `value` under D7(b)                   |
| `skills/arch/SKILL.md:82`         |   3   | No change under D7(a); rename `get` → `value` under D7(b)                   |
| `agents/coder.md:82`              | agent | Rephrase the illustrative `./pre-commit.sh` reference, or accept            |

**Touch-count summary under D7(a) (recommended):** 4 mechanical renames + 1 agent prose tweak + ~16 verify-and-leave-alone reviews. The "19+ callers" inventory framing is correct, but only 5 sites need an actual edit.

**Touch-count summary under D7(b):** 4 + 3 + 1 + ~16 = 7 actual edits.

## Worked examples (today vs. after D2)

**Class 1A — `READ_IF_EXISTS` (`skills/arch/SKILL.md:37`).** Prose unchanged.

Today: `get vision` returns `./VISION.md` regardless of whether the file exists, so `READ_IF_EXISTS ./VISION.md` always tries to Read; if the file is missing the LLM tool-errors and falls back to the "If absent, proceed without it" prose at L39.

After D2: substitutes to `READ_IF_EXISTS ` (empty); the LLM no-ops per D8. The L39 fallback prose is harmless but redundant.

**Class 1B — `SET`+`IF` gate (`skills/build/SKILL.md:73-81`).** Prose unchanged; behavior flips from broken to correct.

Today: `get pre_commit` returns `./pre-commit.sh` (the configured default at `jimconf.sh:56`). `IF pre_commit EXISTS THEN` always evaluates true, so the LLM tries to run a non-existent script on most projects and improvises around the missing-file error. The `ELSE IF require_pre_commit == "true"` branch is dead code.

After D2: `get pre_commit` returns the path only if the script exists. First branch fires when real; halt branch fires when missing-and-required. Gate works as specified.

**Class 2 — write-target (`skills/arch/SKILL.md:24, :31`).** Verb renames `get` → `path` (single-arg form).

Today: `get architecture` returns `./ARCHITECTURE.md`. `arch` writes to that path — works for both first run and subsequent updates.

After D2 alone (no D3): `get architecture` returns empty on first run; `arch` has nowhere to write. Breaks the skill.

After D2 + D3: replace `get architecture` with `path architecture` at the two write sites. The same skill's class-1 site at `arch.md:43` (`SET arch_doc = …get architecture` for new-doc-vs-differential-update) stays on `get`. One skill, two verbs, two semantics — which is what makes the split worth doing.

**Class 3 — non-path config (`skills/build/SKILL.md:74`).** No change under D7(a).

`get require_pre_commit` returns `"false"` (or whatever jimconf resolves to) and is compared with `== "true"` at L79. Existence check is irrelevant. Under key-type dispatch, `get` returns the raw value; the call site is untouched.

## Tasks

The next refactor spec ships these, in roughly this order:

1. **Extend `jimfile.sh`** — change `get`'s semantics for path keys
   to path-or-empty (D2). Extend `cmd_path` with a single-arg key
   form (D3 — overloads the existing `path` verb; dispatches by
   arity). New `case_jimfile_*` test cases per the meta-test
   convention.
2. **Settle and apply non-path key handling** (D7). If key-type
   dispatch wins: extend `jimconf.sh` with key-type declarations.
   If a separate verb wins: add it. Update the 3 class-3 call sites
   accordingly.
3. **Rename 4 write-target call sites** `get <key>` → `path <key>`
   (D3 / class 2).
4. **Read-side call sites stay put.** The substitution surface
   doesn't change; `get` just returns empty when the path is
   missing. Verify `READ_IF_EXISTS` / `SET …` + `IF … EXISTS THEN`
   handling across the 12 class-1 sites (D8) — adjust any prose
   that mishandles an empty slot.
5. **Spec amendments** — `008-jimconf` (any new key-type
   declaration), `009-jimfile` (new `get` semantics + extended
   `path` single-arg form). Amend in place; spec frontmatter stays
   approved.
6. **Agent prose sweep** — `agents/coder.md:82` (pre-commit
   reference) tracks the build-skill resolution. Re-read
   example-path lists in the other agents; amend only if they cause
   confusion.

## Risks worth naming

- **Directory-typed path keys** (`specs`, `brainstorms`, `debug`).
  `test -e` works for dirs as well as files, but "exists" is
  fuzzier for a dir: `docs/specs` typically always exists once any
  spec lands, making the gate a tautology. No current caller
  actually gates on these (the 12 read-side sites all use
  file-typed keys), but worth a test case to lock in the
  semantics.
- **Empty-slot regression coverage.** Today's `meta-matrix`
  patterns substitute to non-empty literal paths and confirm
  `!`-injection fires. Under D2, the new failure mode is the
  substituted value being empty; the matrix needs a row that
  substitutes to `""` and verifies the LLM no-ops per D8 across
  all four directives (`READ_IF_EXISTS`, `RUN_IF_EXISTS`,
  `DO_IF_EXISTS`, `SET`+`IF EXISTS`).
- **`agents/coder.md:82`** references `./pre-commit.sh` as static
  prose (no `!`-substitution; the agent surface doesn't
  substitute). The example becomes misleading once `get` no longer
  returns that path on every project. Rephrase to reference the
  resolved value semantically, or accept it as illustrative.
- **TOCTOU is a non-issue.** Between `get`'s stat and the
  subsequent Read, the file isn't going to vanish in practice.
  Mentioned only to dismiss.

## Cross-link

Sibling brainstorm:
[`20260505-bash-scripts-in-meta.md`](20260505-bash-scripts-in-meta.md).

The shared deliverable — `ARCHITECTURE.md` → Plugin Conventions →
Logic-Flow Conventions — landed via spec 011. 001-meta carries the
acknowledgment amendment. The next spec builds on those.

## Out of scope

- No new feature work — purely mechanical sweep.
- No retroactive changes to the `jimconf.sh` ↔ `jimfile.sh` boundary
  beyond what D2/D3/D7 require.
- No Codex/Gemini/Cursor portability research (sibling brainstorm
  owns that).
- Most-recent / staleness lookup helpers (already deferred by the
  009 plan).
