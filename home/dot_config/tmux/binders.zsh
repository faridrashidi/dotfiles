function _sesh_session_picker() {
    if ! command -v sesh &>/dev/null; then
        echo "Error: sesh is not installed."
        zle reset-prompt >/dev/null 2>&1 || true
        return
    fi

    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf is not installed."
        zle reset-prompt >/dev/null 2>&1 || true
        return
    fi

    zle -I

    {
        exec </dev/tty
        exec <&1

        local session
        session=$(
            sesh list --icons | fzf \
                --ansi \
                --border \
                --border-label ' sesh ' \
                --height 40% \
                --preview 'sesh preview {}' \
                --preview-window 'right:55%' \
                --prompt '⚡  ' \
                --reverse
        )

        zle reset-prompt >/dev/null 2>&1 || true
        [[ -z "$session" ]] && return

        sesh connect "$session"
    }
}
zle -N _sesh_session_picker
bindkey '^t' _sesh_session_picker
