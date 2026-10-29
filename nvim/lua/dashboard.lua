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
    yellow = "#f9e2af",
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
  vim.api.nvim_set_hl(0, "DotfilesDashboardVersion", { fg = pal.lavender })
  vim.api.nvim_set_hl(0, "DotfilesDashboardRule", { fg = pal.surface1 })
  vim.api.nvim_set_hl(0, "DotfilesDashboardIcon", { fg = pal.peach })
  vim.api.nvim_set_hl(0, "DotfilesDashboardFindIcon", { fg = pal.blue })
  vim.api.nvim_set_hl(0, "DotfilesDashboardRecentIcon", { fg = pal.lavender })
  vim.api.nvim_set_hl(0, "DotfilesDashboardConfigIcon", { fg = pal.teal })
  vim.api.nvim_set_hl(0, "DotfilesDashboardMutedIcon", { fg = pal.overlay1 })
  vim.api.nvim_set_hl(0, "DotfilesDashboardLabel", { fg = pal.text })
  vim.api.nvim_set_hl(0, "DotfilesDashboardKey", { fg = pal.teal, bold = true })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerNormal", { bg = pal.base })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerBorder", { fg = pal.surface1, bg = pal.base })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerTitle", { fg = pal.mauve, bg = pal.base, bold = true })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerFooter", { fg = pal.overlay1, bg = pal.base })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerSelection", { bg = pal.surface0, bold = true })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerIcon", { fg = pal.lavender })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerIconCode", { fg = pal.blue })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerIconMarkup", { fg = pal.peach })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerIconConfig", { fg = pal.yellow })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerDirectory", { fg = pal.overlay1 })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerPath", { fg = pal.text, bold = true })
  vim.api.nvim_set_hl(0, "DotfilesDashboardPickerCount", { fg = pal.teal, bg = pal.base, bold = true })
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

local FLOAT_WINHIGHLIGHT = table.concat({
  "Normal:DotfilesDashboardPickerNormal",
  "NormalFloat:DotfilesDashboardPickerNormal",
  "FloatBorder:DotfilesDashboardPickerBorder",
  "FloatTitle:DotfilesDashboardPickerTitle",
  "FloatFooter:DotfilesDashboardPickerFooter",
}, ",")
local PICKER_WINHIGHLIGHT = FLOAT_WINHIGHLIGHT .. ",CursorLine:DotfilesDashboardPickerSelection"

local function truncate_head(text, width)
  if width <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local count = math.max(0, vim.fn.strchars(text) - 1)
  while count > 0 and vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, count)) > width - 1 do
    count = count - 1
  end
  return vim.fn.strcharpart(text, 0, count) .. "…"
end

local function display_path(path)
  local text = vim.fn.fnamemodify(path, ":~")
  return text:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"):gsub("%c", "?")
end

local function chunks_width(chunks)
  local width = 0
  for _, chunk in ipairs(chunks) do
    width = width + vim.fn.strdisplaywidth(chunk[1])
  end
  return width
end

local function adaptive_title(icon, label, width)
  local title = " " .. icon .. " " .. label .. " "
  if vim.fn.strdisplaywidth(title) <= width then
    return title
  end
  title = " " .. label .. " "
  return vim.fn.strdisplaywidth(title) <= width and title or ""
end

local function key_footer(width, full, compact)
  local chunks = width >= chunks_width(full) and full or compact
  if width >= chunks_width(chunks) then
    return chunks
  end
  if width >= 5 then
    return {
      { "⏎", "DotfilesDashboardKey" },
      { " ", "DotfilesDashboardPickerFooter" },
      { "Esc", "DotfilesDashboardKey" },
    }
  end
  return { { "⏎", "DotfilesDashboardKey" } }
end

