# dotfiles

A personal **sync system** for macOS shell + tooling configuration. Not a collection of opinionated configs — a framework for capturing yours.

## What this is

Two-tier setup, separated by branch:

- The **framework** (this repo's `main` branch) is a public-shippable sync engine: a fish script (`wrangle`) that walks your machine, finds untracked dotfiles / fisher plugins / fish universals / brew packages, and prompts you per-item to track, ignore, or skip. Plus a bash bootstrap, a few helper scripts, and a test suite.
- The **personal layer** (your own branch — typically `personal`) is everything specific to you: tracked dotfiles under `home/`, your Brewfile, your fisher plugin list, your captured plugin universals, etc. `wrangle` commits to this branch exclusively.

You can stack additional machine-branches on top of `personal` (e.g., `work → personal → main`) — wrangle handles the cascade-merge along the chain at the start of every run.

## Quick start

```bash
git clone <this-repo-url> <wherever-you-want>
cd <that-dir>
./scripts/bootstrap
```

`bootstrap` installs Homebrew (if missing), the minimum kit (`fish`, `stow`, `git`, `mas`), prompts for a branch name + parent (defaults: `personal` / `main`), stows the framework, bootstraps fisher, then launches an interactive `wrangle` run.

Full walkthrough: **[setup-new-machine.md](setup-new-machine.md)**.

## Branch model

Each machine owns a branch (the "machine-branch") that declares a parent. Examples:

```
main                 (framework, shared)
  └─ personal        (your laptop)
       └─ work       (your work machine — based on personal + more)
       └─ workshop   (your shop machine — also based on personal)
  └─ partner         (somebody else, totally independent of you)
```

Two git config keys control this, both **per-clone** (not pushed to the remote):

```
wrangle.machine-branch <name>           # which branch THIS clone commits to
branch.<name>.wrangle-parent <parent>   # what to merge FROM at the start of each run
```

`bootstrap` sets these for you on first run. Existing setups (just `main` + `personal`) work without explicit config — wrangle defaults to `machine-branch=personal` and `parent=main`.

At the start of every `wrangle sync` run, **Pass 1 walks the chain root-toward-leaf** and merges each parent into its child (skipping edges that already have the parent's commits). On merge conflict the cascade stops, prints resolve instructions, and you resume with `wrangle pull --resume` after `git add` + `git commit`.

You can also just run the cascade without going through drift detection:

```fish
wrangle pull              # fetch + cascade, exit
wrangle pull --resume     # continue after a conflict
```

## What's in this repo

```
scripts/
  bootstrap      Bash. Prepares a fresh-or-existing macOS machine: installs
                 Homebrew + minimum kit, prompts for a machine-branch + parent,
                 adds fish to /etc/shells, chsh's to fish, stows the framework,
                 bootstraps fisher, and launches the first wrangle.
  wrangle        Fish. The sole ongoing sync command. Twelve passes: parent-chain
                 pull, yoink check, orphan-symlink check, re-stow, dotfile drift,
                 fisher drift, univ-var drift, brew drift, changelog, commit,
                 doc-sync (opt-in), push.
  dump-brewfile  Fish helper. `brew bundle dump --describe --force` with
                 .brewignore filtering.
  scan-secrets   Fish helper. Pre-commit safety net: AWS, GitHub, Slack, Stripe,
                 OpenAI, Anthropic, Google API keys; JWTs; PEM/SSH/PGP keys.
  bump-version   Bash helper. Semver-tags main (default: minor bump). Normally
                 called by the release workflow, not manually.
  run-tests      Bash wrapper. Invokes fishtape on test/*.fish.

test/            60+ fishtape tests covering wrangle CLI, scan-secrets, dump-brewfile,
                 bump-version.

.github/workflows/
  test.yml       Runs the test suite on every push/PR.
  release.yml    On PR-merged-to-main with a release:* label, tags + releases.

home/            Mirrors ~. Stow-managed. On main, contains only the framework's
                 conf.d hooks (wrangle integration, etc.). Your personal dotfiles
                 land here on your machine-branch as you [t]rack them via wrangle.

.dotignore       Substring patterns wrangle never asks about. Pre-populated with
                 credential-bearing paths (.aws, .config/gh, .npmrc, etc.) as
                 safety defaults. Shared across machines.

.brewignore      Substring patterns wrangle strips from auto-dumped Brewfile.
                 Empty by default.

.univexport      Allowlist of fish universal-variable patterns. Built up via
                 [t]rack decisions in wrangle's univ-var drift pass.

.univignore      Blocklist for universal variables wrangle never asks about.

.gitignore       Editor swap/backup files, macOS noise, .env, etc.

setup-new-machine.md   The bootstrap walkthrough.
```

**Notably NOT in this repo on `main`:** your `Brewfile`, your personal `config.fish`, `fish_plugins`, `.gitconfig`, vim/editor configs, captured universal variables. Those all live on your machine-branch, added as `wrangle` discovers and tracks them.

## How edits flow

`stow` symlinks each file under `home/` to its `~` counterpart. Editing `~/.config/fish/config.fish` and editing `home/.config/fish/config.fish` (assuming both exist after a track) are the same file on disk. `wrangle` re-stows on every run so newly-added files in `home/` get linked automatically.

---

# User guide

## Running wrangle

Wrangle is structured as subcommands. Bare `wrangle` is shorthand for `wrangle sync` — the dominant case.

```fish
wrangle                                # = wrangle sync
wrangle sync                           # full sync — all 12 passes
wrangle sync --dry-run                 # detect drift, change nothing, no commit, no push
wrangle sync --force                   # re-ask about paths already in .dotignore
wrangle sync --with-claude             # force-on claude doc review this run
wrangle sync --suppress-claude         # force-off claude this run
wrangle sync --no-branch-switch        # don't auto-switch to machine-branch, stay where you are

wrangle pull                           # just walk the parent chain (fetch + cascade-merge), exit
wrangle pull --resume                  # continue a cascade interrupted by a merge conflict

wrangle push                           # push current branch (preview, no prompt), exit

wrangle review-docs                    # skip drift; have claude review docs against recent commits
wrangle import-univ-vars               # source home/.config/fish/exported-univ-vars.fish, exit
wrangle set-parent <branch>            # write branch.<current>.wrangle-parent in git config
wrangle reset-claude-session           # drop the cached claude session id

wrangle help                           # list subcommands + env vars + config keys
wrangle help <subcommand>              # detailed help for one subcommand
wrangle <subcommand> --help            # same as `wrangle help <subcommand>`
```

## What each pass does

1. **Parent-chain pull.** Fetches `origin`, walks the chain (e.g. `main → personal → work`) root-toward-leaf, real-merging (`--no-ff`) each parent into its child. Skips edges that are already up-to-date. On conflict: saves resume state, exits non-zero, prints `wrangle pull --resume` instructions. Skipped if `sync --no-branch-switch` / `WRANGLE_NO_BRANCH_SWITCH=1`.

2. **Yoink check.** Walks `home/` looking for files whose `~` counterpart is gone (you deleted the symlink target). Per match: `[y]oink (remove from repo) / [r]estore (stow back) / [s]kip / [q]uit`.

3. **Orphan-symlink check.** Walks `~` looking for symlinks into `home/` whose targets no longer exist (inverse of yoink). Per match: `[r]emove dangling symlink / [s]kip / [q]uit`.

4. **Re-stow.** `stow --no-folding -R -t ~ home` — ensures every file under `home/` has a fresh symlink in `~`. Catches newly-added files since last run.

5. **Dotfile drift.** Walks `~/.config/*` and top-level `~/.<name>` files. For each one not already a symlink-into-`home/` and not in `.dotignore`: `[t]rack (move into home/ + symlink back) / [i]gnore forever (append to .dotignore) / [s]kip / [q]uit`.

6. **Fisher drift.** Compares `fisher list` against `~/.config/fish/fish_plugins`. For each plugin installed-but-not-tracked: `[t]rack / [i]gnore (uninstall) / [s]kip / [q]uit`. For each plugin tracked-but-not-installed: `[i]nstall / [r]emove from fish_plugins / [s]kip / [q]uit`.

7. **Univ-var drift.** Collects current fish universals via `set -U -L`, auto-skips anything starting with `_` (fish + plugin internal convention), groups the rest by prefix. For each new prefix group: `[t]rack pattern (append to .univexport) / [i]gnore forever (append to .univignore) / [s]kip / [q]uit`. Regenerates `home/.config/fish/exported-univ-vars.fish` when the allowlist changes or any tracked var's value drifts.

8. **Brew drift.** Calls `dump-brewfile` → diff against tracked `Brewfile`. For each entry installed-but-not-in-Brewfile: `[t]rack (append to Brewfile, copying any description comment) / [i]gnore forever (add a substring pattern to .brewignore) / [s]kip / [q]uit`. For each entry in-Brewfile-but-not-installed: `[i]nstall / [r]emove from Brewfile / [s]kip / [q]uit`.

9. **Changelog.** Appends one line per tracked change to `.wrangle-changelog` (gitignored — machine-local). Used as queue context for the doc-sync pass.

10. **Commit.** Stages everything, runs `scan-secrets` over the staged diff (refuses commit on hit unless `WRANGLE_ALLOW_SECRETS=1`), commits with an auto-generated message. If claude opt-in is on and there are multiple changes, claude is asked to summarize the diff for the message; otherwise a heuristic builds it from the per-pass `_changes` log.

11. **Doc sync (opt-in).** If claude opt-in is on and the commit pass produced a commit, claude reviews `home/` + the recent changelog and edits the appropriate `.md` files (README, setup-new-machine, PERSONAL, etc.). Doc edits commit separately as `docs: sync with wrangle run <timestamp>` so provenance stays clean.

12. **Push.** Counts unpushed commits, shows the log + diffstat preview. Prompt: `[y]es / [N]o / [d]iff (full diff in less)`. After [d]iff, re-prompts.

## Ignore files

| File | What it filters | Syntax | How to add |
|---|---|---|---|
| `.dotignore` | Paths under `~` that wrangle's dotfile-drift pass (5) never asks about. | One substring (matched against the path relative to `~`) or glob per line. `#` comments. | Answer `[i]gnore forever` in a wrangle dotfile prompt, or hand-edit. |
| `.brewignore` | Lines stripped from the auto-dumped Brewfile (so `wrangle` doesn't see them as drift). | One substring per line. `#` comments. | Answer `[i]gnore forever` in a wrangle brew prompt, or hand-edit. |
| `.univignore` | Universal-variable names wrangle's univ-var pass (7) never asks about. | One fish-style glob per line (e.g. `tide_*`, `__fish_*`, or an exact name). | Answer `[i]gnore forever` in a wrangle univ-var prompt, or hand-edit. |

The dotfile pass also has a **built-in skiplist** of credential-bearing paths (`.aws`, `.config/gh`, `.kube`, `.npmrc`, etc.) and globs (`*.pem`, `*_rsa`, etc.). These are unaffected by `--force`; the only way to bypass them is to edit the built-in list in `scripts/wrangle` itself.

## Tracked allowlist file

| File | Purpose | Syntax | How to add |
|---|---|---|---|
| `.univexport` | Allowlist of universal variables to capture in `home/.config/fish/exported-univ-vars.fish` (the file you `wrangle import-univ-vars` on a new machine). | One fish-style glob per line, OR an exact var name (exact name match wins over the auto-skip of `_*`). | Answer `[t]rack pattern` in a wrangle univ-var prompt, or hand-edit. |

## Cache + state

Internal — nothing user-facing, but useful for debugging:

```
~/.cache/dotfiles/
  last-wrangle           timestamp of last successful wrangle run (used by staleness nag)
  wrangle-config         "WRANGLE_CLAUDE_OPT_IN=yes" or =no (set by first-run question)
  claude-session-id      persistent UUID for claude --session-id (so it doesn't re-read the repo every run)
  pull-cascade-state     written when a cascade hits a conflict; consumed by --resume-pull
  pull-nag-state         per-parent: SHA last nagged about (so the pull-nag doesn't re-fire for the same commits)
```

The framework's working-tree changelog lives at `<repo>/.wrangle-changelog` and is gitignored.

## Env-var knobs

| Var | Effect |
|---|---|
| `WRANGLE_NO_COMMIT=1` | Skip the commit pass (10). |
| `WRANGLE_NO_PUSH=1` | Skip the push pass (12). |
| `WRANGLE_NO_PUSH_NAG=1` | Silence the "unpushed commits" nag on shell start. |
| `WRANGLE_NO_PULL_NAG=1` | Silence the "upstream changes pending" nag on shell start. |
| `WRANGLE_NO_STALENESS_NAG=1` | Silence the "wrangle hasn't run in N days" nag on shell start. |
| `WRANGLE_NO_BRANCH_SWITCH=1` | Skip Pass 1 (parent-chain pull + auto-switch). Useful when you want to test framework code on `main` without polluting your machine-branch. |
| `WRANGLE_ALLOW_SECRETS=1` | Bypass `scan-secrets` at commit time. Use only when you've verified the hits are test fixtures or false positives. |
| `WRANGLE_CLAUDE_MODEL=<alias>` | Override the claude model (default: `sonnet`). Accepts model aliases or full names. |
| `WRANGLE_CLAUDE_EFFORT=<level>` | Override effort (default: `low`). One of `low`/`medium`/`high`/`xhigh`/`max`. |

## Git config keys

Per-clone (in `.git/config`):

| Key | Default | Purpose |
|---|---|---|
| `wrangle.machine-branch` | `personal` | Which branch this machine commits to (= which branch wrangle auto-switches to). |
| `branch.<X>.wrangle-parent` | `main` (when `<X> != main`) | What to merge from at the start of every run. Set via `wrangle set-parent <parent>` or directly via `git config`. |

## conf.d hooks

`bootstrap` stows two fish hooks into `~/.config/fish/conf.d/`:

| File | Purpose | How to disable |
|---|---|---|
| `wrangle_integration.fish` | Four things on every shell start: (a) adds `<repo>/scripts/` to `$PATH` so `wrangle` and friends are callable; (b) staleness nag if wrangle hasn't run in > 7 days (suggests `wrangle sync`); (c) unpushed-commits nag (suggests `wrangle push`); (d) pull-nag if any chain-edge has new upstream commits (suggests `wrangle pull`). All nags are colorized and prefixed with `wrangle:` so it's obvious where they come from. The pull-nag self-suppresses for already-seen upstream SHAs (only re-fires on genuinely new commits). | Per-nag: set the corresponding `WRANGLE_NO_*_NAG=1` env var (deliberately not advertised in the nag text). To remove entirely: `rm ~/.config/fish/conf.d/wrangle_integration.fish` (will be re-created next bootstrap; or `wrangle [i]gnore`-it). |
| `blank_line_before_output.fish` | `fish_preexec` hook that prints a blank line between your typed command and its output. | `rm ~/.config/fish/conf.d/blank_line_before_output.fish` (it's on the personal branch, so this is a wrangle `[y]oink` candidate). |

## Releasing framework updates (for repo maintainers)

Framework changes ship through a PR-driven flow. Tagging and the GitHub Release are automated — you don't run `bump-version` by hand in the normal case.

```fish
git checkout main && git pull
git checkout -b some-change
# … edit scripts/, tests, docs …
git commit -am "describe the change"
git push -u origin some-change
gh pr create --base main --title "..." --label release:patch   # or release:minor / release:major
```

When the PR is green and you merge it (rebase merge — main stays linear), `.github/workflows/release.yml` reads the `release:*` label, calls `scripts/bump-version`, pushes the next `vX.Y.Z` tag, and creates a GitHub Release with auto-generated notes from the merged commits.

PRs without a `release:*` label merge normally but don't bump the version — use that for changes that aren't user-visible (CI tweaks, README typos, etc.). To release after the fact, label another PR or use `scripts/bump-version` locally as a hotfix escape hatch.

The cascade-pull in `wrangle` (Pass 1) brings released framework updates into your machine-branch automatically on the next run from any machine; you don't need to manually merge `main` into `personal` anymore.

## Key principles

- **Non-destructive.** Nothing here overwrites existing user files. `bootstrap` only appends-with-markers / chsh / brew-installs (all idempotent). `wrangle` only moves files when you say `[t]rack`.
- **Inventories are auto-captured.** Brewfile, fish_plugins, dotfile manifest, exported universals — wrangle maintains them. You don't hand-edit them.
- **Secrets stay out by construction.** Credential paths are in the built-in skiplist, `*.pem` / `*_rsa` / etc. are skip-globbed, and a pre-commit regex scan catches anything that slips through.
- **LLM-optional.** wrangle can use claude-code to keep docs in sync and to summarize commit diffs — opt-in only, asked on first run, controllable per-run via `--with-claude` / `--suppress-claude` and globally via `WRANGLE_CLAUDE_OPT_IN` in `~/.cache/dotfiles/wrangle-config`.
