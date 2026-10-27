-- Reload the config without restarting.
--
-- `:source $MYVIMRC` is not enough on its own: required Lua modules are cached
-- in `package.loaded` and won't re-execute. This clears our own modules, re-runs
-- init.lua, and re-fires FileType so buffer-local settings (abbreviations,
-- prose mode) reapply to buffers that are already open.
--
-- What a reload CANNOT do: remove a keymap, command or autocmd you deleted from
-- the config. It re-runs what's there now; it doesn't undo what ran before.
-- For that, restart. Everything here uses `clear = true` augroups and
-- force-replaced commands, so re-running is otherwise idempotent.

local M = {}

--- Module prefixes owned by this config, and therefore safe to drop.
M.prefixes = { "core", "writing" }

local function is_ours(name)
  for _, prefix in ipairs(M.prefixes) do
    if name == prefix or name:sub(1, #prefix + 1) == prefix .. "." then
      return true
    end
  end
  return false
end

function M.reload()
  -- Tear down anything holding windows before its module disappears, or the
  -- reading-mode padding windows get orphaned: the fresh module starts with an
  -- empty `panes`, and both of its safety autocmds bail early when that's
  -- empty, so nothing re-measures the widths and nothing steps the cursor back
  -- off a pad. The next file you opened would then load INTO a padding window,
  -- at pad width -- which is where "reading mode went narrow" came from.
  --
  -- This checked `reading.state.active` for a while, which never existed; the
  -- state is `panes`, keyed by window.
  --
  -- Which panes WERE centred is worth keeping: a reload doesn't touch the
  -- windows themselves, only the module that remembers them, so the handles
  -- are still valid on the other side and the margins can simply go back.
  local centred = {}
  local ok, reading = pcall(require, "writing.reading")
  if ok and type(reading.panes) == "table" and next(reading.panes) then
    centred = vim.tbl_keys(reading.panes)
    reading.disable_all()
  end

  local cleared = 0
  for name in pairs(package.loaded) do
    if is_ours(name) then
      package.loaded[name] = nil
      cleared = cleared + 1
    end
  end

  local init = vim.env.MYVIMRC
  if not init or init == "" then
    init = vim.fn.stdpath("config") .. "/init.lua"
  end

  local sourced, err = pcall(dofile, init)
  if not sourced then
    vim.notify("Reload failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- Reapply buffer-local settings to already-open buffers.
  local buffers = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= "" then
      vim.api.nvim_buf_call(buf, function()
        pcall(vim.cmd, "iabclear <buffer>")
        pcall(vim.cmd, "doautocmd FileType")
      end)
      buffers = buffers + 1
    end
  end

  -- Re-centre last. The FileType pass above re-runs the ftplugins, which set
  -- window-local options of their own; centring afterwards means reading mode's
  -- settings win, and the originals it squirrels away to restore on toggle-off
  -- are the ones the ftplugins just established. `enable` is quiet here so a
  -- layout that has since grown too narrow declines instead of scolding you,
  -- and the fresh module is a NEW table -- the one captured above went with
  -- `package.loaded`.
  local panes = 0
  if #centred > 0 then
    local fresh
    ok, fresh = pcall(require, "writing.reading")
    for _, win in ipairs(ok and centred or {}) do
      if vim.api.nvim_win_is_valid(win) and fresh.enable(win, true) then
        panes = panes + 1
      end
    end
  end

  vim.notify(string.format(
    "Config reloaded — %d modules, %d buffers%s",
    cleared,
    buffers,
    panes > 0 and string.format(", %d re-centred", panes) or ""
  ))
end

function M.setup()
  vim.api.nvim_create_user_command("Reload", M.reload, { desc = "Reload the nvim config in place" })
end

return M
