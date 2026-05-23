# Print a blank line just before each command's output, separating the typed
# command line from the output it produces. Counterpart to the `echo` at the
# top of fish_prompt (which separates output from the next prompt).
#
# Skipped on bare Enter (no command), and inside non-interactive shells.

function __dotfiles_blank_before_output --on-event fish_preexec
    status is-interactive; or return
    test -n "$argv[1]"; or return
    echo
end
