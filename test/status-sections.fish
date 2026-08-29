# `wrangle status` section tests — verify the two independent comparisons
# are reported separately, under the names that match their remedies.
#
#   Update status     origin/$current ↔ $current   → wrangle push / git pull
#   Framework update  origin/main    → $current    → wrangle update
#
# These were a single section named "Update status" that actually computed
# the framework axis, while the "Framework update" header was an empty
# passthrough from sync's Pass 1. The fixture below puts the machine-branch
# BOTH ahead of its own remote AND behind trunk at the same time, so a
# regression that collapses the two axes back together can't pass.
#
# Hermeticity: same pattern as test/wrangle-behavior.fish — copy scripts/
# into a fresh repo and run THAT copy with a fake HOME. A bare repo serves
# as origin so both remote-tracking comparisons have real data.

set -l repo_root (dirname (realpath (status -f)))/..

# Build a fixture with a real origin. Echoes three paths on stdout:
# fixture repo, fake home, bare origin.
function _wrangle_status_fixture --inherit-variable repo_root
    set -l fix (mktemp -d)
    set -l home_dir (mktemp -d)
    set -l origin (mktemp -d)

    git -C $origin init -q --bare -b main

    git -C $fix init -q -b main
    git -C $fix config user.email test@test.local
    git -C $fix config user.name "status-sections-test"

    mkdir -p $fix/scripts $fix/home/.config/fish/conf.d
    cp $repo_root/scripts/wrangle $fix/scripts/
    cp $repo_root/scripts/_skiplist.fish $fix/scripts/
    cp $repo_root/scripts/_univ_parse.fish $fix/scripts/
    cp $repo_root/scripts/_univ_helpers.fish $fix/scripts/
    cp $repo_root/scripts/_commit_msg.fish $fix/scripts/
    cp $repo_root/scripts/_drift.fish $fix/scripts/
    cp $repo_root/scripts/scan-secrets $fix/scripts/
    cp $repo_root/scripts/dump-brewfile $fix/scripts/

    touch $fix/.dotignore $fix/.brewignore $fix/.fisherignore $fix/.univexport $fix/.univignore
    touch $fix/Brewfile $fix/home/.config/fish/fish_plugins $fix/home/.config/fish/conf.d/.gitkeep

    git -C $fix add -A
    git -C $fix commit -q -m "fixture seed"
    git -C $fix remote add origin $origin
    git -C $fix push -q -u origin main

    # personal branches off main and gets its own upstream.
    git -C $fix checkout -q -b personal
    git -C $fix push -q -u origin personal

    # Trunk moves forward without personal: 1 commit on origin/main that
    # personal has not merged. Drives the Framework update section.
    git -C $fix checkout -q main
    echo "framework change" > $fix/FRAMEWORK.md
    git -C $fix add FRAMEWORK.md
    git -C $fix commit -q -m "framework: a trunk-only commit"
    git -C $fix push -q origin main

    # personal moves forward without origin/personal: 1 unpushed commit.
    # Drives the Update status section.
    git -C $fix checkout -q personal
    echo "local note" > $fix/PERSONAL.md
    git -C $fix add PERSONAL.md
    git -C $fix commit -q -m "personal: a local-only commit"

    echo $fix
    echo $home_dir
    echo $origin
end

# ─── Both axes reported, separately ──────────────────────────────────────
# personal is simultaneously 1 ahead of origin/personal and 1 behind
# origin/main. Each section must report its own axis and its own remedy.

set -l f1 (_wrangle_status_fixture)
set -l fix1 $f1[1]; set -l home1 $f1[2]; set -l origin1 $f1[3]
set -l out (env HOME=$home1 $fix1/scripts/wrangle status 2>&1 | string join \n)

string match -q "*Update status*" -- "$out"
@test "status prints an Update status section" $status -eq 0

string match -q "*Framework update*" -- "$out"
@test "status prints a Framework update section" $status -eq 0

# Update status axis: ahead of its own remote → wrangle push.
string match -q "*not yet on*origin/personal*" -- "$out"
@test "Update status reports commits not yet on origin/personal" $status -eq 0

string match -q "*wrangle push*" -- "$out"
@test "Update status points at wrangle push" $status -eq 0

# Framework update axis: behind trunk → wrangle update.
string match -q "*origin/main*not yet in*personal*" -- "$out"
@test "Framework update reports commits on origin/main not in personal" $status -eq 0

string match -q "*wrangle update*" -- "$out"
@test "Framework update points at wrangle update" $status -eq 0

# The regression this guards: Pass 1's header arriving via the sync
# re-exec with nothing under it.
string match -q "*skipped (WRANGLE_NO_BRANCH_SWITCH set*" -- "$out"
@test "status does NOT print the Pass 1 skipped message" $status -ne 0

rm -rf $fix1 $home1 $origin1

# ─── status is read-only ─────────────────────────────────────────────────
# It re-execs sync --dry-run; nothing in that path may write.

set -l f2 (_wrangle_status_fixture)
set -l fix2 $f2[1]; set -l home2 $f2[2]; set -l origin2 $f2[3]
set -l before (git -C $fix2 rev-parse HEAD)
env HOME=$home2 $fix2/scripts/wrangle status >/dev/null 2>&1

test -f $home2/.cache/dotfiles/last-wrangle
@test "status does NOT create last-wrangle stamp" $status -ne 0

test (git -C $fix2 rev-parse HEAD) = "$before"
@test "status does NOT commit" $status -eq 0

test (git -C $fix2 rev-parse --abbrev-ref HEAD) = personal
@test "status does NOT switch branches" $status -eq 0

rm -rf $fix2 $home2 $origin2

# ─── Drift unit declares its mode ────────────────────────────────────────
# _wrangle_detect_drift takes an explicit mode rather than reading the
# ambient $_dry_run global. Every gate inside tests for `report`, so a
# missing or misspelled mode would fall through to the prompting-and-
# writing branches. It must fail closed instead.

set -l f3 (_wrangle_status_fixture)
set -l fix3 $f3[1]; set -l home3 $f3[2]; set -l origin3 $f3[3]

set -l probe (mktemp)
echo "
set -g GLYPH_ERR X
source $fix3/scripts/_drift.fish
_wrangle_detect_drift
echo \"rv=\$status\"
_wrangle_detect_drift bogus
echo \"rv=\$status\"
" > $probe
set -l probe_out (env HOME=$home3 fish $probe 2>&1 | string join \n)

string match -q "*rv=2*" -- "$probe_out"
@test "_wrangle_detect_drift rejects a missing mode" $status -eq 0

string match -q "*unknown mode 'bogus'*" -- "$probe_out"
@test "_wrangle_detect_drift rejects an unknown mode by name" $status -eq 0

rm -f $probe
rm -rf $fix3 $home3 $origin3
