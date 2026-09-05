-- obsidian.nvim -- wikilinks, and the rename that rewrites them.
--
-- This is the one feature not worth hand-rolling: renaming has to correctly
-- rewrite [[Note]], [[Note|alias]], [[Note#heading]], [[Note#^block]] and
-- ![[Note]] embeds across the whole vault.
--
-- LOAD-BEARING for Obsidian compatibility:
--
--   frontmatter.enabled = false
--     Otherwise obsidian.nvim rewrites a note's frontmatter on save (adding
--     id/aliases/tags). On a Longform `Index.md` that would fight the
--     `longform:` block, which is the one file both tools must agree on.
--
--   ui.enable = false
--     render-markdown.nvim owns concealment and rendering. Running both puts
--     two sets of virtual text on the same line.
--
-- Completion comes from the plugin's built-in obsidian-ls LSP server, so no
-- separate completion engine is needed; see the LspAttach autocmd below.
--
-- Keymaps live in lua/core/keymaps.lua, not in a lazy `keys = {}` table here.
-- Lazy-loading is already handled by `ft = "markdown"`, so nothing is lost by
-- keeping every mapping in one editable place.

--- Every vault under ~/Writing becomes a workspace, discovered rather than
--- hardcoded -- there are fifteen and the list changes.
local function workspaces()
  local root = vim.fn.expand("~/Writing")
  local found = {}

  for name, type in vim.fs.dir(root) do
    if type == "directory" and vim.uv.fs_stat(root .. "/" .. name .. "/.obsidian") then
      table.insert(found, { name = name, path = root .. "/" .. name })
    end
  end

  table.sort(found, function(a, b)
    return a.name < b.name
  end)
  return found
end

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = function()
    return {
      workspaces = workspaces(),
      legacy_commands = false,
      frontmatter = { enabled = false },
      ui = { enable = false },
      -- Human-readable filenames; these are chapters, not zettels.
      note_id_func = function(title)
        return title
      end,
    }
  end,
  config = function(_, opts)
    require("obsidian").setup(opts)

    -- Turn on neovim's built-in completion for obsidian-ls, so `[[` offers
    -- note titles without a third-party completion engine.
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("ObsidianCompletion", { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "obsidian-ls" and client:supports_method("textDocument/completion") then
          vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
        end
      end,
    })
  end,
}
