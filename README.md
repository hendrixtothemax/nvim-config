# 💤 LazyVim

A starter template for LazyVim.

Refer to the official documentation:
[https://lazyvim.github.io/installation](https://lazyvim.github.io/installation)

---

## ✨ Customizations

This configuration includes a small set of personal keybindings to improve window navigation.

---

## 🪟 Window Navigation

Added leader-based window movement using `hjkl`:

```lua
vim.keymap.set("n", "<leader>h", "<C-w>h")
vim.keymap.set("n", "<leader>j", "<C-w>j")
vim.keymap.set("n", "<leader>k", "<C-w>k")
vim.keymap.set("n", "<leader>l", "<C-w>l")
```

---

🪟 Bottom Terminal Toggle

A single keybinding is used to toggle a horizontal terminal at the bottom of the screen.

Key	Action
<leader>ts	Toggle bottom terminal Bottom Terminal Toggle

A single keybinding is used to toggle a horizontal terminal at the bottom of the screen.

Key	Action
<leader>ts	Toggle bottom terminal
