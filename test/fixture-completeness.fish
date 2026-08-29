# Assert the shared fixture installs every script wrangle actually needs.
#
# The failure this guards is quiet by nature. Fish's `source` on a missing
# file warns to stderr and keeps going, so a fixture that omits a sourced
# unit still runs — the function is simply undefined until something calls
# it. A test suite can stay fully green while every fixture is broken.
#
# Rather than trust a hand-maintained list, this derives the requirement
# from the source: every `$repo/scripts/<name>` reference in wrangle and in
# the units it sources must end up in a fixture's scripts/ directory.

set -l repo_root (dirname (realpath (status -f)))/..
source $repo_root/test/helpers/fixture.fish

# ─── Derive what wrangle references ──────────────────────────────────────
# Matches both `source $repo/scripts/_foo.fish` and bare shell-outs like
# `$repo/scripts/scan-secrets`.

set -l required (grep -ohE '\$repo/scripts/[a-z_-]+(\.fish)?' \
                     $repo_root/scripts/wrangle $repo_root/scripts/_*.fish \
                 | string replace -r '.*/' '' | sort -u)

test (count $required) -gt 0
@test "found at least one referenced script to check" $status -eq 0

# ─── Build a fixture and check each one landed ───────────────────────────

set -l fix (mktemp -d)
_wrangle_fixture_install_scripts $fix $repo_root

for name in $required
    test -f $fix/scripts/$name
    @test "fixture installs $name" $status -eq 0
end

# wrangle itself is referenced by path, not via $repo/scripts, so check it
# separately.
test -f $fix/scripts/wrangle
@test "fixture installs wrangle" $status -eq 0

rm -rf $fix

# ─── A fixture run emits no source errors ────────────────────────────────
# The direct form of the same check: run wrangle inside a fixture and
# assert fish never complained about a file it could not source.

set -l fix2 (mktemp -d)
set -l home2 (mktemp -d)
_wrangle_fixture_init_repo $fix2 "fixture-completeness-test" main
_wrangle_fixture_install_scripts $fix2 $repo_root
_wrangle_fixture_seed_files $fix2 $repo_root empty
git -C $fix2 add -A
git -C $fix2 commit -q -m "fixture seed"
git -C $fix2 checkout -q -b personal

set -l err (env HOME=$home2 $fix2/scripts/wrangle status 2>&1 >/dev/null | string join \n)

string match -q "*Error encountered while sourcing*" -- "$err"
@test "fixture run emits no sourcing errors" $status -ne 0

string match -q "*Unknown command*" -- "$err"
@test "fixture run hits no undefined functions" $status -ne 0

rm -rf $fix2 $home2
