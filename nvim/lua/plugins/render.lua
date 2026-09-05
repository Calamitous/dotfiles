-- render-markdown.nvim -- conceals markdown syntax and renders headings,
-- lists, code blocks and tables in the buffer.
--
-- Not live preview, but much closer to Obsidian's reading view than raw text.
-- Colours defer to lua/core/highlights.lua where they overlap.
--
-- No nvim-treesitter dependency: neovim 0.12 bundles the markdown and
-- markdown_inline parsers already, so pulling in the plugin would only add a
-- parser-compilation step for grammars we have.

return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = "markdown",
  opts = {
    -- Render everything except the line the cursor is on, so editing shows
    -- the real syntax where you're working.
    render_modes = { "n", "v", "i", "c" },
    anti_conceal = { enabled = true },
    heading = {
      sign = false,
      icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
      width = "block",
      left_pad = 0,
    },
    code = { sign = false, width = "block", left_pad = 1, right_pad = 1 },
    bullet = { icons = { "•", "◦", "▪", "▫" } },
    checkbox = {
      unchecked = { icon = "☐ " },
      checked = { icon = "☑ " },
    },
    quote = { icon = "▎" },
    link = { enabled = true },
    -- Long prose paragraphs shouldn't be reflowed or padded.
    paragraph = { enabled = false },
  },
}
