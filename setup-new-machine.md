# Setup: new macOS machine

## TL;DR

```bash
git clone <this-repo-url> ~/dotfiles   # or wherever
cd ~/dotfiles
./scripts/bootstrap
```

The bootstrap script handles the automatable parts and then drops you into a `wrangle` session that walks through everything already on the machine.

---

## What `./scripts/bootstrap` actually does

Everything below is idempotent. Safe to re-run on a partially-set-up machine; nothing destructive.

1. **Homebrew** — installs it if missing; sources `brew shellenv` for the rest of the script.
2. **Minimum kit** — `brew install fish stow git mas`. fish is the shell the scripts are written in; stow manages the symlinks; git pinned for clarity (you cloned this repo with it); mas is the only CLI gateway to the Mac App Store, so `brew bundle dump` can see MAS apps (idle if you never install one).
3. **Login shell** — adds `$(brew --prefix)/bin/fish` to `/etc/shells` (sudo), then `chsh -s` to fish. Skipped if already in place.
4. **Personal branch** — sets you up on a `personal` branch. Already-on-personal is a no-op; existing-local-personal gets checked out; existing-on-origin gets checked out tracking origin; otherwise a fresh `personal` is created from `main`. All of your machine-specific changes go on this branch; framework updates from upstream stay on `main` and get merged in automatically by wrangle.
5. **Stow framework** — runs `stow --no-folding -t ~ home`. Creates a symlink at `~/.config/fish/conf.d/wrangle_integration.fish` that auto-loads in new fish sessions: puts `<repo>/scripts/` on `$PATH` and adds the staleness/unpushed nags.
6. **Fisher** — bootstraps the fish plugin manager if not already present.
7. **First wrangle** — execs into a fresh fish session and runs `wrangle`.

---

## Manual steps `bootstrap` can't do

1. **Git remote auth (if you'll push).** Set up auth however you prefer: osxkeychain credential helper (built into git on macOS), SSH keys, the `gh` CLI, etc. Plain `git push` over HTTPS works out of the box once your credential helper is configured. On the first push of your `personal` branch, git will prompt with `git push --set-upstream origin personal` — accept it (or use a different remote if you'd rather push personal elsewhere).

2. **Restore captured universal variables (if your `personal` branch has them).** If your personal branch was previously set up on another machine and `home/.config/fish/exported-univ-vars.fish` is present in the repo, run:
   ```fish
   wrangle --import-univ-vars
   ```
   This restores tide / sponge / other plugin configuration that lives in fish universals rather than files. Skip if this is a fresh personal branch.

3. **Mac App Store sign-in (if you'll install MAS apps).** Open the App Store app and sign in. `mas install <id>` won't work otherwise.

4. **Anything else you want this machine to have.** Install tools normally (`brew install foo`, drag apps to `/Applications`, write dotfiles by hand, whatever). Next time you run `wrangle`, it'll detect drift and walk you through tracking it.

---

## The first `wrangle` session

When bootstrap hands off, you're in interactive `wrangle`. What you'll see:

- A branch-sync notice (`→ switched to personal` if you weren't there already) and a silent fast-forward merge from `main` if any framework updates are pending.
- A first-run welcome banner (only shows once per machine).
- A pre-stow integrity check for yoinked or orphaned dotfile symlinks.
- A dotfile-drift pass: walks top-level entries in `~/` and `~/.config/` that aren't tracked. For each: `[t]rack` (moves into `home/`, symlinks back), `[i]gnore forever` (writes to `.dotignore`), `[s]kip`, `[q]uit`.
- A fisher-plugin drift pass: installed plugins not in `fish_plugins`, and vice versa.
- A univ-var drift pass: groups installed fish universals by prefix. `[t]rack pattern` adds e.g. `tide_*` to `.univexport` and regenerates `home/.config/fish/exported-univ-vars.fish`; `[i]gnore forever` adds the pattern to `.univignore`.
- A brew-drift pass: installed brews/casks/MAS apps not in `Brewfile`, and vice versa.
- A secret-scan against the staged diff before commit (auto-aborts on AWS/GitHub/Slack/OpenAI/Anthropic/Google tokens, JWTs, private keys).
- A commit (auto, on `personal`) and a push prompt if a remote is configured.
- On the very first run: a one-time question asking whether to enable claude-code doc review.

Everything is non-destructive. Hitting `[s]kip` for everything is a valid outcome — wrangle just makes no changes and exits.

---

## Daily use

```fish
wrangle                       # interactive — main entry point
wrangle --dry-run             # see drift, no prompts, no changes, no commit
wrangle --force               # re-ask about paths in .dotignore
wrangle --with-claude         # force-on claude doc review this run
wrangle --suppress-claude     # force-off claude this run
wrangle --reset-claude-session # drop cached claude session id
wrangle --no-branch-switch    # stay on current branch (don't auto-switch to personal)
wrangle --import-univ-vars    # restore captured plugin universals on a new machine
wrangle --review-docs         # invoke claude on current state (no drift required)
wrangle --help                # full reference
```

The repo nags you in two ways from new shells. Both are silenceable per-shell or globally via env var:

- **Staleness nag** — fires if `wrangle` hasn't run in > 7 days. Silence with `WRANGLE_NO_STALENESS_NAG=1`.
- **Unpushed nag** — fires if you committed but declined the push prompt. Silence with `WRANGLE_NO_PUSH_NAG=1`.

Set either (or both) in your `config.fish` or per-shell to mute permanently.

---

## Detaching a machine

```fish
cd ~/dotfiles
stow -t ~ -D home    # removes every symlink wrangle has stowed back into ~
```

The repo itself is untouched. Re-stow any time with `stow --no-folding -t ~ home`.

---

## Where things live

- `~/.cache/dotfiles/last-wrangle` — last successful run timestamp (machine-local).
- `~/.cache/dotfiles/wrangle-config` — claude opt-in answer (machine-local).
- `~/.cache/dotfiles/claude-session-id` — cached claude session for resumption.
- `~/.cache/dotfiles/unpushed` — flag set when you decline the push prompt; cleared on next push.
- `<repo>/.wrangle-changelog` — running log of structural changes (used by claude when enabled).
- `<repo>/.dotignore`, `<repo>/.brewignore`, `<repo>/.univexport`, `<repo>/.univignore` — ignore/allowlists, tracked on your `personal` branch.
- `<repo>/home/.config/fish/exported-univ-vars.fish` — auto-regenerated snapshot of universals matching `.univexport` patterns. Restore on a new machine with `wrangle --import-univ-vars`.

---

## Branches

This repo uses a two-branch model:

- **`main`** is framework only — wrangle/bootstrap scripts, ignore-list templates, tests, docs. Shared and semver-tagged (latest tag indicates the framework release you're on).
- **`personal`** is your machine state — `.gitconfig`, vim configs, Brewfile, plugin lists, captured universals. Per-user — not a single shared branch.

After bootstrap, you're on `personal`. Each wrangle run does a silent fast-forward merge from `origin/main` at the start, so framework updates flow into your personal layer automatically. You never need to merge back to `main`. If you want to detach from upstream framework updates, use `wrangle --no-branch-switch`.
