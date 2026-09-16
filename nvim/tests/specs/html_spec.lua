local t = require("tests.harness")
local platform = require("core.platform")

t.describe("copy as HTML")

t.it("puts HTML on the clipboard on every platform", function()
  -- Obsidian's "Copy as HTML" sets the text/html flavor; so should this. RTF
  -- was a detour forced by pbcopy, and it cost the horizontal rules.
  for _, name in ipairs({ "mac", "wayland", "xclip" }) do
    t.matches(platform.pipelines[name], "%-t html", "the " .. name .. " route converts to html")
  end
  t.ok(not platform.pipelines.mac:find("textutil", 1, true), "macOS no longer goes via RTF")
end)

t.it("hands over character entities rather than raw UTF-8", function()
  -- A bare pandoc fragment declares no charset, so an em dash is at the mercy
  -- of whatever the receiving app assumes. Entities are not.
  for _, name in ipairs({ "mac", "wayland", "xclip", "xsel" }) do
    t.matches(platform.pipelines[name], "%-%-ascii", name .. " asks for entities")
  end
end)

t.it("leaves the author's punctuation alone", function()
  -- pandoc's `smart` extension is on by default and quietly curls quotes,
  -- turns -- into an en dash and ... into an ellipsis. The clipboard should
  -- hand over what was written.
  for _, name in ipairs({ "mac", "wayland", "xclip", "xsel" }) do
    t.matches(platform.pipelines[name], "markdown%-smart", name .. " disables smart punctuation")
  end

  local res = vim.system({ "bash", "-o", "pipefail", "-c",
    (platform.pipelines.xclip:gsub("| xclip.*", "")) },
    { stdin = [[She said "no" -- really... ]] }):wait()

  t.ok(res.code == 0, "pipeline ran")
  t.matches(res.stdout, '"no"', "quotes stay straight")
  t.matches(res.stdout, "%-%-", "the double hyphen stays a double hyphen")
  t.matches(res.stdout, "%.%.%.", "and the three dots stay three dots")
end)

local function mac_without_osascript()
  return (platform.pipelines.mac:gsub("| osascript %-", ""))
end

local function decode(hex)
  return (hex:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

t.it("builds AppleScript carrying BOTH clipboard flavors", function()
  -- pbcopy can only write plain text and RTF; the HTML pasteboard type has to
  -- go through AppleScript as a raw data object. And HTML alone isn't enough
  -- -- a paste into anything plain-text would land empty.
  local res = vim.system({ "bash", "-o", "pipefail", "-c", mac_without_osascript() },
    { stdin = 'One "quoted".\n\n---\n\n*Two.*\n' }):wait()
  t.ok(res.code == 0, "pipeline ran")

  local html = res.stdout:match("data HTML(%x+)")
  local text = res.stdout:match("data utf8(%x+)")
  t.ok(html ~= nil, "an HTML flavor is set")
  t.ok(text ~= nil, "and a plain-text one alongside it")

  html, text = decode(html), decode(text)
  t.matches(html, "<hr />", "the scene break survives -- the whole point of dropping RTF")
  t.matches(html, "<em>Two%.</em>", "and so does the emphasis")
  t.matches(html, '"quoted"', "quotes stay straight in the HTML")

  t.matches(text, "%*Two%.%*", "the plain flavor is the markdown as written")
  t.matches(text, '"quoted"', "straight there too")
  t.ok(not text:find("<", 1, true), "and carries no markup")
end)

t.it("needs no escaping for prose that contains quotes or backslashes", function()
  -- Everything reaches AppleScript as hex, so nothing in a chapter can end the
  -- string early or be read as syntax.
  local nasty = [[He said \"it\\ ends\" -- \u{00ab}really\u{00bb}...]]
  local res = vim.system({ "bash", "-o", "pipefail", "-c", mac_without_osascript() },
    { stdin = nasty }):wait()

  t.ok(res.code == 0, "pipeline ran")
  t.matches(decode(res.stdout:match("data utf8(%x+)")), vim.pesc(nasty), "round-trips byte for byte")
end)

t.it("reports a failure instead of copying nothing", function()
  -- The old `{ ...; }` group ended in a printf that always succeeded, so a
  -- broken pandoc still looked like a clean copy.
  local broken = platform.pipelines.mac:gsub("pandoc ", "pandoc --bogus-flag ", 1)
  local res = vim.system({ "bash", "-o", "pipefail", "-c", (broken:gsub("| osascript %-", "")) },
    { stdin = "x" }):wait()
  t.ok(res.code ~= 0, "a failure upstream is a failure overall")
end)

t.it("keeps the xclip output redirected", function()
  -- xclip owns the selection for as long as it lives; an inherited stdout
  -- keeps the pipe open and the caller waits forever.
  t.matches(platform.pipelines.xclip, ">/dev/null 2>&1", "detached")
end)

t.it("runs pipelines under a shell that reports mid-pipe failures", function()
  local argv = platform.shell()
  if argv[1] == "bash" then
    t.matches(table.concat(argv, " "), "pipefail", "a failing pandoc must not be masked downstream")
  else
    t.ok(argv[1] == "sh", "falls back to plain sh when there is no bash")
  end
  t.ok(argv[#argv] == "-c", "the pipeline is appended as the final argument")
end)

t.it("actually returns non-zero when a middle stage fails", function()
  local argv = platform.shell()
  table.insert(argv, "false | cat")
  t.ok(vim.system(argv):wait().code ~= 0, "pipefail is in effect, not just spelled correctly")
end)
