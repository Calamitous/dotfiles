-- Reopen a vault where you left it: same files, same splits.
--
-- The session lives IN the vault (<vault>/.scriptorium/session.vim) so it
-- follows the book between machines, like .vale-dismissed and .harper-ignored/.
-- Two things make that work:
--
--   * `sesdir` in 'sessionoptions' -- vim's own docs call it "useful with
--     projects accessed over a network from different systems". The session
--     cd's to its own directory, computed at load time, so no absolute path is
--     baked in.
--   * neovim writes buffer paths ~-shortened (`~/Writing/...`), which resolves
--     on Linux and macOS alike as long as vaults live under $HOME.
--
-- Window sizes are written proportionally (`&columns * 40 / 80`), so they scale
-- to whatever terminal opens them.

local vault = require("writing.vault")

local M = {}

--- Save on exit / restore on a bare `nvim`.
M.autosave = true
M.autorestore = true

--- `options` is deliberately absent: it would restore global options and
--- mappings, which this config sets for itself on every start. `terminal` too --
--- the fzf pickers and :Compile run in scratch terminals that must not persist.
M.sessionoptions = "blank,buffers,sesdir,folds,tabpages,winsize"

M.filename = "session.vim"
M.statefile = "session.json"

local stdin = false

function M.path(root)
  root = root or vault.root()
  if not root then
    return nil
  end
  local dir = root .. "/" .. vault.support
  return dir .. "/" .. M.filename, dir .. "/" .. M.statefile
end

--- Make the written session portable.
---
--- Two problems with what mksession emits:
---
---   * Buffers OUTSIDE the vault are written as absolute paths, which don't
---     travel. Their `badd` lines are dropped. A window actually *showing* such
---     a file is left alone -- that was a deliberate layout, and it degrades to
---     an empty buffer rather than breaking the session.
---   * In-vault paths are written ~-shortened (`~/Writing/book/N/a.md`), not
---     relative. That survives a move between machines only if the vault sits
---     at the same path under $HOME. Rewriting them relative to the session
---     file makes the vault relocatable outright -- and `sesdir` has already
---     cd'd there, so `../N/a.md` resolves correctly wherever it lands.
local function make_portable(session, root)
  local home = vim.env.HOME or ""
  local short = vim.fn.fnamemodify(root, ":~")
  local kept = {}

  for _, line in ipairs(vim.fn.readfile(session)) do
    local path = line:match("^badd%s+%+%d+%s+(.*)$")
    if path then
      local full = path:gsub("^~", home)
      if not vim.startswith(full, root .. "/") then
        goto continue
      end
    end

    -- `..` is the vault root, because sesdir cd's to <vault>/.scriptorium.
    line = line:gsub(vim.pesc(short .. "/"), "../")
    if short ~= root then
      line = line:gsub(vim.pesc(root .. "/"), "../")
    end

    table.insert(kept, line)
    ::continue::
  end

  vim.fn.writefile(kept, session)
end

--- Write the session for `root`.
function M.save(root)
  root = root or vault.root()
  if not root then
    return false
  end

  -- Never overwrite a good session with an empty one. Opening nvim, doing
  -- nothing and quitting would otherwise destroy the layout you saved
  -- yesterday -- and an empty session is no use to anyone.
  local has_files = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ""
      and name ~= ""
      and vim.startswith(name, root .. "/")
    then
      has_files = true
      break
    end
  end
  if not has_files then
    return false
  end

  local session, state = M.path(root)
  vim.fn.mkdir(vim.fs.dirname(session), "p")

  -- Record what mksession can't, then tear those windows down so they aren't
  -- saved as empty scratch panes.
  local sidebar = require("writing.sidebar")
  local sidebar_win = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].filetype == "netrw" or (name ~= "" and vim.fn.isdirectory(name) == 1) then
      sidebar_win = win
      break
    end
  end

  vim.fn.writefile({
    vim.json.encode({
      sidebar = sidebar_win and {
        open = true,
        width = vim.api.nvim_win_get_width(sidebar_win),
      } or { open = false },
    }),
  }, state)

  require("writing.reading").disable_all()
  sidebar.close()
  pcall(vim.cmd, "cclose")

  local saved = vim.o.sessionoptions
  vim.o.sessionoptions = M.sessionoptions
  local ok = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(session))
  vim.o.sessionoptions = saved

  if ok then
    make_portable(session, root)
  end
  return ok
end

--- Restore the session for `root`.
function M.restore(root)
  root = root or vault.root() or vim.uv.cwd()
  local session, state = M.path(root)
  if not session or vim.fn.filereadable(session) == 0 then
    return false
  end

  local ok, err = pcall(vim.cmd, "silent source " .. vim.fn.fnameescape(session))
  if not ok then
    vim.notify("Session restore failed: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  -- `sesdir` leaves the cwd at .scriptorium/; put it back somewhere sensible.
  pcall(vim.cmd, "cd " .. vim.fn.fnameescape(root))

  -- Drop buffers whose file has since been renamed or deleted, so they don't
  -- come back as empty phantoms.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and vim.bo[buf].buftype == "" and vim.fn.filereadable(name) == 0 then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  -- The sidebar is reopened rather than restored: mksession wouldn't carry its
  -- window-local settings without pulling in `options` wholesale.
  if vim.fn.filereadable(state) == 1 then
    local decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(state), ""))
    local _, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(state), ""))
    if decoded and type(data) == "table" and data.sidebar and data.sidebar.open then
      local sidebar = require("writing.sidebar")
      if data.sidebar.width then
        sidebar.width = data.sidebar.width
      end
      sidebar.open(root)
    end
  end

  return true
end

function M.delete(root)
  root = root or vault.root()
  local session, state = M.path(root)
  if not session then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end
  vim.fn.delete(session)
  vim.fn.delete(state)
  vim.notify("Session deleted for " .. vim.fs.basename(root))
end

function M.info()
  local root = vault.root()
  local session = M.path(root)
  if not session then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end
  if vim.fn.filereadable(session) == 0 then
    vim.notify("No session saved for " .. vim.fs.basename(root))
    return
  end
  local files = 0
  for _, line in ipairs(vim.fn.readfile(session)) do
    if line:match("^badd") then
      files = files + 1
    end
  end
  vim.notify(string.format(
    "%s\n  %d file(s), saved %s",
    vim.fn.fnamemodify(session, ":~"),
    files,
    vim.fn.strftime("%Y-%m-%d %H:%M", vim.fn.getftime(session))
  ))
end

function M.setup()
  local group = vim.api.nvim_create_augroup("ScriptoriumSession", { clear = true })

  vim.api.nvim_create_autocmd("StdinReadPre", {
    group = group,
    callback = function()
      stdin = true
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    nested = true, -- so FileType fires: prose mode, abbreviations, comments
    callback = function()
      if not M.autorestore or stdin or vim.fn.argc() > 0 then
        return
      end
      local root = vault.root()
      if root then
        M.restore(root)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if M.autosave then
        pcall(M.save)
      end
    end,
  })

  vim.api.nvim_create_user_command("SessionSave", function()
    if M.save() then
      vim.notify("Session saved")
    else
      vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    end
  end, { desc = "Save this vault's window layout" })

  vim.api.nvim_create_user_command("SessionRestore", function()
    if not M.restore() then
      vim.notify("No session saved for this vault")
    end
  end, { desc = "Restore this vault's window layout" })

  vim.api.nvim_create_user_command("SessionDelete", M.delete, { desc = "Forget this vault's layout" })
  vim.api.nvim_create_user_command("SessionInfo", M.info, { desc = "Show this vault's saved session" })
end

return M
