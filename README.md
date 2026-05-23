# dotfiles

A personal **sync system** for macOS shell + tooling configuration. Not a collection of opinionated configs — a framework for capturing yours.

## Branch model

This repo uses a two-branch architecture:

- **`main`** — framework only (scripts, tests, docs, ignore templates). Shared and public-shippable. Semver-tagged (`v1.0.0`, `v1.1.0`, …) on every commit. Only humans (or claude) commit here, never `wrangle`.
- **`personal`** — **per-user, per-machine** branch (NOT a single shared branch). Contains all of `main` plus your specific layer: `.gitconfig`, vim/editor configs, `Brewfile`, fisher plugin list, captured plugin universal variables, etc. Each user maintains their own `personal` (typically in their own private fork or remote). `wrangle` commits go here exclusively. Merges flow from `main` → `personal`, never back.

`bootstrap` automatically sets up `personal` for you on first run: if it doesn't exist locally or on origin, it's created fresh from `main`. `wrangle` auto-switches to `personal` at the start of every run and pulls framework updates from `main` via fast-forward merge.

## What's in this repo

```
scripts/
  bootstrap      Bash script that prepares a fresh-or-existing macOS machine:
                 installs Homebrew + a minimum kit (fish, stow, git, mas),
                 sets up the personal branch, adds fish to /etc/shells,
                 chsh's to fish, stows the framework, bootstraps fisher,
                 and force-runs the first wrangle sync.
  wrangle        Fish script. The sole ongoing sync command. Detects untracked
                 dotfiles, fisher plugins, fish universal variables, and brew
                 packages on the live machine; prompts per item; commits and
                 offers to push.
  dump-brewfile  Fish helper. Wraps `brew bundle dump` with .brewignore filtering.
  scan-secrets   Fish helper. Pre-commit safety net for AWS/GitHub/Slack/OpenAI/
                 Anthropic/Google tokens, JWTs, and PEM private keys.
  bump-version   Bash helper. Semver-tags main (default minor bump).
  run-tests      Bash wrapper that invokes fishtape on test/*.fish.

test/            46+ fishtape tests covering scan-secrets, dump-brewfile, wrangle.

.github/workflows/test.yml   Runs the test suite on every push/PR.

home/            Mirrors ~. Stow-managed. Initially contains only the wrangle
                 integration snippet (.config/fish/conf.d/wrangle_integration.fish).
                 Personal dotfiles land here over time as you [t]rack them via wrangle.

.dotignore       Substring patterns wrangle never asks about. Pre-populated with
                 credential-bearing paths (.aws, .config/gh, .npmrc, etc.) as
                 safety defaults. Shared across machines (committed to repo).

.brewignore      Substring patterns wrangle strips from auto-dumped Brewfile.
                 Empty by default. Add `"Flighty"` to keep an app installed
                 locally without tracking it.

.univexport      Allowlist of fish universal-variable patterns (e.g., `tide_*`).
                 Built up via [t]rack decisions in wrangle's univ-var drift pass.

.univignore      Blocklist for universal variables wrangle never asks about.

.gitignore       *.bak.*, .DS_Store, .wrangle-changelog.

setup-new-machine.md   The bootstrap walkthrough.
```

**Notably NOT in this repo on `main`:** `Brewfile`, your personal `config.fish`, `fish_plugins`, `.gitconfig`, vim/editor configs, captured universal variables. These all live on your own `personal` branch, added as `wrangle` discovers and tracks them on first use.

## Setting up a new machine

See **[setup-new-machine.md](setup-new-machine.md)**. TL;DR:

```bash
git clone <this-repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap
```

`bootstrap` lands you in an interactive `wrangle` session that walks through everything on the machine and asks what to track.

## How edits flow

`stow` symlinks each file under `home/` to its `~` counterpart. Editing `~/.config/fish/config.fish` and editing `home/.config/fish/config.fish` (assuming both exist after a track) are the same file on disk. `wrangle` re-stows on every run so newly-added files in `home/` get linked automatically.

## Daily use

```fish
wrangle                       # walks you through drift, commits to personal, prompts to push
wrangle --dry-run             # see drift without committing or touching anything
wrangle --import-univ-vars    # restore captured plugin universals on a new machine
wrangle --help                # full flag reference
```

## Releasing framework updates (for repo maintainers)

```fish
git checkout main                       # do framework work on main
# … edit scripts/, tests, docs …
git commit -am "describe the change"
./scripts/bump-version                  # creates next minor v* tag (use `patch` or `major` for other bumps)
git push origin main vX.Y.Z
git checkout personal                   # bring framework updates into your personal layer
git merge main
git push origin personal
```

## Key principles

- **Non-destructive.** Nothing here overwrites existing user files. `bootstrap` only appends-with-markers / chsh / brew-installs (all idempotent). `wrangle` only moves files when you say `[t]rack`.
- **Inventories are auto-captured.** Brewfile, fish_plugins, the dotfile manifest — wrangle maintains them. You don't hand-edit them.
- **Secrets stay out by construction.** Credential paths are in the built-in skiplist, `*.pem` / `*_rsa` / etc. are skip-globbed, and a pre-commit regex scan catches anything that slips through.
- **LLM-optional.** wrangle can use claude-code to keep docs in sync with structural changes — opt-in only, asked on first run, controllable per-run via `--with-claude` / `--suppress-claude`.
