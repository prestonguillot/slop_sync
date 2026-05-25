# Self-validating tests for scripts/wrangle's FILE STRUCTURE table of contents.
#
# Parses the ToC out of the script at runtime (does NOT maintain a separate
# copy here) and verifies two invariants:
#
#   1. LABEL RESOLUTION — every parsed ToC entry's label appears verbatim in a
#      `# ─── <label> ───` divider somewhere in the file. Catches drift in
#      either direction (renamed divider without ToC update, or vice versa).
#
#   2. NUMBERING WELL-ORDERED — top-level entries are 1, 2, 3, ... contiguous.
#      Within a top-level N, sub-entries (if any) are N.1, N.2, N.3, ...
#      contiguous. No gaps, no duplicates, no irregular tokens (1a, 1.5, etc.).
#
# Run via `scripts/run-tests` (fishtape).

set -l wrangle_path (dirname (realpath (status -f)))/../scripts/wrangle

# ─── Parser: walk the FILE STRUCTURE block, emit "<num>|<label>" per entry ──

function _parse_toc --argument-names path
    set -l in_toc no
    while read -l line
        if string match -q "# ── FILE STRUCTURE ───*" -- $line
            set in_toc yes
            continue
        end
        if test "$in_toc" = yes; and string match -q "# ─── *" -- $line
            return
        end
        test "$in_toc" = yes; or continue

        # Inside the ToC block. ToC entries look like:
        #   "#   1. <label>"           (top-level: digit followed by dot)
        #   "#      5.1 <label>"       (sub-level: digit.digit)
        # Description prose (e.g. "# Sections in reading order. ...") doesn't
        # start with a digit token, so the trailing numbering filter skips it.
        set -l m (string match -r '^#\s+(\S+)\s+(.+?)\s*$' -- $line)
        test (count $m) -eq 3; or continue
        set -l num $m[2]
        set -l label $m[3]
        string match -qr '^[0-9]+(\.[0-9]+)?\.?$' -- $num; or continue
        echo "$num|$label"
    end < $path
end

set -l toc (_parse_toc $wrangle_path)

# Sanity: parser found a reasonable number of entries. If this drops
# unexpectedly, the parser regex probably broke on a ToC format tweak.
@test "ToC parser: at least 20 entries extracted from FILE STRUCTURE block" (count $toc) -ge 20

# ─── Invariant 1: every label resolves to an in-file divider ────────────

for entry in $toc
    set -l parts (string split -m 1 "|" -- $entry)
    set -l label $parts[2]
    grep -qF "# ─── $label" $wrangle_path
    @test "ToC label resolves to in-file divider: $label" $status -eq 0
end

# ─── Invariant 2: numbering well-ordered ────────────────────────────────

set -l errors
set -l expected_top 0
set -l expected_sub 0

for entry in $toc
    set -l parts (string split -m 1 "|" -- $entry)
    set -l num $parts[1]
    set -l label $parts[2]
    # Normalize: top-level tokens have a trailing dot ("5."), sub-level don't ("5.1").
    set -l norm (string replace -r '\.$' '' -- $num)

    if string match -qr '^[0-9]+$' -- $norm
        # Top-level
        set expected_top (math $expected_top + 1)
        set expected_sub 0
        if test "$norm" != "$expected_top"
            set -a errors "expected top-level $expected_top, got $num ($label)"
        end
    else if string match -qr '^[0-9]+\.[0-9]+$' -- $norm
        # Sub-level: <top>.<sub>
        set -l np (string split -m 1 "." -- $norm)
        set -l t $np[1]
        set -l s $np[2]
        set expected_sub (math $expected_sub + 1)
        if test "$t" != "$expected_top"
            set -a errors "sub $num under wrong parent (current top=$expected_top, label=$label)"
        end
        if test "$s" != "$expected_sub"
            set -a errors "expected $expected_top.$expected_sub, got $num ($label)"
        end
    else
        set -a errors "malformed numbering token: $num ($label)"
    end
end

# Surface specific issues to stderr so fishtape's output shows what broke.
if test (count $errors) -gt 0
    for e in $errors
        echo "  toc-sync: $e" >&2
    end
end
@test "ToC numbering is contiguous at each level (1,2,3...; 5.1,5.2,5.3...)" (count $errors) -eq 0
