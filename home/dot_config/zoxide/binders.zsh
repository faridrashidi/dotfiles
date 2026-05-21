function _zoxide_fzf_widget() {
    # 1. Check if zoxide is installed
    if ! command -v zoxide &>/dev/null; then
        echo "Error: zoxide is not installed."
        zle reset-prompt
        return
    fi

    # 2. Prepare the screen
    zle -I

    # 3. Run zoxide list piped into fzf
    # FIX: We use 'sh -c ... -- {}' pattern.
    # This passes the file path ({}) as argument $1 to the shell command.
    # This avoids all quoting issues because we never paste the path into the string itself.
    local preview_cmd='eza -1 --color=always --icons --group-directories-first --git --git-ignore "$1"'
    local dir=$(zoxide query -l |
        fzf --query "$BUFFER" \
            --preview "sh -c '$preview_cmd' -- {}")

    # 4. Handle selection
    if [ -n "$dir" ]; then
        BUFFER="cd \"$dir\""
        zle accept-line
    else
        zle reset-prompt
    fi
}
zle -N _zoxide_fzf_widget
bindkey "^z" _zoxide_fzf_widget
