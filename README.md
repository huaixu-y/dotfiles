# dotfile

Personal dotfiles for a terminal-based Linux (Wayland) workflow. Each top-level directory holds the configuration for one tool, laid out to mirror its location under `~/.config/`.

## Structure

```
fastfetch/config.jsonc   -> ~/.config/fastfetch/config.jsonc
helix/config.toml        -> ~/.config/helix/config.toml
nushell/config.nu        -> ~/.config/nushell/config.nu
nushell/env.nu           -> ~/.config/nushell/env.nu
nvim/init.lua            -> ~/.config/nvim/init.lua
tmux/tmux.conf           -> ~/.config/tmux/tmux.conf
```

## Tools

- **Nushell** — primary shell. `config.nu` initializes the Starship prompt, sets Neovim (`nvim`) as the buffer editor, hides the banner, aliases `ft` to `fastfetch` and `vim` to `nvim`, and sources `~/.cargo/env.nu`. `env.nu` prepends `~/.kimi-code/bin` to `PATH`.
- **tmux** — prefix `C-Space`, default shell `/usr/bin/nu`, mouse on, 1-based indexing, extended keys (CSI-u), `allow-passthrough` for Yazi image previews (Kitty protocol), Alt-hjkl pane navigation, vi copy mode piping to `wl-copy`, and `display-popup` bindings (`C-p` shell, `M` btop, `m` scratch session, `g` lazygit, `h` helix, `v` nvim, `/` command menu) at 90% size. True color (`*:RGB` terminal feature) and focus events are enabled.
- **Helix** — `catppuccin_mocha` theme, relative line numbers, mouse disabled, cursor shapes per mode, soft-wrap enabled with the wrap indicator hidden.
- **Neovim** (0.12+) — catppuccin theme (mocha) via the `catppuccin/nvim` plugin installed with the built-in `vim.pack`. LSP for Python (`pyright`), Rust (`rust_analyzer`) and C/C++ (`clangd`) via built-in `vim.lsp.config`/`vim.lsp.enable` (no `nvim-lspconfig`). Built-in auto-completion (`vim.lsp.completion`): triggers on server trigger characters and from the 2nd keyword character of a word; `Tab`/`S-Tab` cycle items, `Enter` confirms. Buffer-local LSP keybindings (`gd`, `gD`, `<leader>f`, `<leader>d`; leader is Space). Hybrid relative line numbers. Indentation: 4 spaces.
- **fastfetch** — JSONC module list with the official JSON schema referenced via `$schema`.

Editors share the **Catppuccin** (Mocha) theme.

## Requirements

- Nushell, Starship, tmux, Helix, Neovim ≥ 0.12, fastfetch
- LSP servers on `PATH`: `pyright-langserver`, `rust-analyzer`, `clangd`
- Wayland clipboard: `wl-copy` (for tmux copy mode)
- Optional popups: btop, lazygit, yazi

## Installation

Run the bootstrap script to symlink every tool directory into `~/.config/` (idempotent; anything already at the destination is backed up as `*.bak.<timestamp>` first):

```sh
./install.sh
```

Or deploy manually, e.g.:

```sh
ln -sf ~/.dotfile/helix/config.toml ~/.config/helix/config.toml
```

Notes:

- The first Neovim launch clones `vim.pack` plugins (needs network).
- `nushell/history.txt` is machine-local and git-ignored.

## Verifying changes

- tmux: `tmux source-file ~/.config/tmux/tmux.conf` (or prefix + `r`)
- Nushell: start a new `nu` session or `source` the file
- Helix: `hx --health`
- Neovim: `nvim --headless -u NONE '+lua assert(loadfile("nvim/init.lua"))' +qa` (syntax check)
- fastfetch: run `fastfetch`
