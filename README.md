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

On a new Linux installation, bootstrap asks `Use HPC settings? [y/N]`.
The default uses `~/.pixi` and excludes the Biowulf configuration. Answering
yes uses `/data/$USER/.pixi` and enables that configuration. An existing
`PIXI_HOME` always takes precedence.

On macOS, bootstrap also asks whether to enable Touch ID for `sudo`. The
default is yes; enabling it updates `/private/etc/pam.d/sudo_local`.

## What bootstrap installs

`./bootstrap` installs the top-level projects below. Versions are defined in the
[Pixi](home/dot_config/pixi/pixi-global.toml),
[macOS Pixi](home/dot_config/pixi/pixi-macos.toml), and
[mise](home/dot_config/mise/config.toml) manifests.

### Bootstrap

- [Pixi](https://github.com/prefix-dev/pixi) · [chezmoi](https://github.com/twpayne/chezmoi) · [mise](https://github.com/jdx/mise)

### Language runtimes

- [Python](https://github.com/python/cpython) · [Node.js](https://github.com/nodejs/node) · [R](https://github.com/wch/r-source)† · [Ruby](https://github.com/ruby/ruby) · [Rust](https://github.com/rust-lang/rust) · [Go](https://github.com/golang/go)

### Cross-platform CLI tools

- Shell and terminal: [Atuin](https://github.com/atuinsh/atuin) · [btop](https://github.com/aristocratos/btop) · [direnv](https://github.com/direnv/direnv) · [eza](https://github.com/eza-community/eza) · [fd](https://github.com/sharkdp/fd) · [fzf](https://github.com/junegunn/fzf) · [ncdu](https://github.com/conda-forge/ncdu-feedstock)† · [sesh](https://github.com/joshmedeski/sesh) · [Sheldon](https://github.com/rossmacarthur/sheldon) · [Starship](https://github.com/starship/starship) · [Superfile](https://github.com/yorukot/superfile) · [tmux](https://github.com/tmux/tmux) · [zoxide](https://github.com/ajeetdsouza/zoxide)
- Development: [bat](https://github.com/sharkdp/bat) · [Docker CLI](https://github.com/docker/cli) · [GitHub CLI](https://github.com/cli/cli) · [Google Cloud CLI](https://github.com/conda-forge/google-cloud-sdk-feedstock)† · [lazydocker](https://github.com/jesseduffield/lazydocker) · [lazygit](https://github.com/jesseduffield/lazygit) · [Neovim](https://github.com/neovim/neovim) · [pip](https://github.com/pypa/pip) · [pipx](https://github.com/pypa/pipx) · [ripgrep](https://github.com/BurntSushi/ripgrep) · [uv](https://github.com/astral-sh/uv)
- Utilities: [FFmpeg](https://github.com/FFmpeg/FFmpeg) · [MuPDF](https://github.com/ArtifexSoftware/mupdf) · [GNU Parallel](https://github.com/martinda/gnu-parallel)† · [rsync](https://github.com/WayneD/rsync) · [tealdeer](https://github.com/dbrgn/tealdeer)

### macOS-only Pixi tools

- [ExifTool](https://github.com/exiftool/exiftool) · [Colima](https://github.com/abiosoft/colima) · [Vercel CLI](https://github.com/vercel/vercel) · [Ollama](https://github.com/ollama/ollama) · [yt-dlp](https://github.com/yt-dlp/yt-dlp) · [Fastfetch](https://github.com/fastfetch-cli/fastfetch) · [shfmt](https://github.com/mvdan/sh) · [rclone](https://github.com/rclone/rclone)

### mise-managed tools

- Cross-platform: [Antigravity CLI](https://github.com/google-antigravity/antigravity-cli) · [Codex CLI](https://github.com/openai/codex) · [Claude Code](https://github.com/anthropics/claude-code) · [herdr](https://github.com/ogulcancelik/herdr) · [sharp-cli](https://github.com/vseventer/sharp-cli) · [llmfit](https://github.com/AlexsJones/llmfit) · [multi-git-status](https://github.com/fboender/multi-git-status)
- macOS only: [1Password CLI](https://github.com/1Password/install-cli-action)† · [dooti](https://github.com/lkubb/dooti) · [Things CLI](https://github.com/ryanlewis/things-cli) · [Mole](https://github.com/tw93/Mole)

### Fonts

- [Fira Code](https://github.com/tonsky/FiraCode) · [Inter](https://github.com/rsms/inter) · [Meslo LG](https://github.com/andreberg/Meslo-Font) · [Sahel](https://github.com/rastikerdar/sahel-font) · [Symbols Nerd Font Mono](https://github.com/ryanoasis/nerd-fonts) · [Vazirmatn](https://github.com/rastikerdar/vazirmatn)

† A maintained GitHub mirror, package feedstock, or official installer is linked
when the upstream project does not publish a canonical public GitHub repository.

## Update

```bash
pixi self-update && pixi global outdated && pixi global update
mise outdated && mise upgrade
apps -o && apps -u
```
