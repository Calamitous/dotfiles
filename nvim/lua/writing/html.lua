-- Copy markdown to the clipboard as rich text.
--
-- Puts real rich text on the clipboard, so a paste into Google Docs, Word or
-- an email arrives formatted rather than as literal markup. Handles a visual
-- selection as well as the whole buffer, which the Obsidian plugin could not.
--
-- The actual pipeline differs per platform; see core/platform.lua.

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
  local cmd, err = require("core.platform").html_clipboard_cmd()
  if not cmd then
    vim.notify("Copy as HTML unavailable: " .. err, vim.log.levels.ERROR)
    return
  end

  local md = clean(table.concat(lines, "\n"))
  local words = select(2, md:gsub("%S+", ""))

  -- Run asynchronously: pandoc on a long chapter shouldn't freeze the editor.
  vim.system({ "sh", "-c", cmd }, { stdin = md }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local err = result.stderr
        if err == nil or err == "" then
          err = "exit code " .. tostring(result.code)
        end
        vim.notify("Copy as HTML failed: " .. err, vim.log.levels.ERROR)
      else
        local commas = require("writing.wordcount").commas
        vim.notify(string.format("Copied %s lines (%s words) as HTML", commas(#lines), commas(words)))
      end
    end)
  end)
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
