# Tests for scripts/_cascade_state.fish — pull-cascade resume state +
# pull-nag SHA tracking. Exercises the file I/O against mktemp paths.
#
# Run via `scripts/run-tests` (fishtape).

set -l repo_root (dirname (realpath (status -f)))/..
source $repo_root/scripts/_cascade_state.fish

# ─── _wrangle_save_cascade_state ────────────────────────────────────────

set -l state (mktemp)

_wrangle_save_cascade_state $state personal main:personal personal:work
test (head -1 $state) = "ORIGINAL_BRANCH:personal"
@test "save_cascade_state: first line is ORIGINAL_BRANCH:<name>" $status -eq 0

set -l edges (tail -n +2 $state)
@test "save_cascade_state: 2 edge lines written" (count $edges) -eq 2
test "$edges[1]" = "main:personal"; and test "$edges[2]" = "personal:work"
@test "save_cascade_state: edges preserved in order" $status -eq 0

# Overwriting an existing state file replaces contents (vs appending).
_wrangle_save_cascade_state $state laptop main:laptop
set -l lines (cat $state | string collect | string split \n)
@test "save_cascade_state: rewriting yields 2 total lines (header + 1 edge)" (count $lines) -eq 2

# ─── _wrangle_clear_cascade_state ───────────────────────────────────────

_wrangle_clear_cascade_state $state
@test "clear_cascade_state: file removed" (test -f $state; echo $status) -ne 0

# Clearing a missing file is a no-op (no error).
_wrangle_clear_cascade_state $state
@test "clear_cascade_state: no error on missing file" $status -eq 0

# ─── _wrangle_record_pull_nag against a fixture repo ────────────────────

set -l fix (mktemp -d)
git -C $fix init -q
git -C $fix config user.email test@test.local
git -C $fix config user.name "test"
git -C $fix commit --allow-empty -q -m init

# Set up a fake "origin/main" by creating refs/remotes/origin/main → HEAD.
set -l head_sha (git -C $fix rev-parse HEAD)
git -C $fix update-ref refs/remotes/origin/main $head_sha
git -C $fix update-ref refs/remotes/origin/personal $head_sha

set -l nag (mktemp)
rm -f $nag    # start with no nag file

_wrangle_record_pull_nag $nag $fix main
test -f $nag
@test "record_pull_nag: creates nag file on first call" $status -eq 0

set -l line (head -1 $nag)
test "$line" = "main:$head_sha"
@test "record_pull_nag: writes 'parent:<sha>' line" $status -eq 0

# Record a second parent — should append.
_wrangle_record_pull_nag $nag $fix personal
set -l count (count (cat $nag | string collect | string split \n))
@test "record_pull_nag: appends a second parent line" $count -eq 2

# Re-record same parent → overwrites, doesn't double-add.
_wrangle_record_pull_nag $nag $fix main
set -l count2 (count (cat $nag | string collect | string split \n))
@test "record_pull_nag: re-recording same parent does NOT duplicate" $count2 -eq 2

# Recording for a non-existent origin/branch silently no-ops (file unchanged).
set -l before (cat $nag | string collect)
_wrangle_record_pull_nag $nag $fix nonexistent
set -l after (cat $nag | string collect)
test "$before" = "$after"
@test "record_pull_nag: missing origin/<branch> silently no-ops" $status -eq 0

# ─── cleanup ────────────────────────────────────────────────────────────

rm -f $state $nag
rm -rf $fix
