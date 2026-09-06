if (($+commands[fzf])); then
    if (($+widgets[atuin-search])); then
        # Leave Ctrl-R to Atuin when its history widget is available.
        FZF_CTRL_R_COMMAND="" _cached_eval fzf --zsh
    else
        _cached_eval fzf --zsh
    fi
fi
