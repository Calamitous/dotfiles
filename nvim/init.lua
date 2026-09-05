-- Neovim: prose-writing environment for the Obsidian vaults under ~/Writing.
-- Code editing stays in vim (~/.vimrc); nothing here touches that setup.
--
-- Spec: workshop vault, "2026-09-05 - Tooling Spec - Neovim as an
-- Obsidian-Compatible Writing Environment.md"

require("core.options")
require("core.keymaps")
require("core.reload").setup()
require("core.highlights").setup()
require("writing").setup()
