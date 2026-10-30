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

-- Until WinResized was listened for, a width that changed without any window
-- opening or closing was never re-measured: the pane sat at whatever it had
-- drifted to for the rest of the session.
t.it("re-measures after a width change with no window opening or closing", function()
  vim.o.columns = 220
  open(1)
  local win = vim.api.nvim_get_current_win()
  t.ok(reading.enable(win), "centred")

  vim.api.nvim_win_set_width(win, 60)
  t.eq(vim.api.nvim_win_get_width(win), 60, "narrowed, as a stray resize would")
  vim.cmd("doautocmd WinResized")
  vim.wait(300)

  t.ok(reading.is_active(win), "still centred")
  t.eq(vim.api.nvim_win_get_width(win), reading.width, "and back to 80")
  reading.disable_all()
end)

-- `:edit` loses the window-local `fillchars`, which is what blends the margins
-- and hides the end-of-buffer markers; a filetype that wants a number or sign
-- column narrows the text from the inside without touching the width.
t.it("re-asserts its window options when a file is opened into the pane", function()
  vim.o.columns = 220
  open(1)
  local win = vim.api.nvim_get_current_win()
  t.ok(reading.enable(win), "centred")
  local want = vim.wo[win].fillchars
  t.matches(want, "eob:", "reading mode set fillchars to begin with")

  vim.wo[win].fillchars = ""
  vim.wo[win].number = true
  vim.cmd("edit " .. V.root .. "/N/2.md")
  vim.wait(300)

  t.eq(vim.wo[win].fillchars, want, "fillchars back")
  t.eq(vim.wo[win].number, false, "and no number column eating into the 80")
  reading.disable_all()
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

t.describe("reading mode: the typewriter platen")

-- One line per paragraph, soft-wrapped over several screen rows: the shape of
-- every file in the vault, and the case that breaks `topline` arithmetic.
local PARAS = {}
for i = 1, 60 do
  PARAS[i] = ("Paragraph %d. "):format(i) .. string.rep("word ", 60)
end
V.create({ ["N/1.md"] = "One.", ["N/2.md"] = "Two.", ["N/3.md"] = "Three.",
  ["N/long.md"] = table.concat(PARAS, "\n") })

local function centre_of(win)
  return math.ceil(vim.api.nvim_win_get_height(win) / 2)
end

local function open_long()
  reading.disable_all()
  vim.wait(50)
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/long.md")
  vim.cmd("wincmd =")
  vim.o.wrap = true
  vim.o.linebreak = true
end

t.it("holds the cursor on the middle row at the end of the file", function()
  vim.o.columns = 220
  open_long()
  local win = vim.api.nvim_get_current_win()
  t.ok(reading.enable(win), "centred")

  vim.cmd("normal! G")
  reading.centre_cursor(win)
  t.eq(vim.fn.line("."), vim.fn.line("$"), "on the last line")
  t.eq(vim.fn.winline(), centre_of(win), "and on the middle row")
  reading.disable_all()
end)

-- scrolloff, at any value, gives up here: there is nothing below the last line
-- to scroll into view, so the cursor walks down to the bottom row instead.
t.it("does what scrolloff cannot", function()
  vim.o.columns = 220
  open_long()
  local win = vim.api.nvim_get_current_win()

  vim.wo[win].scrolloff = 999
  vim.cmd("normal! gg")
  for _ = 1, 400 do
    vim.cmd("normal! gj")
  end
  local without = vim.fn.winline()

  t.ok(reading.enable(win), "centred")
  vim.cmd("normal! G")
  reading.centre_cursor(win)

  t.ok(without > centre_of(win), "scrolloff alone left the cursor below the middle")
  t.eq(vim.fn.winline(), centre_of(win), "the platen holds it there")
  reading.disable_all()
end)

t.it("does not sawtooth through wrapped paragraphs", function()
  vim.o.columns = 220
  open_long()
  local win = vim.api.nvim_get_current_win()
  t.ok(reading.enable(win), "centred")
  local want = centre_of(win)

  -- Walk down by DISPLAY line, as prose mode's j does. Ignore the ramp-up: the
  -- first screenful can't be centred, because there's nothing above it.
  vim.cmd("normal! gg")
  local rows, settled = {}, false
  for _ = 1, 120 do
    vim.cmd("normal! gj")
    reading.centre_cursor(win)
    local row = vim.fn.winline()
    settled = settled or row == want
    if settled then
      table.insert(rows, row)
    end
  end

  t.ok(#rows > 40, "walked well past the first screenful (" .. #rows .. " rows)")
  local drift = 0
  for _, row in ipairs(rows) do
    drift = math.max(drift, math.abs(row - want))
  end
  t.eq(drift, 0, "every row was the middle one -- no sawtooth")
  reading.disable_all()
end)

t.it("gives scrolloff and smoothscroll back on toggle off", function()
  vim.o.columns = 220
  open_long()
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].scrolloff = 5
  vim.wo[win].smoothscroll = false

  t.ok(reading.enable(win), "centred")
  t.eq(vim.wo[win].scrolloff, 0, "scrolloff out of the way while centring")
  t.eq(vim.wo[win].smoothscroll, true, "scrolling by screen row")

  reading.disable(win)
  t.eq(vim.wo[win].scrolloff, 5, "scrolloff back")
  t.eq(vim.wo[win].smoothscroll, false, "smoothscroll back")
end)

t.it("leaves scrolling alone when the platen is off", function()
  vim.o.columns = 220
  open_long()
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].scrolloff = 5

  reading.typewriter = false
  t.ok(reading.enable(win), "centred")
  t.eq(vim.wo[win].scrolloff, 5, "scrolloff untouched")
  t.eq(reading.centre_cursor(win), false, "and nothing is centred")

  -- Still restored correctly, even though the typewriter never applied.
  reading.disable(win)
  t.eq(vim.wo[win].scrolloff, 5)
  reading.typewriter = true
end)

