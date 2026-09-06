-- <Leader>? -- the writing keymap reference.
--
-- Rendered into a scrollable float in two columns; the flat list had grown to
-- 58 lines and scrolled off the top of the screen.

local M = {}

M.key_width = 14

--- { section title, { {key, description}, ... } }
M.sections = {
  { "NAVIGATION", {
    { "<Leader>o", "find files in the vault" },
    { "<Leader>/", "grep the vault" },
    { "<Leader>b", "switch buffer" },
    { "<Leader>e", "file sidebar" },
    { "<Leader>E", "sidebar at vault root" },
    { "<Leader>,", "open this config" },
    { "<Leader>r", "reload the config" },
  } },
  { "LINKS", {
    { "gf / <CR>", "follow the link under the cursor" },
    { "<C-o>", "jump back" },
    { "<C-^>", "toggle between two files" },
    { "[[ <C-Space>", "insert a wikilink" },
    { "<Leader>kr", "rename note + rewrite links" },
    { "<Leader>kb", "backlinks" },
    { "<Leader>ks", "quick switch" },
    { "<Leader>kg", "search notes" },
  } },
  { "WRITING", {
    { "<Leader>wr", "centred reading mode" },
    { "<Leader>wp", "prose mode" },
    { "<Leader>l", "toggle checkbox" },
    { "<Leader>y", "copy as rich text" },
  } },
  { "SPELLING", {
    { "]s / [s", "next / prev misspelling" },
    { "zg", "add word to vault dictionary" },
    { "<Leader>s", "suggestions" },
    { "<Leader>S", "toggle spell check" },
  } },
  { "GRAMMAR & STYLE", {
    { "]d / [d", "next / prev suggestion" },
    { "<Leader>d", "why is this flagged?" },
    { "<Leader>a", "accept the fix" },
    { "<Leader>x", "ignore this suggestion" },
    { "<Leader>h", "toggle grammar" },
    { "<F3>", "toggle spell + grammar" },
    { "<Leader>vv", "Vale: lint this chapter" },
    { "<Leader>vd", "Vale: lint the whole draft" },
    { "x", "(in quickfix) won't do" },
  } },
  { "MANUSCRIPT", {
    { "<F9>", "compile the manuscript" },
    { "<Leader>mc", "compile the manuscript" },
    { "<Leader>mk", "compile check (diff only)" },
    { "<Leader>ml", "list drafts" },
    { "<Leader>ms", "show compile pipeline" },
    { "<Leader>wc", "word count: buffer" },
    { "<Leader>wd", "word count: draft" },
    { "<Leader>wD", "word count: directory" },
  } },
  { "VAULT", {
    { "<Leader>wv", "which vault / draft?" },
    { "<Leader>wa", "edit abbreviations" },
    { ":VaultInit", "set up a new vault" },
    { "<Leader>wA", "reload abbreviations" },
  } },
}

--- Render a section into lines, recording where the key column sits.
local function render(sections)
  local lines, marks = {}, {}
  for _, section in ipairs(sections) do
    table.insert(lines, section[1])
    marks[#lines] = { kind = "title" }
    for _, row in ipairs(section[2]) do
      local key = row[1]
      local text = string.format("  %-" .. M.key_width .. "s %s", key, row[2])
      table.insert(lines, text)
      marks[#lines] = { kind = "key", from = 2, to = 2 + #key }
    end
    table.insert(lines, "")
  end
  return lines, marks
end

--- Width one rendered column needs.
local function column_width(lines)
  local w = 0
  for _, line in ipairs(lines) do
    w = math.max(w, vim.fn.strdisplaywidth(line))
  end
  return w
end

--- One column, for terminals too narrow to take two side by side.
local function single_column()
  local lines, marks = render(M.sections)
  local out = {}
  for i, m in pairs(marks) do
    out[i] = { vim.tbl_extend("force", m, { offset = 0 }) }
  end
  return lines, out
end

function M.show()
  -- Split the sections into two balanced columns.
  local total = 0
  for _, s in ipairs(M.sections) do
    total = total + #s[2] + 2
  end

  local left, right, run = {}, {}, 0
  for _, s in ipairs(M.sections) do
    if run < total / 2 then
      table.insert(left, s)
      run = run + #s[2] + 2
    else
      table.insert(right, s)
    end
  end

  local l_lines, l_marks = render(left)
  local r_lines, r_marks = render(right)

  local l_width = 0
  for _, line in ipairs(l_lines) do
    l_width = math.max(l_width, vim.fn.strdisplaywidth(line))
  end
  local gutter = l_width + 4

  local lines, marks = {}, {}
  for i = 1, math.max(#l_lines, #r_lines) do
    local a = l_lines[i] or ""
    local b = r_lines[i] or ""
    local padded = a .. string.rep(" ", gutter - vim.fn.strdisplaywidth(a))
    table.insert(lines, vim.trim(b) == "" and a or (padded .. b))

    local m = {}
    if l_marks[i] then
      m[#m + 1] = vim.tbl_extend("force", l_marks[i], { offset = 0 })
    end
    if r_marks[i] then
      m[#m + 1] = vim.tbl_extend("force", r_marks[i], { offset = gutter })
    end
    marks[i] = m
  end

  -- Fall back to a single column if two won't fit the terminal.
  local width = column_width(lines)
  if width + 4 > vim.o.columns then
    lines, marks = single_column()
    width = column_width(lines)
  end
  width = math.min(width + 2, vim.o.columns - 4)
  local height = math.min(#lines, math.floor(vim.o.lines * 0.85))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local ns = vim.api.nvim_create_namespace("WritingHelp")
  for lnum, list in pairs(marks) do
    for _, m in ipairs(list) do
      if m.kind == "title" then
        local text = lines[lnum]
        local from = m.offset
        local to = math.min(#text, from + 24)
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, from, {
          end_col = to, hl_group = "Title",
        })
      else
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, m.offset + m.from, {
          end_col = m.offset + m.to, hl_group = "Identifier",
        })
      end
    end
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Writing keys  —  q to close ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false

  for _, key in ipairs({ "q", "<Esc>", "<CR>" }) do
    vim.keymap.set("n", key, function()
      pcall(vim.api.nvim_win_close, win, true)
    end, { buffer = buf, nowait = true, silent = true })
  end
end

function M.setup()
  vim.api.nvim_create_user_command("WritingHelp", M.show, {
    desc = "Show writing commands and keymaps",
  })
end

return M
