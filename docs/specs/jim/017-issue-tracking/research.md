---
spec: "spec.md"
status: Active
date: "2026-05-30"
---

<!-- PM feedback (lifecycle scope, ID scheme, VISION non-goal framing) resolved during spec interview. See spec.md for the decisions. Original topic-based copy lives at docs/research/20260530-issue-tracking.md. -->


# Research: Issue Tracking Prior Art

Context: brainstorm at `docs/brainstorms/20260530-issue-tracking.md` — local-files v1, per-file markdown with frontmatter, wiki-link graph, auto-index, optional 3rd-party backends.

## Anchors

**Greenfield in jim itself.** Local audit:

- `glob docs/issues/` — does not exist.
- `find -type d -name issues` — no hits.
- `grep -li "issue" docs/` — only unrelated spec/debug mentions, no implementation.

Implementation will create:

- `skills/issue/SKILL.md` — capture skill (LLM reasoning), mirrors `skills/brainstorm/` layout.
- `skills/issues/SKILL.md` — read-side trend view, mirrors `/jim:conf` / `/jim:file` wrapper pattern.
- `skills/file/scripts/jimfile.sh` (existing, `skills/file/scripts/jimfile.sh:1-…`) — extend with `path issue <slug>` and an issue branch in `next-id`, mirroring existing spec/plan/research/brainstorm path branches.
- `docs/issues/` — new directory, one markdown file per issue.
- `docs/issues/INDEX.md` — auto-generated index.
- `agents/pm.md` (`agents/pm.md:1-75`) — extend `skills` binding.

## Local Patterns

- **Skill+script wrapper pattern.** `/jim:conf` and `/jim:file` are the canonical bash-wrapper skills (deterministic, no LLM reasoning). `/jim:issues` (read-side) and the index regenerator fit this shape. `/jim:issue` (write-side capture) is an LLM skill — mirrors `/jim:brainstorm`.
- **Path resolution.** Add `issues_path` to `jimconf.toml` (default `docs/issues/`); resolve via `jimfile.sh path issue <slug>`. Matches `brainstorms_path` (spec 008).
- **ID generation.** `jimfile.sh next-id` already exists for spec IDs. Same script gets a date-prefixed branch for issues (matches `docs/brainstorms/YYYYMMDD-…` convention).
- **Test template.** `tests/jimfile.sh` (`tests/jimfile.sh:1-…`) — bash test harness, `case_jimfile_*` per `skills/meta-test/scripts/testlib.sh` convention. New issue path / ID logic gets `case_jimfile_issue_*` cases.
- **Strategic-doc gate sentinel.** New skills load VISION/ROADMAP/ARCHITECTURE via the `SET … !\`…\` / IF != "NOT_FOUND" THEN` idiom (ARCHITECTURE.md → Logic-Flow Conventions). The issue collection itself is NOT loaded at session start.
- **Heuristic surfacing during build.** `/jim:build` step 5.2 already invokes `/jim:arch` post-build. Same pattern fits issue surfacing — at end-of-stage or end-of-run, the SDLC skills invoke `/jim:issue` per candidate.

## Prior Art

### Tier 1 — Study Closely

