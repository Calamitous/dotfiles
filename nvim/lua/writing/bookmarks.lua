-- One-key file opening, per vault.
--
-- `<Leader>f` then a letter opens a file listed in
-- <vault>/.scriptorium/Bookmarks.md:
--
--   | Key | File |
--   | --- | ---- |
--   | e   | Metadata/Larger-Scale Edits.md |
--   | o   | Metadata/Outline.md |
--
-- Deliberately one mapping rather than one per bookmark: the key is looked up
-- in whichever vault the current buffer belongs to, so the same `<Leader>fe`
-- means different files in different books and nothing leaks between them.

local vault = require("writing.vault")
local mdtable = require("writing.mdtable")

local M = {}

M.filename = "Bookmarks.md"

function M.relative()
  return vault.support .. "/" .. M.filename
end

--- Bookmarks for the current vault, in file order.
function M.list(bufnr)
  local path = vault.support_path(M.filename, bufnr)
  if not path or vim.fn.filereadable(path) == 0 then
    return {}
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and mdtable.parse(lines) or {}
end

--- Resolve a bookmark key to an absolute path.
function M.resolve(key, bufnr)
  local root = vault.root(bufnr)
  if not root then
    return nil
  end
  for _, entry in ipairs(M.list(bufnr)) do
    if entry.key == key then
      local target = entry.value
      if not vim.startswith(target, "/") then
        target = root .. "/" .. target
      end
      return target
    end
  end
  return nil
end

function M.show()
  local entries = M.list()
  if #entries == 0 then
    vim.notify("No bookmarks -- run :BookmarksEdit", vim.log.levels.WARN)
    return
  end
  local lines = {}
  for _, e in ipairs(entries) do
    local exists = vim.fn.filereadable(M.resolve(e.key) or "") == 1
    table.insert(lines, string.format("  %-4s %s%s", e.key, e.value, exists and "" or "   (missing)"))
  end
  vim.api.nvim_echo(
    vim.tbl_map(function(l) return { l .. "\n" } end,
      vim.list_extend({ "Bookmarks (<Leader>f then a key)" }, lines)),
    false, {}
  )
end

--- Prompt for a key and open its file.
function M.open(key)
  if not vault.root() then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end

  if not key or key == "" then
    vim.api.nvim_echo({ { "Bookmark: " } }, false, {})
    local ok, char = pcall(vim.fn.getcharstr)
    vim.api.nvim_echo({ { "" } }, false, {})
    if not ok or char == "" or char == "\27" then
      return
    end
    key = char
  end

  local target = M.resolve(key)
  if not target then
    M.show()
    return
  end
  if vim.fn.filereadable(target) == 0 then
    vim.notify("Bookmark '" .. key .. "' points at a missing file:\n  " .. target, vim.log.levels.WARN)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(target))
end

function M.edit()
  local path = vault.support_path(M.filename)
  if not path then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end
  if vim.fn.filereadable(path) == 0 then
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile({
      "# Bookmarks",
      "",
      "`<Leader>f` then the key opens the file. Paths are relative to the vault.",
      "",
      "| Key | File |",
      "| --- | ---- |",
    }, path)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.setup()
  vim.api.nvim_create_user_command("Bookmarks", M.show, { desc = "List this vault's bookmarks" })
  vim.api.nvim_create_user_command("BookmarksEdit", M.edit, { desc = "Edit this vault's bookmarks" })
  vim.api.nvim_create_user_command("Bookmark", function(o)
    M.open(o.args ~= "" and o.args or nil)
  end, { nargs = "?", desc = "Open a bookmarked file" })
end

return M
