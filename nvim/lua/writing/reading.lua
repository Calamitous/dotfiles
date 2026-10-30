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

--- Keep the cursor line in the middle of the pane while you read and type --
--- a typewriter platen, where the paper moves and the type bar doesn't. Set it
--- false to leave vertical scrolling alone; it stops centring immediately,
--- though the panes already centred keep their scrolling options until they're
--- toggled off.
M.typewriter = true

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

--- What a centred pane looks like. One table, because these have to be applied
--- twice: once when the margins go up, and again every time a file is opened
--- into the pane -- `:edit` measurably loses the window-local `fillchars`, and
--- a filetype that wants a number, sign or fold column narrows the text from
--- the inside without touching the window's width at all.
local READING_WO = {
  number = false,
  relativenumber = false,
  list = false,
  cursorline = false,
  signcolumn = "no",
  fillchars = "eob: ,vert: ",
}

--- Extra options the typewriter needs. Separate from READING_WO because
--- dropping 'scrolloff' to 0 is only an improvement when something else is
--- keeping the cursor off the window edge; without the centring it would make
--- reading mode worse than the global 5.
local TYPEWRITER_WO = {
  scrolloff = 0,
  -- Lets <C-e>/<C-y> scroll by SCREEN row rather than buffer line, which is
  -- the whole trick: a paragraph here is one line, soft-wrapped over several
  -- rows, and scrolling it a line at a time overshoots the middle by the
  -- height of the paragraph.
  smoothscroll = true,
}

