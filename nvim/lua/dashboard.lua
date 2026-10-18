-- Dependency-free start page: rendered into the untouched empty buffer on a bare `nvim` launch.
local M = {}

local ns = vim.api.nvim_create_namespace("dotfiles.dashboard")

local BLOCK_WIDTH = 36 -- banner width; the rule and menu are laid out to match

local banner = {
  "███╗   ██╗ ██╗   ██╗ ██╗ ███╗   ███╗",
  "████╗  ██║ ██║   ██║ ██║ ████╗ ████║",
  "██╔██╗ ██║ ██║   ██║ ██║ ██╔████╔██║",
  "██║╚██╗██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║",
  "██║ ╚████║  ╚████╔╝  ██║ ██║ ╚═╝ ██║",
  "╚═╝  ╚═══╝   ╚═══╝   ╚═╝ ╚═╝     ╚═╝",
}

local buf, win, saved_wo

local function hex_to_rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

local function lerp_hex(from, to, t)
  local r1, g1, b1 = hex_to_rgb(from)
  local r2, g2, b2 = hex_to_rgb(to)
  local function mix(a, b)
    return math.floor(a + (b - a) * t + 0.5)
  end
  return string.format("#%02x%02x%02x", mix(r1, r2), mix(g1, g2), mix(b1, b2))
end

local function palette()
  local ok, palettes = pcall(require, "catppuccin.palettes")
  if ok then
    local ok_pal, pal = pcall(palettes.get_palette)
    if ok_pal and pal then
      return pal
    end
  end
  return {
    mauve = "#cba6f7",
    blue = "#89b4fa",
    text = "#cdd6f4",
    overlay1 = "#7f849c",
    surface1 = "#45475a",
    peach = "#fab387",
    teal = "#94e2d5",
  }
end

