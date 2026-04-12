#!/usr/bin/env bash
# scripts/harness/lib/scrub-secrets.sh
#
# Streaming secret scrubber. Reads stdin, writes stdout, replacing
# credential patterns with [REDACTED:<pattern-name>]. Used by
# scripts/harness/run-cmd to filter subprocess output BEFORE it reaches
# the agent. Raw (unscrubbed) output is preserved in target/runner.log
# by the caller so operators can debug with the originals.
#
# Design:
#   - Single-pass awk over the input stream. No per-line subshells.
#   - Allowlist file (scrub-secrets-allowlist.txt) holds exact substrings
#     that must bypass redaction — lines containing any allowlist entry
#     are emitted verbatim. The file can contain comments (#) and blanks.
#   - Patterns run in a fixed order so longer, more-specific matches
#     (bearer-auth, aws-secret-env) are resolved before shorter ones.
#
# Patterns enforced:
#   aws-access-key   AKIA followed by 16 upper/digits
#   github-token     ghp_/gho_/ghu_/ghs_/ghr_ + 20+ base62 chars
#   jwt              three dot-separated base64url segments (10+ each)
#   bearer-auth      "Authorization: Bearer <value>" — keep header, hide value
#   aws-secret-env   AWS_SECRET_ACCESS_KEY=<value> — keep key, hide value
#   private-key      -----BEGIN ... PRIVATE KEY----- ... -----END ... -----
#
# Portability note: awk treats /literal/ as a regex constant that implicitly
# matches $0. To call match() with a pattern, we pass the regex as a string
# variable — awk then recompiles it as a dynamic regex. All patterns below
# live in string variables initialized in BEGIN for clarity and reuse.
#
# The scrubber is run on every failed run-cmd invocation, so every shell
# subprocess inside the hot loop matters. Keep this script tight.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
allowlist_file="${SCRUB_ALLOWLIST_FILE:-$script_dir/scrub-secrets-allowlist.txt}"

exec awk -v allowlist_file="$allowlist_file" '
BEGIN {
  # Dynamic-regex strings (awk recompiles on each use, but mawk caches).
  re_aws_access  = "AKIA[0-9A-Z]{16}"
  re_github_tok  = "gh[pousr]_[A-Za-z0-9]{20,}"
  re_jwt         = "eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}"
  re_bearer      = "Authorization:[[:space:]]*Bearer[[:space:]]+[^[:space:]]+"
  re_bearer_hdr  = "Authorization:[[:space:]]*Bearer[[:space:]]+"
  re_aws_secret  = "AWS_SECRET_ACCESS_KEY[[:space:]]*=[[:space:]]*[^[:space:]]+"
  re_aws_key_hdr = "AWS_SECRET_ACCESS_KEY[[:space:]]*=[[:space:]]*"
  re_pk_begin    = "-----BEGIN( RSA| EC| DSA| OPENSSH|) PRIVATE KEY-----"
  re_pk_end      = "-----END( RSA| EC| DSA| OPENSSH|) PRIVATE KEY-----"

  # Load allowlist into an array of exact substrings.
  allow_count = 0
  while ((getline line < allowlist_file) > 0) {
    sub(/^[[:space:]]+/, "", line)
    sub(/[[:space:]]+$/, "", line)
    if (line == "") { continue }
    if (substr(line, 1, 1) == "#") { continue }
    allowlist[allow_count++] = line
  }
  close(allowlist_file)

  in_private_key = 0
}

# Allowlist bypass: emit the line verbatim if it contains any allowed substring.
function allowlisted(s,    i) {
  for (i = 0; i < allow_count; i++) {
    if (index(s, allowlist[i]) > 0) { return 1 }
  }
  return 0
}

# Redact every match of string-valued regex re in s with token. Returns
# the rewritten string.
function redact_simple(s, re, token,    out) {
  out = ""
  while (match(s, re) > 0) {
    out = out substr(s, 1, RSTART - 1) token
    s = substr(s, RSTART + RLENGTH)
  }
  return out s
}

# Redact the value part of a "prefix=value" or "header: value" style match.
# re matches the whole span (header + value); keep_re matches only the
# leading header portion which is preserved verbatim; the rest is replaced
# with token. This keeps error messages readable while hiding the secret.
function redact_prefixed(s, re, keep_re, token,    out, span, ms, ml, kl) {
  out = ""
  while (match(s, re) > 0) {
    ms = RSTART
    ml = RLENGTH
    span = substr(s, ms, ml)
    if (match(span, keep_re) > 0 && RSTART == 1) {
      kl = RLENGTH
      out = out substr(s, 1, ms - 1) substr(span, 1, kl) token
      s = substr(s, ms + ml)
    } else {
      # Fallback: no header to preserve, redact the whole span.
      out = out substr(s, 1, ms - 1) token
      s = substr(s, ms + ml)
    }
  }
  return out s
}

{
  line = $0

  # Private-key block: once a BEGIN line is seen, every line is redacted
  # (including BEGIN and END) until the matching END line is consumed.
  if (in_private_key) {
    if (match(line, re_pk_end) > 0) {
      in_private_key = 0
    }
    print "[REDACTED:private-key]"
    next
  }
  if (match(line, re_pk_begin) > 0) {
    in_private_key = 1
    print "[REDACTED:private-key]"
    next
  }

  # Allowlist bypass — after the private-key check so we never skip a key block.
  if (allow_count > 0 && allowlisted(line)) {
    print line
    next
  }

  # Prefixed redactions first: keep the header/key visible, hide only the value.
  line = redact_prefixed(line, re_bearer,     re_bearer_hdr,  "[REDACTED:bearer-auth]")
  line = redact_prefixed(line, re_aws_secret, re_aws_key_hdr, "[REDACTED:aws-secret-env]")

  # Simple token redactions: replace the whole match.
  line = redact_simple(line, re_jwt,        "[REDACTED:jwt]")
  line = redact_simple(line, re_github_tok, "[REDACTED:github-token]")
  line = redact_simple(line, re_aws_access, "[REDACTED:aws-access-key]")

  print line
}
'
