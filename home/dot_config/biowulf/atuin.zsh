# This runs before Atuin's init so it cannot open the shared legacy database.
_biowulf_atuin_offline_setup() {
    [[ -o interactive ]] || return 1
    (($+commands[python3])) || return 1
    export ATUIN_AUTO_SYNC=false ATUIN_UPDATE_CHECK=false
    export ATUIN_DAEMON__ENABLED=false ATUIN_DAEMON__AUTOSTART=false
    export ATUIN_OUTPUT__ENABLED=false

    if [[ "${_ATUIN_OFFLINE_SHELL_PID:-}" == "$$" && -d "$ATUIN_DATA_DIR" ]]; then
        return 0
    fi
    local helper="$XDG_CONFIG_HOME/biowulf/atuin-offline.py"
    local archive="${ATUIN_OFFLINE_ARCHIVE_DIR:-${DATA:-/data/$USER}/.local/share/atuin-offline}"
    local runtime
    runtime=$(command python3 "$helper" prepare --archive "$archive" --atuin "${commands[atuin]}") || {
        print -u2 -- 'Atuin offline setup failed; using shell history for this session.'
        return 1
    }
    export ATUIN_DATA_DIR="$runtime"
    export ATUIN_DB_PATH="$runtime/history.db"
    export ATUIN_RECORD_STORE_PATH="$runtime/records.db"
    export ATUIN_KEY_PATH="$runtime/key"
    export ATUIN_LOGS__DIR="$runtime/logs"
    export ATUIN_OFFLINE_ARCHIVE_DIR="$archive"
    typeset -g _ATUIN_OFFLINE_SHELL_PID=$$

    _atuin_offline_save() {
        command python3 "$XDG_CONFIG_HOME/biowulf/atuin-offline.py" checkpoint \
            --archive "$ATUIN_OFFLINE_ARCHIVE_DIR" --runtime "$ATUIN_DATA_DIR"
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook -d zshexit _atuin_offline_save
    add-zsh-hook zshexit _atuin_offline_save
    nohup python3 "$helper" watch --archive "$archive" --runtime "$runtime" \
        --parent $$ --interval 30 </dev/null >>"$runtime/backup.log" 2>&1 &!
}

_biowulf_atuin_offline_setup || return 1
unfunction _biowulf_atuin_offline_setup
