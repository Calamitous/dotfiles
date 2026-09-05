-- Copy markdown to the clipboard as rich text.
--
-- The trick is xclip's `-t text/html` target: it puts real HTML on the
-- clipboard, so a paste into Google Docs, Word or an email arrives formatted
-- rather than as literal markup. Handles a visual selection as well as the
-- whole buffer, which the Obsidian plugin could not do.

local M = {}

--- Strip the things that shouldn't reach a shared document.
local function clean(md)
  -- YAML frontmatter (only at the very top).
  md = md:gsub("^%-%-%-\r?\n.-\r?\n%-%-%-%s*\r?\n", "")
  -- Obsidian and HTML comments.
  md = md:gsub("%%%%.-%%%%", "")
  md = md:gsub("<!%-%-.-%-%->", "")
  -- Wikilinks: keep the display text, drop the syntax.
  md = md:gsub("!?%[%[([^%]|]*)|([^%]]*)%]%]", "%2")
  md = md:gsub("!?%[%[([^%]]*)%]%]", "%1")
  return md
end

--- @param lines string[]
local function to_clipboard(lines)
  if vim.fn.executable("pandoc") ~= 1 then
    vim.notify("pandoc not found", vim.log.levels.ERROR)
    return
  end
  if vim.fn.executable("xclip") ~= 1 then
    vim.notify("xclip not found", vim.log.levels.ERROR)
    return
  end

  local md = clean(table.concat(lines, "\n"))

  local result = vim.system(
    { "sh", "-c", "pandoc -f markdown -t html | xclip -selection clipboard -t text/html" },
    { stdin = md }
  ):wait()

  if result.code ~= 0 then
    vim.notify("Copy as HTML failed: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
    return
  end

  local words = select(2, md:gsub("%S+", ""))
  vim.notify(string.format("Copied %d lines (%d words) as HTML", #lines, words))
end

--- Copy the whole buffer.
function M.buffer()
  to_clipboard(vim.api.nvim_buf_get_lines(0, 0, -1, false))
end

--- Copy an inclusive line range (as handed over by a :command range).
function M.range(first, last)
  to_clipboard(vim.api.nvim_buf_get_lines(0, first - 1, last, false))
end

function M.setup()
  vim.api.nvim_create_user_command("CopyHTML", function(opts)
    if opts.range > 0 then
      M.range(opts.line1, opts.line2)
    else
      M.buffer()
    end
  end, { range = true, desc = "Copy buffer or selection to clipboard as rich text" })
end

return M
