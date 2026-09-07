-- Build and tear down a throwaway vault.
--
-- It has to live under ~/Writing: vault detection looks for `.obsidian`, and
-- obsidian.nvim only registers workspaces found there, so a vault in /tmp
-- behaves differently from a real one.

local M = {}

M.root = nil

--- @param files table<string,string>  path relative to the vault -> contents
function M.create(files)
  local root = vim.fn.expand("~/Writing/.scriptorium-test-" .. vim.uv.os_getpid())
  vim.fn.delete(root, "rf")
  vim.fn.mkdir(root .. "/.obsidian", "p")
  vim.fn.mkdir(root .. "/.scriptorium", "p")

  for path, body in pairs(files or {}) do
    local full = root .. "/" .. path
    vim.fn.mkdir(vim.fs.dirname(full), "p")
    vim.fn.writefile(vim.split(body, "\n"), full)
  end

  M.root = root
  vim.cmd("cd " .. vim.fn.fnameescape(root))
  return root
end

--- A Longform Index.md listing `scenes`.
function M.index(title, scenes)
  local lines = { "---", "longform:", "  format: scenes", "  title: " .. title, "  sceneFolder: /", "  scenes:" }
  for _, s in ipairs(scenes) do
    table.insert(lines, "    - " .. s)
  end
  table.insert(lines, "---")
  return table.concat(lines, "\n")
end

--- Turn on filetype detection.
---
--- `nvim -l` starts with it OFF, so buffers open with no filetype and every
--- FileType autocmd -- prose mode, abbreviations, comment highlighting --
--- silently never fires. Specs calling functions directly still pass, which is
--- exactly how that hides.
---
--- Opt-in rather than global: with ftplugins loaded, the specs that change
--- `columns` and resize windows trip an assertion in neovim's grid code.
function M.filetypes()
  vim.cmd("filetype plugin indent on")
end

function M.destroy()
  if M.root then
    vim.cmd("cd " .. vim.fn.fnameescape(vim.fn.expand("~")))
    vim.fn.delete(M.root, "rf")
    M.root = nil
  end
end

--- Close every window and buffer, so one spec can't leak into the next.
function M.reset()
  vim.cmd("silent! only")
  vim.cmd("silent! %bwipeout!")
end

return M
