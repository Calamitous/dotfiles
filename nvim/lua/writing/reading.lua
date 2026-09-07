-- Reading mode: centre a pane's text in a fixed-width column.
--
-- PER PANE, deliberately. `<Leader>wr` centres the window you're in and leaves
-- every other one alone.
--
-- The earlier version centred the whole layout and tried to keep it centred as
-- windows came and went. That needed a watcher, a re-apply on every layout
-- change, a saved size snapshot and a separate "wanted" flag -- and produced a
-- string of bugs: panes crushed into a channel, stale sizes restored, a
-- hit-enter prompt from an automatic re-apply that read as the cursor freezing.
-- Toggling one pane at a time needs none of it: opening or closing a split
-- simply doesn't concern the panes already centred.
--
-- Neovim can't pad a window's edges, so each centred pane gets an empty scratch
-- window either side, as the zen-mode plugins do.

local M = {}

--- Target text width, in columns.
M.width = 80

--- Below this much padding either side, centring isn't worth doing.
M.min_pad = 4

--- Centred panes: [text window] = { left, right, saved options }
M.panes = {}

local AUGROUP = "WritingReading"

local function configure_pad(win, width)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "readingpad"

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
  wo.fillchars = "eob: ,vert: "
  wo.winhl = "Normal:ReadingPad,EndOfBuffer:ReadingPad,WinSeparator:ReadingPad"
end

