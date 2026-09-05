-- Vale -- a prose linter that runs YOUR rules.
--
-- Deliberately no shipped styles. Vale's Microsoft/Google/write-good packages
-- are technical-writing house styles, which is why pointing stock Vale at
-- fiction makes it sound like documentation. `:ValeInit` scaffolds a config
-- with custom rules only, drawn from the craft analysis of this manuscript.
--
-- Rules live in the vault (<vault>/.vale/), so they're versioned with the book
-- and can differ per project. Delete any rule that turns out to be noisy --
-- that's the intended workflow, not a failure.

local vault = require("writing.vault")

local M = {}

M.rules = {}

M.rules["FilterWords.yml"] = [[
extends: existence
message: "Filter word: '%s' puts a layer between the reader and the POV."
level: suggestion
ignorecase: true
tokens:
  - '(?:she|he|they) (?:felt|saw|heard|noticed|realized|realised|watched|observed|wondered|decided|knew|thought|seemed to)'
]]

M.rules["AdverbDialogueTag.yml"] = [[
extends: existence
message: "Adverbial dialogue tag: '%s'. Let the line carry the tone."
level: suggestion
ignorecase: true
tokens:
  - '(?:said|asked|replied|answered|whispered|shouted) \w+ly'
]]

-- NOTE: `nonword: true`. Vale wraps tokens in \b word boundaries by default,
-- which can never match a pattern starting with a quotation mark.
-- Do NOT reach for `raw` here: Vale CONCATENATES raw entries into a single
-- regex rather than alternating them, so a multi-pattern raw list silently
-- matches nothing. tokens are OR'd, which is what's wanted.
M.rules["AssentEnding.yml"] = [[
extends: existence
message: "Assent construction: '%s'. Weak as a chapter ending -- check where this falls."
level: suggestion
nonword: true
tokens:
  - '"I will[,."]'
  - '"Yes, (?:father|mother|my lord|my lady)[,."]'
  - '"As you (?:wish|say)[,."]'
]]

M.rules["Hedges.yml"] = [[
extends: existence
message: "Hedge: '%s' softens the sentence."
level: suggestion
ignorecase: true
tokens:
  - '\b(?:somewhat|rather|quite|very|really|slightly|a bit|almost|nearly|sort of|kind of)\b'
]]

M.config_ini = [[
# Vale configuration -- custom rules only.
#
# No packages are installed on purpose: Vale's shipped styles (Microsoft,
# Google, write-good) are technical-writing house styles and make fiction read
# like documentation.

StylesPath = .vale
MinAlertLevel = suggestion

[*.md]
BasedOnStyles = Prose
]]

-- Dismissals ----------------------------------------------------------------
--
-- A "won't do" list, so a Vale run reads as a checklist rather than the same
-- suggestions every time. Entries are keyed on the RULE plus the TEXT OF THE
-- LINE, not the line number -- so a dismissal survives edits elsewhere in the
-- chapter, but a line you actually rewrite is re-evaluated, which is what you
-- want.
--
-- Stored in <vault>/.vale-dismissed, one record per line, so it's versioned
-- with the book and shared across machines.

M.dismiss_file = ".vale-dismissed"

--- Vault of the most recent run. The quickfix window has no filename, so
--- vault.root() can't resolve from it once `copen` has taken the cursor.
M.last_root = nil

local function dismiss_path(root)
  return root .. "/" .. M.dismiss_file
end

local function key(check, line_text)
  return check .. "\t" .. vim.fn.sha256(vim.trim(line_text or "")):sub(1, 16)
end

local function load_dismissed(root)
  local path = dismiss_path(root)
  local set = {}
  if vim.fn.filereadable(path) == 0 then
    return set
  end
  for _, line in ipairs(vim.fn.readfile(path)) do
    local k = line:match("^([^\t]+\t[^\t]+)")
    if k then
      set[k] = true
    end
  end
  return set
end

