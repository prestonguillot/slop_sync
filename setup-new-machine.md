# Setup: new macOS machine

## TL;DR

```bash
git clone <this-repo-url> <wherever-you-want>
cd <that-dir>
./scripts/bootstrap
```

The bootstrap script handles the automatable parts and then drops you into a `wrangle` session that walks through everything already on the machine.

---

## What `./scripts/bootstrap` actually does

Everything below is idempotent. Safe to re-run on a partially-set-up machine; nothing destructive.

1. **Homebrew** — installs it if missing; sources `brew shellenv` for the rest of the script.
2. **Minimum kit** — `brew install fish stow git mas`. fish is the shell the scripts are written in; stow manages the symlinks; git pinned for clarity (you cloned this repo with it); mas is the only CLI gateway to the Mac App Store, so `brew bundle dump` can see MAS apps (idle if you never install one).
3. **Login shell** — adds `$(brew --prefix)/bin/fish` to `/etc/shells` (sudo), then `chsh -s` to fish. Skipped if already in place.
4. **Machine-branch + parent.** Prompts you for two things:
   - Branch name for this machine (default: `personal`).
   - If creating a new branch: its parent (default: `main`).
   Writes `wrangle.machine-branch` and `branch.<name>.wrangle-parent` to `.git/config` (per-clone, not pushed). Already-on-a-configured-machine-branch is a no-op; existing-local-branch gets switched to; existing-on-origin gets checked out tracking origin; otherwise a fresh branch is created from the chosen parent.
5. **Stow framework** — runs `stow --no-folding -t ~ home`. Creates a symlink for the framework's `wrangle_integration.fish` conf.d hook, plus any other tracked files under `home/`.
6. **Fisher** — bootstraps the fish plugin manager if not already present.
7. **First wrangle** — execs into a fresh fish session and runs `wrangle sync` (so PATH integration from the just-stowed conf.d hook is live).

---

## Manual steps `bootstrap` can't do

1. **Git remote auth (if you'll push).** Set up auth however you prefer: osxkeychain credential helper (built into git on macOS), SSH keys, the `gh` CLI, etc. Plain `git push` over HTTPS works out of the box once your credential helper is configured. On the first push of your machine-branch, git will prompt with `git push --set-upstream origin <branch>` — accept it (or use a different remote if you'd rather push that branch elsewhere).

2. **Restore captured universal variables (if your machine-branch has them).** If your machine-branch was previously set up on another machine and `home/.config/fish/exported-univ-vars.fish` is present in the repo, run:
   ```fish
   wrangle import-univ-vars
   ```
   This restores tide / sponge / other plugin configuration that lives in fish universals rather than files. Skip if this is a fresh machine-branch.

