# 🤠 wrangle 

A sync system for keeping your macOS shell + tooling state consistent across machines, without ever asking you to maintain the inventory by hand.

## What this is

You install tools, write dotfiles, install fisher plugins, configure plugins via fish universals. Over time your machine drifts from anything you've checked in. Normally you'd notice this only when standing up a new machine — at which point you scramble to reconstruct what you had.

Wrangle is a fish script that turns "the current state of my machine" into something **git-tracked, branchable per-machine, and replayable on a fresh box**. The way it does that:

- Each run, wrangle walks your live machine and compares it against the tracked state. Drift goes both ways, and the prompts differ depending on which direction is out of sync:
  - **The machine has something the repo doesn't** (you installed a brew, added a fisher plugin, dropped a new dotfile in `~/.config/`) → wrangle prompts per item: `[t]rack` it into the repo, `[i]gnore forever`, or `[s]kip` for now.
  - **The repo has something the machine doesn't yet** (another of your machines tracked it, you `wrangle pull`ed it down, and it's not present locally) → for fisher and brew, wrangle prompts per item: `[i]nstall` it or `[r]emove` it from the tracked list. For dotfiles, no prompt — stow symlinks newly-tracked files into `~` automatically. The one case that *does* halt is a conflict: a tracked dotfile whose target path already has a real (non-symlink) file with different contents. Stow refuses to clobber, wrangle reports the conflict, and you resolve it by hand (typically: diff, move your local copy aside, re-run — or accept the local copy and re-track it).
  
  Once an already-tracked dotfile is symlinked, "conflicting contents" can't happen — `~/.config/foo` and `home/.config/foo` are the same inode, so editing either is editing both. Conflicts only arise the first time a tracked file lands on a machine that already had its own version.

