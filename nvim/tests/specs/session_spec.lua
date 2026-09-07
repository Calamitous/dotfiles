local t = require("tests.harness")
local V = require("tests.vault")
local session = require("writing.session")

t.describe("sessions")

V.create({
  ["N/1.md"] = "One.",
  ["N/2.md"] = "Two.",
  ["N/Index.md"] = V.index("Test", { "1", "2" }),
})

local function session_text()
  return table.concat(vim.fn.readfile((session.path(V.root))), "\n")
end

t.it("saves a split layout", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  vim.cmd("vsplit " .. V.root .. "/N/2.md")
  t.ok(session.save(V.root), "save returned true")
  t.matches(session_text(), "badd", "session lists buffers")
end)

t.it("writes NO absolute paths -- this is what makes it portable", function()
  local text = session_text()
  t.ok(not text:find("/home/", 1, true), "no /home/")
  t.ok(not text:find("/Users/", 1, true), "no /Users/")
  t.ok(not text:find("~/", 1, true), "no ~/")
  t.matches(text, "%.%./N/1%.md", "paths relative to the session file")
end)

t.it("restores the files and the split", function()
  V.reset()
  t.ok(session.restore(V.root), "restore returned true")
  local names = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    table.insert(names, vim.fs.basename(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))))
  end
  table.sort(names)
  t.eq(names, { "1.md", "2.md" })
end)

t.it("leaves the cwd at the vault root, not .scriptorium", function()
  t.eq(vim.uv.cwd(), V.root)
end)

t.it("excludes buffers from outside the vault", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  vim.fn.writefile({ "outside" }, "/tmp/scriptorium-outside.md")
  vim.cmd("badd /tmp/scriptorium-outside.md")
  session.save(V.root)
  t.ok(not session_text():find("scriptorium%-outside"), "foreign buffer not saved")
  vim.fn.delete("/tmp/scriptorium-outside.md")
end)

t.it("drops scenes whose file has since disappeared", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  vim.cmd("vsplit " .. V.root .. "/N/2.md")
  session.save(V.root)
  vim.fn.delete(V.root .. "/N/2.md")
  V.reset()
  session.restore(V.root)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(b)
    t.ok(not name:match("/N/2%.md$"), "no phantom buffer for the deleted file")
  end
  vim.fn.writefile({ "Two." }, V.root .. "/N/2.md")
end)

t.it("will not overwrite a good session with an empty one", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  vim.cmd("vsplit " .. V.root .. "/N/2.md")
  session.save(V.root)
  local good = session_text()
  t.matches(good, "badd", "a real session to protect")

  V.reset() -- no files open, as if you opened nvim and quit again
  t.ok(not session.save(V.root), "save declined")
  t.eq(session_text(), good, "the saved session is untouched")
end)

t.it("deletes cleanly", function()
  session.delete(V.root)
  t.eq(vim.fn.filereadable((session.path(V.root))), 0)
end)

V.destroy()
