---
id: 20260725-cross-group-enforcement-of-plugin-wide-convention-invariants
num: 97
title: "cross-group enforcement of plugin-wide convention invariants"
status: open
priority: medium
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:39Z
updated: 2026-07-25T08:04:39Z
origin: BLUEPRINT.md
---

## Description

The eight plugin-wide authoring-convention invariants (plugin-name, name-matches-path, allowed-tools-exact, injection-set-rhs, sentinel-vocab, sigil-discipline, skill-budget, untrusted-content) are primary-owned by the sdlc group's blueprint, but they bind every group's skills and agents. `/jim:verify sdlc` scopes checks to sdlc territory, so blueprint/issue/platform skill content is unverified against them.

Options: author a cross-group boundary contract (per-side invariants under one family), duplicate the critical rows per child blueprint, or extend verify with a project-wide scope class. Decide once and apply through the blueprint surface.
