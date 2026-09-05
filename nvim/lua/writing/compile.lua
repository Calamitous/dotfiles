-- Manuscript compilation -- a front end for bin/compile.rb.
--
-- The script does the work and is usable on its own from a shell; this just
-- runs it against the draft for the current buffer and reports the result.

local vault = require("writing.vault")

local M = {}

M.script = vim.fn.expand("~/.local/bin/compile.rb")

local function run(args, on_done)
  local root = vault.root()
  if not root then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end
  if vim.fn.filereadable(M.script) == 0 then
    vim.notify("compile.rb not found at " .. M.script, vim.log.levels.ERROR)
    return
  end

  local cmd = { "ruby", M.script }
  vim.list_extend(cmd, args or {})

  -- Run from the buffer's directory so the draft is resolved the same way the
  -- shell would resolve it.
  local cwd = vim.fn.expand("%:p:h")
  if cwd == "" or not vim.startswith(cwd, root) then
    cwd = root
  end

  vim.system(cmd, { cwd = cwd, text = true }, function(res)
    vim.schedule(function()
      on_done(res)
    end)
  end)
end

local function report(res, title)
  local out = vim.trim((res.stdout or "") .. (res.stderr or ""))
  if out == "" then
    out = "(no output)"
  end

  local lines = vim.split(out, "\n")
  if #lines <= 3 and res.code == 0 then
    vim.notify(out)
    return
  end

  -- Longer output (a diff, a draft list) goes in a scratch split.
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = (title == "diff") and "diff" or "text"
  vim.api.nvim_win_set_height(0, math.min(#lines + 1, 20))
end

--- Compile the current draft.
function M.build(extra)
  run(extra, function(res)
    if res.code ~= 0 then
      vim.notify("compile failed:\n" .. vim.trim((res.stderr or "") .. (res.stdout or "")), vim.log.levels.ERROR)
      return
    end
    report(res, "compile")
  end)
end

--- Compile without writing, and show the diff against the current output.
function M.check()
  run({ "--check" }, function(res)
    report(res, "diff")
  end)
end

--- List the drafts in this vault.
function M.list()
  run({ "--list" }, function(res)
    report(res, "list")
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("Compile", function(o)
    M.build(o.args ~= "" and vim.split(o.args, "%s+") or nil)
  end, { nargs = "*", desc = "Compile the current draft" })

  vim.api.nvim_create_user_command("CompileCheck", M.check, {
    desc = "Compile without writing; diff against the current output",
  })

  vim.api.nvim_create_user_command("CompileList", M.list, { desc = "List drafts in this vault" })
end

return M