local function decorate_input(input_win, input_buf)
  vim.wo[input_win].wrap = false
  vim.wo[input_win].list = true
  vim.wo[input_win].listchars = "precedes:…,extends:…"
  vim.wo[input_win].sidescrolloff = 0
  vim.api.nvim_buf_set_extmark(input_buf, ns, 0, 0, {
    virt_text = { { "❯ ", "DotfilesDashboardKey" } },
    virt_text_pos = "inline",
    right_gravity = false, -- keep the prompt before text inserted at column zero
  })
end

local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function new_file()
  local parent = vim.api.nvim_get_current_win()
  local input_buf = vim.api.nvim_create_buf(false, true)
  local cwd = display_path(vim.fn.getcwd())
  if cwd:sub(-1) ~= "/" then
    cwd = cwd .. "/"
  end
  local group = vim.api.nvim_create_augroup("dotfiles.dashboard.new_file." .. input_buf, { clear = true })
  local input_win, closed = nil, false

  local function footer(width)
    local full = {
      { "Enter", "DotfilesDashboardKey" },
      { " create  ", "DotfilesDashboardPickerFooter" },
      { "Esc", "DotfilesDashboardKey" },
      { " cancel", "DotfilesDashboardPickerFooter" },
    }
    local compact = {
      { "Enter", "DotfilesDashboardKey" },
      { "  ", "DotfilesDashboardPickerFooter" },
      { "Esc", "DotfilesDashboardKey" },
    }
    local chunks = key_footer(width, full, compact)
    if chunks == full then
      local cwd_width = width - chunks_width(full) - 3
      if cwd_width >= 8 then
        table.insert(chunks, 1, { truncate_tail(cwd, cwd_width) .. " · ", "DotfilesDashboardPickerFooter" })
      end
    end
    return chunks
  end

  local function layout()
    local width = math.max(1, math.min(60, math.floor(vim.o.columns * 0.65), vim.o.columns - 4))
    local title = adaptive_title("󰈅", "New file", width)
    return {
      relative = "editor",
      row = math.max(0, math.floor((vim.o.lines - 5) / 2)),
      col = math.max(0, math.floor((vim.o.columns - width) / 2)),
      width = width,
      height = 1,
      title = title,
      title_pos = "center",
      footer = footer(width),
      footer_pos = "center",
    }
  end

  local function close()
    if closed then
      return
    end
    closed = true
    vim.cmd.stopinsert()
    vim.api.nvim_del_augroup_by_id(group)
    if input_win and vim.api.nvim_win_is_valid(input_win) then
      vim.api.nvim_win_close(input_win, true)
    end
    if vim.api.nvim_win_is_valid(parent) then
      vim.api.nvim_set_current_win(parent)
    end
  end

  local function confirm()
    if closed then
      return
    end
    local name = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1] or ""
    close()
    if name ~= "" then
      edit(name)
    end
  end

  local config = layout()
  config.style = "minimal"
  config.border = "rounded"
  config.zindex = 61
  input_win = vim.api.nvim_open_win(input_buf, true, config)
  vim.wo[input_win].winhighlight = FLOAT_WINHIGHLIGHT
  vim.bo[input_buf].bufhidden = "wipe"
  decorate_input(input_win, input_buf)

  local opts = { buffer = input_buf, nowait = true, silent = true }
  for _, mode in ipairs({ "i", "n" }) do
    vim.keymap.set(mode, "<CR>", confirm, opts)
    vim.keymap.set(mode, "<Esc>", close, opts)
    vim.keymap.set(mode, "<C-c>", close, opts)
  end
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if not closed and vim.api.nvim_win_is_valid(input_win) then
        vim.api.nvim_win_set_config(input_win, layout())
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(input_win),
    once = true,
    callback = close,
  })
  vim.cmd("startinsert!")
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

local CODE_EXTENSIONS = {
  c = true, cpp = true, fish = true, go = true, h = true, js = true,
  lua = true, nu = true, py = true, rs = true, sh = true, ts = true, tsx = true,
}
local MARKUP_EXTENSIONS = { css = true, html = true, md = true, xml = true }
local CONFIG_EXTENSIONS = { json = true, jsonc = true, toml = true, yaml = true, yml = true }

