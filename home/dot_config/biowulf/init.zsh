_biowulf_atuin_setup() {
    [[ -o interactive ]] || return 0
    (($+commands[atuin])) || return 0

    export ATUIN_LOCAL_TIMEOUT="${ATUIN_LOCAL_TIMEOUT:-15}"
    export ATUIN_DAEMON__ENABLED="${ATUIN_DAEMON__ENABLED:-true}"

    local socket_dir="${TMPDIR:-/tmp}/atuin-$USER"
    export ATUIN_DAEMON__SOCKET_PATH="${ATUIN_DAEMON__SOCKET_PATH:-$socket_dir/atuin.sock}"
    mkdir -p "${ATUIN_DAEMON__SOCKET_PATH:h}"

    # Avoid opening Atuin's SQLite store on every keystroke over Biowulf's shared storage.
    ZSH_AUTOSUGGEST_STRATEGY=(history)

    [[ "$ATUIN_DAEMON__ENABLED" == "true" ]] || return 0
    atuin daemon --help >/dev/null 2>&1 || return 0

    if command -v pgrep >/dev/null 2>&1; then
        pgrep -u "$USER" -f "atuin daemon" >/dev/null 2>&1 && return 0
    elif [[ -S "$ATUIN_DAEMON__SOCKET_PATH" ]]; then
        return 0
    fi

    [[ -S "$ATUIN_DAEMON__SOCKET_PATH" ]] && rm -f "$ATUIN_DAEMON__SOCKET_PATH"
    atuin daemon >/dev/null 2>&1 &|
}

_biowulf_atuin_setup
unfunction _biowulf_atuin_setup

[[ -d "$DATA" ]] && cd "$DATA"
