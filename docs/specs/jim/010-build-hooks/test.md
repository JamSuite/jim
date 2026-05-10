---
spec: "docs/specs/jim/010-build-hooks/spec.md"
status: complete
date: "2026-05-07"
---

# 010 Configurable build hooks — Test Plan

## Automated tests

- [x] `bash tests/jimconf.sh` — 20/20 cases passing locally
  - **6 new cases** added: `case_pre_completion_default`, `case_pre_completion_overridden`, `case_require_pre_commit_default`, `case_require_pre_commit_overridden`, `case_require_pre_completion_default`, `case_require_pre_completion_overridden`
  - **5 existing cases updated** for new key counts and entries: `case_no_config_returns_defaults`, `case_full_config_returns_overrides`, `case_list_outputs_all_keys`, `case_keys_outputs_valid_keys`, `case_malformed_lines_are_ignored`

## Manual smoke tests (post-restart)

The build-skill changes take effect after a Claude Code restart. After restart, exercise `/jim:build` against a sample spec:

- [x] Per-commit gate fires on Red / Green / Tidy commits when `./pre-commit.sh` exists
- [x] Pre-completion gate fires at step 5 when `./pre-completion.sh` exists
- [x] Halt-on-non-zero behavior at both gates
- [x] `require_pre_commit = "true"` halts when the per-commit script is absent
- [x] `require_pre_completion = "true"` halts at step 5 when the script is absent
- [x] `require_*` defaults to `"false"` — zero-config user is unaffected

## Config surface verification

- [x] `/jim:conf list` shows all 10 keys
- [x] `/jim:conf get pre_completion` resolves to default (`./pre-completion.sh`) or override
- [x] `/jim:conf get require_pre_commit` resolves to `false` (default) or override
- [x] `/jim:conf get require_pre_completion` resolves to `false` (default) or override
- [x] `/jim:conf keys` lists all 10 keys including the three new ones
