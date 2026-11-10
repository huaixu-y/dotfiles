#!/usr/bin/env bash
# Install all dotfiles dependencies on Fedora (dnf5), then symlink the
# configs via install.sh. Idempotent; safe to re-run.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -t 1 ]]; then
    green=$'\033[32m' yellow=$'\033[33m' cyan=$'\033[36m' reset=$'\033[0m'
else
    green="" yellow="" cyan="" reset=""
fi
section() { printf '\n%s==> %s%s\n' "$cyan" "$1" "$reset"; }
note()    { printf '  %s•%s %s\n' "$cyan" "$reset" "$1"; }
ok()      { printf '  %sok%s    %s\n' "$green" "$reset" "$1"; }
skipped_msg() { printf '  %sskip%s  %s\n' "$yellow" "$reset" "$1"; }

# Plan line: state (install/installed/skipped), component, detail.
plan_action() {
    case "$1" in
        install)   printf '  %snew%s   %-14s %s\n' "$cyan" "$reset" "$2" "$3" ;;
        installed) printf '  %sok%s    %-14s %s\n' "$green" "$reset" "$2" "$3" ;;
        skipped)   printf '  %sskip%s  %-14s %s\n' "$yellow" "$reset" "$2" "$3" ;;
    esac
}

# Fedora package names; ghostty, yazi and lazygit are not in the official repos.
all_packages=(
    fish nushell tmux neovim fastfetch kitty ghostty yazi lazygit
    fd-find ripgrep btop wl-clipboard
    clang-tools-extra nodejs-npm
    cascadia-code-nf-fonts git curl
)

usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [--skip name[,name...]]... [-y|--yes]

Shows the installation plan and asks for confirmation before installing;
-y/--yes skips the confirmation (for non-interactive runs).

Skip components by package name, plus "starship", "pyright" and
"rust-analyzer" (installed via rustup, not dnf).
Skipping ghostty, yazi or lazygit also skips its COPR repository.
Example: ./bootstrap.sh --skip ghostty,kitty --skip pyright
EOF
}

