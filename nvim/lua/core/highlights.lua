-- Markdown highlighting for prose.
--
-- Everything you'd want to tweak is in the two tables at the top.
--
-- On italics: neovim asks for real italics (`@markup.italic` links to `Italic`,
-- which is `gui=italic`). If they show up as REVERSE VIDEO instead, the
-- terminal is substituting, and no neovim setting can fix it:
--
--   * tmux -- `set -g default-terminal "tmux-256color"`. The common
--     `screen-256color` has no italic capability at all (terminfo `sitm`).
--   * urxvt / xterm -- render italics as reverse unless an italic font
--     variant is configured. kitty handles them out of the box.
--
-- Test your terminal with:  printf '\e[3mitalic\e[0m\n'
--
-- If you'd rather not fight it, set `M.italics = false` below: emphasis then
-- reads as colour alone, which every terminal can do.

local M = {}

--- Use real italics for emphasis. Set false if your terminal fakes them
--- with reverse video.
M.italics = false

--- Colours. nil means "leave whatever the colorscheme chose".
M.palette = {
  italic = "#d3a0d8", -- _emphasis_
  strong = "#f0c674", -- **bold**
  heading = "#81a2be",
  heading_alt = "#8abeb7", -- deeper heading levels
  raw = "#b5bd68", -- `code`
  link = "#7aa6da",
  quote = "#8a8a8a",
  list = "#b294bb",
  strike = "#6f6f6f",
}

function M.apply()
  local p = M.palette
  local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- Emphasis. `reverse`/`standout` are explicitly off so that a terminal
  -- without italic support falls back to plain coloured text rather than
  -- inverting the line.
  hl("@markup.italic", { fg = p.italic, italic = M.italics, reverse = false, standout = false })
  hl("@markup.strong", { fg = p.strong, bold = true, reverse = false, standout = false })
  hl("@markup.strikethrough", { fg = p.strike, strikethrough = true })

  -- Bold-italic (***both***) should read as clearly more than either.
  hl("@markup.strong.emphasis", { fg = p.strong, bold = true, italic = M.italics })

  -- Headings: bold throughout, shading down through the levels.
  for level = 1, 6 do
    hl("@markup.heading." .. level, {
      fg = level <= 2 and p.heading or p.heading_alt,
      bold = true,
    })
  end
  hl("@markup.heading", { fg = p.heading, bold = true })

  hl("@markup.raw", { fg = p.raw })
  hl("@markup.raw.block", { fg = p.raw })
  hl("@markup.link", { fg = p.link })
  hl("@markup.link.label", { fg = p.link, underline = true })
  hl("@markup.link.url", { fg = p.link, underline = true })
  hl("@markup.quote", { fg = p.quote, italic = M.italics })
  hl("@markup.list", { fg = p.list })
  hl("@markup.list.checked", { fg = p.raw })
  hl("@markup.list.unchecked", { fg = p.quote })

  -- Concealed markers (the `_` and `**` themselves) shouldn't draw the eye.
  hl("Conceal", { fg = p.quote })

  -- Legacy vim-syntax groups, in case treesitter is ever off for a buffer.
  vim.api.nvim_set_hl(0, "htmlItalic", { fg = p.italic, italic = M.italics })
  vim.api.nvim_set_hl(0, "htmlBold", { fg = p.strong, bold = true })
  vim.api.nvim_set_hl(0, "markdownItalic", { fg = p.italic, italic = M.italics })
  vim.api.nvim_set_hl(0, "markdownBold", { fg = p.strong, bold = true })
end

--- Toggle real italics at runtime, for testing what the terminal can do.
function M.toggle_italics()
  M.italics = not M.italics
  M.apply()
  vim.notify("Italics " .. (M.italics and "on (real)" or "off (colour only)"))
end

function M.setup()
  M.apply()
  -- Colorschemes reset highlight groups; reapply after any change.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("WritingHighlights", { clear = true }),
    callback = M.apply,
  })
  vim.api.nvim_create_user_command("Italics", M.toggle_italics, {
    desc = "Toggle real italics vs colour-only emphasis",
  })
end

return M
