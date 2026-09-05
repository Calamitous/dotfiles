-- Prose mode -- a forward port of WordProcessorMode() (`:WP`) from ~/.vimrc,
-- made buffer-local and auto-enabled for markdown inside a vault.
--
-- Deliberately omitted from the original: `set paste`, which disables
-- insert-mode abbreviations, insert mappings and textwidth. It was masking
-- the abbreviation support this config depends on.
--
-- No `formatprg`: this vault convention is one line per paragraph, soft-wrapped.
-- Reflowing with `gq` would hard-wrap chapters and produce huge git diffs.
-- The mthesaur.txt thesaurus is wired up only if actually present.

local vault = require("writing.vault")

local M = {}

M.thesaurus = vim.fn.expand("~/.vim/thesaurus/mthesaur.txt")

--- Per-vault spelling dictionary, relative to the vault root. `zg` adds the
--- word under the cursor; `zw` marks one wrong; `z=` suggests. Because it lives
--- in the vault, invented vocabulary travels with the book in its own repo --
--- the same arrangement as Meta/Abbreviations.md.
M.spellfile = "Meta/dictionary.utf-8.add"

--- Point 'spellfile' at this vault's dictionary, creating the folder if needed.
local function set_spellfile(bufnr)
  local path = vault.path(M.spellfile, bufnr)
  if not path then
    return
  end
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  vim.opt_local.spellfile = path
end

local function set_local_options()
  vim.opt_local.wrap = true
  vim.opt_local.linebreak = true
  vim.opt_local.breakindent = true
  vim.opt_local.textwidth = 0
  vim.opt_local.colorcolumn = ""
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.list = false
  vim.opt_local.spell = true
  vim.opt_local.spelllang = "en_us"
  set_spellfile()
  vim.opt_local.expandtab = true
  vim.opt_local.conceallevel = 2

  -- Thesaurus-backed completion (<C-x><C-t>), only if the file exists.
  if vim.uv.fs_stat(M.thesaurus) then
    vim.opt_local.thesaurus:append(M.thesaurus)
    vim.opt_local.complete:append("s")
  end
end

local function set_local_maps(bufnr)
  local opts = { buffer = bufnr, silent = true }

  -- Move by display line, not logical line -- essential with soft wrap.
  for _, key in ipairs({ "j", "k" }) do
    vim.keymap.set({ "n", "v" }, key, function()
      return vim.v.count == 0 and ("g" .. key) or key
    end, vim.tbl_extend("force", opts, { expr = true }))
  end
  vim.keymap.set({ "n", "v" }, "<Down>", "gj", opts)
  vim.keymap.set({ "n", "v" }, "<Up>", "gk", opts)
  vim.keymap.set({ "n", "v" }, "0", "g0", opts)
  vim.keymap.set({ "n", "v" }, "$", "g$", opts)

  -- Undo breakpoints at sentence boundaries, so `u` rewinds a sentence at a
  -- time rather than an entire paragraph.
  for _, ch in ipairs({ ".", "!", "?", ":", "," }) do
    vim.keymap.set("i", ch, ch .. "<C-g>u", opts)
  end
end

function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_call(bufnr, function()
    set_local_options()
    set_local_maps(bufnr)
  end)
  vim.b[bufnr].prose_mode = true
end

function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_call(bufnr, function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = false
    vim.opt_local.number = true
    vim.opt_local.conceallevel = 0
    for _, key in ipairs({ "j", "k", "0", "$", "<Down>", "<Up>" }) do
      pcall(vim.keymap.del, { "n", "v" }, key, { buffer = bufnr })
    end
    for _, ch in ipairs({ ".", "!", "?", ":", "," }) do
      pcall(vim.keymap.del, "i", ch, { buffer = bufnr })
    end
  end)
  vim.b[bufnr].prose_mode = false
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.b[bufnr].prose_mode then
    M.disable(bufnr)
    vim.notify("Prose mode off")
  else
    M.enable(bufnr)
    vim.notify("Prose mode on")
  end
end

function M.setup()
  local vault = require("writing.vault")

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("WritingProse", { clear = true }),
    pattern = "markdown",
    callback = function(args)
      -- Auto-enable only inside a vault; a stray README stays a normal buffer.
      if vault.in_vault(args.buf) then
        M.enable(args.buf)
      end
    end,
  })

  vim.api.nvim_create_user_command("WP", function() M.toggle() end, { desc = "Toggle prose mode" })
  vim.api.nvim_create_user_command("ProseMode", function() M.toggle() end, { desc = "Toggle prose mode" })
end

return M
