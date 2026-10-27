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

--- `output` defaults to out.md; pass a string for a different one, or `false`
--- for a draft with no `output:` key at all.
local function index(steps, output)
  local lines = {
    "---", "longform:", "  format: scenes", "  title: Test", "  sceneFolder: /",
    "  scenes:", "    - a", "    - b",
    "compile:",
  }
  if output ~= false then
    table.insert(lines, "  output: " .. (output or "out.md"))
  end
  vim.list_extend(lines, { "  steps:", steps, "---" })
  return table.concat(lines, "\n")
end

local PIPELINE = '    - strip_frontmatter\n    - concatenate: "\\n\\n"'

--- Write an Index.md for the test draft and return the two scenes to a known state.
local function draft(steps, output)
  vim.fn.writefile({ "Word one." }, V.root .. "/N/a.md")
  vim.fn.writefile({ "Word two." }, V.root .. "/N/b.md")
  vim.fn.writefile(vim.split(index(steps or PIPELINE, output), "\n"), V.root .. "/N/Index.md")
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

t.describe("where the manuscript goes")

-- `output:` is resolved against the DRAFT folder, not the working directory --
-- the two coincide in every other test here, which is exactly why this one
-- passes an explicit Index.md and runs from somewhere else.
t.it("resolves a relative output against the draft, not the cwd", function()
  draft()
  vim.fn.delete(V.root .. "/out.md")
  local out, code = run({ V.root .. "/N/Index.md" }, V.root)
  t.eq(code, 0, out)
  t.eq(vim.fn.filereadable(V.root .. "/N/out.md"), 1, "landed beside Index.md")
  t.eq(vim.fn.filereadable(V.root .. "/out.md"), 0, "not in the cwd")
end)

t.it("reports the path relative to the vault, not a bare filename", function()
  draft()
  local out = run({ V.root .. "/N/Index.md" }, V.root)
  t.matches(out, "N/out%.md", "says which folder it went to")
end)

t.it("accepts an absolute output path", function()
  vim.fn.mkdir(V.root .. "/Renders", "p")
  draft(nil, V.root .. "/Renders/abs.md")
  local out, code = run({})
  t.eq(code, 0, out)
  t.matches(table.concat(vim.fn.readfile(V.root .. "/Renders/abs.md"), "\n"), "Word one.")
end)

t.it("expands ~ in an output path", function()
  vim.fn.mkdir(V.root .. "/Renders", "p")
  -- The test vault lives under ~/Writing, so this is a real tilde path.
  draft(nil, "~/Writing/" .. vim.fs.basename(V.root) .. "/Renders/tilde.md")
  local out, code = run({})
  t.eq(code, 0, out)
  t.eq(vim.fn.filereadable(V.root .. "/Renders/tilde.md"), 1, "~ resolved to $HOME")
end)

t.it("refuses to create a missing directory, and says so cleanly", function()
  draft(nil, "Nowhere/out.md")
  local out, code = run({})
  t.ok(code ~= 0, "should fail")
  t.matches(out, "no such directory")
  t.matches(out, "Nowhere", "names the directory")
  t.ok(not out:find("compile%.rb:%d"), "a message, not a Ruby backtrace: " .. out)
end)

t.it("refuses to compile over one of its own chapters", function()
  draft(nil, "a.md")
  local out, code = run({})
  t.ok(code ~= 0, "should fail")
  t.matches(out, "overwrite a chapter")
  t.matches(table.concat(vim.fn.readfile(V.root .. "/N/a.md"), "\n"), "Word one.", "chapter intact")
end)

-- With no `output:` of its own, a draft goes wherever Longform would have put
-- it, so the two tools agree with nothing configured.
local function longform_data(target)
  local dir = V.root .. "/.obsidian/plugins/longform"
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.json.encode({
    workflows = {
      ["Default Workflow"] = {
        steps = {
          { id = "strip-frontmatter" },
          { id = "write-to-note", optionValues = { target = target } },
        },
      },
    },
  }) }, dir .. "/data.json")
  return dir .. "/data.json"
