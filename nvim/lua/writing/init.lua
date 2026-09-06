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
  require("writing.checkbox").setup()
  require("writing.compile").setup()
  require("writing.vale").setup()
  require("writing.harper_sync").setup()
  require("writing.help").setup()

  -- One switch for every checker, for a single key like <F3>.
  -- If either is on, both go off; otherwise both come on -- so they can't
  -- drift out of step.
  vim.api.nvim_create_user_command("Checks", function()
    local prose = require("writing.prose")
    local lsp = require("core.lsp")

    local harper_on = lsp.on
    if harper_on == nil then
      harper_on = lsp.enabled_by_default
    end
    local spell_on = vim.wo.spell
    local turning_on = not (harper_on or spell_on)

    prose.set_spell(turning_on)
    pcall(function()
      lsp.enable(turning_on)
    end)
    vim.notify("Checks " .. (turning_on and "on" or "off") .. " (spell + harper)")
  end, { desc = "Toggle spell check and grammar together" })

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
