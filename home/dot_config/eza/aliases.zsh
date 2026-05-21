alias eza="LS_COLORS= eza"
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --color=always --no-quotes"
    alias l="eza --all --icons --group-directories-first --oneline"
    alias ll="eza --all --icons --group-directories-first --long --header --git --octal-permissions"
    alias lt="eza --all --tree --level 2"
fi
