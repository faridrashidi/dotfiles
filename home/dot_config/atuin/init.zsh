if (($+commands[atuin])); then
    if [[ -r "$XDG_CONFIG_HOME/biowulf/atuin.zsh" ]]; then
        source "$XDG_CONFIG_HOME/biowulf/atuin.zsh" || return 0
    fi
    _cached_eval atuin init zsh
fi
