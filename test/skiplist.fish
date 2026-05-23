# Skiplist tests. Source scripts/_skiplist.fish directly and exercise
# _wrangle_load_dotignore + _wrangle_is_skipped against fixture data.
#
# Run via `scripts/run-tests` (fishtape).

set -l repo_root (dirname (realpath (status -f)))/..
source $repo_root/scripts/_skiplist.fish

# ─── _wrangle_load_dotignore: parsing ────────────────────────────────────

set -l fixture (mktemp)
echo "# header comment, ignored" > $fixture
echo "" >> $fixture
echo ".aws" >> $fixture
echo ".config/gh    # trailing comment + whitespace" >> $fixture
echo "    .ssh    " >> $fixture      # leading + trailing whitespace
echo "" >> $fixture
echo "*.pem" >> $fixture
echo "id_*" >> $fixture
echo "  # indented comment, ignored" >> $fixture

set -l entries (_wrangle_load_dotignore $fixture)
rm -f $fixture

@test "load_dotignore returns 5 entries from fixture" (count $entries) -eq 5

contains -- ".aws" $entries
@test "load_dotignore keeps plain entry .aws" $status -eq 0

contains -- ".config/gh" $entries
@test "load_dotignore strips trailing #-comment from .config/gh" $status -eq 0

contains -- ".ssh" $entries
@test "load_dotignore strips leading + trailing whitespace from .ssh" $status -eq 0

contains -- "*.pem" $entries
@test "load_dotignore keeps glob *.pem" $status -eq 0

contains -- "id_*" $entries
@test "load_dotignore keeps glob id_*" $status -eq 0

# Missing file returns empty (not an error).
set -l missing (_wrangle_load_dotignore /tmp/definitely-does-not-exist-$fish_pid)
@test "load_dotignore on missing file returns empty" (count $missing) -eq 0

# ─── _wrangle_is_skipped: exact + prefix matching ───────────────────────

set -l exact_entries .aws .config/gh .ssh

_wrangle_is_skipped .aws $exact_entries
@test "exact match: .aws is skipped" $status -eq 0

_wrangle_is_skipped .aws/credentials $exact_entries
@test "prefix match: .aws/credentials is skipped" $status -eq 0

_wrangle_is_skipped .aws/sub/dir/file $exact_entries
@test "prefix match: nested .aws/sub/dir/file is skipped" $status -eq 0

_wrangle_is_skipped .config/gh $exact_entries
@test "exact match: multi-segment .config/gh is skipped" $status -eq 0

_wrangle_is_skipped .config/gh/hosts.yml $exact_entries
@test "prefix match: .config/gh/hosts.yml is skipped" $status -eq 0

# Path that LOOKS like a prefix but doesn't share a / boundary should NOT match.
# e.g. `.awsthing` is not under `.aws`.
_wrangle_is_skipped .awsthing $exact_entries
@test "exact entry .aws does NOT skip .awsthing (no / boundary)" $status -ne 0

# Non-matching paths.
_wrangle_is_skipped .gitconfig $exact_entries
@test "exact-entry list does not skip .gitconfig" $status -ne 0

_wrangle_is_skipped .config/fish/config.fish $exact_entries
@test "exact-entry list does not skip .config/fish/config.fish" $status -ne 0

# ─── _wrangle_is_skipped: glob matching ─────────────────────────────────

set -l glob_entries '*.pem' 'id_*' '.zcompdump*'

_wrangle_is_skipped foo.pem $glob_entries
@test "glob basename: foo.pem matches *.pem" $status -eq 0

_wrangle_is_skipped .config/secrets/server.pem $glob_entries
@test "glob basename: deep .config/secrets/server.pem matches *.pem" $status -eq 0

_wrangle_is_skipped id_rsa $glob_entries
@test "glob basename: id_rsa matches id_*" $status -eq 0

_wrangle_is_skipped id_ed25519.pub $glob_entries
@test "glob basename: id_ed25519.pub matches id_*" $status -eq 0

_wrangle_is_skipped .zcompdump-host-5.9 $glob_entries
@test "glob basename: .zcompdump-host-5.9 matches .zcompdump*" $status -eq 0

# Negative — glob list shouldn't match arbitrary paths.
_wrangle_is_skipped .gitconfig $glob_entries
@test "glob list does not skip .gitconfig" $status -ne 0

_wrangle_is_skipped .config/fish/config.fish $glob_entries
@test "glob list does not skip .config/fish/config.fish" $status -ne 0

# Fish's `string match` only treats `*` as a wildcard — `?` and `[...]` are
# literal. Entries containing `*` go through the glob branch; others go through
# the exact-or-prefix branch (where `?` and `[` are also literal).

_wrangle_is_skipped 'foo?bar' 'foo?bar'
@test "literal ?: 'foo?bar' is an exact-match entry, matches 'foo?bar'" $status -eq 0

_wrangle_is_skipped 'foofbar' 'foo?bar'
@test "literal ?: 'foo?bar' (no glob) does NOT match 'foofbar'" $status -ne 0

_wrangle_is_skipped 'a' '[abc]'
@test "literal [: '[abc]' is an exact-match entry, does NOT match 'a'" $status -ne 0

# ─── Empty entry list: nothing skipped ───────────────────────────────────

_wrangle_is_skipped .anything
@test "empty entry list: nothing matches" $status -ne 0

# ─── End-to-end with the actual default .dotignore ──────────────────────
# Sanity that the shipped defaults match the paths the README claims they cover.

set -l default_entries (_wrangle_load_dotignore $repo_root/.dotignore)

for p in .aws .aws/credentials .config/gh .config/gh/hosts.yml .ssh .ssh/id_rsa.pub .DS_Store .bash_history
    _wrangle_is_skipped $p $default_entries
    @test "default .dotignore skips $p" $status -eq 0
end

for p in foo.pem .config/some/cert.pem id_rsa id_ed25519.pub
    _wrangle_is_skipped $p $default_entries
    @test "default .dotignore skips $p (via glob)" $status -eq 0
end

for p in .gitconfig .config/fish/config.fish .vim/vimrc .vimrc .config/ghostty/config
    _wrangle_is_skipped $p $default_entries
    @test "default .dotignore does NOT skip $p" $status -ne 0
end