--- Is this window one this module created?
function M.is_pad(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "readingpad"
end

--- The centred pane a window belongs to, if any.
local function owner(win)
  if M.panes[win] then
    return win
  end
  for text, entry in pairs(M.panes) do
    if entry.left == win or entry.right == win then
      return text
    end
  end
  return nil
end

function M.is_active(win)
  win = win or vim.api.nvim_get_current_win()
  return M.panes[win] ~= nil
end

--- Centre one pane. Defaults to the current window.
--- @param quiet boolean|nil  suppress the "too narrow" message
function M.enable(win, quiet)
  win = win or vim.api.nvim_get_current_win()
  if M.panes[win] or M.is_pad(win) then
    return false
  end

  local total = vim.api.nvim_win_get_width(win) - M.width - 2
  if total < 2 * M.min_pad then
    if not quiet then
      vim.notify(
        string.format("This pane is too narrow to centre %d columns", M.width),
        vim.log.levels.WARN
      )
    end
    return false
  end

  local left = math.floor(total / 2)
  local saved = {
    number = vim.wo[win].number,
    relativenumber = vim.wo[win].relativenumber,
    list = vim.wo[win].list,
    cursorline = vim.wo[win].cursorline,
    signcolumn = vim.wo[win].signcolumn,
    fillchars = vim.wo[win].fillchars,
  }

  vim.api.nvim_set_hl(0, "ReadingPad", { link = "Normal", default = true })

  -- `leftabove vsplit` takes its columns from the LEFT NEIGHBOUR, not from the
  -- pane being split, so creating the margins silently shrinks an unrelated
  -- pane. Record every other pane's width and put it back afterwards: the pads
  -- plus the text pane occupy exactly what the pane occupied before, so the
  -- arithmetic works out -- it just has to be enforced.
  local others = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= win then
      others[w] = vim.api.nvim_win_get_width(w)
    end
  end

  local current = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(win)
  vim.cmd("leftabove vsplit")
  local lp = vim.api.nvim_get_current_win()
  configure_pad(lp, left)

  vim.api.nvim_set_current_win(win)
  vim.cmd("rightbelow vsplit")
  local rp = vim.api.nvim_get_current_win()
  configure_pad(rp, total - left)

  -- Deliberately NOT winfixwidth. Pinning the centred pane means vim can't take
  -- columns from it when a split opens elsewhere, so it takes them from the
  -- other panes instead -- which looks like reading mode resizing windows it
  -- has nothing to do with. Let it flex, and drop the centring if it drifts
  -- (see M.validate).
  pcall(vim.api.nvim_win_set_width, win, M.width)

  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.list = false
  wo.cursorline = false
  wo.signcolumn = "no"
  wo.fillchars = "eob: ,vert: "

  -- Settle the whole row together against one target map. Setting any single
  -- width nudges its neighbours, so the pads, this pane and the untouched panes
  -- all have to be pinned at once -- leaving the pads out lets them absorb and
  -- release columns, which is how centring the leftmost pane ended up stealing
  -- 40 columns from its neighbour.
  local target = { [win] = M.width, [lp] = left, [rp] = total - left }
  for w, width in pairs(others) do
    target[w] = width
  end

  for _ = 1, 8 do
    local settled = true
    for w, width in pairs(target) do
      if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_width(w) ~= width then
        pcall(vim.api.nvim_win_set_width, w, width)
        settled = false
      end
    end
    if settled then
      break
    end
  end

  M.panes[win] = { left = lp, right = rp, saved = saved }

  if vim.api.nvim_win_is_valid(current) then
    vim.api.nvim_set_current_win(current)
  end
  return true
end

--- Uncentre one pane. Defaults to the pane the cursor is in (or owns).
function M.disable(win)
  win = owner(win or vim.api.nvim_get_current_win())
  local entry = win and M.panes[win]
  if not entry then
    return false
  end

  M.panes[win] = nil

  for _, pad in ipairs({ entry.left, entry.right }) do
    if vim.api.nvim_win_is_valid(pad) then
      pcall(vim.api.nvim_win_close, pad, true)
    end
  end

  if vim.api.nvim_win_is_valid(win) then
    local wo = vim.wo[win]
    for opt, value in pairs(entry.saved) do
      wo[opt] = value
    end
  end
  return true
end

--- Any window between this pane's pads that isn't the pane itself.
local function intruders(entry)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local from, to
  for i, w in ipairs(wins) do
    if w == entry.left then
      from = i
    elseif w == entry.right then
      to = i
    end
  end
  if not from or not to or to <= from then
    return false
  end
  return (to - from - 1) > 1
end

--- Drop the centring from any pane that is no longer actually centred.
---
--- Splitting a centred pane halves it; splitting elsewhere can borrow from it.
--- Either way the margins no longer mean anything, so take them off rather than
--- leaving a pane flanked by pads at some arbitrary width.
function M.validate()
  -- Twice: setting one pane's width nudges its neighbours, so a single pass can
  -- leave a pane a few columns off.
  for _ = 1, 2 do
  for win, entry in pairs(M.panes) do
    if
      not vim.api.nvim_win_is_valid(win)
      or not vim.api.nvim_win_is_valid(entry.left)
      or not vim.api.nvim_win_is_valid(entry.right)
    then
      M.disable(win)
      goto continue
    end

    -- A window that isn't ours appearing BETWEEN the pads means the centred
    -- pane was split. Width alone can't tell: vim borrows from the pads too, so
    -- a split leaves the pane at (say) 74 rather than halving it.
    if intruders(entry) then
      M.disable(win)
      goto continue
    end

    local width = vim.api.nvim_win_get_width(win)
    if width ~= M.width then
      -- Reclaim from this pane's OWN pads, not from the rest of the layout.
      local available = width
        + vim.api.nvim_win_get_width(entry.left)
        + vim.api.nvim_win_get_width(entry.right)

      if available >= M.width + 2 * M.min_pad then
        pcall(vim.api.nvim_win_set_width, win, M.width)
        local spare = available - M.width
        pcall(vim.api.nvim_win_set_width, entry.left, math.floor(spare / 2))
      else
        M.disable(win)
      end
    end

    ::continue::
  end
  end
end

function M.disable_all()
  for win in pairs(vim.deepcopy and M.panes or M.panes) do
    M.disable(win)
  end
  M.panes = {}
end

--- Resize the current pane by `delta` columns.
---
--- In a centred pane a plain `:vertical resize` hits the 80-column text window,
--- so the margins stay put and the split boundary never moves -- the opposite
--- of what a resize key should do. Uncentre, resize the pane's whole slot, then
--- centre again: the text stays at M.width and the margins take up the slack.
function M.resize(delta)
  local win = vim.api.nvim_get_current_win()
  local entry = M.panes[win]

  if not entry then
    vim.cmd("vertical resize " .. (delta >= 0 and "+" or "") .. delta)
    return
  end

  -- Measure the slot BEFORE dismantling it: text + both margins + separators.
  -- Resizing after `disable` and hoping the pane sits at its slot width
  -- overshoots, because closing the pads doesn't hand the columns back exactly.
  local slot = vim.api.nvim_win_get_width(win)
    + vim.api.nvim_win_get_width(entry.left)
    + vim.api.nvim_win_get_width(entry.right)
    + 2

  M.disable(win)
  pcall(vim.api.nvim_win_set_width, win, slot + delta)
  M.enable(win, true)
end

function M.toggle(width)
  if width then
    M.width = width
  end
  local win = vim.api.nvim_get_current_win()
  if owner(win) then
    M.disable(win)
    vim.notify("Reading mode off")
  elseif M.enable(win) then
    vim.notify("Reading mode on")
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })

  -- If a centred pane or one of its pads goes away, drop the rest of the pair
  -- rather than leaving a stray empty column behind.
  vim.api.nvim_create_autocmd({ "WinNew", "WinClosed", "VimResized" }, {
    group = group,
    callback = function()
      if vim.tbl_isempty(M.panes) then
        return
      end
      vim.schedule(M.validate)
    end,
  })

  -- Pads are ordinary windows, so <C-w>w, <C-w>l and even a mouse click can
  -- land the cursor in one -- an empty, unmodifiable buffer that looks like the
  -- editor has jumped to the corner of the screen. Step off whatever way we
  -- came in.
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if vim.tbl_isempty(M.panes) or not M.is_pad(vim.api.nvim_get_current_win()) then
        return
      end
      for _ = 1, #vim.api.nvim_tabpage_list_wins(0) do
        vim.cmd("wincmd w")
        if not M.is_pad(vim.api.nvim_get_current_win()) then
          return
        end
      end
    end,
  })

  vim.api.nvim_create_user_command("Reading", function(opts)
    M.toggle(tonumber(opts.args))
  end, { nargs = "?", desc = "Centre this pane at a fixed width" })

  vim.api.nvim_create_user_command("ReadingOff", M.disable_all, {
    desc = "Uncentre every pane",
  })
end

return M
