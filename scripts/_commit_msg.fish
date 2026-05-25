# Commit-message builder for wrangle's commit pass. Extracted from
# scripts/wrangle so test/commit-msg.fish can exercise the deterministic
# (non-claude) paths in isolation.
#
# Strategy:
#   1 change         → "wrangle: <change>"
#   claude opt-in    → ask claude (lives in scripts/wrangle, shells out)
#   0 changes, 1 staged file  → "wrangle: edit <file>"
#   0 changes, N staged files → "wrangle: sync N file(s)"
#   N changes        → "wrangle: <first change> (+N-1 more)"
#
# Args:
#   $1 = repo path
#   $2 = claude_opt ("on" / "off")
#   $3..-1 = changes (each one a short string like "tracked dotfile: .vimrc")
#
# The claude path delegates to `_build_commit_msg_via_claude` (still defined
# in scripts/wrangle since it shells out to the claude CLI). Tests stub that
# function with a `return 1` no-op and pass `claude_opt=off` to exercise the
# deterministic paths only.

function _build_commit_msg --argument-names repo claude_opt
    set -l changes $argv[3..-1]
    set -l n (count $changes)

    if test $n -eq 1
        echo "wrangle: $changes[1]"
        return
    end

    if test "$claude_opt" = on; and command -q claude
        set -l msg (_build_commit_msg_via_claude $repo $changes)
        if test $status -eq 0; and test -n "$msg"
            echo $msg
            return
        end
    end

    # Heuristic fallback
    if test $n -eq 0
        set -l file_count (git -C $repo diff --cached --name-only 2>/dev/null | count)
        if test $file_count -eq 1
            set -l f (git -C $repo diff --cached --name-only | head -1)
            echo "wrangle: edit $f"
        else
            echo "wrangle: sync $file_count file(s)"
        end
        return
    end

    echo "wrangle: $changes[1] (+"(math $n - 1)" more)"
end
