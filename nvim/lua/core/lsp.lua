-- Language servers.
--
-- Only harper-ls is configured here; obsidian.nvim starts its own obsidian-ls
-- internally (see lua/plugins/obsidian.lua).
--
-- harper-ls shares the SAME dictionary `zg` writes, <vault>/Meta/dictionary.utf-8.add,
-- so a word added while writing is known to both the spell checker and the
-- grammar checker. One list, versioned with the book.

local M = {}

M.dictionary = "Meta/dictionary.utf-8.add"

--- Linters tuned for fiction rather than documentation. Prose breaks several
--- of harper's defaults on purpose: dialogue is full of fragments, and
--- sentence length is a stylistic choice.
M.linters = {
  SpellCheck = true,
  RepeatedWords = true,
  Spaces = true,
  AnA = true,
  CorrectNumberSuffix = true,
  UnclosedQuotes = true,
  SentenceCapitalization = false, -- dialogue fragments are not errors
  LongSentences = false, -- deliberate
  SpelledNumbers = false, -- style choice
  BoringWords = false, -- not its call
  Dashes = false, -- em/en dash use is deliberate
}

function M.setup()
  if vim.fn.executable("harper-ls") ~= 1 then
    return
  end

  vim.lsp.config("harper_ls", {
    cmd = { "harper-ls", "--stdio" },
    filetypes = { "markdown", "text" },
    root_markers = { ".obsidian", ".git" },
    settings = {
      ["harper-ls"] = {
        linters = M.linters,
        dialect = "American",
        -- Quiet by default: suggestions, not errors. Prose isn't broken code.
        diagnosticSeverity = "hint",
        markdown = { IgnoreLinkTitle = true },
        codeActions = { ForceStable = true },
      },
    },
  })

  vim.lsp.enable("harper_ls")

  -- Point harper at this vault's dictionary once the client knows its root.
  -- Doing it in before_init doesn't work -- root_dir isn't resolved yet.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("HarperDictionary", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "harper_ls" or not client.root_dir then
        return
      end

      local path = client.root_dir .. "/" .. M.dictionary
      if vim.tbl_get(client.settings, "harper-ls", "userDictPath") == path then
        return
      end

      client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
        ["harper-ls"] = { userDictPath = path },
      })
      client:notify("workspace/didChangeConfiguration", { settings = client.settings })
    end,
  })

  -- Diagnostics: unobtrusive while drafting.
  vim.diagnostic.config({
    virtual_text = false,
    underline = true,
    signs = true,
    severity_sort = true,
    float = { border = "rounded", source = true },
  })
end

return M
