# Avoid querying Atuin on every keystroke, even with its local database.
ZSH_AUTOSUGGEST_STRATEGY=(history)

[[ "$PWD" == "$HOME" && -d "$DATA" ]] && cd "$DATA"
