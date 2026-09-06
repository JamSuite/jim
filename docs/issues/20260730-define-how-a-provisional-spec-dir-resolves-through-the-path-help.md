---
id: 20260730-define-how-a-provisional-spec-dir-resolves-through-the-path-help
num: 146
title: "Define how a provisional spec dir resolves through the path helper"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, jimfile]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-30T10:55:21Z
updated: 2026-07-31T12:40:00Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

## Description

`jimfile.sh cmd_path` composes a spec-family path as
`<specs>/<group>/<id>-<name>/<kind>.md`. A provisional spec's directory
basename is the *whole* reserved token (`P-<date>-<slug>`) — there is no
separate ordinal and name to compose — so a caller passing that spec's
frontmatter `id:` plus its slug resolves

    <specs>/<group>/P-20260728-alpha-alpha/plan.md

a directory that does not exist. The composition happens to work only if the
caller splits the token into `P-<date>` and `<slug>`, which nothing documents
and no fixture covers.

Five call sites resolve paths this way, not three (widened 2026-07-30 by the
review's second pass):

- `skills/spec/SKILL.md:231` — the provisional branch's own write path, so the
  spec file can land outside the directory Step 8 just created;
- `skills/plan/SKILL.md:120` — with `Bash(mkdir *)` and `Write` granted, so the
  fabricated directory gets created;
- `skills/research/SKILL.md:38` — auto-spawned by `/jim:plan` Step 3, so this
  one fires **unattended**;
- `skills/plan/assets/plan-template.md:3` — bakes `{id}-{name}` into a
  *persisted* machine-read back-reference, so the wrong path is durable rather
  than transient;
- and `cmd_path` itself (`skills/file/scripts/jimfile.sh:783-791`), which
  composes the path with **no validation of `id` or `name`** and requires all
  three arguments — there is no correct way to call it on the provisional
  branch, so a caller must invent a `<name>`.

In practice the later stages are usually invoked *with* the spec directory and
would write into it, which is why the build's tests never caught this — but it
leaves `sdlc/017` AC 5's "the downstream stages run against it unchanged"
unearned rather than satisfied, and the unattended research spawn is not covered
by "usually".

Two candidate resolutions:

- **Teach `cmd_path` a provisional form** — accept the token as the entire
  basename, mirroring the three-argument form `mv-spec-id` already grew for the
  same reason. Keeps callers uniform: pass the identity, get the path.
- **Or state that a provisional spec's paths are read from the directory, never
  composed**, and say so in each skill body that resolves one.

The first is preferable if any caller genuinely composes rather than receives a
path — and it should **validate `id` and `name`** while it is there, which the
current composition does not. Fix `plan-template.md` either way. Cover the
provisional shape with a fixture; none exists anywhere. The gap survived a full
build and a green 903-case suite precisely because nothing asserts it.

Surfaced by `sdlc/017`'s post-build review. Raised to `critical` and widened
from three call sites to five on 2026-07-30, when the review's investigated
second pass superseded its first — the unattended `/jim:research` spawn and the
persisted template back-reference are what changed the severity.
