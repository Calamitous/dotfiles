-- Add a chapter to the current draft.
--
-- Two things have to happen: create the file from a template, and list it in
-- the draft's Index.md. The second is the awkward one -- Index.md is
-- Longform's, and everything else here treats it as read-only, because
-- Obsidian caches it in memory and flushes on change, so an outside write can
-- be silently clobbered.
--
-- So: this refuses to run while Obsidian is open, and appends to the scene
-- list TEXTUALLY rather than parsing and re-emitting the YAML -- a round trip
-- would drop comments and could reorder keys.
--
-- Template: <vault>/.scriptorium/Scene.md (edit it to taste).

local vault = require("writing.vault")
local draft = require("writing.draft")

local M = {}

M.template = "Scene.md"

--- Is Obsidian running? Process name differs by platform.
local function obsidian_running()
  for _, name in ipairs({ "obsidian", "Obsidian" }) do
    local res = vim.system({ "pgrep", "-x", name }, { text = true }):wait()
    if res.code == 0 and vim.trim(res.stdout or "") ~= "" then
      return true
    end
  end
  return false
end

--- Append `title` to the `scenes:` list of a Longform Index.md, in place.
--- Returns true, or false plus a reason.
local function add_to_index(index_path, title)
  local lines = vim.fn.readfile(index_path)

  local scenes_at, indent
  for i, line in ipairs(lines) do
    local lead = line:match("^(%s*)scenes:%s*$")
    if lead then
      scenes_at, indent = i, #lead
      break
    end
  end
  if not scenes_at then
    return false, "no `scenes:` list found in " .. vim.fs.basename(index_path)
  end

  -- Last consecutive list item belonging to that block.
  local last, item_indent = scenes_at, indent + 2
  for i = scenes_at + 1, #lines do
    local lead, rest = lines[i]:match("^(%s*)(.*)$")
    if rest:match("^%-%s") and #lead > indent then
      last, item_indent = i, #lead
    elseif rest ~= "" then
      break
    end
  end

  for i = scenes_at + 1, last do
    if lines[i]:match("^%s*%-%s*" .. vim.pesc(title) .. "%s*$") then
      return false, "already listed in the draft"
    end
  end

  table.insert(lines, last + 1, string.rep(" ", item_indent) .. "- " .. title)
  vim.fn.writefile(lines, index_path)
  return true
end

--- Create a scene and add it to the draft.
function M.create(title)
  local root = vault.root()
  if not root then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end

  local index = vault.draft()
  if not index then
    vim.notify("No draft (Index.md) above this buffer", vim.log.levels.WARN)
    return
  end

  title = vim.trim(title or "")
  if title == "" then
    title = vim.trim(vim.fn.input("New chapter title: "))
    if title == "" then
      return
    end
  end

  local d = draft.read(index)
  local path = draft.scene_path(d, title)

  if vim.uv.fs_stat(path) then
    vim.notify(vim.fs.basename(path) .. " already exists", vim.log.levels.WARN)
    return
  end

  if obsidian_running() then
    vim.notify(
      "Obsidian is running -- close it first, or its cached copy of Index.md "
        .. "will overwrite the new scene.",
      vim.log.levels.ERROR
    )
    return
  end

  -- File, from the template if there is one.
  local template = vault.support_path(M.template)
  local body = (template and vim.fn.filereadable(template) == 1) and vim.fn.readfile(template) or { "" }
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(body, path)

  local ok, err = add_to_index(index, title)
  if not ok then
    vim.notify("Created " .. vim.fs.basename(path) .. ", but " .. err, vim.log.levels.WARN)
  else
    vim.notify(string.format("Added '%s' to %s", title, d.title or vim.fs.basename(index)))
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.cmd("normal! G")
end

