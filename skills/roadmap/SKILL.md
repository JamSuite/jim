---
name: roadmap
description: >
  Create or update the project ROADMAP.md — Now/Next/Later execution buckets
  with version anchors. Use when the user invokes /jim:roadmap, wants to
  organize priorities, or asks what's coming next. Do not use for product
  direction (/jim:vision), technical architecture (/jim:arch), or scoping
  individual work items (/jim:spec).
agent: pm
allowed-tools: Bash(bash *)
---

# /jim:roadmap

Create or update the project's ROADMAP.md — a concise Now/Next/Later execution sequence with version anchors.

*(The `agent: pm` field in this frontmatter is a jim documentation convention, not a Claude Code routing mechanism.)*

## Process

### 1. Seed the conversation

Use `$ARGUMENTS` as a hint for what the user wants to add or update. If empty, start from scratch or review the existing roadmap.

### 2. Read context

Read !`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get vision` from the project root if it exists — for strategic alignment.

If missing, note: "No vision doc yet — consider running `/jim:vision` first to establish product direction. I'll proceed without it." Do not block.

### 3. Search for linkable specs

Glob !`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get specs`/**/*.md to find existing specs. Grep frontmatter `title:` fields to build a list of linkable candidates. Hold this list — when the user mentions a deliverable that matches a known spec, offer the link.

Do not Read full spec contents — Glob and Grep only. This prevents context overflow in repos with many specs.

### 4. Check for existing ROADMAP.md

Read !`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get roadmap` from the project root.

- **Exists:** Differential update. Read existing content. Summarize the current state to the user. Ask what they want to change — add items, move items between buckets, update version anchors, refine objectives.
- **Does not exist:** Fresh creation. Proceed to interview.

### 5. Interview

Walk through the three time-horizon buckets:

- **Now** — "What's actively being worked on? What version or milestone does this map to?"
- **Next** — "What's committed but not started? When does this come after Now?"
- **Later** — "What ideas are on the horizon but not committed?"

For each item the user describes, determine the appropriate detail level:

| Signal | Format |
|--------|--------|
| User describes clear objectives and success criteria | Goal-oriented: Objective / Deliverables / Success Metrics |
| User lists tactical items or early ideas | Simple bullet list |

When a deliverable matches a known spec from step 3, offer: "I found a spec for that — want me to link it? `[003-pm-strategy](docs/specs/jim/003-pm-strategy/spec.md)`"

### 6. Conciseness enforcement

The roadmap is a strategic communication tool, not a backlog. Push back when it gets too detailed:

- More than 5-7 items per bucket → "This is getting long — want to consolidate, or create specs for the detailed items with `/jim:spec`?"
- Any item description exceeds 3-4 lines → "This is getting detailed — want to create a spec for this? The roadmap works best as a big-picture view."

### 7. Generate ROADMAP.md

Read `assets/roadmap-template.md`. Fill buckets with interview results. Set "Last updated" to today's date. Keep it concise.

Write to !`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get roadmap` at the project root.

### 8. Silent self-check

Before presenting, validate against these anti-patterns:

- **Feature list, no outcomes** — Items are just feature names without strategic context. Fix: add objectives or group under meaningful themes.
- **Backlog masquerading as roadmap** — More than ~7 items per bucket. Fix: consolidate or defer detail to specs.
- **No version anchors** — Buckets have no version or milestone markers. Fix: ask the user for version targets.

Auto-correct violations before presenting.

### 9. Present and stop

Show the drafted ROADMAP.md to the user.

- **Differential update:** Show change summary first. Ask: "Want me to apply these changes?"
- **New creation:** Ask: "Want me to write this, or would you like changes first?"

Use Edit for updates, Write for new files. Never auto-apply.