- The capture strategy per domain:
  - **Dotfiles** go under `home/` and get [GNU stow](https://www.gnu.org/software/stow/)–symlinked back into `~`.
  - **Brew formulae, casks, and Mac App Store apps** go into a `Brewfile` (via `brew bundle dump`, filtered through your `.brewignore`). On a new machine, `brew bundle install` (or wrangle's own prompt) reinstalls everything from that file.
  - **Fisher plugins** go into `fish_plugins`, which fisher itself reads on `fisher update`.
  - **Fish universal variables** (the ones plugins like tide use for config) get captured into a sourceable file you can replay on another machine via `wrangle import-univ-vars`.

- The whole repo is a **git repo with a branch per machine**. Wrangle's commits go to your machine's branch; framework changes (the wrangle script itself, etc.) live on `main`. Branches declare a parent so updates flow downstream — your laptop branches off `main`, your work machine can branch off your laptop, etc. The `wrangle pull` / `sync` / `push` subcommands wrap the git-side mechanics so you rarely touch git directly.

- Every commit goes through a **pre-commit regex secret-scan** that catches the obvious shapes (AWS / GitHub / Stripe / OpenAI / Anthropic keys, JWTs, PEM / SSH / PGP blocks). On a hit wrangle refuses to commit unless you set `WRANGLE_ALLOW_SECRETS=1`.

- Wrangle optionally uses [claude-code](https://github.com/anthropics/claude-code) for two things: summarizing commit diffs into nicer commit messages, and reviewing the repo's docs when changes accumulate. Both are opt-in; first run asks. Everything else works with claude off.

Day-to-day there are three subcommands that matter:

- `wrangle sync` — the main one: detect drift, ask per-item, commit, optionally push.
- `wrangle pull` — bring framework updates (or upstream parent-branch changes) down.
- `wrangle push` — push your current branch's commits.

`wrangle help` lists the rest.

## Quick start

```bash
git clone <this-repo-url> <wherever-you-want>
cd <that-dir>
./scripts/bootstrap
```

`bootstrap` is a bash script that:

1. Installs Homebrew if missing.
2. Brew-installs the minimum kit wrangle needs: `fish`, `stow`, `git`, `mas`.
3. Adds fish to `/etc/shells` (sudo) and `chsh`'s your login shell to fish.
4. Prompts for this machine's branch name (default `personal`) and its parent (default `main`).
5. Stows the framework's conf.d hooks into `~/.config/fish/conf.d/`.
6. Bootstraps fisher.
7. Launches your first `wrangle sync`.

Everything is idempotent and non-destructive — safe to re-run on a partially-set-up machine. The full walkthrough is in [setup-new-machine.md](setup-new-machine.md).

## The flow you'll actually use

After bootstrap:

- **You install a new tool / edit a dotfile / install a fisher plugin.** Wrangle doesn't watch for changes — it's pull-based.
- **You run `wrangle sync` whenever you want to capture what's drifted.** It walks each domain (dotfiles, fisher, universals, brew), prompts per-item, makes the chosen edits, commits, and offers to push.
- **You run `wrangle pull` when a framework release ships** (or another machine of yours has pushed changes to a branch yours is based on). It fetches origin and merges parent-branches into yours along the chain.
- **You run `wrangle push` when the shell-start nag tells you have unpushed commits** — usually because you said `[N]o` to the push prompt at the end of a sync.

Three nags fire on shell start to keep you honest: staleness (haven't run wrangle in a week), unpushed (you have local commits not on origin), and pull-pending (origin has commits you haven't merged down). All three are colorized and prefixed with `wrangle:` and each one suggests the exact subcommand that resolves it.

## How tracking works

`stow` is the load-bearing piece. The repo has a `home/` directory that mirrors your `~` layout. When a file lives at `home/.config/fish/config.fish`, stow creates a symlink at `~/.config/fish/config.fish` pointing back into the repo. Edits to either path are edits to the same file. Wrangle re-stows every run, so newly-tracked files get linked automatically.

Domain-specific bits:

- **Dotfiles**: wrangle walks top-level `~/.<name>` files and `~/.config/*` entries. For each one not already a symlink-into-the-repo and not on the ignore list, it offers to `[t]rack` (mv into `home/`, symlink back), `[i]gnore forever` (append to `.dotignore`), `[s]kip` (decide later), or `[q]uit`.
- **Fisher plugins**: compares `fisher list` against the tracked `fish_plugins` file. Two directions: plugins installed but not tracked → offer to track or uninstall; plugins tracked but not installed → offer to install (with a spinner) or remove from the file.
- **Fish universals**: collects current universals (`set -U -L`), auto-skips anything starting with `_` (fish + plugin internal convention), groups the rest by prefix. For each new prefix group, offers to track the pattern (e.g. `tide_*`) into `.univexport`, ignore forever into `.univignore`, or skip.
- **Brew**: calls `dump-brewfile` (a thin wrapper around `brew bundle dump --describe --force` with `.brewignore` filtering applied) and diffs against your tracked `Brewfile`. Installed-but-not-tracked → track / ignore-via-substring / skip. Tracked-but-not-installed → install / remove / skip.

Wrangle also catches files that are tracked but have uncommitted changes (e.g. you edited your `config.fish` directly without running wrangle): each pass reports its domain's dirty files so they get committed alongside any newly-tracked items.

## Branch model

Each machine commits to its own branch and declares a parent. Framework changes (the wrangle script itself, etc.) live on `main`. Your machine's branch (default name `personal`) declares `main` as its parent. If you want a second machine that builds on the first, give it its own branch that declares `personal` as its parent — and so on for arbitrary depth.

```
main                     framework
  └─ personal            your laptop (parent = main)
       └─ work           your work machine (parent = personal)
       └─ workshop       your shop machine (parent = personal)
```

Two git config keys control this, per-clone (not pushed):

- `wrangle.machine-branch <name>` — which branch this clone commits to.
- `branch.<name>.wrangle-parent <parent>` — that branch's parent in the chain.

Both default sensibly: missing `wrangle.machine-branch` → `personal`; missing `branch.<X>.wrangle-parent` → `main`. Bootstrap sets them explicitly on first run.

`wrangle pull` walks the chain root-toward-leaf, fast-skipping any edge that's already up-to-date and real-merging the rest (with `--no-ff`, so the merge boundary stays visible in `git log`). On merge conflict it stops mid-cascade, prints what to resolve, and you continue with `wrangle pull --resume` after `git add` + `git commit`.

You declare a new branch's parent with `wrangle set-parent <parent>` (which is just a typed wrapper around `git config branch.<current>.wrangle-parent <parent>`).

## Repo layout

```
scripts/
  bootstrap      Bash. The one-time setup script.
  wrangle        Fish. The everyday command.
  dump-brewfile  Fish. `brew bundle dump` with .brewignore filtering applied.
  scan-secrets   Fish. Pre-commit safety net for high-confidence secret patterns.
  bump-version   Bash. Semver-tags main. Called by the release workflow, rarely manually.
  run-tests      Bash. Wraps fishtape over test/*.fish.

test/            Fishtape tests covering wrangle CLI surface, scan-secrets, dump-brewfile, bump-version.

.github/workflows/
  test.yml       Runs the test suite on every push/PR.
  release.yml    On a release:*-labeled PR merging to main, tags + cuts a GitHub Release.

home/            Mirrors ~. Stow-managed. On main, only contains the framework's
                 conf.d hooks. Your machine-branch builds up tracked dotfiles here.

.dotignore       Per-line substring patterns / globs that the dotfile pass skips.
.brewignore      Per-line substrings that get stripped from auto-dumped Brewfile.
.univexport      Allowlist of fish-universal-variable patterns to capture.
.univignore      Blocklist of universals to never ask about.
.gitignore       Editor swap files, macOS noise, .env, .wrangle-changelog, etc.

setup-new-machine.md   Walkthrough for the first run on a fresh machine.
```

Things that aren't on `main` (they're personal-layer, on your machine-branch): `Brewfile`, your personal `config.fish` / `fish_plugins` / `.gitconfig` / vim configs, the auto-generated `home/.config/fish/exported-univ-vars.fish`.

## Subcommand reference

`wrangle help` is the authoritative source — it prints subcommands, env vars, and git config keys in one shot. `wrangle help <subcmd>` (or equivalently `wrangle <subcmd> --help`) describes a single subcommand's flags.

| Subcommand | What it does |
|---|---|
| `wrangle sync` | The main workflow. Detect drift across all domains, prompt per item, commit, push. Accepts `--dry-run`, `--force`, `--with-claude` / `--suppress-claude`, `--no-branch-switch`. |
| `wrangle pull` | Fetch origin + cascade-merge along the parent chain. Accepts `--resume` to continue after a conflict. |
| `wrangle push` | Push the current branch to origin, with a preview of what's about to ship. No prompt — typing the subcommand is the decision. |
| `wrangle review-docs` | Skip drift; have claude review the repo's docs against recent commits. |
| `wrangle import-univ-vars` | Source `home/.config/fish/exported-univ-vars.fish` to restore captured plugin universals on a new machine. |
| `wrangle set-parent <branch>` | Declare `<branch>` as the current branch's wrangle-parent (writes git config). |
| `wrangle reset-claude-session` | Drop the cached claude session id. Next claude call starts fresh. |

Bare `wrangle`, `wrangle -h`, and `wrangle --help` all print top-level help. There's no implicit-sync shortcut — type `wrangle sync` to sync.

## Customization

There are four user-editable files at the repo root that wrangle reads. All take one substring / fish-glob pattern per line; `#` comments are fine.

| File | What it controls | Typical entries |
|---|---|---|
| `.dotignore` | Paths under `~` that wrangle never asks about. Pre-populated with credential-bearing paths (`.aws`, `.config/gh`, `.npmrc`, etc.). | Credential dirs, caches, history files, big data dirs. |
| `.brewignore` | Lines stripped from the auto-dumped Brewfile *before* wrangle compares against the tracked Brewfile. | Apps you've installed locally but don't want to drag to other machines. |
| `.univexport` | Fish universal-variable names/patterns to capture into the exportable file. | `tide_*`, `sponge_*`, etc. Exact names also work (override the auto-skip of `_*`). |
| `.univignore` | Universal-variable names/patterns wrangle never asks about. | `_*` (fish/plugin internal state) — already auto-skipped, so this is mainly for one-off vars. |

All four can be edited by hand. Wrangle also writes to them when you answer `[t]rack` or `[i]gnore forever` during a sync, so you usually don't have to.

The default `.dotignore` ships pre-populated with credential paths, key-file globs, common shell/OS noise, and tool caches that you almost certainly don't want to sync. Delete any line you disagree with. `wrangle sync --force` bypasses `.dotignore` entirely (including the credential entries) — the pre-commit secret-scan is the secondary safety net that catches anything obvious in that case.

## Shell integration

Bootstrap stows one conf.d hook into your `~/.config/fish/conf.d/` (it's a symlink, so updates flow automatically through `wrangle pull`):

**`wrangle_integration.fish`** does four things on every interactive shell start:

1. Adds `<repo>/scripts/` to `$PATH` so `wrangle` and friends are callable.
2. **Staleness nag** if wrangle hasn't run in > 7 days. Suggests `wrangle sync`.
3. **Unpushed nag** if your current branch has unpushed commits. Suggests `wrangle push`.
4. **Pull nag** if origin has commits on any chain edge you haven't merged. Suggests `wrangle pull`. This one self-suppresses for already-seen upstream SHAs, so it only re-fires on genuinely new commits.

All three nags are colorized and prefixed with `wrangle:`. Each has a corresponding `WRANGLE_NO_*_NAG=1` env var to silence it (see [Env vars](#env-vars-and-git-config) below).

## Env vars and git config

Env vars (set in `config.fish` for permanent effect):

| Var | Effect |
|---|---|
| `WRANGLE_NO_COMMIT` | Skip the commit step at the end of `sync`. |
| `WRANGLE_NO_PUSH` | Skip the push step at the end of `sync`. |
| `WRANGLE_NO_PUSH_NAG` | Silence the shell-start unpushed-commits nag. |
| `WRANGLE_NO_PULL_NAG` | Silence the shell-start pull-pending nag. |
| `WRANGLE_NO_STALENESS_NAG` | Silence the shell-start staleness nag. |
| `WRANGLE_NO_BRANCH_SWITCH` | Skip the parent-chain pull at the start of `sync`. |
| `WRANGLE_ALLOW_SECRETS` | Bypass `scan-secrets` at commit time (use only when you've verified the hits are test fixtures or false positives). |
| `WRANGLE_CLAUDE_MODEL` | Override the claude model (default `sonnet`). |
| `WRANGLE_CLAUDE_EFFORT` | Override claude effort: `low` (default) / `medium` / `high` / `xhigh` / `max`. |

Git config (per-clone, in `.git/config`):

| Key | Default | Purpose |
|---|---|---|
| `wrangle.machine-branch` | `personal` | Which branch this clone commits to. |
| `branch.<X>.wrangle-parent` | `main` (when `<X>` is not `main`) | What `<X>` merges from during `wrangle pull`. |

Cache files at `~/.cache/dotfiles/` (nothing user-facing — documented here for the rare debug case):

```
last-wrangle           timestamp of last successful sync (drives staleness nag)
wrangle-config         "WRANGLE_CLAUDE_OPT_IN=yes" or =no, set by first-run question
claude-session-id      persistent UUID for claude --session-id
pull-cascade-state     set when a `wrangle pull` hits a conflict; consumed by `--resume`
pull-nag-state         per-parent SHA last nagged about (deduplicates the pull nag)
```

## Releasing framework updates (for maintainers)

Framework changes ship through a PR-driven flow. Tagging and the GitHub Release are automated.

```fish
git checkout main && git pull
git checkout -b some-change
# edit scripts/, tests, docs, etc.
git commit -am "describe the change"
git push -u origin some-change
gh pr create --base main --title "..." --label release:patch   # or release:minor / release:major
```

When the PR is green and you merge it (rebase merge — main stays linear), `.github/workflows/release.yml` reads the `release:*` label, calls `scripts/bump-version`, pushes the next `vX.Y.Z` tag, and creates a GitHub Release with auto-generated notes.

PRs without a `release:*` label merge normally but don't bump the version — use that for changes that aren't user-visible (CI tweaks, README typos, etc.). To release after the fact, label another PR or run `scripts/bump-version` manually.

Released framework updates flow into your machine-branch the next time you run `wrangle pull` (or `wrangle sync`, which starts with a pull). You don't manually merge main into anything.

## Key principles

- **Non-destructive.** Nothing overwrites existing user files. `bootstrap` only does idempotent appends + chsh + brew installs. `wrangle` only moves files when you say `[t]rack`.
- **Inventories are auto-captured.** Brewfile, fish_plugins, the dotfile tree, the captured universals — wrangle maintains them. You don't hand-edit them.
- **Secrets stay out by construction.** Credential paths and key-file globs are pre-populated in `.dotignore`, and a pre-commit regex secret-scan catches anything that slips through.
- **LLM-optional.** Wrangle can use claude-code to keep docs in sync and to summarize diffs into commit messages, but the rest works fine with claude off. Opt-in is asked on first run, controllable per-run via `--with-claude` / `--suppress-claude`.
