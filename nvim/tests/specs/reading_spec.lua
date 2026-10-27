local t = require("tests.harness")
local V = require("tests.vault")
local reading = require("writing.reading")

t.describe("reading mode (per pane)")

local function layout()
  local text, pad = {}, {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
    table.insert(ft == "readingpad" and pad or text, vim.api.nvim_win_get_width(w))
  end
  return text, pad
end

local function open(n)
  reading.disable_all()
  vim.wait(50)
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  for i = 2, n do
    vim.cmd("vsplit " .. V.root .. "/N/" .. i .. ".md")
  end
  vim.cmd("wincmd =")
end

V.create({ ["N/1.md"] = "One.", ["N/2.md"] = "Two.", ["N/3.md"] = "Three." })

t.it("centres the current pane", function()
  vim.o.columns = 220
  open(1)
  t.ok(reading.enable(), "enabled")
  local text = layout()
  t.eq(text, { 80 })
  reading.disable_all()
end)

t.it("centres ONLY the current pane, leaving others alone", function()
  vim.o.columns = 260
  open(2)
  local before = layout()
  reading.enable()
  local text = layout()
  t.eq(#text, 2, "still two text panes")
  t.ok(vim.tbl_contains(text, 80), "the current pane is centred")
  t.ok(text[1] ~= text[2] or before[1] ~= before[2], "the other pane was not centred to match")
  reading.disable_all()
end)

t.it("each pane can be toggled independently", function()
  vim.o.columns = 300
  open(2)
  local wins = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    table.insert(wins, w)
  end
  reading.enable(wins[1])
  t.ok(reading.is_active(wins[1]), "first centred")
  t.ok(not reading.is_active(wins[2]), "second untouched")
  reading.enable(wins[2])
  t.ok(reading.is_active(wins[2]), "second centred too")
  reading.disable(wins[1])
  t.ok(not reading.is_active(wins[1]), "first uncentred")
  t.ok(reading.is_active(wins[2]), "second still centred")
  reading.disable_all()
end)

t.it("restores the pane on toggle off", function()
  vim.o.columns = 220
  open(1)
  local before = layout()
  reading.enable()
  reading.disable()
  local text, pad = layout()
  t.eq(text, before, "width restored")
  t.eq(#pad, 0, "no pads left")
end)

t.it("a split in ANOTHER pane leaves the centred one at its width", function()
  vim.o.columns = 320
  open(2)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  reading.enable(wins[1])
  vim.api.nvim_set_current_win(wins[2])
  vim.cmd("vsplit " .. V.root .. "/N/3.md")
  vim.wait(300)
  t.ok(reading.is_active(wins[1]), "still centred")
  t.eq(vim.api.nvim_win_get_width(wins[1]), 80, "reclaimed from its own pads")
  reading.disable_all()
end)

t.it("the cursor never lands in a padding window", function()
  vim.o.columns = 220
  open(1)
  reading.enable()
  local pads = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if reading.is_pad(w) then
      table.insert(pads, w)
    end
  end
  t.eq(#pads, 2, "two pads to try")
  for _, pad in ipairs(pads) do
    vim.api.nvim_set_current_win(pad)
    vim.cmd("doautocmd WinEnter")
    t.ok(not reading.is_pad(vim.api.nvim_get_current_win()), "stepped off the pad")
  end
  reading.disable_all()
end)

t.it("cycling with wincmd w skips the pads", function()
  vim.o.columns = 220
  open(1)
  reading.enable()
  for _ = 1, 6 do
    vim.cmd("wincmd w")
    vim.cmd("doautocmd WinEnter")
    t.ok(not reading.is_pad(vim.api.nvim_get_current_win()), "never rests on a pad")
  end
  reading.disable_all()
end)

t.it("closing a centred pane cleans up its pads", function()
  vim.o.columns = 300
  open(2)
  local win = vim.api.nvim_get_current_win()
  reading.enable(win)
  vim.api.nvim_win_close(win, true)
  vim.wait(300)
  local _, pad = layout()
  t.eq(#pad, 0, "no orphaned pads")
  reading.disable_all()
end)

t.it("opening a split elsewhere does not resize the other panes", function()
  vim.o.columns = 300
  open(2)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  reading.enable(wins[1])
  local other_before = vim.api.nvim_win_get_width(wins[2])
  vim.api.nvim_set_current_win(wins[2])
  vim.cmd("split " .. V.root .. "/N/3.md")  -- horizontal: must not steal columns
  vim.wait(200)
  t.eq(vim.api.nvim_win_get_width(wins[2]), other_before, "untouched pane kept its width")
  reading.disable_all()
end)

t.it("splitting a centred pane drops its centring instead of half-centring it", function()
  vim.o.columns = 300
  open(1)
  reading.enable()
  local win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit " .. V.root .. "/N/2.md")
  vim.wait(300)
  t.ok(not reading.is_active(win), "centring dropped")
  local _, pad = layout()
  t.eq(#pad, 0, "no pads left flanking a half-width pane")
end)

t.it("centring any pane leaves every other pane exactly as it was", function()
  vim.o.columns = 300
  for idx = 1, 3 do
    open(3)
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local before = {}
    for _, w in ipairs(wins) do
      before[w] = vim.api.nvim_win_get_width(w)
    end

    reading.enable(wins[idx])
    t.eq(vim.api.nvim_win_get_width(wins[idx]), 80, "pane " .. idx .. " centred")
    for i, w in ipairs(wins) do
      if i ~= idx then
        t.eq(vim.api.nvim_win_get_width(w), before[w],
          "pane " .. i .. " untouched while centring " .. idx)
      end
    end
    reading.disable_all()
  end
end)

t.it("resizing a centred pane moves the split, not the text column", function()
  vim.o.columns = 300
  open(2)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  reading.enable(wins[1])
  local other = vim.api.nvim_win_get_width(wins[2])

  vim.api.nvim_set_current_win(wins[1])
  reading.resize(-20)
  t.eq(vim.api.nvim_win_get_width(wins[1]), 80, "text column unchanged")
  t.eq(vim.api.nvim_win_get_width(wins[2]), other + 20, "the split boundary moved")

  vim.api.nvim_set_current_win(wins[1])
  reading.resize(20)
  t.eq(vim.api.nvim_win_get_width(wins[2]), other, "and back")
  reading.disable_all()
end)

t.it("declines a pane too narrow to centre", function()
  -- 80 target + 2 separators + 2x4 minimum padding needs 90 columns.
  vim.o.columns = 86
  open(1)
  t.ok(not reading.enable(nil, true), "declined")
  local _, pad = layout()
  t.eq(#pad, 0)
end)

t.it("enabling twice on one pane does not stack pads", function()
  vim.o.columns = 220
  open(1)
  reading.enable()
  reading.enable()
  local _, pad = layout()
  t.eq(#pad, 2)
  reading.disable_all()
end)

t.it("disable_all clears everything", function()
  vim.o.columns = 300
  open(2)
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    reading.enable(w)
  end
  reading.disable_all()
  local _, pad = layout()
  t.eq(#pad, 0)
  t.eq(vim.tbl_count(reading.panes), 0)
end)

t.describe("reading mode: keeping files out of the margins")

-- The bug this covers: a picker `:edit`s into whatever window has focus. If
-- that's a padding window, the chapter loads at margin width -- and replacing
-- the buffer takes the `readingpad` filetype with it, so afterwards nothing
-- can tell the window was ever a pad and the narrow view sticks.
-- While a pane is tracked you cannot even come to rest in its margin: the
-- WinEnter guard moves you straight back out. So the reachable form of the bug
-- is an ORPHANED pad, which is the next test.
t.it("the WinEnter guard refuses to leave the cursor in a margin", function()
  vim.o.columns = 220
  open(1)
  local text = vim.api.nvim_get_current_win()
  t.ok(reading.enable(text), "centred")

  vim.api.nvim_set_current_win(reading.panes[text].left)
  t.ok(not reading.is_pad(vim.api.nvim_get_current_win()), "bounced out again")

  vim.cmd("edit " .. V.root .. "/N/2.md")
  t.eq(vim.api.nvim_win_get_width(0), reading.width, "the file opened at full width")
  reading.disable_all()
end)

-- A dead condition in reload.lua checked `reading.state.active` for a while.
-- It never existed, so `:Reload` orphaned the pads and silently disabled both
-- of the guards above. Pin the name the state actually has.
t.it("exposes its state as `panes`, which reload.lua checks", function()
  t.eq(reading.state, nil, "there is no `state` table")
  t.eq(type(reading.panes), "table")
  t.eq(type(reading.disable_all), "function")
end)

t.it("stays put when the cursor is already in a real window", function()
  vim.o.columns = 220
  open(1)
  reading.enable()
  local win = vim.api.nvim_get_current_win()
  t.eq(reading.leave_pad(), false, "no move needed")
  t.eq(vim.api.nvim_get_current_win(), win)
  reading.disable_all()
end)

t.it("escapes a pad whose pane is no longer tracked", function()
  vim.o.columns = 220
  open(1)
  local text = vim.api.nvim_get_current_win()
  reading.enable(text)
  local pad = reading.panes[text].left

  -- What a `:Reload` used to leave behind: pads on screen, panes forgotten.
  reading.panes = {}
  vim.api.nvim_set_current_win(pad)

  t.ok(reading.leave_pad(), "found somewhere real to go")
  t.ok(not reading.is_pad(vim.api.nvim_get_current_win()), "out of the margin")

  -- And the dead margins go with it. Nothing owns them any more, so nothing
  -- would ever have closed them; they'd sit there until the session ended.
  local _, pad = layout()
  t.eq(#pad, 0, "swept the orphans")
end)

t.it("keeps the margins of panes that are still tracked", function()
  vim.o.columns = 300
  open(2)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  reading.enable(wins[1])
  reading.enable(wins[2])

  -- Orphan ONE pane's pads. The other pane is still centred, so the WinEnter
  -- guard is live and won't let the cursor rest in the orphan at all -- the
  -- sweep has to happen anyway, and must take only the two dead margins.
  local orphan = reading.panes[wins[1]]
  reading.panes[wins[1]] = nil
  vim.api.nvim_set_current_win(orphan.left)

  t.ok(reading.leave_pad(), "swept")
  local _, pad = layout()
  t.eq(#pad, 2, "only the orphans were closed")
  t.ok(reading.is_active(wins[2]), "the live pane is untouched")
  reading.disable_all()
end)

V.destroy()
