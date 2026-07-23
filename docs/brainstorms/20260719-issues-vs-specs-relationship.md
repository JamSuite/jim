# Brainstorm: The relationship between issues and specs in jim

*2026-07-19*

## 1. The question

Claude Code, across several conversations, keeps telling the user the same thing after
reading jim's issue spec + skill + README + WORKFLOW: **the main unit of work in jim is the
spec, not the issue.** It reads the current issue implementation as a way to capture
*follow-on* work — not the primary work-item of the SDLC.

Two asks:
1. Find the evidence in-repo for why Claude Code reaches that conclusion.
2. Do I agree — or do I see it differently? What *is* the issue↔spec relationship?

## 2. The answer: the spec is the main unit of work, not the issue

Claude Code is right, and it isn't guessing — the repo states this design intent explicitly
and repeatedly. That's the easy half of the answer. The rest of this doc is the harder half:
*why* jim is built this way, the one real gap in the design, and whether that gap is a bug or
a deliberate choice.

### The evidence in the repo

It's not a subtle inference. Four artifacts say it in near-plain language:

1. **VISION.md § Non-Goals** — *"Not a project management tool. … Issue capture is in scope —
   but only as a discovery artifact surfaced during the jim workflow and saved for later
   analysis, not as a team-coordination primitive."* And separately, *"Teams that need a
   project management system (Jira, Linear, etc.)"* are listed under "Not for." This is the
   root instruction; everything downstream inherits it.

2. **README + WORKFLOW** — the whole product is three verbs: `/jim:spec → /jim:plan →
   /jim:build`. WORKFLOW's SDLC diagram runs BRAINSTORM → SPEC → PLAN → BUILD; issues aren't
   on that path at all. The Artifacts table calls issues *"Discovery artifacts surfaced during
   the workflow"* and specs *"Work definition — requirements, acceptance criteria."* One is
   the work; the other is a note about the work.

3. **skills/issue/SKILL.md** — the definition is explicit: *"An issue captures an actionable
   discovery — pending, unresolved work surfaced during the jim workflow … a discovery
   artifact in the VISION sense … not a Jira-style team-coordination ticket."* The whole skill
   is capture plus read-only review (`list`/`stats`/`show`/`insights`). There is no execution
   verb — no `/jim:issue build` or `/jim:issue start`. Doing the work lives in spec→plan→build,
   not in the issue.

4. **Spec 017 § Problem Statement** — the origin: *"During spec → research → plan → build
   workflows, developers and agents surface bits of work that are out of scope for the current
   task but worth saving."* Issues were defined, from the start, as a place to hold
   **out-of-scope** discoveries — defined relative to whatever spec is currently in focus.

So Claude Code isn't interpreting — it's reporting jim's stated design. On the factual
question, I agree completely.

### jim reverses the usual issue-tracker model

In Jira / Linear / GitHub Issues, the **issue is the unit of work** — the ticket you assign,
estimate, move across a board, and close when the work ships. Specs, if they exist, are
attachments on a ticket.

jim reverses this. The **spec is the unit of work**; the issue is a lightweight capture that
feeds into specs. jim is spec-driven, not ticket-driven, so the artifact that carries
requirements, acceptance criteria, and a lifecycle (draft → approved → planned → built) is the
spec. The issue carries none of that — just an `open`/`closed` status, no plan, no ACs, no
build.

This reversal is why the confusion keeps recurring. The word "issue" carries the GitHub/Jira
meaning — issue = primary work unit — and jim uses it to mean nearly the opposite. Anyone who
brings the industry meaning to the word will trip. **The name fights the concept.**

### The issue exists to keep the spec focused

The useful way to read the design: issues exist *so specs can stay narrow.* Spec 017's premise
is scope discipline — you're mid-plan on spec X, you notice something real but off-topic, and
you have two bad options: chase it now and derail the current spec, or lose it when the session
ends. The issue is the third option — save it without acting on it, so you can hold the current
spec's boundary without losing what you noticed.

Read that way, "issues aren't the main work item" isn't a limitation, it's the point. If issues
*were* the main work item, they'd pull scope back in and jim would just be Jira with markdown
files.

