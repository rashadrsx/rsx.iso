#!/bin/bash
# Sync your live config files (~/.config/..., ~/.zshrc, ...) into the ISO.
# What gets synced is listed in airootfs/root/rsx/dotfiles.list
#
# Usage:
#   ./sync-dotfiles.sh                    sync everything in the manifest
#   ./sync-dotfiles.sh -n                 dry run (show what would change)
#   ./sync-dotfiles.sh -c                 sync, then git commit the result
#   ./sync-dotfiles.sh add <path> [name]  add a live file/folder to the manifest and sync it
#                                         (name defaults to the basename, e.g. ~/.config/btop -> btop)
#   ./sync-dotfiles.sh remove <name>      remove an entry from the manifest and the ISO copy
#   ./sync-dotfiles.sh list               show manifest entries and their status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RSX_DIR="$SCRIPT_DIR/airootfs/root/rsx"
DEST="$RSX_DIR/dotfiles"
MANIFEST="$RSX_DIR/dotfiles.list"

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

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; }

expand() { echo "${1/#\~/$HOME}"; }

# Prints "live<TAB>name" for every manifest entry
entries() {
    grep -vE '^\s*(#|$)' "$MANIFEST" | awk '{print $1 "\t" $2}'
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
        opts+=(--delete)
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
        git add -A "$DEST" "$MANIFEST"
        if git diff --cached --quiet -- "$DEST" "$MANIFEST"; then
            log "no changes to commit"
        else
            git commit -q -m "sync dotfiles" -- "$DEST" "$MANIFEST"
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

command -v rsync >/dev/null || { err "rsync is required (pacman -S rsync)"; exit 1; }
[ -f "$MANIFEST" ] || { err "manifest not found: $MANIFEST"; exit 1; }

case "${1:-}" in
    add)        shift; cmd_add "$@" ;;
    remove|rm)  shift; cmd_remove "$@" ;;
    list|ls)    cmd_list ;;
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
