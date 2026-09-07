-- Highlight Obsidian %%comments%% (and <!-- html --> ones).
--
-- Treesitter's markdown parser knows nothing about %%..%%, which is an
-- Obsidian extension, so nothing highlights it -- a note to yourself reads
-- exactly like the prose around it.
--
-- Done with extmarks rather than `matchadd` because comments can span lines
-- (this manuscript has one), and a window-local pattern match can't span them.

local M = {}

M.ns = vim.api.nvim_create_namespace("ScriptoriumComments")
M.group = "ScriptoriumComment"

--- Debounce, so a long chapter isn't rescanned on every keystroke.
M.debounce_ms = 120

local pending = {}

--- Find every comment span and mark it.
function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local function mark(row, from, to)
    pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, row - 1, from, {
      end_col = math.min(to, #(lines[row] or "")),
      hl_group = M.group,
    })
  end

  -- Walk the buffer tracking whether we're inside an unclosed %% .. %%.
  local open, delim = false, "%%"

  for i, line in ipairs(lines) do
    local col = 1
    while true do
      if open then
        local e = line:find(delim, col, true)
        if e then
          mark(i, 0, e + 1)
          open, col = false, e + 2
        else
          mark(i, 0, #line)
          break
        end
      else
        local s = line:find(delim, col, true)
        if not s then
          break
        end
        local e = line:find(delim, s + 2, true)
        if e then
          mark(i, s - 1, e + 1)
          col = e + 2
        else
          mark(i, s - 1, #line)
          open = true
          break
        end
      end
    end

    -- HTML comments, single line only (that's all this manuscript uses).
    local hs, he = line:find("<!%-%-.-%-%->")
    if hs then
      mark(i, hs - 1, he)
    end
  end
end

local function schedule(buf)
  if pending[buf] then
    return
  end
  pending[buf] = true
  vim.defer_fn(function()
    pending[buf] = nil
    M.refresh(buf)
  end, M.debounce_ms)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("ScriptoriumComments", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = group,
    pattern = "*.md",
    callback = function(args)
      M.refresh(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    pattern = "*.md",
    callback = function(args)
      schedule(args.buf)
    end,
  })
end

return M
