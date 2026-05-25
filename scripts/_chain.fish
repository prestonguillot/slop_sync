# Parent-chain helpers. Resolve which branch this machine commits to, and
# walk the per-branch `wrangle-parent` chain that drives `wrangle pull`'s
# cascade-merge. Extracted from scripts/wrangle so test/chain.fish can
# exercise them against a fixture git repo.
#
# Branch metadata lives in git config (per-clone, not pushed):
#   wrangle.machine-branch <branch>                  # this machine's branch
#   branch.<name>.wrangle-parent <parent>            # empty/main = root chain
#
# All three helpers take the repo path as the first arg (vs the previous
# `--inherit-variable repo`) so tests can pass in a fixture repo.

# Return the configured machine-branch for this clone, defaulting to `personal`.
function _wrangle_machine_branch --argument-names repo
    set -l mb (git -C $repo config wrangle.machine-branch 2>/dev/null)
    test -z "$mb"; and set mb personal
    echo $mb
end

# Return the parent of a given branch, or status 1 if it has none.
# Hardcoded rule: `main` is always the chain root.
# Default when unset: `main` (backward-compat for setups predating the
# parent-chain feature).
function _wrangle_parent_of --argument-names repo branch
    test -z "$branch"; and return 1
    test "$branch" = main; and return 1
    set -l p (git -C $repo config "branch.$branch.wrangle-parent" 2>/dev/null)
    if test -z "$p"
        echo main
    else
        echo $p
    end
end

# Walk the parent chain root-toward-leaf. Returns the chain as a list,
# one branch per line. E.g. for `work` with `work → personal → main`:
#   main
#   personal
#   work
function _wrangle_chain_for --argument-names repo branch
    set -l chain
    set -l cur $branch
    while test -n "$cur"
        set chain $cur $chain
        set cur (_wrangle_parent_of $repo $cur)
    end
    for b in $chain
        echo $b
    end
end
