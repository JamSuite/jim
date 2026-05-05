# jimfile non-default-layout walkthrough — 2026-05-04

Spec 008 build, plan task 13. Manual confirmation that `/jim:debug`,
`/jim:brainstorm`, and `/jim:spec` route artifacts through `jimfile.sh`
to the configured paths declared in a project's `jimconf.toml`.

## Setup

Scratch project at `/tmp/jim-walkthrough.75UhdC/` with:

- `jimconf.toml` overriding three keys:
  - `specs_path        = "<scratch>/custom-specs"`
  - `debug_path        = "<scratch>/custom-debug"`
  - `brainstorms_path  = "<scratch>/custom-brain"`
- Pre-existing specs: `<scratch>/custom-specs/jim/002-foo/`,
  `<scratch>/custom-specs/jim/005-bar/` (gap-bearing layout to verify
  the max+1 rule).

Each script call below ran with `bash skills/file/scripts/jimfile.sh
-c <scratch>/jimconf.toml ...` so `jimconf.sh` reads the override file
and `jimfile.sh` honors it.

## Observations

| Operation | Expected | Got |
| :-- | :-- | :-- |
| `next-id jim` | `006` (max of 002/005 + 1, gap not reclaimed) | `006` |
| `path spec jim 006 walkthrough` | `<scratch>/custom-specs/jim/006-walkthrough/spec.md` | matches |
| `path debug "walkthrough topic"` | `<scratch>/custom-debug/20260504-walkthrough-topic.md` | matches |
| `path brainstorm "walkthrough topic"` | `<scratch>/custom-brain/20260504-walkthrough-topic.md` | matches |
| `path debug` after the file already exists | `…-walkthrough-topic-2.md` (Decision 5 collision) | matches |
| `glob specs jim` | three dirs incl. the new 006 | three dirs incl. `006-walkthrough` |
| `glob debug` | the one created file under `custom-debug/` | matches |
| `glob brainstorms` | the one created file under `custom-brain/` | matches |

Every artifact landed at the configured path (none under the default
`docs/specs`, `docs/debug`, or `docs/brainstorms`). Spec ID assignment
correctly skipped reclaiming `001`/`003`/`004` and produced `006`,
satisfying spec 008 OoS ("Spec ID gap reclamation … explicitly excluded").
The collision rule produced the documented `-2` suffix on the second
debug-path resolution after the first file was written.

## Conclusion

Spec 008 acceptance criterion #11 ("at least one consuming skill has
migrated end-to-end and produces correct output") is met by all three
migrated consumers (`debug`, `brainstorm`, `spec`) under a non-default
configuration. No regressions observed in `bash tests/run.sh` (43/43
pass — 12 jimconf cases + 31 jimfile cases).
