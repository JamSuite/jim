---
title: "Issue Tracking — Local Files (v1)"
type: feature
group: "issue"
id: "017"
status: approved
origin:
  - "docs/brainstorms/20260530-issue-tracking.md"
  - "docs/research/20260530-issue-tracking.md"
---

# 017 Issue Tracking — Local Files (v1)

## Overview

Adds local-files issue tracking to jim — `/jim:issue` captures a single discovery from the current conversation as a structured markdown file under `docs/issues/`, and `/jim:issues` renders clustering and blocking views over the collection. Foundation for later workflow integration and 3rd-party backends, deliberately scoped narrow.

## Problem Statement

During spec → research → plan → build workflows, developers and agents surface bits of work that are out of scope for the current task but worth saving — out-of-scope ideas, deferred edge cases, gaps noticed during research, security concerns flagged in passing. Today these are lost when the session ends or buried in conversation history. Developers using jim have no native way to capture these as structured artifacts that link back to their originating workflow, and resort to ad-hoc notes or external tools that lose the provenance trail.

The vision (`VISION.md`, recently updated) explicitly carves out *discovery artifact capture* as in-scope for jim, distinct from team-coordination project management. This spec delivers that carve-out's first concrete surface.

## User Stories

- As a developer using jim, I can run `/jim:issue [subject]` to capture a discovery from my current conversation as a structured markdown file, so that bits of work surfaced during the workflow are saved as persistent artifacts instead of lost when the session ends.
- As a developer, I can run `/jim:issues` to see a clustering view (by origin and labels) and a blocking view (by out-degree of `blocks` relations), so that I can spot which areas of the project are generating noise and which issues block the most other work.
- As an agent navigating an existing issue collection mid-task, I can read the auto-generated index to find related issues by status, priority, labels, and typed relations, so that I can ground my work in prior discoveries without scanning every issue file.
- As a developer, I can close an issue by editing its status field directly in the markdown file, so that closure is a low-friction edit instead of a specialized command flow.

## Acceptance Criteria

**Capture (`/jim:issue`)**