### One-sentence summary

> A **spec** is committed, in-focus work with a full lifecycle. An **issue** is
> noticed-but-deferred intent, with no lifecycle beyond open/closed. The spec is the current
> scope; the issue is something deliberately left outside it — saved so it isn't lost, not
> queued to be worked.

Issues and specs aren't two sizes of the same thing (big ticket / small ticket). They're
different kinds of object: one is work, the other is a record of a decision to defer work.
That's why the "main unit" question has a clean answer — they aren't competing for the title.

## 3. The gap: an issue cannot turn into a spec

There is exactly one place the design feels incomplete, and it's the same thing the user's
unease keeps circling:

- **Provenance runs backward only.** An issue records `origin` — the spec/plan/brainstorm it
  came *from*. There is no forward pointer: when an issue later becomes real work, nothing
  records which spec addressed it.
- **There is no issue→spec promotion.** The lifecycle is `open`/`closed`, and closing is a
  plain file edit. An issue that represents genuine follow-on work has two possible fates: a
  human reads it and re-writes it as a spec by hand (with no link back), or it just gets
  closed. There is no `/jim:spec --from-issue <id>`, and no lineage recorded when it closes.

So work flows one way: spec → issue. The return leg — issue → spec — doesn't exist.

Is that a bug, or a deliberate boundary? I checked three things, and all three point to
**deliberate**.

### Deliberate from the start: the VISION note

The VISION sentence that scopes issues as capture-only was added in its own commit, `3bfaa1e`
(2026-05-30 11:34:32 UTC, jrko), touching VISION.md only. It rewrote the "Not a project
management tool" non-goal to *append* the discovery-artifact carve-out. Its commit message:
*"Frames spec 017 (issue tracking v1) within the vision."* It landed **13 seconds before**
`39c9d68`, which committed spec 017's spec.md, brainstorm, and research together. So the
capture-only scope was written down to bound the feature *before* the feature was committed —
not something that emerged later. (It traces to spec 017, not to any plan.md. Later touch-ups
adjusted the surrounding bullet slightly, but the quoted sentence is verbatim from `3bfaa1e`.)

### Held across nine specs

017 was the first issue spec; eight follow-ons came after (017–025).

| Spec | Type | What changed | Nature |
|------|------|--------------|--------|
| 017 issue-tracking | feature | local-files ad-hoc capture (birth) | birth |
| 018 workflow-integration | feature | auto-surface candidate batch at end of each phase | **conceptual** |
| 019 command-consolidation | feature | merge `/jim:issue` + `/jim:issues` into subcommands | UX |
| 020 insights | feature | read-only LLM-analytical view | feature growth |
| 021 id-prefix | feature | configurable id prefix schemes | plumbing |
| 022 timestamp-fidelity | feature | second-resolution created/updated timestamps | plumbing |
| 023 id-rederive | feature | re-derive existing ids to active scheme | plumbing |
| 024 pipeline-ownership | **bug** | *stop* filing work jim's pipeline auto-performs | **conceptual** |
| 025 candidate-batch-extraction | refactor | single-source the fileable-bar contract | refactor |

Of the eight follow-ons, only two changed what an issue *is* or how it fits the workflow — 018
and 024. The other six are mechanical (renaming commands, id formats, timestamps, a refactor).
And the two that matter both pull the same way: **save fewer issues, more deliberately.**

- **018** connected capture to the workflow, but put you in the role of filter — jim
  over-suggests and you drop most suggestions before any are saved.
- **024** was a *bug*: the end-of-phase suggestions were proposing work jim's pipeline already
  does automatically. The fix made jim suggest even less.

Across all nine specs, three things never changed: (1) lifecycle stayed `open`/`closed`; (2) no
promotion verb ever appeared; (3) provenance stayed backward-only. Nine specs of active work,
and the return leg was never added — most tellingly not in 018, where it would have fit most
naturally.

### Deferred on purpose in spec 018

018 is the spec that wired capture into the workflow, so it's where a promotion path would have
gone. An issue system can connect to a workflow two ways:

