-- lua/config/terminal.lua
-- Terminal manager: up to 5 windows, multiple panes, persistent

local Terminal = require("toggleterm.terminal").Terminal

local M = {}

-- =========================
-- Constants
-- =========================
local MAX_WINDOWS = 5
local PERSIST_FILE = vim.fn.stdpath("data") .. "/terminal_state.json"

-- =========================
-- State
-- =========================
-- windows[i] = { name: string, panes: [{ term_id, direction }], active_pane: int }
local state = {
  windows = {},
  active = 0,
  sidebar_buf = nil,
  sidebar_win = nil,
}

-- All Terminal objects, keyed by a monotonic term_id
local terms = {}
local next_term_id = 1

-- =========================
-- Forward declarations
-- =========================
local prune_empty_windows
local refresh_sidebar
local save_state

-- =========================
-- Pane cleanup (called by on_exit)
-- =========================
local function remove_pane_by_term_id(term_id)
  for i = 1, MAX_WINDOWS do
    local w = state.windows[i]
    if w then
      for j, p in ipairs(w.panes) do
        if p.term_id == term_id then
          terms[term_id] = nil
          table.remove(w.panes, j)
          w.active_pane = math.max(1, math.min(w.active_pane, #w.panes))
          prune_empty_windows()
          save_state()
          vim.schedule(refresh_sidebar)
          return
        end
      end
    end
  end
end

-- =========================
-- Terminal factory
-- =========================
local function make_terminal(direction)
  local id = next_term_id
  next_term_id = next_term_id + 1

  local t = Terminal:new({
    cmd = vim.o.shell,
    hidden = true,
    direction = direction or "horizontal",
    size = function(term)
      if term.direction == "vertical" then
        return math.floor(vim.o.columns * 0.4)
      elseif term.direction == "horizontal" then
        return 12
      end
    end,

    on_exit = function(_t, _job, _code, _name)
      vim.schedule(function()
        remove_pane_by_term_id(id)
      end)
    end,
  })

  terms[id] = t
  return id
end

local function get_term(id)
  return terms[id]
end

-- =========================
-- Persistence
-- =========================
save_state = function()
  local data = { active = state.active, windows = {} }

  for i = 1, MAX_WINDOWS do
    local w = state.windows[i]
    if w then
      local panes = {}
      for _, p in ipairs(w.panes) do
        table.insert(panes, { direction = p.direction })
      end
      data.windows[tostring(i)] = {
        name = w.name,
        active_pane = w.active_pane,
        panes = panes,
      }
    end
  end

  local ok, encoded = pcall(vim.fn.json_encode, data)
  if not ok then
    return
  end

  local f = io.open(PERSIST_FILE, "w")
  if f then
    f:write(encoded)
    f:close()
  end
end

local function load_state()
  local f = io.open(PERSIST_FILE, "r")
  if not f then
    return
  end

  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    return
  end

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or type(data) ~= "table" then
    return
  end

  state.active = tonumber(data.active) or 0

  for key, w in pairs(data.windows or {}) do
    local idx = tonumber(key)
    if idx and idx >= 1 and idx <= MAX_WINDOWS then
      local panes = {}
      for i, p in ipairs(w.panes or {}) do
        -- first pane is always horizontal, subsequent panes are vertical
        local default_dir = i == 1 and "horizontal" or "vertical"
        local dir = p.direction or default_dir
        local id = make_terminal(dir)
        table.insert(panes, { term_id = id, direction = dir })
      end

      if #panes > 0 then
        state.windows[idx] = {
          name = w.name or ("Window " .. idx),
          panes = panes,
          active_pane = tonumber(w.active_pane) or 1,
        }
      end
    end
  end

  if state.active ~= 0 and not state.windows[state.active] then
    state.active = 0
    for i = 1, MAX_WINDOWS do
      if state.windows[i] then
        state.active = i
        break
      end
    end
  end
end

-- =========================
-- Window helpers
-- =========================
local function count_windows()
  local n = 0
  for i = 1, MAX_WINDOWS do
    if state.windows[i] then
      n = n + 1
    end
  end
  return n
end

local function next_free_slot()
  for i = 1, MAX_WINDOWS do
    if not state.windows[i] then
      return i
    end
  end
  return nil
end

prune_empty_windows = function()
  for i = 1, MAX_WINDOWS do
    local w = state.windows[i]
    if w and #w.panes == 0 then
      state.windows[i] = nil
    end
  end

  if state.active ~= 0 and not state.windows[state.active] then
    state.active = 0
    for i = 1, MAX_WINDOWS do
      if state.windows[i] then
        state.active = i
        break
      end
    end
  end
end

local function close_all_panes(win_idx)
  local w = state.windows[win_idx]
  if not w then
    return
  end
  for _, p in ipairs(w.panes) do
    local t = get_term(p.term_id)
    if t and t:is_open() then
      t:close()
    end
  end
end

local function open_all_panes(win_idx)
  local w = state.windows[win_idx]
  if not w then
    return
  end
  for _, p in ipairs(w.panes) do
    local t = get_term(p.term_id)
    if t then
      t:open()
    end
  end
end

-- =========================
-- Sidebar
-- =========================
local function sidebar_lines()
  local lines = {
    "  Terminal Windows",
    "  ─────────────────",
    "",
  }

  for i = 1, MAX_WINDOWS do
    local w = state.windows[i]
    if w then
      local marker = (i == state.active) and "▶" or " "
      local pane_str = #w.panes == 1 and "1 pane" or (#w.panes .. " panes")
      table.insert(
        lines,
        string.format("  %s [%d] %s  (%s)", marker, i, w.name, pane_str)
      )
    else
      table.insert(lines, string.format("    [%d] empty", i))
    end
  end

  vim.list_extend(lines, {
    "",
    "  ─────────────────",
    "  <leader>ts  toggle",
    "  <leader>ta  new window",
    "  <leader>tw  cycle windows",
    "  <leader>tp  new pane",
    "  <leader>tc  cycle panes",
    "  <leader>tx  close pane",
    "  <leader>tb  sidebar",
  })

  return lines
end

refresh_sidebar = function()
  if not (state.sidebar_win and vim.api.nvim_win_is_valid(state.sidebar_win)) then
    return
  end

  local lines = sidebar_lines()
  vim.api.nvim_buf_set_option(state.sidebar_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.sidebar_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.sidebar_buf, "modifiable", false)
end

local function open_sidebar()
  if state.sidebar_win and vim.api.nvim_win_is_valid(state.sidebar_win) then
    refresh_sidebar()
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  state.sidebar_buf = buf

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "terminal_sidebar")

  local lines = sidebar_lines()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = 32
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local col = vim.o.columns - width - 2

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = 1,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Terminals ",
    title_pos = "center",
  })

  state.sidebar_win = win
  vim.api.nvim_win_set_option(win, "winhl", "Normal:NormalFloat")
