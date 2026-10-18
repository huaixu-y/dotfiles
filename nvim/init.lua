vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Indentation
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Hybrid relative line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- General editing
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true -- required by Catppuccin
vim.o.winborder = "rounded"
vim.opt.clipboard = "unnamedplus"

-- Completion popup: Tab/S-Tab cycle items, Enter confirms the selected one.
-- With "noselect", an open menu with nothing selected must not swallow Enter.
vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true })
vim.keymap.set("i", "<CR>", function()
  if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected ~= -1 then
    return "<C-y>"
  end
  return "<CR>"
end, { expr = true })

-- Theme
vim.pack.add({ { src = "https://github.com/catppuccin/nvim", name = "catppuccin" } })
require("catppuccin").setup({ flavour = "mocha" })
vim.cmd.colorscheme("catppuccin")

-- Start page (after the theme so it can read the palette)
require("dashboard").setup()

-- LSP servers (built-in vim.lsp.config; executables must be on PATH)
vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyrightconfig.json", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
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

vim.diagnostic.config({
  severity_sort = true,
  -- only errors are shown inline; other severities via signs/underline and <leader>ld
  virtual_text = { severity = vim.diagnostic.severity.ERROR },
})

-- Built-in LSP completion (autotrigger) + buffer-local keymaps
vim.opt.completeopt = { "menuone", "noselect", "popup", "fuzzy" }
vim.opt.pumheight = 10
vim.opt.pumblend = 10
-- Nerd Font icons for the completion menu's kind column (requires a Nerd Font)
local kind_icons = {
  Text = "󰉿", Method = "󰆧", Function = "󰊕", Constructor = "",
  Field = "󰜢", Variable = "󰀫", Class = "󰠱", Interface = "",
  Module = "", Property = "󰜢", Unit = "󰑭", Value = "󰎠",
  Enum = "", Keyword = "󰌋", Snippet = "", Color = "󰏘",
  File = "󰈙", Reference = "󰈇", Folder = "󰉋", EnumMember = "",
  Constant = "󰏿", Struct = "󰙅", Event = "", Operator = "󰆕",
  TypeParameter = "󰊄",
}

local function completion_convert(item)
  local kind = vim.lsp.protocol.CompletionItemKind[item.kind]
  local icon = kind and kind_icons[kind]
  return { kind = (icon ~= nil and icon ~= "") and (icon .. " " .. kind) or kind }
end

local completion_augroup = vim.api.nvim_create_augroup("dotfiles.lsp_completion", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, {
        autotrigger = true,
        convert = completion_convert,
      })

      -- Also trigger from the 2nd keyword character; register once per buffer
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
            -- charcol/strcharpart use char (not byte) indexing, so multibyte works
            local prev = col >= 2 and vim.fn.strcharpart(vim.api.nvim_get_current_line(), vim.fn.charcol(".") - 2, 1)
              or ""
            if prev:match("[%w_]") then
              vim.lsp.completion.get()
            end
          end,
        })
      end
    end

    -- gd/gD are not built-in defaults (those are the gr* maps)
    local opts = { buffer = args.buf }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set({ "n", "v" }, "<leader>lf", vim.lsp.buf.format, opts)
    vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, opts)
  end,
})
