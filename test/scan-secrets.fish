# scan-secrets behavior tests. Run via `scripts/run-tests` (fishtape).
#
# fishtape's @test runs fish's `test` builtin with the remaining args.
# Pattern: run command(s), capture output/status, then a single @test assertion.

set -l scan (dirname (realpath (status -f)))/../scripts/scan-secrets

# ─── Clean input: no false positives, exit 0 ──────────────────────────────

echo "just some normal text" | $scan >/dev/null
@test "clean input exits 0" $status -eq 0

echo "config_password_strength=strong" | $scan >/dev/null
@test "config-keys with word 'password' don't false-positive" $status -eq 0

echo -n "" | $scan >/dev/null
@test "empty input exits 0" $status -eq 0

# ─── Provider tokens ──────────────────────────────────────────────────────

set -l out (echo "AKIAIOSFODNN7EXAMPLE" | $scan)
string match -q "*AWS access key*" -- "$out"
@test "AWS access key detected" $status -eq 0

set out (echo "ghp_abcdefghijklmnopqrstuvwxyz0123456789" | $scan)
string match -q "*GitHub token*" -- "$out"
@test "GitHub classic token detected" $status -eq 0

set out (echo "xoxb-1234567890-abcdefghijk" | $scan)
string match -q "*Slack token*" -- "$out"
@test "Slack token detected" $status -eq 0

set out (echo "sk_live_abcdefghijklmnopqrstuvwx" | $scan)
string match -q "*Stripe live key*" -- "$out"
@test "Stripe live key detected" $status -eq 0

set out (echo "sk_live_51AbcdefGhIjklmnopQRstuVWxyz0123456789abcdef" | $scan)
string match -q "*Stripe*" -- "$out"
@test "Stripe live key detected (long form)" $status -eq 0

set out (echo "sk-abcdefghijklmnopqrstuvwxyz" | $scan)
string match -q "*OpenAI-style key*" -- "$out"
@test "OpenAI-style key detected" $status -eq 0

set out (echo "sk-ant-abcdefghijklmnopqrstuv" | $scan)
string match -q "*Anthropic key*" -- "$out"
@test "Anthropic key detected (matches OpenAI-style too)" $status -eq 0

set out (echo "AIzaSyA-1234567890abcdefghijklmnopqrstu" | $scan)
string match -q "*Google API key*" -- "$out"
@test "Google API key detected" $status -eq 0

set out (echo "ACa1b2c3d4e5f60718293a4b5c6d7e8f90" | $scan)
string match -q "*Twilio*" -- "$out"
@test "Twilio account SID detected" $status -eq 0

# ─── Key file formats ─────────────────────────────────────────────────────

set out (echo "-----BEGIN RSA PRIVATE KEY-----" | $scan)
string match -q "*PEM private key*" -- "$out"
@test "PEM private key header detected" $status -eq 0

set out (echo "-----BEGIN OPENSSH PRIVATE KEY-----" | $scan)
string match -q "*OpenSSH private key*" -- "$out"
@test "OpenSSH private key header detected" $status -eq 0

# ─── Distinctive formats ──────────────────────────────────────────────────

set out (echo "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signaturefoo123" | $scan)
string match -q "*JWT-like token*" -- "$out"
@test "JWT-like token detected" $status -eq 0

# ─── Multi-hit + exit-status semantics ────────────────────────────────────

set out (printf '%s\n' 'AKIAIOSFODNN7EXAMPLE' 'ghp_abcdefghijklmnopqrstuvwxyz0123456789' | $scan)
@test "multiple hits produce ≥2 lines of output" (count $out) -ge 2

echo "AKIAIOSFODNN7EXAMPLE" | $scan >/dev/null
@test "exit code equals hit count (single hit → 1)" $status -eq 1

set out (printf '%s\n' 'first line clean' 'AKIAIOSFODNN7EXAMPLE' 'third line clean' | $scan)
@test "multi-line input with one hit produces exactly one finding" (count $out) -eq 1

echo "akiaiosfodnn7example" | $scan >/dev/null
@test "case-sensitive — lowercase 'akia' should NOT match" $status -eq 0

# ─── Negative cases: boundary + near-miss patterns ───────────────────────
# Cover length boundaries, wrong-shape prefixes, and substring contexts that
# look token-ish without actually matching the patterns.

echo "AKIAIOSFODNN7EXAMPL" | $scan >/dev/null
@test "AWS pattern: 15 chars after AKIA (one short) → no match" $status -eq 0

echo "BKIAIOSFODNN7EXAMPLE" | $scan >/dev/null
@test "AWS pattern: wrong prefix (BKIA instead of AKIA) → no match" $status -eq 0

echo "AKIA" | $scan >/dev/null
@test "AWS pattern: prefix alone with no suffix → no match" $status -eq 0

echo "gh_abcdefghijklmnopqrstuvwxyz0123456789ab" | $scan >/dev/null
@test "GitHub pattern: missing letter slot (gh_ vs gh[poursi]_) → no match" $status -eq 0

echo "ghp_tooshort1234567890abc" | $scan >/dev/null
@test "GitHub pattern: ghp_ + 21 chars (need 36+) → no match" $status -eq 0

echo "xoxz-abcdefghij" | $scan >/dev/null
@test "Slack pattern: wrong letter slot (xoxz- vs xox[abprs]-) → no match" $status -eq 0

echo "sk-tooshortbutsame" | $scan >/dev/null
@test "OpenAI pattern: sk- + 15 chars (need 20+) → no match" $status -eq 0

echo "sk-ant-tooshort" | $scan >/dev/null
@test "Anthropic pattern: sk-ant- + 8 chars (need 20+) → no match" $status -eq 0

echo "----BEGIN RSA PRIVATE KEY----" | $scan >/dev/null
@test "PEM pattern: 4 dashes instead of 5 → no match" $status -eq 0

echo "eyJsegment1.eyJsegment2.x" | $scan >/dev/null
@test "JWT pattern: third segment 1 char (need 8+) → no match" $status -eq 0

echo "header.eyJsegment2okay.signatureokay" | $scan >/dev/null
@test "JWT pattern: first segment missing eyJ prefix → no match" $status -eq 0
