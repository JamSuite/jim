---
id: 20260728-spec-issue-placement-config-for-issue-content-location
num: 126
title: "Spec issue_placement config for issue content location"
status: open
priority: medium
labels: [id-coordination, issue]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-28T00:47:22Z
updated: 2026-07-28T00:47:22Z
origin: docs/specs/issue/010-ordinal-coordination/spec.md
---

## Description

`issue/010` (coordinated issue display ordinals) coordinates issue *ids*
through the allocator but explicitly defers `issue_placement` — where a filed
issue's *content* lives.

Today issue files ride the working branch under `docs/issues/` and appear in
`INDEX.md` per branch. The id-coordination brainstorm
(`docs/brainstorms/20260724-id-coordination.md`) framed issues as cross-branch
discovery artifacts that could be centralized:

- `issue_placement = content` — the whole issue file is committed to a shared
  destination at filing time, so feature branches stop carrying issue files and
  INDEX conflicts vanish; but every filing becomes a central commit and a
  branch-filed issue may reference artifacts absent on the destination.
- `issue_placement = reservation` — only the id reservation lands centrally; the
  issue body stays on the feature branch until merge.

Scope for the follow-on spec:

- Decide the destination model (dedicated central branch vs main vs
  stay-on-branch) and how it interacts with the coordination branch, which per
  `platform/007` holds only registry logs and no issue/spec content.
- Introduce the `issue_placement` config key (does not exist in `jimconf.sh`
  yet) and its read-from-current-branch semantics.
- Weigh the disclosure surface: centralizing content publishes issue bodies
  earlier and more widely than today's on-branch-until-merge behavior.
- Reconcile with the VISION non-goal that issue capture is a discovery artifact
  surfaced during the workflow, not a team-coordination primitive.

Follow-on to `issue/010`, where it was deferred as out of scope.
