local t = require("tests.harness")
local find = require("writing.find")

t.describe("grep picker")

local cmd = find.grep_command()

t.it("highlights the search term in the preview", function()
  t.matches(cmd, "grep %-%-color=always", "preview colours the query")
  t.matches(cmd, "%-e {q}", "the query is the highlighted pattern")
end)

t.it("marks the term with a background, not the default thin red", function()
  t.matches(cmd, "GREP_COLORS", "sets the grep match colour")
  t.matches(cmd, vim.pesc(find.match_highlight), "uses the configured code")
  t.matches(cmd, 'GREP_COLORS="mt=', "double-quoted, so the semicolons aren\'t shell separators")
end)

t.it("keeps every line in the preview, not just matches", function()
  -- The second pattern matches end-of-line, so nothing is filtered out.
  t.matches(cmd, '%-e \\?"%$\\?"', "second pattern is $")
end)

t.it("centres the preview on the matching line", function()
  t.matches(cmd, "preview%-window=[^ ]*%+{2}%-/2", "scrolls to the hit and centres it")
end)

t.it("re-runs ripgrep as you type", function()
  t.matches(cmd, "change:reload:", "reloads on change")
  t.matches(cmd, "start:reload:", "and on open")
end)

t.it("honours the case setting", function()
  t.matches(cmd, "%-%-ignore%-case", "case-insensitive by default")
  find.ignore_case = false
  t.matches(find.grep_command(), "%-%-smart%-case", "smart-case when flipped")
  find.ignore_case = true
end)

t.it("keeps the split bindings from the vim setup", function()
  t.matches(cmd, "ctrl%-v", "vsplit")
  t.matches(cmd, "ctrl%-x", "split")
  t.matches(cmd, "ctrl%-t", "tab")
end)


t.describe("file-level jumps")

local V = require("tests.vault")
V.create({ ["a.md"] = "aaa\nbbb\nccc\nddd\neee", ["b.md"] = "one\ntwo\nthree" })

t.it("skips jumps made within the same file", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/a.md")
  vim.cmd("normal! G")      -- a jump, same file
  vim.cmd("normal! gg")     -- another, same file
  vim.cmd("edit " .. V.root .. "/b.md")
  vim.cmd("normal! G")      -- and one in the new file

  t.ok(find.jump_file(-1), "jumped back")
  t.matches(vim.api.nvim_buf_get_name(0), "a%.md$", "landed in the previous FILE, not a prior line of b.md")
end)

t.it("reports when there is no earlier file", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/a.md")
  t.ok(not find.jump_file(-1), "nothing to go back to")
end)

V.destroy()
