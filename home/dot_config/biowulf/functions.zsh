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

    local fields="jobid,jobname,elapsed_time,timelimit,cpu_max,cpus,mem_max,mem"
    local pending_fields="jobid,jobname,timelimit,cpus,mem"
    case "$1" in
        pending)
            dashboard_cli jobs --fields "$pending_fields" --pending
            ;;
        failed)
            dashboard_cli jobs --joblist "$2_" --fields "$fields" --order start_time | grep 'FAILED\|TIMEOUT'
            ;;
        left)
            echo $(dashboard_cli jobs --joblist "$2_" --fields "$fields" | grep RUNNING | wc -l) - 0 | bc -l
            ;;
        maxmem)
            dashboard_cli jobs --joblist "$2_" --fields "$fields" --order mem_max --desc | head
            ;;
        done)
            echo $(dashboard_cli jobs --joblist "$2_" --fields "$fields" | grep COMPLETED | wc -l) - 0 | bc -l
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

    jobstat failed "$1" | cut -d' ' -f3 |
        while read -r line; do
            local logfile="swarm_${line}.o"
            if [[ -f "$logfile" ]]; then
                head -n2 "$logfile" | tail -n1 | sed 's/(   //g' | sed 's/ )//g'
            else
                echo "Log file $logfile not found."
            fi
        done
}
