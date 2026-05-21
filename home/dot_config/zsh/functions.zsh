function imgopt() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: imgopt"
        echo "  Optimizes images in current directory."
        echo "  Requirements: parallel, sips (macOS), exiftool, clop"
        return 0
    fi

    local req_tools=("parallel" "sips" "exiftool" "clop")
    for tool in "${req_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "Error: '$tool' is not installed."
            return 1
        fi
    done

    local target_dir="${PWD##*/}"
    mkdir -p "$target_dir" &&
        find . -type f -not -path "./$target_dir/*" -not -name '.DS_Store' \
            -exec sh -c 'cp -p "{}" "./'"$target_dir"'/$(echo "{}" | sed "s|^\./||" | tr "/" "_")"' \; &&
        find "$target_dir" -maxdepth 1 -type f -iname "*.heic" |
        parallel --line-buffer '
        if ! (
            sips -s format jpeg -s formatOptions 100 {} --out {.}.jpg >/dev/null 2>&1 && \
            exiftool -tagsfromfile {} {.}.jpg -all:all -overwrite_original >/dev/null 2>&1 && \
            touch -r {} {.}.jpg >/dev/null 2>&1 && \
            rm {} >/dev/null 2>&1
        ); then
            echo "{} ✘"
        fi' &&
        clop optimise "$target_dir"
}

function ytdl() {
    if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: ytdl <media_type> [options] <url>"
        echo "Media types: 'a' (audio), 'v' (video)"
        echo "Options: -s (subtitles), -e (embed thumbnail)"
        echo "Examples:"
        echo "  ytdl a https://youtube.com/watch?v=xyz"
        echo "  ytdl v -s -e https://youtube.com/watch?v=xyz"
        return 1
    fi

    if ! command -v yt-dlp &>/dev/null; then
        echo "Error: yt-dlp is not installed."
        return 1
    fi
    if ! command -v ffmpeg &>/dev/null; then
        echo "Error: ffmpeg is not installed."
        return 1
    fi

    local media_type="$1"
    shift
    local url=""
    local special_options=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s)
                special_options+=("--write-subs" "--write-auto-subs")
                shift
                ;;
            -e)
                special_options+=("--embed-thumbnail")
                if [[ "$media_type" == "a" ]]; then
                    special_options+=("--postprocessor-args" "-vf crop=ih:ih:(iw-ow)/2:(ih-oh)/2")
                fi
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'"
                return 1
                ;;
            *)
                url="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$url" ]]; then
        echo "Error: No URL provided."
        return 1
    fi

    local common_options=(
        --output "%(upload_date)s - %(title)s.%(ext)s"
        --concurrent-fragments 8
        --no-warnings
    )

    case "$media_type" in
        a)
            local tmp_file
            tmp_file=$(mktemp)
            if yt-dlp "${common_options[@]}" "${special_options[@]}" \
                --extract-audio --audio-format mp3 \
                --print-to-file after_move:filepath "$tmp_file" \
                "$url"; then
                echo "Audio downloaded: $(cat "$tmp_file")"
            else
                echo "Error: Audio download failed."
                rm -f "$tmp_file"
                return 1
            fi
            rm -f "$tmp_file"
            ;;
        v)
            local output_file
            local format="bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]"
            local extra_args=("--format-sort" "vcodec:h264,res,acodec:m4a")
            if [[ "$url" =~ "instagram.com" ]]; then
                format="bestvideo[vcodec~='^h264$'][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]"
                extra_args=("--postprocessor-args" "-c:v libx264 -pix_fmt yuv420p")
            fi
            local tmp_file
            tmp_file=$(mktemp)
            if yt-dlp "${common_options[@]}" "${special_options[@]}" \
                --format "$format" \
                --merge-output-format mp4 \
                "${extra_args[@]}" \
                --print-to-file after_move:filepath "$tmp_file" \
                "$url"; then
                echo "Video downloaded: $(cat "$tmp_file")"
            else
                echo "Error: Video download failed."
                rm -f "$tmp_file"
                return 1
            fi
            rm -f "$tmp_file"
            ;;
        *)
            echo "Error: Invalid media type. Use 'a' for audio or 'v' for video."
            return 1
            ;;
    esac
}
alias ytdl="noglob ytdl"

function adown() {
    if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: adown <url>"
        echo "  Downloads file using aria2c with optimized settings."
        return 1
    fi

    if ! command -v aria2c &>/dev/null; then
        echo "Error: aria2c is not installed."
        return 1
    fi

    local url="$1"
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo "Error: Invalid URL scheme. Must be http or https."
        return 1
    fi

    aria2c --max-connection-per-server=16 \
        --split=16 \
        --console-log-level=error \
        --continue=true \
        --summary-interval=0 \
        "$url" || {
        echo "Error: Download failed for $url"
        return 1
    }

    echo "Download completed: $url"
}

