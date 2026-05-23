# Skiplist helpers for wrangle's dotfile pass.
# Sourced by `scripts/wrangle` and `test/skiplist.fish`. Don't run directly.
#
# Two functions:
#   _wrangle_load_dotignore <file> → emits one cleaned entry per line
#     (strips trailing #-comments, leading/trailing whitespace, blank lines).
#   _wrangle_is_skipped <rel> <entry...> → returns 0 if <rel> matches any entry.
#     Entries containing `*` are matched as fish globs against basename OR
#     full path. Other entries match by exact path or directory prefix.
#     (Note: fish's `string match` only treats `*` as a wildcard, not `?` or
#     `[...]`. Those characters are taken literally.)

function _wrangle_load_dotignore --argument-names file
    test -f $file; or return 0
    sed -E 's/[[:space:]]*#.*$//' $file \
        | sed -E 's/^[[:space:]]+//' \
        | sed -E 's/[[:space:]]+$//' \
        | grep -v '^[[:space:]]*$'
end

function _wrangle_is_skipped
    set -l rel $argv[1]
    set -l entries $argv[2..-1]
    for s in $entries
        if string match -q '*\**' -- $s
            # Glob: match basename OR full path.
            if string match -q -- $s (basename $rel); or string match -q -- $s $rel
                return 0
            end
        else
            # Exact path or directory prefix.
            if test "$rel" = "$s"; or string match -q -- "$s/*" $rel
                return 0
            end
        end
    end
    return 1
end
