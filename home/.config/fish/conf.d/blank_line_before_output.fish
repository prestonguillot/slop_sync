# Print a blank line just before each command's output, separating the typed
# command line from the output it produces. Orthogonal to tide's
# `tide_prompt_add_newline_before` (which separates output from the NEXT
# prompt) — this hook separates the typed command from its OWN output.
#
# Skipped on bare Enter (no command), and inside non-interactive shells.

function __dotfiles_blank_before_output --on-event fish_preexec
    status is-interactive; or return
    test -n "$argv[1]"; or return
    echo
end
