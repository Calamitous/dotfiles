-- Word counts for a buffer, a directory, or the current Longform draft.
--
-- Generalises <vault>/bin/current_word_count.sh, which is hardcoded to one
-- volume and counts the compiled output rather than the sources.

local vault = require("writing.vault")

local M = {}

--- 136525 -> "136,525"
function M.commas(n)
  local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

--- Count words the way a manuscript should be counted: no frontmatter, no
--- comments, no wikilink syntax.
--- @param text string
--- @return integer
function M.count(text)
  text = text:gsub("^%-%-%-\r?\n.-\r?\n%-%-%-%s*\r?\n", "")
  text = text:gsub("%%%%.-%%%%", "")
  text = text:gsub("<!%-%-.-%-%->", "")
  text = text:gsub("!?%[%[([^%]|]*)|([^%]]*)%]%]", "%2")
  text = text:gsub("!?%[%[([^%]]*)%]%]", "%1")
  return select(2, text:gsub("%S+", ""))
end

function M.count_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return 0
  end
  return M.count(table.concat(lines, "\n"))
end

function M.count_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
  return M.count(table.concat(lines, "\n"))
end

--- Sort "1 - Falling Star" before "10 - Betrayal" -- chapter files need
--- numeric-aware ordering, not plain lexicographic.
local function natural_lt(a, b)
  local function chunks(s)
    local out = {}
    for text, num in s:gmatch("(%D*)(%d*)") do
      if text ~= "" then table.insert(out, text:lower()) end
      if num ~= "" then table.insert(out, tonumber(num)) end
    end
    return out
  end
  local ca, cb = chunks(a), chunks(b)
  for i = 1, math.max(#ca, #cb) do
    local x, y = ca[i], cb[i]
    if x == nil then return true end
    if y == nil then return false end
    if type(x) ~= type(y) then
      x, y = tostring(x), tostring(y)
    end
    if x ~= y then return x < y end
  end
  return false
end

local function report(title, rows, total)
  local width, num_width = 0, #M.commas(total)
  for _, row in ipairs(rows) do
    width = math.max(width, #row.name)
  end

  local rule = string.rep("-", math.max(#title, width + num_width + 2))
  local line = "%-" .. width .. "s  %" .. num_width .. "s"

  local out = { title, rule }
  for _, row in ipairs(rows) do
    table.insert(out, string.format(line, row.name, M.commas(row.words)))
  end
  table.insert(out, rule)
  table.insert(out, string.format(line, "TOTAL", M.commas(total)))

  vim.api.nvim_echo(
    vim.tbl_map(function(l) return { l .. "\n" } end, out),
    false,
    {}
  )
end

--- Count every markdown file under a directory, recursively.
function M.dir(path)
  path = path and vim.fn.expand(path) or vim.fn.expand("%:p:h")
  local files = vim.fn.globpath(path, "**/*.md", true, true)

  table.sort(files, function(a, b)
    return natural_lt(vim.fs.basename(a), vim.fs.basename(b))
  end)

  local rows, total = {}, 0
  for _, file in ipairs(files) do
    local words = M.count_file(file)
    total = total + words
    table.insert(rows, { name = vim.fs.basename(file):gsub("%.md$", ""), words = words })
  end

  if #rows == 0 then
    vim.notify("No markdown files under " .. path, vim.log.levels.WARN)
    return
  end

  report(vim.fn.fnamemodify(path, ":~"), rows, total)
end

--- Count the scenes of the nearest Longform draft, in scene order.
function M.draft()
  local index = vault.draft()
  if not index then
    vim.notify("No Index.md found above this buffer", vim.log.levels.WARN)
    return
  end

  local draft = require("writing.draft").read(index)
  if not draft or #draft.scenes == 0 then
    vim.notify("No scenes listed in " .. index, vim.log.levels.WARN)
    return
  end

  local dir = vim.fs.dirname(index)
  local rows, total = {}, 0
  for _, scene in ipairs(draft.scenes) do
    local words = M.count_file(dir .. "/" .. scene .. ".md")
    total = total + words
    table.insert(rows, { name = scene, words = words })
  end

  report(draft.title or vim.fs.basename(dir), rows, total)
end

function M.setup()
  vim.api.nvim_create_user_command("WordCount", function()
    vim.notify(string.format("%s words", M.commas(M.count_buffer(0))))
  end, { desc = "Word count for this buffer" })

  vim.api.nvim_create_user_command("WordCountDir", function(opts)
    M.dir(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", complete = "dir", desc = "Word count per file under a directory" })

  vim.api.nvim_create_user_command("WordCountDraft", M.draft, { desc = "Word count for the current draft's scenes" })
end

return M
