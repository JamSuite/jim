---
id: 20260623-configurable-commit-convention-for-git-dependent-skills
num: 13
title: "Configurable commit convention for git-dependent skills"
status: open
priority: medium
labels: [git, config, commit-convention, architecture]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-23T08:35:27Z
updated: 2026-06-23T08:35:27Z
origin: conversation
---

## Description

jim currently assumes its own commit convention, and that assumption is
becoming load-bearing as skills start reading git. This is presumptuous:
many teams adopting jim already have their own commit conventions, hooks,
and tooling, and jim shouldn't force its style on them as a precondition
of use.

**Current state.** The only commit discipline jim documents is the four
TDD-phase prefixes (`test`/`feat`/`fix`/`refactor`) in
`skills/build/references/tdd-guide.md` § 5. Anything richer — full header
rules, the wider Conventional Commits type set, scopes, trailers, Tidy
First as a general rule — is not jim's; it lives in each user's personal
config. Meanwhile `/jim:review` (via `jimledger.sh metrics`) now *decodes*
commit subjects by type to produce process metrics, so a mismatch between
the user's real convention and jim's assumptions silently degrades output
(the scoped-header undercount fixed in `fix(review): count scoped and
breaking commit headers` was one symptom).

**Why now.** `/jim:review` is jim's first git-dependent skill — new
territory — but likely not the last. Each future git-leveraging skill that
bakes in a fixed convention compounds the presumption and the drift.

**Proposed direction.** A jim config mechanism (joining the existing
`pre_commit` / `require_pre_commit` keys) that lets the user *choose* a
commit standard rather than inherit jim's, e.g.:

- a named standard (Conventional Commits, short or long form),
- a user-defined custom convention, or
- defer-to-host — honor whatever the project/user already does — with
  explicit caveats that deferring degrades jim features which parse commit
  structure (e.g. review's per-type metrics become best-effort or blank).

**Holistic ask.** Design *how git-dependent skills discover and honor the
configured convention* — a shared contract, not per-skill assumptions —
and how jim surfaces the trade-offs so the user can configure knowingly
(which features degrade under each choice). Fits VISION Phase 3
(configuration & integration).

**Action:** a future spec to (1) design the commit-convention config
surface and (2) define the contract git-dependent skills follow to read
and respect it.
