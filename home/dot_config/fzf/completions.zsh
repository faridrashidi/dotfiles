#!/usr/bin/env zsh

###############################################################################
# 1. Menu Appearance                                                          #
###############################################################################

# fzf-tab ignores FZF_DEFAULT_OPTS unless told otherwise
zstyle ':fzf-tab:*' use-fzf-default-opts yes

# LS_COLORS is deliberately left unset so eza uses its own theme.yml, so give
# the completion menu an explicit gruvbox-material palette instead
zstyle ':completion:*' list-colors \
    'di=38;5;109' 'ln=38;5;108' 'ex=38;5;142' 'so=38;5;175' \
    'pi=38;5;214' 'bd=38;5;167' 'cd=38;5;167'

# Group results by completion type; page between groups with < and >
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' fzf-min-height 15

# Render in a tmux popup; falls back to inline fzf when not inside tmux
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:*' popup-min-size 80 15

###############################################################################
# 2. Previews                                                                 #
###############################################################################

# Directory arguments — list contents
zstyle ':fzf-tab:complete:(cd|z|zi|__zoxide_z|ls|l|ll|lt|eza|pushd|rmdir):*' fzf-preview \
    'eza -1 --color=always --icons --group-directories-first -- "$realpath"'

# Everything else — directory listing or syntax-highlighted file contents
zstyle ':fzf-tab:complete:*:*' fzf-preview \
    'if [[ -d "$realpath" ]]; then
         eza -1 --color=always --icons --group-directories-first -- "$realpath"
     else
         bat --color=always --style=numbers --line-range=:200 -- "$realpath" 2>/dev/null
     fi'

# Variables and exports — show the current value
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
    fzf-preview 'echo ${(P)word}'

# git — show the diff or log for the highlighted ref/path
zstyle ':fzf-tab:complete:git-(add|diff|restore|checkout|stash):*' fzf-preview \
    'git diff --color=always -- "$word" | head -200'
zstyle ':fzf-tab:complete:git-(log|show|revert|rebase|cherry-pick):*' fzf-preview \
    'git log --color=always --oneline --graph -20 "$word"'

# man pages
zstyle ':fzf-tab:complete:man:*' fzf-preview 'man -- "$word" 2>/dev/null | head -200'

# Processes — show the full command line
zstyle ':fzf-tab:complete:(kill|k):argument-rest' fzf-preview \
    'ps -p "$word" -o command= 2>/dev/null'
