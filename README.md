# dotfiles

A personal **sync system** for macOS shell + tooling configuration. Not a collection of opinionated configs — a framework for capturing yours.

## What's in this repo

```
scripts/
  bootstrap      Bash script that prepares a fresh-or-existing macOS machine:
                 installs Homebrew + a minimum kit (fish, stow, git, mas),
                 adds fish to /etc/shells, chsh's to fish, stows the framework,
                 bootstraps fisher, and force-runs the first wrangle sync.
  wrangle        Fish script. The sole ongoing sync command. Detects untracked
                 dotfiles, fisher plugins, and brew packages on the live machine;
                 prompts per item; commits and offers to push.
  dump-brewfile  Fish helper. Wraps `brew bundle dump` with .brewignore filtering.
  scan-secrets   Fish helper. Pre-commit safety net for AWS/GitHub/Slack/OpenAI/
                 Anthropic/Google tokens, JWTs, and PEM private keys.

home/            Mirrors ~. Stow-managed. Initially contains only the wrangle
                 integration snippet (.config/fish/conf.d/wrangle_integration.fish).
                 Personal dotfiles land here over time as you [t]rack them via wrangle.

.dotignore       Substring patterns wrangle never asks about. Pre-populated with
                 credential-bearing paths (.aws, .config/gh, .npmrc, etc.) as
                 safety defaults. Shared across machines (committed to repo).

.brewignore      Substring patterns wrangle strips from auto-dumped Brewfile.
                 Empty by default. Add `"Flighty"` to keep an app installed
                 locally without tracking it.

.gitignore       *.bak.*, .DS_Store, etc.

setup-new-machine.md   The bootstrap walkthrough.
```

**Notably NOT in this repo until you run wrangle:** `Brewfile`, your personal `config.fish`, `fish_plugins`, `.gitconfig`, vim/editor configs. These get added as `wrangle` discovers and tracks them on first use.

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
wrangle            # walks you through drift, commits, prompts to push
wrangle --dry-run  # see drift without committing or touching anything
wrangle --help     # full flag reference
```

## Key principles

- **Non-destructive.** Nothing here overwrites existing user files. `bootstrap` only appends-with-markers / chsh / brew-installs (all idempotent). `wrangle` only moves files when you say `[t]rack`.
- **Inventories are auto-captured.** Brewfile, fish_plugins, the dotfile manifest — wrangle maintains them. You don't hand-edit them.
- **Secrets stay out by construction.** Credential paths are in the built-in skiplist, `*.pem` / `*_rsa` / etc. are skip-globbed, and a pre-commit regex scan catches anything that slips through.
- **LLM-optional.** wrangle can use claude-code to keep docs in sync with structural changes — opt-in only, asked on first run, controllable per-run via `--with-claude` / `--suppress-claude`.
