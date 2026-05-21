function git_deleted_media() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: git_deleted_media [-d]"
        echo "  Lists deleted media files (pdf, sketch, png, etc) in git history."
        echo "  -d: Permanently remove them from history (WARNING: Rewrites history)."
        return 0
    fi

    local dry_run=true
    if [[ "$1" == "-d" ]]; then
        dry_run=false
        shift
    fi

    local files
    files=$(git log --all --diff-filter=D --summary |
        grep -iE 'delete mode .*(\.pdf|\.sketch|\.png|\.webp|\.jpe?g)$' |
        awk '{print $4}' |
        sort -u)

    if [[ -z "$files" ]]; then
        echo "No deleted media files found in history."
        return 0
    fi

    echo "$files"
    echo ""

    if $dry_run; then
        echo "Run with -d to permanently remove ONLY these files from history."
        return 0
    fi

    if ! command -v git-filter-repo >/dev/null; then
        echo "Error: git-filter-repo not found. Install via: pip install --user git-filter-repo"
        return 1
    fi

    local temp_file
    temp_file=$(mktemp)
    printf '%s\n' "$files" >"$temp_file"

    echo "Removing files from history..."
    git filter-repo --paths-from-file "$temp_file" --invert-paths --force
    rm -f "$temp_file"

    local repo_name=$(basename "$PWD")
    local github_user=$(git config --get user.name | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "History rewritten. If shared, run:"
    echo "  git remote add origin git@github.com:${github_user}/${repo_name}.git"
    echo "  git push --force --all && git push --force --tags"
}
