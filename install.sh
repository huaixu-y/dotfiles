#!/usr/bin/env bash
# Bootstrap: symlink each tool config directory into ~/.config.
# Idempotent: correct existing links are kept; anything else at the
# destination is backed up with a timestamp suffix before linking.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

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
