-- Create a note from one of the vault's own templates.
--
-- Obsidian's core Templates plugin keeps its library in a folder named in
-- <vault>/.obsidian/templates.json -- every vault here says "Z. Templates".
-- This reads that file rather than hardcoding the name, so a vault that moves
-- its templates keeps working, and it only ever READS .obsidian/, the same
-- stance compile.rb takes.
--
-- Deliberately NOT :NewScene. This never touches a draft's Index.md, because a
-- character sheet or a location note is not a chapter. :NewScene stays the
-- command for prose, and it keeps its own template (.scriptorium/Scene.md) so
-- that adding a chapter needs no picker at all.
--
-- The template library is also where Longform keeps its compile scripts
-- ("Z. Templates/Longform Scripts/*.js"), so only markdown is offered.

local vault = require("writing.vault")
local find = require("writing.find")

local M = {}

--- Folder to use when .obsidian/templates.json is missing or says nothing.
---
--- Obsidian's own default for an unset folder is "", meaning the vault root --
--- useless here, since then every note in the vault would look like a
--- template. This is the name all the vaults actually use.
M.default_folder = "Z. Templates"

--- strftime formats for the {{date}} and {{time}} placeholders.
---
--- Obsidian's templates.json can carry `dateFormat`/`timeFormat` in moment.js
--- syntax; no vault here sets either, and translating moment to strftime for a
--- setting nobody uses isn't worth the surface. These are Obsidian's own
--- defaults (YYYY-MM-DD, HH:mm) spelled for strftime.
M.date_format = "%Y-%m-%d"
M.time_format = "%H:%M"

--- The templates folder for a vault, as an absolute path.
---
--- @param root string|nil  vault root; defaults to the current buffer's
--- @return string|nil  absolute path, or nil if there is no such directory
function M.folder(root)
  root = root or vault.root()
  if not root then
    return nil
  end

  local name = M.default_folder
  local config = root .. "/.obsidian/templates.json"
  if vim.fn.filereadable(config) == 1 then
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(config), "\n"))
    -- `folder` can legitimately be "" (the vault root). Treat that as unset:
    -- offering every note as a template is worse than offering none.
    if ok and type(data) == "table" and type(data.folder) == "string" and data.folder ~= "" then
      name = data.folder
    end
  end

  local dir = name:sub(1, 1) == "/" and name or (root .. "/" .. name)
  return vim.fn.isdirectory(dir) == 1 and dir or nil
end

--- Every markdown template in the vault, as paths relative to the folder.
---
--- Sorted, and nested paths included: the libraries here are organised into
--- "Worldbuilding/" and friends, and the subfolder is half the name.
--- @return string[]
function M.list(root)
  local dir = M.folder(root)
  if not dir then
    return {}
  end

  local found = {}
  for name, type in vim.fs.dir(dir, { depth = 8 }) do
    if type == "file" and name:sub(-3) == ".md" then
      table.insert(found, name)
    end
  end
  table.sort(found)
  return found
end

--- Substitute Obsidian's core template placeholders.
---
--- {{title}}, {{date}} and {{time}} are the three the core Templates plugin
--- defines, so a template written for this command still behaves in Obsidian.
--- Anything else in braces is left exactly as it is -- a Templater expression
--- or a literal `{{foo}}` in prose is not ours to rewrite.
---
--- @param lines string[]
--- @param title string
--- @param now integer|nil  unix time, for the specs
--- @return string[]
function M.render(lines, title, now)
  now = now or os.time()
  local subs = {
    title = title,
    date = os.date(M.date_format, now),
    time = os.date(M.time_format, now),
  }

  local out = {}
  for i, line in ipairs(lines) do
    -- gsub with a function, so a replacement containing % or \ can't be read
    -- as a capture reference. Character names have apostrophes and ampersands.
    out[i] = (line:gsub("{{%s*([%w_]+)%s*}}", function(key)
      return subs[key:lower()]
    end))
  end
  return out
end

