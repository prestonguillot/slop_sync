# .fisherignore tests. Source scripts/_skiplist.fish (the fisher pass reuses
# _wrangle_load_dotignore for parsing) and exercise the loader + the exact
# `contains --` filter primitive wrangle uses against fixture data.
#
# Run via `scripts/run-tests` (fishtape).

set -l repo_root (dirname (realpath (status -f)))/..
source $repo_root/scripts/_skiplist.fish

# ─── _wrangle_load_dotignore: parsing for fisher plugin identifiers ─────

set -l fixture (mktemp)
echo "# header comment, ignored" > $fixture
echo "PatrickF1/fzf.fish" >> $fixture
echo "" >> $fixture
echo "jorgebucaran/autopair.fish    # trailing comment" >> $fixture
echo "  # indented comment, ignored" >> $fixture

set -l entries (_wrangle_load_dotignore $fixture)
rm -f $fixture

@test ".fisherignore loads 2 plugin entries from fixture" (count $entries) -eq 2

contains -- "PatrickF1/fzf.fish" $entries
@test ".fisherignore keeps plain plugin entry" $status -eq 0

contains -- "jorgebucaran/autopair.fish" $entries
@test ".fisherignore strips trailing #-comment from plugin entry" $status -eq 0

# ─── `contains --` filter primitive (what the fisher pass uses) ─────────
# wrangle filters `fisher list` and `fish_plugins` with `contains --`, not
# the glob-based _wrangle_is_skipped. Verify exact-match semantics:
# - An ignored plugin matches the ignore list.
# - A non-ignored plugin does not.
# - A near-miss substring does not match (exact match only).

set -l ignores PatrickF1/fzf.fish jorgebucaran/autopair.fish

contains -- "PatrickF1/fzf.fish" $ignores
@test "fisher filter: ignored plugin matches" $status -eq 0

contains -- "ilancosman/tide@v6" $ignores
@test "fisher filter: non-ignored plugin does not match" $status -ne 0

contains -- "fzf.fish" $ignores
@test "fisher filter: bare substring does not match (exact-only)" $status -ne 0

# ─── Missing file returns empty (not an error) ──────────────────────────
set -l missing (_wrangle_load_dotignore /tmp/definitely-does-not-exist-$fish_pid)
@test ".fisherignore missing file returns empty" (count $missing) -eq 0

# ─── End-to-end: shipped default .fisherignore on main is a clean template ─
# The shipped file is comment-only — users populate it by answering [i]gnore
# in a fisher pass. Should parse to zero entries.
set -l default_entries (_wrangle_load_dotignore $repo_root/.fisherignore)
@test "shipped .fisherignore parses to zero user entries (template only)" (count $default_entries) -eq 0
