---
name: arch
description: >
  Generate or update ARCHITECTURE.md from actual codebase analysis. Use when
  the user invokes /jim:arch, when starting a new project and needing an
  architecture baseline, or when the architecture document has drifted from
  the real codebase. Do not use for planning specific features (/jim:plan) or
  for implementation (/jim:build).
agent: architect
argument-hint: "[directory-path]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh *)
---

# /jim:arch

Generate or update ARCHITECTURE.md from actual codebase scanning. The document reflects reality, not aspirations.

## Argument Routing

Use `$ARGUMENTS` to determine scope:

| Input | Behavior |
| :--- | :--- |
| Empty | Create or update the resolved architecture path (default: !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh path architecture`) |
| Directory path | Create or update the architecture file inside that directory, using the filename portion of the resolved architecture path |

## Process

### 1. Establish scope

Resolve the configured architecture path: !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh path architecture`.

If `$ARGUMENTS` is empty, that *is* the target path. If `$ARGUMENTS` is a directory, the target is `{$ARGUMENTS}/<filename portion of the resolved path>`.

### 2. Read the vision doc as upstream context

SET vision_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`
IF vision_doc != "NOT_FOUND" THEN
  Read vision_doc — the architecture serves the vision; where there is tension between the actual code and the stated vision, flag it rather than silently encoding the discrepancy into the architecture document.
ENDIF

If absent, proceed without it. Note its absence in the Overview if you generate a new file.

### 3. Check for existing ARCHITECTURE.md

SET arch_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`

IF arch_doc != "NOT_FOUND" THEN
  This is a differential update. Read the existing document fully. Summarize proposed changes to the user — which sections will be updated, which will be preserved — before writing anything. Use Edit, not Write. (When `$ARGUMENTS` is a directory, the target is `{$ARGUMENTS}/<filename portion of arch_doc>`; the differential-update treatment still applies if a file exists at the target.)
ELSE
  Generate a new document from `assets/architecture-template.md`.
ENDIF

### 4. Scan the codebase

Do not fill the template from assumptions. Read actual code.

Use Glob and Grep to populate each section:

- **Project Structure:** Glob `{directory}/**` to map the directory tree. Focus on the top 2-3 levels; annotate directories whose purpose is non-obvious.
- **Partition (spec 033):** SET map_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get blueprint` — when `map_doc != "NOT_FOUND"`, the project has a context map: the spec-group partition is *its* declared content. Reference `BLUEPRINT.md` for the partition (a link plus at most a one-line summary); never re-declare groups, roles, relations, or territories in this document — one authority, no second copy to drift.
- **Core Components:** Grep for entry points, exported functions, class/interface definitions, and module boundaries. Identify what each component exposes and depends on.
- **Data Stores:** Grep for database connections, file reads/writes, cache calls, or persistence patterns. Look for config files that declare data locations.
- **External Integrations:** Grep for HTTP clients, API calls, SDK imports, and third-party service references. Check package manifests (package.json, go.mod, requirements.txt, Cargo.toml) for external dependencies.
- **Deployment & Infrastructure:** Look for Dockerfile, docker-compose.yml, .github/workflows/, Makefile, build scripts. Check package.json `scripts` or equivalent.
- **Security Considerations:** Grep for auth patterns, secret/credential handling, environment variable reads, file permission checks.
- **Development & Testing:** Find test files and directories, CI config, linting config. Identify the test framework and test command.

For each finding, record the file path and relevant line range. The architecture document is grounded in evidence, not inference.

### 5. Generate or update the document

Read `assets/architecture-template.md` for the section structure.

Fill each section from scan findings:

- Use actual directory names, file paths, and component names from the codebase.
- Write the High-Level System Diagram as a Mermaid flowchart. Use actual component names — not generic "Component A" placeholders.
- If a section has no findings (e.g., no external integrations), write "*None identified.*" rather than removing the section. This signals completeness, not omission.
- If VISION.md flagged a tension between vision and implementation, note it in Security Considerations or a brief "Architecture Notes" at the end.

### 6. Present and stop

Show the completed document (or summarize changes for a differential update). List which sections changed and which sections had no findings.

SET auto_arch_feedback = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get auto_arch_feedback`

IF auto_arch_feedback == "true" THEN
  Write the proposed update directly to the configured architecture path. Summarize which sections were added, changed, or preserved.
ELSE
  Present the diff and ask: "Does this look accurate? Any sections to refine?" Wait for confirmation.
ENDIF

Do not proceed to the next phase.

## Validation Checklist

Before presenting, confirm:

- [ ] Every section is populated from actual code, not from the template placeholder text
- [ ] No generic placeholder names remain (e.g., "Component A", "{project-root}")
- [ ] High-Level System Diagram uses real component names
- [ ] Sections with no findings say "*None identified.*" rather than being removed
- [ ] VISION.md was checked and any tensions are noted
- [ ] Differential update used Edit, not Write
- [ ] File paths in Component sections include actual line-range anchors where relevant
