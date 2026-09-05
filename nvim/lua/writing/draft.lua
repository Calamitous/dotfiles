-- Read a Longform draft definition out of an Index.md.
--
-- This is a deliberately narrow reader, not a YAML parser: the shape is fixed
-- by Longform's own serialiser (setDraftOnFrontmatterObject), so we only need
-- the handful of keys it emits.
--
--   ---
--   longform:
--     format: scenes
--     title: Brass, Bone, & Steel Volume 1
--     sceneFolder: /
--     scenes:
--       - 1 - Falling Star
--   ---
--
-- Nested (indented) scenes are flattened; order is preserved.

local M = {}

--- @param path string  absolute path to an Index.md
--- @return table|nil { title, format, workflow, sceneFolder, scenes[] }
function M.read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or lines[1] ~= "---" then
    return nil
  end

  local draft = { scenes = {}, path = path }
  local in_longform, in_scenes = false, false

  for i = 2, #lines do
    local line = lines[i]
    if line == "---" then
      break
    end

    local indent = #(line:match("^(%s*)") or "")
    local trimmed = vim.trim(line)

    if trimmed == "" then
      goto continue
    end

    if indent == 0 then
      -- A new top-level key ends the longform block (and any scene list).
      in_longform = trimmed:match("^longform:") ~= nil
      in_scenes = false
      goto continue
    end

    if not in_longform then
      goto continue
    end

    local item = trimmed:match("^%-%s*(.+)$")
    if in_scenes and item then
      -- Strip optional quoting Longform may add around awkward titles.
      item = item:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
      table.insert(draft.scenes, item)
      goto continue
    end

    local key, value = trimmed:match("^([%w_]+):%s*(.*)$")
    if key then
      in_scenes = (key == "scenes")
      if not in_scenes and value ~= "" then
        value = value:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
        draft[key] = value
      end
    end

    ::continue::
  end

  return draft
end

--- Absolute path to a scene file within a draft.
function M.scene_path(draft, scene)
  local dir = vim.fs.dirname(draft.path)
  local folder = draft.sceneFolder
  if folder and folder ~= "/" and folder ~= "" then
    dir = dir .. "/" .. folder:gsub("^/", ""):gsub("/$", "")
  end
  return dir .. "/" .. scene .. ".md"
end

--- Every Index.md in the vault, so a draft can be picked when several exist.
--- @param root string  vault root
function M.list(root)
  local found = vim.fn.globpath(root, "**/Index.md", true, true)
  local drafts = {}
  for _, path in ipairs(found) do
    if not path:find("/%.obsidian/") then
      local draft = M.read(path)
      if draft and #draft.scenes > 0 then
        table.insert(drafts, draft)
      end
    end
  end
  table.sort(drafts, function(a, b) return a.path < b.path end)
  return drafts
end

return M
