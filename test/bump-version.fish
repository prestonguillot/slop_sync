# bump-version arithmetic tests. Run via `scripts/run-tests` (fishtape).
#
# Sets up a temp git repo with a known v* tag and runs bump-version --dry-run
# to verify the next-version calculation. Doesn't actually create tags.

set -l bump (dirname (realpath (status -f)))/../scripts/bump-version

# Helper: spin up a temp main-branch repo with one tag.
function _make_versioned_repo --argument-names tag
    set -l tmp (mktemp -d)
    cd $tmp
    git init -q -b main
    git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "init"
    git tag -a "$tag" -m "$tag" 2>/dev/null
    mkdir -p scripts
    echo $tmp
end

# Helper: extract the next-version from a dry-run output line like
# "Dry run: would tag vX.Y.Z on <sha> (<bump> bump from <prev>)"
function _next_version
    string match -r 'tag (v\d+\.\d+\.\d+) ' -- "$argv" | tail -1
end

# ─── Minor bump (default) ─────────────────────────────────────────────────

set -l fixture (_make_versioned_repo v1.0.0)
cp $bump $fixture/scripts/bump-version
cd $fixture
set -l out (./scripts/bump-version --dry-run 2>&1)
set -l next (_next_version $out)
@test "v1.0.0 + minor = v1.1.0" "$next" = "v1.1.0"
rm -rf $fixture

set fixture (_make_versioned_repo v2.5.7)
cp $bump $fixture/scripts/bump-version
cd $fixture
set out (./scripts/bump-version --dry-run 2>&1)
set next (_next_version $out)
@test "v2.5.7 + minor = v2.6.0 (patch resets to 0)" "$next" = "v2.6.0"
rm -rf $fixture

# ─── Patch bump ───────────────────────────────────────────────────────────

set fixture (_make_versioned_repo v1.0.0)
cp $bump $fixture/scripts/bump-version
cd $fixture
set out (./scripts/bump-version patch --dry-run 2>&1)
set next (_next_version $out)
@test "v1.0.0 + patch = v1.0.1" "$next" = "v1.0.1"
rm -rf $fixture

set fixture (_make_versioned_repo v3.7.42)
cp $bump $fixture/scripts/bump-version
cd $fixture
set out (./scripts/bump-version patch --dry-run 2>&1)
set next (_next_version $out)
@test "v3.7.42 + patch = v3.7.43" "$next" = "v3.7.43"
rm -rf $fixture

# ─── Major bump ───────────────────────────────────────────────────────────

set fixture (_make_versioned_repo v1.5.3)
cp $bump $fixture/scripts/bump-version
cd $fixture
set out (./scripts/bump-version major --dry-run 2>&1)
set next (_next_version $out)
@test "v1.5.3 + major = v2.0.0 (minor + patch reset)" "$next" = "v2.0.0"
rm -rf $fixture

# ─── No prior tag → starts from v0.0.0 ───────────────────────────────────

set -l empty (mktemp -d)
cd $empty
git init -q -b main
git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "init"
mkdir -p scripts
cp $bump scripts/bump-version
set out (./scripts/bump-version --dry-run 2>&1)
set next (_next_version $out)
@test "no prior tag + minor = v0.1.0 (treats current as v0.0.0)" "$next" = "v0.1.0"
rm -rf $empty

# ─── Refuses non-main ────────────────────────────────────────────────────

set fixture (_make_versioned_repo v1.0.0)
cp $bump $fixture/scripts/bump-version
cd $fixture
git checkout -q -b some-feature
./scripts/bump-version --dry-run 2>/dev/null
@test "bump-version on non-main exits non-zero" $status -ne 0
rm -rf $fixture
