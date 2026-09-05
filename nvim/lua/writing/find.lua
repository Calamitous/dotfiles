-- Fuzzy finding, scoped to the vault.
--
-- Runs the real fzf binary in a floating terminal rather than a plugin, so it
-- behaves exactly like `:FZF` did in vim -- same tool, same keys, same muscle
-- memory. The one change: the search root is the Obsidian vault, not the git
-- repo, so `rg --files` sees the whole vault regardless of where you started.
--
-- ctrl-v / ctrl-x / ctrl-t open in a vsplit / split / tab, matching the
-- g:fzf_action mapping from ~/.vimrc. Tab multi-selects.

local vault = require("writing.vault")

local M = {}

local EXPECT = "ctrl-v,ctrl-x,ctrl-t"

--- Case-insensitive matching in both pickers. Set to false for smart-case
--- instead (a lowercase query matches anything; any uppercase letter in the
--- query forces an exact-case match).
M.ignore_case = true

--- ripgrep invocation for the grep picker.
local function rg_cmd()
  return "rg --column --line-number --no-heading --color=always "
    .. (M.ignore_case and "--ignore-case" or "--smart-case")
end

--- fzf's own matcher: -i forces case-insensitive, +i forces case-sensitive.
local function fzf_case()
  return M.ignore_case and "-i" or "+i"
end

local function float(title)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.max(20, math.min(vim.o.columns - 4, math.floor(vim.o.columns * 0.9)))
  local height = math.max(10, math.min(vim.o.lines - 4, math.floor(vim.o.lines * 0.8)))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  -- Escape should abort the picker, not drop into terminal-normal mode.
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>i<C-c>", { buffer = buf, silent = true })
  return buf, win
end

--- Run an fzf pipeline in a float; hand the selected lines to `handler`.
local function run(cmd, cwd, title, handler)
  local outfile = vim.fn.tempname()
  local buf, win = float(title)

  vim.fn.jobstart({ "sh", "-c", cmd .. " > " .. vim.fn.shellescape(outfile) }, {
    term = true,
    cwd = cwd,
    on_exit = function(_, code)
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end

      local lines = {}
      if vim.fn.filereadable(outfile) == 1 then
        lines = vim.fn.readfile(outfile)
      end
      vim.fn.delete(outfile)

      -- fzf exits 130 on abort, 1 on no match.
      if code ~= 0 or #lines == 0 then
        return
      end
      vim.schedule(function()
        handler(lines, cwd)
      end)
    end,
  })

  vim.cmd.startinsert()
end

--- Translate the --expect key into an open command.
local function open_with(key)
  if key == "ctrl-v" then
    return "vsplit"
  elseif key == "ctrl-x" then
    return "split"
  elseif key == "ctrl-t" then
    return "tabedit"
  end
  return "edit"
end

local function on_files(lines, cwd)
  local cmd = open_with(table.remove(lines, 1))
  for _, rel in ipairs(lines) do
    if rel ~= "" then
      vim.cmd[cmd](vim.fn.fnameescape(cwd .. "/" .. rel))
    end
  end
end

local function on_grep(lines, cwd)
  local cmd = open_with(table.remove(lines, 1))
  for _, entry in ipairs(lines) do
    local file, lnum, col = entry:match("^(.-):(%d+):(%d+):")
    if file then
      vim.cmd[cmd](vim.fn.fnameescape(cwd .. "/" .. file))
      pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(lnum), tonumber(col) - 1 })
      vim.cmd("normal! zz")
    end
  end
end

--- Search root: the vault if we're in one, otherwise the working directory.
local function root()
  return vault.root() or vim.uv.cwd()
end

--- Fuzzy-find files. <Leader>o
function M.files(dir)
  local cwd = dir or root()
  local source = vim.fn.executable("rg") == 1 and "rg --files" or "find . -type f"
  local cmd = table.concat({
    source,
    "| fzf --multi --exit-0 " .. fzf_case(),
    "--expect=" .. EXPECT,
    "--prompt='Files> '",
    "--preview 'head -n 300 {}'",
    "--preview-window=right:55%:wrap",
  }, " ")

  run(cmd, cwd, vim.fs.basename(cwd) .. " — files", on_files)
end

--- Live-grep the vault contents. <Leader>/
function M.grep(dir)
  local cwd = dir or root()
  local cmd = table.concat({
    "fzf --ansi --disabled --multi --exit-0 " .. fzf_case(),
    "--expect=" .. EXPECT,
    "--prompt='Grep> '",
    "--delimiter=:",
    "--bind 'start:reload:" .. rg_cmd() .. " -- {q} || true'",
    "--bind 'change:reload:" .. rg_cmd() .. " -- {q} || true'",
    "--preview 'head -n {2} {1} | tail -n 25'",
    "--preview-window=right:55%:wrap",
  }, " ")

  run(cmd, cwd, vim.fs.basename(cwd) .. " — grep", on_grep)
end

--- Fuzzy-find within this nvim config. <Leader>,
--- Resolves the dotfiles symlink so buffers open at their real path in the
--- repo, which keeps `:!git status` and friends honest.
function M.config()
  local dir = vim.fn.stdpath("config")
  M.files(vim.uv.fs_realpath(dir) or dir)
end

--- Fuzzy-find among open buffers.
function M.buffers()
  local names = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" then
        table.insert(names, vim.fn.fnamemodify(name, ":~:."))
      end
    end
  end

  if #names == 0 then
    vim.notify("No listed buffers", vim.log.levels.WARN)
    return
  end

  vim.ui.select(names, { prompt = "Buffers" }, function(choice)
    if choice then
      vim.cmd.edit(vim.fn.fnameescape(vim.fn.expand(choice)))
    end
  end)
end

function M.setup()
  if vim.fn.executable("fzf") ~= 1 then
    return
  end

  vim.api.nvim_create_user_command("Files", function(o)
    M.files(o.args ~= "" and vim.fn.expand(o.args) or nil)
  end, { nargs = "?", complete = "dir", desc = "Fuzzy-find files in the vault" })

  vim.api.nvim_create_user_command("Grep", function(o)
    M.grep(o.args ~= "" and vim.fn.expand(o.args) or nil)
  end, { nargs = "?", complete = "dir", desc = "Live-grep the vault" })

  vim.api.nvim_create_user_command("Buffers", M.buffers, { desc = "Switch buffer" })

  vim.api.nvim_create_user_command("Config", M.config, { desc = "Open the nvim config" })
end

return M
