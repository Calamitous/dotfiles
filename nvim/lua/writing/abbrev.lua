-- Per-vault abbreviations, written as ordinary vim commands.
--
--   <vault>/.scriptorium/abbreviations.vim
--
--     iabbrev bsh Bayze Shab
--     iabbrev nmr Namarûn
--
-- Real vimscript, so `:help abbreviations` applies and the file can be sourced
-- by hand. It replaced a parsed markdown table -- the table needed its own
-- syntax rules for something vim already expresses.
--
-- The one thing added on the way in is `<buffer>`. Abbreviations are installed
-- BUFFER-LOCALLY, which is what keeps vaults apart: `dk` can mean D'khara in
-- one book and something else in another, with both open at once. Plain global
-- `:iabbrev` would leak across every vault.
--
-- NOTE: `set paste` disables insert-mode abbreviations entirely. It is
-- deliberately absent from this config; do not reintroduce it.

local vault = require("writing.vault")

local M = {}

M.filename = "abbreviations.vim"

--- The markdown table this replaced. Still read if no .vim file exists, and
--- converted by `:AbbrevEdit`.
M.legacy = "Abbreviations.md"

function M.relative()
  return vault.support .. "/" .. M.filename
end

--- Does this line define an abbreviation? Covers vim's abbreviated spellings
--- (`ab`, `abbr`, `iab`, `inoreab`, ...).
local function abbrev_command(line)
  local cmd = line:match("^%s*([%a]+)")
  if not cmd then
    return false
  end
  for _, prefix in ipairs({ "ab", "iab", "cab", "noreab", "inoreab", "cnoreab" }) do
    if vim.startswith(cmd, prefix) then
      return true
    end
  end
  return false
end

--- Add `<buffer>` to an abbreviation command that doesn't already have it.
local function scope_to_buffer(line)
  if not abbrev_command(line) or line:find("<buffer>", 1, true) then
    return line
  end
  return (line:gsub("^(%s*[%a]+)%s+", "%1 <buffer> ", 1))
end

--- Read the legacy markdown table, so an existing vault keeps working.
local function legacy_lines(root)
  local path = root .. "/" .. vault.support .. "/" .. M.legacy
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  local out = {}
  for _, entry in ipairs(require("writing.mdtable").parse(lines)) do
    table.insert(out, string.format("iabbrev %s %s", entry.key, entry.value))
  end
  return out
end

--- Install this vault's abbreviations into a buffer.
--- @return integer count
function M.apply(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root = vault.root(bufnr)
  if not root then
    return 0
  end

  local path = root .. "/" .. M.relative()
  local lines
  if vim.fn.filereadable(path) == 1 then
    local ok, read = pcall(vim.fn.readfile, path)
    lines = ok and read or nil
  else
    lines = legacy_lines(root)
  end
  if not lines then
    return 0
  end

  local count = 0
  vim.api.nvim_buf_call(bufnr, function()
    for _, line in ipairs(lines) do
      if vim.trim(line) ~= "" and not vim.startswith(vim.trim(line), '"') then
        if pcall(vim.cmd, scope_to_buffer(line)) then
          count = count + 1
        end
      end
    end
  end)
  return count
end

function M.reload()
  local total = 0
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "markdown" then
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("iabclear <buffer>")
      end)
      total = total + M.apply(bufnr)
    end
  end
  vim.notify(string.format("Reloaded %d abbreviation(s)", total))
end

--- Open this vault's abbreviations, converting a legacy table if there is one.
function M.edit()
  local root = vault.root()
  if not root then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end

  local path = root .. "/" .. M.relative()

  if vim.fn.filereadable(path) == 0 then
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    local body = {
      '" Abbreviations for this vault. Ordinary vim commands -- `<buffer>` is',
      '" added automatically, so these stay local to this book.',
      '" Saving this file applies it immediately.',
      "",
    }
    local migrated = legacy_lines(root)
    if migrated and #migrated > 0 then
      vim.list_extend(body, migrated)
      vim.fn.writefile(body, path)
      vim.notify(string.format("Converted %d abbreviation(s) from %s", #migrated, M.legacy))
    else
      table.insert(body, "iabbrev ")
      vim.fn.writefile(body, path)
    end
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.setup()
  local group = vim.api.nvim_create_augroup("WritingAbbrev", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(args)
      M.apply(args.buf)
    end,
  })

  -- Saving reapplies everywhere, so adding one is `<Leader>wa`, type, `:w`.
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = { "*/" .. M.relative(), "*/" .. vault.support .. "/" .. M.legacy },
    callback = function()
      M.reload()
    end,
  })

  vim.api.nvim_create_user_command("AbbrevReload", M.reload, { desc = "Reload per-vault abbreviations" })
  vim.api.nvim_create_user_command("AbbrevEdit", M.edit, { desc = "Edit this vault's abbreviations" })
end

return M
