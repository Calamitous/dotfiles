-- Make harper's "ignore this lint" decisions travel with the vault.
--
-- harper-ls stores them per-file under
--   ~/.local/share/harper-ls/ignored_lints/<abs path, / replaced by %>
-- which is machine-local and keyed by ABSOLUTE path, so the same vault on
-- another computer (/Users/... vs /home/...) sees none of them.
--
-- The file contents, however, are content hashes:
--   { "context_hashes": [ 4822034463046054603 ] }
-- Those are portable. Only the filename is not. So this mirrors them into
-- <vault>/.harper-ignored/ keyed by a VAULT-RELATIVE path, which can be
-- committed, and rewrites the key back to an absolute path on the way in.
--
-- harper-ls has no setting for its state directory (its only flag is --stdio),
-- so syncing the files is the available route.

local vault = require("writing.vault")

local M = {}

M.vault_dir = ".harper-ignored"

local function state_dir()
  local base = vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")
  return base .. "/harper-ls/ignored_lints"
end

--- harper's key for an absolute path: leading slash dropped, "/" -> "%",
--- trailing "%" appended.
local function encode(path)
  return (path:gsub("^/", ""):gsub("/", "%%")) .. "%"
end

local function decode(name)
  return "/" .. (name:gsub("%%$", ""):gsub("%%", "/"))
end

-- Hashes are u64 and MUST NOT go through a JSON number: vim.json.decode turns
-- them into floats (4822034463046054603 -> 4.2589963615768e+18), which harper
-- can no longer match. So they're read and written as exact digit strings.

local function read_hashes(path)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local text = table.concat(vim.fn.readfile(path), "")
  local out = {}
  for num in text:gmatch("%-?%d+") do
    table.insert(out, num)
  end
  return out
end

local function write_hashes(path, hashes)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ '{"context_hashes":[' .. table.concat(hashes, ",") .. "]}" }, path)
end

--- Union two hash lists, preserving them as strings.
local function merge(a, b)
  local seen, out = {}, {}
  for _, list in ipairs({ a, b }) do
    for _, h in ipairs(list) do
      if not seen[h] then
        seen[h] = true
        table.insert(out, h)
      end
    end
  end
  return out
end

--- Copy harper's ignores for this vault into the vault.
--- @return integer files written
function M.export(root)
  root = root or vault.root()
  if not root then
    return 0
  end

  local src = state_dir()
  if vim.fn.isdirectory(src) == 0 then
    return 0
  end

  local prefix = root:gsub("^/", "") .. "/"
  local count = 0

  for name, type in vim.fs.dir(src) do
    if type == "file" then
      local abs = decode(name)
      if vim.startswith(abs, root .. "/") then
        local rel = abs:sub(#root + 2)
        local target = root .. "/" .. M.vault_dir .. "/" .. encode(rel)
        local merged = merge(read_hashes(src .. "/" .. name), read_hashes(target))
        write_hashes(target, merged)
        count = count + 1
      end
    end
  end

  return count
end

--- Copy the vault's ignores into harper's state for this machine.
--- @return integer files written
function M.import(root)
  root = root or vault.root()
  if not root then
    return 0
  end

  local src = root .. "/" .. M.vault_dir
  if vim.fn.isdirectory(src) == 0 then
    return 0
  end

  local dst = state_dir()
  vim.fn.mkdir(dst, "p")
  local count = 0

  for name, type in vim.fs.dir(src) do
    if type == "file" then
      local rel = decode(name):gsub("^/", "")
      local target = dst .. "/" .. encode(root .. "/" .. rel)
      local merged = merge(read_hashes(src .. "/" .. name), read_hashes(target))
      write_hashes(target, merged)
      count = count + 1
    end
  end

  return count
end

function M.sync(root)
  root = root or vault.root()
  if not root then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end
  local out = M.export(root)
  local into = M.import(root)
  require("core.lsp").refresh()
  vim.notify(string.format("Harper ignores synced (%d out, %d in)", out, into))
end

function M.setup()
  local group = vim.api.nvim_create_augroup("HarperIgnoreSync", { clear = true })
  local imported = {}

  -- Import once per vault per session, so ignores made on another machine
  -- apply here.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(args)
      local root = vault.root(args.buf)
      if root and not imported[root] then
        imported[root] = true
        if M.import(root) > 0 then
          vim.schedule(function()
            require("core.lsp").refresh()
          end)
        end
      end
    end,
  })

  -- Export on the way out, so today's ignores are committed with the book.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for root in pairs(imported) do
        M.export(root)
      end
    end,
  })

  vim.api.nvim_create_user_command("HarperSync", function()
    M.sync()
  end, { desc = "Sync harper ignores with the vault" })
end

return M
