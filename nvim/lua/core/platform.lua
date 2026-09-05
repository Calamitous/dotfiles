-- Platform differences. This config runs on both Manjaro and macOS.

local M = {}

M.sysname = vim.uv.os_uname().sysname
M.is_mac = M.sysname == "Darwin"
M.is_linux = M.sysname == "Linux"

local function has(bin)
  return vim.fn.executable(bin) == 1
end

--- Shell pipeline that takes markdown on stdin and puts RICH TEXT on the
--- system clipboard. Returns nil if no route is available.
---
--- The three platforms need genuinely different things:
---   * macOS   pbcopy can't accept text/html, so convert to RTF first with
---             textutil -- that's what pastes as formatted text into Pages,
---             Word and Docs.
---   * Wayland wl-copy takes a MIME type directly.
---   * X11     xclip takes a target; its output MUST be redirected or it holds
---             the pipe open for as long as it owns the selection and the
---             caller hangs.
function M.html_clipboard_cmd()
  if not has("pandoc") then
    return nil, "pandoc not found"
  end

  if M.is_mac then
    if not has("textutil") or not has("pbcopy") then
      return nil, "textutil/pbcopy not found"
    end
    return "pandoc -f markdown -t html | textutil -stdin -format html -convert rtf -stdout | pbcopy"
  end

  if vim.env.WAYLAND_DISPLAY and has("wl-copy") then
    return "pandoc -f markdown -t html | wl-copy --type text/html"
  end

  if has("xclip") then
    return "pandoc -f markdown -t html | xclip -selection clipboard -t text/html >/dev/null 2>&1"
  end

  if has("xsel") then
    return "pandoc -f markdown -t html | xsel --clipboard --input >/dev/null 2>&1"
  end

  return nil, "no clipboard tool found (want pbcopy, wl-copy, xclip or xsel)"
end

--- Open a file or URL with the desktop handler.
function M.opener()
  if M.is_mac then
    return "open"
  end
  return "xdg-open"
end

return M
