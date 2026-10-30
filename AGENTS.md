# AGENTS.md

## Project scope

This is the personal **dotfiles repository** `huaixu-y/dotfiles` (GitHub, branch `main`). It has no package manifest, build system, automated test suite, or CI.

`README.md` is the single source of truth for repository structure, tool behavior, dependencies, installation, deployment, and per-tool verification. Read the relevant sections before making changes. Do not duplicate those details here; update the README when they change.

## Working on changes

- **Make minimal, focused changes.** Commit history uses small single-purpose commits, optionally prefixed with the tool name (`tmux: ...`).
- Validate each affected tool using the commands in `README.md`; there is no repository-wide build or test command.
- Keep documentation synchronized with configuration changes in the same commit. Update `README.md` for user-facing behavior, dependencies, installation, usage, or verification changes; update this file only for agent workflows, constraints, or editing rules.
- Before finishing, review `git diff` against both documents. Configuration commits should include both documents, or explicitly explain why either document intentionally needs no update. Use `SKIP_DOCS_CHECK=1` only after that review.
- Never describe documentation or validation as completed without actually checking it.

## Editing constraints

- Keep platform-specific alternatives as commented-out lines rather than deleting them.
- Write all comments and documentation in English. Keep comments sparse and explain only non-obvious reasons, workarounds, pitfalls, or external requirements.
- Use each tool's native format and preserve existing indentation (2-space in JSONC/Lua-ish files, none in tmux.conf).
- Manage Neovim plugins with the built-in **`vim.pack`** (Neovim 0.12+). Do not introduce external plugin managers unless explicitly requested.
- Do not commit machine-local state; existing exclusions belong in `.gitignore`.

## Security

- Never commit secrets, tokens, or machine-local data.
- Keep absolute paths parameterized by `$HOME`, `$nu.home-dir`, or the equivalent when the configuration language allows.
