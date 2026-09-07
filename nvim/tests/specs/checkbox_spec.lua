local t = require("tests.harness")
local cb = require("writing.checkbox")

t.describe("checkbox")

t.it("toggles an unchecked box", function()
  t.eq(cb.toggle_line("- [ ] task"), "- [x] task")
end)

t.it("toggles a checked box back", function()
  t.eq(cb.toggle_line("- [x] task"), "- [ ] task")
end)

t.it("treats [X] as checked", function()
  t.eq(cb.toggle_line("- [X] task"), "- [ ] task")
end)

t.it("adds a box to a bare list item", function()
  t.eq(cb.toggle_line("- bare"), "- [ ] bare")
  t.eq(cb.toggle_line("* star"), "* [ ] star")
  t.eq(cb.toggle_line("1. ordered"), "1. [ ] ordered")
end)

t.it("adds a box to plain text and blank lines", function()
  t.eq(cb.toggle_line("Just text."), "- [ ] Just text.")
  t.eq(cb.toggle_line(""), "- [ ] ")
end)

t.it("preserves indentation", function()
  t.eq(cb.toggle_line("  indented"), "  - [ ] indented")
  t.eq(cb.toggle_line("  - [ ] nested"), "  - [x] nested")
end)

t.it("leaves headings alone", function()
  t.eq(cb.toggle_line("# Heading"), nil)
  t.eq(cb.toggle_line("## Part 1"), nil)
end)

t.it("does not trip over wikilinks in the text", function()
  t.eq(cb.toggle_line("- [ ] see [[A Note]]"), "- [x] see [[A Note]]")
end)

t.it("round-trips", function()
  local a = cb.toggle_line("- [ ] task")
  t.eq(cb.toggle_line(a), "- [ ] task")
end)