end

local function no_longform_data()
  vim.fn.delete(V.root .. "/.obsidian/plugins", "rf")
end

-- The target is relative to the draft folder, and this test draft sits one
-- level down (`N/`) where the real books sit two (`Novels/Volume 1/`) -- so one
-- `../` here is the equivalent of Longform's `../../Renders/$1`.
t.it("falls back to Longform's write-to-note target", function()
  vim.fn.mkdir(V.root .. "/Renders", "p")
  longform_data("../Renders/$1")
  draft(nil, false)
  local out, code = run({})
  t.eq(code, 0, out)
  t.eq(vim.fn.filereadable(V.root .. "/Renders/Test.md"), 1, "$1 became the title, .md appended")
  t.matches(out, "Renders/Test%.md")
  t.matches(run({ "--steps" }), "write%-to%-note", "--steps says where the path came from")
end)

t.it("appends .md only when the target lacks it", function()
  vim.fn.mkdir(V.root .. "/Renders", "p")
  longform_data("../Renders/Named.md")
  draft(nil, false)
  local out, code = run({})
  t.eq(code, 0, out)
  t.eq(vim.fn.filereadable(V.root .. "/Renders/Named.md"), 1, "no double extension")
  t.eq(vim.fn.filereadable(V.root .. "/Renders/Named.md.md"), 0)
end)

t.it("an explicit output: beats Longform's target", function()
  vim.fn.mkdir(V.root .. "/Renders", "p")
  longform_data("../Renders/$1")
  vim.fn.delete(V.root .. "/Renders/Test.md")
  draft(nil, "out.md")
  local out, code = run({})
  t.eq(code, 0, out)
  t.eq(vim.fn.filereadable(V.root .. "/N/out.md"), 1, "used the draft's own setting")
  t.eq(vim.fn.filereadable(V.root .. "/Renders/Test.md"), 0, "ignored Longform's")
end)

-- Clears the fixture itself rather than trusting a previous test to tidy up.
t.it("falls back to the draft title when Longform has no settings", function()
  no_longform_data()
  draft(nil, false)
  local out, code = run({})
  t.eq(code, 0, out)
  t.eq(vim.fn.filereadable(V.root .. "/N/Test.md"), 1, "<draft folder>/<title>.md")
end)

if vim.fn.executable("pandoc") == 0 then
  t.skip("names the .docx without clobbering the markdown", "pandoc not installed")
else
  -- An `output:` with no .md suffix used to make the extension substitution a
  -- no-op, so pandoc was handed the markdown as both input and output.
  t.it("names the .docx without clobbering the markdown", function()
    draft(nil, "bare")
    local out, code = run({ "--docx" })
    t.eq(code, 0, out)
    t.eq(vim.fn.filereadable(V.root .. "/N/bare.docx"), 1, "rendered bare.docx")
    t.matches(table.concat(vim.fn.readfile(V.root .. "/N/bare"), "\n"), "Word one.",
      "markdown survived")
  end)
end

