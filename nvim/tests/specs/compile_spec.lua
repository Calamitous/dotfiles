local t = require("tests.harness")
local V = require("tests.vault")

t.describe("compile.rb")

local script = vim.fn.expand("~/.local/bin/compile.rb")

local function run(args, cwd)
  local cmd = { "ruby", script }
  vim.list_extend(cmd, args)
  local res = vim.system(cmd, { cwd = cwd or (V.root .. "/N"), text = true }):wait()
  return (res.stdout or "") .. (res.stderr or ""), res.code
end

local function index(steps)
  return table.concat({
    "---", "longform:", "  format: scenes", "  title: Test", "  sceneFolder: /",
    "  scenes:", "    - a", "    - b",
    "compile:", "  output: out.md", "  steps:", steps, "---",
  }, "\n")
end

if vim.fn.filereadable(script) == 0 then
  t.skip("all compile tests", "compile.rb not installed")
  return
end

V.create({ ["N/a.md"] = "Word one.", ["N/b.md"] = "Word two." })

t.it("builds a manuscript", function()
  vim.fn.writefile(vim.split(index('    - strip_frontmatter\n    - concatenate: "\\n\\n"'), "\n"), V.root .. "/N/Index.md")
  local out, code = run({})
  t.eq(code, 0, out)
  t.matches(out, "2 scenes")
  t.matches(table.concat(vim.fn.readfile(V.root .. "/N/out.md"), "\n"), "Word one.")
end)

t.it("rejects a scene step placed after the join", function()
  vim.fn.writefile(vim.split(index('    - concatenate: "\\n"\n    - prepend_title: "# $title"'), "\n"), V.root .. "/N/Index.md")
  local out, code = run({})
  t.ok(code ~= 0, "should fail")
  t.matches(out, "cannot run after the join")
end)

t.it("rejects a pipeline with no join step", function()
  vim.fn.writefile(vim.split(index("    - strip_frontmatter"), "\n"), V.root .. "/N/Index.md")
  local out, code = run({})
  t.ok(code ~= 0, "should fail")
  t.matches(out, "no join step")
end)

t.it("rejects two join steps", function()
  vim.fn.writefile(vim.split(index('    - concatenate: "\\n"\n    - concatenate: "\\n"'), "\n"), V.root .. "/N/Index.md")
  local out, code = run({})
  t.ok(code ~= 0, "should fail")
  t.matches(out, "exactly one")
end)

t.it("--steps labels each step by kind", function()
  vim.fn.writefile(vim.split(index('    - strip_frontmatter\n    - concatenate: "\\n"\n    - msword_hrs'), "\n"), V.root .. "/N/Index.md")
  local out = run({ "--steps" })
  t.matches(out, "scene%s+strip_frontmatter")
  t.matches(out, "join%s+concatenate")
  t.matches(out, "document%s+msword_hrs")
  t.matches(out, "Available steps")
end)

t.it("refuses to guess between several drafts", function()
  vim.fn.mkdir(V.root .. "/M", "p")
  vim.fn.writefile({ "x" }, V.root .. "/M/a.md")
  vim.fn.writefile(vim.split(V.index("Second", { "a" }), "\n"), V.root .. "/M/Index.md")
  local out, code = run({}, V.root)
  t.ok(code ~= 0, "should refuse")
  t.matches(out, "nothing to choose between them")
  vim.fn.delete(V.root .. "/M", "rf")
end)

t.it("formats counts with thousands separators", function()
  local body = {}
  for _ = 1, 700 do table.insert(body, "word word word") end
  vim.fn.writefile(body, V.root .. "/N/a.md")
  vim.fn.writefile(vim.split(index('    - strip_frontmatter\n    - concatenate: "\\n\\n"'), "\n"), V.root .. "/N/Index.md")
  local out = run({})
  t.matches(out, "%d,%d%d%d words")
end)

V.destroy()


t.describe("scriptorium front end")

local front = vim.fn.exepath("scriptorium")

local function sc(args, cwd)
  local cmd = { front }
  vim.list_extend(cmd, args)
  local res = vim.system(cmd, { cwd = cwd or (V.root .. "/N"), text = true }):wait()
  return (res.stdout or "") .. (res.stderr or ""), res.code
end

if front == "" then
  t.skip("dispatches to the underlying scripts", "scriptorium not on PATH")
else
  V.create({ ["N/a.md"] = "Word one.", ["N/b.md"] = "Word two." })
  vim.fn.writefile(vim.split(table.concat({
    "---", "longform:", "  format: scenes", "  title: Test", "  sceneFolder: /",
    "  scenes:", "    - a", "    - b",
    "compile:", "  output: out.md", "  steps:",
    "    - strip_frontmatter", '    - concatenate: "\\n\\n"', "---",
  }, "\n"), "\n"), V.root .. "/N/Index.md")

  t.it("shows usage with no arguments", function()
    local out, code = sc({})
    t.eq(code, 0)
    t.matches(out, "scriptorium init")
    t.matches(out, "scriptorium compile")
  end)

  t.it("rejects an unknown command", function()
    local out, code = sc({ "bogus" })
    t.ok(code ~= 0, "non-zero exit")
    t.matches(out, "unknown command")
  end)

  t.it("dispatches compile", function()
    local out, code = sc({ "compile" })
    t.eq(code, 0, out)
    t.matches(out, "2 scenes")
  end)

  t.it("dispatches steps", function()
    t.matches(sc({ "steps" }), "Available steps")
  end)

  t.it("dispatches drafts", function()
    t.matches(sc({ "drafts" }), "Test")
  end)

  t.it("dispatches init", function()
    t.matches(sc({ "init", "--dry-run" }, V.root), "dry run")
  end)

  V.destroy()
end
