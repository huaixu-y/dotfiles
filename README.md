# dotfiles

Personal dotfiles for a terminal-based Linux (Wayland) workflow. Each top-level directory holds the configuration for one tool, laid out to mirror its location under `~/.config/`.

## Structure

```
fastfetch/config.jsonc   -> ~/.config/fastfetch/config.jsonc
fish/config.fish         -> ~/.config/fish/config.fish
fish/completions/*.fish  -> ~/.config/fish/completions/*.fish
helix/config.toml        -> ~/.config/helix/config.toml
kitty/kitty.conf         -> ~/.config/kitty/kitty.conf
kitty/themes/mocha.conf  -> ~/.config/kitty/themes/mocha.conf
nushell/config.nu        -> ~/.config/nushell/config.nu
nushell/env.nu           -> ~/.config/nushell/env.nu
nvim/init.lua            -> ~/.config/nvim/init.lua
nvim/lua/dashboard.lua   -> ~/.config/nvim/lua/dashboard.lua
tmux/tmux.conf           -> ~/.config/tmux/tmux.conf
yazi/theme.toml          -> ~/.config/yazi/theme.toml
yazi/catppuccin-mocha.tmTheme -> ~/.config/yazi/catppuccin-mocha.tmTheme
```

## Tools

- **fish** — primary shell. `config.fish` initializes the Starship prompt (skipped when not installed), disables the welcome greeting, aliases `ft` to `fastfetch` and `vim` to `nvim`, and sets `EDITOR=nvim` when installed. Completion for `gc` is included; `gitcode` completion is machine-local and git-ignored. The cargo env comes from rustup's own `conf.d/rustup.fish` drop-in (git-ignored).
- **Nushell** — secondary shell, after fish in the tmux auto-detect order. `config.nu` initializes the Starship prompt, hides the banner, aliases `ft` to `fastfetch` and `vim` to `nvim`, and sources `~/.cargo/env.nu`. `env.nu` sets `$env.EDITOR` to `nvim` when it is installed.
- **tmux** — prefix `C-Space`, default shell auto-detected at server start (fish → nu → zsh, falling back to `/bin/sh`), mouse on, 1-based indexing, extended keys (CSI-u), `allow-passthrough` for Yazi image previews (Kitty protocol), Alt-hjkl pane navigation, vi copy mode piping to `wl-copy`, 10ms escape-time, 10000-line scrollback, and `display-popup` bindings (`C-p` shell, `g` lazygit, `v` nvim, `/` command menu) at 90% size. True color (`*:RGB` terminal feature) and focus events are enabled.
- **Helix** — `catppuccin_mocha` theme, relative line numbers, mouse disabled, cursor shapes per mode, soft-wrap enabled with the wrap indicator hidden.
- **Neovim** (0.12+) — catppuccin theme (mocha) via the `catppuccin/nvim` plugin installed with the built-in `vim.pack`. LSP for Python (`pyright`), Rust (`rust_analyzer`) and C/C++ (`clangd`) via built-in `vim.lsp.config`/`vim.lsp.enable` (no `nvim-lspconfig`). Built-in auto-completion (`vim.lsp.completion`): triggers on server trigger characters and from the 2nd keyword character of a word; `Tab`/`S-Tab` cycle items, `Enter` confirms. Buffer-local LSP keybindings (`gd`, `gD`, `<leader>lf` format, `<leader>ld` diagnostics; leader is Space). Hybrid relative line numbers. Indentation: 4 spaces. A hand-written start page (`lua/dashboard.lua`, no plugin) in the empty buffer on a bare `nvim` launch: centred banner with a mauve→blue gradient, cwd/version line, and a menu (`n` new file, `f` find file, `r` recent files, `c` open config, `q` quit); skips when files, `-c`/`+cmd` or a session are given, and `let g:dotfiles_dashboard_skip = 1` disables it. File search is asynchronous, using fd, ripgrep, or Git with a dependency-free fallback. Find and recent files share a centered Catppuccin floating picker with file icons and a live filter input.
- **fastfetch** — JSONC module list with the official JSON schema referenced via `$schema`.
- **Yazi** — Catppuccin Mocha theme (vendored from [catppuccin/yazi](https://github.com/catppuccin/yazi), lavender accent) with the matching syntax-highlighting theme from [catppuccin/bat](https://github.com/catppuccin/bat).
- **Kitty** — Cascadia Code NF (Nerd Font) with auto-detected bold/italic, `fish` as the shell, hidden titlebar (shadow kept for resizing), background blur with 0.9 opacity (COSMIC supports `org.kde.KWin.Blur`), and the Catppuccin Mocha theme (vendored from [catppuccin/kitty](https://github.com/catppuccin/kitty)).

Editors share the **Catppuccin** (Mocha) theme.

## Requirements

- Nushell, Starship, tmux, Helix, Neovim ≥ 0.12, fastfetch
- LSP servers on `PATH`: `pyright-langserver`, `rust-analyzer`, `clangd`
- Wayland clipboard: `wl-copy` (for tmux copy mode)
- Optional: fd or ripgrep for faster Dashboard file searches; btop and lazygit for tmux popups (yazi benefits from the tmux `allow-passthrough` setting for image previews)

## Installation

Run the bootstrap script to symlink every tool directory except `helix/` into `~/.config/` (idempotent; anything already at the destination is backed up as `*.bak.<timestamp>` first, and only the 3 most recent backups per tool are kept). The installer intentionally targets `~/.config`; custom `XDG_CONFIG_HOME` locations are not supported because Yazi's syntax theme uses a static absolute path:

```sh
./install.sh
```

Or deploy manually by symlinking a tool directory into `~/.config/`, e.g.:

```sh
ln -s ~/.dotfiles/helix ~/.config/helix
```

Notes:

- The first Neovim launch clones `vim.pack` plugins (needs network).
- `nushell/history.txt` and `fish/fish_variables` are machine-local and git-ignored.

## Verifying changes

- tmux: `tmux source-file ~/.config/tmux/tmux.conf` (or prefix + `r`)
- Nushell: start a new `nu` session or `source` the file
- fish: `fish -n ~/.config/fish/config.fish` (syntax check) or start a new `fish` session
- Helix: `hx --health`
- Neovim: `nvim --headless -u NONE '+lua assert(loadfile("nvim/init.lua"))' +qa` (syntax check)
- fastfetch: run `fastfetch`
