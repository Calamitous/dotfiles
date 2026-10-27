local t = require("tests.harness")
local V = require("tests.vault")

t.describe(":Reload")

V.create({ ["N/1.md"] = "One.", ["N/2.md"] = "Two." })

local function pads()
  local n = 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "readingpad" then
      n = n + 1
    end
  end
  return n
end

-- A reload clears `package.loaded`, so the module the spec holds afterwards is
-- a stale table: the live state belongs to whatever `require` hands back now.
local function fresh()
  return require("writing.reading")
end

-- Source something harmless instead of the real config. The config is
-- idempotent, but re-running it mid-suite would re-register every command and
-- autocmd around the specs still to come.
local stub = V.root .. "/stub-init.lua"
vim.fn.writefile({ "vim.g.reload_stub = (vim.g.reload_stub or 0) + 1" }, stub)

local function reload()
  local was = vim.env.MYVIMRC
  vim.env.MYVIMRC = stub
  require("core.reload").reload()
  vim.env.MYVIMRC = was
end

t.it("puts the margins back on a pane that was centred", function()
  vim.o.columns = 220
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  vim.cmd("wincmd =")  -- a headless nvim doesn't apply `columns` to the layout
                       -- until something asks it to; without this the pane is
                       -- still 80 wide and there is nothing to centre.
  local win = vim.api.nvim_get_current_win()
  t.ok(fresh().enable(win), "centred to begin with")
  t.eq(pads(), 2, "two margins before")

  reload()

  t.ok(vim.g.reload_stub and vim.g.reload_stub > 0, "the reload really ran")
  t.ok(vim.api.nvim_win_is_valid(win), "the window itself survived")
  t.ok(fresh().is_active(win), "still tracked as centred")
  t.eq(vim.api.nvim_win_get_width(win), fresh().width, "still 80 columns")
  t.eq(pads(), 2, "exactly two margins after -- not four, not none")

  fresh().disable_all()
end)

t.it("leaves an uncentred pane alone", function()
  vim.o.columns = 220
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/2.md")
  vim.cmd("wincmd =")
  local win = vim.api.nvim_get_current_win()
  local before = vim.api.nvim_win_get_width(win)

  reload()

  t.eq(pads(), 0, "nothing centred, nothing to restore")
  t.eq(vim.api.nvim_win_get_width(win), before, "width untouched")
  t.eq(vim.tbl_count(fresh().panes), 0)
end)

V.destroy()
