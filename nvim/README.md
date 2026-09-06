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
| `<Leader>S` | turn spell check on/off (`:Spell`) |

Two independent checkers, two sets of keys — worth keeping straight:

| | spell check | harper (grammar) |
|---|---|---|
| jump | `]s` / `[s` | `]d` / `[d` |
| toggle | `<Leader>S` / `:Spell` | `<Leader>h` / `:Harper` |
| accept the word | `zg` | `zg` (same list) |
| dismiss one | — | `<Leader>x` |

**`:Checks` toggles both at once** (`<Leader>H`, and `<F3>`). It doesn't flip
them independently: if either is on, both go off; if both are off, both come
on — so they can't drift out of step.

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

## Prose linting

Two checkers, doing different jobs.

**Harper** (grammar) runs as an LSP on every markdown buffer, quietly — hints,
not errors, with no virtual text.

| Key | Does |
|---|---|
| `<Leader>h` | **turn grammar checking on/off** |
| `]d` / `[d` | next / previous suggestion |
| `<Leader>d` | full detail for the one under the cursor |
| `<Leader>a` | accept a fix (code action) |
| `<Leader>x` | **ignore this one** — leaves the prose alone |
| `zg` | add the word to this vault's dictionary |

**Why is this word underlined?** The message for the line your cursor is on
appears beneath it automatically -- only that line, so the page isn't littered.
`<Leader>d` opens the full detail in a float; `<Leader>a` offers the fix.

**Which one to reach for.** An unknown word is underlined by *two* independent
things — harper's diagnostic and vim's own spell checker — so:

| Situation | Use | Why |
|---|---|---|
| a name or invented word (*Shazedah*, *sanat-magi*) | **`zg`** | teaches **both**; the underline goes away entirely |
| a grammar or style suggestion you disagree with | `<Leader>x` | silences harper only |

`<Leader>x` on a *spelling* flag leaves the spell underline in place and looks
like it didn't work. It now says so when that happens.

**`zg` takes effect immediately.** Harper caches its dictionary, so a word added
while writing used to stay flagged until nvim restarted. `zg`, `zw` and friends
now push a `didChangeConfiguration` at harper so it re-reads. One keystroke
teaches the spell checker and the grammar checker together.

**Both ignore lists travel with the vault.** Vale's dismissals live in
`<vault>/.vale-dismissed`. Harper's own store is machine-local and keyed by
absolute path (`~/.local/share/harper-ls/ignored_lints/`), so it's mirrored
into `<vault>/.harper-ignored/` under vault-relative names: exported when you
ignore something and on exit, imported the first time you open a markdown file
in that vault. Commit both directories and your decisions follow you between
machines.

`:HarperSync` forces a round trip if you want it immediately.

This works because the files hold *content hashes* rather than positions, so
only the filename needed rewriting. One trap if you ever touch this code: the
hashes are u64 and must never pass through `vim.json.decode`, which turns them
into floats and silently destroys the match.

**Drafting vs revising.** `<Leader>h` (`:Harper`) silences it without stopping
the server, so nothing is recomputed when you turn it back on. To start every
session quiet, set `M.enabled_by_default = false` in `lua/core/lsp.lua` and
switch it on when you revise.

It reads **the same dictionary `zg` writes** (`Meta/dictionary.utf-8.add`), so a
word added while writing is known to the spell checker and the grammar checker
both. Adding the existing BBaS dictionary dropped its diagnostics on one
chapter from 119 to 77.

Linters are tuned for fiction in `lua/core/lsp.lua` — `SentenceCapitalization`
and `LongSentences` are off, because dialogue is full of fragments and sentence
length is a choice.

**Vale** (style) runs on demand, with **your** rules and no shipped styles.

| Key | Command | Does |
|---|---|---|
| `<Leader>vv` | `:Vale` | lint **this chapter** into the quickfix list |
| `<Leader>vd` | `:ValeDraft` | lint **every chapter in the book** |
| | `:ValeInit` | create the config in this vault |

> **"file" vs "draft."** A *file* is the buffer you're in — one chapter. A
> *draft* is the whole book: the scene list in `Index.md`, all 63 of them.
> "Draft" is Longform's word for a manuscript project (scene list + workflow),
> which unfortunately collides with the everyday "first draft / second draft".
> Same distinction applies to `:WordCount` vs `:WordCountDraft`.
>
> Draft-wide commands read the **scene list**, not the folder — the folder also
> contains `Index.md`, notes, and the compiled manuscript, and linting that
> would report every issue in the book twice.

`:ValeInit` writes `.vale.ini` and `.vale/Prose/*.yml` into the vault, so rules
are versioned with the book and can differ per project. The starting set comes
from the craft analysis of BBaS:

| Rule | Flags |
|---|---|
| `FilterWords` | `she felt`, `she saw`, `she noticed` — distance from POV |
| `AdverbDialogueTag` | `said quietly`, `said harshly` |
| `AssentEnding` | `"I will,"` and friends — weak chapter endings |
| `Hedges` | `very`, `quite`, `rather`, `almost` |

Deleting a noisy rule is the intended workflow, not a failure.

**Using the list as a checklist.** In the quickfix window, `x` marks the entry
under the cursor as *won't do*: it drops off the list and stays off on future
runs. `:ValeUndismissAll` clears them.

| Key | Does |
|---|---|
| `<CR>` | jump to the entry |
| `x` | won't do -- dismiss permanently |
| `]q` / `[q` | next / previous entry without leaving the file |

Dismissals live in `<vault>/.vale-dismissed`, so they're versioned with the book
and shared across machines. They're keyed on the **rule plus the text of the
line**, not the line number -- so:

- editing elsewhere in the chapter doesn't resurrect them,
- but **rewriting that line brings the suggestion back**, because the sentence
  you dismissed no longer exists.

For a permanent, in-prose exception, Vale's own comments also work:
`<!-- vale Prose.Hedges = NO -->` ... `<!-- vale Prose.Hedges = YES -->`. Those
travel with the text and are stripped by `compile.rb`, so they never reach the
manuscript.

**Two Vale gotchas**, both of which silently match nothing rather than erroring:
`tokens` are wrapped in `\b` word boundaries, so a pattern starting with a
quotation mark needs `nonword: true`; and `raw` entries are **concatenated**
into one regex rather than alternated, so a multi-pattern `raw` list is almost
never what you want.

## Compiling a manuscript

`../bin/compile.rb` builds a manuscript from a Longform draft, replacing the
Longform compile chain. It's usable from a shell on its own; nvim just fronts it.

Its output is byte-identical to Longform's own compile, verified against a
freshly generated build of BBaS Vol 1 (11,846 lines, 136,525 words).

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
