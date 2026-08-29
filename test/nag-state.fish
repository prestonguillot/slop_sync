# scripts/_nag_state.fish — the pull-nag state file's format and path.
#
# This file exists because ~/.cache/dotfiles/pull-nag-state has two
# writers: wrangle (after a successful merge) and the shell-start nag
# (after firing, so later shells don't re-nag until origin/main moves).
# Both are load-bearing. When the `main:<sha>` format was hardcoded on
# both sides plus a third time for the read, a drift between them failed
# silently — the read is a grep, so it just misses, and the nag then
# either fires in every shell forever or goes quiet permanently.
#
# These tests pin the round-trip, so a change to the format has to be a
# change to this one file.

set -l repo_root (dirname (realpath (status -f)))/..
source $repo_root/scripts/_nag_state.fish

# Isolate: the functions resolve the path under $HOME, so a fake HOME
# keeps the developer's real nag state untouched.
set -l fake_home (mktemp -d)
set -g __real_home $HOME
set -x HOME $fake_home

# ─── Round-trip ──────────────────────────────────────────────────────────

set -l sha deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
_wrangle_nag_state_write $sha
test (_wrangle_nag_state_read) = "$sha"
@test "a written SHA reads back unchanged" $status -eq 0

# ─── The format both sides depend on ─────────────────────────────────────

test (cat (_wrangle_nag_state_path)) = "main:$sha"
@test "on-disk format is the single line main:<sha>" $status -eq 0

string match -q "*/.cache/dotfiles/pull-nag-state" -- (_wrangle_nag_state_path)
@test "state file path is ~/.cache/dotfiles/pull-nag-state" $status -eq 0

# ─── Missing file reads as empty ─────────────────────────────────────────
# Empty is the safe direction: it makes the nag fire rather than
# silently suppressing it.

rm -f (_wrangle_nag_state_path)
test -z (_wrangle_nag_state_read)
@test "absent state file reads as empty" $status -eq 0

# ─── Writes create the cache dir ─────────────────────────────────────────
# The shell nag can be the first thing to write it on a new machine.

rm -rf $fake_home/.cache
_wrangle_nag_state_write $sha
test -f (_wrangle_nag_state_path)
@test "write creates the cache directory if absent" $status -eq 0

# ─── An empty SHA is not recorded ────────────────────────────────────────
# git rev-parse on a missing ref yields nothing; writing that would pin
# the nag to a bogus value.

rm -f (_wrangle_nag_state_path)
_wrangle_nag_state_write ""
test -f (_wrangle_nag_state_path)
@test "writing an empty SHA records nothing" $status -ne 0

set -x HOME $__real_home
rm -rf $fake_home
