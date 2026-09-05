-- File navigator sidebar, built on netrw (which ships with neovim -- no plugin).
--
-- Wrapped to behave like the NERDTree setup in ~/.vimrc: <Leader>e toggles a
-- left sidebar, opens at the vault root, reveals the current file, and closes
-- itself once you pick something (NERDTreeQuitOnOpen=1).
--
-- We open a split and `:edit` the directory rather than calling `:Lexplore`,
-- because Lexplore keeps its own toggle state which gets out of step whenever a
-- window is closed some other way.
--
-- CAUTION: renaming a file here will NOT update the `[[wikilinks]]` pointing at
-- it. Rename through Obsidian (or `:ObsidianRename`, once that's installed).

local vault = require("writing.vault")

local M = {}

M.width = 32

--- Close the sidebar after opening a file, matching NERDTreeQuitOnOpen.
M.close_on_open = true

--- netrw doesn't always have its filetype set yet (it's set as the plugin
--- renders), so fall back to "the buffer is a directory", which is true of an
--- explorer window from the moment it opens.
local function is_explorer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.bo[buf].filetype == "netrw" then
    return true
  end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and vim.fn.isdirectory(name) == 1
end

local function find_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_explorer(vim.api.nvim_win_get_buf(win)) then
      return win
    end
  end
  return nil
end

function M.close()
  local win = find_win()
  if win and #vim.api.nvim_tabpage_list_wins(0) > 1 then
    pcall(vim.api.nvim_win_close, win, true)
    return true
  end
  return false
end

--- Open the sidebar, rooted at the vault and revealing the current file.
function M.open(dir)
  local file = vim.api.nvim_buf_get_name(0)
  local reveal = (file ~= "" and vim.fs.basename(file)) or nil

  dir = dir or (file ~= "" and vim.fs.dirname(file)) or vault.root() or vim.uv.cwd()

  vim.cmd("topleft " .. M.width .. "vsplit")
  vim.cmd.edit(vim.fn.fnameescape(dir))

  local win = vim.api.nvim_get_current_win()
  vim.wo[win].winfixwidth = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true
  vim.wo[win].list = false
  vim.wo[win].spell = false

  -- Put the cursor on the file we came from.
  if reveal then
    vim.fn.search("\\V" .. vim.fn.escape(reveal, "\\"), "cw")
  end

  if M.close_on_open then
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = vim.api.nvim_create_augroup("WritingSidebarClose", { clear = true }),
      callback = function(args)
        -- Fired for the file netrw just opened, not for netrw itself.
        if not is_explorer(args.buf) and vim.bo[args.buf].buftype == "" then
          M.close()
          return true -- one-shot
        end
      end,
    })
  end
end

function M.toggle(dir)
  if not M.close() then
    M.open(dir)
  end
end

--- Open rooted at the vault rather than the current file's directory.
function M.vault_root()
  M.toggle(vault.root() or vim.uv.cwd())
end

function M.setup()
  -- netrw appearance: tree view, no banner, open files in the previous window.
  vim.g.netrw_liststyle = 3
  vim.g.netrw_banner = 0
  vim.g.netrw_browse_split = 4
  vim.g.netrw_altv = 1
  vim.g.netrw_winsize = 25
  vim.g.netrw_hide = 1
  vim.g.netrw_list_hide = [[^\.\.\=/\=$,^\.obsidian/$,^\.git/$,\.DS_Store$]]

  vim.api.nvim_create_user_command("Sidebar", function(o)
    M.toggle(o.args ~= "" and vim.fn.expand(o.args) or nil)
  end, { nargs = "?", complete = "dir", desc = "Toggle the file sidebar" })

  vim.api.nvim_create_user_command("SidebarVault", M.vault_root, {
    desc = "Toggle the file sidebar at the vault root",
  })
end

return M