- **Issue → work (promotion):** the workflow reads *from* the issue list — "here are open
  issues relevant to this spec, pull any in?", or a command that turns issue #14 into a spec.
  This is how a Jira/Linear backlog feeds work.
- **Work → issue (capture):** the workflow writes *into* the issue list — each phase saves the
  discoveries it noticed.

018 built only the second. Its data flow runs one way — `skill → collect → show → save` — and
nothing reads back out into spec/plan/build. And it named the reverse directly in Out of Scope:
*"…any automatic transitions (e.g., 'filing a spec for an open issue moves it to in-progress')
— deferred to a separate 'issue lifecycle / cross-phase state' spec."* "Deferred" plus a named
future spec means jrko saw the issue→work path and postponed it — not rejected it.

### Conclusion: deliberate but deferred, not forbidden

The capture-only boundary is a real design choice, held from the VISION line through nine
specs. But 018's wording matters: promotion is **deferred to a future spec**, not ruled out.
jrko treats the return leg as real future work, just not built yet.

## 4. The fix: let an issue turn into a spec

The deferred issue→spec path is worth building. But the shape it should take isn't a
promotion *verb* — it's two smaller moves plus one new artifact. This section captures the
direction settled on 2026-07-19.

### How this is done by hand today

His email describes the flow plainly: `/jim:issue list → /jim:issue show N →` one of *"spec it
out"* / *"implement, no spec"* / *"expand the issue"*. He notes the issue *"usually carries a
decent context already, so the spec process tends to move a bit faster."* Read literally: **the
issue is the prompt, and `show N` is the promotion.** Running `show N` first drops the issue
into the conversation; *"spec it out"* then lets the PM agent pick that context up. He never
codified a promotion verb because the context-carry already does the work — he just does it
manually every time. That's not a missing feature so much as an un-automated habit.

### What the tooling allows today

- **`/jim:issue` has a real by-number lookup.** `skills/issue/SKILL.md` step 1: `show` resolves
  its token as *"an ordinal number, a slug, or a slug prefix."* So `/jim:issue #13` → "show 13"
  is a spec'd contract, not luck. The read side already supports pulling one issue into focus.
- **`/jim:spec` only knows the *outbound* half.** The spec skill touches issues in exactly one
  direction — Step 11 surfaces *candidate* issues to *file* (work → issue). Its `allowed-tools`
  carries `issue/scripts/index.sh` (list) and `new.sh` (write) but **not** `render.sh show`. It
  cannot read a specific issue in. The inbound path is absent at the tooling layer, not just
  conceptually. This is the "one real gap" above, confirmed in the manifest.

### Change 1: let `/jim:spec` read an issue in

A flag is ceremony for something natural language already does. An issue should be able to
enter spec context three ways, in increasing explicitness — none of them a flag:

