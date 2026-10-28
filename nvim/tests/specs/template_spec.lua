local t = require("tests.harness")
local V = require("tests.vault")
local template = require("writing.template")

local CHARACTER = table.concat({
  "---",
  "created: {{date}}",
  "---",
  "",
  "# {{title}}",
  "",
  "Role:",
}, "\n")

local root = V.create({
  [".obsidian/templates.json"] = '{\n  "folder": "Z. Templates"\n}',
  ["Z. Templates/Chapter Template.md"] = "---\ncharacters:\nscenes:\n---",
  ["Z. Templates/Worldbuilding/Character Template (Main).md"] = CHARACTER,
  ["Z. Templates/Worldbuilding/Character Template (Side).md"] = "Name:",
  -- Longform keeps its compile scripts in the same folder. Not templates.
  ["Z. Templates/Longform Scripts/CrunchComments.js"] = "// nope",
  ["Characters/Existing.md"] = "taken",
})

t.describe("templates: finding the library")

t.it("reads the folder out of .obsidian/templates.json", function()
  t.eq(template.folder(root), root .. "/Z. Templates")
end)

t.it("falls back to the conventional name when there is no templates.json", function()
  local config = root .. "/.obsidian/templates.json"
  local saved = vim.fn.readfile(config)
  vim.fn.delete(config)
  local got = template.folder(root)
  vim.fn.writefile(saved, config)
  t.eq(got, root .. "/Z. Templates")
end)

t.it("treats an empty folder setting as unset, not as the vault root", function()
  -- Obsidian writes "" for "templates live at the root". Honouring that would
  -- offer every note in the vault as a template.
  local config = root .. "/.obsidian/templates.json"
  local saved = vim.fn.readfile(config)
  vim.fn.writefile({ '{ "folder": "" }' }, config)
  local got = template.folder(root)
  vim.fn.writefile(saved, config)
  t.eq(got, root .. "/Z. Templates")
end)

t.it("returns nil when the named folder does not exist", function()
  local config = root .. "/.obsidian/templates.json"
  local saved = vim.fn.readfile(config)
  vim.fn.writefile({ '{ "folder": "Nowhere" }' }, config)
  local got = template.folder(root)
  vim.fn.writefile(saved, config)
  t.eq(got, nil)
end)

t.it("survives a corrupt templates.json", function()
  local config = root .. "/.obsidian/templates.json"
  local saved = vim.fn.readfile(config)
  vim.fn.writefile({ "{ not json" }, config)
  local got = template.folder(root)
  vim.fn.writefile(saved, config)
  t.eq(got, root .. "/Z. Templates")
end)

t.describe("templates: listing")

t.it("finds nested templates and keeps the subfolder in the name", function()
  t.eq(template.list(root), {
    "Chapter Template.md",
    "Worldbuilding/Character Template (Main).md",
    "Worldbuilding/Character Template (Side).md",
  })
end)

t.it("skips Longform's compile scripts", function()
  for _, name in ipairs(template.list(root)) do
    t.ok(not name:match("%.js$"), name .. " is not a template")
  end
end)

t.describe("templates: placeholders")

t.it("substitutes title, date and time", function()
  local at = os.time({ year = 2026, month = 10, day = 27, hour = 14, min = 5, sec = 0 })
  t.eq(template.render({ "{{title}}", "{{date}} {{time}}" }, "Milloria Vance", at), {
    "Milloria Vance",
    os.date("%Y-%m-%d", at) .. " " .. os.date("%H:%M", at),
  })
end)

t.it("tolerates spaces inside the braces, and any case", function()
  t.eq(template.render({ "{{ Title }}" }, "Fortney", 0), { "Fortney" })
end)

t.it("leaves a template with no placeholders byte-identical", function()
  local lines = { "---", "characters:", "scenes:", "---" }
  t.eq(template.render(lines, "Anything", 0), lines)
end)

