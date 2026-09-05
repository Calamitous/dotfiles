-- Markdown checkbox toggling.
--
--   - [ ] task   ->  - [x] task      toggle
--   - [x] task   ->  - [ ] task      toggle back
--   - task       ->  - [ ] task      add a checkbox to a bare list item
--   plain text   ->  (left alone)
--
-- Works on the current line, or over a visual selection.

local M = {}

-- Unordered (-, *, +) and ordered (1. / 1)) list markers, indentation included.
local BULLET = "^(%s*[-*+]%s+)"
local ORDERED = "^(%s*%d+[.)]%s+)"

local function marker(line)
  return line:match(BULLET) or line:match(ORDERED)
end

--- Toggle one line. Returns the new text, or nil if it isn't a list item.
function M.toggle_line(line)
  local prefix = marker(line)
  if not prefix then
    return nil
  end

  local rest = line:sub(#prefix + 1)
  local state, after = rest:match("^%[([ xX])%]%s?(.*)$")

  if state then
    return prefix .. "[" .. (state == " " and "x" or " ") .. "] " .. after
  end

  -- A list item with no checkbox yet: give it one.
  return prefix .. "[ ] " .. rest
end

--- Toggle an inclusive line range (defaults to the cursor line).
function M.toggle(first, last)
  local cursor = vim.api.nvim_win_get_cursor(0)
  first = first or cursor[1]
  last = last or first

  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local changed, delta = 0, 0

  for i, line in ipairs(lines) do
    local new = M.toggle_line(line)
    if new then
      if first + i - 1 == cursor[1] then
        delta = #new - #line
      end
      lines[i] = new
      changed = changed + 1
    end
  end

  if changed == 0 then
    vim.notify("No list item here", vim.log.levels.WARN)
    return
  end

  vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)

  -- Keep the cursor on the same word when a checkbox was inserted.
  if delta ~= 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { cursor[1], math.max(0, cursor[2] + delta) })
  end
end

function M.setup()
  vim.api.nvim_create_user_command("CheckboxToggle", function(opts)
    if opts.range > 0 then
      M.toggle(opts.line1, opts.line2)
    else
      M.toggle()
    end
  end, { range = true, desc = "Toggle a markdown checkbox (or add one to a list item)" })
end

return M
