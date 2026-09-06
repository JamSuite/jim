---
id: 20260812-new-sh-composes-and-stats-a-path-before-valid-id-runs
num: 320
title: "new.sh composes and stats a path before valid-id runs"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, verify, issue]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T04:09:10Z
updated: 2026-08-12T08:31:52Z
origin: docs/specs/issue/000-blueprint/spec.md
---

## Description

`new.sh` composes an issue path and stats it **before** the id clears the
validator, breaking the ordering its own comment two lines below asserts.

## Mechanism

`skills/issue/scripts/new.sh:209-228`:

```
if (( slug_via_alloc )); then
    while [[ -e "$issues_dir/$slug.md" ]]; do        # composes + stats
  elif [[ -e "$issues_dir/$slug.md" ]]; then         # composes + stats
...
# Always validate the id through the single security boundary before composing a
# path — even a caller-supplied --slug, and even an allocator-derived one.
bash "$JIMFILE" valid-id "$slug" || { echo "error: invalid issue id" >&2; exit 1; }
path="$issues_dir/$slug.md"
```

The `id-gate-before-path` invariant (criticality **critical**) reads "Every id
passes the validator before any path composition or file read". Lines 213 and 218
do both, before line 226 runs.

**Exposure is bounded.** The branch is entered only when `slug_via_alloc=1`, so a
caller-supplied `--slug` skips it; and a malformed id is still refused at 226
before any write. The worst case is a file-existence oracle, not a write outside
the collection. But the id fed to that stat derives from the untrusted `--title`
via `jimalloc.sh allocate issue "$title"`, whose sanitization lives outside this
group — so the composed value is not provably validator-clean at that point.

**Secondary.** `migrate.sh:116`'s collision discriminator `${new}-${n}` is not
re-validated before it becomes a path at `:213`. The charset is preserved and
`..` cannot be introduced, so only the 128-character cap could be silently
exceeded.

## Proposed action

Move the `valid-id` call above line 209 so it precedes every composition, and
re-validate `migrate.sh`'s discriminator before it becomes a path.

## Origin

Post-build review of `issue/011`; the `id-gate-before-path` judge. Resolved
**fix** at the blueprint fork — the rule stands and the code diverged — so the
invariant text is unchanged and this issue carries the divergence.

## Resolution (2026-08-12)

Fixed in `227ce29`. The `valid-id` call moves above the disambiguation block, so
nothing composes or stats a path from an unvalidated id, and each suffixed
variant the loop derives clears the boundary in turn — a derived id is a new id,
and it composes the next iteration's path. A slug pushed past the 128-character
cap by its own suffix is now refused there rather than discovered after the loop.

**The secondary is closed too.** `migrate.sh`'s collision discriminator appended
`-2` to an id that had cleared the boundary and used the result as a filename.
Clearance does not transfer: the charset cannot change and `..` cannot be
introduced, but the length cap can be crossed. It now clears the boundary on its
own account, which is what the file's header already claimed.

Pinned by `case_new_validates_the_id_before_composing_a_path` — a textual
assertion that the gate precedes the first composition, because what it guards is
a stat and a stat leaves nothing for a behavioural case to read — and by
`case_issues_migrate_discriminator_clears_the_id_boundary`, which drives two
issues re-deriving to the same 128-character id so the discriminated form is 130.
Both proven to go red with their guard removed.

Writing the second of those exposed a separate defect that was swallowing its own
skip reason, filed and fixed as
`20260812-migration-preview-drops-every-skip-reason`.
