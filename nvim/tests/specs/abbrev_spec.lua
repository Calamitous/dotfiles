local t = require("tests.harness")
local V = require("tests.vault")
local abbrev = require("writing.abbrev")

V.filetypes()

t.describe("abbreviations")

local function installed()
  local out = {}
  for line in vim.api.nvim_exec2("iabbrev", { output = true }).output:gmatch("[^\n]+") do
    local lhs = line:match("^i%s+(%S+)")
    if lhs then
      out[#out + 1] = lhs
    end
  end
  table.sort(out)
  return out
end

V.create({
  ["note.md"] = "text",
  [".scriptorium/abbreviations.vim"] = table.concat({
    '" a comment, ignored',
    "iabbrev bsh Bayze Shab",
    "iabbrev nmr Namarûn",
    "iab dk D'khara",
    "",
  }, "\n"),
})

t.it("reads plain vim commands", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/note.md")
  t.eq(installed(), { "bsh", "dk", "nmr" })
end)

t.it("scopes them to the buffer, so vaults can't collide", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/note.md")
  local out = vim.api.nvim_exec2("iabbrev", { output = true }).output
  t.matches(out, "@", "listed as buffer-local (vim marks these with @)")
end)

t.it("handles multi-word expansions and unicode", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/note.md")
  local out = vim.api.nvim_exec2("iabbrev", { output = true }).output
  t.matches(out, "Bayze Shab", "spaces survive")
  t.matches(out, "Namar", "unicode survives")
  t.matches(out, "D'khara", "apostrophes survive")
end)

t.it("ignores comments and blank lines", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/note.md")
  t.eq(#installed(), 3, "only the three real ones")
end)

t.it("still reads a legacy markdown table when there's no .vim file", function()
  local root = V.root
  vim.fn.delete(root .. "/.scriptorium/abbreviations.vim")
  vim.fn.writefile({
    "| Abbr | Expands to |",
    "| ---- | ---------- |",
    "| f | Fortney |",
  }, root .. "/.scriptorium/Abbreviations.md")

  V.reset()
  vim.cmd("edit " .. root .. "/note.md")
  t.eq(installed(), { "f" }, "legacy table still works")
end)

t.it("converts a legacy table to vim commands on :AbbrevEdit", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/note.md")
  abbrev.edit()
  local written = table.concat(vim.fn.readfile(V.root .. "/.scriptorium/abbreviations.vim"), "\n")
  t.matches(written, "iabbrev f Fortney", "table row became a vim command")
end)

t.describe("what triggers an expansion")

-- Typing through feedkeys so this exercises the real insert-mode path,
-- including prose mode's undo-breakpoint mappings.
local function typed(keys)
  V.reset()
  vim.cmd("edit " .. V.root .. "/note.md")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("i" .. keys .. "<Esc>", true, false, true), "x", false)
  return vim.api.nvim_get_current_line()
end

vim.fn.writefile({ "iabbrev f Fortney" }, V.root .. "/.scriptorium/abbreviations.vim")

t.it("expands on a space", function()
  t.eq(typed("f "), "Fortney ")
end)

t.it("expands on sentence punctuation", function()
  -- These are mapped by prose mode for undo breakpoints; without an explicit
  -- <C-]> in that mapping the abbreviation is swallowed.
  for _, ch in ipairs({ ".", ",", "!", "?", ":" }) do
    t.eq(typed("f" .. ch), "Fortney" .. ch, "expanded before " .. ch)
  end
end)

t.it("expands on unmapped punctuation too", function()
  t.eq(typed('f"'), 'Fortney"')
  t.eq(typed("f;"), "Fortney;")
end)

t.it("expands mid-sentence", function()
  t.eq(typed("I saw f, then f."), "I saw Fortney, then Fortney.")
end)

t.it("leaves a longer word starting with the same letters alone", function()
  t.eq(typed("fox "), "fox ")
end)

V.destroy()
