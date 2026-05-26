# dotfiles

My personal dotfiles and macOS/Linux setup automation, managed with [pixi](https://github.com/prefix-dev/pixi) and [chezmoi](https://github.com/twpayne/chezmoi).

## Installation

```bash
git clone https://github.com/faridrashidi/dotfiles
cd dotfiles
./bootstrap
```

## Update

```bash
pixi self-update && pixi-global-outdated && pixi-global-sync
npm -g outdated && npm -g update
pipx upgrade-all
apps -o && apps -u
```