t.it("--docx with --check says it did nothing", function()
  draft()
  local out = run({ "--check", "--docx" })
  t.matches(out, "%-%-docx does nothing")
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

  t.it("init creates a vault that doesn't exist yet", function()
    local new = vim.fn.expand("~/Writing/.scriptorium-new-" .. vim.uv.os_getpid())
    vim.fn.delete(new, "rf")

    local out, code = sc({ "init", "--dry-run", new }, V.root)
    t.eq(code, 0, out)
    t.matches(out, "would create")
    t.eq(vim.fn.isdirectory(new), 0, "a dry run writes nothing")

    out, code = sc({ "init", new }, V.root)
    t.eq(code, 0, out)
    t.eq(vim.fn.isdirectory(new .. "/.obsidian"), 1, "made the vault marker")
    t.eq(vim.fn.filereadable(new .. "/.vale.ini"), 1, "and installed the template")

    -- Re-running must change nothing; that's the whole contract of vault-init.
    out = sc({ "init", new }, V.root)
    t.matches(out, "0 created")
    t.matches(out, "10 kept")

    vim.fn.delete(new, "rf")
  end)

  t.it("dispatches draft, and the Index.md it writes compiles", function()
    local dir = V.root .. "/Fresh"
    local out, code = sc({ "draft", "Volume 9", dir }, V.root)
    t.eq(code, 0, out)
    t.matches(out, "create")
    t.eq(vim.fn.filereadable(dir .. "/Index.md"), 1, "wrote an Index.md")

    -- The point of the file: both tools accept it. compile.rb reads the
    -- `longform:` block, so a draft it can't list is a draft Longform can't see
    -- either.
    t.matches(sc({ "drafts" }, dir), "Volume 9")

    vim.fn.writefile({ "First words." }, dir .. "/1 - Opening.md")
    local index = vim.fn.readfile(dir .. "/Index.md")
    for i, line in ipairs(index) do
      if line:match("^  scenes:") then
        index[i] = "  scenes:\n    - 1 - Opening"
      end
    end
    vim.fn.writefile(vim.split(table.concat(index, "\n"), "\n"), dir .. "/Index.md")

    out, code = sc({ "compile" }, dir)
    t.eq(code, 0, out)
    t.matches(out, "Volume 9")
  end)

  t.it("draft refuses to touch a folder that is already a draft", function()
    local dir = V.root .. "/N"  -- has an Index.md from the specs above
    local before = table.concat(vim.fn.readfile(dir .. "/Index.md"), "\n")
    local out, code = sc({ "draft", "Clobber", dir }, V.root)
    t.ok(code ~= 0, "non-zero exit")
    t.matches(out, "already")
    t.eq(table.concat(vim.fn.readfile(dir .. "/Index.md"), "\n"), before, "untouched")
  end)

  t.it("draft needs a vault, and says so", function()
    local outside = vim.fn.tempname()
    local out, code = sc({ "draft", "Nowhere", outside }, V.root)
    t.ok(code ~= 0, "non-zero exit")
    t.matches(out, "not inside an Obsidian vault")
    t.eq(vim.fn.isdirectory(outside), 0, "nothing created")
  end)

  t.it("draft --dry-run writes nothing", function()
    local dir = V.root .. "/Ghost"
    local out, code = sc({ "draft", "--dry-run", "Ghost", dir }, V.root)
    t.eq(code, 0, out)
    t.matches(out, "would create")
    t.eq(vim.fn.isdirectory(dir), 0)
  end)

  t.it("draft copies the vault's workflow name into the new draft", function()
    local plugin = V.root .. "/.obsidian/plugins/longform"
    vim.fn.mkdir(plugin, "p")
    vim.fn.writefile({ '{"workflows":{"Only Workflow":{"steps":[]}}}' }, plugin .. "/data.json")

    local dir = V.root .. "/Flowed"
    local out = sc({ "draft", "Flowed", dir }, V.root)
    t.matches(out, "Only Workflow")
    t.matches(table.concat(vim.fn.readfile(dir .. "/Index.md"), "\n"), "workflow: Only Workflow")

    vim.fn.delete(plugin, "rf")
  end)

  t.it("bare vault-init still refuses to create one", function()
    local script = vim.fn.exepath("vault-init")
    if script == "" then
      return
    end
    local gone = vim.fn.expand("~/Writing/.scriptorium-absent-" .. vim.uv.os_getpid())
    local res = vim.system({ script, gone }, { text = true }):wait()
    t.ok(res.code ~= 0, "non-zero exit")
    t.matches((res.stdout or "") .. (res.stderr or ""), "pass %-%-create")
    t.eq(vim.fn.isdirectory(gone), 0, "nothing created")
  end)

  V.destroy()
end
