# Tests for scripts/_univ_helpers.fish — currently just _univ_prefix, the
# helper that groups univ-vars by their leading prefix for batch-tracking
# in the capture sub-pass.
#
# Run via `scripts/run-tests` (fishtape).

set -l repo_root (dirname (realpath (status -f)))/..
source $repo_root/scripts/_univ_helpers.fish

# ─── plain (no-underscore) prefix ────────────────────────────────────────

test (_univ_prefix tide_pwd_color_dirs) = tide_
@test "_univ_prefix: tide_pwd_color_dirs → tide_" $status -eq 0

test (_univ_prefix sponge_color) = sponge_
@test "_univ_prefix: sponge_color → sponge_" $status -eq 0

# ─── leading single underscore (plugin-internal cache convention) ────────

test (_univ_prefix _fisher_plugins) = _fisher_
@test "_univ_prefix: _fisher_plugins → _fisher_" $status -eq 0

# ─── leading double underscore (fish builtin convention) ─────────────────

test (_univ_prefix __fish_initialized) = __fish_
@test "_univ_prefix: __fish_initialized → __fish_" $status -eq 0

# ─── prefix-only (no suffix after the trailing _) ───────────────────────

test (_univ_prefix tide_) = tide_
@test "_univ_prefix: prefix-only name (tide_) returns the prefix" $status -eq 0

# ─── no underscore → empty output ────────────────────────────────────────

set -l out (_univ_prefix noprefix)
@test "_univ_prefix: noprefix → empty" (count $out) -eq 0

# ─── names with digits ──────────────────────────────────────────────────

test (_univ_prefix tide2_color) = tide2_
@test "_univ_prefix: names with digits work (tide2_color → tide2_)" $status -eq 0

# ─── empty input → empty output (does not crash) ────────────────────────

set -l out2 (_univ_prefix "")
@test "_univ_prefix: empty input → empty output, no error" (count $out2) -eq 0
