# wrangle integration — auto-loaded by fish from ~/.config/fish/conf.d/.
#
# Stowed from the dotfiles repo. Provides four things:
#   1. <repo>/scripts/ on $PATH (so `wrangle` and friends are callable)
#   2. Staleness nag if `wrangle` hasn't run in > 7 days
#   3. Unpushed-commits nag (per-shell while you have unpushed commits)
#   4. Pull-nag if any chain-edge has new upstream commits (once per unique upstream SHA)
#
# Silencer env vars exist (see README) but are deliberately NOT advertised in
# the nag text — the nags are designed to fire only when they have something
# new to say, so silencing is a niche customization, not a daily-driver knob.
#
# To remove cleanly: `cd <repo> && stow -t ~ -D home`, or just delete the symlink.

# Locate the repo via the symlink's realpath (this file is a symlink into the repo).
set -l _dotfiles_repo (realpath (status -f) | string replace -r '/home/\.config/fish/conf\.d/wrangle_integration\.fish$' '')
if test -d $_dotfiles_repo/scripts
    set -x PATH $PATH $_dotfiles_repo/scripts
end

# ── Nag-styling helpers ───────────────────────────────────────────────────
# Mini palette mirroring wrangle's own (palette lives in scripts/wrangle but
# this file can't source it — runs in every shell, including non-interactive).
function __wrangle_nag_tag    ; printf '%s%swrangle:%s' (set_color yellow) (set_color --bold) (set_color normal); end
function __wrangle_nag_name   ; printf '%s%s%s' (set_color cyan) "$argv" (set_color normal); end
function __wrangle_nag_count  ; printf '%s%s%s' (set_color --bold) "$argv" (set_color normal); end
function __wrangle_nag_action ; printf '%s%s%s' (set_color brblack) "$argv" (set_color normal); end

# ── Staleness nag ─────────────────────────────────────────────────────────
if status is-interactive; and test -z "$WRANGLE_NO_STALENESS_NAG"
    set -l _stamp ~/.cache/dotfiles/last-wrangle
    set -l _max_age 604800
    if not test -f $_stamp
        echo (__wrangle_nag_tag)" never run on this machine. Run "(__wrangle_nag_action 'wrangle sync')" to baseline."
    else
        set -l _age (math (date +%s) - (stat -f '%m' $_stamp))
        if test $_age -gt $_max_age
            set -l _days (math --scale=0 $_age / 86400)
            echo (__wrangle_nag_tag)" last ran "(__wrangle_nag_count "$_days days")" ago. Run "(__wrangle_nag_action 'wrangle sync')" to check for drift."
        end
    end
end

# ── Unpushed-commits nag ──────────────────────────────────────────────────
# Asks git directly so it stays accurate even if you pushed outside wrangle.
# Quiet if no upstream is configured or repo is in a weird state.
if status is-interactive; and test -z "$WRANGLE_NO_PUSH_NAG"; and test -d $_dotfiles_repo/.git
    set -l _ahead (command git -C $_dotfiles_repo rev-list --count '@{u}..HEAD' 2>/dev/null)
    if test -n "$_ahead"; and test $_ahead -gt 0
        set -l _branch (command git -C $_dotfiles_repo rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo (__wrangle_nag_tag)" "(__wrangle_nag_count "$_ahead")" unpushed commit(s) on "(__wrangle_nag_name $_branch)". Run "(__wrangle_nag_action 'wrangle push')"."
    end
end

# ── Pull-nag ──────────────────────────────────────────────────────────────
# Walks the parent chain (per git config) and reports any edge with unpulled
# upstream commits. Reads last-fetched state — does NOT fetch (would slow
# every shell start). Wrangle fetches at the start of every sync run, so the
# nag tracks how stale things are between runs.
#
# Only nags once per unique upstream SHA (cached at ~/.cache/dotfiles/pull-nag-state).
# When new commits arrive upstream, nags again. By design, the silencer env
# var is rarely needed — the nag self-suppresses for already-seen news.
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
            # Format: "  main → personal: 1 commit" / "  main → personal: 2 commits"
            # NB: must double-quote pluralization. `commit(s)` unquoted is a
            # command substitution in fish ("run the command `s`"), which is
            # how this code shipped buggy in v1.6.0 and went unnoticed until
            # someone hit the >1-commit branch.
            set -l _commit_word commit
            test $_ahead -gt 1; and set _commit_word commits
            set _lines $_lines "  "(__wrangle_nag_name $_parent)" → "(__wrangle_nag_name $_child)": "(__wrangle_nag_count "$_ahead")" $_commit_word"
            set _need_update yes
        end
    end

    if test (count $_lines) -gt 0
        echo (__wrangle_nag_tag)" upstream changes pending. Run "(__wrangle_nag_action 'wrangle pull')"."
        for _l in $_lines
            echo "$_l"
        end
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