--- Rewrite one entry in a draft's scene list, in place.
---
--- Textual, like the append in `create`: parsing and re-emitting the YAML would
--- lose the `compile:` block's formatting and could reorder keys.
--- @return boolean  whether the entry was found
function M.retitle(index, old_title, new_title)
  local lines = vim.fn.readfile(index)
  for i, line in ipairs(lines) do
    local indent = line:match("^(%s*)%-%s*" .. vim.pesc(old_title) .. "%s*$")
    if indent then
      lines[i] = indent .. "- " .. new_title
      vim.fn.writefile(lines, index)
      return true
    end
  end
  return false
end

--- Decide what a rename of `bufnr` should do.
---
--- Pure: no IO, no LSP, no prompting -- so the decision can be tested directly
--- while the LSP call itself stays obsidian.nvim's business.
---
--- @return table  { kind = "scene"|"note"|"error", old, index, reason }
function M.plan(bufnr)
  bufnr = bufnr or 0
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return { kind = "error", reason = "this buffer has no file" }
  end

  local old = vim.fs.basename(file):gsub("%.md$", "")
  local index = vault.draft(bufnr)
  if not index then
    -- Not in a draft: a plain note rename is all that's wanted.
    return { kind = "note", old = old }
  end

  local d = draft.read(index)
  for _, scene in ipairs((d or {}).scenes or {}) do
    if scene == old then
      return { kind = "scene", old = old, index = index }
    end
  end

  -- Inside a draft folder but not listed -- notes, outlines, the compiled
  -- manuscript. Rename it like any other note.
  return { kind = "note", old = old, index = index }
end

--- Rename the note in the current buffer.
---
--- The single entry point for every rename. When the buffer is a scene of the
--- current draft it also rewrites the scene list, which `:Obsidian rename`
--- cannot: scene entries are plain strings, not wikilinks, so a plain rename
--- leaves the draft pointing at a file that no longer exists.
function M.rename(new_title)
  local plan = M.plan(0)
  if plan.kind == "error" then
    vim.notify(plan.reason, vim.log.levels.WARN)
    return
  end

  new_title = vim.trim(new_title or "")
  if new_title == "" then
    new_title = vim.trim(vim.fn.input("Rename '" .. plan.old .. "' to: ", plan.old))
    if new_title == "" or new_title == plan.old then
      return
    end
  end

  if plan.kind == "scene" and obsidian_running() then
    vim.notify(
      "Obsidian is running -- close it first, or its cached copy of Index.md "
        .. "will undo the scene-list change.",
      vim.log.levels.ERROR
    )
    return
  end

  -- vim.lsp.buf.rename rather than `:Obsidian rename`, which takes a single
  -- argument and so can't handle a title with spaces.
  vim.lsp.buf.rename(new_title)

  if plan.kind ~= "scene" then
    return
  end

  -- The rename is async; wait for the new file before touching the index.
  local d = draft.read(plan.index)
  local target = draft.scene_path(d, new_title)
  if not vim.wait(5000, function()
    return vim.uv.fs_stat(target) ~= nil
  end, 100) then
    vim.notify("Rename didn't complete; scene list left alone", vim.log.levels.ERROR)
    return
  end

  if M.retitle(plan.index, plan.old, new_title) then
    vim.notify(string.format("Renamed '%s' -> '%s', draft updated", plan.old, new_title))
  else
    vim.notify("Renamed the file, but couldn't find it in the scene list", vim.log.levels.WARN)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("NewScene", function(o)
    M.create(o.args)
  end, { nargs = "*", desc = "Create a chapter and add it to the draft" })

  vim.api.nvim_create_user_command("Rename", function(o)
    M.rename(o.args)
  end, { nargs = "*", desc = "Rename this note (and the draft, if it's a scene)" })

  vim.api.nvim_create_user_command("SceneRename", function(o)
    M.rename(o.args)
  end, { nargs = "*", desc = "Alias for :Rename" })

  vim.api.nvim_create_user_command("SceneTemplate", function()
    local path = vault.support_path(M.template)
    if not path then
      vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
      return
    end
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.cmd.edit(vim.fn.fnameescape(path))
  end, { desc = "Edit this vault's scene template" })
end

return M
