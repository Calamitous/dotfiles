-- Writing environment: Obsidian-compatible prose editing.
-- See: workshop vault, "2026-09-05 - Tooling Spec - Neovim as an
-- Obsidian-Compatible Writing Environment.md"

local M = {}

M.vault = require("writing.vault")
M.draft = require("writing.draft")

function M.setup()
  require("writing.abbrev").setup()
  require("writing.prose").setup()
  require("writing.html").setup()
  require("writing.wordcount").setup()
  require("writing.find").setup()
  require("writing.reading").setup()
  require("writing.sidebar").setup()

  vim.api.nvim_create_user_command("WritingHelp", function()
    local rows = {
      { "", "NAVIGATION" },
      { "<Leader>o", ":Files      fuzzy-find files in the vault" },
      { "<Leader>/", ":Grep       live-grep the vault contents" },
      { "<Leader>b", ":Buffers    switch buffer" },
      { "<Leader>e", ":Sidebar    file navigator (E = vault root)" },
      { "<Leader>,", ":Config     open this nvim config" },
      { "<Leader>r", ":Reload     reload the config in place" },
      { "", "" },
      { "", "WRITING" },
      { "<Leader>wr", ":Reading    centred fixed-width reading mode" },
      { "<Leader>wp", ":WP         prose mode (wrap, spell, gj/gk)" },
      { "<Leader>y", ":CopyHTML   copy buffer/selection as rich text" },
      { "<Leader>s", "z=          spelling suggestions" },
      { "zg", "            add word to this vault's dictionary" },
      { "]s / [s", "      next / previous misspelling" },
      { "", "" },
      { "", "COUNTS" },
      { "<Leader>wc", ":WordCount       this buffer" },
      { "<Leader>wd", ":WordCountDraft  the whole draft, by scene" },
      { "<Leader>wD", ":WordCountDir    a directory, per file" },
      { "", "" },
      { "", "VAULT" },
      { "<Leader>wv", ":VaultInfo     which vault/draft this buffer is in" },
      { "<Leader>wa", ":AbbrevEdit    edit this vault's abbreviations" },
      { "<Leader>wA", ":AbbrevReload  reload them after editing" },
      { "", "" },
      { "", "APPEARANCE" },
      { "", ":Italics       toggle real italics vs colour-only" },
    }

    local out = {}
    for _, row in ipairs(rows) do
      if row[1] == "" and row[2] == "" then
        table.insert(out, { "\n" })
      elseif row[1] == "" then
        table.insert(out, { row[2] .. "\n", "Title" })
      else
        table.insert(out, { string.format("  %-12s ", row[1]), "Identifier" })
        table.insert(out, { row[2] .. "\n" })
      end
    end
    vim.api.nvim_echo(out, false, {})
  end, { desc = "Show writing commands and keymaps" })

  vim.api.nvim_create_user_command("VaultInfo", function()
    local root = M.vault.root()
    if not root then
      vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
      return
    end
    local index = M.vault.draft()
    local lines = {
      "Vault:  " .. root,
      "Draft:  " .. (index and vim.fn.fnamemodify(index, ":~:.") or "(none above this buffer)"),
    }
    if index then
      local draft = M.draft.read(index)
      if draft then
        lines[#lines + 1] = "Title:  " .. (draft.title or "(untitled)")
        lines[#lines + 1] = "Scenes: " .. #draft.scenes
      end
    end
    vim.api.nvim_echo(vim.tbl_map(function(l) return { l .. "\n" } end, lines), false, {})
  end, { desc = "Show the vault and draft for this buffer" })
end

return M
