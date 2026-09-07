-- Parse a two-column markdown table into ordered pairs.
--
-- Shared by the per-vault abbreviations and bookmarks, both of which are
-- configured by a table in a note so they can be edited from Obsidian as well
-- as from here.
--
-- Accepts either form, and ignores headers, separators, blanks and `#` lines:
--
--   | key | value |
--   | --- | ----- |
--   | dk  | D'khara |
--
--   dk = D'khara

local M = {}

local function is_separator(line)
  return line:match("^%s*|?[%s:|-]+|?%s*$") ~= nil and line:match("%-%-") ~= nil
end

--- @param lines string[]
--- @return { key: string, value: string }[]
function M.parse(lines)
  local out = {}

  for i, line in ipairs(lines) do
    if line:match("^%s*$") or line:match("^%s*#") or is_separator(line) then
      goto continue
    end

    local key, value

    if line:match("^%s*|") then
      -- A header row is one immediately followed by a separator.
      if lines[i + 1] and is_separator(lines[i + 1]) then
        goto continue
      end
      local cells = {}
      for cell in line:gmatch("|([^|]*)") do
        table.insert(cells, vim.trim(cell))
      end
      key, value = cells[1], cells[2]
    else
      key, value = line:match("^%s*(%S+)%s*=%s*(.-)%s*$")
    end

    if key and value and key ~= "" and value ~= "" and not key:find("%s") then
      table.insert(out, { key = key, value = value })
    end

    ::continue::
  end

  return out
end

return M
