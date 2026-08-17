In Claude Code, plugins handle configuration through several conventions, ranging from manifest-prompted values at install time to project-local Markdown files read at skill invocation. Three main patterns have emerged.

## 1. The "State & Settings" Convention (.local.md)
The most common and flexible pattern for community and official plugins is using a Markdown file with YAML frontmatter. Plugins read the configuration at skill-invocation time and apply it to skill behavior.

* Config Location: .claude/<plugin-name>.local.md (Project Root)
* Skill for Fetching: The Read tool is used to pull the file content, followed by the Bash tool to parse YAML frontmatter (often using grep, sed, or yq).
* Documentation Skill: Anthropic ships a specific meta-skill called plugin-settings to teach other plugins how to use this pattern.  

## Featured Configurable Plugins
### Plugin Settings (Official Tooling)
* Link: anthropics/claude-code/plugins/plugin-dev/skills/plugin-settings
* Description: This isn't just a plugin; it's the "blueprint" skill that ships with the developer kit to standardize how all other plugins handle local state and user preferences.
* Configuration Handling:
  * What is configurable: Plugin "modes" (strict vs. lenient), feature toggles, and session-specific metadata.  
  * Where it lives: .claude/<plugin-name>.local.md.
  * Skill to read: The plugin provides bash snippets for hooks to parse config:  
    ```bash
    # Skill-native logic example:
    STATE_FILE=".claude/my-plugin.local.md"
    LEVEL=$(grep '^validation_level:' "$STATE_FILE" | sed 's/validation_level: *//')
    ```

### Commit Commands (Official)
* Link: anthropics/claude-code/plugins/commit-commands
* Description: Automates git workflows, including conventional commits, branch management, and PR creation.  
* Configuration Handling:
  * What is configurable: Git attribution (e.g., "Co-authored-by: Claude"), conventional commit styles, and auto-push behaviors.
  * Where it lives: Hierarchical settings.json files.
    * User: ~/.claude/settings.json
    * Project: .claude/settings.json
    * Local: .claude/settings.local.json
  * Skill to read: Uses the built-in /config system. Claude accesses these values via an internal environment context rather than a specific filesystem-reading skill.

### Feature Dev (Official)
* Link: anthropics/claude-code/plugins/feature-dev
* Description: A multi-phase agentic workflow for architecting and implementing complex features.  
* Configuration Handling:
  * What is configurable: Project-specific architecture rules, preferred testing frameworks, and "Phase" exit criteria.
  * Where it lives: Heavily relies on CLAUDE.md at the project root. This is the "Memory Bank" style of configuration.
  * Skill to read: Read. The plugin's system prompt instructs the agent to always check CLAUDE.md for architectural context before starting a task.

### Claude-Mem (Persistent Memory)
* Link: github.com/thedotmack/claude-mem
* Description: Automatically captures tool usage and code changes across sessions, compresses them using AI, and injects relevant history back into future sessions to maintain continuity.  
* Configuration Handling:
  * What is configurable: Data directory path, worker port, AI compression thresholds, and privacy exclusions (via tags).  
  * Where it lives: ~/.claude-mem/settings.json (Global) and environment variables like CLAUDE_MEM_DATA_DIR.
  * Skills:
    * mem-search: SKILL.md — Uses a shell snippet to resolve the active worker port from environment variables to query the local SQLite database.

### Arc-Kit (Enterprise Architecture)
* Link: github.com/tractorjuice/arc-kit
* Description: A toolkit for enterprise architecture governance, vendor procurement, and automated document generation.
* Configuration Handling:
  * What is configurable: Organization name, document classification levels (e.g., SECRET, PUBLIC), and governance frameworks (e.g., UK Government vs. Generic).  
  * Where it lives: The userConfig block in plugin.json. Values are stored in ~/.claude/settings.json for non-sensitive data and the system keychain for API keys.
  * Skills:
    * sub-agent-config: Automatically receives configuration via CLAUDE_PLUGIN_OPTION_<KEY> environment variables.
    * template-substitutor: Dynamically injects ${user_config.organisation_name} into Markdown templates.

### Strategic Compact (Context Management)
* Link: github.com/anilcancakir/claude-code-plugins
* Description: Prevents "context bloat" by suggesting manual compaction at strategic project milestones (e.g., after a successful test run or feature completion) rather than arbitrary token limits.  
* Configuration Handling:
  * What is configurable: Compaction thresholds and phase-detection sensitivity (Exploration vs. Implementation mode).
  * Where it lives: .claude/strategic-compact.local.md (Project Local).
  * Skills:
    * serena-navigator: Reads the .local.md file using the Read tool and parses the YAML frontmatter to determine if it should suggest a context wipe.

### Project Optimizer
* Link: github.com/anilcancakir/claude-code-plugins/tree/main/project-optimizer
* Description: Audits project structure and automatically generates/maintains the CLAUDE.md and brand.md files.
* Configuration Handling:
  * What is configurable: Brand archetypes (12 Jungian archetypes), project identity, and technical stack requirements.  
  * Where it lives: CLAUDE.md (Technical) and brand.md (Style/Identity).
  * Skills:
    * /my_setup: SKILL.md — Uses the Bash tool to run jq commands against local JSON manifests to verify setup.

## Configuration Conventions

|Method|Fetching Mechanism|Primary Use Case|
|------|------------------|----------------|
|userConfig|Manifest Substitution|API Keys & Global Setup: Values like ${user_config.KEY} are auto-replaced in skill text.|
|Env Vars|CLAUDE_PLUGIN_OPTION_|Subprocesses: Used by Bash hooks and MCP servers to read settings without file I/O.|
|.local.md|Read + grep/sed|Project-local plugin state: stored as YAML frontmatter; read at skill-invocation time.|
|settings.json|/config command|User UI: Hierarchical settings (User → Project → Local) managed via the Claude Code REPL.|

## Summary of Configuration Skills

If you are building a plugin, these are the "skills" (tools) you will use to fetch configuration:

| Skill / Tool | Source | Purpose |
| :--- | :--- | :--- |
| **`Read`** | Built-in | Used to read `.local.md` files or `CLAUDE.md` context. |
| **`Bash`** | Built-in | Used to extract specific variables from YAML/JSON config files via CLI tools (grep, sed, yq). |
| **`plugin-settings`** | [plugin-dev](https://github.com/anthropics/claude-code/tree/main/plugins/plugin-dev) | A reference skill that provides logic for handling `.local.md` patterns and state persistence. |
| **`userConfig`** | [plugin.json](https://code.claude.com/docs/en/plugins-reference#user-configuration) | A manifest-level schema that generates interactive setup prompts during the installation phase. |

Runtime: Plugin checks for a .claude/<plugin>.local.md file using the Read tool for project-specific overrides.

