local Terminal = require("toggleterm.terminal").Terminal

local M = {}

-- =========================
-- State
-- =========================
local state = {
  terminals = {}, -- indexed terminals
  active = 0, -- current terminal index
  visible = false, -- are terminals shown
  max = 5,
}

-- =========================
-- UI: window bar
-- =========================
local function render_bar()
  if not state.visible or state.active == 0 then
    return ""
  end

  local parts = {}

  for i = 1, state.max do
    if i == state.active then
      table.insert(parts, "[" .. i .. "]")
    elseif state.terminals[i] then
      table.insert(parts, " " .. i .. " ")
    end
  end

  return table.concat(parts, " ")
end

function M.statusline()
  return render_bar()
end

-- =========================
-- Terminal helpers
-- =========================
local function create_terminal(index)
  state.terminals[index] = Terminal:new({
    cmd = "zsh",
    hidden = true,
    direction = "horizontal",
    size = 12,

    on_open = function()
      state.visible = true
      state.active = index
    end,

    on_close = function()
      -- if last terminal closes, hide bar
      vim.schedule(function()
        local any_open = false
        for _, t in pairs(state.terminals) do
          if t and t:is_open() then
            any_open = true
            break
          end
        end
        state.visible = any_open
        if not any_open then
          state.active = 0
        end
      end)
    end,
  })
end

local function ensure_terminal(index)
  if index > state.max then
    return
  end
  if not state.terminals[index] then
    create_terminal(index)
  end
  return state.terminals[index]
end

-- =========================
-- Actions
-- =========================

-- Toggle current terminal
function M.toggle()
  if state.active == 0 then
    state.active = 1
  end

  local term = ensure_terminal(state.active)
  if term then
    term:toggle()
  end
end

-- Create new terminal (ta)
function M.new_terminal()
  local next_index = state.active + 1

  if next_index > state.max then
    next_index = 1
  end

  state.active = next_index

  local term = ensure_terminal(state.active)
  if term then
    term:toggle()
  end
end

-- Cycle terminals (tw)
function M.cycle()
  if state.active == 0 then
    return
  end

  local current = state.terminals[state.active]
  if current then
    current:toggle()
  end

  -- find next existing terminal
  local next_index = state.active + 1

  for _ = 1, state.max do
    if next_index > state.max then
      next_index = 1
    end

    if state.terminals[next_index] then
      break
    end

    next_index = next_index + 1
  end

  state.active = next_index

  local next_term = ensure_terminal(state.active)
  if next_term then
    next_term:toggle()
  end
end

-- =========================
-- Keymaps
-- =========================
function M.setup_keymaps()
  vim.keymap.set("n", "<leader>ts", M.toggle, { desc = "Toggle terminal" })
  vim.keymap.set("n", "<leader>ta", M.new_terminal, { desc = "New terminal" })
  vim.keymap.set("n", "<leader>tw", M.cycle, { desc = "Cycle terminals" })

  vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })
end

return M
