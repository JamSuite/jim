#!/usr/bin/env bash
#
# skills/issue/scripts/new.sh — Write one issue file from fields. The single
#   issue-file emitter: every candidate-batch step (the seven surfacing skills)
#   and /jim:issue add file through here, so the spec-017 template is
#   materialized in exactly one place (spec 025 AC1–AC3).
#
# SECURITY MODEL (spec 025 security.md)
#   - Untrusted body never reaches a shell command line. The caller writes the
#     body to a temp file with the Write tool and passes --body-file; this
#     script appends those bytes verbatim with `cat` (file→file copy). Body is
#     never interpolated, `source`d, or `eval`d (AC4, Finding 5).
#   - Scalar fields are YAML-encoded so an untrusted --title/--labels/--origin
#     cannot inject or alter frontmatter or cross the frontmatter/body boundary
#     (AC4, Findings 1, 6): --title is escaped into a double-quoted scalar,
#     each --labels token is reduced to the slug charset, newlines are stripped.
#   - The target path is derived only through the validated id resolver: the id
#     is checked with `jimfile.sh valid-id` before any write, so untrusted input
#     cannot direct the write outside the issues directory (AC5, Finding 2).
#   - stdout is exactly "<slug>\t<path>"; failures go to stderr as fixed reason
#     codes — never raw --title/--body content (Finding 4).
#
# USAGE
#   bash new.sh --title <s> --priority <low|medium|high|critical> \
#               --labels <csv> --origin <s> --body-file <path> \
#               [--status open] [--slug <id>] [--num <int>] \
#               [--created <ts>] [--updated <ts>] [--dir <issues_dir>]
#
#   Unspecified identity fields are resolved via jimfile.sh (next-id, next-num,
#   now); --slug/--num/--created/--updated let a caller pin pre-resolved values
#   (e.g. /jim:issue add's confirm-or-edit display). --dir overrides the
#   configured issues directory for tests; production callers omit it.
#
# EXIT CODES
#   0  success
#   1  validation or IO failure (bad priority, invalid id, unreadable body, write error)
#   2  usage error (unknown/missing flag)
#
# Conventions: set -uo pipefail; LC_ALL=C; BASH_SOURCE-relative jimfile path.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"

# ─── Parse flags ─────────────────────────────────────────────────────────────

title="" priority="" labels="" origin="" body_file=""
status="open" slug="" num="" created="" updated="" dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)     title="${2-}";     shift 2 || break ;;
    --priority)  priority="${2-}";  shift 2 || break ;;
    --labels)    labels="${2-}";    shift 2 || break ;;
    --origin)    origin="${2-}";    shift 2 || break ;;
    --body-file) body_file="${2-}"; shift 2 || break ;;
    --status)    status="${2-}";    shift 2 || break ;;
    --slug)      slug="${2-}";      shift 2 || break ;;
    --num)       num="${2-}";       shift 2 || break ;;
    --created)   created="${2-}";   shift 2 || break ;;
    --updated)   updated="${2-}";   shift 2 || break ;;
    --dir)       dir="${2-}";       shift 2 || break ;;
    *) echo "error: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

# ─── Validate required inputs ────────────────────────────────────────────────

[[ -n "$title"     ]] || { echo "error: --title is required" >&2; exit 2; }
[[ -n "$priority"  ]] || { echo "error: --priority is required" >&2; exit 2; }
[[ -n "$origin"    ]] || { echo "error: --origin is required" >&2; exit 2; }
[[ -n "$body_file" ]] || { echo "error: --body-file is required" >&2; exit 2; }
[[ -r "$body_file" ]] || { echo "error: --body-file is not readable" >&2; exit 1; }

case "$priority" in
  low|medium|high|critical) ;;
  *) echo "error: invalid priority (expected low|medium|high|critical)" >&2; exit 1 ;;
esac

case "$status" in
  open|closed) ;;
  *) echo "error: invalid status (expected open|closed)" >&2; exit 1 ;;
