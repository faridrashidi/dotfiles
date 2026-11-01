# Atuin must not open SQLite files on NFS or GPFS. Shells on a node share a
# local runtime, and atuin-offline.py moves history between nodes via /data.
_biowulf_atuin_offline() {
    [[ -o interactive ]] && (($+commands[python3])) || return 1
    local exports
    exports=$(command python3 "$XDG_CONFIG_HOME/biowulf/atuin-offline.py" prepare) || {
        print -u2 -- 'Atuin offline setup failed; using plain shell history.'
        return 1
    }
    eval "$exports"
    zmodload zsh/datetime
    zmodload -F zsh/stat b:zstat
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _atuin_offline_sync
    add-zsh-hook zshexit _atuin_offline_save
    if [[ -n "$SLURM_JOB_ID" ]]; then
        # Walltime and scancel send SIGTERM, then SIGKILL; zshexit never runs.
        TRAPTERM() {
            _atuin_offline_save
            return $((128 + $1))
        }
    fi
}

# Save and import in the background, at most every 30 seconds per node.
_atuin_offline_sync() {
    local -a synced
    zstat -A synced +mtime -- "$ATUIN_HOME/synced" 2>/dev/null
    ((EPOCHSECONDS - ${synced[1]:-0} >= 30)) || return 0
    command python3 "$XDG_CONFIG_HOME/biowulf/atuin-offline.py" sync \
        </dev/null >>"$ATUIN_HOME/sync.log" 2>&1 &!
}

# A Slurm job ends as soon as its shell exits, so save in the foreground there.
_atuin_offline_save() {
    local helper="$XDG_CONFIG_HOME/biowulf/atuin-offline.py"
    if [[ -n "$SLURM_JOB_ID" ]]; then
        command python3 "$helper" checkpoint
    else
        command python3 "$helper" checkpoint </dev/null >>"$ATUIN_HOME/sync.log" 2>&1 &!
    fi
}

_biowulf_atuin_offline || return 1
unfunction _biowulf_atuin_offline