local function apply_options(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  for opt, value in pairs(READING_WO) do
    vim.wo[win][opt] = value
  end
  if M.typewriter then
    for opt, value in pairs(TYPEWRITER_WO) do
      vim.wo[win][opt] = value
    end
  end
end

--- The screen row the cursor should sit on.
local function centre_row(win)
  return math.ceil(vim.api.nvim_win_get_height(win) / 2)
end

local centring = false

--- Scroll the pane so the cursor sits on its middle row.
---
--- `scrolloff` cannot do this. Even at 999 it gives up at the end of the file:
--- walking to the last line of a buffer leaves the cursor on the bottom row,
--- because there is nothing below to scroll into view. <C-e> keeps going --
--- vim will happily scroll until only the last line is left on screen -- so
--- the correction is made in screen rows, measured and applied, rather than
--- asked for.
---
--- Near the top of the buffer there is nothing above the first line to scroll
--- in either, so <C-y> no-ops and the cursor walks down to the middle row
--- before it starts to hold. That's the right behaviour, not a failure.
---
--- The measure-and-scroll idea is from scrollEOF.nvim (MIT, Aasim-A), which
--- does it with `topline` arithmetic; that reads the same in code but jumps a
--- whole wrapped paragraph at a time, which sawtooths badly in prose.
function M.centre_cursor(win)
  win = win or vim.api.nvim_get_current_win()
  if centring or not M.typewriter or not M.panes[win] then
    return false
  end

  -- `winline()` reports the CURRENT window, so there's nothing to measure for
  -- a pane the cursor isn't in.
  if win ~= vim.api.nvim_get_current_win() then
    return false
  end

  -- Normal and insert only. In visual or operator-pending a `:normal!` would
  -- interfere with the selection or the pending operator. Insert mode survives
  -- a `:normal!` run from an autocommand -- but the cursor COLUMN does not, on
  -- its own; see the 'virtualedit' dance below.
  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "n" and mode:sub(1, 1) ~= "i" then
    return false
  end

  local row = vim.fn.winline()
  local want = centre_row(win)
  if row == want then
    return false
  end

  -- \x05 is <C-e>, \x19 is <C-y>.
  local keys = row > want and ("%d\x05"):format(row - want) or ("%d\x19"):format(want - row)

  centring = true
  -- `:normal!` runs these keys under normal-mode rules, and normal mode will
  -- not leave the cursor past the last character of a line. In insert mode it
  -- legitimately IS past it -- that is what `A` does -- so the scroll dragged
  -- the cursor back a column and the next letter typed landed before the final
  -- one. 'onemore' is the exemption for exactly that, held only for the two
  -- keys below. Restoring it afterwards does not re-clamp the cursor.
  local ve = vim.wo.virtualedit
  vim.wo.virtualedit = "onemore"
  pcall(vim.cmd, "normal! " .. keys)
  vim.wo.virtualedit = ve
  centring = false
  return true
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

--- Close padding windows that no pane claims any more.
---
--- `disable` closes its own pads, so an orphan only happens when the module
--- loses its state while the windows live on -- a reload that couldn't source
--- the config, a hand-cleared `package.loaded`. Nothing will ever reclaim
--- them, so two dead margins sit there until you quit. Sweep them the moment
--- we trip over one.
local function close_orphan_pads()
  local dead = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if M.is_pad(w) and not owner(w) then
      table.insert(dead, w)
    end
  end
  for _, w in ipairs(dead) do
    pcall(vim.api.nvim_win_close, w, true)
  end
  return #dead
end

--- Step out of a padding window, before anything opens a file in it.
---
--- Pickers `:edit` into the current window, and the cursor can be sitting in a
--- pad -- after a `:Reload` orphaned them, or a stray <C-w>h. Loading a real
--- file there replaces the scratch buffer, which takes the `readingpad`
--- filetype with it: `is_pad` can no longer recognise the window, the WinEnter
--- guard can't rescue it, and `validate` sees the text pane still at M.width
--- and leaves well alone. The result is a chapter in a margin-width window for
--- the rest of the session, which is what "reading mode went narrow" meant.
---
--- @return boolean  whether it changed anything
function M.leave_pad()
  -- Dead margins first, and unconditionally: while any OTHER pane is still
  -- centred the WinEnter guard is live, so it bounces the cursor out of an
  -- orphan before we ever get here -- and then nothing would sweep it. Closing
  -- a window the cursor is in moves the cursor, which the move below sorts out.
  local swept = close_orphan_pads() > 0

  local win = vim.api.nvim_get_current_win()
  if not M.is_pad(win) then
    return swept
  end

  local text = owner(win)
  if text and vim.api.nvim_win_is_valid(text) then
    vim.api.nvim_set_current_win(text)
    return true
  end

  -- Still in a pad: an owned one, or an orphan the sweep above couldn't close.
  -- Any real window will do.
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not M.is_pad(w) and vim.api.nvim_win_get_config(w).relative == "" then
      vim.api.nvim_set_current_win(w)
      return true
    end
  end
  return swept
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
  -- Both tables, whatever M.typewriter says right now: the flag can change
  -- between enable and disable, and an option saved from only one of them
  -- would leak.
  local saved = {}
  for _, tbl in ipairs({ READING_WO, TYPEWRITER_WO }) do
    for opt in pairs(tbl) do
      saved[opt] = vim.wo[win][opt]
    end
  end

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

  apply_options(win)

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
  M.centre_cursor(win)
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
local validating = false

function M.validate()
  -- Setting a width fires WinResized, which schedules another validate. The
  -- passes below settle to a fixed point and the next one would no-op, but
  -- there's no reason to let them nest while this one is still working.
  if validating then
    return
  end
  validating = true
  local ok, err = pcall(M.validate_once)
  validating = false
  if not ok then
    error(err)
  end
end

function M.validate_once()
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
  -- Snapshot the keys: `disable` clears its own entry as it goes.
  local wins = vim.tbl_keys(M.panes)
  for _, win in ipairs(wins) do
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
  -- WinResized matters as much as the other three: a width can change without
  -- any window opening or closing -- netrw's sidebar pinning itself, a plugin
  -- nudging a neighbour, a bare `:vertical resize` -- and until this was
  -- listened for, nothing ever re-measured. The pane stayed where it had
  -- drifted to for the rest of the session, which is the "it went narrow and
  -- stayed narrow" everyone kept reporting.
  vim.api.nvim_create_autocmd({ "WinNew", "WinClosed", "WinResized", "VimResized" }, {
    group = group,
    callback = function()
      if vim.tbl_isempty(M.panes) then
        return
      end
      vim.schedule(M.validate)
    end,
  })

  -- Opening a file into a centred pane runs its ftplugins, and what they set on
  -- the window outlives the buffer that triggered it. Put reading mode's own
  -- settings back on top afterwards -- scheduled, so it lands after the
  -- ftplugin rather than racing it.
  vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if not M.panes[win] then
        return
      end
      vim.schedule(function()
        if M.panes[win] then
          apply_options(win)
          M.centre_cursor(win)
        end
      end)
    end,
  })

  -- The typewriter platen. CursorMovedI as well as CursorMoved, so the line
  -- you're typing stays put instead of marching down the screen.
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      if vim.tbl_isempty(M.panes) then
        return
      end
      M.centre_cursor()
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
