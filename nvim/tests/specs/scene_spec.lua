local t = require("tests.harness")
local V = require("tests.vault")
local scene = require("writing.scene")
local draft = require("writing.draft")

t.describe("scenes")

V.create({
  ["N/1 - Opening.md"] = "Chapter one.",
  ["N/refs.md"] = "See [[1 - Opening]] and [[1 - Opening|the start]].",
  ["N/Index.md"] = V.index("Test", { "1 - Opening" }),
  [".scriptorium/Scene.md"] = "---\ncharacters:\n---\n",
})

local function scenes()
  return draft.read(V.root .. "/N/Index.md").scenes
end

t.it("creates a chapter from the template and lists it", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1 - Opening.md")
  scene.create("2 - The Second")
  t.eq(scenes(), { "1 - Opening", "2 - The Second" }, "added to the scene list")
  t.eq(vim.fn.filereadable(V.root .. "/N/2 - The Second.md"), 1, "file created")
  t.matches(table.concat(vim.fn.readfile(V.root .. "/N/2 - The Second.md"), "\n"),
    "characters:", "used the template")
end)

t.it("refuses to create a duplicate", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1 - Opening.md")
  scene.create("2 - The Second")
  t.eq(#scenes(), 2, "scene list unchanged")
end)

t.describe("rename decisions")

t.it("a listed scene renames the file AND the draft", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1 - Opening.md")
  local plan = scene.plan(0)
  t.eq(plan.kind, "scene")
  t.eq(plan.old, "1 - Opening")
  t.matches(plan.index, "Index%.md$")
end)

t.it("an unlisted file in the draft folder is an ordinary note rename", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/refs.md")
  t.eq(scene.plan(0).kind, "note", "refs.md isn't in the scene list")
end)

t.it("a note outside any draft is an ordinary rename", function()
  V.reset()
  vim.fn.writefile({ "loose" }, V.root .. "/loose.md")
  vim.cmd("edit " .. V.root .. "/loose.md")
  local plan = scene.plan(0)
  t.eq(plan.kind, "note")
  t.eq(plan.index, nil, "no draft above it")
end)

t.it("a buffer with no file is an error, not a crash", function()
  V.reset()
  vim.cmd("enew")
  t.eq(scene.plan(0).kind, "error")
end)

t.describe("scene index rewriting")

t.it("retitles a scene in the index, preserving everything else", function()
  local index = V.root .. "/N/Index.md"
  vim.fn.writefile(vim.split(table.concat({
    "---", "longform:", "  format: scenes", "  title: Test", "  sceneFolder: /",
    "  scenes:", "    - 1 - Opening", "    - 2 - The Second",
    "  ignoredFiles:", "    - notes",
    "compile:", "  output: out.md", "---",
  }, "\n"), "\n"), index)

  t.ok(scene.retitle(index, "1 - Opening", "1 - A Falling Star"), "entry found")
  local after = table.concat(vim.fn.readfile(index), "\n")
  t.matches(after, "    %- 1 %- A Falling Star", "entry rewritten")
  t.ok(not after:find("1 %- Opening"), "old title gone")
  t.matches(after, "    %- 2 %- The Second", "sibling untouched")
  t.matches(after, "  ignoredFiles:", "ignoredFiles untouched")
  t.matches(after, "compile:", "compile block untouched")
  t.eq(draft.read(index).scenes, { "1 - A Falling Star", "2 - The Second" })
end)

t.it("reports when the scene isn't listed", function()
  t.ok(not scene.retitle(V.root .. "/N/Index.md", "nope", "x"), "returns false")
end)

-- The full rename goes through obsidian-ls, which only registers workspaces
-- found under ~/Writing when it loads -- a vault created mid-run isn't one.
-- The index half is covered above; this exercises the whole path when it can.
local function wait_for_lsp(bufnr)
  return vim.wait(15000, function()
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
      if c.name == "obsidian-ls" then
        return true
      end
    end
  end, 200)
end

V.reset()
vim.cmd("edit " .. V.root .. "/N/1 - Opening.md")
if not wait_for_lsp(vim.api.nvim_get_current_buf()) then
  t.skip("renames a chapter and updates the scene list", "obsidian-ls did not attach")
  t.skip("rewrites wikilinks when renaming", "obsidian-ls did not attach")
else
  vim.wait(1500)
  scene.rename("1 - A Falling Star")

  t.it("renames a chapter and updates the scene list", function()
    t.eq(scenes()[1], "1 - A Falling Star", "scene list updated")
    t.eq(vim.fn.filereadable(V.root .. "/N/1 - A Falling Star.md"), 1, "file renamed")
    t.eq(vim.fn.filereadable(V.root .. "/N/1 - Opening.md"), 0, "old file gone")
  end)

  t.it("rewrites wikilinks when renaming", function()
    local refs = table.concat(vim.fn.readfile(V.root .. "/N/refs.md"), "\n")
    t.matches(refs, "%[%[1 %- A Falling Star%]%]", "plain link rewritten")
    t.matches(refs, "%[%[1 %- A Falling Star|the start%]%]", "aliased link rewritten")
  end)
end

V.destroy()
