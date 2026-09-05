-- Reading mode: centre the text in a fixed-width column.
--
-- Neovim can't pad a window's left and right edges directly, so this does what
-- the zen-mode plugins do -- opens an empty scratch window on each side and
-- pins it to the right width. No plugin, and the padding windows are wiped on
-- exit, so nothing leaks into the session.

local M = {}

--- Target text width, in columns.
M.width = 80

--- Minimum padding; below this, centring isn't worth it and we bail.
M.min_pad = 4

M.state = { active = false }

local AUGROUP = "WritingReading"

--- Padding either side. The two window separators cost a column each, so
--- subtract them here or the text column comes out narrower than requested.
local function pad_width()
  return math.floor((vim.o.columns - M.width - 2) / 2)
end

--- An empty, unobtrusive scratch window on one side.
local function make_pad(side, width)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "readingpad"

  vim.cmd(side == "left" and "topleft vsplit" or "botright vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_width(win, width)

  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.cursorline = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.list = false
  wo.spell = false
  wo.statuscolumn = ""
  wo.winfixwidth = true
  wo.fillchars = "eob: ,vert: "
  wo.winhl = "Normal:ReadingPad,EndOfBuffer:ReadingPad,WinSeparator:ReadingPad"

  return win
end

local function close_pads()
  for _, key in ipairs({ "left", "right" }) do
    local win = M.state[key]
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    M.state[key] = nil
  end
end

function M.enable(width)
  if M.state.active then
    return
  end

  M.width = width or M.width
  local pad = pad_width()
  if pad < M.min_pad then
    vim.notify(
      string.format("Terminal too narrow to centre %d columns (have %d)", M.width, vim.o.columns),
      vim.log.levels.WARN
    )
    return
  end

  local main = vim.api.nvim_get_current_win()

  M.state.saved = {
    laststatus = vim.o.laststatus,
    number = vim.wo[main].number,
    relativenumber = vim.wo[main].relativenumber,
    list = vim.wo[main].list,
    cursorline = vim.wo[main].cursorline,
    signcolumn = vim.wo[main].signcolumn,
    fillchars = vim.wo[main].fillchars,
  }

  vim.api.nvim_set_hl(0, "ReadingPad", { link = "Normal", default = true })

  local left = make_pad("left", pad)
  vim.api.nvim_set_current_win(main)
  local right = make_pad("right", pad)
  vim.api.nvim_set_current_win(main)

  vim.o.laststatus = 0
  local wo = vim.wo[main]
  wo.number = false
  wo.relativenumber = false
  wo.list = false
  wo.cursorline = false
  wo.signcolumn = "no"
  wo.fillchars = "eob: ,vert: "

  M.state.active = true
  M.state.main = main
  M.state.left = left
  M.state.right = right

  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })

  -- Re-centre when the terminal is resized.
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if not M.state.active then
        return
      end
      local w = pad_width()
      if w < M.min_pad then
        M.disable()
        return
      end
      for _, key in ipairs({ "left", "right" }) do
        local win = M.state[key]
        if win and vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_set_width(win, w)
        end
      end
    end,
  })

  -- If either the text window or a pad goes away, tear the whole thing down
  -- rather than leaving an orphaned column behind.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      if not M.state.active then
        return
      end
      local closed = tonumber(args.match)
      if closed == M.state.main or closed == M.state.left or closed == M.state.right then
        vim.schedule(function()
          M.disable()
        end)
      end
    end,
  })
end

function M.disable()
  if not M.state.active then
    return
  end

  M.state.active = false
  pcall(vim.api.nvim_del_augroup_by_name, AUGROUP)
  close_pads()

  local saved = M.state.saved or {}
  vim.o.laststatus = saved.laststatus or 2

  local main = M.state.main
  if main and vim.api.nvim_win_is_valid(main) then
    local wo = vim.wo[main]
    wo.number = saved.number
    wo.relativenumber = saved.relativenumber
    wo.list = saved.list
    wo.cursorline = saved.cursorline
    wo.signcolumn = saved.signcolumn or "yes"
    wo.fillchars = saved.fillchars or ""
    pcall(vim.api.nvim_set_current_win, main)
  end

  M.state.main = nil
  M.state.saved = nil
end

function M.toggle(width)
  if M.state.active then
    M.disable()
  else
    M.enable(width)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("Reading", function(opts)
    M.toggle(tonumber(opts.args))
  end, { nargs = "?", desc = "Toggle centred reading mode (optional width)" })
end

return M
