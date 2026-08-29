# _nag_state.fish — the shell-start pull-nag state file.
#
# Sourced by scripts/wrangle and by
# home/.config/fish/conf.d/wrangle_integration.fish. Don't run directly.
#
# WHY THIS FILE EXISTS
#
# ~/.cache/dotfiles/pull-nag-state has two writers — wrangle records the
# SHA after a successful merge, and the shell nag records it after firing
# so later shells don't re-nag until origin/main moves again. Both are
# load-bearing. But the `main:<sha>` format used to be hardcoded in both
# places plus a third for the read, and nothing errors when they drift:
# the read is a grep, so a format change just misses, and the nag then
# either fires in every shell forever or goes silent permanently. One
# owner for the format removes that failure mode.
#
# The integration file is sourced by every fish shell, including
# non-interactive ones, so this stays small and defines functions only —
# no work at source time. (That constraint is also why the integration
# file keeps its own mini palette rather than reusing wrangle's, which
# lives inside the 2,600-line executable.)
#
# Format: a single line, `main:<sha>`. Absent file or unreadable content
# reads as empty, which makes the nag fire — the safe direction.

# Path to the state file. Single definition; both callers use it.
function _wrangle_nag_state_path
    echo ~/.cache/dotfiles/pull-nag-state
end

# Echo the recorded origin/main SHA, or nothing if there isn't one.
function _wrangle_nag_state_read
    set -l path (_wrangle_nag_state_path)
    test -f $path; or return 0
    grep "^main:" $path 2>/dev/null | head -1 | string replace "main:" ''
end

# Record <sha> as the origin/main the user has already been told about.
function _wrangle_nag_state_write --argument-names sha
    test -z "$sha"; and return 0
    set -l path (_wrangle_nag_state_path)
    mkdir -p (dirname $path)
    echo "main:$sha" > $path
end
