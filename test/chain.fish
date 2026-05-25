# Tests for scripts/_chain.fish — parent-chain resolution against a fixture
# git repo. Covers default machine-branch resolution, explicit overrides,
# the hardcoded `main is root` rule, and chain walking for deep parent
# hierarchies (work → personal → main).
#
# Run via `scripts/run-tests` (fishtape).

set -l repo_root (dirname (realpath (status -f)))/..
source $repo_root/scripts/_chain.fish

# ─── fixture: fresh repo with no wrangle config ──────────────────────────

set -l fix (mktemp -d)
git -C $fix init -q
git -C $fix config user.email test@test.local
git -C $fix config user.name "test"
git -C $fix commit --allow-empty -q -m init

# ─── _wrangle_machine_branch defaults ────────────────────────────────────

test (_wrangle_machine_branch $fix) = personal
@test "_wrangle_machine_branch: unset config defaults to 'personal'" $status -eq 0

git -C $fix config wrangle.machine-branch laptop
test (_wrangle_machine_branch $fix) = laptop
@test "_wrangle_machine_branch: explicit config wins" $status -eq 0

# ─── _wrangle_parent_of: hardcoded 'main is root' rule ──────────────────

_wrangle_parent_of $fix main
@test "_wrangle_parent_of main: returns status 1 (no parent)" $status -ne 0

# Even if someone sneaks a config for main, the hardcoded rule wins.
git -C $fix config branch.main.wrangle-parent personal
_wrangle_parent_of $fix main
@test "_wrangle_parent_of main: STILL no parent even with config set" $status -ne 0

# ─── _wrangle_parent_of: explicit config wins ───────────────────────────

git -C $fix config branch.laptop.wrangle-parent main
test (_wrangle_parent_of $fix laptop) = main
@test "_wrangle_parent_of laptop: explicit config returns 'main'" $status -eq 0

git -C $fix config branch.work.wrangle-parent laptop
test (_wrangle_parent_of $fix work) = laptop
@test "_wrangle_parent_of work: explicit config returns 'laptop'" $status -eq 0

# ─── _wrangle_parent_of: unset on non-main defaults to 'main' ───────────

test (_wrangle_parent_of $fix never-configured) = main
@test "_wrangle_parent_of never-configured: defaults to 'main'" $status -eq 0

# ─── _wrangle_parent_of: empty input returns status 1 ───────────────────

_wrangle_parent_of $fix ""
@test "_wrangle_parent_of '': empty input returns status 1" $status -ne 0

# ─── _wrangle_chain_for: single-branch chain (root) ─────────────────────

set -l chain_main (_wrangle_chain_for $fix main)
@test "_wrangle_chain_for main: one-element chain" (count $chain_main) -eq 1
test "$chain_main[1]" = main
@test "_wrangle_chain_for main: element is 'main'" $status -eq 0

# ─── _wrangle_chain_for: two-element chain (laptop → main) ──────────────

set -l chain_laptop (_wrangle_chain_for $fix laptop)
@test "_wrangle_chain_for laptop: two-element chain" (count $chain_laptop) -eq 2
test "$chain_laptop[1]" = main; and test "$chain_laptop[2]" = laptop
@test "_wrangle_chain_for laptop: [main, laptop] order" $status -eq 0

# ─── _wrangle_chain_for: three-element chain (work → laptop → main) ─────

set -l chain_work (_wrangle_chain_for $fix work)
@test "_wrangle_chain_for work: three-element chain" (count $chain_work) -eq 3
test "$chain_work[1]" = main; and test "$chain_work[2]" = laptop; and test "$chain_work[3]" = work
@test "_wrangle_chain_for work: [main, laptop, work] order" $status -eq 0

# ─── cleanup ────────────────────────────────────────────────────────────

rm -rf $fix
