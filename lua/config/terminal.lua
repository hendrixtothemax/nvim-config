local Terminal = require("toggleterm.terminal").Terminal

local terminals = {}

local function get_terminal(name, cmd)
  if terminals[name] == nil then
    terminals[name] = Terminal:new({
      cmd = cmd,
      hidden = true,
      direction = "horizontal",
      size = 12,
    })
  end

  return terminals[name]
end

-- Keymap to create new terminal
vim.keymap.set("n", "<leader>ts", function()
  get_terminal("shell", "zsh"):toggle()
end, { desc = "Shell" })
