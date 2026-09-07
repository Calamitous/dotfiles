-- Minimal test harness. No dependencies: this config avoids plugins where it
-- can, and a test runner that needs plenary or busted would be one more thing
-- to install on a new machine before you could check anything works.

local M = { total = 0, failed = 0, skipped = 0, group = nil }

local RED, GREEN, DIM, YELLOW, RESET = "\27[31m", "\27[32m", "\27[90m", "\27[33m", "\27[0m"

function M.describe(name)
  M.group = name
  io.write("\n" .. name .. "\n")
end

function M.it(name, fn)
  M.total = M.total + 1
  local ok, err = pcall(fn)
  if ok then
    io.write(GREEN .. "  ok   " .. RESET .. name .. "\n")
  else
    M.failed = M.failed + 1
    io.write(RED .. "  FAIL " .. RESET .. name .. "\n")
    io.write(DIM .. "         " .. tostring(err):gsub("\n", "\n         ") .. RESET .. "\n")
  end
end

function M.skip(name, why)
  M.total = M.total + 1
  M.skipped = M.skipped + 1
  io.write(YELLOW .. "  skip " .. RESET .. name .. DIM .. "  (" .. why .. ")" .. RESET .. "\n")
end

local function show(v)
  return type(v) == "table" and vim.inspect(v):gsub("%s+", " ") or tostring(v)
end

function M.eq(got, want, what)
  if not vim.deep_equal(got, want) then
    error(string.format("%s\n  expected: %s\n  got     : %s", what or "not equal", show(want), show(got)), 2)
  end
end

function M.ok(value, what)
  if not value then
    error(what or "expected a truthy value", 2)
  end
end

function M.matches(str, pattern, what)
  if not tostring(str):match(pattern) then
    error(string.format("%s\n  pattern: %s\n  got    : %s", what or "no match", pattern, show(str)), 2)
  end
end

function M.finish()
  -- Totals are aggregated by tests/run across processes; nothing to do here.
end

return M
