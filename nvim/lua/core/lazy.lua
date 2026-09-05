-- Plugin manager bootstrap (lazy.nvim).
--
-- Plugin versions are pinned in lazy-lock.json, which is committed, so every
-- machine gets the same set. Run :Lazy update deliberately, then commit the
-- new lock file.

-- `:Reload` re-runs init.lua; lazy.setup() must not run twice.
if vim.g.lazy_bootstrapped then
  return
end
vim.g.lazy_bootstrapped = true

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  vim.notify("Bootstrapping lazy.nvim...")
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to clone lazy.nvim:\n" .. out, vim.log.levels.ERROR)
    return
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = {} },
  checker = { enabled = false },  -- don't phone home looking for updates
  change_detection = { notify = false },
  ui = { border = "rounded" },
})
