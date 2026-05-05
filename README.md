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
| `/jim:brainstorm` | Freeform ideation and exploratory notes |
| `/jim:conf` | Inspect resolved jim configuration paths |
| `/jim:file` | Inspect jim's file/path resolver (existence, slug, date, next-id, path, glob) |
| `/jim:meta-skill` | Build a jim plugin skill from spec |
| `/jim:meta-agent` | Build a jim plugin agent from spec |

## Agents

| Agent | Role |
|-------|------|
| `@jim:pm` | Specs, vision, roadmap, brainstorms |
| `@jim:architect` | Plans, architecture |
| `@jim:coder` | TDD builds, debugging |
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
/jim:file next-id jim                                 # next zero-padded spec ID
/jim:file path spec jim 008 jimfile                   # canonical spec path
/jim:file path debug "auth bug"                       # date-prefixed debug path
/jim:file glob specs jim                              # every spec in the jim group
/jim:file kinds                                       # valid artifact kinds
```

Path-and-name resolution only — the script never reads, writes, or deletes files. Slug normalization, the `.`/`..` reject, and the 64-char cap are enforced by the script (security boundary).

## How to develop for Jim

See [`WORKFLOW.md`](./WORKFLOW.md) for the full SDLC process.

Jim builds itself using its own workflow. Jim's specs live in [`docs/specs/jim/`](docs/specs/jim/).

### Running tests

The resolver scripts (`skills/conf/scripts/jimconf.sh` and `skills/file/scripts/jimfile.sh`) are covered by a plain-bash test runner with zero third-party dependencies:

```bash
bash tests/run.sh                  # all tests
bash tests/run.sh defaults         # jimconf cases — filter by name substring
bash tests/run.sh jimfile          # jimfile cases only
```

Tests live under `tests/` and are not loaded by Claude Code — they are a developer-only artifact.

