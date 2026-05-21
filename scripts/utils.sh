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
        return
    fi

    local output
    if output=$(sh -c "$cmd" 2>&1); then
        print_msg "$cmd" "success"
    else
        print_msg "$cmd" "error"
        local -a errors
        IFS=$'\n' read -r -d '' -a errors <<<"$output"
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
            [[ "$error_len" != "-1" ]] && tail -n "$error_len" "$log_file" || cat "$log_file"
        fi
    fi
}

ask() {
    local var=$1
    local default=$2
    if [[ ! -t 0 ]]; then
        read var
    else
        read -ep "$1=[$default] >>> " var
    fi
    echo "${var:-$default}"
}

# Simple global variables for progress bar state (Bash 3.x compatible)
_progress_index=0
_progress_start=0

progress_bar() {
    local array_ref="$1"
    local arr=("${!array_ref}")
    local total=${#arr[@]}

    # Initialize or increment state
    if [[ "$_progress_start" -eq 0 ]]; then
        _progress_start=$(date +%s)
        _progress_index=0
    fi
    _progress_index=$((_progress_index + 1))

    local current_index=$_progress_index
    local start=$_progress_start
    local now=$(date +%s)
    local elapsed=$((now - start))
    local percent=$((100 * current_index / total))
    local eta=0
    [[ "$current_index" -gt 0 ]] && eta=$(((elapsed * total / current_index) - elapsed))

    # Colors
    local CYAN="\033[36m" GREEN="\033[32m" YELLOW="\033[33m" WHITE="\033[37m"
    local BOLD="\033[1m" DIM="\033[2m" RESET="\033[0m"

    # Progress bar characters
    local bar_width=45
    local filled=$((percent * bar_width / 100))
    local empty=$((bar_width - filled))
    local bar="" spaces=""
    [[ $filled -gt 0 ]] && bar=$(printf '%0.s█' $(seq 1 $filled))
    [[ $empty -gt 0 ]] && spaces=$(printf '%0.s░' $(seq 1 $empty))

    # Spinner animation
    local spinners=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spinner="${spinners[$((current_index % ${#spinners[@]}))]}"

    # Format time as MM:SS
    local elapsed_fmt=$(printf "%02d:%02d" $((elapsed / 60)) $((elapsed % 60)))
    local eta_fmt=$(printf "%02d:%02d" $((eta / 60)) $((eta % 60)))

    # Pad current_index to match total's digit count
    local total_digits=${#total}
    local current_padded=$(printf "%${total_digits}d" $current_index)

    # Build progress line
    local progress_line="${CYAN}${spinner}${RESET} ${WHITE}${bar}${DIM}${spaces}${RESET} "
    progress_line+="${BOLD}$(printf '%3d' $percent)%${RESET} "
    progress_line+="${DIM}│${RESET} ${GREEN}${current_padded}${DIM}/${RESET}${total} "
    progress_line+="${DIM}│${RESET} ${YELLOW}🕒 ${elapsed_fmt}${RESET} "
    progress_line+="${DIM}│${RESET} ${CYAN}⏳ ${eta_fmt}${RESET}"

    # Save cursor, go to bottom of screen, clear line above and progress line, print, restore cursor
    if [[ -n "$TERM" && "$TERM" != "dumb" && -t 1 ]]; then
        local term_lines=$(tput lines)
        tput sc
        # Clear the line above the progress bar (ensures empty line between content and progress)
        tput cup $((term_lines - 2)) 0
        tput el
        # Draw the progress bar at the bottom
        tput cup $((term_lines - 1)) 0
        tput el
        printf "%b" "$progress_line"
        tput rc
    else
        # Fallback for non-interactive terminals (e.g., GitHub CLI)
        printf "%b " "$progress_line"
    fi

    # Reset state when complete
    if [[ "$current_index" -ge "$total" ]]; then
        _progress_index=0
        _progress_start=0
        # Clear the progress bar line and the empty line above it
        if [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
            local term_lines=$(tput lines)
            tput sc
            tput cup $((term_lines - 2)) 0
            tput el
            tput cup $((term_lines - 1)) 0
            tput el
            tput rc
        fi
    fi
}
