---
spec: "standalone"
status: Active
date: "2026-07-18"
---

<!-- 3-way comparative research: steviee/git-issues vs remenoscodes/git-native-issue vs jim:issue.
     Comparison task — structured for scannability rather than the feature-research template. -->

# Research: Git-Native Issue Trackers — 3-Way Comparison (git-issues vs git-native-issue vs jim:issue)

**Bottom line up front.** The three tools split across **two storage philosophies**, and that split — not the implementation language — is the real story:

- **Camp A — working-tree markdown files** (human-readable, git-diffable, browsable without the tool): **`steviee/git-issues`** (Go) and **`jim:issue`** (bash + LLM).
- **Camp B — issues in `refs/`, as git commit-chains** (merge-proof, distributed, but invisible in the working tree): **`remenoscodes/git-native-issue`** (99.8% shell).

Two facts reshape the earlier (2-way) conclusions: (1) jim:issue was *consciously forked from git-issues* — spec 017 studied it as Tier-1 prior art, adopted its schema, and **deliberately deferred its workflow verbs** (017 `research.md:44-55`); and (2) **git-native-issue proves the harder git-objects model is fully doable in pure shell** (99.8% shell, 284 tests) — which settles "could a git-native tracker be written in bash?" decisively: yes, even the ref-based design. That, in turn, removes almost all of git-issues' Go rationale.

## The three tools at a glance

| | **git-issues** (steviee) | **git-native-issue** (remenoscodes) | **jim:issue** |
|---|---|---|---|
| Language | Go | **Shell (99.8%)** | Bash + POSIX (+ LLM prompt layer) |
| Storage | `.issues/NNNN-slug.md` working-tree files | **`refs/issues/<uuid>` commit-chains + git trailers** | `docs/issues/YYYYMMDD-slug.md` working-tree files |
| Readable without the tool | ✅ `cat`/diff/PR-review | ❌ needs `git issue show` / `git log refs/issues/*` | ✅ `cat`/diff/PR-review + materialized `INDEX.md` |
| ID scheme | sequential `0001` | **UUID** (zero-coordination) | date-slug + display `num` ordinal |
| Merge behavior | collides on branches → "new issues on main only" | **refs never touch code merges; explicit `git issue merge` (CRDT-ish)** | collision-tolerant files; `INDEX.md` can conflict |
| Aimed at AI agents | ✅ ("Iron Workflow") | ✅ (structured metadata for agents) | ✅ (native to the jim SDLC) |
| Distribution | `go install` binary | shell install (brew/script/make) | Claude Code plugin (no deps) |

## 3-way capability matrix

Legend: ✅ has it · ⚠️ partial/adjacent · ❌ absent.

| Capability | git-issues | git-native-issue | jim:issue | Notes |
|---|---|---|---|---|
| **Typed relations + dependency graph** | ✅ (blocks/depends-on/related-to/duplicates, `graph`) | ❌ ("potential future") | ✅ (same 4 types + INDEX.md Graph + wikilinks) | jim & git-issues win; **git-native-issue has no relations** |
| **Comments / threaded discussion** | ❌ | ✅ (comments = commit messages) | ❌ (edit the body) | **both file-based tools lack this** |
| **Full-text search** | ❌ | ✅ `git issue search` (titles/bodies/comments) | ❌ (list/show only) | git-native-issue only |
| **Platform bridges (import/export/sync)** | ⚠️ GitHub import only | ✅ GitHub+GitLab+Gitea+Forgejo, bidirectional, `Provider-ID` dedupe | ❌ | the git-bug "bridges" model 017 reserved for the future |
| **Lifecycle states** | open/in-progress/closed | open/in-progress/closed | **open/closed only** | jim is binary by choice (PM non-goal) |
| **Assignee / milestone** | ❌ | ✅ | ❌ | jim disclaims (team-coordination non-goal) |
| **Deterministic "next"/blocked** | ✅ `next`/`blocked` | ⚠️ filter by state/priority | ⚠️ `insights` (LLM) + `stats` blocking rank | jim has the graph data, no deterministic verb |
| **Integrity validation** | ✅ `check` | ✅ `fsck` (UUID/trailers/tree) | ✅ INDEX.md Integrity Warnings | all three |
| **Conversation-native capture w/ judgment** | ❌ (`new --title …`) | ❌ (`create <title>`) | ✅ **`add` drafts from context + actionability gate** | jim's core differentiator |
| **Auto candidate capture across SDLC** | ❌ | ❌ | ✅ (7 skills, end-of-phase batches) | jim only |
| **`origin` provenance + lint** | ❌ | ⚠️ `Provider-ID` (platform, not artifact) | ✅ (which spec/plan/research surfaced it) | jim's "discovery artifact" identity |
| **LLM analytical view** | ❌ | ❌ | ✅ `insights` (convergence/sequencing/parallel) | jim only |
| **Configurable ID scheme** | ❌ (fixed sequential) | ❌ (fixed UUID) | ✅ date/sequential/project/timestamp + template (021) | jim is the *most* configurable on naming |
| **Fileable-bar filtering** | ❌ | ❌ | ✅ (Resolution/Actionability/Pipeline-ownership) | jim keeps the collection honest |
| **Injection-hardened for LLM content** | n/a (not LLM-interpreted) | n/a | ✅ (untrusted-wrapping, no source/eval, capability-backed insights) | jim *needs* it |
| **Explicit large-scale design** | ❌ (flat-dir rescan) | ✅ **"10,000+ via `git for-each-ref`"** | ⚠️ flat-dir + staleness-gated index | see Scalability |