end

local function close_sidebar()
  if state.sidebar_win and vim.api.nvim_win_is_valid(state.sidebar_win) then
    vim.api.nvim_win_close(state.sidebar_win, true)
    state.sidebar_win = nil
    state.sidebar_buf = nil
  end
end

function M.toggle_sidebar()
  if state.sidebar_win and vim.api.nvim_win_is_valid(state.sidebar_win) then
    close_sidebar()
  else
    open_sidebar()
  end
end

-- =========================
-- Actions
-- =========================

function M.toggle()
  if state.active == 0 then
    M.new_window()
    return
  end

  local w = state.windows[state.active]
  if not w then
    M.new_window()
    return
  end

  local any_open = false
  for _, p in ipairs(w.panes) do
    local t = get_term(p.term_id)
    if t and t:is_open() then
      any_open = true
      break
    end
  end

  if any_open then
    close_all_panes(state.active)
  else
    open_all_panes(state.active)
  end

  refresh_sidebar()
end

function M.new_window()
  if count_windows() >= MAX_WINDOWS then
    vim.notify(
      "Terminal limit reached (" .. MAX_WINDOWS .. " windows max)",
      vim.log.levels.WARN
    )
    return
  end

  local slot = next_free_slot()
  if not slot then
    return
  end

  if state.active ~= 0 and state.windows[state.active] then
    close_all_panes(state.active)
  end

  -- first pane in a window is always horizontal (bottom band)
  local id = make_terminal("horizontal")
  state.windows[slot] = {
    name = "Window " .. slot,
    panes = { { term_id = id, direction = "horizontal" } },
    active_pane = 1,
  }
  state.active = slot

  local t = get_term(id)
  if t then
    t:open()
  end

  save_state()
  refresh_sidebar()
