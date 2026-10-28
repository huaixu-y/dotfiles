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
    base = "#1e1e2e",
    mauve = "#cba6f7",
    blue = "#89b4fa",
    text = "#cdd6f4",
    overlay1 = "#7f849c",
    surface0 = "#313244",
    surface1 = "#45475a",
    peach = "#fab387",
    teal = "#94e2d5",
    lavender = "#b4befe",
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
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerNormal", { bg = pal.base })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerBorder", { fg = pal.surface1, bg = pal.base })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerTitle", { fg = pal.mauve, bg = pal.base, bold = true })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerFooter", { fg = pal.overlay1, bg = pal.base })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerSelection", { bg = pal.surface0 })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerIcon", { fg = pal.lavender })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerPath", { fg = pal.text })
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

local FIND_FILE_LIMIT = 2000
local PICKER_HEIGHT = 15
local IGNORED_DIRS = { ".git", "node_modules", ".venv", "__pycache__", "target" }
local IGNORED_DIR_SET = {}
for _, name in ipairs(IGNORED_DIRS) do
  IGNORED_DIR_SET[name] = true
end

local finding_files = false

local FILE_ICONS = {
  c = "", cpp = "", css = "", fish = "", go = "", h = "",
  html = "", js = "", json = "", jsonc = "", lua = "", md = "󰂺",
  nu = "", py = "", rs = "", sh = "", toml = "", ts = "",
  tsx = "", xml = "󰗀", yaml = "", yml = "",
}

local function file_icon(path)
  local extension = path:match("%.([^.]+)$")
  return (extension and FILE_ICONS[extension:lower()]) or "󰈔"
end

-- Keep the informative tail when a label does not fit.
local function truncate_tail(text, width)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local start = 0
  while vim.fn.strdisplaywidth(vim.fn.strcharpart(text, start)) > width - 1 do
    start = start + 1
  end
  return "…" .. vim.fn.strcharpart(text, start)
end

local function matches_filter(path, query)
  local text = path:lower()
  for token in query:lower():gmatch("%S+") do
    if not text:find(token, 1, true) then
      return false
    end
  end
  return true
end

