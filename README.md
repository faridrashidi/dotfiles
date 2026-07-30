# dotfiles

My personal dotfiles and macOS/Linux setup automation, managed with [pixi](https://github.com/prefix-dev/pixi), [mise](https://github.com/jdx/mise), and [chezmoi](https://github.com/twpayne/chezmoi).

## Installation

```bash
git clone https://github.com/faridrashidi/dotfiles
cd dotfiles
./bootstrap
```

## Update

```bash
pixi self-update && pixi global outdated && pixi global update
mise outdated && mise upgrade
apps -o && apps -u
```
