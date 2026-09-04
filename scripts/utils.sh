WHITE="\033[37m"
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
UNDERLINE="\033[4m"
RESET="\033[0m"

print_msg() {
    local msg="$1"
    local kind="$2"
    # local now="[$(date '+%H:%M:%S')] "
    local now=""

    case "$kind" in
        default) echo -e "${WHITE}${now}• $msg${RESET}" ;;
        success) echo -e "${GREEN}${now}✔ $msg${RESET}" ;;
        error) echo -e "${RED}${now}✘ $msg${RESET}" ;;
        warning) echo -e "${YELLOW}${now}↺ $msg${RESET}" ;;
        banner)
            local width=80
            local msg_upper=$(echo "$msg" | tr '[:lower:]' '[:upper:]')
            local msg_len=${#msg_upper}
            local pad_total=$((width - 2 - msg_len))
            [[ $pad_total -lt 0 ]] && pad_total=0
            local pad_left=$((pad_total / 2))
            local pad_right=$((pad_total - pad_left))
            local border=$(printf '═%.0s' $(seq 1 $((width - 2))))
            echo -e "${BLUE}╔${border}╗${RESET}"
            printf "${BLUE}║${RESET}%*s${BLUE}%s${RESET}%*s${BLUE}║${RESET}\n" "$pad_left" "" "$msg_upper" "$pad_right" ""
            echo -e "${BLUE}╚${border}╝${RESET}"
            ;;
        *)
            echo "Wrong Choice!"
            exit 1
            ;;
    esac
}

_TABLE_WIDTHS=()

print_table_header() {
    _TABLE_WIDTHS=()
    local labels=()
    for spec in "$@"; do
        labels+=("${spec%%:*}")
        _TABLE_WIDTHS+=("${spec##*:}")
    done
    local n=${#_TABLE_WIDTHS[@]}
    local top="╔" sep="╠" row="║"
    for ((i = 0; i < n; i++)); do
        local pad=$(printf '═%.0s' $(seq 1 $((_TABLE_WIDTHS[i] + 2))))
        top+="$pad"
        sep+="$pad"
        ((i < n - 1)) && top+="╦" || top+="╗"
        ((i < n - 1)) && sep+="╬" || sep+="╣"
        row+=$(printf " %-${_TABLE_WIDTHS[i]}s " "${labels[i]}")
        row+="║"
    done
    echo -e "${BLUE}${top}${RESET}"
    echo -e "${BLUE}${row}${RESET}"
    echo -e "${BLUE}${sep}${RESET}"
}

print_table_row() {
    local vals=("$@") row="║"
    for ((i = 0; i < ${#_TABLE_WIDTHS[@]}; i++)); do
        row+=$(printf " %-${_TABLE_WIDTHS[i]}s " "${vals[i]:-}")
        row+="║"
    done
    echo -e "$row"
}

print_table_footer() {
    local n=${#_TABLE_WIDTHS[@]}
    local bottom="╚"
    for ((i = 0; i < n; i++)); do
        bottom+=$(printf '═%.0s' $(seq 1 $((_TABLE_WIDTHS[i] + 2))))
        ((i < n - 1)) && bottom+="╩" || bottom+="╝"
    done
    echo -e "${BLUE}${bottom}${RESET}"
}

run() {
    local cmd="$1"
    local is_test="${2:-false}"
    local error_len="${3:-10}"

    if [[ "$is_test" == "true" ]]; then
        print_msg "$cmd" "default"
        return
    fi

    local program=${cmd%% *}
    if ! command -v "$program" >/dev/null 2>&1; then
        print_msg "[$program is not available] $cmd" "error"
        return 127
    fi

    local output
    if output=$(sh -c "$cmd" 2>&1); then
        print_msg "$cmd" "success"
    else
        local exit_code=$?
        print_msg "$cmd" "error"
        local -a errors
        IFS=$'\n' read -r -d '' -a errors <<<"$output" || true
        local n=${#errors[@]}
        local start_idx=0
        [[ "$error_len" != "-1" ]] && start_idx=$((n - error_len)) && [[ $start_idx -lt 0 ]] && start_idx=0
        for ((i = start_idx; i < n; i++)); do
            echo "${errors[$i]}"
        done

        local log_file=""
        for ((i = 0; i < n; i++)); do
            if [[ "${errors[$i]}" =~ [Ss]ee.+[Ll]og && "${errors[$i]}" =~ (/[^ ]+\.log) ]]; then
                log_file="${BASH_REMATCH[1]}"
                break
            fi
        done
        if [[ -n "$log_file" && -f "$log_file" ]]; then
            echo "Found log file: $log_file. Printing last $error_len lines:"
            [[ "$error_len" != "-1" ]] && tail -n "$error_len" "$log_file" || cat "$log_file" || true
        fi
        return "$exit_code"
    fi
}
