export ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"

# Keep history (state) and caches out of the config directory.
export HISTFILE="$XDG_STATE_HOME/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
export HISTSIZE=1000000
export SAVEHIST=1000000
export LESSHISTFILE="-"
