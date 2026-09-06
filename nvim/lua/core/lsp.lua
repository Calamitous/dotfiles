-- Language servers.
--
-- Only harper-ls is configured here; obsidian.nvim starts its own obsidian-ls
-- internally (see lua/plugins/obsidian.lua).
--
-- harper-ls shares the SAME dictionary `zg` writes, <vault>/.scriptorium/dictionary.utf-8.add,
-- so a word added while writing is known to both the spell checker and the
-- grammar checker. One list, versioned with the book.

local M = {}

M.dictionary = require("writing.vault").support .. "/dictionary.utf-8.add"

--- Start with grammar checking on? Set false to draft undisturbed and turn it
--- on when you revise; `:Harper` toggles it either way.
M.enabled_by_default = true

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

  vim.api.nvim_create_user_command("Harper", function()
    M.toggle()
  end, { desc = "Toggle harper grammar checking" })

  vim.api.nvim_create_user_command("HarperIgnore", M.ignore, { desc = "Ignore the suggestion under the cursor" })
  vim.api.nvim_create_user_command("HarperRefresh", M.refresh, { desc = "Make harper re-read the dictionary" })

  -- Spell-list changes must be pushed to harper, which caches the file.
  for _, key in ipairs({ "zg", "zG", "zw", "zW", "zug", "zuw" }) do
    vim.keymap.set("n", key, function()
      vim.cmd("normal! " .. key)
      M.refresh()
    end, { desc = "Spell list (refreshes Harper)" })
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

  -- Diagnostics: quiet, but the reason for the one under the cursor is shown
  -- without having to ask. `virtual_lines.current_line` renders only the
  -- current line's message, so the page isn't littered with them.
  vim.diagnostic.config({
    virtual_text = false,
    virtual_lines = { current_line = true },
    underline = true,
    signs = true,
    severity_sort = true,
    float = { border = "rounded", source = true },
  })

  if not M.enabled_by_default then
    vim.schedule(function()
      M.enable(false)
    end)
  end
end

--- Harper's diagnostic namespaces (one per client).
local function namespaces()
  local out = {}
  for _, client in ipairs(vim.lsp.get_clients({ name = "harper_ls" })) do
    table.insert(out, vim.lsp.diagnostic.get_namespace(client.id))
  end
  return out
end

--- Turn harper's diagnostics on or off, leaving every other source alone.
function M.enable(on)
  local ns = namespaces()
  if #ns == 0 then
    vim.notify("harper-ls isn't running here", vim.log.levels.WARN)
    return
  end
  for _, id in ipairs(ns) do
    vim.diagnostic.enable(on, { ns_id = id })
  end
  M.on = on
end

--- Tell harper to re-read its dictionary.
---
--- `zg` writes to the spellfile, which is also harper's userDictPath -- but
--- harper caches it, so a word added while writing stayed flagged until nvim
--- was restarted. A didChangeConfiguration notification makes it re-read.
function M.refresh()
  for _, client in ipairs(vim.lsp.get_clients({ name = "harper_ls" })) do
    client:notify("workspace/didChangeConfiguration", { settings = client.settings })
  end
end

--- Ignore the harper suggestion under the cursor, via harper's own code
--- action -- the same "Ignore Harper error" you'd get from <Leader>a.
---
--- Note this silences harper only. An unknown word is underlined by TWO
--- independent things -- harper's diagnostic and vim's own spell checker --
--- so a proper noun wants `zg`, which teaches both, rather than this.
function M.ignore()
  local word = vim.fn.expand("<cword>")

  vim.lsp.buf.code_action({
    filter = function(a)
      return a.title and a.title:lower():find("ignore") ~= nil
    end,
    apply = true,
  })

  -- If the word is also unknown to vim's spell checker, the underline stays
  -- after this and looks like the ignore failed. Say so.
  vim.defer_fn(function()
    if word ~= "" and vim.wo.spell and vim.fn.spellbadword(word)[2] ~= "" then
      vim.notify(
        string.format("Harper ignored, but '%s' is still flagged by spell check - use zg to add it", word),
        vim.log.levels.WARN
      )
    end
  end, 800)
  -- Mirror it into the vault straight away, so it survives even if nvim is
  -- killed rather than exited.
  vim.defer_fn(function()
    pcall(function()
      require("writing.harper_sync").export()
    end)
  end, 1500)
end

--- Add the word under the cursor to this vault's dictionary, teaching both
--- vim's spell checker and harper in one keystroke.
function M.add_word()
  vim.cmd("normal! zg")
  M.refresh()
  vim.notify("Added to " .. vim.fs.basename(vim.bo.spellfile ~= "" and vim.bo.spellfile or "dictionary"))
end

function M.toggle()
  if M.on == nil then
    M.on = true
  end
  M.enable(not M.on)
  vim.notify("Harper " .. (M.on and "on" or "off"))
end

return M
