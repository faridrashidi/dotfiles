# dotfiles

My personal dotfiles and macOS/Linux setup automation.

<p align="center">
  <img
    src="https://github.com/user-attachments/assets/3a121cc6-d4df-40d7-b7d1-11309a157cc9"
    alt="Dotfiles environment"
    width="1200"
  >
</p>

## Installation

```bash
git clone https://github.com/faridrashidi/dotfiles
cd dotfiles
./bootstrap
```

Requires Git, Bash, and curl. macOS also requires Xcode Command Line Tools.
On Linux, Zsh is installed with Pixi.
On first run, bootstrap asks for your Git name and email. For unattended runs
(cloud-init, Packer, CI), set them in the environment instead:

```bash
GIT_NAME="Your Name" GIT_EMAIL="you@example.com" ./bootstrap
```

On Linux, bootstrap asks for a profile, or reads `DOTFILES_PROFILE`:

- `desktop` (default, and always used on macOS): everything below.
- `server`: for cloud VMs. Installs only the "All profiles" tools in the
  [Pixi manifest](home/dot_config/pixi/pixi-global.toml.tmpl), plus Zsh. Skips
  mise-managed tools and fonts.
- `hpc`: everything except fonts, FFmpeg, Google Cloud CLI, and Wrangler. Uses
  `/data/$USER/.pixi` and enables the Biowulf configuration.
  Atuin uses a separate local database for each shell, with offline history
  exchange and backups on `/data`. No Atuin account is needed.

An existing `PIXI_HOME` always takes precedence.

### Biowulf history

Each interactive Zsh shell gets its own Atuin databases on local storage.
An allocated `/lscratch/$SLURM_JOB_ID` is preferred, then a local `TMPDIR`,
then `/tmp`. Network filesystems are rejected for the live databases.
Atuin's daemon, cloud sync, and update checks are disabled on Biowulf.

History changes are saved every 30 seconds and on normal shell exit under
`/data/$USER/.local/share/atuin-offline/snapshots`. Each shell publishes its
own closed SQLite snapshot by atomic replacement. Other shells copy these
files locally before reading and merging them. Only changed entries are
published; unfinished commands cannot overwrite completed ones, and deleted
entries stay deleted. Shared files are never opened as live SQLite databases.
Snapshots and their directory are private to the user.

New shells restore the saved history automatically. Running shells receive
other sessions' saved changes during the next 30-second checkpoint. Force a
checkpoint with `_atuin_offline_save`. If a node or job is killed abruptly,
changes since the last successful checkpoint may be lost. Keep snapshots on
`/data`: Slurm deletes a job's local scratch directory when the job ends.
Failed backups leave the local files in place and are reported in
`$ATUIN_DATA_DIR/backup.log`.

When migrating an existing installation, stop the old Atuin daemon and export
a consistent copy of its history to `snapshots/seed.db` before enabling this
configuration. Startup refuses to silently replace existing history with an
empty archive. Use a SQLite backup, rather than copying an open database and
omitting its WAL file. Restart existing shells after migration.

## What bootstrap installs

`./bootstrap` installs the top-level projects below. Versions are defined in the
[Pixi](home/dot_config/pixi/pixi-global.toml.tmpl) and
[mise](home/dot_config/mise/config.toml.tmpl) manifests.

### Bootstrap

