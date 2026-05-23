# enabled vim mode, fuck it we ball
fish_vi_key_bindings

######## PATH ########

set -x PATH $HOME/bin $PATH
set -x PATH $PATH $HOME/.local/bin
set -x PATH $PATH /sbin /usr/sbin

# Add this repo's scripts/ to PATH. config.fish is a symlink into the dotfiles
# repo (via stow), so realpath gives us the actual location regardless of where
# you cloned the repo. Walk up: …/repo/home/.config/fish/config.fish → …/repo.
set -l _dotfiles_repo (realpath (status -f) | string replace -r '/home/\.config/fish/config\.fish$' '')
if test -d $_dotfiles_repo/scripts
    set -x PATH $PATH $_dotfiles_repo/scripts
end
set -e _dotfiles_repo

######## Shell behavior ########

set fish_greeting

# History settings (preserved from prior config)
set -g fish_history_ignore_duplicates yes
set -g fish_history_ignore_space yes
set -g history_max_size 2000

######## Aliases & functions ########

alias cls clear
alias ll 'eza -la --git --icons'
alias la 'eza -a --icons'
alias l 'eza --icons'
alias ls 'eza --icons'
alias h 'cd ~'

alias htop btop
alias cat 'bat --paging=never'

function hey --description 'claude -p with auto-quoted prompt'
    claude -p "$argv"
end

# Show tldr first; fall back to real man if no tldr page exists.
function man --description 'tldr first, real man as fallback'
    if command -q tldr; and command tldr $argv 2>/dev/null
        return 0
    end
    command man $argv
end

######## Integrations ########

# Locate brew across Apple Silicon (/opt/homebrew) and Intel (/usr/local) — the
# eval bootstraps PATH so subsequent `brew` / `fish` invocations resolve naturally.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew
    if test -x $_brew
        eval ($_brew shellenv)
        break
    end
end
set -e _brew

# zoxide: smart cd. `cd foo` falls back to frecent-jump if foo isn't a real path.
if command -q zoxide
    zoxide init fish --cmd cd | source
end

# direnv: per-directory .envrc auto-loading.
if command -q direnv
    direnv hook fish | source
end

# fnm: Fast Node Manager (preserved — Node tooling already installed locally)
if command -q fnm
    fnm env --use-on-cd | source
end

# Nag if `wrangle` hasn't run in > 7 days (catches drifted dotfiles + brew state).
if status is-interactive
    set -l _stamp ~/.cache/dotfiles/last-wrangle
    set -l _max_age 604800  # 7 days
    if not test -f $_stamp
        echo "⚠  wrangle has never run on this machine — run it to baseline dotfile + brew tracking."
    else
        set -l _age (math (date +%s) - (stat -f '%m' $_stamp))
        if test $_age -gt $_max_age
            echo "⚠  wrangle last ran "(math --scale=0 $_age / 86400)" days ago — run it to check for drift."
        end
    end
end

# Nag if wrangle made changes the user hasn't pushed yet. Dismissable.
if status is-interactive; and test -z "$WRANGLE_NO_PUSH_NAG"
    if test -f ~/.cache/dotfiles/unpushed
        echo "⚠  dotfiles repo has unpushed commits. Push when ready (or set WRANGLE_NO_PUSH_NAG=1 to silence)."
    end
end
