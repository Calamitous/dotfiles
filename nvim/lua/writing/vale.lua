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

--- Lint a file (default: current buffer) into the quickfix list.
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
  if path == "" then
    vim.notify("Buffer has no file", vim.log.levels.WARN)
    return
  end

  vim.system({ "vale", "--output=JSON", path }, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      local ok, parsed = pcall(vim.json.decode, res.stdout or "")
      if not ok or type(parsed) ~= "table" then
        vim.notify("vale: " .. vim.trim((res.stderr or "") .. (res.stdout or "")), vim.log.levels.ERROR)
        return
      end

      local items = {}
      for file, alerts in pairs(parsed) do
        for _, a in ipairs(alerts) do
          table.insert(items, {
            filename = file,
            lnum = a.Line,
            col = (a.Span and a.Span[1]) or 1,
            text = string.format("[%s] %s", a.Check or "?", a.Message or ""),
            type = a.Severity == "error" and "E" or (a.Severity == "warning" and "W" or "I"),
          })
        end
      end

      if #items == 0 then
        vim.notify("Vale: clean")
        return
      end

      table.sort(items, function(x, y) return x.lnum < y.lnum end)
      vim.fn.setqflist({}, "r", { title = "Vale", items = items })
      vim.cmd("copen")
      vim.notify(string.format("Vale: %d suggestion(s)", #items))
    end)
  end)
end

--- Lint the whole current draft.
function M.draft()
  local index = vault.draft()
  if not index then
    vim.notify("No draft above this buffer", vim.log.levels.WARN)
    return
  end
  M.run(vim.fs.dirname(index))
end

function M.setup()
  vim.api.nvim_create_user_command("Vale", function(o)
    M.run(o.args ~= "" and vim.fn.expand(o.args) or nil)
  end, { nargs = "?", complete = "file", desc = "Lint prose with Vale" })

  vim.api.nvim_create_user_command("ValeDraft", M.draft, { desc = "Lint the whole draft with Vale" })
  vim.api.nvim_create_user_command("ValeInit", M.init, { desc = "Create Vale config in this vault" })
end

return M