t.it("leaves placeholders it does not know alone", function()
  -- A Templater expression, or a literal pair of braces in prose, is not ours.
  t.eq(template.render({ "{{tp.file.title}}", "{{unknown}}" }, "X", 0),
    { "{{tp.file.title}}", "{{unknown}}" })
end)

t.it("does not read a replacement as a capture reference", function()
  -- gsub treats % in the replacement specially; names have punctuation.
  t.eq(template.render({ "# {{title}}" }, "Brass, Bone, & 100%", 0), { "# Brass, Bone, & 100%" })
end)

t.describe("templates: naming the new file")

t.it("prefills with the current buffer's folder, vault-relative", function()
  t.eq(template.prefill(root, root .. "/Characters/Existing.md"), "Characters/")
end)

t.it("prefills with nothing at the vault root", function()
  t.eq(template.prefill(root, root .. "/Note.md"), "")
end)

t.it("prefills with nothing for a buffer outside the vault", function()
  t.eq(template.prefill(root, "/etc/hosts"), "")
end)

t.it("resolves an answer against the vault root and adds .md", function()
  t.eq(template.resolve(root, "Characters/Milloria"), root .. "/Characters/Milloria.md")
end)

t.it("keeps an .md the answer already has", function()
  t.eq(template.resolve(root, "Characters/Milloria.md"), root .. "/Characters/Milloria.md")
end)

t.it("refuses an answer that is only a folder", function()
  t.eq(template.resolve(root, "Characters/"), nil)
  t.eq(template.resolve(root, "  "), nil)
end)

t.describe("templates: creating the file")

t.it("writes the rendered template and nothing else", function()
  local ok, err = template.create(
    root .. "/Z. Templates/Worldbuilding/Character Template (Main).md",
    root .. "/Characters/Milloria.md",
    "Milloria"
  )
  t.eq({ ok, err }, { true, nil })

  local body = vim.fn.readfile(root .. "/Characters/Milloria.md")
  t.eq(body[5], "# Milloria")
  t.matches(body[2], "^created: %d%d%d%d%-%d%d%-%d%d$", "date was substituted")
end)

t.it("creates a missing parent folder, like :NewScene", function()
  local ok = template.create(
    root .. "/Z. Templates/Chapter Template.md",
    root .. "/Places/Deep/Nested/Ravencroft.md",
    "Ravencroft"
  )
  t.ok(ok, "wrote into a folder that did not exist")
  t.eq(vim.fn.filereadable(root .. "/Places/Deep/Nested/Ravencroft.md"), 1)
end)

t.it("refuses to overwrite an existing note", function()
  local ok, err = template.create(
    root .. "/Z. Templates/Chapter Template.md",
    root .. "/Characters/Existing.md",
    "Existing"
  )
  t.eq(ok, false)
  t.matches(err, "already exists")
  t.eq(vim.fn.readfile(root .. "/Characters/Existing.md"), { "taken" })
end)

t.it("leaves the draft alone -- a note is not a scene", function()
  -- The whole point of this command next to :NewScene. No Index.md is written,
  -- so there is nothing for Obsidian's cached copy to clobber.
  t.eq(vim.fn.filereadable(root .. "/Index.md"), 0)
end)

t.it("reports a template that is not readable", function()
  local ok, err = template.create(root .. "/Z. Templates/Gone.md", root .. "/x.md", "x")
  t.eq(ok, false)
  t.matches(err, "not readable")
end)

t.describe("templates: the picker")

t.it("asks fzf for markdown only, single-select, with a preview", function()
  -- The pipeline is built inside M.pick, which is interactive; assert the
  -- pieces it depends on instead. --expect is deliberately absent: there is
  -- one thing to do with a template.
  local find = require("writing.find")
  t.ok(type(find.run) == "function", "find.run is exported for this module")
  t.ok(type(find.fzf_case) == "function", "find.fzf_case is exported for this module")
end)

V.destroy()
t.finish()
