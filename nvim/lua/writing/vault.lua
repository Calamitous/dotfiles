-- Vault awareness: locate the Obsidian vault (and Longform draft) a buffer lives in.
-- This is the keystone module -- abbreviations, word counts, search scope and
-- compile all resolve their context through here.

local M = {}

--- Nearest ancestor directory containing `.obsidian/`.
--- @param bufnr integer|nil  defaults to current buffer
--- @return string|nil  absolute path to the vault root
function M.root(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  local source = (name ~= "" and name) or vim.uv.cwd()
  local ok, root = pcall(vim.fs.root, source, ".obsidian")
  if ok and root then
    return root
  end
  return nil
end

--- Short name of the vault (its directory basename), for display.
function M.name(bufnr)
  local root = M.root(bufnr)
  return root and vim.fs.basename(root) or nil
end

--- True if the buffer lives inside an Obsidian vault.
function M.in_vault(bufnr)
  return M.root(bufnr) ~= nil
end

--- Nearest ancestor `Index.md` (a Longform draft), searching upward from the
--- buffer but never escaping the vault root.
--- @return string|nil  absolute path to the draft's Index.md
function M.draft(bufnr)
  bufnr = bufnr or 0
  local root = M.root(bufnr)
  if not root then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = (name ~= "" and vim.fs.dirname(name)) or vim.uv.cwd()

  while dir and dir:sub(1, #root) == root do
    local candidate = dir .. "/Index.md"
    if vim.uv.fs_stat(candidate) then
      return candidate
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
  return nil
end

--- Path to a file inside the current vault, or nil if not in a vault.
function M.path(relative, bufnr)
  local root = M.root(bufnr)
  return root and (root .. "/" .. relative) or nil
end

return M
