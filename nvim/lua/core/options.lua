-- Editor options. Prose-leaning; code lives in vim, not here.
--
-- Notably absent: `set paste` (see lua/writing/abbrev.lua for why).

local o = vim.opt

o.number = true
o.cursorline = true
o.scrolloff = 5
o.backspace = { "indent", "eol", "start" }
o.history = 1000

o.tabstop = 2
o.shiftwidth = 2
o.softtabstop = 2
o.expandtab = true
o.autoindent = true

-- Wrap at word boundaries rather than mid-word. 'linebreak' is inert unless
-- 'wrap' is on, so both are set explicitly here.
o.wrap = true
o.linebreak = true
o.breakindent = true

o.showmatch = true
o.incsearch = true
o.ignorecase = true
o.smartcase = true

o.termguicolors = true
o.background = "dark"
o.showmode = false
o.signcolumn = "yes"

o.clipboard = "unnamedplus"

-- Completion menu. `menuone` matters: without it a single match is inserted
-- silently instead of offering a menu, which reads as "completion is broken".
-- `noselect` keeps you in control of what gets inserted.
o.completeopt = { "menu", "menuone", "noselect", "popup" }

o.swapfile = false
o.backup = true
o.undofile = true
o.undolevels = 1000
o.undoreload = 10000

o.listchars = { tab = ">~", nbsp = "_", trail = "." }
o.list = true

-- Keep state out of the config repo.
local state = vim.fn.stdpath("state")
for dir, opt in pairs({ backup = "backupdir", undo = "undodir", view = "viewdir" }) do
  local path = state .. "/" .. dir
  vim.fn.mkdir(path, "p")
  vim.opt[opt] = path
end

-- Strip trailing whitespace on save, preserving cursor position.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("StripTrailingWhitespace", { clear = true }),
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    pcall(vim.api.nvim_win_set_cursor, 0, pos)
  end,
})

-- Restore cursor to its last position in a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("RestoreCursor", { clear = true }),
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
