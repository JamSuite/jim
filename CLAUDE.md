# WebFetch

* If a WebFetch or WebSearch call fails or returns a rate-limit error (429), **stop immediately and ask the user to fetch that URL manually**. Do not continue the task with missing data. Do not defer the ask to the end of the task. The user will paste the content and you can resume.
* **Do not work around failed fetches** by using alternative tools (`gh api`, `curl`, `Bash`, etc.) to download the same content. The point is to stop and ask — not to find another way to fetch it yourself.

# Bash scripts

When editing or authoring jim's bash scripts under `skills/*/scripts/`:

* **Never `source` or `eval` user-supplied data.** Parse with `grep` / `sed` / `cut`. Sourcing executes the file as bash — security boundary.
* **No third-party deps.** Bash + POSIX only (`grep`, `sed`, `cut`, `tr`, `awk`, `find`, `sort`, `head`). No `jq`, `yq`, `bats`, etc.
* **`set -uo pipefail`, NOT `set -e`.** `set -e` interferes with the `OUT=$(...)` output-capture pattern the tests use; assertions append failure detail and let cases continue.
* **Inter-script composition uses `BASH_SOURCE`-relative paths**, not `${CLAUDE_PLUGIN_ROOT}` (which only substitutes in skill content, not script bodies). Pattern: `"$(cd "$(dirname "${BASH_SOURCE[0]}")/../sibling" && pwd)/script.sh"`.
* **Canonical references:** test conventions live in `skills/meta-test/scripts/testlib.sh` header; skill↔script composition lives in `ARCHITECTURE.md` → Plugin Conventions → Scripting Layer. Use `/jim:meta-test scaffold <name>` to author new test files (the template encodes every convention).
