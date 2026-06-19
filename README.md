# jim

```
    .---.                     
    |   |                     
    '---'.--. __  __   ___    
    .---.|__||  |/  `.'   `.  
    |   |.--.|   .-.  .-.   ' 
    |   ||  ||  |  |  |  |  | 
    |   ||  ||  |  |  |  |  | 
    |   ||  ||  |  |  |  |  | 
    |   ||  ||  |  |  |  |  | 
    |   ||__||__|  |__|  |__| 
 __.'   '                     
|      '                      
|____.'                       
```

<!-- https://patorjk.com/software/taag/#p=display&f=Crazy&t=jim&x=none -->


# What is it

Jim is a **spec-driven SDLC plugin for Claude Code**. It gives you a structured development workflow through namespaced slash commands and specialized agents. You talk to Jim like a person.

```
/jim:spec    → define the work
/jim:plan    → research and break it into tasks
/jim:build   → TDD implementation, one task at a time
```

Jim enforces a simple discipline: think before you code. Every feature, bug fix, or refactor starts with a spec. Every spec gets a plan. Every plan gets built test-first.

Jim can also develop itself — skills and agents for the plugin are specs like any other.

## Commands

| Command | What it does |
|---------|-------------|
| `/jim:spec` | Define a feature, bug, or refactor |
| `/jim:plan` | Research codebase + create atomic task plan |
| `/jim:build` | TDD red-green-refactor, one task at a time |
| `/jim:vision` | Create/update project vision |
| `/jim:arch` | Create/update technical architecture |
| `/jim:roadmap` | Create/update execution roadmap |
| `/jim:debug` | Diagnose failures, produce debug report |
| `/jim:sec` | Design-time security analysis of specs, plans, or arbitrary files; produces `security.md` |
| `/jim:review` | Post-build review — drift vs spec/plan/architecture, code + process metrics, security regressions; produces `review.md` |
| `/jim:brainstorm` | Freeform ideation and exploratory notes |
| `/jim:issue` | Capture a discovery (`add <subject>`) or review the collection (`list` / `stats` / `show` / `insights`) — `insights` is an LLM analysis (convergence, sequencing, parallel-work) run by a read-only subagent |
| `/jim:conf` | Inspect resolved jim configuration paths |
| `/jim:file` | Inspect jim's file/path resolver (existence, slug, date, now, next-id, next-num, path, glob) |
| `/jim:meta-skill` | Build a jim plugin skill from spec |
| `/jim:meta-agent` | Build a jim plugin agent from spec |
| `/jim:meta-test` | Scaffold a bash test file, append a case, or run the suite |

## Agents

| Agent | Role |
|-------|------|
| `@jim:pm` | Specs, vision, roadmap, brainstorms |
| `@jim:architect` | Plans, architecture |
| `@jim:coder` | TDD builds, debugging |
| `@jim:security` | Design-time security review of specs and plans |
| `@jim:reviewer` | Post-build review of shipped code against spec, plan, and architecture |
| `@jim:meta` | Plugin development — builds skills and agents |

## How to install

### From the Marketplace

*(coming soon)*

### From source

1. Clone the repo:
   ```bash
   git clone https://github.com/JamSuite/jim.git
   ```

2. Launch Claude Code in your project with `--plugin-dir` pointing to your local clone:
   ```bash
   claude --plugin-dir /path/to/jim
   ```

That's it — Jim's slash commands and agents are now available in your session.

## Configuration

Jim works with **zero configuration** — every skill defaults to the conventional paths (`docs/specs/`, `ARCHITECTURE.md`, etc.). To adopt jim into a project that already uses different document locations, drop a `jimconf.toml` at the project root and override only the keys you need.

Copy the shipped template to start:

```bash
cp jimconf.toml.example jimconf.toml
```

Supported keys (all optional — omitted keys keep their defaults):

| Key | Default | Used by |
|-----|---------|---------|
| `specs_path` | `docs/specs` | `/jim:spec`, `/jim:plan`, `/jim:research`, `/jim:meta-skill`, `/jim:meta-agent`, `/jim:roadmap` |
| `architecture_path` | `ARCHITECTURE.md` | `/jim:arch`, `/jim:plan`, `/jim:vision`, `/jim:research`, `/jim:spec` |
| `vision_path` | `VISION.md` | `/jim:vision`, `/jim:roadmap`, `/jim:arch`, `/jim:spec`, `/jim:research`, `/jim:brainstorm` |
| `roadmap_path` | `ROADMAP.md` | `/jim:roadmap`, `/jim:brainstorm` |
| `brainstorms_path` | `docs/brainstorms` | `/jim:brainstorm` |
| `debug_path` | `docs/debug` | `/jim:debug` |
| `security_adhoc_path` | `docs/security` | `/jim:sec` (ad-hoc opt-in file output) |
| `pre_commit_path` | `./pre-commit.sh` | `/jim:build` (per-commit hook) |
| `pre_completion_path` | `./pre-completion.sh` | `/jim:build` (post-completion hook) |
| `require_pre_commit` | `"false"` | `/jim:build` — when `"true"`, missing pre-commit script halts the build |
| `require_pre_completion` | `"false"` | `/jim:build` — when `"true"`, missing pre-completion script halts the build |
| `auto_arch_feedback` | `"false"` | `/jim:build` → `/jim:arch` — when `"true"`, ARCHITECTURE.md updates apply without confirmation |
| `require_review` | `"false"` | `/jim:build` → `/jim:review` — when `"true"`, the post-build review runs as a required step at the completion gate (advisory; never blocks) |
| `auto_review` | `"false"` | `/jim:build` → `/jim:review` — when `"true"`, the post-build review runs automatically with no prompt; composes independently of `auto_issue_file` |
| `require_security` | `"false"` | `/jim:plan`, `/jim:build` — when `"true"`, next-phase start blocks until security review covers the prior phase; developer in the loop for routing |
| `auto_security` | `"false"` | `/jim:plan`, `/jim:build` — same gate as `require_security`, but findings route automatically (no per-finding prompts) |
| `require_security_loop` | `"false"` | `/jim:sec` — when `"true"`, repeat the review-and-routing cycle until the severity threshold clears or the iteration limit is reached |
| `require_security_loop_sev` | `"critical"` | `/jim:sec` — severity threshold for the loop's exit condition (`"critical"` / `"notable"` / `"advisory"`) |
| `auto_security_loop_limit` | `"5"` | `/jim:sec` — maximum iterations of the gated review-and-routing loop |
| `issues_path` | `./docs/issues/` | `/jim:issue`  — issue collection location |
| `issue_capture` | `"true"` | surface potential issues at the end of each development phase; `"false"` disables surfacing |
| `auto_issue_file` | `"false"` | automatically file issues without prompting |
| `issue_list_group` | `"status"` | `/jim:issue list` — default grouping (`status` / `priority` / `origin` / `none`) |
| `issue_list_sort` | `"date"` | `/jim:issue list` — default sort within groups (`date` / `priority` / `num`) |
| `issue_list_cols` | `"num,date,priority,title"` | `/jim:issue list` — default columns (any of `num,date,priority,status,slug,labels,title`) |
| `issue_list_order` | `"desc"` | `/jim:issue list` — sort direction (`desc` = newest/highest first, `asc`) |
| `issue_list_closed` | `"false"` | `/jim:issue list` — when `"false"`, the default and priority-filtered views hide closed issues (use `list closed` to see them); `"true"` includes closed in every view |
| `issue_id_prefix` | `"date"` | `/jim:issue add` — issue-id prefix scheme (`date` / `timestamp` / `sequential` / `project`, or a `{date:…}`/`{seq:…}` template); forward-only — converge existing ids with `migrate.sh prefix` |
| `issue_id_project` | `""` (empty) | `/jim:issue add` — static project tag prepended when `issue_id_prefix = "project"` |

> **Manual migration rule.** Changing a configured path does **not** move existing files. If you point `architecture_path` at a new location, you are responsible for moving (or recreating) the file at the new path. Jim never relocates artifacts on a config change.

Inspect what jim resolves with `/jim:conf`:

```
/jim:conf list                              # active project config
/jim:conf get specs                         # one key
/jim:conf path                              # which file is active
/jim:conf -c jimconf.toml.example list      # see the shipped defaults
```

### File/path operations — `/jim:file`

`/jim:conf` resolves *where* a configured doc lives. `/jim:file` is its sibling for *operations against those locations* — the deterministic surface jim's skills use to compute filenames and look up artifacts. Backed by `skills/file/scripts/jimfile.sh`, which shells out to `jimconf.sh` so every `/jim:conf` override is honored automatically.

```
/jim:file exists docs/specs/jim/008-jimfile/spec.md   # "yes" or "no"
/jim:file slug "Auth Token Expiry"                    # auth-token-expiry
/jim:file date                                        # YYYYMMDD
/jim:file now                                         # YYYY-MM-DDThh:mm:ssZ (UTC)
/jim:file next-id jim                                 # next zero-padded spec ID
/jim:file next-num issue                              # next issue display ordinal
/jim:file path spec jim 008 jimfile                   # canonical spec path
/jim:file path debug "auth bug"                       # date-prefixed debug path
/jim:file glob specs jim                              # every spec in the jim group
/jim:file kinds                                       # valid artifact kinds
```

Path-and-name resolution only — the script never reads, writes, or deletes files. Slug normalization, the `.`/`..` reject, and the 64-char cap are enforced by the script (security boundary).

### Issue prefix

Changing `issue_id_prefix` is forward-only, it doesn't touch existing files. To converge an existing collection on the active scheme, run `migrate.sh prefix`, a one-shot, opt-in script:

```bash
bash skills/issue/scripts/migrate.sh prefix            # preview the rename/skip/collision plan (read-only)
bash skills/issue/scripts/migrate.sh prefix --apply    # rename files, rewrite inbound relations/[[wikilinks]], regen INDEX.md
```

`--apply` is destructive (it renames files) and flags an uncommitted collection before mutating — commit a clean state first so recovery is a simple `git restore`.

*Note:* migrate.sh handles the four named presets (`date` / `timestamp` / `sequential` / `project`) only; custom `{date:…}` templates are reported as un-migratable and left unchanged. The `project` tag must itself be hyphen-free — migration recovers each slug by splitting the id at its first dash, so a hyphenated tag (e.g. `MY-TEAM`) won't migrate cleanly.

## Permissions

When you invoke a jim slash command in a new Claude Code session, the spawned subagent (e.g. `@jim:architect` for `/jim:plan`) reads jim's bundled template (e.g. `skills/plan/assets/plan-template.md`) and Claude Code surfaces a Read permission prompt:

```
Read file
  Read(/path/to/jim/skills/plan/assets/plan-template.md)
