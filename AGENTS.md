# AGENTS.md

## Project overview

This is a personal **dotfiles repository** (`huaixu-y/dotfiles` on GitHub, branch `main`). It is not a buildable software project — there is no package manifest (`pyproject.toml`, `package.json`, `Cargo.toml`, etc.), no build system, no test suite, and no CI. Each top-level directory holds the configuration for one tool, laid out to mirror its location under `~/.config/`:

```
fastfetch/config.jsonc   -> ~/.config/fastfetch/config.jsonc
helix/config.toml        -> ~/.config/helix/config.toml
nushell/config.nu        -> ~/.config/nushell/config.nu
nushell/env.nu           -> ~/.config/nushell/env.nu
nvim/init.lua            -> ~/.config/nvim/init.lua
tmux/tmux.conf           -> ~/.config/tmux/tmux.conf
```

The `install.sh` bootstrap script symlinks each tool directory into `~/.config/` (idempotent; existing entries are backed up as `*.bak.<timestamp>` before linking, and old backups are pruned, keeping the 3 most recent per tool). The tmux config references `~/.config/tmux/tmux.conf` in its reload binding, confirming that layout.

## Technology stack

Configurations for a terminal-based Linux (Wayland) workflow:

- **Nushell** — the primary shell. `config.nu` initializes the Starship prompt (regenerating `starship.nu` into `$nu.data-dir/vendor/autoload` on every startup), hides the banner, aliases `ft` to `fastfetch` and `vim` to `nvim`, and sources `~/.cargo/env.nu`. `env.nu` currently only sets `$env.EDITOR` to `nvim` when it is installed. `nushell/history.txt` is machine-local and git-ignored via `nushell/.gitignore`.
- **tmux** — prefix is `C-Space` (not the default `C-b`), default shell is auto-detected at server start via `run-shell` + `command -v nu` (falling back to `/bin/sh` so panes still spawn when nu is missing), mouse on, 1-based indexing, 10ms escape-time, 10000-line history limit, extended keys (CSI-u), `allow-passthrough` for Yazi image previews (Kitty protocol), Alt-hjkl pane navigation, vi copy mode piping to `wl-copy` (Wayland; macOS `pbcopy` and X11 `xclip` alternatives are kept commented out), and several `display-popup` bindings (`C-p` shell, `M` btop, `m` scratch session, `g` lazygit, `h` helix, `v` nvim, `/` command menu) at 90% size. True color (the `*:RGB` terminal feature) and focus events are enabled.
- **Helix** — `catppuccin_mocha` theme, relative line numbers, mouse disabled, cursor shapes per mode, soft-wrap enabled with the wrap indicator hidden (`wrap-indicator = ""`). The runtime lives at the default location `~/.config/helix/runtime` — which resolves into this repo because `~/.config/helix` is a symlink to `helix/` here — and is git-ignored (`helix/runtime`).
- **Neovim** (0.12+) — `init.lua` sets the catppuccin theme (mocha) via the `catppuccin/nvim` plugin installed with `vim.pack`, and enables LSP for Python (`pyright`), Rust (`rust_analyzer`) and C/C++ (`clangd`) using the built-in `vim.lsp.config`/`vim.lsp.enable` with hand-written server configs — no `nvim-lspconfig` and no `require('lspconfig')` (deprecated). Auto-completion uses the built-in `vim.lsp.completion`: `autotrigger = true` (server trigger characters) plus an `InsertCharPre` autocmd that calls `vim.lsp.completion.get()` starting from the 2nd keyword character of a word. Popup interaction: `Tab`/`S-Tab` cycle items, `Enter` confirms the selected item (`C-y`), all falling through to their normal behavior when the menu is closed; `completeopt` keeps `noselect`. `mapleader` is Space; the same `LspAttach` autocmd adds buffer-local mappings (`gd`, `gD`, `<leader>f` format, `<leader>d` diagnostics) on top of Neovim's built-in `gr*` LSP defaults. Line numbers are hybrid relative; indentation is 4 spaces. Server executables must be on `PATH` (`pyright-langserver`, `rust-analyzer`, `clangd`).
- **fastfetch** — JSONC module list with the official JSON schema referenced via `$schema`.

Consistent theme choice across editors: **Catppuccin** (Mocha).

## Build, test, and deployment

- Nothing to build and no tests to run.
- Verify changes by reloading the affected tool:
  - tmux: `tmux source-file ~/.config/tmux/tmux.conf` (or prefix + `r`); check syntax with `tmux source-file` from a running server.
  - Nushell: start a new `nu` session or `source` the file; note `config.nu` executes `starship init nu` and `mkdir` at load time.
  - Helix: run `hx --health` to validate config and runtime paths.
  - Neovim: check Lua syntax with `nvim --headless -u NONE '+lua assert(loadfile("nvim/init.lua"))' +qa`; note the first real launch clones `vim.pack` plugins (needs network).
  - fastfetch: run `fastfetch` to validate the JSONC.
- Deployment = run `./install.sh` to symlink every tool directory into `~/.config/`, or copy/symlink manually per file.

## Conventions for editing

- **Make minimal, focused changes.** Commit history shows small single-purpose commits (e.g. "tmux: add Alt-hjkl pane navigation bindings"); match that style — optionally prefix commit subjects with the tool name (`tmux: ...`).
- Keep platform-specific alternatives as commented-out lines rather than deleting them (see the clipboard bindings in `tmux/tmux.conf`).
- Do not commit `nushell/history.txt` (git-ignored).
- All comments and documentation are in English; write new comments in English.
- File formats: use each tool's native format (TOML for Helix, JSONC for fastfetch, Nushell script, Lua for Neovim, tmux config syntax) and preserve existing indentation (2-space in JSONC/Lua-ish files, none in tmux.conf).
- Neovim plugins are managed with the built-in **`vim.pack`** (Neovim 0.12+) by default — do not introduce external plugin managers (lazy.nvim, packer, etc.) unless explicitly requested.

## Security considerations

- This repo is pushed to a personal GitHub remote over SSH. It contains only program configuration — **never commit secrets, tokens, or machine-local data** (shell history is already ignored).
- Be careful with absolute paths embedded in configs (e.g. `~/.cargo/env.nu`): they reflect the owner's machine and should stay parameterized by `$HOME`/`$nu.home-dir` where the config language allows.
