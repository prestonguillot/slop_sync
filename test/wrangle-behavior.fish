# wrangle behavior tests — invoke wrangle inside fixture repos and assert
# the resulting state. Covers behaviors that go beyond CLI-surface testing.

set -l repo_root (dirname (realpath (status -f)))/..
set -l wrangle $repo_root/scripts/wrangle

# ─── review-docs requires claude ──────────────────────────────────────────

env PATH=/nonexistent-bin $wrangle review-docs 2>/dev/null
@test "review-docs without claude on PATH exits non-zero" $status -ne 0

# ─── Dry-run is hermetic ─────────────────────────────────────────────────
# `sync --dry-run` must never create a last-wrangle stamp.

# NB: this still invokes wrangle against the REAL working tree (wrangle locates
# its repo from its own script path, which we can't redirect). HOME=$fake_home
# only isolates state files. WRANGLE_NO_BRANCH_SWITCH=1 is belt-and-suspenders
# against the branch-switch pass: dry-run is supposed to skip it (see Pass 1 in
# scripts/wrangle), but if that ever regresses, the env var guarantees this
# test won't switch the developer's HEAD. Proper fixture-based isolation is a
# separate TODO.
set -l fake_home (mktemp -d)
env HOME=$fake_home WRANGLE_NO_BRANCH_SWITCH=1 $wrangle sync --dry-run >/dev/null 2>&1
test -f $fake_home/.cache/dotfiles/last-wrangle
@test "sync --dry-run does NOT create last-wrangle stamp" $status -ne 0
rm -rf $fake_home
