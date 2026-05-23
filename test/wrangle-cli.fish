# wrangle CLI surface tests. Smoke-tests for subcommand dispatch + per-subcommand help.

set -l wrangle (dirname (realpath (status -f)))/../scripts/wrangle

# ─── Top-level help ──────────────────────────────────────────────────────

$wrangle help >/dev/null
@test "wrangle help exits 0" $status -eq 0

set -l top_help ($wrangle help)

for subcmd in sync pull review-docs import-univ-vars set-parent reset-claude-session
    string match -q "*$subcmd*" -- "$top_help"
    @test "top-level help lists subcommand: $subcmd" $status -eq 0
end

string match -q "*WRANGLE_NO_PUSH_NAG*"     -- "$top_help"; @test "top-level help mentions WRANGLE_NO_PUSH_NAG" $status -eq 0
string match -q "*WRANGLE_NO_PULL_NAG*"     -- "$top_help"; @test "top-level help mentions WRANGLE_NO_PULL_NAG" $status -eq 0
string match -q "*WRANGLE_NO_STALENESS_NAG*" -- "$top_help"; @test "top-level help mentions WRANGLE_NO_STALENESS_NAG" $status -eq 0
string match -q "*WRANGLE_NO_BRANCH_SWITCH*" -- "$top_help"; @test "top-level help mentions WRANGLE_NO_BRANCH_SWITCH" $status -eq 0
string match -q "*WRANGLE_ALLOW_SECRETS*"   -- "$top_help"; @test "top-level help mentions WRANGLE_ALLOW_SECRETS" $status -eq 0
string match -q "*WRANGLE_CLAUDE_MODEL*"    -- "$top_help"; @test "top-level help mentions WRANGLE_CLAUDE_MODEL" $status -eq 0
string match -q "*WRANGLE_CLAUDE_EFFORT*"   -- "$top_help"; @test "top-level help mentions WRANGLE_CLAUDE_EFFORT" $status -eq 0

string match -q "*wrangle.machine-branch*"  -- "$top_help"; @test "top-level help mentions wrangle.machine-branch git config" $status -eq 0
string match -q "*wrangle-parent*"          -- "$top_help"; @test "top-level help mentions branch.<X>.wrangle-parent git config" $status -eq 0

# ─── Per-subcommand --help ──────────────────────────────────────────────

set -l sync_help ($wrangle sync --help)
string match -q "*--dry-run*"          -- "$sync_help"; @test "sync --help mentions --dry-run" $status -eq 0
string match -q "*--force*"            -- "$sync_help"; @test "sync --help mentions --force" $status -eq 0
string match -q "*--with-claude*"      -- "$sync_help"; @test "sync --help mentions --with-claude" $status -eq 0
string match -q "*--suppress-claude*"  -- "$sync_help"; @test "sync --help mentions --suppress-claude" $status -eq 0
string match -q "*--no-branch-switch*" -- "$sync_help"; @test "sync --help mentions --no-branch-switch" $status -eq 0

set -l pull_help ($wrangle pull --help)
string match -q "*--resume*" -- "$pull_help"; @test "pull --help mentions --resume" $status -eq 0

# `wrangle help <subcmd>` works the same as `wrangle <subcmd> --help`.
set -l help_sync ($wrangle help sync)
string match -q "*--dry-run*" -- "$help_sync"; @test "help sync mentions --dry-run" $status -eq 0

set -l help_pull ($wrangle help pull)
string match -q "*--resume*" -- "$help_pull"; @test "help pull mentions --resume" $status -eq 0

# ─── Subcommand dispatch ────────────────────────────────────────────────

# Unknown subcommand exits non-zero with a hint to `wrangle help`.
$wrangle nonexistent-subcmd 2>/dev/null
@test "unknown subcommand exits non-zero" $status -ne 0

set -l unknown_err ($wrangle nonexistent-subcmd 2>&1)
string match -q "*unknown subcommand*" -- "$unknown_err"
@test "unknown subcommand prints 'unknown subcommand'" $status -eq 0

string match -q "*wrangle help*" -- "$unknown_err"
@test "unknown subcommand suggests \`wrangle help\`" $status -eq 0

# ─── sync-specific: mutually-exclusive flags ────────────────────────────

set -l conflict_out ($wrangle sync --with-claude --suppress-claude 2>&1)
@test "sync --with-claude + --suppress-claude exits non-zero" $status -ne 0

string match -q "*mutually exclusive*" -- "$conflict_out"
@test "sync --with-claude + --suppress-claude prints 'mutually exclusive'" $status -eq 0

# Non-sync subcommands don't accept --with-claude (argparse rejects it).
$wrangle pull --with-claude 2>/dev/null
@test "pull rejects --with-claude (sync-only flag)" $status -ne 0

# ─── set-parent positional validation ───────────────────────────────────

set -l setp_out ($wrangle set-parent 2>&1)
@test "set-parent with no args exits non-zero" $status -ne 0

string match -q "*expects exactly one argument*" -- "$setp_out"
@test "set-parent with no args prints usage" $status -eq 0