3. **Mac App Store sign-in (if you'll install MAS apps).** Open the App Store app and sign in. `mas install <id>` won't work otherwise.

4. **Anything else you want this machine to have.** Install tools normally (`brew install foo`, drag apps to `/Applications`, write dotfiles by hand, whatever). Next time you run `wrangle`, it'll detect drift and walk you through tracking it.

---

## The first `wrangle` session

When bootstrap hands off, you're in interactive `wrangle`. What you'll see:

- A parent-chain pull (Pass 1) — fetches origin, walks the chain, real-merges each parent into its child (skipping edges that are already up-to-date). On the very first run from a fresh branch, this typically lands as "already has parent's changes (skip)" since you just branched from it.
- A first-run welcome banner (only shows once per machine).
- A one-time question asking whether to enable claude-code doc review.
- A pre-stow integrity check for yoinked or orphaned dotfile symlinks.
- A re-stow.
- A dotfile-drift pass: walks top-level entries in `~/` and `~/.config/` that aren't tracked. For each: `[t]rack` (moves into `home/`, symlinks back), `[i]gnore forever` (writes to `.dotignore`), `[s]kip`, `[q]uit`.
- A fisher-plugin drift pass: installed plugins not in `fish_plugins`, and vice versa.
- A univ-var drift pass: groups installed fish universals by prefix. `[t]rack pattern` adds e.g. `tide_*` to `.univexport` and regenerates `home/.config/fish/exported-univ-vars.fish`; `[i]gnore forever` adds the pattern to `.univignore`.
- A brew-drift pass: installed brews/casks/MAS apps not in `Brewfile`, and vice versa.
- A secret-scan against the staged diff before commit (auto-aborts on AWS/GitHub/Slack/Stripe/OpenAI/Anthropic/Google tokens, JWTs, private keys).
- A commit (auto, on your machine-branch).
- An optional claude doc-sync pass (if you opted in).
- A push prompt with preview (commit count + filename stats + `[d]iff` for full).

Everything is non-destructive. Hitting `[s]kip` for everything is a valid outcome — wrangle just makes no changes and exits.

For the per-domain detail on what each pass does, see **[README.md → How tracking works](README.md#how-tracking-works)**.

---

## Daily use

Three subcommands cover the everyday loop:

- `wrangle sync` — the main one: detect drift across all domains, prompt per-item, commit, optionally push.
- `wrangle pull` — fetch origin and cascade-merge along the parent chain. Framework updates and commits from upstream machine-branches arrive here.
- `wrangle push` — push your current branch's commits.

`wrangle help` lists the rest (env vars, git config keys, the less-frequent subcommands like `import-univ-vars`, `set-parent`, `review-docs`, `reset-claude-session`). `wrangle help <subcommand>` (or `wrangle <subcommand> --help`) describes a single subcommand's flags.

The repo nags you in three ways from new shells. All are colorized and prefixed with `wrangle:` so it's obvious where they come from, and each suggests a concrete subcommand to fix the situation:

- **Staleness nag** — fires once per shell if `wrangle` hasn't run in > 7 days. Suggests `wrangle sync`.
- **Unpushed nag** — fires once per shell if the current branch has unpushed commits. Suggests `wrangle push`.
- **Pull nag** — fires when any chain-edge has new upstream commits, but **self-suppresses** for already-seen upstream SHAs (so you're not nagged twice about the same commits). Suggests `wrangle pull`.

All three are silenceable via env var (`WRANGLE_NO_STALENESS_NAG=1`, `WRANGLE_NO_PUSH_NAG=1`, `WRANGLE_NO_PULL_NAG=1`) but the nags themselves don't advertise this — they're designed to fire only when they have something new to say.

---

## Detaching a machine

```fish
cd <your-repo>
stow -t ~ -D home    # removes every symlink wrangle has stowed back into ~
```

The repo itself is untouched. Re-stow any time with `stow --no-folding -t ~ home`.

---

## Where things live

- `~/.cache/dotfiles/last-wrangle` — last successful run timestamp (machine-local).
- `~/.cache/dotfiles/wrangle-config` — claude opt-in answer (machine-local).
- `~/.cache/dotfiles/claude-session-id` — cached claude session for resumption.
- `~/.cache/dotfiles/pull-cascade-state` — set when a `wrangle pull` hits a conflict; consumed by `wrangle pull --resume`.
- `~/.cache/dotfiles/pull-nag-state` — per-parent SHA last nagged about (so the pull nag doesn't re-fire for the same commits).
- `<repo>/.wrangle-changelog` — running log of structural changes (used by claude when enabled).
- `<repo>/.dotignore`, `<repo>/.brewignore`, `<repo>/.univexport`, `<repo>/.univignore` — ignore/allowlists, tracked on your machine-branch.
- `<repo>/home/.config/fish/exported-univ-vars.fish` — auto-regenerated snapshot of universals matching `.univexport` patterns. Restore on a new machine with `wrangle import-univ-vars`.

---

## Branches

For the full branch-model explanation see **[README.md → Branch model](README.md#branch-model)**. Quick summary:

- **`main`** is framework only — wrangle/bootstrap scripts, ignore-list templates, tests, docs. Shared and semver-tagged.
- **Your machine-branch** (default `personal`) is your machine state — `.gitconfig`, vim configs, Brewfile, plugin lists, captured universals. Per-user, can chain to other machine-branches (e.g., `work → personal → main`).

Wrangle's Pass 1 walks the parent chain at the start of every `wrangle sync` run and merges parents into their children, so framework updates flow into your machine-branch automatically. You never need to merge back to `main`. If you want to detach from upstream framework updates for one run, use `wrangle sync --no-branch-switch`.
