vim.g.mapleader = " "

-- Indentation: 4 spaces
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Line numbers: relative, current line absolute (like Helix)
vim.opt.number = true
vim.opt.relativenumber = true

-- Tab / Shift-Tab cycle the completion popup; insert a tab otherwise
vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true })
-- Enter confirms the selected completion item; newline otherwise.
-- With "noselect" in 'completeopt', an open menu with nothing selected is just closed.
vim.keymap.set("i", "<CR>", function()
  return vim.fn.pumvisible() == 1 and "<C-y>" or "<CR>"
end, { expr = true })

-- Theme: catppuccin-nvim, mocha flavor
vim.pack.add({ { src = "https://github.com/catppuccin/nvim", name = "catppuccin" } })
require("catppuccin").setup({ flavour = "mocha" })
vim.cmd.colorscheme("catppuccin")

-- LSP server configurations (no plugins; built-in vim.lsp.config)
-- Requires `pyright-langserver`, `rust-analyzer` and `clangd` executables on PATH
vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
})

vim.lsp.config("rust_analyzer", {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_markers = { "Cargo.toml", "rust-project.json", ".git" },
})

vim.lsp.config("clangd", {
  cmd = { "clangd" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  root_markers = { ".clangd", "compile_commands.json", "compile_flags.txt", ".git" },
})

vim.lsp.enable({ "pyright", "rust_analyzer", "clangd" })

-- Auto-completion while typing (built-in LSP completion, autotrigger)
-- plus buffer-local LSP keybindings
vim.opt.completeopt = { "menuone", "noselect", "popup" }
local completion_augroup = vim.api.nvim_create_augroup("dotfiles.lsp_completion", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })

      -- Also trigger completion from the 2nd keyword character of a word.
      -- Register only once per buffer, even if multiple clients attach.
      if #vim.api.nvim_get_autocmds({ group = completion_augroup, buffer = args.buf }) == 0 then
        vim.api.nvim_create_autocmd("InsertCharPre", {
          group = completion_augroup,
          buffer = args.buf,
          callback = function()
            if vim.fn.pumvisible() ~= 0 then
              return
            end
            if not vim.v.char:match("[%w_]") then
              return
            end
            local col = vim.fn.col(".")
            local prev = col >= 2 and vim.api.nvim_get_current_line():sub(col - 1, col - 1) or ""
            if prev:match("[%w_]") then
              vim.lsp.completion.get()
            end
          end,
        })
      end
    end

    local opts = { buffer = args.buf }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)            -- go to definition
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)           -- go to declaration
    vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, opts)         -- format buffer
    vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)  -- line diagnostics
  end,
})