Do you want to proceed?
  1. Yes
  2. Yes, allow reading from assets/ during this session
```

**Default behavior — pick option 2 once per session.** Choosing **"Yes, allow reading from assets/ during this session"** authorizes the read for the rest of the Claude Code session. Subsequent invocations of jim slash commands in the same session do not re-prompt. The prompt returns when you start a fresh session.

### Zero-prompt setup (optional)

To suppress the prompt entirely across sessions, add a `permissions.allow` block to your project's `.claude/settings.json` listing absolute paths to jim's `skills/*/assets/` and `skills/*/references/` directories. Replace `/absolute/path/to/jim` with the actual install path on your machine (find it with `realpath` on the directory containing `plugin.json`):

```json
{
  "permissions": {
    "allow": [
      "Read(/absolute/path/to/jim/skills/*/assets/**)",
      "Read(/absolute/path/to/jim/skills/*/references/**)"
    ]
  }
}
```

Restart Claude Code after editing settings. Subagents inherit the parent session's permission rules, so the prompt is silenced for every jim skill that reads from its own bundled templates or methodology docs.

### Why this is necessary

Claude Code's documented permission model does not let a plugin ship pre-approved file access for its subagents. Skill frontmatter `allowed-tools` grants apply only to the skill's main-thread execution and do not propagate to spawned subagents; subagent frontmatter has no `allowed-tools` field; and plugin manifests/settings cannot declare permissions. The user-side `.claude/settings.json` is the only documented mechanism that survives the skill → subagent boundary. See `ARCHITECTURE.md` → Permission Conventions for the full verified-scope discussion, and the doc citations behind it. (A future jim release may add a `/jim:setup` helper to generate the snippet for your install path automatically.)

## How to develop for Jim

See [`WORKFLOW.md`](./WORKFLOW.md) for the full SDLC process.

Jim builds itself using its own workflow. Jim's specs live in [`docs/specs/jim/`](docs/specs/jim/).

### Running tests

Jim's bash scripts (`jimconf.sh`, `jimfile.sh`, `metatest.sh`) are covered by a plain-bash test suite with zero third-party dependencies. The shared framework and aggregate runner live under `skills/meta-test/scripts/`; per-script test files live in `tests/` and source the relocated lib via a `BASH_SOURCE`-relative path.

```bash
/jim:meta-test run                          # via the skill — every case across every file
/jim:meta-test run jimfile                  # via the skill — only jimfile (standalone path)

bash skills/meta-test/scripts/run.sh        # direct — every case across every file
bash skills/meta-test/scripts/run.sh jimfile  # direct — filter by case-name substring
bash tests/jimconf.sh                       # standalone — only jimconf cases
bash tests/jimfile.sh                       # standalone — only jimfile cases
bash tests/metatest.sh                      # standalone — only metatest cases
```

Shared infrastructure (asserts, fixtures, reporter) lives in `skills/meta-test/scripts/testlib.sh`; per-script test files source it. Test discovery is by function-name convention — any function named `case_*` is a test. To add a new test file, use `/jim:meta-test scaffold <name>` (or see the recipe in the `testlib.sh` header).

Tests live under `tests/` (per-script files only) and are not loaded by Claude Code — they are a developer-only artifact.