esac

# ─── Resolve identity (overrides win; else compose via jimfile.sh) ───────────

[[ -n "$slug"    ]] || slug="$(bash "$JIMFILE" next-id issue "$title")" || {
  echo "error: could not resolve slug" >&2; exit 1; }
[[ -n "$num"     ]] || num="$(bash "$JIMFILE" next-num issue)" || {
  echo "error: could not resolve num" >&2; exit 1; }
[[ -n "$created" ]] || created="$(bash "$JIMFILE" now)"
[[ -n "$updated" ]] || updated="$created"

[[ "$num" =~ ^[0-9]+$ ]] || { echo "error: --num must be an integer" >&2; exit 1; }

# Always validate the id through the single security boundary before composing a
# path — even a caller-supplied --slug (AC5).
bash "$JIMFILE" valid-id "$slug" || { echo "error: invalid issue id" >&2; exit 1; }

if [[ -n "$dir" ]]; then
  dir="${dir%/}"
  path="$dir/$slug.md"
else
  path="$(bash "$JIMFILE" path issue "$slug")" || { echo "error: could not resolve path" >&2; exit 1; }
fi

# ─── Encode untrusted scalar fields ──────────────────────────────────────────

# --title: collapse newlines, escape backslash then double-quote for a YAML
# double-quoted scalar. Order matters (backslash first).
title_enc="$(printf '%s' "$title" | tr '\n\r' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"

# --origin: collapse newlines; emitted as a plain scalar (skill-controlled path
# or "conversation"). Not in the AC4 untrusted-field set, but normalized anyway.
origin_enc="$(printf '%s' "$origin" | tr '\n\r' '  ')"

# --labels: csv → slug tokens. Any character outside [a-z0-9-] is reduced, so a
# label containing ] , " or [[ cannot break the inline YAML array.
labels_enc=""
labels="$(printf '%s' "$labels" | tr '\n\r' '  ')"
IFS=',' read -ra _label_parts <<< "$labels"
for _raw in "${_label_parts[@]}"; do
  _tok="$(printf '%s' "$_raw" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9-]/-/g; s/-\+/-/g; s/^-//; s/-$//')"
  [[ -n "$_tok" ]] || continue
  if [[ -z "$labels_enc" ]]; then labels_enc="$_tok"; else labels_enc="$labels_enc, $_tok"; fi
done

# ─── Atomic write (tmp + mv) ─────────────────────────────────────────────────

mkdir -p "$(dirname "$path")" || { echo "error: cannot create issues directory" >&2; exit 1; }

tmpfile="$(mktemp "$(dirname "$path")/.new.tmp.XXXXXX")" || {
  echo "error: cannot create tmp file" >&2; exit 1; }
trap 'rm -f "$tmpfile"' EXIT INT TERM

{
  printf -- '---\n'
  printf 'id: %s\n' "$slug"
  printf 'num: %s\n' "$num"
  printf 'title: "%s"\n' "$title_enc"
  printf 'status: %s\n' "$status"
  printf 'priority: %s\n' "$priority"
  printf 'labels: [%s]\n' "$labels_enc"
  printf 'relations:\n  blocks: []\n  depends-on: []\n  related-to: []\n  duplicates: []\n'
  printf 'created: %s\n' "$created"
  printf 'updated: %s\n' "$updated"
  printf 'origin: %s\n' "$origin_enc"
  printf -- '---\n'
  printf '\n## Description\n\n'
  cat "$body_file"
  # Guarantee a trailing newline regardless of the body file's last byte.
  [[ -z "$(tail -c1 "$body_file")" ]] || printf '\n'
} > "$tmpfile" || { echo "error: write failed" >&2; exit 1; }

mv "$tmpfile" "$path" || { echo "error: atomic rename failed" >&2; exit 1; }
trap - EXIT INT TERM

printf '%s\t%s\n' "$slug" "$path"
