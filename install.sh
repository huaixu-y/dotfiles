#!/usr/bin/env bash
# Bootstrap: symlink each tool config directory into ~/.config.
# Only tools whose command is on PATH are linked; --all links everything.
# Idempotent: correct existing links are kept; anything else at the
# destination is backed up with a timestamp suffix before linking.
set -euo pipefail

if [[ -t 1 ]]; then
    green=$'\033[32m' yellow=$'\033[33m' cyan=$'\033[36m' gray=$'\033[90m' reset=$'\033[0m'
else
    green="" yellow="" cyan="" gray="" reset=""
fi
# Status tag padded to 6 columns, then the message.
say() { printf '%s%-6s%s%s\n' "$1" "$2" "$reset" "$3"; }

LINK_ALL=0
if [[ "${1:-}" == "--all" ]] && (($# == 1)); then
    LINK_ALL=1
elif (($#)); then
    echo "usage: ./install.sh [--all]" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Yazi's syntax theme needs a static path, so installation targets ~/.config.
CONFIG_HOME="$HOME/.config"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"
KEEP_BACKUPS=3

TOOLS=(fastfetch fish ghostty kitty nushell nvim tmux yazi)

mkdir -p "$CONFIG_HOME"

for tool in "${TOOLS[@]}"; do
    src="$REPO_DIR/$tool"
    dest="$CONFIG_HOME/$tool"

    if [[ ! -d "$src" ]]; then
        say "$yellow" skip "$tool (missing in repo)"
        continue
    fi

    # nushell's command is nu; every other tool matches its directory name.
    cmd="$tool"
    [[ "$tool" == nushell ]] && cmd=nu
    if (( ! LINK_ALL )) && ! command -v "$cmd" >/dev/null; then
        say "$yellow" skip "$tool ($cmd not installed)"
        continue
    fi

    if [[ -L "$dest" ]]; then
        if [[ "$(readlink "$dest")" == "$src" ]]; then
            say "$green" ok "$tool (already linked)"
            continue
        fi
        mv "$dest" "${dest}${BACKUP_SUFFIX}"
        say "$yellow" back "$dest -> ${dest}${BACKUP_SUFFIX} (was a symlink)"
    elif [[ -e "$dest" ]]; then
        mv "$dest" "${dest}${BACKUP_SUFFIX}"
        say "$yellow" back "$dest -> ${dest}${BACKUP_SUFFIX}"
    fi

    ln -s "$src" "$dest"
    say "$cyan" link "$dest -> $src"
done

# Prune old backups, keeping the most recent ones per tool.
# Timestamp suffixes are zero-padded, so name sort matches age.
shopt -s nullglob
for tool in "${TOOLS[@]}"; do
    backups=("$CONFIG_HOME/$tool".bak.*)
    if ((${#backups[@]} > KEEP_BACKUPS)); then
        while IFS= read -r old; do
            rm -rf -- "$old"
            say "$gray" prune "$old"
        done < <(printf '%s\n' "${backups[@]}" | sort | head -n "-$KEEP_BACKUPS")
    fi
done
