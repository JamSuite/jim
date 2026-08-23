---
id: 20260726-document-coordination-branch-protection-and-team-setup
num: 118
title: "Document coordination-branch protection and team setup"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [id-coordination, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T19:02:03Z
updated: 2026-07-26T19:02:03Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

The allocator needs push rights to the coordination branch for everyone running jim, which is a team-setup story the docs must cover.

Document:
- The coordination branch wants an unusual **middle** protection profile — direct pushes allowed, force-push and deletion denied (this pairs with the G3 erosion guard `platform/007` ships).
- Everyone running jim needs write access to the coordination branch, even when `main` is protected. Protecting `main` while leaving `jim/registry` writable is the expected setup.
- IDs must never serve as authorization or integrity anchors: the coordination branch is typically *less* protected than `main`.

Follow-on to `platform/007` (foundation); user-facing setup docs (README / WORKFLOW.md).
