#!/bin/bash
# Sync your live config files (~/.config/..., ~/.zshrc, ...) into the ISO.
# What gets synced is listed in airootfs/root/rsx/dotfiles.list
# Paths to skip (caches, databases, logs) go in airootfs/root/rsx/dotfiles.ignore
#
# Usage:
#   ./sync-dotfiles.sh                    sync everything in the manifest
#   ./sync-dotfiles.sh -n                 dry run (show what would change)
#   ./sync-dotfiles.sh -c                 sync, then git commit the result
#   ./sync-dotfiles.sh add <path> [name]  add a live file/folder to the manifest and sync it
#                                         (name defaults to the basename, e.g. ~/.config/btop -> btop)
#   ./sync-dotfiles.sh remove <name>      remove an entry from the manifest and the ISO copy
#   ./sync-dotfiles.sh list               show manifest entries and their status
#   ./sync-dotfiles.sh ignore [path]      stop syncing a file/folder (e.g. ~/Projects/docker/jellyfin/cache
#                                         or docker/jellyfin/cache); no path = show the ignore list
#   ./sync-dotfiles.sh unignore <path>    sync it again
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RSX_DIR="$SCRIPT_DIR/airootfs/root/rsx"
DEST="$RSX_DIR/dotfiles"
MANIFEST="$RSX_DIR/dotfiles.list"
IGNORE="$RSX_DIR/dotfiles.ignore"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1" >&2; }

# Junk that should never end up in the ISO
EXCLUDES=(
    --exclude='.git/'
    --exclude='.idea/'
    --exclude='*.bak'
    --exclude='*.bak-*'
    --exclude='*.log'
    --exclude='watch_later/'
    --exclude='keymap.toml-*'
    --exclude='__pycache__/'
)

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

expand() { echo "${1/#\~/$HOME}"; }

# Prints "live<TAB>name" for every manifest entry
entries() {
    grep -vE '^\s*(#|$)' "$MANIFEST" | awk '{print $1 "\t" $2}'
}

# Prints rsync --exclude options for one entry, from dotfiles.ignore
# ("docker/jellyfin/cache/" -> "--exclude=/jellyfin/cache/" for entry "docker")
ignores_for() {
    local name="$1" line
    [ -f "$IGNORE" ] || return 0
    while read -r line _; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == "$name/"* ]] && echo "--exclude=/${line#"$name/"}"
    done < "$IGNORE"
    return 0
}

sync_entry() {
    local live="$1" name="$2" dry="$3"
    local src target
    src="$(expand "$live")"
    target="$DEST/$name"

    if [ ! -e "$src" ]; then
        warn "skip  $live (not found on this machine, keeping ISO copy)"
        return
    fi

    local opts=(-a --itemize-changes "${EXCLUDES[@]}")
    [ "$dry" -eq 1 ] && opts+=(--dry-run)

    if [ -d "$src" ]; then
        [ "$dry" -eq 0 ] && mkdir -p "$target"
        # --delete-excluded also cleans ignored stuff out of the ISO copy
        opts+=(--delete --delete-excluded)
        mapfile -t -O "${#opts[@]}" opts < <(ignores_for "$name")
        rsync "${opts[@]}" "$src/" "$target/" | sed "s|^|    $name: |"
    else
        [ "$dry" -eq 0 ] && mkdir -p "$(dirname "$target")"
        rsync "${opts[@]}" "$src" "$target" | sed "s|^|    $name: |"
    fi
    log "sync  $live -> dotfiles/$name"
}

