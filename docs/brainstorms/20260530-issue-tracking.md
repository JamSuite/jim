# Brainstorm: Issue Tracking

*2026-05-30*

## Framing

Some PM-tool'ish features, plus the ability to route to 3rd-party tools. The jim workflow sharpens ideas and narrows scope before the build phase, but along the way it surfaces interesting bits of potential work that deserve to be saved for later analysis and action. The vision is to extend jim to capture those bits — both *inline* as part of the jim workflow, and *ad-hoc* as a real-time capture tool.

## Workflow integration

Config options to enable:

- **Enable issue tracking** — read all jim artifacts produced during the workflow (brainstorm, spec, security, research, plan, notes, anything that comes up while progressing through the pipeline to build and merge). After the plan implementation is complete, offer a list or table of potential issues to be converted into real issues.
- **Auto-convert to issues** with a configurable threshold — all, or filtered by importance.

## Ad-hoc capture

Users should be able to file issues at-will, outside the workflow.

## Backends

Issues are routed to various backends, configured per-project:

- Local files (first implementation)
- Local DB
- GitHub Issues
- Linear
- (extensible)

### Local files (v1)

- 1 issue = 1 file
- Markdown with frontmatter
- Wiki-style links to build a graph
- An index
- Some kind of frontmatter schema and issue template to structure the collection
- Supporting operational tools for usage and management

## Usage

- When the user is in the loop, the agent should analyze the issue and suggest reasonable defaults for a quick optimal diversion — not a lengthy interview each time.
- Users should be able to filter issues and see trends emerging from the graph.
- Agents should be able to search and navigate the collection quickly and effectively.

## Clarifications

### Inline capture timing (configurable)

Two modes, user picks:

- **Per-stage** — agent holds candidates in context and offers/creates issues at the end of each jim stage. Survives session clearing between stages (a real workflow pattern).
- **End-of-run** — agent holds candidates in context for the entire spec→plan→build run, offers at the end.

### Backend is either/or, not mirrored

Per project, jim is configured to use exactly one backend. If GitHub Issues is configured, jim talks to the GitHub API — it does not also create local markdown files. No sync engine, no dual-write.

3rd-party integration *may* be two-way (read + write against the remote), but it's never a mirror of a local store.

### Boundary vs VISION non-goals

Not managing team workflows. Issues are *discoveries surfaced while using jim*, captured as artifacts. Legit jim output.

**Parking lot — larger system loop:** A future direction could extend the harness to review and delegate captured issues to agents (auto-route, auto-pick-up). Still not typical PM tooling, but a meaningful future-state.

### Link types in scope

All of these:

- Issue ↔ issue (dependencies, duplicates, blocks)
- Issue ↔ spec/plan/research/brainstorm (provenance — where did this discovery come from?)
- Issue ↔ commit/PR (resolution)

Frontmatter schema needs to support all four classes of link.

### Discovery — explicit + heuristic

Both:

- **Explicit flag** — user says "save that" / "file an issue for that".
- **Heuristics** — agent notices issue-worthy bits without being told (out-of-scope ideas, deferred edge cases, dropped TODOs, surprising research findings) and surfaces them at the configured offer point.

### Invocation — slash command + conversational

- `/jim:issue "subject"` — explicit slash command, discoverable.
- Conversational — if the user tells the agent "create/file an issue" mid-conversation, the agent invokes `/jim:issue` with a subject and a context summary derived from Claude's judgement of the current conversation.

(Implies the `/jim:issue` flow itself takes a subject + optional context, and runs the "suggest reasonable defaults, no long interview" model.)

### Frontmatter — strawman v1

- `id`
- `title`
- `status`
- `severity` / `priority`
- `origin` (link to spec / plan / brainstorm / research that surfaced it)
- `links` (other issues, PRs)
- `created`
- `tags`

Accepted as a starting point.

### Lifecycle — deferred for v1

Status lifecycle (`open`, `in-progress`, `resolved`, `wontfix`, `duplicate`) is needed for multi-user / multi-agent coordination but is **not required** for the initial file-based implementation. Skip for v1, revisit when coordination becomes a real concern.

### Layout & mechanics (v1, local files)

- **Location** — mirror brainstorms: `docs/issues/<slug>.md`, one file per issue.
- **ID scheme** — **configurable** (sequential, date-prefixed, hash — user picks per project).
- **Index** — **auto-generated**. Regenerated on every issue write. Index reflects the graph derived from frontmatter + wiki-links.
- **Heuristic surfacing** — **configurable** (interrupt immediately, or silently queue and offer at the gate).

**Pattern note:** three of these came back "configurable." Issue tracking is shaping up as a feature with strong opinions about *defaults* but unusually high user-tunability. Worth deciding later which defaults ship vs. which knobs are exposed in v1 config.

## UX

### `/jim:issue` mini-interview — single confirm moment

Agent reads context (conversation + recent artifacts), drafts the full issue (title, severity, origin, tags, body), and presents it as a **single confirm-or-edit moment**. User says "good, file it" or edits inline.

Trust Claude's judgement by default; user can edit as needed. No per-field interview.

### End-of-stage / end-of-run candidate offer

- **Format:** table — title, suggested severity, one-line summary, origin.
- **Default interaction:** batch confirm (all candidates filed in one response).
- User can override per-candidate if they want to skip/edit/individually review.

### Trend-spotting — what counts

Of the candidate "trend" definitions, two matter:

- **Clustering** — multiple issues linking to the same spec / origin / tag (signals a noisy area).
- **Blocking** — high-degree issue nodes that block many others (signals a critical-path item).

The rest (frequency-over-time, provenance ratios) — not the target for v1.

### Conversational invocation transparency — configurable

When the user says "file an issue for that" mid-conversation:

- **Loud mode** — agent shows the drafted issue first (same confirm moment as `/jim:issue`).
- **Quiet mode** — agent writes and reports ("filed as `auth-401-swallow`").

Configurable. The pattern of "configurable" keeps reappearing — should consciously decide the *shipping default* per knob.

### Agent search & navigation

Agents navigate by reading the **auto-generated `INDEX.md`** and following links. Same surface as humans — no separate query API. Keeps infra minimal and means the index has to be good enough for both readers.

### Trend-spotting delivery — `/jim:issues`

A dedicated `/jim:issues` command renders the trend view on demand (clustering + blocking). Pull, not push — no proactive jim interruptions about issue trends.

### Edit / update flow — both

- Direct file edit (always available — files are markdown).
- Conversational ("bump that to critical", "link this to issue X") — agent finds the right file via the index and applies the edit.

### Closure without lifecycle — `resolved: true` frontmatter

V1 represents "done" with a `resolved: true` (or equivalent) frontmatter field. Almost-but-not-quite lifecycle — minimum viable closure that supports filtering ("show me open") without committing to a full state machine. When real lifecycle ships, this field is the natural upgrade path.
