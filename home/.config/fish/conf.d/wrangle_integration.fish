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
set -e _dotfiles_repo

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

if status is-interactive; and test -z "$WRANGLE_NO_PUSH_NAG"
    if test -f ~/.cache/dotfiles/unpushed
        echo "⚠  dotfiles repo has unpushed commits. Push when ready (or set WRANGLE_NO_PUSH_NAG=1 to silence)."
    end
end
