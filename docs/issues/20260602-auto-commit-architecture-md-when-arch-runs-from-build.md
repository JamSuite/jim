---
num: 4
id: 20260602-auto-commit-architecture-md-when-arch-runs-from-build
title: "Auto-commit ARCHITECTURE.md when /jim:arch runs from /jim:build"
status: open
priority: low
labels: [arch, build, workflow, future]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-02T00:00:00Z
updated: 2026-06-02T00:00:00Z
origin: skills/build/SKILL.md
---

## Description

### The observation

Spec 018 WS-4 explicitly accommodates pending `ARCHITECTURE.md` changes
at the moment the build's candidate batch fires. The rationale: Step 6.2
calls `/jim:arch` which writes `ARCHITECTURE.md` but does NOT commit it
(verified during spec 018 implementation — `/jim:arch` Step 6 writes
silently with `auto_arch_feedback="true"` or after approval otherwise,
with no commit branch in either case). Filed issue files then coexist
with the pending arch-refresh changes; the developer commits both as a
follow-up administrative step.

This works but leaves the developer juggling two pending change-sets at
the end of every build.

### Proposed refinement

When `/jim:arch` is invoked from within `/jim:build`'s completion gate
(Step 6.2), it could optionally commit its own write before returning
control. This would eliminate one of the two pending administrative
artifacts and restore WS-4's literal precondition ("after the final
build commit" with no caveats about arch-refresh hanging in the
working tree).

Options to weigh:

1. **Always commit when invoked by build.** Simplest. `/jim:arch`
   detects its invocation context (or the caller signals it via an
   args flag) and commits the write before returning.
2. **Config-gated.** A new `auto_arch_commit_from_build` flag, default
   `"false"` (preserve current behavior; opt in to auto-commit).
3. **Build-side wrap.** `/jim:build` Step 6.2 wraps the `/jim:arch`
   call and commits any resulting `ARCHITECTURE.md` change itself,
   keeping `/jim:arch` unchanged.

Option 3 is the least invasive to `/jim:arch`'s contract but couples
`/jim:build` to git semantics it currently doesn't own. Option 2 is
the conservative path. Option 1 changes default behavior, which is
the most aggressive.

### Tradeoffs

**For:**

- One fewer pending change-set at end of build.
- WS-4's contract becomes unambiguous (no carve-out for arch).
- Aligns with the user's "all code changes and commits done before
  issue management" principle without footnotes.

**Against:**

- `/jim:arch` invoked standalone (i.e., via direct `/jim:arch`) should
  continue to leave commits to the developer — auto-commit-on-write
  would change behavior in a context where the developer expects to
  review the diff first.
- Requires either a new config flag (option 2) or some signal that
  `/jim:arch` is running under `/jim:build`'s gate (option 1/3).

### Sequencing

Independent of any other open work. Not pressing — the WS-4 trade-off
documented in spec 018 plan task 18 is workable. File this as trend
signal; consider promoting to a spec if multiple users report friction.

### Origin context

Surfaced during the spec 018 end-of-build candidate batch (2026-06-02),
which itself was the first batch fired in jim's history. The build that
implemented the batch step also produced its first administrative-housekeeping
discovery — a fitting first capture for the feature it ships.
