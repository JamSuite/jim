---
id: 20260704-harden-the-verify-floor-path-param-whitespace-dashes-only-id-mkd
num: 51
title: "Harden the verify floor: path-param whitespace, dashes-only Id, mkdir grant"
status: open
priority: low
labels: [verify, hardening]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T23:53:21Z
updated: 2026-07-04T23:53:21Z
origin: docs/specs/jim/035-verify-engine/review.md
---

## Description

## Context

From the spec 035 post-build review (`review.md` Findings 3–6). A bundle of
low-severity hardening / cleanup items in the verify floor. None is a
trust-boundary risk — every security guarantee held in the review fan-out —
but each is a genuine, cheap improvement.

## What

1. **`safe_path_param` leading-whitespace (Finding 3).** A crafted params line
   `scope= -rf` yields the value `" -rf"`, which slips past the `[[ "$v" == -* ]]`
   leading-dash reject (leads with a space) and passes `valid-relpath`. Contained
   harmlessly today by the `--`/`-e` call-site guards, but the string check should
   trim (or reject) leading/trailing whitespace so the leading-dash intent is
   airtight. `skills/verify/scripts/jimverify.sh:189-195`.

2. **Separator-regex silent drop (Finding 4).** `parse`'s
   `if (c1 ~ /^:?-+:?$/) next` runs on every table row before the data branch, so a
   dashes-only Id (`-`, `---`) is silently skipped as if it were a table separator —
   a silent drop that contradicts the "never a silent drop" contract. Apply the
   separator skip only to the row immediately after the header (or once the header
   is seen). `skills/verify/scripts/jimverify.sh:117`. Pathological input, but a
   real hole.

3. **Legacy criticality strictness (Finding 5).** A legacy (Id-less) row whose
   criticality is outside the lowercase `critical|high|medium|low` enum degrades to
   `failed`, not the `judge` fallback AC #10 promises. Realistic legacy tables use
   the spec 029 enum, so it is normally moot — at minimum document the
   enum-strictness in `check-authoring.md`, or decide legacy rows should always
   judge-fall-back regardless of criticality wording.

4. **Unused `mkdir` grant (Finding 6).** `verify/SKILL.md` declares `Bash(mkdir *)`,
   the one allowed-tools entry that is a wildcard rather than an exact script path.
   The issue-offer files through `new.sh` (which resolves its own dir), so the skill
   body may never invoke `mkdir`. Confirm and drop if unused (minor permission-creep).

## Why

Defense-in-depth thinness and contract precision. Low priority — grouped so they
can be swept in one small pass rather than tracked as four separate tickets.
