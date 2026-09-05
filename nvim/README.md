# nvim — prose writing environment

Neovim configured for writing, against the Obsidian vaults under `~/Writing`.
Code editing stays in **vim** (`../vimrc`); nothing here touches that setup.

Install: `ln -s ~/Projects/dotfiles/nvim ~/.config/nvim`

Press `<Leader>?` (`:WritingHelp`) inside nvim for this list. Leader is **space**.

## Keymaps

### Navigation
| Key | Command | Does |
|---|---|---|
| `<Leader>o` | `:Files` | fuzzy-find files in the vault |
| `<Leader>/` | `:Grep` | live-grep the vault contents |
| `<Leader>b` | `:Buffers` | switch buffer |
| `<Leader>e` | `:Sidebar` | file navigator, at this file's folder |
| `<Leader>E` | `:SidebarVault` | file navigator, at the vault root |
| `<Leader>,` | `:Config` | open this config |
| `<Leader>r` | `:Reload` | reload the config in place |

`:Reload` re-runs the config without restarting. It cannot remove a keymap or
command you deleted from a file — for that, restart.

Both pickers run the real `fzf` binary in a floating window, scoped to the
**vault root** (not the git root). `ctrl-v` / `ctrl-x` / `ctrl-t` open in a
vsplit / split / tab, `Tab` multi-selects, `Esc` aborts. Matching is
case-insensitive; flip `M.ignore_case` in `lua/writing/find.lua` for smart-case.

### Wikilinks (obsidian.nvim)
| Key | Command | Does |
|---|---|---|
| `<Leader>kr` | `:Obsidian rename` | **rename a note and rewrite every link to it** |
| `gf` / `<CR>` | `:Obsidian follow_link` | follow the `[[link]]` under the cursor |
| `<Leader>kf` | `:Obsidian follow_link` | same, explicitly |
| `<Leader>kb` | `:Obsidian backlinks` | what links here |
| `<Leader>ks` | `:Obsidian quick_switch` | jump to a note by title |
| `<Leader>kn` | `:Obsidian new` | new note |
| `<Leader>kt` | `:Obsidian toc` | table of contents |
| `<Leader>kl` | `:Obsidian links` | links in this note |
| `<Leader>kg` | `:Obsidian search` | grep across notes |
| `<Leader>k#` | `:Obsidian tags` | tags |
| `<Leader>ko` | `:Obsidian open` | open this note in the Obsidian app |

More subcommands available to bind, all in `lua/core/keymaps.lua`:
`footnotes` `template` `new_from_template` `workspace` `bookmarks` `paste_img`
`unique_note` `today` `tomorrow` `yesterday` `dailies` `rebuild_cache` `check`.
Run `:Obsidian` and press `<Tab>` to see the current list.

Rename rewrites `[[Note]]`, `[[Note|alias]]`, `[[Note#heading]]`, `[[Note#^block]]`
and `![[Note]]` embeds across the vault. **Use `<Leader>kr` and answer the
prompt** -- `:Obsidian rename Two Words` fails, because the subcommand takes a
single argument.

`gf` is routed through the plugin deliberately. Vim's native `gf` builds its
target from `<cfile>`, and since `'isfname'` contains no space it truncates
`[[Fortney Nurani, Princess]]` to `Fortney` -- so it appeared to work only for
links whose first word was already unique. `<CR>` does the same thing.

Renaming any other way -- `mv`, the `<Leader>e` sidebar, a file manager -- will
**not** update links. That's equally true of Obsidian itself.

### Inserting a wikilink

Type `[[`, then **`<C-Space>`** to list matching notes. Completions come from
the built-in `obsidian-ls` LSP; no separate completion engine is needed.