1. **Already in context** — you ran `show N` first (jrko's flow). Spec just uses it.
2. **Named** — "spec the issue about X," or a pasted `docs/issues/….md` path. Unambiguous.
3. **Proactively offered** — spec searches open issues and surfaces relevant ones.

`--from-issue <id>` is strictly worse than all three: it's the only one that adds ceremony to a
thing the interview can already absorb. Skip it. (The spec skill would need `render.sh show`
added to its `allowed-tools` to read a named/searched issue — a one-line manifest change.)

The caveat on option 3: spec's job is to *narrow* scope, and issues exist to *protect* that
focus. Auto-*pulling* issues would invert the design. So spec must **offer, not absorb** — "3
open issues look related to this spec; pull any in?" — leaving you as the filter, exactly the
posture 018 gave the candidate-batch surface (jim over-suggests, human drops most). And the
moment an issue *is* pulled in is the natural place to record the **forward edge** (the spec
notes "Addresses #14"), which closes the backward-only-provenance hole at no extra cost.

### Change 2: add `/jim:epic` to group and order issues

Bigger than promoting one issue: the strategy of deciding *which* specs to write, in what
order, is a real and currently-homeless activity. Naming it after scrum/agile, an **epic** is a
titled goal + an ordered list of the specs we intend to write, with dependencies noted so
dependent items come first. It lives at `docs/epics/` and sits in the genuine gap between
ROADMAP (whole-project Now/Next/Later buckets) and spec (a single work item).

The elegant part: **the epic is the deferred "issue lifecycle / cross-phase state" mechanism
018 postponed** — without mutating the issue. Keep issues capture-only and open/closed. The
epic becomes the layer that *reads* the discovery pile, decides which issues graduate, orders
them, records deps, and links issue #14 → spec 026. Promotion lives in the epic, not in a
promotion verb bolted onto the issue. This preserves the entire existing design (issues protect
spec focus; no execution verb; backward-only lifecycle stays simple) and fills the
institutional-memory hole the backward-only graph left — the forward edge now has a home.

One fork to decide when this gets specced: whether epic *members* are issues (reuse the
primitive — the lean) or a distinct new object. Reuse risks nudging "issue" back toward
"backlog ticket" (the naming collision this whole doc traces). The framing guard that holds the
line: **an epic sequences existing discoveries; it does not turn issues into a backlog.** The
issue stays a noticed-and-deferred discovery; the epic is the curation view that decides which
discoveries are worth graduating and when.

### Does this make jim a project management tool?

The honest answer: it drifts *toward* the line, but doesn't cross the one the VISION actually
cares about. That line is **team coordination** — assignment, boards, sprints, estimation,
multi-person status. Jira/Linear coordinate *people*. An epic as scoped here sequences *your
own work* — and jim already does exactly that at the ROADMAP level. Epic is finer-grained
roadmapping, not a new category of tool.

So the VISION doesn't need to retreat — it needs the same move it already made for issues.
`3bfaa1e` didn't delete "Not a project management tool"; it *appended* a carve-out scoping
issues as in-bounds ("a discovery artifact … not a team-coordination primitive"). Epics want
the parallel carve-out: sharpen the non-goal to name what's actually excluded (team
coordination — assignment, boards, sprints, estimation) and affirm what's included
(single-author strategic sequencing: vision → roadmap → epics → specs). The through-line is
"jim organizes *one author's* SDLC, never *a team's* coordination." Epics fit inside that; a
sprint board never will.

### Does this make the issue the main unit of work?

