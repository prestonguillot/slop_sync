# wrangle behavior tests — invoke wrangle inside fixture repos and assert
# the resulting state. Covers behaviors that go beyond CLI-surface testing.

set -l repo_root (dirname (realpath (status -f)))/..
set -l wrangle $repo_root/scripts/wrangle

# ─── review-docs requires claude ──────────────────────────────────────────

env PATH=/nonexistent-bin $wrangle review-docs 2>/dev/null
@test "review-docs without claude on PATH exits non-zero" $status -ne 0

# ─── Dry-run is hermetic ─────────────────────────────────────────────────
# `sync --dry-run` must never create a last-wrangle stamp.

set -l fake_home (mktemp -d)
env HOME=$fake_home $wrangle sync --dry-run >/dev/null 2>&1
test -f $fake_home/.cache/dotfiles/last-wrangle
@test "sync --dry-run does NOT create last-wrangle stamp" $status -ne 0
rm -rf $fake_home