skip=()
assume_yes=0
while (($#)); do
    case "$1" in
        -y|--yes) assume_yes=1; shift ;;
        --skip)
            (($# >= 2)) && [[ -n "$2" ]] || { echo "error: --skip needs a non-empty value" >&2; exit 1; }
            IFS=',' read -ra names <<< "$2"; skip+=("${names[@]}"); shift 2 ;;
        --skip=*)
            [[ -n "${1#*=}" ]] || { echo "error: --skip needs a non-empty value" >&2; exit 1; }
            IFS=',' read -ra names <<< "${1#*=}"; skip+=("${names[@]}"); shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument '$1'" >&2; usage >&2; exit 1 ;;
    esac
done

skipped() {
    local name
    for name in "${skip[@]}"; do
        [[ "$name" == "$1" ]] && return 0
    done
    return 1
}

if ((${#skip[@]})); then
    for name in "${skip[@]}"; do
        valid=0
        for known in starship pyright rust-analyzer "${all_packages[@]}"; do
            [[ "$name" == "$known" ]] && valid=1 && break
        done
        ((valid)) || { echo "error: unknown skip name '$name'" >&2; usage >&2; exit 1; }
    done
fi

SUDO=""
if ((EUID != 0)); then
    command -v sudo >/dev/null || { echo "error: sudo is required" >&2; exit 1; }
    SUDO="sudo"
fi

# Distro-specific installation. To add Debian: add build_debian_plan and
# install_debian plus a case branch, and generalize show_plan/validate_plan
# (their dnf/nodejs-npm wording is Fedora-specific). No COPR there, and
# several packages need other sources (nushell, ghostty, yazi, lazygit,
# fastfetch, Neovim >= 0.12, Nerd Font).
coprs=()
packages=()
build_fedora_plan() {
    local package
    skipped ghostty || coprs+=(scottames/ghostty)
    skipped yazi || coprs+=(lihaohong/yazi)
    skipped lazygit || coprs+=(dejan/lazygit)

    for package in "${all_packages[@]}"; do
        skipped "$package" || packages+=("$package")
    done
}

scheduled() {
    local package
    for package in "${packages[@]}"; do
        [[ "$package" == "$1" ]] && return 0
    done
    return 1
}

# Fail before any system changes when an action needs a command that is
# neither installed nor scheduled (e.g. --skip curl without curl on PATH).
validate_plan() {
    local need_curl=0 need_npm=0
    if ! skipped starship && ! command -v starship >/dev/null; then
        need_curl=1
    fi
    if ! skipped rust-analyzer && ! command -v rustup >/dev/null \
        && [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
        need_curl=1
    fi
    if ! skipped pyright && ! command -v pyright-langserver >/dev/null \
        && [[ ! -x "$HOME/.local/bin/pyright-langserver" ]]; then
        need_npm=1
    fi

    if ((need_curl)) && ! command -v curl >/dev/null && ! scheduled curl; then
        echo "error: Starship/rustup installers need curl, which is neither installed nor scheduled; do not --skip curl" >&2
        exit 1
    fi
    if ((need_npm)) && ! command -v npm >/dev/null && ! scheduled nodejs-npm; then
        echo "error: Pyright needs npm, which is neither installed nor scheduled; do not --skip nodejs-npm" >&2
        exit 1
    fi
}

show_plan() {
    section "Installation plan ($distro)"
    if ((${#coprs[@]})); then
        printf '  %sCOPR repositories:%s\n' "$cyan" "$reset"
        printf '    %s\n' "${coprs[@]}"
    fi
    if ((${#packages[@]})); then
        printf '  %sdnf packages%s (already-installed ones are skipped):\n' "$cyan" "$reset"
        printf '%s\n' "${packages[*]}" | fmt -w 68 | sed 's/^/    /'
    fi

    if skipped starship; then
        plan_action skipped starship "(--skip)"
    elif command -v starship >/dev/null; then
        plan_action installed starship "already installed"
    else
        plan_action install starship "starship.rs installer"
    fi

    if skipped pyright; then
        plan_action skipped pyright "(--skip)"
    elif command -v pyright-langserver >/dev/null \
        || [[ -x "$HOME/.local/bin/pyright-langserver" ]]; then
        plan_action installed pyright "already installed"
    else
        plan_action install pyright "npm install -g --prefix ~/.local"
    fi

    if skipped rust-analyzer; then
        plan_action skipped rust-analyzer "(--skip)"
        return
    fi
    rustup_bin="$(command -v rustup || true)"
    if [[ -z "$rustup_bin" && -x "$HOME/.cargo/bin/rustup" ]]; then
        rustup_bin="$HOME/.cargo/bin/rustup"
    fi
    if [[ -z "$rustup_bin" ]]; then
        plan_action install rust-analyzer "install rustup, then rustup component add"
    elif "$rustup_bin" component list --installed 2>/dev/null | grep -q '^rust-analyzer'; then
        plan_action installed rust-analyzer "already installed"
    else
        plan_action install rust-analyzer "rustup component add"
    fi
}

confirm_plan() {
    ((assume_yes)) && return 0
    local answer
    if ! read -r -p "Proceed with installation? [y/N] " answer; then
        echo "error: confirmation required; use --yes for non-interactive runs" >&2
        exit 1
    fi
    [[ "$answer" =~ ^[yY]([eE][sS])?$ ]] || { echo "Aborted."; exit 0; }
}

install_fedora() {
    local copr
    section "Enabling COPR repositories"
    if ((${#coprs[@]})); then
        for copr in "${coprs[@]}"; do
            $SUDO dnf copr enable -y "$copr"
        done
    else
        skipped_msg "all COPR repositories (--skip)"
    fi

    section "Installing packages (dnf)"
    if ((${#packages[@]})); then
        $SUDO dnf install -y "${packages[@]}"
    else
        skipped_msg "all packages (--skip)"
    fi
}

distro="$(. /etc/os-release 2>/dev/null && echo "${ID:-}")"
case "$distro" in
    fedora)
        build_fedora_plan
        validate_plan
        show_plan
        confirm_plan
        install_fedora ;;
    debian) echo "error: Debian support is not implemented yet" >&2; exit 1 ;;
    *) echo "error: unsupported distribution '${distro:-unknown}' (Fedora only)" >&2; exit 1 ;;
esac

# Starship is not packaged in Fedora; use its official installer.
section "Starship prompt"
if skipped starship; then
    skipped_msg "starship (--skip)"
elif command -v starship >/dev/null; then
    ok "starship already installed"
else
    curl -sS https://starship.rs/install.sh | $SUDO sh -s -- -y
fi

# User-level install (no sudo); Neovim needs ~/.local/bin on PATH.
section "Pyright (Neovim Python LSP)"
if skipped pyright; then
    skipped_msg "pyright (--skip)"
elif command -v pyright-langserver >/dev/null \
    || [[ -x "$HOME/.local/bin/pyright-langserver" ]]; then
    ok "pyright-langserver already installed"
else
    npm install -g --prefix "$HOME/.local" pyright
fi

# rust-analyzer comes from rustup, not dnf; install rustup itself when missing.
# The shell configs pick up ~/.cargo/env* on the next login.
section "rust-analyzer (rustup)"
if skipped rust-analyzer; then
    skipped_msg "rust-analyzer (--skip)"
else
    if ! command -v rustup >/dev/null && [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi
    export PATH="$HOME/.cargo/bin:$PATH"
    rustup component add rust-analyzer
fi

if command -v nvim >/dev/null; then
    nvim_ver="$(nvim --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
    if [[ "$(printf '%s\n' 0.12 "$nvim_ver" | sort -V | head -n1)" != "0.12" ]]; then
        echo "warning: Neovim $nvim_ver found, but >= 0.12 is required (vim.pack)" >&2
    fi
fi

section "Linking configurations"
"$REPO_DIR/install.sh"

section "Notes"
note "The first Neovim launch clones vim.pack plugins (needs network)."
note "Optional: make fish your login shell with: chsh -s \"\$(command -v fish)\""
if ! skipped pyright; then
    note "pyright-langserver lives in ~/.local/bin; make sure it is on PATH."
fi

printf '\n%sDone.%s\n' "$green" "$reset"