`<C-Space>` is worth the habit because autocompletion only fires on the
server's trigger characters (`[`, `#`, `^`). Typing `[[` therefore asks with an
*empty* query, and the letters you type afterwards don't ask again -- so a menu
often never appears on its own. `<C-Space>` asks at the point you've reached.
(`<C-x><C-o>`, vim's built-in omni-completion, does the same thing.)

The completion list includes a **create** entry, so `[[New Note` + `<C-Space>`
offers to make a note that doesn't exist yet.

The LSP only attaches inside a registered workspace: a directory under
`~/Writing` containing `.obsidian/`. Outside one, links are inert text.

### Moving around

Standard vim, but worth knowing next to the link keys:

| Key | Does |
|---|---|
| `<C-o>` | jump **back** -- e.g. return to the chapter after following a link |
| `<C-i>` | jump forward again |
| `<C-^>` | toggle between the two most recent files |
| `` ` `` `` ` `` | back to your position before the last jump in this file |

`<C-o>` walks a *history* of every jump across files, so pressing it repeatedly
rewinds your whole path. `<C-^>` just flips between two files, which is usually
what you want when checking a character sheet while writing a chapter.

### Writing
| Key | Command | Does |
|---|---|---|
| `<Leader>wr` | `:Reading` | centred fixed-width reading mode |
| `<Leader>wp` | `:WP` | prose mode — wrap, spell, `gj`/`gk` (alias `:ProseMode`) |
| `<Leader>y` | `:CopyHTML` | copy buffer *or selection* as rich text |
| `<Leader>s` | `z=` | spelling suggestions |
| `<Leader>l` | `:CheckboxToggle` | check/uncheck a checkbox, or add one to a list item |

`:Reading 100` sets a one-off width; the default lives in `M.width`
(`lua/writing/reading.lua`). Prose mode auto-enables for markdown inside a vault.

`<Leader>l` works on the cursor line or a visual selection. `- [ ]` toggles to
`- [x]` and back; a bare list item (`- task`, `* task`, `1. task`) gains a
checkbox; anything else is left alone.

`:CopyHTML` runs the text through pandoc into the clipboard as `text/html`, so a
paste into Google Docs or Word arrives formatted. Frontmatter, `%%comments%%`
and wikilink syntax are stripped first.

### Counts
| Key | Command | Does |
|---|---|---|
| `<Leader>wc` | `:WordCount` | this buffer |
| `<Leader>wd` | `:WordCountDraft` | the whole draft, scene by scene |
| `<Leader>wD` | `:WordCountDir` | a directory, per file |

Counts exclude frontmatter, comments and wikilink syntax, and sort chapter files
numerically (`2 -` before `10 -`).

### Vault
| Key | Command | Does |
|---|---|---|
| `<Leader>wv` | `:VaultInfo` | which vault and draft this buffer is in |
| `<Leader>wa` | `:AbbrevEdit` | edit this vault's abbreviations |
| `<Leader>wA` | `:AbbrevReload` | reload them after editing |

## Per-vault abbreviations

Each vault can define its own, in `<vault>/Meta/Abbreviations.md` — editable
from Obsidian too. Either syntax works:

```markdown
| Abbr | Expands to |
| ---- | ---------- |
| bsh  | Bayze Shab |

nmr = Namarûn
```

They install **buffer-locally**, so two vaults' abbreviations can be open at
once without collision. `:AbbrevEdit` creates the file if it doesn't exist.

**Adding one is `<Leader>wa`, type the row, `:w`.** Saving the file reapplies it
to every open markdown buffer automatically -- no reload step. `:AbbrevReload`
(`<Leader>wA`) is only needed if the file changed outside nvim, e.g. edited in
Obsidian or pulled from git.

> **Never set `paste`.** It silently disables insert-mode abbreviations,
> insert mappings and `textwidth`. It is deliberately absent from this config.

## Spelling

A fantasy manuscript is full of words no dictionary has, so each vault keeps its
own dictionary at `<vault>/Meta/dictionary.utf-8.add`:

| Key | Does |
|---|---|
| `zg` | add the word under the cursor to this vault's dictionary |
| `zw` | mark the word under the cursor as wrong |
| `z=` | suggestions (also `<Leader>s`) |
| `]s` / `[s` | next / previous misspelling |

The dictionary lives in the vault, so invented vocabulary travels with the book
in its own git repo -- the same arrangement as `Meta/Abbreviations.md`.

`zg` also writes a compiled `dictionary.utf-8.add.spl` beside it. Commit the
`.add` (it's your word list); the `.spl` is generated and can be ignored:

```gitignore
Meta/*.spl
```

Misspellings are **underlined** by default. Undercurl is deliberately not the
default: terminals that can't draw it (notably `xterm-256color` over ssh or
tmux) fall back to **reverse video**, which looks like broken highlighting. Set
`M.spell_style` in `lua/core/highlights.lua` to `"undercurl"`, `"text"` or
`"off"` to taste.

## Appearance

Colours and emphasis styling live in the two tables at the top of
`lua/core/highlights.lua`.

**If `_italics_` render as reverse video**, the terminal is faking them and no
neovim setting can fix it. Test with `printf '\e[3mitalic\e[0m\n'`:

- **tmux** — needs `set -g default-terminal "tmux-256color"`. The common
  `screen-256color` has no italic capability at all.
- **urxvt / xterm** — render italics as reverse unless an italic font variant is
  configured. kitty works out of the box.

`:Italics` toggles between real italics and colour-only emphasis, which every
terminal can display.

## Layout

```
init.lua                    entry point
lua/core/options.lua        editor options
lua/core/keymaps.lua        global keymaps  <- add hotkeys here
lua/core/highlights.lua     markdown colours and emphasis
lua/writing/vault.lua       vault + draft detection (the keystone)
lua/writing/draft.lua       Longform Index.md reader
lua/writing/abbrev.lua      per-vault abbreviations
lua/writing/prose.lua       prose mode
lua/writing/reading.lua     centred reading mode
lua/writing/find.lua        fzf pickers
lua/writing/html.lua        copy as rich text
lua/writing/wordcount.lua   word counts
```

Buffer-local mappings live in the module that owns them (prose mode's `j`/`k`,
for instance), not in `keymaps.lua`.

## Design notes

Full spec, including why things are built this way and what Obsidian
compatibility requires, is in the workshop vault:
`Claude/Claude Notebook Analyses/2026-09-05 - Tooling Spec - Neovim as an Obsidian-Compatible Writing Environment.md`

Two rules that matter:

1. **Obsidian stays usable.** Both tools read the same files. Anything written
   here must survive a round trip through Obsidian, and vice versa.
2. **Never write Longform's files from outside Obsidian.** Obsidian caches file
   and plugin state in memory and flushes on change, so external writes can be
   silently clobbered. Read them; don't write them.

## Compiling a manuscript

`../bin/compile.rb` builds a manuscript from a Longform draft, replacing the
Longform compile chain. It's usable from a shell on its own; nvim just fronts it.

| Key | Command | Does |
|---|---|---|
| `<Leader>mc` | `:Compile` | build the manuscript |
| `<Leader>mk` | `:CompileCheck` | build **without writing**, show the diff |
| `<Leader>ml` | `:CompileList` | drafts in this vault (`*` = selected) |

From a shell: `compile.rb`, `--list`, `--check`, `--docx`, `--select PATH`.

**Which draft?** In order: an `Index.md` above the current file, then this
tool's own `.compile-draft`, then Longform's remembered selection. So a vault
with several books (A&A has five drafts) compiles the one you're editing.

**Configuration** goes in `Index.md` as a `compile:` key *sibling* to
`longform:` -- never nested inside it, because Longform rebuilds that key
wholesale on every write:

```yaml
longform:
  scenes: [...]          # Obsidian still drives this
compile:
  output: My Book.md
  steps:
    - strip_frontmatter
    - remove_links
    - crunch_comments
    - prepend_title: "# Chapter $title"
    - concatenate: "\n\n---\n\n"
    - msword_hrs
```

Reorder steps by moving lines. Omit the block entirely and the Longform default
workflow is used. A vault can add its own steps in `<vault>/bin/compile_steps.rb`,
so custom behaviour is versioned with the book rather than duplicated here.

**It never writes Longform's files** -- not `Index.md`, not anything under
`.obsidian/`. Obsidian caches those in memory and flushes on change, so an
outside write can be silently clobbered. Read-only in that direction, always.

## Saving doesn't touch what you didn't edit

Opening a chapter and saving it produces **no** git diff. Two defaults had to
change for that:

- **`fixeol` is off.** Obsidian writes files without a trailing newline; nvim
  would otherwise add one, so the first save of every file showed up as a
  change.
- **Trailing whitespace is not stripped in markdown.** Two trailing spaces are
  a hard line break in markdown, so stripping them silently alters rendering.
  It still strips in other filetypes.

Verified against real chapters: open, `:wq`, byte-identical.

## Plugins

Managed by `lazy.nvim`; versions pinned in `lazy-lock.json` (committed).
`:Lazy` for the UI, `:Lazy update` to update -- then commit the new lock file.

| Plugin | For |
|---|---|
| `obsidian.nvim` | wikilinks, rename-with-link-rewrite, `[[` completion |
| `render-markdown.nvim` | in-buffer rendering of headings, lists, code, tables |
| `plenary.nvim` | dependency of obsidian.nvim |

Two obsidian.nvim settings are load-bearing and should not be changed:
`frontmatter.enabled = false` (otherwise it rewrites frontmatter on save, which
would fight Longform's `longform:` block) and `ui.enable = false`
(render-markdown owns rendering; running both double-renders every line).

## Requirements

`fzf` and `ripgrep` (pickers) · `pandoc` and `xclip` (copy as HTML).
Each feature degrades quietly if its tool is missing.
