---
id: 20260808-neither-the-canonical-snippet-nor-the-sweep-binds-the-scrub-gate
num: 289
title: "Neither the canonical snippet nor the sweep binds the scrub gate"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-08T18:40:07Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

The auto-file scrub gate's entire coupling is one caller-supplied flag. The two
artifacts meant to carry that coupling — the canonical call-shape snippet and
the mechanical sweep — both fail to bind it.

## Gap 1 — the canonical snippet omits the flag

`skills/issue/SKILL.md:226-230` is billed as *the* emitter call shape, and the
group blueprint's Provides face declares "the emitter **call shape**, defined
once in this group's `SKILL.md`" as the guaranteed surface. It shows:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/new.sh \
  --title "<title>" --priority <p> --labels "<csv>" --origin "<origin>" --body-file "<tmp>"
```

No `--auto`, not even the optional `[--auto]` form a consumer already uses at
`skills/verify/SKILL.md:272`. The rule requiring the flag arrives three
paragraphs later at `:238`.

Given that omitting the flag is the **fail-open** direction (see the related
issue), the one artifact a consumer copies encodes the unsafe case.

## Gap 2 — the sweep proves mention, not handling

`tests/docsurfaces.sh:197-198`:

```bash
grep -q 'new\.sh \[\?--auto' "$f" || missing+="$name "
grep -q 'exit code 4'        "$f" || unhandled+="$name "
```

Both are **file-scoped, not branch-scoped**. A skill whose `--auto` sat on its
*interactive* emitter call while the auto path omitted it would pass. The second
grep proves the literal phrase appears somewhere in the file, not that anything
handles the code. Neither checks that the fallback target exists.

This is structurally the same weakness as the §7a pointer the previous review
faulted: proximity is asserted, binding is not.

## Gap 3 — the non-vacuity guard has slack

`tests/docsurfaces.sh:201-202` asserts `n >= 8` while the actual consumer count
is **9**. If any one skill stopped reading `auto_issue_file`, `n` falls to 8, the
guard still passes, and that skill leaves the sweep silently.

## Proposed action

- Add `--auto` (or `[--auto]` with the condition stated inline) to the §7a
  canonical snippet.
- Tighten the guard to `-eq 9`, or derive the expected count rather than
  hardcoding a floor.
- Make the sweep branch-scoped: extract each file's AUTO-FILE PATH block and
  assert the flag and the rc-4 handler within it, and that the named fallback
  target exists in the same file.

## Also

`skills/meta-skill/SKILL.md:98` — the checklist a new candidate-batch skill is
authored from — names the fileable bar and the emitter but says nothing about
`--auto` or rc 4, so a future auto-filing skill is caught only after the fact.

## Resolution (2026-08-11)

Fixed in `457c8d6`. The canonical § 7a snippet carries `[--auto]`, and the
docsurfaces sweep is scoped to each skill's auto-file branch rather than to its
file — so a `--auto` sitting on the interactive call no longer satisfies it. The
sweep also checks the fallback path it redirects to exists, and counts against
the real consumer total rather than one below it. Verify's restatement was
brought into the same shape as the other eight, which is what makes the branch
mechanically findable.
