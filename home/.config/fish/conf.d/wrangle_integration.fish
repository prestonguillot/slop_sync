# wrangle integration — auto-loaded by fish from ~/.config/fish/conf.d/.
#
# Stowed from the dotfiles repo. Provides three things:
#   1. <repo>/scripts/ on $PATH (so `wrangle` and friends are callable)
#   2. Staleness nag if `wrangle` hasn't run in > 7 days (silence with WRANGLE_NO_STALENESS_NAG=1)
#   3. Unpushed-commits nag (silence with WRANGLE_NO_PUSH_NAG=1)
#
# To remove cleanly: `cd <repo> && stow -t ~ -D home`, or just delete the symlink.

# Locate the repo via the symlink's realpath (this file is a symlink into the repo).
set -l _dotfiles_repo (realpath (status -f) | string replace -r '/home/\.config/fish/conf\.d/wrangle_integration\.fish$' '')
if test -d $_dotfiles_repo/scripts
    set -x PATH $PATH $_dotfiles_repo/scripts
end

if status is-interactive; and test -z "$WRANGLE_NO_STALENESS_NAG"
    set -l _stamp ~/.cache/dotfiles/last-wrangle
    set -l _max_age 604800
    if not test -f $_stamp
        echo "⚠  wrangle has never run on this machine — run it to baseline dotfile + brew tracking. Silence with WRANGLE_NO_STALENESS_NAG=1."
    else
        set -l _age (math (date +%s) - (stat -f '%m' $_stamp))
        if test $_age -gt $_max_age
            echo "⚠  wrangle last ran "(math --scale=0 $_age / 86400)" days ago — run it to check for drift. Silence with WRANGLE_NO_STALENESS_NAG=1."
        end
    end
end

# Unpushed-commits nag. Asks git directly so it stays accurate even if you
# push outside wrangle (manual `git push`, push from another machine, etc.).
# Quiet if no upstream is configured or repo is in a weird state.
if status is-interactive; and test -z "$WRANGLE_NO_PUSH_NAG"; and test -d $_dotfiles_repo/.git
    set -l _ahead (command git -C $_dotfiles_repo rev-list --count '@{u}..HEAD' 2>/dev/null)
    if test -n "$_ahead"; and test $_ahead -gt 0
        echo "⚠  dotfiles repo has $_ahead unpushed commit(s). Push when ready (or set WRANGLE_NO_PUSH_NAG=1 to silence)."
    end
end

set -e _dotfiles_repo
