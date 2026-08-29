# test/helpers/fixture.fish — shared fixture construction for the behavior
# tests. Sourced by test/*.fish; don't run directly.
#
# Lives under helpers/ rather than directly in test/ because scripts/run-tests
# runs `fishtape test/*.fish`, and that glob does not recurse — a file here is
# sourceable without being collected as a test file of its own.
#
# WHY THIS EXISTS
#
# Every behavior test builds the same hermetic fixture: copy the framework
# into a fresh git repo and run THAT copy with a fake HOME, so neither the
# developer's working tree nor their real state files are touched.
#
# The list of files to copy was duplicated across four test files. Adding a
# sourced unit to wrangle therefore meant editing five files, and missing one
# failed quietly: fish's `source` on a missing file warns to stderr and keeps
# going, so the fixture runs with a function silently undefined until
# something calls it. That is exactly how _drift.fish and _nag_state.fish
# were briefly missing from every fixture while the suite stayed green.
#
# _wrangle_fixture_install_scripts globs scripts/_*.fish instead of listing
# them, so a new sourced unit needs no test change at all. The two shell-out
# executables are named explicitly because they are not sourced and so can't
# be caught by that glob; test/fixture-completeness.fish asserts this
# function installs everything wrangle actually references.

# Copy everything wrangle needs to run into <fix>/scripts.
function _wrangle_fixture_install_scripts --argument-names fix repo_root
    mkdir -p $fix/scripts
    cp $repo_root/scripts/wrangle $fix/scripts/

    # Every sourced unit, by glob. This is the point of the helper: adding
    # scripts/_foo.fish to wrangle requires no edit here.
    for f in $repo_root/scripts/_*.fish
        cp $f $fix/scripts/
    end

    # Executables wrangle shells out to. Not sourced, so not caught above.
    cp $repo_root/scripts/scan-secrets $fix/scripts/
    cp $repo_root/scripts/dump-brewfile $fix/scripts/
end

# Seed the files wrangle expects to find before it will run: the five
# ignore/allowlist files, an empty Brewfile, and an empty fish_plugins.
#
# <mode> is `empty` (blank ignore files — a fixture that should see no
# skiplist filtering) or `real` (copy the repo's own, so behavior matches
# what wrangle does against a real clone, falling back to blank if absent).
function _wrangle_fixture_seed_files --argument-names fix repo_root mode
    mkdir -p $fix/home/.config/fish/conf.d

    if test "$mode" = real
        for f in .dotignore .brewignore .fisherignore .univexport .univignore
            cp $repo_root/$f $fix/ 2>/dev/null; or touch $fix/$f
        end
    else
        touch $fix/.dotignore $fix/.brewignore $fix/.fisherignore \
              $fix/.univexport $fix/.univignore
    end

    touch $fix/Brewfile
    touch $fix/home/.config/fish/fish_plugins
    touch $fix/home/.config/fish/conf.d/.gitkeep
end

# Initialize a fixture repo with a deterministic identity. <trunk> names the
# initial branch so tests don't inherit the developer's init.defaultBranch.
function _wrangle_fixture_init_repo --argument-names fix author trunk
    git -C $fix init -q -b $trunk
    git -C $fix config user.email test@test.local
    git -C $fix config user.name "$author"
end
