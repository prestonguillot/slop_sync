# wrangle behavior tests — invoke wrangle inside a hermetic fixture repo
# and assert observable side-effects.
#
# Hermeticity: wrangle resolves its repo from its own script path
# (`git -C $script_dir rev-parse --show-toplevel`), so to isolate a test
# we copy scripts/ into a fresh `git init`ed fixture and run THAT copy.
# Combined with HOME=$fake_home this isolates BOTH the repo and all state
# files. Earlier versions of these tests ran wrangle against the real
# working tree (only HOME was isolated), which caused Pass 1's auto-switch
# to silently move the developer's HEAD to `personal` mid-test — see
# memory note `feedback_tests_switch_branches.md`.

set -l repo_root (dirname (realpath (status -f)))/..

# Build a fresh fixture: clone scripts/ + minimal repo skeleton into a
# new git repo with `personal` checked out. Echoes two paths on stdout:
# fixture repo, then fake home.
function _wrangle_fixture --inherit-variable repo_root
    set -l fix (mktemp -d)
    set -l home_dir (mktemp -d)

    git -C $fix init -q
    git -C $fix config user.email test@test.local
    git -C $fix config user.name "wrangle-behavior-test"

    # Copy the framework: scripts/, the four ignore files (so wrangle has
    # something to read), an empty home/ tree, and an empty Brewfile.
    mkdir -p $fix/scripts $fix/home/.config/fish/conf.d $fix/test
    cp $repo_root/scripts/wrangle $fix/scripts/
    cp $repo_root/scripts/_skiplist.fish $fix/scripts/
    cp $repo_root/scripts/_univ_parse.fish $fix/scripts/
    cp $repo_root/scripts/_univ_helpers.fish $fix/scripts/
    cp $repo_root/scripts/_chain.fish $fix/scripts/
    cp $repo_root/scripts/_cascade_state.fish $fix/scripts/
    cp $repo_root/scripts/_commit_msg.fish $fix/scripts/
    cp $repo_root/scripts/scan-secrets $fix/scripts/
    cp $repo_root/scripts/dump-brewfile $fix/scripts/

    # Seed the ignore files (templates from main; copying real ones keeps
    # behavior aligned with what wrangle actually runs against on a real repo).
    cp $repo_root/.dotignore     $fix/ 2>/dev/null; or touch $fix/.dotignore
    cp $repo_root/.brewignore    $fix/ 2>/dev/null; or touch $fix/.brewignore
    cp $repo_root/.fisherignore  $fix/ 2>/dev/null; or touch $fix/.fisherignore
    cp $repo_root/.univexport    $fix/ 2>/dev/null; or touch $fix/.univexport
    cp $repo_root/.univignore    $fix/ 2>/dev/null; or touch $fix/.univignore
    touch $fix/Brewfile
    touch $fix/home/.config/fish/fish_plugins
    touch $fix/home/.config/fish/conf.d/.gitkeep

    git -C $fix add -A
    git -C $fix commit -q -m "fixture seed"

    # wrangle expects a `personal` branch (the default machine-branch).
    # Create it directly off main so the auto-switch pass has somewhere to go.
    git -C $fix checkout -q -b personal

    echo $fix
    echo $home_dir
end

# ─── review-docs requires claude ──────────────────────────────────────────

set -l f1 (_wrangle_fixture)
set -l fix1 $f1[1]; set -l home1 $f1[2]
env HOME=$home1 PATH=/nonexistent-bin $fix1/scripts/wrangle review-docs 2>/dev/null
@test "review-docs without claude on PATH exits non-zero" $status -ne 0
rm -rf $fix1 $home1

# ─── Dry-run is hermetic ─────────────────────────────────────────────────
# `sync --dry-run` must never create a last-wrangle stamp.

set -l f2 (_wrangle_fixture)
set -l fix2 $f2[1]; set -l home2 $f2[2]
env HOME=$home2 $fix2/scripts/wrangle sync --dry-run >/dev/null 2>&1
test -f $home2/.cache/dotfiles/last-wrangle
@test "sync --dry-run does NOT create last-wrangle stamp" $status -ne 0
rm -rf $fix2 $home2