### Reading the matrix

- **jim + git-issues share a data model** (typed relations, graph, human-readable files) that **git-native-issue lacks** (no relations, no working-tree files).
- **git-native-issue leads on distributed/collaboration features** (comments, full-text search, 4-platform bridges, merge-proof refs, 10k-scale) that **both file-based tools lack**.
- **jim uniquely owns the discovery/LLM layer** (conversation capture, candidate batches, origin, insights, fileable bar, injection hardening) — none of which either external tool attempts. This is jim's moat and it sits *on top of* whichever storage model you pick.

## Storage, naming & scalability (the central axis)

**Three ID/collision strategies, escalating in merge-safety:**
1. **git-issues — sequential `0001`.** Human-sortable, but two branches both mint `0042` → merge collision. Mitigation: *"new issues only on main."* Worst for parallel/agentic work.
2. **jim — `YYYYMMDD-slug` + `num`.** Collision-tolerant working-tree files (distinct slugs; `-2`/`-3` discriminator; no main-only rule). Cost: no monotonic id order → recovered via a separate `num` ordinal + second-resolution timestamps (022). Middle ground.
3. **git-native-issue — UUID in `refs/`.** Zero coordination, and code merges *never touch issues* because they live outside the working tree; divergence is reconciled by an explicit `git issue merge` with field-level rules (last-writer-wins scalars, set-merge labels, union comments). Best merge-safety — at the cost of human readability.

**Organization & scale.** git-issues and jim are **flat single directories** that rescan to build views (jim adds a staleness-gated index so an unchanged collection costs a `stat`, not a rescan). Neither shards; fine at jim's target scale (hundreds of discovery artifacts/project). **git-native-issue explicitly targets 10,000+** because `git for-each-ref` is one batch op, not a subprocess-per-issue — a genuinely more scalable substrate, relevant only at scales jim doesn't target.

**The readability trade-off is the crux.** jim's 017 research *explicitly rejected* the git-objects model (git-bug) because it "loses human readability without the tool." git-native-issue is that rejected model, well-executed: you cannot `cat` an issue or see it in a PR diff without `git issue show`. jim materializes the opposite bet — a committed, browsable `INDEX.md` — which is exactly what makes jimui's Board possible.

## Templates & custom fields