cmd_sync() {
    local dry="$1" commit="$2"
    [ "$dry" -eq 1 ] && warn "dry run, nothing will be changed"
    mkdir -p "$DEST"

    while IFS=$'\t' read -r live name; do
        sync_entry "$live" "$name" "$dry"
    done < <(entries)

    # Warn about stuff in the ISO that isn't in the manifest anymore
    local listed top
    listed="$(entries | cut -f2 | cut -d/ -f1 | sort -u)"
    for top in "$DEST"/* "$DEST"/.[!.]*; do
        [ -e "$top" ] || continue
        top="$(basename "$top")"
        grep -qxF "$top" <<<"$listed" || warn "dotfiles/$top is not in the manifest (remove it or add an entry)"
    done

    if [ "$commit" -eq 1 ] && [ "$dry" -eq 0 ]; then
        cd "$SCRIPT_DIR"
        git add -A "$DEST" "$MANIFEST" "$IGNORE"
        if git diff --cached --quiet -- "$DEST" "$MANIFEST" "$IGNORE"; then
            log "no changes to commit"
        else
            git commit -q -m "sync dotfiles" -- "$DEST" "$MANIFEST" "$IGNORE"
            log "committed"
        fi
    fi
}

cmd_add() {
    local path="${1:-}" name="${2:-}"
    [ -n "$path" ] || { err "usage: $0 add <path> [name]"; exit 1; }

    local abs live
    abs="$(realpath -s "$(expand "$path")")"
    [ -e "$abs" ] || { err "$abs does not exist"; exit 1; }
    [[ "$abs" == "$HOME"/* ]] || { err "only paths inside \$HOME are supported"; exit 1; }
    [[ "$abs" != *" "* ]] || { err "paths with spaces are not supported"; exit 1; }

    live="~${abs#"$HOME"}"
    name="${name:-$(basename "$abs")}"

    if entries | cut -f1 | grep -qxF "$live"; then
        err "$live is already in the manifest"; exit 1
    fi
    if entries | cut -f2 | grep -qxF "$name"; then
        err "name '$name' is already used, pick another: $0 add $path <name>"; exit 1
    fi

    printf '%-27s %s\n' "$live" "$name" >> "$MANIFEST"
    log "added $live -> dotfiles/$name"
    sync_entry "$live" "$name" 0
}

cmd_remove() {
    local name="${1:-}"
    [ -n "$name" ] || { err "usage: $0 remove <name>"; exit 1; }
    entries | cut -f2 | grep -qxF "$name" || { err "'$name' is not in the manifest"; exit 1; }

    local tmp
    tmp="$(mktemp)"
    awk -v n="$name" '/^[[:space:]]*(#|$)/ || $2 != n' "$MANIFEST" > "$tmp"
    cat "$tmp" > "$MANIFEST" && rm -f "$tmp"
    rm -rf "${DEST:?}/$name"
    log "removed $name (manifest + ISO copy)"
}

cmd_list() {
    local live name
    while IFS=$'\t' read -r live name; do
        if [ -e "$(expand "$live")" ]; then
            printf "${GREEN}%-8s${NC} %-28s -> %s\n" "live" "$live" "$name"
        else
            printf "${YELLOW}%-8s${NC} %-28s -> %s\n" "missing" "$live" "$name"
        fi
    done < <(entries)
}

# Turns a live path (~/Projects/docker/jellyfin/cache) or an ISO path
# (docker/jellyfin/cache) into a dotfiles.ignore line: docker/jellyfin/cache/
# Folders get a trailing / so rsx-setup recreates them empty on deploy.
to_ignore_line() {
    local arg="$1" live name live_abs rel="" match="" is_dir=0
    [[ "$arg" == */ ]] && is_dir=1
    arg="${arg%/}"

    if [[ "$arg" == "~"* || "$arg" == /* || -e "$arg" ]]; then
        # Live path: find the manifest folder entry it lives in
        local abs
        abs="$(realpath -sm "$(expand "$arg")")"
        while IFS=$'\t' read -r live name; do
            live_abs="$(realpath -sm "$(expand "$live")")"
            if [[ "$abs" == "$live_abs" ]]; then
                err "can't ignore a whole entry, use: $0 remove $name"; return 1
            fi
            if [[ "$abs" == "$live_abs/"* ]]; then
                match="$name"; rel="${abs#"$live_abs/"}"; break
            fi
        done < <(entries)
        [ -n "$match" ] || { err "$arg is not inside any folder in the manifest"; return 1; }
        [ -d "$abs" ] && is_dir=1
    else
        if entries | cut -f2 | grep -qxF "$arg"; then
            err "can't ignore a whole entry, use: $0 remove $arg"; return 1
        fi
        # ISO path: <name>/<rest>, pick the longest matching manifest name
        while IFS=$'\t' read -r live name; do
            if [[ "$arg" == "$name/"* && ${#name} -gt ${#match} ]]; then
                match="$name"; rel="${arg#"$name/"}"
            fi
        done < <(entries)
        [ -n "$match" ] || { err "'$arg' does not start with a manifest name (see: $0 list)"; return 1; }
        live="$(entries | awk -F'\t' -v n="$match" '$2 == n {print $1}')"
        [[ -d "$(expand "$live")/$rel" || -d "$DEST/$match/$rel" ]] && is_dir=1
    fi

    [ -n "$rel" ] || { err "can't ignore a whole entry, use: $0 remove $match"; return 1; }
    [ "$is_dir" -eq 1 ] && rel="$rel/"
    echo "$match/$rel"
}

ignored() { [ -f "$IGNORE" ] && grep -vE '^\s*(#|$)' "$IGNORE" | awk '{print $1}' || true; }

cmd_ignore() {
    if [ -z "${1:-}" ]; then
        local line
        while read -r line; do
            if [ -e "$DEST/${line%/}" ]; then
                printf "${YELLOW}%-10s${NC} %s\n" "in ISO" "$line"
            else
                printf "${GREEN}%-10s${NC} %s\n" "ignored" "$line"
            fi
        done < <(ignored)
        return
    fi

    local line
    line="$(to_ignore_line "$1")" || exit 1
    if ignored | sed 's|/$||' | grep -qxF "${line%/}"; then
        warn "$line is already ignored"; return
    fi

    [ -f "$IGNORE" ] || echo "# RSX dotfiles ignore list (see sync-dotfiles.sh)" > "$IGNORE"
    echo "$line" >> "$IGNORE"
    log "ignored $line"

    if [ -e "$DEST/${line%/}" ]; then
        rm -rf "${DEST:?}/${line%/}"
        log "removed dotfiles/${line%/} from the ISO copy"
    fi
}

cmd_unignore() {
    [ -n "${1:-}" ] || { err "usage: $0 unignore <path>"; exit 1; }
    local line
    line="$(to_ignore_line "$1")" || exit 1
    ignored | sed 's|/$||' | grep -qxF "${line%/}" || { err "$line is not in the ignore list"; exit 1; }

    local tmp
    tmp="$(mktemp)"
    awk -v p="${line%/}" '{ l = $1; sub(/\/$/, "", l) } /^[[:space:]]*(#|$)/ || l != p' "$IGNORE" > "$tmp"
    cat "$tmp" > "$IGNORE" && rm -f "$tmp"
    log "unignored $line (run $0 to sync it again)"
}

command -v rsync >/dev/null || { err "rsync is required (pacman -S rsync)"; exit 1; }
[ -f "$MANIFEST" ] || { err "manifest not found: $MANIFEST"; exit 1; }

case "${1:-}" in
    add)        shift; cmd_add "$@" ;;
    remove|rm)  shift; cmd_remove "$@" ;;
    list|ls)    cmd_list ;;
    ignore)     shift; cmd_ignore "$@" ;;
    unignore)   shift; cmd_unignore "$@" ;;
    -h|--help|help) usage ;;
    *)
        DRY=0; COMMIT=0
        while getopts "nch" opt; do
            case "$opt" in
                n) DRY=1 ;;
                c) COMMIT=1 ;;
                h) usage; exit 0 ;;
                *) usage; exit 1 ;;
            esac
        done
        cmd_sync "$DRY" "$COMMIT"
        ;;
esac
