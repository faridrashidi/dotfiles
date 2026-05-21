function parrun() {
    if [[ $# -ne 3 || "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: parrun <jobs> <command> <input_file>"
        echo "  <jobs>: Number of parallel jobs (0 for all cores)"
        echo "  <command>: Command or zsh function to execute"
        echo "  <input_file>: File containing list of arguments"
        return 1
    fi

    if ! command -v parallel &>/dev/null; then
        echo "Error: GNU parallel is not installed."
        return 1
    fi

    local jobs="$1"
    local command="$2"
    local input_file="$3"

    if ! [[ "$jobs" =~ ^[0-9]+$ ]]; then
        echo "Error: Jobs must be a non-negative integer."
        return 1
    fi

    if [[ "$jobs" -eq 0 ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            jobs=$(sysctl -n hw.physicalcpu)
        else
            jobs=$(nproc)
        fi
    fi

    if [[ ! -f "$input_file" || ! -r "$input_file" ]]; then
        echo "Error: Input file '$input_file' not found or not readable."
        return 1
    fi

    local cmd_name="${command%% *}"
    if ! typeset -f "$cmd_name" &>/dev/null && ! command -v "$cmd_name" &>/dev/null; then
        echo "Error: Command '$cmd_name' not found."
        return 1
    fi

    if typeset -f "$cmd_name" &>/dev/null; then
        if ! command -v env_parallel &>/dev/null; then
            echo "Error: env_parallel is not installed."
            return 1
        fi
        source $(which env_parallel.zsh)
        env_parallel --env "$cmd_name" -j "$jobs" --bar "$command >/dev/null" "{}" <"$input_file"
    else
        parallel -j "$jobs" --bar "$command >/dev/null" "{}" <"$input_file"
    fi
}
