-- Per-vault abbreviations.
--
-- Abbreviations are installed BUFFER-LOCALLY (`iabbrev <buffer>`), which is what
-- makes this per-vault for free: two buffers from different vaults can carry
-- different sets at the same time, and switching vaults needs no teardown.
--
-- Source file: <vault>/.scriptorium/Abbreviations.md (see vault.support).
-- Accepts a markdown table, or plain `lhs = rhs` lines:
--
--   | Abbr | Expands to |
--   |------|------------|
--   | dk   | D'khara    |
--
--   dk = D'khara
--
-- NOTE: `set paste` disables insert-mode abbreviations entirely. It is
-- deliberately absent from this config; do not reintroduce it.

local vault = require("writing.vault")

local M = {}

M.filename = "Abbreviations.md"

--- Full vault-relative path, derived from vault.support.
function M.relative()
  return vault.support .. "/" .. M.filename
end

local function is_separator(line)
  return line:match("^%s*|?[%s:|-]+|?%s*$") ~= nil and line:match("%-%-") ~= nil
end

--- Parse the abbreviations file into a list of {lhs, rhs} pairs.
local function parse(lines)
  local pairs_out = {}

  for i, line in ipairs(lines) do
    if line:match("^%s*$") or line:match("^%s*#") or is_separator(line) then
      goto continue
    end

    local lhs, rhs

    if line:match("^%s*|") then
      -- Markdown table row. Skip a header row (one followed by a separator).
      if lines[i + 1] and is_separator(lines[i + 1]) then
        goto continue
      end
      local cells = {}
      for cell in line:gmatch("|([^|]*)") do
        table.insert(cells, vim.trim(cell))
      end
      lhs, rhs = cells[1], cells[2]
    else
      lhs, rhs = line:match("^%s*(%S+)%s*=%s*(.-)%s*$")
    end

    if lhs and rhs and lhs ~= "" and rhs ~= "" and not lhs:find("%s") then
      table.insert(pairs_out, { lhs = lhs, rhs = rhs })
    end

    ::continue::
  end

  return pairs_out
end

--- Escape an expansion for use as the {rhs} of an :iabbrev.
local function escape_rhs(rhs)
  -- A bare `|` would terminate the command; a bare `<` could be read as a key code.
  return (rhs:gsub("<", "<lt>"):gsub("|", "\\|"))
end

--- Read and install abbreviations for a buffer. Silent when there's no file.
--- @return integer count installed
function M.apply(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local path = vault.support_path(M.filename, bufnr)
  if not path or not vim.uv.fs_stat(path) then
    return 0
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return 0
  end

  local count = 0
  vim.api.nvim_buf_call(bufnr, function()
    for _, entry in ipairs(parse(lines)) do
      local cmd = string.format("iabbrev <buffer> %s %s", entry.lhs, escape_rhs(entry.rhs))
      if pcall(vim.cmd, cmd) then
        count = count + 1
      end
    end
  end)

  return count
end

--- Re-read the file and reapply to every loaded markdown buffer.
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

--- Open the current vault's abbreviations file, seeding it if absent.
function M.edit()
  local path = vault.support_path(M.filename)
  if not path then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end

  if not vim.uv.fs_stat(path) then
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile({
      "# Abbreviations",
      "",
      "Expanded automatically while editing markdown in this vault.",
      "Reload after editing with `:AbbrevReload`.",
      "",
      "| Abbr | Expands to |",
      "| ---- | ---------- |",
    }, path)
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

  -- Saving the abbreviations file reloads it everywhere, so adding one is just
  -- `<Leader>wa`, type, `:w` -- no separate reload step.
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*/" .. M.relative(),
    callback = function()
      M.reload()
    end,
  })

  vim.api.nvim_create_user_command("AbbrevReload", M.reload, { desc = "Reload per-vault abbreviations" })
  vim.api.nvim_create_user_command("AbbrevEdit", M.edit, { desc = "Edit this vault's abbreviations" })
end

return M