--- Dismiss the quickfix entry under the cursor.
function M.dismiss()
  local qf = vim.fn.getqflist({ items = 0, idx = 0 })
  local item = qf.items[qf.idx]
  if not item or not item.user_data or not item.user_data.check then
    vim.notify("No Vale entry here", vim.log.levels.WARN)
    return
  end

  local root = item.user_data.root or M.last_root or vault.root()
  if not root then
    vim.notify("Can't locate the vault for this entry", vim.log.levels.WARN)
    return
  end

  local record = string.format(
    "%s\t%s",
    key(item.user_data.check, item.user_data.line_text),
    vim.trim(item.user_data.line_text or ""):sub(1, 90)
  )

  local path = dismiss_path(root)
  local existing = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
  table.insert(existing, record)
  vim.fn.writefile(existing, path)

  -- Drop it from the visible list so the checklist shrinks as you work.
  table.remove(qf.items, qf.idx)
  vim.fn.setqflist({}, "r", { title = "Vale", items = qf.items })
  vim.notify(string.format("Dismissed [%s] (%d left)", item.user_data.check, #qf.items))
end

--- Forget every dismissal in this vault.
function M.undismiss_all()
  local root = vault.root() or M.last_root
  if not root then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end
  local path = dismiss_path(root)
  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
    vim.notify("Cleared all Vale dismissals")
  else
    vim.notify("No dismissals to clear")
  end
end

--- Create .vale.ini and the rule files in the current vault.
function M.init()
  local root = vault.root()
  if not root then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end

  local dir = root .. "/.vale/Prose"
  vim.fn.mkdir(dir, "p")

  local ini = root .. "/.vale.ini"
  local created = {}

  if vim.fn.filereadable(ini) == 0 then
    vim.fn.writefile(vim.split(M.config_ini, "\n"), ini)
    table.insert(created, ".vale.ini")
  end

  for name, body in pairs(M.rules) do
    local path = dir .. "/" .. name
    if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile(vim.split(body, "\n"), path)
      table.insert(created, ".vale/Prose/" .. name)
    end
  end

  if #created == 0 then
    vim.notify("Vale config already present in " .. vim.fs.basename(root))
  else
    vim.notify("Created:\n  " .. table.concat(created, "\n  "))
  end
end

--- Lint one or more paths into the quickfix list.
--- @param path string|string[]|nil  defaults to the current buffer
function M.run(path)
  if vim.fn.executable("vale") ~= 1 then
    vim.notify("vale not installed", vim.log.levels.ERROR)
    return
  end

  local root = vault.root()
  if not root then
    vim.notify("Not inside an Obsidian vault", vim.log.levels.WARN)
    return
  end
  if vim.fn.filereadable(root .. "/.vale.ini") == 0 then
    vim.notify("No .vale.ini in this vault -- run :ValeInit", vim.log.levels.WARN)
    return
  end

  path = path or vim.api.nvim_buf_get_name(0)
  local paths = type(path) == "table" and path or { path }
  if #paths == 0 or paths[1] == "" then
    vim.notify("Nothing to lint", vim.log.levels.WARN)
    return
  end

  local cmd = { "vale", "--output=JSON" }
  vim.list_extend(cmd, paths)

  M.last_root = root

  vim.system(cmd, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      local ok, parsed = pcall(vim.json.decode, res.stdout or "")
      if not ok or type(parsed) ~= "table" then
        vim.notify("vale: " .. vim.trim((res.stderr or "") .. (res.stdout or "")), vim.log.levels.ERROR)
        return
      end

      local dismissed = load_dismissed(root)
      local lines_cache = {}
      local items, skipped = {}, 0

      for file, alerts in pairs(parsed) do
        local abs = vim.startswith(file, "/") and file or (root .. "/" .. file)
        if not lines_cache[abs] then
          lines_cache[abs] = vim.fn.filereadable(abs) == 1 and vim.fn.readfile(abs) or {}
        end

        for _, a in ipairs(alerts) do
          local line_text = lines_cache[abs][a.Line] or ""
          if dismissed[key(a.Check or "?", line_text)] then
            skipped = skipped + 1
          else
            table.insert(items, {
              filename = abs,
              lnum = a.Line,
              col = (a.Span and a.Span[1]) or 1,
              text = string.format("[%s] %s", a.Check or "?", a.Message or ""),
              type = a.Severity == "error" and "E" or (a.Severity == "warning" and "W" or "I"),
              user_data = { check = a.Check or "?", line_text = line_text, root = root },
            })
          end
        end
      end

      local suffix = skipped > 0 and string.format(" (%d dismissed)", skipped) or ""

      if #items == 0 then
        vim.notify("Vale: clean" .. suffix)
        return
      end

      table.sort(items, function(x, y) return x.lnum < y.lnum end)
      vim.fn.setqflist({}, "r", { title = "Vale", items = items })
      vim.cmd("copen")
      vim.notify(string.format("Vale: %d suggestion(s)%s", #items, suffix))
    end)
  end)
end

--- Lint every scene in the current draft.
---
--- Deliberately the scene list from Index.md, not the folder: the folder also
--- holds Index.md, notes files, and the compiled manuscript -- linting that
--- last one would report every issue in the book a second time.
function M.draft()
  local index = vault.draft()
  if not index then
    vim.notify("No draft above this buffer", vim.log.levels.WARN)
    return
  end

  local d = require("writing.draft").read(index)
  if not d or #d.scenes == 0 then
    vim.notify("No scenes listed in " .. vim.fs.basename(index), vim.log.levels.WARN)
    return
  end

  local paths = {}
  for _, scene in ipairs(d.scenes) do
    local p = require("writing.draft").scene_path(d, scene)
    if vim.uv.fs_stat(p) then
      table.insert(paths, p)
    end
  end

  vim.notify(string.format("Vale: linting %d scenes...", #paths))
  M.run(paths)
end

function M.setup()
  vim.api.nvim_create_user_command("Vale", function(o)
    M.run(o.args ~= "" and vim.fn.expand(o.args) or nil)
  end, { nargs = "?", complete = "file", desc = "Lint prose with Vale" })

  vim.api.nvim_create_user_command("ValeDraft", M.draft, { desc = "Lint the whole draft with Vale" })
  vim.api.nvim_create_user_command("ValeInit", M.init, { desc = "Create Vale config in this vault" })
  vim.api.nvim_create_user_command("ValeDismiss", M.dismiss, { desc = "Dismiss the Vale entry under the cursor" })
  vim.api.nvim_create_user_command("ValeUndismissAll", M.undismiss_all, { desc = "Clear all Vale dismissals" })

  -- `x` dismisses inside the quickfix window, so the list works as a checklist.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ValeQuickfix", { clear = true }),
    pattern = "qf",
    callback = function(args)
      vim.keymap.set("n", "x", M.dismiss, { buffer = args.buf, desc = "Vale: won't do" })
    end,
  })
end

return M
