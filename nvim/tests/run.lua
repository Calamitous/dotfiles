-- Runs ONE spec file. `tests/run` invokes this once per file so that each gets
-- a clean neovim: state set by one spec (filetype detection, window layout,
-- module state) can't leak into the next, and a crash takes down only its own
-- file instead of the whole suite.
--
-- Usage: nvim -l tests/run.lua <spec.lua> [counts-file]

local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local root = vim.fs.dirname(here)
vim.opt.runtimepath:prepend(root)

-- `nvim -l` puts the config on the runtimepath but does NOT source init.lua, so
-- `require` finds the modules while none of their setup() has run: no autocmds,
-- no commands, no keymaps. Specs that call functions directly still pass, which
-- makes the omission easy to miss -- load the real init explicitly.
local init = root .. "/init.lua"
if vim.fn.filereadable(init) == 1 then
  local ok, err = pcall(dofile, init)
  if not ok then
    io.write("\27[31mconfig failed to load:\27[0m " .. tostring(err) .. "\n")
    os.exit(1)
  end
end

local t = require("tests.harness")

local spec = _G.arg and _G.arg[1]
local counts = _G.arg and _G.arg[2]

if not spec then
  io.write("usage: nvim -l tests/run.lua <spec.lua>\n")
  os.exit(2)
end

local ok, err = pcall(dofile, spec)
if not ok then
  t.total = t.total + 1
  t.failed = t.failed + 1
  io.write("\27[31m  FAIL \27[0m" .. vim.fn.fnamemodify(spec, ":t:r") .. " (spec crashed)\n         " .. tostring(err) .. "\n")
end

if counts then
  vim.fn.writefile({ string.format("%d %d %d", t.total, t.failed, t.skipped) }, counts)
end

os.exit(t.failed > 0 and 1 or 0)