local function open_file_picker(files, title, on_choice)
  if #files == 0 then
    vim.notify("No files found", vim.log.levels.INFO)
    return
  end

  local parent = vim.api.nvim_get_current_win()
  local input_buf = vim.api.nvim_create_buf(false, true)
  local list_buf = vim.api.nvim_create_buf(false, true)
  local width = math.max(20, math.min(100, math.floor(vim.o.columns * 0.65)))
  width = math.min(width, math.max(20, vim.o.columns - 4))
  local height = math.min(PICKER_HEIGHT, math.max(1, vim.o.lines - 10))
  local top = math.max(0, math.floor((vim.o.lines - height - 5) / 2) - 1)
  local left = math.max(0, math.floor((vim.o.columns - width) / 2))
  local filtered, input_win, list_win = {}, nil, nil
  local closed = false

  local function render()
    if closed then
      return
    end
    local query = table.concat(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false), " ")
    filtered = {}
    for _, path in ipairs(files) do
      if matches_filter(path, query) then
        filtered[#filtered + 1] = path
      end
    end

    local lines, marks = {}, {}
    for i, path in ipairs(filtered) do
      local icon = file_icon(path)
      local display = vim.fn.fnamemodify(path, ":~"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
      display = truncate_tail(display, width - 6)
      lines[i] = " " .. icon .. " " .. display .. " "
      local path_col = #icon + 2
      marks[#marks + 1] = { row = i - 1, col = 1, stop = #icon + 1, hl = "DotfilesDashboardPickerIcon" }
      marks[#marks + 1] = {
        row = i - 1,
        col = path_col,
        stop = path_col + #display,
        hl = "DotfilesDashboardPickerPath",
      }
    end
    if #filtered == 0 then
      lines = { "  No matching files " }
      marks = { { row = 0, col = 2, stop = 19, hl = "DotfilesDashboardSubtitle" } }
    end

    vim.bo[list_buf].modifiable = true
    vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
    vim.bo[list_buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(list_buf, ns, 0, -1)
    for _, mark in ipairs(marks) do
      vim.api.nvim_buf_set_extmark(list_buf, ns, mark.row, mark.col, {
        end_col = mark.stop,
        hl_group = mark.hl,
      })
    end

    vim.api.nvim_win_set_config(list_win, {
      title = (" %d/%d "):format(#filtered, #files),
      title_pos = "center",
    })
    local row = math.max(1, math.min(vim.api.nvim_win_get_cursor(list_win)[1], #filtered))
    vim.api.nvim_win_set_cursor(list_win, { row, 0 })
  end

  local function close()
    if closed then
      return
    end
    closed = true
    vim.cmd.stopinsert()
    if vim.api.nvim_win_is_valid(input_win) then
      vim.api.nvim_win_close(input_win, true)
    end
    if vim.api.nvim_win_is_valid(list_win) then
      vim.api.nvim_win_close(list_win, true)
    end
    if vim.api.nvim_win_is_valid(parent) then
      vim.api.nvim_set_current_win(parent)
    end
  end
  local function choose()
    local choice = filtered[vim.api.nvim_win_get_cursor(list_win)[1]]
    if not choice then
      return
    end
    close()
    on_choice(choice)
  end
  local function move(delta)
    if #filtered == 0 then
      return
    end
    local row = vim.api.nvim_win_get_cursor(list_win)[1]
    row = (row - 1 + delta) % #filtered + 1
    vim.api.nvim_win_set_cursor(list_win, { row, 0 })
  end
  local function focus_input()
    vim.api.nvim_set_current_win(input_win)
    vim.cmd("startinsert!")
  end

  input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor",
    row = top,
    col = left,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = " 󰍉 " .. title .. " ",
    title_pos = "center",
    zindex = 61,
  })
  list_win = vim.api.nvim_open_win(list_buf, false, {
    relative = "editor",
    row = top + 3,
    col = left,
    width = width,
    height = height,
    title = (" %d/%d "):format(#files, #files),
    title_pos = "center",
    style = "minimal",
    border = "rounded",
    footer = " C-n/p move   Enter open   Esc close ",
    footer_pos = "center",
    zindex = 60,
  })
  local winhighlight = table.concat({
    "Normal:DotfilesDashboardPickerNormal",
    "NormalFloat:DotfilesDashboardPickerNormal",
    "FloatBorder:DotfilesDashboardPickerBorder",
    "FloatTitle:DotfilesDashboardPickerTitle",
    "FloatFooter:DotfilesDashboardPickerFooter",
    "CursorLine:DotfilesDashboardPickerSelection",
  }, ",")
  vim.wo[input_win].winhighlight = winhighlight
  vim.wo[list_win].winhighlight = winhighlight
  vim.wo[list_win].cursorline = true
  vim.wo[list_win].fillchars = "eob: "
  vim.bo[input_buf].bufhidden = "wipe"
  vim.bo[list_buf].bufhidden = "wipe"

  local input_opts = { buffer = input_buf, nowait = true, silent = true }
  for _, mode in ipairs({ "i", "n" }) do
    vim.keymap.set(mode, "<CR>", choose, input_opts)
    vim.keymap.set(mode, "<Esc>", close, input_opts)
    vim.keymap.set(mode, "<C-c>", close, input_opts)
    vim.keymap.set(mode, "<C-n>", function() move(1) end, input_opts)
    vim.keymap.set(mode, "<C-p>", function() move(-1) end, input_opts)
    vim.keymap.set(mode, "<Down>", function() move(1) end, input_opts)
    vim.keymap.set(mode, "<Up>", function() move(-1) end, input_opts)
  end
  local list_opts = { buffer = list_buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", choose, list_opts)
  vim.keymap.set("n", "<Esc>", close, list_opts)
  vim.keymap.set("n", "<C-c>", close, list_opts)
  vim.keymap.set("n", "q", close, list_opts)
  vim.keymap.set("n", "/", focus_input, list_opts)
  vim.keymap.set("n", "i", focus_input, list_opts)
  vim.keymap.set("n", "<C-n>", function() move(1) end, list_opts)
  vim.keymap.set("n", "<C-p>", function() move(-1) end, list_opts)
  vim.keymap.set("n", "<Down>", function() move(1) end, list_opts)
  vim.keymap.set("n", "<Up>", function() move(-1) end, list_opts)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = input_buf,
    callback = render,
  })
  render()
  vim.cmd("startinsert!")
end

local function show_file_picker(cwd, files)
  finding_files = false
  table.sort(files)
  open_file_picker(files, "Find file", function(choice)
    edit(vim.fs.joinpath(cwd, choice))
  end)
end

-- Prune ignored directories and yield between scans to keep the UI responsive.
local function scan_files(cwd)
  local files, dirs = {}, { cwd }
  local prefix = cwd:sub(-1) == "/" and cwd or cwd .. "/"
  local function step()
    if #files >= FIND_FILE_LIMIT then
      show_file_picker(cwd, files)
      return
    end
    local dir = table.remove(dirs)
    if not dir then
      show_file_picker(cwd, files)
      return
    end
    local scanner = vim.uv.fs_scandir(dir)
    if scanner then
      while #files < FIND_FILE_LIMIT do
        local name, kind = vim.uv.fs_scandir_next(scanner)
        if not name then
          break
        end
        local path = vim.fs.joinpath(dir, name)
        if kind == "directory" then
          if not IGNORED_DIR_SET[name] then
            dirs[#dirs + 1] = path
          end
        elseif kind == "file" or kind == "link" then
          local target = kind == "link" and vim.uv.fs_stat(path) or nil
          if kind == "file" or (target and target.type == "file") then
            files[#files + 1] = path:sub(#prefix + 1)
          end
        end
      end
    end
    vim.schedule(step)
  end
  step()
end

local function find_file()
  if finding_files then
    return
  end
  finding_files = true
  local cwd = vim.fn.getcwd()
  local cmd
  local fd = vim.fn.executable("fd") == 1 and "fd"
    or (vim.fn.executable("fdfind") == 1 and "fdfind" or nil)
  if fd then
    cmd = { fd, "--type", "f", "--hidden", "--color", "never", "--print0" }
    for _, name in ipairs(IGNORED_DIRS) do
      vim.list_extend(cmd, { "--exclude", name })
    end
  elseif vim.fn.executable("rg") == 1 then
    cmd = { "rg", "--files", "--hidden", "--color", "never", "--null" }
    for _, name in ipairs(IGNORED_DIRS) do
      vim.list_extend(cmd, { "--glob", "!" .. name .. "/" })
    end
  elseif vim.fn.executable("git") == 1 and vim.fs.find(".git", { path = cwd, upward = true })[1] then
    cmd = { "git", "ls-files", "--cached", "--others", "--exclude-standard", "-z" }
  end

  if not cmd then
    scan_files(cwd)
    return
  end
  vim.system(cmd, { cwd = cwd, text = true }, function(result)
    local files = {}
    if result.code == 0 then
      for path in (result.stdout or ""):gmatch("([^%z]+)") do
        if path:sub(1, 2) == "./" then
          path = path:sub(3)
        end
        files[#files + 1] = path
        if #files >= FIND_FILE_LIMIT then
          break
        end
      end
    end
    vim.schedule(function()
      if result.code == 0 then
        show_file_picker(cwd, files)
      else
        scan_files(cwd)
      end
    end)
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
  open_file_picker(files, "Recent files", edit)
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
  return truncate_tail(text, BLOCK_WIDTH)
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
