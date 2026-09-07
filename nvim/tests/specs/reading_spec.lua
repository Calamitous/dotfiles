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

V.destroy()
