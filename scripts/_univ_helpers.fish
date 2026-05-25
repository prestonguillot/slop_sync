# Pure helpers for the univ-var pass. Currently just _univ_prefix; lives in
# its own file so test/univ-helpers.fish can source it without invoking the
# rest of wrangle. Sister file to _univ_parse.fish (which handles the parsing
# half of the import sub-pass).

# Extract the prefix of a fish universal-variable name. Used by the capture
# sub-pass to group untracked vars by prefix for batch-tracking.
#
# Examples:
#   __fish_X     → "__fish_"
#   _tide_Y      → "_tide_"
#   tide_Z       → "tide_"
#   noprefix     → ""           (no underscore in the name)
#
# Returns empty (no output) for names without an underscore.
function _univ_prefix --argument-names name
    if string match -qr '^__[a-zA-Z0-9]+_' -- $name
        string match -r '^__[a-zA-Z0-9]+_' -- $name
    else if string match -qr '^_[a-zA-Z0-9]+_' -- $name
        string match -r '^_[a-zA-Z0-9]+_' -- $name
    else if string match -qr '^[a-zA-Z0-9]+_' -- $name
        string match -r '^[a-zA-Z0-9]+_' -- $name
    end
end
