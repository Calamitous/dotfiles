-- Keymaps. Leader is space, matching ~/.vimrc.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

map("i", "kj", "<Esc>", { desc = "Leave insert mode" })

map("n", "<Leader>?", "<Cmd>WritingHelp<CR>", { desc = "Show writing commands" })
map("n", "<F2>", "<Cmd>ObsidianRename<CR>", { desc = "Rename the file, updating all wikilinks references to it." })

-- Fuzzy finding (vault-scoped)
map("n", "<Leader>o", "<Cmd>Files<CR>", { desc = "Find files in vault" })

map("n", "<F8>", "<Cmd>Grep<CR>", { desc = "Grep vault contents" })
map("n", "<Leader>/", "<Cmd>Grep<CR>", { desc = "Grep vault contents" })

map("n", "<Leader>b", "<Cmd>Buffers<CR>", { desc = "Switch buffer" })

map("n", "<Leader>e", "<Cmd>Sidebar<CR>", { desc = "File sidebar (here)" })
map("n", "<F4>", "<Cmd>Sidebar<CR>", { desc = "File sidebar (here)" })

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

-- Wikilinks (obsidian.nvim). These need a markdown buffer in a vault -- the
-- plugin loads on `ft = "markdown"`.
--
-- Other subcommands available to bind:
--   search  tags  links  footnotes  template  new_from_template  workspace
--   bookmarks  paste_img  unique_note  today  tomorrow  yesterday  dailies
--   open  (opens the note in the Obsidian app)  rebuild_cache  check
map("n", "<Leader>kr", "<Cmd>Obsidian rename<CR>", { desc = "Rename note + rewrite links" })
map("n", "<Leader>kf", "<Cmd>Obsidian follow_link<CR>", { desc = "Follow wikilink" })
map("n", "<Leader>kb", "<Cmd>Obsidian backlinks<CR>", { desc = "Backlinks" })
map("n", "<Leader>ks", "<Cmd>Obsidian quick_switch<CR>", { desc = "Quick switch note" })
map("n", "<Leader>kn", "<Cmd>Obsidian new<CR>", { desc = "New note" })
map("n", "<Leader>kt", "<Cmd>Obsidian toc<CR>", { desc = "Table of contents" })
map("n", "<Leader>kl", "<Cmd>Obsidian links<CR>", { desc = "Links in this note" })
map("n", "<Leader>kg", "<Cmd>Obsidian search<CR>", { desc = "Search notes (grep)" })
map("n", "<Leader>k#", "<Cmd>Obsidian tags<CR>", { desc = "Tags" })
map("n", "<Leader>ko", "<Cmd>Obsidian open<CR>", { desc = "Open in Obsidian app" })

-- Checkboxes
map("n", "<Leader>l", "<Cmd>CheckboxToggle<CR>", { desc = "Toggle checkbox" })
map("v", "<Leader>l", ":CheckboxToggle<CR>", { desc = "Toggle checkboxes" })

map("n", "<F2>", "z=", { desc = "Spelling suggestions" })