local function setup_highlights()
  local pal = palette()
  for i = 1, #banner do
    vim.api.nvim_set_hl(0, "DotfilesDashboardBanner" .. i, {
      fg = lerp_hex(pal.mauve, pal.blue, (i - 1) / (#banner - 1)),
      bold = true,
    })
  end
  vim.api.nvim_set_hl(0, "DotfilesDashboardSubtitle", { fg = pal.overlay1 })
  vim.api.nvim_set_hl(0, "DotfilesDashboardRule", { fg = pal.surface1 })
  vim.api.nvim_set_hl(0, "DotfilesDashboardIcon", { fg = pal.peach })
  vim.api.nvim_set_hl(0, "DotfilesDashboardLabel", { fg = pal.text })
  vim.api.nvim_set_hl(0, "DotfilesDashboardKey", { fg = pal.teal, bold = true })
end

local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function new_file()
  vim.ui.input({ prompt = "New file: " }, function(name)
    if name ~= nil and name ~= "" then
      edit(name)
    end
  end)
end

local IGNORED = { "/%.git/", "/node_modules/", "/%.venv/", "/__pycache__/", "/target/" }

local function find_file()
  local cwd = vim.fn.getcwd()
  local files = {}
  for _, path in ipairs(vim.fn.globpath(cwd, "**/*", false, true)) do
    if vim.fn.isdirectory(path) == 0 then
      local ignored = vim.iter(IGNORED):any(function(pat)
        return path:find(pat) ~= nil
      end)
      if not ignored then
        files[#files + 1] = path
        if #files >= 2000 then
          break
        end
      end
    end
  end
  vim.ui.select(files, { prompt = "Find file" }, function(choice)
    if choice then
      edit(choice)
    end
  end)
end

local function recent_files()
  local seen, files = {}, {}
  for _, path in ipairs(vim.v.oldfiles) do
    if vim.fn.filereadable(path) == 1 and not seen[path] then
      seen[path] = true
      files[#files + 1] = path
      if #files >= 200 then
        break
      end
    end
  end
  vim.ui.select(files, { prompt = "Recent files" }, function(choice)
    if choice then
      edit(choice)
    end
  end)
end

local menu = {
  { icon = "󰈅", label = "New file", key = "n", action = new_file },
  { icon = "󰍉", label = "Find file", key = "f", action = find_file },
  { icon = "󰋚", label = "Recent files", key = "r", action = recent_files },
  { icon = "󰒓", label = "Open config", key = "c", action = function() edit(vim.fn.stdpath("config") .. "/init.lua") end },
  { icon = "󰐥", label = "Quit", key = "q", action = function() vim.cmd.quit() end },
}

local function subtitle()
  local text = ("v%s · %s"):format(tostring(vim.version()), vim.fn.fnamemodify(vim.fn.getcwd(), ":~"))
  if vim.fn.strdisplaywidth(text) <= BLOCK_WIDTH then
    return text
  end
  -- keep the tail (the informative part) and mark the cut
  local start = 0
  while vim.fn.strdisplaywidth(vim.fn.strcharpart(text, start)) > BLOCK_WIDTH - 1 do
    start = start + 1
  end
  return "…" .. vim.fn.strcharpart(text, start)
end

local function menu_rows()
  local rows = {}
  for _, item in ipairs(menu) do
    local used = 4 + vim.fn.strdisplaywidth(item.icon) + 2 + vim.fn.strdisplaywidth(item.label)
    local gap = math.max(1, BLOCK_WIDTH - used - 1) -- key sits on the block's right edge
    rows[#rows + 1] = {
      { string.rep(" ", 4), "DotfilesDashboardLabel" },
      { item.icon, "DotfilesDashboardIcon" },
      { "  " .. item.label, "DotfilesDashboardLabel" },
      { string.rep(" ", gap), "DotfilesDashboardLabel" },
      { item.key, "DotfilesDashboardKey" },
    }
  end
  return rows
end

local function render()
  if not (buf and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)) then
    return
  end
  if vim.api.nvim_win_get_buf(win) ~= buf then
    return
  end

  local rows = {}
  for i, line in ipairs(banner) do
    rows[#rows + 1] = { { line, "DotfilesDashboardBanner" .. i } }
  end
  rows[#rows + 1] = {}
  rows[#rows + 1] = { { subtitle(), "DotfilesDashboardSubtitle" } }
  rows[#rows + 1] = { { string.rep("─", BLOCK_WIDTH), "DotfilesDashboardRule" } }
  rows[#rows + 1] = {}
  vim.list_extend(rows, menu_rows())

  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)
  local top = math.max(0, math.floor((height - #rows) / 2))

  local lines, marks = {}, {}
  for _ = 1, top do
    lines[#lines + 1] = ""
  end
  for i, spans in ipairs(rows) do
    local row_width = 0
    for _, span in ipairs(spans) do
      row_width = row_width + vim.fn.strdisplaywidth(span[1])
    end
    local line, col = "", 0
    if row_width > 0 then
      local indent = math.max(0, math.floor((width - row_width) / 2))
      line, col = string.rep(" ", indent), indent
      for _, span in ipairs(spans) do
        local text, hl = span[1], span[2]
        if hl and text ~= "" then
          marks[#marks + 1] = { row = top + i - 1, start = col, stop = col + #text, hl = hl }
        end
        line = line .. text
        col = col + #text
      end
    end
    lines[#lines + 1] = line
  end
  for _ = #lines + 1, height do
    lines[#lines + 1] = ""
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, mark.row, mark.start, {
      end_col = mark.stop,
      hl_group = mark.hl,
      priority = 200,
    })
  end

  pcall(vim.api.nvim_win_set_cursor, win, { math.min(top + 1, #lines), 0 })
end

local WINDOW_OPTS = { "number", "relativenumber", "signcolumn", "foldcolumn", "wrap", "list", "spell", "cursorline", "fillchars" }

local function restore_window_opts()
  if not saved_wo then
    return
  end
  if vim.api.nvim_win_is_valid(saved_wo.win) then
    for _, name in ipairs(WINDOW_OPTS) do
      vim.wo[saved_wo.win][name] = saved_wo[name]
    end
  end
  saved_wo = nil
end

local function setup_keymaps()
  for _, item in ipairs(menu) do
    vim.keymap.set("n", item.key, item.action, { buffer = buf, nowait = true, desc = item.label })
  end
end

local function is_startup_page()
  if vim.g.dotfiles_dashboard_skip == 1 then
    return false
  end
  if vim.fn.argc() > 0 or vim.v.this_session ~= "" then
    return false
  end
  for _, arg in ipairs(vim.v.argv) do
    if arg == "-" or arg == "-c" or arg == "--cmd" or arg:sub(1, 1) == "+" then
      return false
    end
  end
  local current = vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_name(current) == ""
    and vim.bo[current].buftype == ""
    and not vim.bo[current].modified
    and vim.fn.line2byte("$") == -1
end

local function attach()
  buf = vim.api.nvim_get_current_buf()
  win = vim.api.nvim_get_current_win()

  vim.bo[buf].swapfile = false
  vim.bo[buf].undolevels = -1
  vim.bo[buf].buflisted = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  saved_wo = { win = win }
  for _, name in ipairs(WINDOW_OPTS) do
    saved_wo[name] = vim.wo[win][name]
  end
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = false
  vim.wo[win].list = false
  vim.wo[win].spell = false
  vim.wo[win].cursorline = false
  vim.wo[win].fillchars = "eob: "

  setup_keymaps()
  render()

  local group = vim.api.nvim_create_augroup("dotfiles.dashboard", { clear = true })
  vim.api.nvim_create_autocmd("BufWinLeave", { group = group, buffer = buf, callback = restore_window_opts })
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, { group = group, callback = render })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      setup_highlights()
      render()
    end,
  })
end

function M.setup()
  setup_highlights()
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("dotfiles.dashboard.enter", { clear = true }),
    callback = function()
      if is_startup_page() then
        attach()
      end
    end,
  })
end

return M