- [Pixi](https://github.com/prefix-dev/pixi)
- [chezmoi](https://github.com/twpayne/chezmoi)
- [mise](https://github.com/jdx/mise)

### Language runtimes

- [Python](https://github.com/python/cpython) (3.12.12)
- [Node.js](https://github.com/nodejs/node) (26.8.1)
- [R](https://github.com/wch/r-source)† (4.3.3)
- [Ruby](https://github.com/ruby/ruby) (4.0.6)
- [Rust](https://github.com/rust-lang/rust) (1.98.1)
- [Go](https://github.com/golang/go) (1.27.1)

### Cross-platform CLI tools

- Shell and terminal:
  - [Atuin](https://github.com/atuinsh/atuin)
  - [btop](https://github.com/aristocratos/btop)
  - [direnv](https://github.com/direnv/direnv)
  - [dust](https://github.com/bootandy/dust)
  - [eza](https://github.com/eza-community/eza)
  - [fd](https://github.com/sharkdp/fd)
  - [fzf](https://github.com/junegunn/fzf) (0.68.0)
  - [ncdu](https://github.com/conda-forge/ncdu-feedstock)†
  - [sesh](https://github.com/joshmedeski/sesh)
  - [Sheldon](https://github.com/rossmacarthur/sheldon)
  - [Starship](https://github.com/starship/starship)
  - [Superfile](https://github.com/yorukot/superfile)
  - [tmux](https://github.com/tmux/tmux) (3.5a)
  - [zoxide](https://github.com/ajeetdsouza/zoxide)
- Development:
  - [bat](https://github.com/sharkdp/bat)
  - [Docker CLI](https://github.com/docker/cli) (29.6.2)
  - [Git](https://github.com/git/git)
  - [GitHub CLI](https://github.com/cli/cli) (2.96.0)
  - [Google Cloud CLI](https://github.com/conda-forge/google-cloud-sdk-feedstock)†
  - [lazydocker](https://github.com/jesseduffield/lazydocker) (0.24.4)
  - [lazygit](https://github.com/jesseduffield/lazygit) (0.58.1)
  - [Neovim](https://github.com/neovim/neovim)
  - [ripgrep](https://github.com/BurntSushi/ripgrep)
  - [ripgrep-all](https://github.com/phiresky/ripgrep-all)
  - [uv](https://github.com/astral-sh/uv)
- Utilities:
  - [FFmpeg](https://github.com/FFmpeg/FFmpeg)
  - [jq](https://github.com/jqlang/jq)
  - [MuPDF](https://github.com/ArtifexSoftware/mupdf)
  - [ouch](https://github.com/ouch-org/ouch)
  - [GNU Parallel](https://github.com/martinda/gnu-parallel)†
  - [rsync](https://github.com/WayneD/rsync)
  - [sd](https://github.com/chmln/sd)
  - [tealdeer](https://github.com/dbrgn/tealdeer)
  - [VisiData](https://github.com/saulpw/visidata)

### macOS-only Pixi tools

- [ExifTool](https://github.com/exiftool/exiftool)
- [Colima](https://github.com/abiosoft/colima)
- [Vercel CLI](https://github.com/vercel/vercel)
- [Ollama](https://github.com/ollama/ollama)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [Fastfetch](https://github.com/fastfetch-cli/fastfetch)
- [shfmt](https://github.com/mvdan/sh)
- [rclone](https://github.com/rclone/rclone)

### Linux-only Pixi tools

- [Zsh](https://github.com/zsh-users/zsh)

### mise-managed tools

- Cross-platform:
  - [Antigravity CLI](https://github.com/google-antigravity/antigravity-cli)
  - [Codex CLI](https://github.com/openai/codex)
  - [Claude Code](https://github.com/anthropics/claude-code)
  - [herdr](https://github.com/ogulcancelik/herdr)
  - [gitmoji-cli](https://github.com/carloscuesta/gitmoji-cli)
  - [sharp-cli](https://github.com/vseventer/sharp-cli)
  - [skills](https://github.com/vercel-labs/skills)
  - [Wrangler](https://github.com/cloudflare/workers-sdk)
  - [llmfit](https://github.com/AlexsJones/llmfit)
  - [mgitstatus](https://github.com/fboender/multi-git-status)
- macOS only:
  - [1Password CLI](https://github.com/1Password/install-cli-action)†
  - [dooti](https://github.com/lkubb/dooti)
  - [Mole](https://github.com/tw93/Mole)

### Fonts

- [Fira Code](https://github.com/tonsky/FiraCode)
- [Inter](https://github.com/rsms/inter)
- [Lalezar](https://github.com/google/fonts/tree/main/ofl/lalezar)
- [Meslo LG](https://github.com/andreberg/Meslo-Font)
- [Sahel](https://github.com/rastikerdar/sahel-font)
- [Symbols Nerd Font Mono](https://github.com/ryanoasis/nerd-fonts)
- [Vazirmatn](https://github.com/rastikerdar/vazirmatn)

† A maintained GitHub mirror, package feedstock, or official installer is linked
when the upstream project does not publish a canonical public GitHub repository.

## Update

The current Atuin upgrades on macOS and Biowulf are installed inside this
checkout at `.tools/pixi`. The existing Pixi Atuin environment links to that
directory. Keep `.tools` in place while those launchers are in use; it is
excluded from Git.

```bash
pixi self-update && pixi global-outdated && pixi global update
mise outdated && mise upgrade && mise prune -y
apps -o && apps -u
```