**[steviee/git-issues](https://github.com/steviee/git-issues)** ([HN discussion](https://news.ycombinator.com/item?id=47973644)) — explicitly AI-agent-first markdown tracker. Near-1:1 design match for the brainstorm.

| File | What It Is | Why It Matters |
|---|---|---|
| `.issues/0001-fix-login-bug.md` | YAML-frontmatter markdown issue | Schema is almost identical to the brainstorm's strawman |
| `.issues/.agent.md` | In-repo schema + command reference for agents | Pattern jim could mirror as `docs/issues/README.md`, or rely on the `/jim:issue` skill body |
| `.issues/.config.yml` | Defaults + predefined labels | Maps to `jimconf.toml` (extends existing convention) |

Schema fields: `id`, `title`, `status`, `priority`, `labels`, `relations`, `created`, `updated`. Relations are **bidirectional and typed**: `blocks`, `depends-on`, `related-to`, `duplicates`. Lifecycle: `open → in-progress (claim) → closed`. ID: zero-padded numeric (`0001-slug.md`). No central index — `issues check` scans for consistency. Agent-friendly commands: `next` (highest-priority unblocked), `claim`, `done`, `blocked`, `check`, `graph`.

**Key lesson for jim:** "new issues only on main" to prevent ID collisions across worktrees/branches. Direct concern if auto-capture fires during a feature-branch build.

### Tier 2 — Study for Specific Patterns

**[mgoellnitz/trackdown](https://github.com/mgoellnitz/trackdown)** — plain-markdown, but aggregated in a single `issues.md` (not per-file). Counter-example to jim's per-file model. The auto-generated `roadmap.md` (groups by version, tracks in-progress/resolved counts) is the closest reference for the trend view jim wants from `/jim:issues`.

| File | What It Is | Why It Matters |
|---|---|---|
| `issues.md` | Aggregate ticket file | Per-file vs aggregate trade-off |
| `roadmap.md` | Auto-grouped progress view | Template for jim's auto-`INDEX.md` shape |

Status transitions are commit-message driven (`refs #ID` → in-progress, `fixes #ID` → resolved) — low-friction lifecycle worth parking for later.

**[Obsidian + Dataview](https://dev.to/penfieldlabs/what-karpathys-llm-wiki-is-missing-and-how-to-fix-it-1988)** — typed wikilinks + queryable frontmatter is the model `/jim:issues` clustering/blocking view depends on. Dataview-style queries (`status: open AND priority: high`) work because frontmatter is structured — validates the schema choice. Interactive force-directed graph view is overkill for v1; park.

### Tier 3 — Reference Only

**[git-bug](https://github.com/git-bug/git-bug)** — issues as git objects, not files. Misaligned with jim's plain-markdown choice (no human readability without the tool). Transferable: **bridges architecture** — the GitHub/GitLab sync model is the right shape for jim's future 3rd-party backends (Linear/GitHub Issues).

**[Fossil SCM](https://fossil-scm.org/home/doc/tip/www/bugtheory.wiki)** — DB-backed tickets with replayable change artifacts. Included to confirm the DB alternative was considered and rejected for v1.

## Security & Performance

- **ID collision under parallel branches.** Sequential numeric IDs (one of the configurable options the brainstorm proposed) can collide at merge time when issues are filed on multiple feature branches. **Mitigation:** date-prefixed default (collision-tolerant), or restrict creation to main (`git-issues`' approach). Worth raising in spec scoping.
- **Index regeneration cost.** Auto-`INDEX.md` rebuilt on every issue write is O(n) per write. Invisible at low n; noticeable past ~hundreds of issues. **Mitigation:** lazy regeneration (mark stale, rebuild on next `/jim:issues`) or incremental updates.
- **`source`/`eval` boundary.** Frontmatter parser must never `source` issue files (CLAUDE.md security rule). Parse with `grep` / `sed` / `cut`, matching `jimconf.sh` discipline.
- **Build-time side-effects.** Heuristic surfacing during `/jim:build` must not interrupt the TDD red-green-refactor commit chain. Issue creation is a side-effect, not part of the commit discipline.

## Recommendations

**Alignment:** Aligns with ARCHITECTURE.md (markdown-first, bash + POSIX scripting layer, `jimfile.sh` extension, no new dependencies). Surfaces tension with VISION.md's "Not a project management tool" non-goal — handled in Peer Feedback.

Three options for the spec to weigh.

**Option A — Mirror git-issues' schema directly.** Adopt the proven schema verbatim (id/title/status/priority/labels/relations/created/updated, bidirectional typed relations). Defer the `claim` / `next` / `done` agent CLI. *Diverges from brainstorm's "lifecycle deferred for v1"* — flag for PM.

**Option B — Brainstorm strawman strictly.** Build the strawman (id/title/status/severity/origin/links/created/tags) with `resolved: true` as the only closure marker. *Trade-off:* `/jim:issues` clustering can't distinguish "active work" from "open backlog" until lifecycle ships in v2.

**Option C — Hybrid (recommended).** Schema from Option A (proven shape, bidirectional typed relations), but defer agent-CLI commands as the brainstorm intended; closure is `status: closed` rather than `resolved: true`. *Minor divergence:* status as string vs boolean is identical effort and matches prior art's vocabulary.

**Cross-cutting (apply to all three):**

- ID default: **date-prefixed** (matches `docs/brainstorms/`, sidesteps git-issues' main-only constraint).
- INDEX.md regeneration: **lazy + on-demand refresh via `/jim:issues`** (avoids n-per-write cost).
- 3rd-party backends: follow git-bug's **bridge** abstraction when those backends are specced.

## Peer Feedback

**For PM (spec feasibility):**

- The brainstorm's "lifecycle deferred for v1" is workable, but git-issues shows a string `status` field is no more expensive than `resolved: true` and matches prior art vocabulary. Suggest revisiting during spec scoping.
- The "configurable ID scheme" decision has a hidden cost: numeric/sequential IDs introduce real collision risk under parallel branches. If sequential is shipped as a choice, document the "create on main only" caveat; the safer default is date-prefixed.
- VISION.md's "Not a project management tool" non-goal can stand if the spec frames issues as **discovery artifacts surfaced during the jim workflow**, not work-tracking primitives. Matches how `git-issues` positions itself. Consider clarifying the non-goal language via `/jim:vision` to carve out this case explicitly.

**For Architect:** N/A — no plan exists yet.
