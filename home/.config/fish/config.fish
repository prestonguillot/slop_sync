# enabled vim mode, fuck it we ball.
# Set the variable instead of calling the function directly so plugins that
# listen via `--on-variable fish_key_bindings` (e.g. autopair.fish) get
# notified and register their bindings in vi insert mode.
set -g fish_key_bindings fish_vi_key_bindings

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

# Suppress the `(venvname)` prompt prefix that venv's activate.fish would
# otherwise inject — tide already renders the active virtualenv on its own.
set -gx VIRTUAL_ENV_DISABLE_PROMPT 1

######## Aliases & functions ########

alias cls clear
alias ll 'eza -la --git --icons'
alias lla 'eza -la --git --icons -a'
alias la 'eza -a --icons'
alias l 'eza --icons'
alias ls 'eza --icons'
function lr --description 'eza -R with depth (default 1)'
    set -l depth 1
    if test (count $argv) -gt 0; and string match -qr '^\d+$' -- $argv[1]
        set depth $argv[1]
        set -e argv[1]
    end
    eza -R -L $depth --icons $argv
end
function lt --description 'eza -T with depth (default 1)'
    set -l depth 1
    if test (count $argv) -gt 0; and string match -qr '^\d+$' -- $argv[1]
        set depth $argv[1]
        set -e argv[1]
    end
    eza -T -L $depth --icons $argv
end
function lra --description 'eza -aR with depth (default 1)'
    set -l depth 1
    if test (count $argv) -gt 0; and string match -qr '^\d+$' -- $argv[1]
        set depth $argv[1]
        set -e argv[1]
    end
    eza -aR -L $depth --icons $argv
end
function lta --description 'eza -aT with depth (default 1)'
    set -l depth 1
    if test (count $argv) -gt 0; and string match -qr '^\d+$' -- $argv[1]
        set depth $argv[1]
        set -e argv[1]
    end
    eza -aT -L $depth --icons $argv
end
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

# (staleness + unpushed nags live in conf.d/wrangle_integration.fish — framework-owned)