end

function M.new_pane()
  if state.active == 0 then
    vim.notify("No active terminal window", vim.log.levels.WARN)
    return
  end

  local w = state.windows[state.active]
  if not w then
    return
  end

  -- subsequent panes split vertically (side by side)
  local id = make_terminal("vertical")
  table.insert(w.panes, { term_id = id, direction = "vertical" })
  w.active_pane = #w.panes

  local t = get_term(id)
  if t then
    t:open()
  end

  save_state()
  refresh_sidebar()
end

function M.cycle_windows()
  local count = count_windows()

  if count == 0 then
    vim.notify("No terminal windows", vim.log.levels.WARN)
    return
  end

  if count == 1 then
    M.toggle()
    return
  end

  if state.active ~= 0 then
    close_all_panes(state.active)
  end

  local start = state.active == 0 and 0 or state.active
  local next_idx = (start % MAX_WINDOWS) + 1

  for _ = 1, MAX_WINDOWS do
    if state.windows[next_idx] then
      break
    end
    next_idx = (next_idx % MAX_WINDOWS) + 1
  end

  state.active = next_idx
  open_all_panes(state.active)
  refresh_sidebar()
end

function M.cycle_panes()
  if state.active == 0 then
    return
  end

  local w = state.windows[state.active]
  if not w or #w.panes <= 1 then
    return
  end

  w.active_pane = (w.active_pane % #w.panes) + 1

  vim.cmd("wincmd w")
  refresh_sidebar()
end

function M.close_pane()
  if state.active == 0 then
    return
  end

  local w = state.windows[state.active]
  if not w then
    return
  end

  local idx = w.active_pane
  local p = w.panes[idx]
  if not p then
    return
  end

  local t = get_term(p.term_id)
  if t and t:is_open() then
    t:close()
  end

  -- on_exit handles cleanup for open terminals via remove_pane_by_term_id;
  -- if the terminal was never opened, clean up manually
  if not t then
    terms[p.term_id] = nil
    table.remove(w.panes, idx)
    w.active_pane = math.max(1, math.min(w.active_pane, #w.panes))
    prune_empty_windows()
    save_state()
    refresh_sidebar()
  end
end

-- =========================
-- Statusline component
-- =========================
function M.statusline()
  if state.active == 0 or count_windows() == 0 then
    return ""
  end

  local parts = {}
  for i = 1, MAX_WINDOWS do
    if state.windows[i] then
      if i == state.active then
        table.insert(parts, "[" .. i .. "]")
      else
        table.insert(parts, " " .. i .. " ")
      end
    end
  end

  return table.concat(parts, " ")
end

-- =========================
-- Setup
-- =========================
function M.setup_keymaps()
  local function map(mode, lhs, fn, desc)
    vim.keymap.set(mode, lhs, fn, { noremap = true, silent = true, desc = desc })
  end

  map("n", "<leader>ts", M.toggle, "Toggle terminal")
  map("n", "<leader>tb", M.toggle_sidebar, "Toggle terminal sidebar")
  map("n", "<leader>ta", M.new_window, "New terminal window")
  map("n", "<leader>tw", M.cycle_windows, "Cycle terminal windows")
  map("n", "<leader>tp", M.new_pane, "New terminal pane")
  map("n", "<leader>tc", M.cycle_panes, "Cycle terminal panes")
  map("n", "<leader>tx", M.close_pane, "Close terminal pane")

  map("t", "<Esc>", [[<C-\><C-n>]], "Exit terminal mode")
end

function M.setup()
  load_state()

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("TerminalPersist", { clear = true }),
    callback = save_state,
  })

  if state.active ~= 0 and state.windows[state.active] then
    vim.schedule(function()
      open_all_panes(state.active)
      refresh_sidebar()
    end)
  end

  M.setup_keymaps()
end

return M