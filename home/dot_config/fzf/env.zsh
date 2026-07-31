export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_DEFAULT_OPTS="
  --height 40% --layout=reverse --border --info=inline-right
  --color=bg+:#3c3836,bg:#282828,spinner:#89b482,hl:#ea6962
  --color=fg:#d4be98,header:#ea6962,info:#d8a657,pointer:#89b482
  --color=marker:#89b482,fg+:#d4be98,prompt:#d8a657,hl+:#ea6962
  --color=border:#504945
  --bind 'ctrl-/:toggle-preview,ctrl-a:select-all'
  --bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down'
  --tmux center,90%,70%
  --scheme=path
"
export FZF_CTRL_T_COMMAND="fd --type=f --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_COMMAND="fd --type=d --strip-cwd-prefix --exclude .git"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
export FZF_TMUX_OPTS=" -p90%,70% "
