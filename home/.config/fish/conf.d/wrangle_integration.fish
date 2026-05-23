# wrangle integration — auto-loaded by fish from ~/.config/fish/conf.d/.
#
# Stowed from the dotfiles repo. Provides four things:
#   1. <repo>/scripts/ on $PATH (so `wrangle` and friends are callable)
#   2. Staleness nag if `wrangle` hasn't run in > 7 days (silence with WRANGLE_NO_STALENESS_NAG=1)
#   3. Unpushed-commits nag (silence with WRANGLE_NO_PUSH_NAG=1)
#   4. Pull-nag if any chain-edge has new upstream commits (silence with WRANGLE_NO_PULL_NAG=1)
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

# Pull-nag: walks the parent chain (per git config) and reports any edge
# with unpulled upstream commits. Reads last-fetched state — does NOT fetch
# (would slow every shell start). Wrangle fetches at the start of every run,
# so the nag tracks how stale things are between runs.
#
# Only nags once per unique upstream SHA — cached at ~/.cache/dotfiles/pull-nag-state.
# When new commits arrive upstream (SHA changes), nags again.
if status is-interactive; and test -z "$WRANGLE_NO_PULL_NAG"; and test -d $_dotfiles_repo/.git
    # Determine the chain by walking branch.<X>.wrangle-parent in git config.
    set -l _mb (command git -C $_dotfiles_repo config wrangle.machine-branch 2>/dev/null)
    test -z "$_mb"; and set _mb personal

    set -l _chain $_mb
    set -l _cur $_mb
    while test -n "$_cur"; and test "$_cur" != main
        set -l _p (command git -C $_dotfiles_repo config "branch.$_cur.wrangle-parent" 2>/dev/null)
        test -z "$_p"; and set _p main
        set _chain $_p $_chain
        set _cur $_p
    end

    # For each (parent, child) edge, count unmerged commits and check cache.
    set -l _state_file ~/.cache/dotfiles/pull-nag-state
    set -l _lines
    set -l _need_update no
    if test (count $_chain) -ge 2
        for _i in (seq 1 (math (count $_chain) - 1))
            set -l _parent $_chain[$_i]
            set -l _child $_chain[(math $_i + 1)]
            set -l _parent_ref origin/$_parent
            command git -C $_dotfiles_repo rev-parse --verify --quiet $_parent_ref >/dev/null 2>&1
            or set _parent_ref $_parent
            set -l _ahead (command git -C $_dotfiles_repo rev-list --count "$_child..$_parent_ref" 2>/dev/null)
            test -z "$_ahead"; or test "$_ahead" -eq 0; and continue
            # Check cache: have we already nagged about this exact upstream SHA?
            set -l _sha (command git -C $_dotfiles_repo rev-parse $_parent_ref 2>/dev/null)
            set -l _cached ""
            if test -f $_state_file
                set _cached (grep "^$_parent:" $_state_file 2>/dev/null | head -1 | string replace "$_parent:" '')
            end
            if test "$_cached" = "$_sha"
                continue   # already nagged about this SHA, skip
            end
            set _lines $_lines "    $_parent → $_child: $_ahead new commit(s)"
            set _need_update yes
        end
    end

    if test (count $_lines) -gt 0
        echo "⚠  upstream changes pending — run \`wrangle --pull\`:"
        for _l in $_lines
            echo "$_l"
        end
        echo "   (silence with WRANGLE_NO_PULL_NAG=1)"
    end

    # Update the nag cache with current SHAs (whether we nagged or not, so
    # subsequent shells see what we last surfaced).
    if test "$_need_update" = yes
        mkdir -p (dirname $_state_file)
        set -l _tmp (mktemp)
        if test (count $_chain) -ge 2
            for _i in (seq 1 (math (count $_chain) - 1))
                set -l _parent $_chain[$_i]
                set -l _parent_ref origin/$_parent
                command git -C $_dotfiles_repo rev-parse --verify --quiet $_parent_ref >/dev/null 2>&1
                or set _parent_ref $_parent
                set -l _sha (command git -C $_dotfiles_repo rev-parse $_parent_ref 2>/dev/null)
                test -n "$_sha"; and echo "$_parent:$_sha" >> $_tmp
            end
        end
        mv $_tmp $_state_file
    end
end

set -e _dotfiles_repo
