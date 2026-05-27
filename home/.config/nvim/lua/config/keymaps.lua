-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- ─── macOS-style word motion (Option + Left/Right) ───────────────────────
map({ "n", "v" }, "<M-Right>", "e", { desc = "Move to end of word" })
map("i", "<M-Right>", "<C-o>e", { desc = "Move to end of word" })
map({ "n", "v" }, "<M-Left>", "b", { desc = "Move to start of word" })
map("i", "<M-Left>", "<C-o>b", { desc = "Move to start of word" })
map("v", "<S-M-Right>", "e", { desc = "Extend selection to end of word" })
map("v", "<S-M-Left>", "b", { desc = "Extend selection to start of word" })

-- ─── macOS-style line motion (Cmd + Left/Right) ──────────────────────────
map({ "n", "v" }, "<D-Left>", "^", { desc = "Move to first non-blank of line" })
map("i", "<D-Left>", "<C-o>^", { desc = "Move to first non-blank of line" })
map({ "n", "v" }, "<D-Right>", "$", { desc = "Move to end of line" })
map("i", "<D-Right>", "<C-o>$", { desc = "Move to end of line" })

-- Cmd+Shift+Left/Right: select to line boundaries
map("n", "<S-D-Left>", "v0", { desc = "Select to start of line" })
map("n", "<S-D-Right>", "v$", { desc = "Select to end of line" })
map("v", "<S-D-Left>", "0", { desc = "Extend selection to start of line" })
map("v", "<S-D-Right>", "$", { desc = "Extend selection to end of line" })
map("i", "<S-D-Left>", "<C-o>v0", { desc = "Select to start of line" })
map("i", "<S-D-Right>", "<C-o>v$", { desc = "Select to end of line" })

-- ─── Home / End (and Shift variants) ─────────────────────────────────────
map({ "n", "v" }, "<Home>", "^")
map("i", "<Home>", "<C-o>^")
map({ "n", "v" }, "<End>", "$")
map("i", "<End>", "<C-o>$")

map("n", "<S-Home>", "v0")
map("n", "<S-End>", "v$")
map("v", "<S-Home>", "0")
map("v", "<S-End>", "$")
map("i", "<S-Home>", "<C-o>v0")
map("i", "<S-End>", "<C-o>v$")

-- ─── Modern selection feel ───────────────────────────────────────────────
-- Backspace deletes selection in visual mode
map("v", "<BS>", "d", { desc = "Delete visual selection" })