local function file_icon(path)
  local extension = path:match("%.([^.]+)$")
  extension = extension and extension:lower() or ""
  local icon = FILE_ICONS[extension] or "󰈔"
  local highlight = CODE_EXTENSIONS[extension] and "DotfilesDashboardPickerIconCode"
    or (MARKUP_EXTENSIONS[extension] and "DotfilesDashboardPickerIconMarkup")
    or (CONFIG_EXTENSIONS[extension] and "DotfilesDashboardPickerIconConfig")
    or "DotfilesDashboardPickerIcon"
  return icon, highlight
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
  local group = vim.api.nvim_create_augroup("dotfiles.dashboard.picker." .. input_buf, { clear = true })
  local filtered, input_win, list_win = {}, nil, nil
  local displayed_count = #files
  local closed = false

  local function footer(width)
    return key_footer(width, {
      { "C-n/p", "DotfilesDashboardKey" },
      { " move  ", "DotfilesDashboardPickerFooter" },
      { "Enter", "DotfilesDashboardKey" },
      { " open  ", "DotfilesDashboardPickerFooter" },
      { "Esc", "DotfilesDashboardKey" },
      { " close", "DotfilesDashboardPickerFooter" },
    }, {
      { "C-n/p", "DotfilesDashboardKey" },
      { "  ", "DotfilesDashboardPickerFooter" },
      { "Enter", "DotfilesDashboardKey" },
      { "  ", "DotfilesDashboardPickerFooter" },
      { "Esc", "DotfilesDashboardKey" },
    })
  end

  local function count_title(width)
    if vim.o.lines < 6 then
      return ""
    end
    local text = (" %d/%d "):format(displayed_count, #files)
    if vim.fn.strdisplaywidth(text) > width then
      return ""
    end
    return { { text, "DotfilesDashboardPickerCount" } }
  end

  local function layout()
    local width = math.max(1, math.min(100, math.floor(vim.o.columns * 0.65), vim.o.columns - 4))
    local bordered = vim.o.lines >= 6
    local height = bordered and math.min(PICKER_HEIGHT, math.max(1, vim.o.lines - 10))
      or math.min(PICKER_HEIGHT, math.max(1, vim.o.lines - 2))
    local total_height = height + (bordered and 5 or 1)
    local top = math.max(0, math.floor((vim.o.lines - total_height) / 2))
    local left = math.max(0, math.floor((vim.o.columns - width) / 2))
    local border = bordered and "rounded" or "none"
    return {
      relative = "editor",
      row = top,
      col = left,
      width = width,
      height = 1,
      border = border,
      title = bordered and adaptive_title("󰍉", title, width) or "",
      title_pos = "center",
      zindex = 61,
    }, {
      relative = "editor",
      row = top + (bordered and 3 or 1),
      col = left,
      width = width,
      height = height,
      border = border,
      title = bordered and count_title(width) or "",
      title_pos = "center",
      footer = bordered and footer(width) or "",
      footer_pos = "center",
      zindex = 60,
    }
  end

  local function render()
    if closed or not vim.api.nvim_win_is_valid(list_win) then
      return
    end
    local query = table.concat(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false), " ")
    filtered = {}
    for _, path in ipairs(files) do
      if matches_filter(path, query) then
        filtered[#filtered + 1] = path
      end
    end
    displayed_count = #filtered

    local width = vim.api.nvim_win_get_config(list_win).width
    local lines, marks = {}, {}
    for i, path in ipairs(filtered) do
      local icon, icon_highlight = file_icon(path)
      local path_width = math.max(1, width - vim.fn.strdisplaywidth(icon) - 3)
      local display = truncate_tail(display_path(path), path_width)
      lines[i] = " " .. icon .. " " .. display .. " "
      local path_col = #icon + 2
      marks[#marks + 1] = { row = i - 1, col = 1, stop = #icon + 1, hl = icon_highlight }
      local slash = display:match("^.*()/")
      if slash then
        marks[#marks + 1] = {
          row = i - 1,
          col = path_col,
          stop = path_col + slash,
          hl = "DotfilesDashboardPickerDirectory",
        }
        if slash < #display then
          marks[#marks + 1] = {
            row = i - 1,
            col = path_col + slash,
            stop = path_col + #display,
            hl = "DotfilesDashboardPickerPath",
          }
        end
      else
        marks[#marks + 1] = {
          row = i - 1,
          col = path_col,
          stop = path_col + #display,
          hl = "DotfilesDashboardPickerPath",
        }
      end
    end
    if #filtered == 0 then
      local message = truncate_head("No matching files", math.max(1, width - 2))
      lines = { " " .. message .. " " }
      marks = { { row = 0, col = 1, stop = 1 + #message, hl = "DotfilesDashboardSubtitle" } }
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
      title = count_title(width),
      title_pos = "center",
    })
    vim.wo[list_win].cursorline = #filtered > 0
    local row = math.max(1, math.min(vim.api.nvim_win_get_cursor(list_win)[1], #filtered))
    vim.api.nvim_win_set_cursor(list_win, { row, 0 })
  end

  local function close()
    if closed then
      return
    end
    closed = true
    vim.cmd.stopinsert()
    vim.api.nvim_del_augroup_by_id(group)
    if input_win and vim.api.nvim_win_is_valid(input_win) then
      vim.api.nvim_win_close(input_win, true)
    end
    if list_win and vim.api.nvim_win_is_valid(list_win) then
      vim.api.nvim_win_close(list_win, true)
    end
    if vim.api.nvim_win_is_valid(parent) then
      vim.api.nvim_set_current_win(parent)
    end
  end
  local function choose()
    if closed or not vim.api.nvim_win_is_valid(list_win) then
      return
    end
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

  local input_config, list_config = layout()
  input_config.style = "minimal"
  list_config.style = "minimal"
  input_win = vim.api.nvim_open_win(input_buf, true, input_config)
  list_win = vim.api.nvim_open_win(list_buf, false, list_config)
  vim.wo[input_win].winhighlight = FLOAT_WINHIGHLIGHT
  vim.wo[list_win].winhighlight = PICKER_WINHIGHLIGHT
  vim.wo[list_win].cursorline = true
  vim.wo[list_win].fillchars = "eob: "
  vim.bo[input_buf].bufhidden = "wipe"
  vim.bo[list_buf].bufhidden = "wipe"
  decorate_input(input_win, input_buf)

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
    group = group,
    buffer = input_buf,
    callback = render,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if closed or not vim.api.nvim_win_is_valid(input_win) or not vim.api.nvim_win_is_valid(list_win) then
        return
      end
      local input_config, list_config = layout()
      vim.api.nvim_win_set_config(input_win, input_config)
      vim.api.nvim_win_set_config(list_win, list_config)
      render()
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = { tostring(input_win), tostring(list_win) },
    once = true,
    callback = close,
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
  { icon = "󰈅", label = "New file", key = "n", action = new_file, hl = "DotfilesDashboardIcon" },
  { icon = "󰍉", label = "Find file", key = "f", action = find_file, hl = "DotfilesDashboardFindIcon" },
  { icon = "󰋚", label = "Recent files", key = "r", action = recent_files, hl = "DotfilesDashboardRecentIcon" },
  { icon = "󰒓", label = "Open config", key = "c", action = function() edit(vim.fn.stdpath("config") .. "/init.lua") end, hl = "DotfilesDashboardConfigIcon" },
  { icon = "󰐥", label = "Quit", key = "q", action = function() vim.cmd.quit() end, hl = "DotfilesDashboardMutedIcon" },
}

local function subtitle(width)
  local version = "v" .. tostring(vim.version())
  local text = version .. " · " .. display_path(vim.fn.getcwd())
  if vim.fn.strdisplaywidth(text) > width then
    return { { truncate_tail(text, width), "DotfilesDashboardSubtitle" } }
  end
  return {
    { version, "DotfilesDashboardVersion" },
    { text:sub(#version + 1), "DotfilesDashboardSubtitle" },
  }
end

local function compact_menu_row(width)
  local spans = {}
  local used = 0
  for i, item in ipairs(menu) do
    local separator = i > 1 and " " or ""
    if used + #separator + vim.fn.strdisplaywidth(item.key) > width then
      break
    end
    spans[#spans + 1] = { separator, "DotfilesDashboardLabel" }
    spans[#spans + 1] = { item.key, "DotfilesDashboardKey" }
    used = used + #separator + vim.fn.strdisplaywidth(item.key)
  end
  return spans
end

local function menu_rows(block_width)
  local rows = {}
  for _, item in ipairs(menu) do
    if block_width >= 10 then
      local indent = block_width >= BLOCK_WIDTH and 4 or (block_width >= 20 and 2 or 0)
      local icon_width = vim.fn.strdisplaywidth(item.icon)
      local label = truncate_head(item.label, block_width - indent - icon_width - 5)
      local used = indent + icon_width + 1 + vim.fn.strdisplaywidth(label)
      local gap = math.max(1, block_width - used - 3)
      rows[#rows + 1] = {
        { string.rep(" ", indent), "DotfilesDashboardLabel" },
        { item.icon, item.hl },
        { " " .. label, "DotfilesDashboardLabel" },
        { string.rep(" ", gap), "DotfilesDashboardLabel" },
        { "[", "DotfilesDashboardRule" },
        { item.key, "DotfilesDashboardKey" },
        { "]", "DotfilesDashboardRule" },
      }
    elseif block_width >= 3 then
      rows[#rows + 1] = {
        { item.icon, item.hl },
        { " ", "DotfilesDashboardLabel" },
        { item.key, "DotfilesDashboardKey" },
      }
    else
      rows[#rows + 1] = { { item.key, "DotfilesDashboardKey" } }
    end
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

  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)
  local block_width = math.min(BLOCK_WIDTH, width)
  local rows = {}
  if width >= BLOCK_WIDTH and height >= 15 then
    for i, line in ipairs(banner) do
      rows[#rows + 1] = { { line, "DotfilesDashboardBanner" .. i } }
    end
    rows[#rows + 1] = {}
    rows[#rows + 1] = subtitle(block_width)
    rows[#rows + 1] = { { string.rep("─", BLOCK_WIDTH), "DotfilesDashboardRule" } }
    rows[#rows + 1] = {}
    vim.list_extend(rows, menu_rows(block_width))
  else
    local logo = {
      { "N", "DotfilesDashboardBanner2" },
      { "V", "DotfilesDashboardBanner3" },
      { "I", "DotfilesDashboardBanner4" },
      { "M", "DotfilesDashboardBanner5" },
    }
    rows[#rows + 1] = vim.list_slice(logo, 1, math.min(#logo, block_width))
    if height <= 5 then
      if height == 2 then
        rows[#rows + 1] = compact_menu_row(block_width)
      elseif height == 3 then
        rows[#rows + 1] = subtitle(block_width)
        rows[#rows + 1] = compact_menu_row(block_width)
      elseif height >= 4 then
        rows[#rows + 1] = subtitle(block_width)
        rows[#rows + 1] = { { string.rep("─", block_width), "DotfilesDashboardRule" } }
        if height == 5 then
          rows[#rows + 1] = {}
        end
        rows[#rows + 1] = compact_menu_row(block_width)
      end
    else
      if height >= 7 then
        rows[#rows + 1] = subtitle(block_width)
      end
      if height >= 9 then
        rows[#rows + 1] = { { string.rep("─", block_width), "DotfilesDashboardRule" } }
      end
      if height >= 10 then
        rows[#rows + 1] = {}
      end
      vim.list_extend(rows, menu_rows(block_width))
    end
  end

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