t.it("ignores panes it isn't centring", function()
  vim.o.columns = 220
  open_long()
  local win = vim.api.nvim_get_current_win()
  t.eq(reading.centre_cursor(win), false, "not a centred pane")
  reading.enable(win)
  vim.cmd("normal! G")
  t.ok(reading.centre_cursor(win), "centred pane, cursor off the middle")
  t.eq(reading.centre_cursor(win), false, "already on the middle row")
  reading.disable_all()
end)

t.it("leaves 'virtualedit' exactly as it found it", function()
  vim.o.columns = 220
  open_long()
  local win = vim.api.nvim_get_current_win()
  reading.enable(win)
  vim.cmd("normal! G")

  vim.wo[win].virtualedit = "block"
  t.ok(reading.centre_cursor(win), "scrolled")
  t.eq(vim.wo[win].virtualedit, "block", "restored after the scroll")

  vim.wo[win].virtualedit = ""
  vim.cmd("normal! gg")
  reading.centre_cursor(win)
  t.eq(vim.wo[win].virtualedit, "", "and restored when it was unset")
  reading.disable_all()
end)

-- The regression this guards is `A` appending before the last letter instead of
-- after it: the platen's `:normal!` runs under normal-mode rules, which refuse
-- to leave the cursor past end-of-line, so it used to drag the column back one.
--
-- It cannot be reproduced in-process. `nvim -l` has no input loop, so
-- CursorMovedI never fires at all, and feedkeys() with the flags that would
-- hold insert mode trips a grid assertion in headless neovim. Hence a child
-- neovim driven by `-s`, which replays the keys through the same path a typed
-- `A` takes.
local function append_at_eol()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")

  local para = {}
  for i = 1, 30 do
    para[i] = ("P%d. "):format(i) .. string.rep("word ", 60) .. "final"
  end
  vim.fn.writefile(para, dir .. "/prose.md")

  vim.fn.writefile({
    ("vim.opt.runtimepath:prepend(%q)"):format(root),
    "vim.o.lines, vim.o.columns = 40, 220",
    'require("writing.reading").setup()',
    -- <C-g>c stands in for the CursorMovedI the platen listens on: the same
    -- module call in the same insert mode, but synchronous, so the key replay
    -- cannot race it.
    'vim.keymap.set("i", "<C-g>c", function() require("writing.reading").centre_cursor() end)',
    'vim.api.nvim_create_autocmd("VimEnter", { callback = function()',
    '  vim.cmd("wincmd =")',
    '  require("writing.reading").enable()',
    "  vim.api.nvim_win_set_cursor(0, { 15, 10 })",
    "end })",
  }, dir .. "/init.lua")

  -- Raw bytes, written with "b" so nothing is appended: \7 is <C-g>, \27 is
  -- <Esc>, \13 is <CR>.
  vim.fn.writefile({ "A\7cXX\27:w!\13:qa!\13" }, dir .. "/keys", "b")

  vim.fn.system({
    vim.v.progpath,
    "--clean",
    "--headless",
    "-u",
    dir .. "/init.lua",
    "-s",
    dir .. "/keys",
    dir .. "/prose.md",
  })

  local line = (vim.fn.readfile(dir .. "/prose.md") or {})[15]
  vim.fn.delete(dir, "rf")
  return line
end

local NAME = "`A` appends after the last letter, not before it"
if vim.fn.executable(vim.v.progpath) ~= 1 then
  t.skip(NAME, "no neovim binary to drive")
else
  t.it(NAME, function()
    t.matches(append_at_eol(), "finalXX$", "typed text landed at the end of the line")
  end)
end

V.destroy()
