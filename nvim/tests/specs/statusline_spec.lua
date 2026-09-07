local t = require("tests.harness")
local V = require("tests.vault")
local statusline = require("writing.statusline")

V.filetypes()

t.describe("statusline word count")

V.create({
  ["N/1.md"] = "---\ntitle: x\n---\n\nOne two three four five.\n\n%% a note to self %%\n",
  ["plain.txt"] = "not markdown",
})

local function render()
  return vim.api.nvim_eval_statusline(vim.o.statusline, { winid = 0 }).str
end

t.it("counts the words in a markdown buffer in a vault", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  vim.wait(300)
  t.eq(vim.b.scriptorium_words, "5", "frontmatter and the comment excluded")
  t.matches(render(), "5 words")
end)

t.it("agrees with :WordCount", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  vim.wait(300)
  local wc = require("writing.wordcount")
  t.eq(vim.b.scriptorium_words, wc.commas(wc.count_buffer(0)), "same number as the command")
end)

t.it("names the vault", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/N/1.md")
  t.matches(statusline.vault(), vim.pesc(vim.fs.basename(V.root)))
end)

t.it("shows no count for a non-markdown buffer", function()
  V.reset()
  vim.cmd("edit " .. V.root .. "/plain.txt")
  vim.wait(200)
  t.eq(statusline.words(), "", "nothing to count here")
end)

t.it("shows no count outside a vault", function()
  V.reset()
  vim.fn.writefile({ "loose words here" }, "/tmp/scriptorium-loose.md")
  vim.cmd("edit /tmp/scriptorium-loose.md")
  vim.wait(200)
  t.eq(statusline.words(), "", "no vault, no count")
  vim.fn.delete("/tmp/scriptorium-loose.md")
end)

t.it("uses one statusline for the whole window", function()
  -- laststatus=3: per-window bars would put one under each reading-mode pad.
  t.eq(vim.o.laststatus, 3)
end)

V.destroy()
