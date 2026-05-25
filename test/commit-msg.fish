# Tests for scripts/_commit_msg.fish — the plain (non-claude) commit-message
# builder. The claude path delegates to `_build_commit_msg_via_claude` (which
# shells out to claude and isn't tested here); we stub it so only the
# deterministic paths fire.
#
# Run via `scripts/run-tests` (fishtape).

set -l repo_root (dirname (realpath (status -f)))/..
source $repo_root/scripts/_commit_msg.fish

# Stub the claude path so it never gets reached (the tests pass claude_opt=off
# anyway, but defense-in-depth in case a regression makes the gate forget).
function _build_commit_msg_via_claude
    return 1
end

# ─── 1 change → "wrangle: <change>" ─────────────────────────────────────

set -l msg (_build_commit_msg /nonexistent off "tracked dotfile: .vimrc")
test "$msg" = "wrangle: tracked dotfile: .vimrc"
@test "single change → 'wrangle: <change>'" $status -eq 0

# ─── multi-change → "wrangle: <first> (+N more)" ────────────────────────

set -l msg2 (_build_commit_msg /nonexistent off "tracked dotfile: .vimrc" "tracked fisher plugin: foo" "ignored brew: jq")
test "$msg2" = "wrangle: tracked dotfile: .vimrc (+2 more)"
@test "3 changes → 'wrangle: <first> (+2 more)'" $status -eq 0

set -l msg3 (_build_commit_msg /nonexistent off "a" "b")
test "$msg3" = "wrangle: a (+1 more)"
@test "2 changes → 'wrangle: a (+1 more)'" $status -eq 0

# ─── 0 changes path needs a fixture git repo (it reads the staged diff) ──

set -l fix (mktemp -d)
git -C $fix init -q
git -C $fix config user.email t@t.local
git -C $fix config user.name "t"
git -C $fix commit --allow-empty -q -m init

# 0 changes, 0 staged → "wrangle: sync 0 file(s)" (degenerate; mostly verifies
# the empty-changes branch doesn't crash).
set -l msg4 (_build_commit_msg $fix off)
test "$msg4" = "wrangle: sync 0 file(s)"
@test "0 changes, 0 staged → 'wrangle: sync 0 file(s)'" $status -eq 0

# 0 changes, 1 staged → "wrangle: edit <file>"
echo "hello" > $fix/README.md
git -C $fix add README.md
set -l msg5 (_build_commit_msg $fix off)
test "$msg5" = "wrangle: edit README.md"
@test "0 changes, 1 staged → 'wrangle: edit <file>'" $status -eq 0

# 0 changes, N staged → "wrangle: sync N file(s)"
echo "x" > $fix/a.txt
echo "y" > $fix/b.txt
echo "z" > $fix/c.txt
git -C $fix add a.txt b.txt c.txt
set -l msg6 (_build_commit_msg $fix off)
test "$msg6" = "wrangle: sync 4 file(s)"
@test "0 changes, multi-staged → 'wrangle: sync N file(s)'" $status -eq 0

# ─── cleanup ────────────────────────────────────────────────────────────

rm -rf $fix
functions -e _build_commit_msg_via_claude
