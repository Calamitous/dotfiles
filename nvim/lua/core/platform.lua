-- Platform differences. This config runs on both Manjaro and macOS.

local M = {}

M.sysname = vim.uv.os_uname().sysname
M.is_mac = M.sysname == "Darwin"
M.is_linux = M.sysname == "Linux"

local function has(bin)
  return vim.fn.executable(bin) == 1
end

--- Shell pipelines that take markdown on stdin and put RICH TEXT on the
--- system clipboard.
---
--- All of them put HTML on the clipboard -- the same thing Obsidian's "Copy as
--- HTML" does, and what Docs and Word read to reconstruct formatting.
---
---   * macOS   `pbcopy` is the awkward one: it only writes the plain-text and
---             RTF pasteboard flavors, so it CANNOT carry text/html at all.
---             AppleScript can, via a raw `«data HTML…»` object, so the HTML
---             is hex-encoded and handed to osascript. (An earlier version
---             converted to RTF with textutil instead. That pastes as
---             formatted text, but RTF has no horizontal-rule element, so
---             every `---` scene break was silently dropped on the way -- see
---             `mac_rtf` below, kept as a fallback.)
---   * Wayland wl-copy takes a MIME type directly.
---   * X11     xclip takes a target; its output MUST be redirected or it holds
---             the pipe open for as long as it owns the selection and the
---             caller hangs.
---
--- `--ascii` throughout: pandoc writes a bare fragment with no charset
--- declared, so an em dash or curly quote is at the mercy of whatever encoding
--- the receiving app assumes. `&#x2014;` entities are not.
---
--- `markdown-smart` turns OFF pandoc's smart-punctuation extension, which is
--- on by default and rewrites straight quotes as curly, `--` as an en dash and
--- `...` as an ellipsis. The clipboard should hand over the manuscript as
--- written; typographic decisions belong to the author, not the pipe.
M.pipelines = {
  -- Read stdin once, then hex-encode two flavors of it. Hex rather than a
  -- quoted AppleScript string so nothing in the prose -- quotes, backslashes,
  -- newlines -- has to be escaped on the way through.
  --
  -- Both flavors matter: HTML alone means a paste into anything plain-text
  -- (a terminal, a text field, another editor) silently yields nothing.
  --
  -- Separate statements rather than one `{ ...; }` group: a group's exit
  -- status is its last command's, which here would always be a successful
  -- printf, and a failed pandoc would go unreported again.
  mac = [[md=$(cat); ]]
    .. [[html=$(printf '%s' "$md" | pandoc -f markdown-smart -t html --ascii ]]
    .. [[| hexdump -ve '1/1 "%.2x"') || exit 1; ]]
    .. [[text=$(printf '%s' "$md" | hexdump -ve '1/1 "%.2x"') || exit 1; ]]
    .. [[printf 'set the clipboard to {«class HTML»:«data HTML%s», «class utf8»:«data utf8%s»}' ]]
    .. [["$html" "$text" | osascript -]],

  wayland = "pandoc -f markdown-smart -t html --ascii | wl-copy --type text/html",
  xclip = "pandoc -f markdown-smart -t html --ascii | xclip -selection clipboard -t text/html >/dev/null 2>&1",
  xsel = "pandoc -f markdown-smart -t html --ascii | xsel --clipboard --input >/dev/null 2>&1",
}

--- The old RTF route, for if AppleScript turns out not to cooperate.
---
--- Swap it in with `require("core.platform").pipelines.mac = ...mac_rtf` (or
--- edit the table above). It pastes as formatted text everywhere, at the cost
--- of losing `<hr />`: the sed rewrites scene breaks to a centred `* * *` so
--- they at least survive in some form.
M.pipelines.mac_rtf = "pandoc -f markdown-smart -t html --ascii "
  .. [[| sed 's|<hr />|<p style="text-align:center">* * *</p>|g' ]]
  .. "| textutil -stdin -format html -convert rtf -stdout | pbcopy"

--- Pick the pipeline this machine can actually run.
--- @return string|nil pipeline, string|nil error
function M.html_clipboard_cmd()
  if not has("pandoc") then
    return nil, "pandoc not found"
  end

  if M.is_mac then
    if not has("osascript") or not has("hexdump") then
      return nil, "osascript/hexdump not found"
    end
    return M.pipelines.mac
  end

  if vim.env.WAYLAND_DISPLAY and has("wl-copy") then
    return M.pipelines.wayland
  end

  if has("xclip") then
    return M.pipelines.xclip
  end

  if has("xsel") then
    return M.pipelines.xsel
  end

  return nil, "no clipboard tool found (want pbcopy, wl-copy, xclip or xsel)"
end

--- Shell to run a clipboard pipeline under.
---
--- `pipefail` is the whole point: without it the exit status is the LAST
--- command's, so a pandoc or textutil failure still ends in a happy `pbcopy`
--- and you get a silent empty clipboard with no error. macOS /bin/sh is bash,
--- but Linux /bin/sh may be dash, which has no pipefail -- so ask for bash by
--- name and fall back to a plain sh rather than emitting a syntax error.
--- @return string[] argv prefix, to which the pipeline is appended
function M.shell()
  if has("bash") then
    return { "bash", "-o", "pipefail", "-c" }
  end
  return { "sh", "-c" }
end

--- Open a file or URL with the desktop handler.
function M.opener()
  if M.is_mac then
    return "open"
  end
  return "xdg-open"
end

return M
