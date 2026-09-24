#!/usr/bin/env bash
# Bootstrap: symlink each tool config directory into ~/.config.
# Idempotent: correct existing links are kept; anything else at the
# destination is backed up with a timestamp suffix before linking.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"
KEEP_BACKUPS=3

TOOLS=(fastfetch helix nushell nvim tmux)

mkdir -p "$CONFIG_HOME"

for tool in "${TOOLS[@]}"; do
    src="$REPO_DIR/$tool"
    dest="$CONFIG_HOME/$tool"

    if [[ ! -d "$src" ]]; then
        echo "skip  $tool (missing in repo)"
        continue
    fi

    if [[ -L "$dest" ]]; then
        if [[ "$(readlink "$dest")" == "$src" ]]; then
            echo "ok    $tool (already linked)"
            continue
        fi
        mv "$dest" "${dest}${BACKUP_SUFFIX}"
        echo "back  $dest -> ${dest}${BACKUP_SUFFIX} (was a symlink)"
    elif [[ -e "$dest" ]]; then
        mv "$dest" "${dest}${BACKUP_SUFFIX}"
        echo "back  $dest -> ${dest}${BACKUP_SUFFIX}"
    fi

    ln -s "$src" "$dest"
    echo "link  $dest -> $src"
done

# Prune old backups, keeping the most recent ones per tool.
# Timestamp suffixes are zero-padded, so name sort matches age.
shopt -s nullglob
for tool in "${TOOLS[@]}"; do
    backups=("$CONFIG_HOME/$tool".bak.*)
    if (( ${#backups[@]} > KEEP_BACKUPS )); then
        while IFS= read -r old; do
            rm -rf -- "$old"
            echo "prune $old"
        done < <(printf '%s\n' "${backups[@]}" | sort | head -n "-$KEEP_BACKUPS")
    fi
done
