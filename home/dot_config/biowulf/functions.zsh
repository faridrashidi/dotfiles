function jobstat() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: jobstat {failed|left|maxmem|pending|done} <jobid>"
        echo "  Wraps dashboard_cli for Slurm jobs."
        return 0
    fi

    if ! command -v dashboard_cli &>/dev/null; then
        echo "Error: dashboard_cli not found."
        return 1
    fi

    local jobid="$2" output
    case "$1" in
        failed|left|maxmem|done)
            if [[ ! "$jobid" =~ '^[0-9]+(_[0-9]*)?$' ]]; then
                echo "Error: A numeric job ID, array ID, or subjob ID is required." >&2
                return 1
            fi
            # A bare ID keeps the existing whole-array behavior.
            [[ "$jobid" == *_* ]] || jobid+="_"
            ;;
    esac

    local fields="jobid,state,jobname,elapsed_time,timelimit,cpu_max,cpus,mem_max,mem"
    local pending_fields="jobid,jobname,timelimit,cpus,mem"
    case "$1" in
        pending)
            dashboard_cli jobs --fields "$pending_fields" --pending
            ;;
        failed)
            output=$(dashboard_cli jobs --jobid "$jobid" --fields "$fields" \
                --ended --tab --noheader --order start_time) || return $?
            print -r -- "$output" | awk -F '\t' '$2 == "FAILED" || $2 == "TIMEOUT"'
            ;;
        left|done)
            local -a state_filter=(--running)
            [[ "$1" == done ]] && state_filter=(--state COMPLETED)
            output=$(dashboard_cli jobs --jobid "$jobid" --fields jobid \
                --tab --noheader "${state_filter[@]}") || return $?
            print -r -- "$output" | awk 'NF { count++ } END { print count+0 }'
            ;;
        maxmem)
            output=$(dashboard_cli jobs --jobid "$jobid" --fields "$fields" \
                --order mem_max --desc) || return $?
            print -r -- "$output" | head
            ;;
        *)
            dashboard_cli jobs --fields "$fields" --order start_time --running
            ;;
    esac
}

function jobfail() {
    if [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: jobfail <jobid>"
        echo "  Extracts failure logs for a specific job ID."
        return 1
    fi

    if ! typeset -f jobstat >/dev/null; then
        echo "Error: Function 'jobstat' is missing."
        return 1
    fi

    local output line rest
    output=$(jobstat failed "$1") || return $?
    while IFS=$'\t' read -r line rest; do
        [[ -z "$line" ]] && continue
        local logfile="swarm_${line}.o"
        if [[ -f "$logfile" ]]; then
            head -n2 "$logfile" | tail -n1 | sed 's/(   //g' | sed 's/ )//g'
        else
            echo "Log file $logfile not found."
        fi
    done <<<"$output"
}
