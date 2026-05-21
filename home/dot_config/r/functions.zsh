function cran() {
    if [[ $# -ne 3 || "$1" != "install" ]]; then
        echo "Usage: cran install <source> <package>"
        echo "Sources: cran, github, bitbucket, bioconductor"
        return 1
    fi

    if ! command -v Rscript &>/dev/null; then
        echo "Error: Rscript is not installed."
        return 1
    fi

    local source="$2"
    local package="$3"
    local cmd=""

    case "$source" in
        cran)
            cmd="install.packages(\"$package\", repos=\"https://cloud.r-project.org\")"
            ;;
        github)
            cmd="devtools::install_github(\"$package\")"
            ;;
        bitbucket)
            cmd="devtools::install_bitbucket(\"$package\")"
            ;;
        bioconductor)
            cmd="BiocManager::install(\"$package\")"
            ;;
        *)
            echo "Error: Invalid source '$source'."
            return 1
            ;;
    esac

    if [[ -n "$cmd" ]]; then
        if Rscript -e "$cmd"; then
            echo "Successfully installed '$package' from $source."
        else
            echo "Error: Failed to install '$package' from $source."
            return 1
        fi
    fi
}

function init_renv() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: init_renv"
        echo "  Initializes R renv with a hidden .renv directory via direnv."
        return 0
    fi

    if ! command -v Rscript &>/dev/null; then
        echo "Error: Rscript not found."
        return 1
    fi
    if ! command -v direnv &>/dev/null; then
        echo "Error: direnv not found."
        return 1
    fi

    local envrc=".envrc"

    function _append_envrc_export() {
        local pattern="$1"
        local line="$2"

        if grep -qF "$pattern" "$envrc" 2>/dev/null; then
            return 0
        fi

        if [[ -f "$envrc" ]] && [[ -n "$(tail -c 1 "$envrc" 2>/dev/null)" ]]; then
            printf '\n' >>"$envrc"
        fi

        printf '%s\n' "$line" >>"$envrc"
    }

    _append_envrc_export 'RENV_PATHS_RENV' 'export RENV_PATHS_RENV="$PWD/.renv"'
    _append_envrc_export 'RENV_DOWNLOAD_METHOD' 'export RENV_DOWNLOAD_METHOD="libcurl"'
    unset -f _append_envrc_export

    if ! direnv allow; then
        echo "Error: direnv allow failed."
        return 1
    fi

    if ! direnv exec . Rscript -e 'options(renv.consent = TRUE); renv::init(restart = FALSE); renv::settings$use.cache(FALSE)'; then
        echo "Error: renv initialization failed via direnv exec."
        return 1
    fi

    echo "renv initialized successfully."
}