| | Template system? | Custom fields? | Can it emit jim's template? |
|---|---|---|---|
| git-issues | ❌ (schema compiled into Go binary) | ❌ | ❌ |
| git-native-issue | ❌ (fields fixed by `ISSUE-FORMAT.md` / `Format-Version` trailer) | ⚠️ arbitrary trailers technically possible, but not a template mechanism | ❌ (trailers, not frontmatter — `num`/`origin` wouldn't map) |
| jim:issue | ✅ fixed template single-sourced through `new.sh` | ❌ (only id-prefix scheme is configurable) | — |

Neither external tool has a template hook, and **neither can be pointed at jim's template.** git-native-issue is the furthest — it doesn't even use YAML frontmatter (metadata is git trailers on a commit), so files aren't mutually readable with jim/git-issues at all.

## "Could a git-native tracker be pure bash?" — answered

**Yes, decisively — git-native-issue is the proof.** It implements the *harder* refs/commit-chain model, distributed merge, 4-platform bridges, full-text search, and `fsck`, entirely in shell (99.8%), with 284 tests across 8 categories. jim already independently proves the *file-based* half (frontmatter parsing without a YAML lib, atomic writes, graph edges, integrity checks in `index.sh`/`render.sh`).

**Consequence for the Go question:** git-issues' Go implementation buys **single-binary distribution, `$EDITOR`/TUI, Windows portability, and raw speed at huge scale** — and *nothing else functional that a shell tool can't do* (git-native-issue does strictly more, in shell). For jim's context — runs inside Claude Code where bash is always present, modest issue counts, no-new-deps mandate — the Go advantages are irrelevant.

**What jim would add for deterministic parity with the file-based feature set** is small and on-philosophy: a `render.sh next`/`blocked` read arm (020's `insights-graph` already emits `ISOLATED`/`BLOCKING`), convenience `close`/`reopen` verbs. The features jim *lacks vs git-native-issue* (comments, full-text search, bridges, refs storage) are a different, larger philosophical commitment — see below.

## Recommendations

**1. Do NOT adopt either tool as a runtime backend. Build/extend in jim's bash layer.** Reasons, in order:
- **Architecture.** git-issues (Go binary) breaks jim's bash/POSIX/no-deps plugin model outright. git-native-issue is bash — but its **refs-based storage reverses 017's deliberate, documented human-readability decision** and would make jim's issues invisible in the working tree and PR diffs (and unavailable to jimui's file-reading daemon without shelling into git plumbing).
- **Both replace only the layer jim already owns** (deterministic storage/query) while none of jim's actual value — conversation capture, candidate batches, origin, insights, fileable bar, injection hardening — comes from either. Net capability gain ≈ 0; net cost = a dependency + a reversed architecture decision.
- **git-native-issue also *lacks jim's relations/graph*** — jim would regress on its own core feature to gain comments/bridges it has explicitly disclaimed (assignee/milestone are on the PM non-goal list).

**2. git-native-issue is the more interesting *study* target — and the better *future-backend candidate* IF distribution ever changes.** It is a concrete, tested realization of the git-bug "bridges + git-objects" model that 017 reserved for the future. If jim ever needs true offline-distributed, multi-developer, multi-platform issue sync, its `refs/issues` + `Provider-ID` bridge design is the reference architecture — and being shell, it's studyable line-by-line. Today that need doesn't exist (jim is single-developer, VISION §Non-Goals), so this is a *watch-list* item, not a plan.

**3. Cherry-pick selectively — and stay inside the PM non-goal.** Safe, on-philosophy pulls: `next`/`blocked` as **read/analysis** conveniences (same family as `insights`); git-native-issue's **`fsck`-style deeper integrity check** and its **`for-each-ref`-style batch mindset** if jim's collections ever grow. Avoid: `claim`/`done`/`in-progress` lifecycle, assignee, milestone — these drift jim toward the project-management/ticketing role VISION explicitly disclaims. Comments and full-text search are plausible *someday* adds but are net-new surface, not parity gaps.

**4. Route the visual/traversal/collaboration ideas into jimui.** jimui's VISION already wants a Board with an **Inbox lane for untriaged issues**, Epics with % complete, and a Specs/Issues browser — a single-binary daemon reading/writing jim's markdown in place ("not a second source of truth"). That is the home for git-issues' `graph`/`next` UX **and** git-native-issue's search/board affordances — built **over jim's materialized markdown + INDEX.md**. Note the hard constraint: jimui reads *files*, so it depends on jim staying in Camp A. Adopting git-native-issue's refs model would *break* jimui's premise — another reason to stay file-based.

## Anchors & test template (for any follow-on build)

- `skills/issue/SKILL.md` (capture/read verbs, actionability gate, §7a fileable bar); `skills/issue/scripts/{new,index,render}.sh` (emitter, parser/graph, read dispatcher); `skills/issue/assets/issue-template.md` (fixed schema); `docs/specs/jim/017-issue-tracking/research.md` (where git-issues was tiered & Option C chosen); `../jimui/VISION.md` (Board/Inbox target).
- **Test template:** `tests/issues.sh` is the per-script suite (sources `skills/meta-test/scripts/testlib.sh`; `OUT=$(...)` capture, `set -uo pipefail`, `--dir` override). A `render.sh next`/`blocked` arm adds cases here — scaffold via `/jim:meta-test scaffold`.

## Peer Feedback

- **For PM / jimui direction:** two external tools now bracket jimui's design space — git-issues shows the file+board UX, git-native-issue shows the distributed/search/bridge ceiling. Both are worth a focused UX/architecture read before jimui's Phase-1 spec. Key constraint to lock: **jimui's file-reading premise commits jim to Camp A (working-tree markdown)** — worth stating explicitly so a future "adopt refs storage" idea is evaluated against it.
- **For a future jim:issue spec (optional, low urgency):** a deterministic `next`/`blocked` read pair remains a cheap, on-philosophy extension. git-native-issue additionally surfaces two *watch-list* questions — (a) do jim collections ever reach a scale where `for-each-ref`-style batching matters, and (b) is offline-distributed multi-dev sync ever in scope? Both are product decisions, not gaps; flagged, not recommended.
