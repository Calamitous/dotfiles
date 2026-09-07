local t = require("tests.harness")
local V = require("tests.vault")
local comments = require("writing.comments")

V.filetypes()

t.describe("comment highlighting")

V.create({
  ["one.md"] = table.concat({
    "Prose here.",
    "%% a note to self %%",
    "More prose %% inline %% and on.",
    "%% a comment that",
    "spans two lines %%",
    "Done.",
  }, "\n"),
})

local function marks()
  V.reset()
  vim.cmd("edit " .. V.root .. "/one.md")
  comments.refresh(0)
  return vim.api.nvim_buf_get_extmarks(0, comments.ns, 0, -1, { details = true })
end

t.it("marks whole-line comments", function()
  local m = marks()
  t.ok(#m >= 3, "found at least three spans, got " .. #m)
end)

t.it("marks a comment spanning two lines", function()
  local rows = {}
  for _, m in ipairs(marks()) do
    rows[m[2]] = true
  end
  t.ok(rows[3] and rows[4], "both rows of the multi-line comment are marked")
end)

t.it("leaves prose alone", function()
  local rows = {}
  for _, m in ipairs(marks()) do
    rows[m[2]] = true
  end
  t.ok(not rows[0], "line 1 is prose and unmarked")
  t.ok(not rows[5], "last line is prose and unmarked")
end)

V.destroy()
