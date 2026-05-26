# wrangle integration — auto-loaded by fish from ~/.config/fish/conf.d/.
#
# Stowed from the dotfiles repo. Provides four things:
#   1. <repo>/scripts/ on $PATH (so `wrangle` and friends are callable)
#   2. Staleness nag if `wrangle` hasn't run in > 7 days
#   3. Unpushed-commits nag (per-shell while you have unpushed commits)
#   4. Update-nag if origin/main has commits not yet merged into current
#      machine-branch (once per unique origin/main SHA)
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

# ── Update-nag ────────────────────────────────────────────────────────────
# Reports if origin/main has commits not yet merged into the current
# machine-branch. Reads last-fetched state only — does NOT fetch (would
# slow every shell start). Wrangle fetches at the start of every sync run,
# so the nag tracks how stale things are between runs.
#
# Only nags once per unique origin/main SHA (cached at
# ~/.cache/dotfiles/pull-nag-state, single-line `main:<sha>` format).
if status is-interactive; and test -z "$WRANGLE_NO_PULL_NAG"; and test -d $_dotfiles_repo/.git
    set -l _mb (command git -C $_dotfiles_repo config wrangle.machine-branch 2>/dev/null)
    test -z "$_mb"; and set _mb personal

    command git -C $_dotfiles_repo rev-parse --verify --quiet origin/main >/dev/null 2>&1
    if test $status -eq 0
        set -l _ahead (command git -C $_dotfiles_repo rev-list --count "$_mb..origin/main" 2>/dev/null)
        if test -n "$_ahead"; and test "$_ahead" -gt 0
            set -l _sha (command git -C $_dotfiles_repo rev-parse origin/main 2>/dev/null)
            set -l _state_file ~/.cache/dotfiles/pull-nag-state
            set -l _cached ""
            test -f $_state_file; and set _cached (grep "^main:" $_state_file 2>/dev/null | head -1 | string replace "main:" '')

            if test "$_cached" != "$_sha"
                # Pluralize manually. `commit(s)` unquoted is a command
                # substitution in fish ("run the command `s`") — must quote.
                set -l _commit_word commit
                test $_ahead -gt 1; and set _commit_word commits
                echo (__wrangle_nag_tag)" framework updates pending. Run "(__wrangle_nag_action 'wrangle update')"."
                echo "  "(__wrangle_nag_name main)" → "(__wrangle_nag_name $_mb)": "(__wrangle_nag_count "$_ahead")" $_commit_word"
                # Record so subsequent shells don't re-nag until origin/main moves.
                mkdir -p (dirname $_state_file)
                echo "main:$_sha" > $_state_file
            end
        end
    end
end

set -e _dotfiles_repo
