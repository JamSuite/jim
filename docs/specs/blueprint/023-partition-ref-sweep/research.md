---
spec: "docs/specs/blueprint/023-partition-ref-sweep/spec.md"
status: Active
date: "2026-07-23"
---

# Research: Partition ref sweep mis-rewrites typed refs on renumbering moves

## Anchors

**Fault location — the two sweep verbs** (`skills/partition/scripts/jimpartition.sh`):

- `:1654-1769` — `cmd_rewrite_identity`. Rewrites three token kinds: frontmatter `group:` (`:1715-1729`), dotted-key `<old>.<surface>` and typed-ref `<old>/<digit>` via the body scan (`:1734-1760`, kind emitted `:1753`). The typed-ref branch replaces only the group half, number verbatim (`:1752`) — the number-preserving rewrite at the bug's core.
- `:1790-1886` — `cmd_rewrite_refs`. Remap rows are TAB-split `<og>/<onum>→<ng>/<nnum>`, slug + 3-digit gated (`:1810-1824`); the remap **is** the whitelist (`:1775-1778`, `:1857-1858`); whole-token match replaces both halves (`:1863-1873`), kind `path` when preceded by `/` else `typed-ref` (`:1870`).
- Both verbs share the guard-pass/edit-pass loop separation (identity `:1676-1692`/`:1698-1766`; refs `:1826-1842`) — any fix must preserve it.

**Remap emitters** — they determine what "remap-covered" means:

- `:1328-1403` — `cmd_renumber_map` (split). Emits a row for **every assigned spec, remainder included** — a continuing remainder gets identity rows `MAP old/NNN → old/NNN` (`:1392-1398`). So for split, remap coverage of all live typed refs is computable from the remap file alone.
- `:1417-1463` — `cmd_merge_map` (merge). The absorption target is skipped (`:1446`) — target tokens never appear as remap keys; every moved source spec gets a row. Cross-source refs (`src2/NNN` inside a body moved from `src1`) are therefore remap-handled and safe under either order — manifestation 1 is strictly same-source.

**Documented sweep order** (the prose half of the fix):

- `skills/partition/SKILL.md:369` (split), `:425` (merge) — "`rewrite-identity` … + `rewrite-refs` over the swept set". Rename runs identity only (`:312-314`) — no remap exists there.
- `skills/partition/references/partition-methodology.md:493-498` (split materialize step 2), `:678-682` (merge), `:305-311` (rename); sweep-set assembly `:458-469` / `:643-650`.
- Usage text `jimpartition.sh:65-69`; dispatch `:2070-2074` (positional forward, no flag preprocessing).

**Secondary doc surface:** `agents/gatherer.md:63` names dotted-key/typed-ref as identity's mechanical set — needs a caveat if typed-ref conditionally leaves that set. `ARCHITECTURE.md` mentions are pipeline-regenerated (`/jim:arch` at build completion) — no manual edit.

**Tests** (`tests/jimpartition.sh` — where the regression tests land):

- rewrite-identity block `:1370-1606`; rewrite-refs block `:1770-1876`; renumber-map `:1693-1768` (`_extraction_tail` `:1698-1706` already asserts the remainder identity row `MAP cart/005 → cart/005`); merge-map `:2157-2236`.

## Local Patterns

- **Test template:** `test_rewrite_refs_typed_ref` (`tests/jimpartition.sh:1774-1783`) — bash testlib framework (`skills/meta-test/scripts/testlib.sh`; `set -uo pipefail`, never `set -e`; `OUT=$(...)` capture; `assert_eq`/`assert_match`/`assert_exit`), fixtures via `git_init` (`:78-83`) + `repo_add` (`:87-92`). The regression tests compose *both* verbs over one fixture in the documented order — same fixture shape as the empirical repros (2026-07-23): manifestation 1 needs a moved body + renumber row; manifestation 2 needs an extraction-arm body citing a remainder spec whose remap row is an identity mapping.
- **No option surface exists on either verb** — positional args only, zero flags repo-wide. Any flag (e.g. a typed-ref skip) is a greenfield addition: usage block `jimpartition.sh:65-69`, arg parse (`:1655-1665` / `:1791-1801`), and slug-gating of `awk -v` inputs (`:1663-1665`) must all be extended in kind.
- **Precedent for tightening identity's match set:** closed issue `docs/issues/20260721-narrow-rewrite-identity-dotted-key-and-typed-ref-over-match.md` — the verb's kinds were deliberately narrowed once already; the extension exclusion (`:1744-1749`) shows the pattern for carving tokens out of the body scan.

## Security & Performance

- **Remap-as-whitelist doctrine must survive the fix:** remaps are script-emitted (`renumber-map`/`merge-map`), never hand-authored or scanned from content (the 045 script-emitted doctrine). Any remap-aware change to `rewrite-identity` must not open a path where hand-fed remap content widens what identity may rewrite.
- **Guard-pass discipline:** new code paths must keep the all-files-guarded-before-any-edit property (path safety, symlink escape, tracked-only) both verbs currently enforce.
- **Regression risk — rename (043):** identity's typed-ref rewrite is *correct* there (no renumbering); the fix must be conditional, and the existing rename/identity tests (`:1401-1416` et al.) must pass unmodified (spec AC 3).
- **Performance:** both sweeps are one `awk` per file over the `git ls-files` set; neither reordering nor kind-scoping changes the profile.

## Recommendations

Options for the architect — evidence, not decisions:

1. **Scope identity away from typed refs on renumbering moves (necessary).** Manifestation 2 is order-independent, so some scoping is required. Two shapes:
   - *(a) Blanket skip flag* — an opt-in flag on `rewrite-identity` that drops the typed-ref kind; split/merge flows pass it, rename does not. Smallest change; since both emitters cover **all** live numbers of the affected groups (remainder identity rows included), a blanket skip is behaviorally identical to remap-aware skipping for every non-dangling ref.
   - *(b) Remap-aware skip* — pass the remap file into identity and skip only covered tokens. More coupling for no observable gain; differs from (a) only on already-dangling refs (out of scope per spec).
2. **Sweep order becomes free after scoping.** With typed refs owned solely by `rewrite-refs`, the verbs commute on the collision zone; AC 4 then only requires the prose (SKILL.md `:369`, `:425`; methodology `:493-498`, `:678-682`) to state whatever order + flag the plan settles on. Reordering alone (issue #87's first proposal) is demonstrably insufficient — do not adopt it as the sole fix.
3. **Regression tests** land in `tests/jimpartition.sh` beside the existing verb blocks: two composed-sweep cases (split extraction arm covering both manifestations; merge arm covering manifestation 1), using `git_init`/`repo_add`, asserting final body text and `REWROTE` records.
4. **Doc touches:** the two SKILL.md order lines, the two methodology materialize steps, usage text if a flag lands, and the `gatherer.md:63` kind-set caveat. `ARCHITECTURE.md` regen is pipeline-owned — not a task.

**Alignment:** the fix stays entirely in the deterministic scripting layer plus its prose flows — consistent with ARCHITECTURE.md's mechanical-floor doctrine (scripts own rewrites; remaps are script-emitted, spec 045) and VISION's human-in-the-loop stance (the gate still presents every edit as a secret-scrubbed diff; no new judgment surface). No divergence from locked constraints.
