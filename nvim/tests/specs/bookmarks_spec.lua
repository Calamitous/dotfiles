local t = require("tests.harness")
local V = require("tests.vault")
local mdtable = require("writing.mdtable")
local bookmarks = require("writing.bookmarks")

t.describe("markdown table parsing")

t.it("reads a table, skipping header and separator", function()
  t.eq(mdtable.parse({
    "| Key | File |",
    "| --- | ---- |",
    "| e   | Metadata/Edits.md |",
    "| o   | Metadata/Outline.md |",
  }), {
    { key = "e", value = "Metadata/Edits.md" },
    { key = "o", value = "Metadata/Outline.md" },
  })
end)

t.it("reads the key = value form", function()
  t.eq(mdtable.parse({ "nmr = Namarûn" }), { { key = "nmr", value = "Namarûn" } })
end)

t.it("ignores blanks, prose and comments", function()
  t.eq(mdtable.parse({ "# Title", "", "Some prose.", "a = b" }),
    { { key = "a", value = "b" } })
end)

t.it("keeps file order", function()
  local got = mdtable.parse({ "c = 3", "a = 1", "b = 2" })
  t.eq({ got[1].key, got[2].key, got[3].key }, { "c", "a", "b" })
end)

t.describe("bookmarks")

V.create({
  ["Metadata/Larger-Scale Edits.md"] = "Edits.",
  ["Metadata/Outline.md"] = "Outline.",
  ["one.md"] = "note",
  [".scriptorium/Bookmarks.md"] = table.concat({
    "| Key | File |",
    "| --- | ---- |",
    "| e | Metadata/Larger-Scale Edits.md |",
    "| o | Metadata/Outline.md |",
    "| x | Metadata/Nope.md |",
  }, "\n"),
})

t.it("resolves a key to an absolute path in this vault", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/one.md")
  t.eq(bookmarks.resolve("e"), V.root .. "/Metadata/Larger-Scale Edits.md")
end)

t.it("handles filenames with spaces", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/one.md")
  bookmarks.open("e")
  t.matches(vim.api.nvim_buf_get_name(0), "Larger%-Scale Edits%.md$", "opened the file")
end)

t.it("returns nil for an unknown key", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/one.md")
  t.eq(bookmarks.resolve("zzz"), nil)
end)

t.it("does not open a bookmark pointing at a missing file", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/one.md")
  bookmarks.open("x")
  t.matches(vim.api.nvim_buf_get_name(0), "one%.md$", "stayed put")
end)

t.it("lists nothing outside a vault", function()
  V.reset()
  vim.cmd("edit /tmp/scriptorium-loose.md")
  t.eq(bookmarks.resolve("e"), nil)
  vim.fn.delete("/tmp/scriptorium-loose.md")
end)

V.destroy()
