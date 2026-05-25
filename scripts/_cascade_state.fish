# Cascade-state I/O helpers. The pull cascade (`wrangle pull`) writes/reads
# two small state files under ~/.cache/dotfiles/:
#
#   pull-cascade-state  — set when a cascade hits a merge conflict; consumed
#                         by `wrangle pull --resume`.
#                         Format: first line "ORIGINAL_BRANCH:<name>"
#                                 followed by remaining "parent:child" edges,
#                                 one per line.
#
#   pull-nag-state      — records SHAs of successfully-merged parents so the
#                         shell-start pull nag doesn't re-fire for the same
#                         commits. Format: "parent:<sha>" lines.
#
# Extracted from scripts/wrangle so test/cascade-state.fish can exercise the
# file I/O directly. State-file paths are explicit first args (vs the
# previous `--inherit-variable pull_cascade_state` / `pull_nag_state`) so
# tests can use mktemp paths.

# Write cascade-resume state. argv[1] = original branch (where to land back),
# argv[2..-1] = remaining "parent:child" edges.
function _wrangle_save_cascade_state --argument-names path
    set -l original $argv[2]
    set -l remaining_edges $argv[3..-1]
    echo "ORIGINAL_BRANCH:$original" > $path
    for edge in $remaining_edges
        echo $edge >> $path
    end
end

# Delete the cascade state file (called after a successful resume).
function _wrangle_clear_cascade_state --argument-names path
    rm -f $path
end

# Record that `parent` was successfully merged by appending its origin/<parent>
# SHA to the nag-state file. If a record for `parent` already exists, it's
# overwritten (newest wins). Silently no-ops if `origin/<parent>` doesn't
# resolve (e.g. brand-new branch not yet pushed).
#
# Args: <state-path> <repo-path> <parent-branch>
function _wrangle_record_pull_nag --argument-names path repo parent
    # `--verify` is load-bearing: without it, `git rev-parse origin/missing`
    # echoes the literal ref name to stdout (exit 128) and we'd write a bogus
    # SHA. With --verify, missing refs produce empty stdout, which `test -z`
    # catches.
    set -l sha (git -C $repo rev-parse --verify origin/$parent 2>/dev/null)
    test -z "$sha"; and return
    set -l tmp (mktemp)
    if test -f $path
        grep -v "^$parent:" $path > $tmp 2>/dev/null
    end
    echo "$parent:$sha" >> $tmp
    mv $tmp $path
end
