#!/usr/bin/env bash
#
# skills/issue/scripts/identity.sh — Resolve the contributor identity the
#   environment supplies, or refuse. The emitter records the result as an
#   issue's filer, and the transition verbs record it as an issue's holder, so
#   this is the one place that decides what counts as a recordable identity.
#
#   The value is stored as version control supplies it — not normalized,
#   truncated, or mapped through a table. Which form it takes is each
#   contributor's own configuration decision.
#
# SECURITY MODEL
#   - The configured identity accepts embedded newlines and arbitrary bytes, so
#     an unchecked value can close the frontmatter it is written into and open
#     fields of its own. It is validated against a positively enumerated
#     character set: only that set is accepted, and everything outside it is
#     refused. Stating the set positively is what makes unanticipated input —
#     a Unicode line separator, a stray control byte — fail closed rather than
#     survive a list of characters someone thought to name.
#   - A refused value never appears in the refusal. Reasons are fixed strings,
#     so a terminal log cannot be made to carry the value that was rejected.
#   - The value is compared, never sourced or evaluated.
#
# USAGE
#   bash identity.sh resolve
#
# EXIT CODES
#   0  resolved — the identity is on stdout
#   1  none configured — nothing on stdout
#   2  configured but not recordable, or a usage error — nothing on stdout

set -uo pipefail

# Byte-exact ranges. Under any other collation the ranges below could admit
# characters beyond ASCII, which is the opposite of failing closed.
export LC_ALL=C

# The accepted set: broad enough for the addresses version control actually
# carries, including forge noreply forms like 1234+name@users.noreply.host, and
# bounded so anything else is refused rather than recorded. It excludes the
# quote and backslash that would otherwise escape the scalar this value is
# written into.
IDENTITY_CHARS='A-Za-z0-9._%+@-'

# Longest address the mail standards admit; a value beyond it is not one.
IDENTITY_MAX=254

usage() {
  echo "usage: identity.sh resolve" >&2
}

# resolve — print the configured identity, or refuse.
resolve() {
  local value
  value="$(git config --get user.email 2>/dev/null)" || value=""

  if [[ -z "$value" ]]; then
    echo "error: no identity configured; set user.email" >&2
    return 1
  fi

  if (( ${#value} > IDENTITY_MAX )); then
    echo "error: configured identity is not recordable" >&2
    return 2
  fi

  # Accept only the enumerated set: one character outside it refuses the whole
  # value. Newlines, spaces and multi-byte sequences are all outside it.
  if [[ "$value" == *[!$IDENTITY_CHARS]* ]]; then
    echo "error: configured identity is not recordable" >&2
    return 2
  fi

  printf '%s\n' "$value"
  return 0
}

case "${1:-}" in
  resolve)
    shift
    if [[ $# -ne 0 ]]; then usage; exit 2; fi
    resolve
    exit $?
    ;;
  *)
    usage
    exit 2
    ;;
esac