- [ ] `/jim:issue [subject]` creates a new markdown file under the configured issues directory. When invoked with no subject, the agent derives a title from current conversation context. When invoked with a subject string, the string seeds the title and the body still draws from conversation context.
- [ ] Before any file write, the agent presents the full drafted issue (title, frontmatter metadata, body) for a single confirm-or-edit moment. The user can approve, edit inline, or cancel. No fields are confirmed via per-field interview. The confirmation prompt explicitly reminds the user that this moment is the last chance to scrub sensitive content (API keys, customer data, raw secrets) before persistence.
- [ ] Each issue file uses YAML frontmatter with the fields `id`, `title`, `status`, `priority`, `labels`, `relations`, `created`, `updated`, and `origin` (link to the source spec / brainstorm / research / debug / conversation, when knowable). *External Constraint — sourced from `docs/research/20260530-issue-tracking.md` § Recommendations (Option C).*
- [ ] `status` is a string with the values `open` and `closed`. No other lifecycle states are recognized in v1. *External Constraint — sourced from same.*
- [ ] `relations` supports four bidirectional typed link types: `blocks`, `depends-on`, `related-to`, `duplicates`. Setting `blocks` on one issue implies `depends-on` on the target. *External Constraint — sourced from same.*
- [ ] Issue file names use a date-prefixed slug format (`YYYYMMDD-slug.md`) — collision-tolerant under parallel feature branches. *External Constraint — sourced from same § Cross-cutting.*
- [ ] Slug normalization (applied to both the user-supplied subject and the agent-derived title) restricts the slug to lowercase alphanumeric and dash characters; path separators (`/`, `\`), `..`, leading dots, and control characters are rejected as an error before any file write.

**Read view (`/jim:issues`)**

- [ ] `/jim:issues` renders two report sections derived from the index: **Clusters** (issues grouped by `origin` and by `labels`, with a count per group) and **Blocking** (issues with the most outgoing `blocks` relations, sorted by out-degree).
- [ ] The report distinguishes open vs closed counts at the top.
- [ ] `/jim:issues` is read-only — it does not mutate the collection.

**Index (`INDEX.md`)**

- [ ] `docs/issues/INDEX.md` is auto-generated and lists every issue in the collection with title, status, priority, labels, and origin. Agents can navigate the collection by reading the index alone — no per-file scan needed for routine lookup.
- [ ] The index regenerates on every `/jim:issue` write so that consumers (both `/jim:issues` and agents reading the index directly) always see current data.
- [ ] Wiki-style links of the form `[[other-issue-slug]]` in an issue body, **and** entries in the frontmatter `relations:` map, both surface as edges in the index's graph view. Frontmatter is the canonical structural channel; body wikilinks alias to `related-to` edges. The graph dedupes per `(source, type, target)` so dual-channel authorship produces one edge. Bidirectional integrity is checked against frontmatter relations only — body wikilinks are one-way "see also" pointers that do not trigger or satisfy reciprocation warnings.
- [ ] Wiki-link content (the text between `[[` and `]]`) must match the slug normalization rule. Malformed link content is treated as plain prose, not a graph edge — graph resolution does not follow path-shaped or otherwise out-of-format link content.

**Path and config**

- [ ] The canonical write path for a new issue is resolvable via jim's standard file-path resolver, matching how spec / plan / research / brainstorm paths are resolved today. *External Constraint — sourced from `ARCHITECTURE.md` § Plugin Conventions → Scripting Layer.*
- [ ] The default storage location `docs/issues/` is overridable per project via jim's standard config mechanism. *External Constraint — same source.*

**Security and safety**

- [ ] The frontmatter parser must never `source` or `eval` issue files, and must never invoke a full YAML parser (YAML tag-based deserialization is a recurring CVE class). Parsing uses line-oriented tools (`grep` / `sed` / `cut`) against the known field set only, mirroring the discipline in `skills/conf/scripts/jimconf.sh` and `skills/file/scripts/jimfile.sh`. *External Constraint — sourced from `CLAUDE.md` § Bash scripts.*
- [ ] When issue content (body or frontmatter values) flows from an issue file into a subordinate agent's context — during graph navigation, clustering analysis, or any agent-to-agent context handoff — the content is wrapped in a structural marker identifying it as untrusted user-authored data, and the receiving agent is instructed not to follow instructions embedded in that content. Defense-in-depth against indirect prompt injection through the persistent issue collection.

## UI Mockup

`/jim:issue` confirm-or-edit moment:

```
> /jim:issue auth middleware swallows 401s

I'll draft this from our conversation about the auth review.

+--------------------------------------+
| 20260530-auth-middleware-swallow-401 |
+--------------------------------------+
| status:    open                      |
| priority:  high                      |
| labels:    [auth, middleware]        |
| origin:    docs/specs/sdlc/013-sec/   |
| relations:                           |
|   related-to: []                     |
+--------------------------------------+
| ## Description                       |
| The auth middleware catches 401      |
| responses from upstream and converts |
| them to 200 before they reach the    |
| client. Token expiry is masked.      |
|                                      |
| Surfaced during /jim:sec review of   |
| the spec-016 plan.                   |
+--------------------------------------+

[file] [edit] [cancel]
```

`/jim:issues` trend view:

```
> /jim:issues

Issue Collection — docs/issues/

  Open: 14    Closed: 8

== Clusters ==

  By origin
    docs/specs/sdlc/013-sec/                 5
    docs/brainstorms/20260530-...md         2
    (unattributed)                          7

  By label
    auth        4
    middleware  3
    security    6

== Blocking ==

  20260528-credential-leak-log-trace
    blocks 4 issues
      - 20260527-session-fixation-vector
      - 20260526-csrf-token-rotation
      - 20260525-rate-limit-exhaustion
      - 20260524-audit-log-tamper-check
```

## Out of Scope

- **Workflow integration.** Auto-capture of candidate issues during `/jim:build`, `/jim:plan`, `/jim:spec`, `/jim:research`, `/jim:brainstorm` runs (per-stage offer, end-of-run offer, heuristic surfacing, batch-confirm tables) — deferred to a follow-on spec. v1 is ad-hoc capture only.
- **3rd-party backends.** GitHub Issues, Linear, etc. — deferred. Will follow the bridge abstraction pattern surfaced in research when scoped.
- **Full lifecycle states.** `in-progress`, `wontfix`, `duplicate`, custom states — not in v1. Only `open` and `closed`.
- **Agent-CLI commands.** `claim`, `next`, `done`, `blocked`, `graph` (as seen in `steviee/git-issues`) — deferred.
- **Configurable ID schemes.** Sequential / hash / custom — v1 ships date-prefixed only. Configurability deferred until a real reason emerges.
- **Conversational invocation modes** (loud vs quiet) — these belong to workflow integration which is itself deferred. `/jim:issue` always operates in single-confirm "loud" mode in v1.
- **Editing issues via `/jim:issue` subcommand.** Updates happen via direct file edit (the files are plain markdown). v1's `/jim:issue` is capture-only.
- **Interactive force-directed graph view.** The trend view is text-only.
- **Cross-project issue federation.** Each project's `docs/issues/` is independent.
- **Structured audit trail for status transitions.** v1 relies on `git log` / `git blame` over `docs/issues/` for the "who/when/why" of closure. A structured `transitions:` schema entry is deferred until lifecycle expands beyond `open` / `closed`.

## Open Questions

None — outstanding ambiguities were resolved during brainstorm (`docs/brainstorms/20260530-issue-tracking.md`) and research (`docs/research/20260530-issue-tracking.md`).
