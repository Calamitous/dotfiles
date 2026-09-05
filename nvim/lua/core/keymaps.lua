-- Keymaps. Leader is space, matching ~/.vimrc.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

map("i", "kj", "<Esc>", { desc = "Leave insert mode" })

map("n", "<Leader>?", "<Cmd>WritingHelp<CR>", { desc = "Show writing commands" })

-- Fuzzy finding (vault-scoped)
map("n", "<Leader>o", "<Cmd>Files<CR>", { desc = "Find files in vault" })
map("n", "<Leader>/", "<Cmd>Grep<CR>", { desc = "Grep vault contents" })
map("n", "<Leader>b", "<Cmd>Buffers<CR>", { desc = "Switch buffer" })
map("n", "<Leader>e", "<Cmd>Sidebar<CR>", { desc = "File sidebar (here)" })
map("n", "<Leader>E", "<Cmd>SidebarVault<CR>", { desc = "File sidebar (vault root)" })
map("n", "<Leader>,", "<Cmd>Config<CR>", { desc = "Open nvim config" })
map("n", "<Leader>r", "<Cmd>Reload<CR>", { desc = "Reload nvim config" })

-- Writing
map("n", "<Leader>wc", "<Cmd>WordCount<CR>", { desc = "Word count (buffer)" })
map("n", "<Leader>wd", "<Cmd>WordCountDraft<CR>", { desc = "Word count (draft)" })
map("n", "<Leader>wD", "<Cmd>WordCountDir<CR>", { desc = "Word count (directory)" })
map("n", "<Leader>wp", "<Cmd>WP<CR>", { desc = "Toggle prose mode" })
map("n", "<Leader>wa", "<Cmd>AbbrevEdit<CR>", { desc = "Edit vault abbreviations" })
map("n", "<Leader>wA", "<Cmd>AbbrevReload<CR>", { desc = "Reload vault abbreviations" })
map("n", "<Leader>wv", "<Cmd>VaultInfo<CR>", { desc = "Vault info" })
map("n", "<Leader>wr", "<Cmd>Reading<CR>", { desc = "Toggle reading mode" })

-- Copy as rich text
map("n", "<Leader>y", "<Cmd>CopyHTML<CR>", { desc = "Copy buffer as HTML" })
map("v", "<Leader>y", ":CopyHTML<CR>", { desc = "Copy selection as HTML" })

-- Spelling
map("n", "<Leader>s", "z=", { desc = "Spelling suggestions" })

map("n", "<F2>", "z=", { desc = "Spelling suggestions" })
