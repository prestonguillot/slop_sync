# wrangle CLI surface tests. Smoke-tests for argparse + dry-run safety.

set -l wrangle (dirname (realpath (status -f)))/../scripts/wrangle

# ─── Help ─────────────────────────────────────────────────────────────────

$wrangle --help >/dev/null
@test "--help exits 0" $status -eq 0

set -l help_out ($wrangle --help)

string match -q "*--dry-run*" -- "$help_out"
@test "--help mentions --dry-run" $status -eq 0

string match -q "*--force*" -- "$help_out"
@test "--help mentions --force" $status -eq 0

string match -q "*--review-docs*" -- "$help_out"
@test "--help mentions --review-docs" $status -eq 0

string match -q "*WRANGLE_NO_PUSH_NAG*" -- "$help_out"
@test "--help mentions WRANGLE_NO_PUSH_NAG" $status -eq 0

string match -q "*WRANGLE_NO_STALENESS_NAG*" -- "$help_out"
@test "--help mentions WRANGLE_NO_STALENESS_NAG" $status -eq 0

string match -q "*WRANGLE_CLAUDE_MODEL*" -- "$help_out"
@test "--help mentions WRANGLE_CLAUDE_MODEL" $status -eq 0

string match -q "*WRANGLE_CLAUDE_EFFORT*" -- "$help_out"
@test "--help mentions WRANGLE_CLAUDE_EFFORT" $status -eq 0

string match -q "*WRANGLE_ALLOW_SECRETS*" -- "$help_out"
@test "--help mentions WRANGLE_ALLOW_SECRETS" $status -eq 0

string match -q "*--no-branch-switch*" -- "$help_out"
@test "--help mentions --no-branch-switch" $status -eq 0

string match -q "*--import-univ-vars*" -- "$help_out"
@test "--help mentions --import-univ-vars" $status -eq 0

string match -q "*WRANGLE_NO_BRANCH_SWITCH*" -- "$help_out"
@test "--help mentions WRANGLE_NO_BRANCH_SWITCH" $status -eq 0

# ─── Mutually-exclusive flags ─────────────────────────────────────────────

set -l conflict_out ($wrangle --with-claude --suppress-claude 2>&1)
@test "--with-claude + --suppress-claude exits non-zero" $status -ne 0

string match -q "*mutually exclusive*" -- "$conflict_out"
@test "--with-claude + --suppress-claude prints 'mutually exclusive'" $status -eq 0