function archive() {
    if [[ $# -lt 2 || "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: archive <format> <folder>"
        echo "Formats: zip, tar, targz, tarbz2"
        return 1
    fi

    local format="$1"
    local folder="$2"

    if [[ ! -d "$folder" ]]; then
        echo "Error: Directory '$folder' does not exist."
        return 1
    fi

    local name="${folder:t:r}"
    case "$format" in
        zip)
            if ! command -v zip &>/dev/null; then
                echo "Error: zip not found."
                return 1
            fi
            zip -r "$name" "$folder"
            ;;
        tar)
            if ! command -v tar &>/dev/null; then
                echo "Error: tar not found."
                return 1
            fi
            tar -cvf "$name" "$folder"
            ;;
        targz)
            if ! command -v tar &>/dev/null; then
                echo "Error: tar not found."
                return 1
            fi
            tar -czvf "$name.tar.gz" "$folder"
            ;;
        tarbz2)
            if ! command -v tar &>/dev/null; then
                echo "Error: tar not found."
                return 1
            fi
            tar -cjvf "$name.tar.bz2" "$folder"
            ;;
        *)
            echo "Error: Unsupported format '$format'."
            return 1
            ;;
    esac
}

function convert() {
    if [[ $# -ne 2 || "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: convert <output_format> <input_file>"
        echo "Supported formats: mp3, mp4"
        return 1
    fi

    if ! command -v ffmpeg &>/dev/null; then
        echo "Error: ffmpeg is not installed."
        return 1
    fi

    local output_format="$1"
    local input_file="$2"

    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file '$input_file' does not exist."
        return 1
    fi

    local base_name="${input_file:r}"
    local output_file="${base_name}.${output_format}"

    if [[ -f "$output_file" ]]; then
        echo "Error: Output file '$output_file' already exists."
        return 1
    fi

    case "$output_format" in
        mp3)
            ffmpeg -i "$input_file" -codec:a libmp3lame -b:a 320k -loglevel error "$output_file"
            ;;
        mp4)
            ffmpeg -i "$input_file" -c:v libx264 -crf 23 -c:a aac -loglevel error "$output_file"
            ;;
        *)
            echo "Error: Format '$output_format' not supported."
            return 1
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        echo "Converted to: $output_file"
    else
        echo "Error: Conversion failed."
        return 1
    fi
}

function backup() {
    local DROPBOX_DIR="${HOME}/Dropbox"
    local DOT_BACKUP_TARGET_DIR="/Volumes/Data/iMac/backup"
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: backup"
        echo "  Zips \$DROPBOX_DIR and rsyncs to \$DOT_BACKUP_TARGET_DIR"
        return 0
    fi

    if ! command -v rsync &>/dev/null || ! command -v zip &>/dev/null; then
        echo "Error: rsync and zip are required."
        return 1
    fi

    local source="${DROPBOX_DIR:-}"
    local target="${DOT_BACKUP_TARGET_DIR:-}"

    if [[ -z "$source" || -z "$target" ]]; then
        echo "Error: DROPBOX_DIR and DOT_BACKUP_TARGET_DIR must be configured."
        return 1
    fi

    if [[ ! -d "$source" ]]; then
        echo "Error: Source '$source' not found."
        return 1
    fi
    if [[ ! -d "$target" ]]; then
        echo "Error: Target '$target' not found (drive not mounted?)."
        return 1
    fi
    if [[ ! -w "$target" ]]; then
        echo "Error: Target '$target' is not writable."
        return 1
    fi

    if ! cd "$HOME"; then
        echo "Error: Cannot access home dir."
        return 1
    fi

    local name="$(date +%y-%m-%d-%H-%M)"
    local zipfile="${name}.zip"

    zip -r "$zipfile" "$(basename "$source")" || {
        echo "Error: ZIP creation failed."
        return 1
    }

    rsync -ahrX --no-compress --info=progress2 --remove-source-files "$zipfile" "$target" || {
        echo "Error: rsync failed."
        return 1
    }

    cd - >/dev/null
    echo "Backup completed: $zipfile -> $target"
}

function dsize() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: dsize [directory]"
        echo "  Shows disk usage of immediate children, sorted by size."
        return 0
    fi

    local target="${1:-.}"
    if [[ ! -d "$target" ]]; then
        echo "Error: Directory '$target' not found."
        return 1
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        du -ah -d 1 "$target" | sort -hr
    else
        du -ah --max-depth=1 "$target" | sort -hr
    fi
}
