-- Statusline, with a live word count for prose.
--
-- obsidian.nvim renders its own counts as greyed virtual text at the end of the
-- file (`{{backlinks}} backlinks  {{properties}} properties  ...`). That's
-- turned off in lua/plugins/obsidian.lua; a count belongs in the statusline,
-- not appended to the prose.
--
-- The count is the same one :WordCount reports -- frontmatter, %%comments%% and
-- wikilink syntax excluded -- so the number here matches the number the
-- compiler and the draft totals give.

local M = {}

--- Recount at most this often, in ms. A statusline is redrawn constantly; the
--- count is cached per buffer and refreshed on a debounce instead.
M.debounce_ms = 400

local pending = {}

local function countable(bufnr)
  return vim.bo[bufnr].filetype == "markdown"
    and vim.bo[bufnr].buftype == ""
    and require("writing.vault").root(bufnr) ~= nil
end

local function recount(bufnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) or not countable(bufnr) then
    return
  end
  local wc = require("writing.wordcount")
  vim.b[bufnr].scriptorium_words = wc.commas(wc.count_buffer(bufnr))
  vim.cmd("redrawstatus")
end

local function schedule(bufnr)
  if pending[bufnr] then
    return
  end
  pending[bufnr] = true
  vim.defer_fn(function()
    pending[bufnr] = nil
    recount(bufnr)
  end, M.debounce_ms)
end

--- The word-count segment, or "" where a count would be meaningless.
function M.words()
  local words = vim.b.scriptorium_words
  return words and (words .. " words  ") or ""
end

--- Which vault this buffer belongs to, for a multi-vault session.
function M.vault()
  local root = require("writing.vault").root()
  return root and (vim.fs.basename(root) .. "  ") or ""
end

function M.setup()
  -- One statusline for the whole window, not one per split: with reading mode
  -- on, per-window statuslines would put a bar under each padding column too.
  vim.o.laststatus = 3

  vim.o.statusline = table.concat({
    -- Just the chapter name: the vault is named on the right, and a
    -- cwd-relative path truncates to nothing useful in a deep vault.
    " %t",
    "%m%r",
    "%=",
    "%{%v:lua.require'writing.statusline'.words()%}",
    "%{%v:lua.require'writing.statusline'.vault()%}",
    "%l:%c  %P ",
  })

  local group = vim.api.nvim_create_augroup("ScriptoriumStatusline", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = group,
    pattern = "*.md",
    callback = function(args)
      recount(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = group,
    pattern = "*.md",
    callback = function(args)
      schedule(args.buf)
    end,
  })
end

return M