--- Copy `template` to `path`, substituting placeholders.
---
--- @param template string  absolute path to the template
--- @param path string  absolute path to create
--- @param title string  for {{title}}
--- @return boolean ok, string|nil err
function M.create(template, path, title)
  if vim.fn.filereadable(template) ~= 1 then
    return false, "template is not readable: " .. template
  end
  if vim.uv.fs_stat(path) then
    return false, vim.fn.fnamemodify(path, ":~:.") .. " already exists"
  end

  local body = M.render(vim.fn.readfile(template), title)
  -- Like :NewScene, the parent is created if it's missing. That's the Obsidian
  -- behaviour for a new note in a new folder, and it is not the `output:`
  -- rule from compile.rb -- a note is something you're authoring now, not a
  -- build artifact landing somewhere you may have mistyped.
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  if vim.fn.writefile(body, path) ~= 0 then
    return false, "could not write " .. path
  end
  return true, nil
end

--- Where the prompt starts: the current buffer's folder, vault-relative,
--- with a trailing slash. Empty string at the vault root.
--- @return string
function M.prefill(root, bufname)
  bufname = bufname or vim.api.nvim_buf_get_name(0)
  local dir = (bufname ~= "" and vim.fs.dirname(bufname)) or vim.uv.cwd()
  if not dir or dir:sub(1, #root) ~= root then
    return ""
  end
  local rel = dir:sub(#root + 2)
  return rel == "" and "" or (rel .. "/")
end

--- Resolve what the prompt came back with, against the vault root.
---
--- Vault-relative always, so the prefilled folder and anything typed over it
--- mean the same thing. `.md` is appended if it's missing.
--- @return string|nil  absolute path
function M.resolve(root, answer)
  answer = vim.trim(answer or "")
  if answer == "" or answer:sub(-1) == "/" then
    return nil
  end
  if answer:sub(-3) ~= ".md" then
    answer = answer .. ".md"
  end
  return vim.fs.normalize(root .. "/" .. answer)
end

--- Pick a template, name the file, open it. <Leader>mt
function M.pick()
  local root = vault.root()
  if not root then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end

  local dir = M.folder(root)
  if not dir then
    vim.notify(
      string.format("No templates folder in this vault (looked for %s/)", M.default_folder),
      vim.log.levels.WARN
    )
    return
  end

  if #M.list(root) == 0 then
    vim.notify("No markdown templates in " .. vim.fn.fnamemodify(dir, ":~:."), vim.log.levels.WARN)
    return
  end

  -- No --expect: there's one thing to do with a template, so the split keys
  -- would only be a way to get the wrong result.
  local cmd = table.concat({
    "find . -type f -name '*.md' | sed 's|^\\./||' | sort",
    "| fzf --exit-0 --no-multi " .. find.fzf_case(),
    "--prompt='Template> '",
    "--preview 'cat {}'",
    "--preview-window=right:55%:wrap",
  }, " ")

  find.run(cmd, dir, "templates — " .. vim.fs.basename(root), function(lines)
    local choice = lines[1]
    if not choice or choice == "" then
      return
    end

    local ok, answer = pcall(vim.fn.input, {
      prompt = "New note: ",
      default = M.prefill(root),
      completion = "file",
      cancelreturn = "",
    })
    if not ok then
      return
    end

    local path = M.resolve(root, answer)
    if not path then
      return
    end

    local written, err = M.create(dir .. "/" .. choice, path, vim.fn.fnamemodify(path, ":t:r"))
    if not written then
      vim.notify(err, vim.log.levels.WARN)
      return
    end

    -- Step off a reading-mode margin before opening, like the file picker.
    pcall(function()
      require("writing.reading").leave_pad()
    end)
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.notify(string.format("%s, from %s", vim.fn.fnamemodify(path, ":~:."), choice))
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("NewFromTemplate", M.pick, {
    desc = "Create a note from one of the vault's templates",
  })

  vim.api.nvim_create_user_command("Templates", function()
    local dir = M.folder()
    if not dir then
      vim.notify("No templates folder in this vault", vim.log.levels.WARN)
      return
    end
    require("writing.find").files(dir)
  end, { desc = "Browse this vault's templates" })
end

return M
