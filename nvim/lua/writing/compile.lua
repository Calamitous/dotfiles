-- Manuscript compilation -- a front end for bin/compile.rb.
--
-- The script does the work and is usable on its own from a shell; this just
-- runs it against the draft for the current buffer and reports the result.

local vault = require("writing.vault")

local M = {}

M.script = vim.fn.expand("~/.local/bin/compile.rb")

--- Write modified buffers in this vault before compiling. compile.rb reads
--- from disk, so without this an unsaved edit is silently absent from the
--- build -- and since nothing changed, git shows clean and it looks as though
--- the compile did nothing.
M.autosave = true

--- Save modified, real, writable buffers under `root`.
--- @return integer number written
local function save_vault_buffers(root)
  local written = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].modified
      and vim.bo[buf].buftype == ""
      and not vim.bo[buf].readonly
      and name ~= ""
      and vim.startswith(name, root .. "/")
    then
      vim.api.nvim_buf_call(buf, function()
        if pcall(vim.cmd, "silent write") then
          written = written + 1
        end
      end)
    end
  end
  return written
end

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

  local saved = 0
  if M.autosave then
    saved = save_vault_buffers(root)
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
      on_done(res, saved)
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
  run(extra, function(res, saved)
    if res.code ~= 0 then
      vim.notify("compile failed:\n" .. vim.trim((res.stderr or "") .. (res.stdout or "")), vim.log.levels.ERROR)
      return
    end
    if saved and saved > 0 then
      vim.notify(string.format("Saved %d buffer(s) first", saved))
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

--- Show the compile pipeline, labelled by kind.
function M.steps()
  run({ "--steps" }, function(res)
    report(res, "steps")
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
  vim.api.nvim_create_user_command("CompileSteps", M.steps, { desc = "Show the compile pipeline" })
end

return M
