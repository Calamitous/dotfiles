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
map("n", "<F10>",     "<Cmd>CopyHTML<CR>", { desc = "Copy buffer as HTML" })
map("v", "<Leader>y", ":CopyHTML<CR>",     { desc = "Copy selection as HTML" })
map("v", "<F10>",     ":CopyHTML<CR>",     { desc = "Copy selection as HTML" })

-- Spelling
map("n", "<Leader>s", "z=", { desc = "Spelling suggestions" })

-- Wikilinks (obsidian.nvim). These need a markdown buffer in a vault -- the
-- plugin loads on `ft = "markdown"`.
--
-- Other subcommands available to bind:
--   search  tags  links  footnotes  template  new_from_template  workspace
--   bookmarks  paste_img  unique_note  today  tomorrow  yesterday  dailies
--   open  (opens the note in the Obsidian app)  rebuild_cache  check
-- Manual completion trigger. Autotrigger only fires on the server's trigger
-- characters ("[", "#", "^"), so typing `[[` requests with an empty query and
-- the letters you type after it don't re-request. <C-Space> asks explicitly.
map("i", "<C-Space>", function()
  if vim.lsp.completion and next(vim.lsp.get_clients({ bufnr = 0 })) then
    vim.lsp.completion.get()
  else
    return "<C-x><C-o>"
  end
end, { expr = false, desc = "Trigger completion" })

-- `gf` on a wikilink. Without this it falls through to vim's native file
-- lookup, which builds its target from <cfile> -- and since 'isfname' has no
-- space, that truncates [[Fortney Nurani, Princess]] to "Fortney" and fails.
-- It only appeared to work for links whose first word was already unique.
-- Outside markdown, plain gf is untouched.
map("n", "gf", function()
  if vim.bo.filetype == "markdown" and vim.fn.exists(":Obsidian") == 2 then
    vim.cmd("Obsidian follow_link")
  else
    vim.cmd("normal! gf")
  end
end, { desc = "Follow wikilink / file under cursor" })

map("n", "<Leader>kr", "<Cmd>Obsidian rename<CR>", { desc = "Rename note + rewrite links" })
map("n", "<F2>", "<Cmd>Obsidian rename<CR>", { desc = "Rename note + rewrite links" })

map("n", "<Leader>kf", "<Cmd>Obsidian follow_link<CR>", { desc = "Follow wikilink" })
map("n", "<Leader>kb", "<Cmd>Obsidian backlinks<CR>", { desc = "Backlinks" })
map("n", "<Leader>ks", "<Cmd>Obsidian quick_switch<CR>", { desc = "Quick switch note" })
map("n", "<Leader>kn", "<Cmd>Obsidian new<CR>", { desc = "New note" })
map("n", "<Leader>kt", "<Cmd>Obsidian toc<CR>", { desc = "Table of contents" })
map("n", "<Leader>kl", "<Cmd>Obsidian links<CR>", { desc = "Links in this note" })
map("n", "<Leader>kg", "<Cmd>Obsidian search<CR>", { desc = "Search notes (grep)" })
map("n", "<Leader>k#", "<Cmd>Obsidian tags<CR>", { desc = "Tags" })
map("n", "<Leader>ko", "<Cmd>Obsidian open<CR>", { desc = "Open in Obsidian app" })

-- Diagnostics (harper grammar)
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "<Leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic" })
map("n", "<Leader>a", vim.lsp.buf.code_action, { desc = "Code action (accept fix)" })

map("n", "<F3>", "<Cmd>Harper<CR>", { desc = "Toggle grammar checking" })
map("n", "<Leader>h", "<Cmd>Harper<CR>", { desc = "Toggle grammar checking" })
map("n", "<Leader>x", "<Cmd>HarperIgnore<CR>", { desc = "Ignore this suggestion" })

-- Prose linting (Vale)
map("n", "<Leader>vv", "<Cmd>Vale<CR>", { desc = "Lint this file" })
map("n", "<Leader>vd", "<Cmd>ValeDraft<CR>", { desc = "Lint the whole draft" })
map("n", "]q", "<Cmd>cnext<CR>", { desc = "Next quickfix entry" })
map("n", "[q", "<Cmd>cprevious<CR>", { desc = "Previous quickfix entry" })

-- Manuscript
map("n", "<Leader>mc", "<Cmd>Compile<CR>", { desc = "Compile manuscript" })
map("n", "<Leader>mk", "<Cmd>CompileCheck<CR>", { desc = "Compile check (diff only)" })
map("n", "<Leader>ml", "<Cmd>CompileList<CR>", { desc = "List drafts" })

-- Checkboxes
map("n", "<Leader>l", "<Cmd>CheckboxToggle<CR>", { desc = "Toggle checkbox" })
map("v", "<Leader>l", ":CheckboxToggle<CR>", { desc = "Toggle checkboxes" })