Worth stating plainly, because it's the natural next question: after all four moves ship, would
Claude Code stop reading "spec is the unit of work"? No — and the plan is built to keep it that
way. The moves make the issue an *input* to the spec (Moves 1–2) and give promotion a home that
*isn't* the issue (Move 3). None of them adds an execution verb to the issue — there is still
no `/jim:issue build`, no ACs, no lifecycle beyond open/closed. The one path that *would* make
the issue a unit of work — issue → build with no spec (jrko's "implement, no spec" shortcut) —
is deliberately **not** codified here; that door is the one the VISION non-goal keeps shut.

What changes is not the unit of work but the *character* of the split. Today it reads as "the
one real gap" — issue as dead-end, backward-only provenance. After the plan it reads as a
deliberate three-tier layering with a forward path:

| Tier | Role | Skill behavior | Gets built? |
|------|------|----------------|-------------|
| **Epic** | strategic sequencing — which specs, in what order | *new* — groups + orders issues into a spec plan | no (like ROADMAP) |
| **Spec** | **the unit of work** — requirements, ACs, lifecycle | **smarter** — now ingests a named issue and *offers* relevant ones while scoping | yes |
| **Issue** | discovery input — noticed-and-deferred | unchanged — capture + read; open/closed | no |

The distinction the table makes explicit — and that a bare "Spec: unchanged" hides: the spec's
**role** (the unit of work) doesn't move, but the spec **skill** changes materially. It stops
being blind to issues. Same position in the hierarchy; a meaningfully more capable tool. Those
two facts aren't in tension — the first is about the artifact, the second about the command.

## 5. Chores: work done without a spec

A later pass (2026-07-19) pushed on the "issue → build with no spec" path the three-tier model
had set aside — and it turned out to be the common case, not the edge case. This section
captures the ideas raised, what the current schema actually supports, and the suggestions that
came out of it.

### Most issues are chores

The path the three-tier model waved off — issue straight to implementation, no spec — has a
better name than "issue → build": a **chore**. A chore is a small piece of work you start in a
fresh Claude Code plan-mode session and implement without a spec, never touching `/jim:build`.
Which jim skills get used, if any, is ad-hoc / à la carte — often it's just plain plan-mode
Claude Code.

The empirical claim that reframes everything: **most issues are chores.** If that's true, then
"the spec is *the* unit of work" is too absolute. jim actually has **two grades of work**:

- **Chore** — the *issue* is the unit of work. No spec, done ad-hoc in plan mode. jim captures
  it, then **abandons it at execution**: no in-process state, no record of where the work
  happened, closure is a manual flip of a field.
- **Spec** — the *spec* is the unit of work. Full lifecycle, ACs, plan, build.

So the issue *already is* a unit of work for the majority case — jim just never tracked it as
one. That's the correction to the top of this doc: the spec is the unit of work for
*spec-worthy* work, but a whole second grade (chores) is issue-native and has been running
untracked. The idea below isn't "make the issue a unit of work" — it's "**start tracking the
unit of work the issue already is.**"

One sub-thread named here but kept separate: chores that *correct an earlier spec* — surgical
edits to an existing spec plus its code — are work jim and Claude are reluctant to do (specs get
treated as write-once; the coder is conservative about editing shipped work). That's a real and
*distinct* problem from status tracking, and a good candidate to file as its own issue.

### The idea: track issue status in git

The proposal (raised as "something to consider" for `/jim:issue`): track issue **status** well
enough to know when something is *in process*, and — since the workflow is git-based — record
*where the work is happening* so an in-flight issue points at running work rather than sitting
as a dead note. Concretely:

- When an issue is promoted / picked up, the status change is recorded on the **main branch**.
- The issue records a **git branch name** (if a branch is used) and/or a **Claude Code session
  id** (if obtainable), stored in the issue on main.
- The issue is now **in process**: looking at it, you can follow the pointer to the work — a git
  branch and/or a session log — and see the work getting done.
- When a spec *is* created from the issue, a **back-reference to that spec** is written into the
  issue for tracking.

The thesis: with an in-process status and a mechanism to record where the work lives, **the jim
issue becomes a genuinely tracked unit of work.**

### What the issue schema supports today

Checked against `skills/issue/`:

- **Status is a hard binary.** The template ships `status: open`; `new.sh` validates
  `open|closed` and rejects anything else; `render.sh` carries `STATUS_TOKENS=(open closed)`. The
  lifecycle isn't just convention — it's *enforced at the writer*.
- **There is no close verb.** Closing is a *deliberate edit* (SKILL.md § 6a): an agent handed
  "close issue #5" opens the file, flips `status: open` → `status: closed`, and refreshes
  `updated` via the `jimfile.sh now` helper. Same for any other field change.
- **A `relations:` graph already exists** (`blocks` / `depends-on` / `related-to` /
  `duplicates`) and an `origin:` field (backward provenance). But there is **no assignee, no
  branch, and no session field** anywhere in the schema.

So adding in-process tracking touches three places at minimum: a new status token, new
work-location fields, and the writer/renderer that currently hard-code the binary.

### Does this make the issue a unit of work?

The reasoning holds. `status: in_progress` plus a pointer to where the work lives means an
in-flight issue is a live work item you can follow to running work — which is what a tracked
unit of work *is*. For the **chore grade** this closes the loop completely (the issue is the
work, now tracked end to end). For the **promoted grade** the issue becomes a *tracker/index*
pointing at the spec that carries the substance. Either way the issue graduates from "capture"
to "tracked work" — without gaining ACs or a build of its own, so the spec's role is untouched.

### Keep it a record, not an assignment board

The load-bearing fields are `status` + work-location (`branch` / `session`). Those are
**provenance** — "where did/does this work live" — which is squarely jim's institutional-memory
pitch, not team coordination. The field that flirts with the VISION line is **"assigned to."**
In a solo context, "assignee" collapses into "which branch/session owns this" — a *pointer*,
not a *board*. So model work-location as the primitive and treat a human-name assignee as
optional garnish. The test that keeps this on the right side of "not a project management tool":
a recorded **pointer** to where work happens is fine; an **assignment board** coordinating work
across people is the line. The day the assignee field grows a board is the day this becomes the
PM tool the VISION refuses.

### How to mark an issue "in process": options

How you'd set an issue *in process*, given that today's closure is a direct edit through a
deterministic helper:

- **A — lifecycle verbs (cleanest UX):** `/jim:issue start <id>` → `status: in_progress`, stamp a
  `started` time, record branch + session; `/jim:issue close <id>` → formalizes today's manual
  flip; `/jim:issue reopen <id>` → back to `open`. `start` can auto-grab the branch from
  `git branch --show-current` so there's nothing to type.
- **B — generic state setter (most deterministic):** `/jim:issue set <id> status=in_progress
  branch=feat/foo`. One verb, flexible, fits "bash owns state" — but less discoverable.
- **C — helper-only, no new verb (smallest change):** add a `status.sh <id> <new-status>
  [--branch X] [--session Y]` transition script and keep routing natural-language "start #13" /
  "close #5" through it. Bash stays the owner of the atomic write + validation.

**Recommendation: A on top of C** — a deterministic `status.sh` transition helper (atomic write,
stamps `updated`, validates the `open → in_progress → closed` transition) exposed through thin
`start` / `close` / `reopen` verbs. State-mutation stays deterministic (jim's bedrock); `start`
gets a natural home to capture branch/session. Note this *does* break the current "capture is
the only judgment verb; reads are deterministic" split by adding execution-adjacent verbs — a
real design decision, not a free addition.

### Notes for whoever builds this

- **Status column is `%-8s`** (`render.sh`). `in_progress` is 11 chars and breaks alignment —
  either pick a shorter token (`active`, `wip`) or widen the pad.
- **`new.sh` hard-rejects any status but `open|closed`** — the writer, not just the renderer,
  needs the new token.
- **Session id may come for free via the commit trailer.** This repo already stamps
  `Claude-Session: https://claude.ai/code/session_…` on commits. Store the *branch* and its
  commits transitively carry the session — so the session id may not need its own field except
  for uncommitted, in-flight work. Whether a skill can read its *own* live session id at runtime
  is the open question; the commit trailer is the reliable path.

### Recording the spec back onto the issue

When a spec is created from an issue, writing a reference back into the issue is exactly the
forward-lineage edge this doc has circled from the start. It fits the existing schema two ways:
a dedicated `spec:` field, or a new relation type (`promoted-to` / `addressed-by`) in the
`relations:` graph. That single write closes the backward-only-provenance / institutional-memory
hole — issue #14 → spec 026 becomes visible from the issue side, not just inferable from the
spec side.

## 6. Summary and next steps

**Two grades of work.** Chores are issue-native and currently untracked; specs are spec-native.
The issue is already the unit of work for chores — the goal is to track it, not to promote it.

**Changes to make:**

- **Do not build `--from-issue`.** Natural-language context plus a pasted issue path already
  cover it.
- **`/jim:spec` reads issues in.** Add `render.sh show` to its allowed-tools so it can read a
  named issue. Have it offer relevant open issues without pulling them in automatically. When an
  issue is pulled in, record the spec on that issue.
- **Add `/jim:epic`.** A new document type at `docs/epics/` that groups and orders issues into a
  planned sequence of specs. This is where an issue graduates to a spec.
- **Track in-process work.** Add a `status: in_progress` state plus branch and (optional) session
  fields, so an in-flight issue points at where the work is happening. Formalize status changes
  with a `status.sh` helper behind `start` / `close` / `reopen` verbs. Watch three things: the
  `open|closed` guard in `new.sh`, the 8-character status column in `render.sh`, and the
  session-id-via-commit-trailer path.
- **Record the spec on the issue.** When a spec is created from an issue, write the reference back
  (`spec:` field or a `promoted-to` relation). This is the missing forward link.
- **Update VISION.md.** Keep "not a project management tool," but add a carve-out for
  single-author sequencing (epics), the same way the earlier carve-out was added for issues. The
  line to hold: a record of where work happens is fine; an assignment board across people is not.

**To file as a separate issue:** jim and Claude are reluctant to surgically edit an existing spec
and its code. This is a distinct problem, worth its own issue.
