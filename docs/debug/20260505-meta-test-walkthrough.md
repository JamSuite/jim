# Meta-test dogfood walkthrough — 2026-05-05

Spec: `docs/specs/jim/007-meta-test/`
Plan task: 25 (Phase F end-to-end dogfood)

## Outcome

All dispatcher actions and refusal modes verified end-to-end against `tests/scratchtest.sh` (a throwaway file, scaffolded then cleaned up). The aggregate runner picked up the new file and ran it alongside the existing 55 cases for a clean 57/57 with scratchtest present.

## Bug surfaced and fixed during the walkthrough

The first dogfood pass exposed a global-name collision: the scaffold template defined `SCRIPT="$REPO_ROOT/..."` for the script-under-test path. The existing `tests/jimconf.sh` also uses bare `SCRIPT`. When the aggregate runner sourced both, scratchtest's value overwrote jimconf's, breaking 11 jimconf cases.

Fix applied to `skills/meta-test/assets/test-file.sh.tmpl`: namespace the global as `SCRIPT_<name>` (substituted from a `SCRIPT___NAME__` placeholder). Every scaffolded test file now declares its script-under-test in a unique global, eliminating the collision class. The dispatcher's confirmation message was updated to match.

`tests/jimconf.sh` was left as-is (still uses bare `SCRIPT`) because it predates the convention and its bare global doesn't collide with anything in production use; future-scaffolded files use the namespaced convention by construction.

## Walkthrough steps

| # | Action | Expected | Actual | Pass? |
| :--- | :--- | :--- | :--- | :--- |
| A | `bash skills/meta-test/scripts/metatest.sh scaffold scratchtest` | exit 0; `tests/scratchtest.sh` created | exit 0; file created with `SCRIPT_scratchtest` global, `run_scratchtest()` invoker, `case_scratchtest_smoke()` case, standalone-runnable tail with explanatory comment block | ✓ |
| B | Inspect scaffolded file for namespaced globals | `SCRIPT_scratchtest=` and `run_scratchtest()` present | both present | ✓ |
| C | Re-scaffold the same name | exit 1; stderr "tests/scratchtest.sh already exists" | exit 1; expected stderr | ✓ |
| D | `scaffold "bad-name"` (hyphen) | exit 1; stderr names regex constraint | exit 1; "is not a valid name. Must match ^[a-zA-Z_][a-zA-Z0-9_]*$" | ✓ |
| E | `bash tests/scratchtest.sh` (standalone) | exit 0; smoke case passes | exit 0; `PASS - case_scratchtest_smoke`; `Ran 1 tests: 1 passed` | ✓ |
| F | `add scratchtest handles_input` | exit 0; case appended | exit 0; "Appended case_scratchtest_handles_input() to tests/scratchtest.sh" | ✓ |
| G | `add scratchtest handles_input` (duplicate) | exit 2; stderr names conflict | exit 2; "case_scratchtest_handles_input already exists" | ✓ |
| H | `add nonexistent some_case` (missing file) | exit 1; stderr names file | exit 1; "tests/nonexistent.sh does not exist" | ✓ |
| I | `metatest.sh run scratchtest` (with name → standalone path) | exit 0; smoke case runs | exit 0; `PASS - case_scratchtest_smoke`; `Ran 1 tests: 1 passed` | ✓ |
| J | `metatest.sh run` (no args → aggregate runner) | exit 0; full suite + scratchtest cases run | exit 0; `Ran 57 tests: 57 passed, 0 failed` (55 baseline + 2 scratchtest) | ✓ |
| K | Cleanup `tests/scratchtest.sh` | file removed | removed | ✓ |

## Gating note

The plan AC mentions confirming "scaffold without an approved spec/plan **refuses** with the missing-spec gate message" (Plan task 25 step a). That gating lives in `skills/meta-test/SKILL.md` (LLM-level — checks markdown frontmatter), **not** in the dispatcher script. The dispatcher scaffolds any name passing the bash-identifier regex, regardless of upstream spec/plan state.

This is by design (see plan Decision 9 — "gating logic belongs in the SKILL.md, not the script"). To dogfood the gating, an interactive `/jim:meta-test <name>` invocation against a name with no matching spec/plan is required — that's a SKILL-layer test that fits a future hand-driven verification pass, not the dispatcher script's test surface.

## Final state

- Full suite: `bash skills/meta-test/scripts/run.sh` → **55 passed, 0 failed** (baseline restored).
- Scratchtest cleaned up; no residue under `tests/`.
- One small wording fix to dispatcher's confirmation message (`SCRIPT` → `SCRIPT_<name>` in the "Next:" line).
