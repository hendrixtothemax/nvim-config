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

## 🧠 Notes

These mappings are intended to reduce friction when moving between splits and make navigation more consistent with Vim movement keys.
