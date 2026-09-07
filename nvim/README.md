# Scriptorium

A writing environment for the Obsidian vaults under `~/Writing`: neovim for
drafting and revising, `bin/compile.rb` for building a manuscript, and a shared
dictionary and rule set that travel with each book.

Named for the room where manuscripts were copied — it's a workshop, not a word
processor. It does not replace Obsidian; both tools read the same files, and
anything written here survives a round trip through the other.

Code editing stays in **vim** (`../vimrc`); nothing here touches that setup.

Install: `ln -s ~/Projects/dotfiles/nvim ~/.config/nvim`

Press `<Leader>?` (`:WritingHelp`) inside nvim for this list — it opens in a
scrollable float, two columns where the terminal is wide enough, one where it
isn't. `q` closes it. Leader is **space**.

## Keymaps

### Navigation
| Key | Command | Does |
|---|---|---|
| `<Leader>o` | `:Files` | fuzzy-find files in the vault |
| `<Leader>f` | `:Bookmark` | open a bookmarked file by key |
| `<Leader>/` | `:Grep` | live-grep the vault; the term is highlighted in the preview |
| `<Leader>b` | `:Buffers` | switch buffer |
| `<Leader>e` | `:Sidebar` | file navigator, at this file's folder |
| `<Leader>E` | `:SidebarVault` | file navigator, at the vault root |
| `<Leader>,` | `:Config` | open this config |
| `<Leader>q` | `:confirm qall` | **quit everything** — prompts if anything is unsaved |
| `<Leader>Q` | `:wqall` | save all and quit |
| `<Leader>r` | `:Reload` | reload the config in place |

`:Reload` re-runs the config without restarting. It cannot remove a keymap or
command you deleted from a file — for that, restart.

The search term is marked in the grep preview with a **background colour**
(bold black on yellow) rather than grep's default bold red, which is thin and
easy to lose in a wall of prose. Change it with `M.match_highlight` in
`lua/writing/find.lua` — an ANSI SGR list, e.g. `"1;37;44"` for white on blue or
`"1;31"` for grep's own red.

Both pickers run the real `fzf` binary in a floating window, scoped to the
**vault root** (not the git root). `ctrl-v` / `ctrl-x` / `ctrl-t` open in a
vsplit / split / tab, `Tab` multi-selects, `Esc` aborts. Matching is
case-insensitive; flip `M.ignore_case` in `lua/writing/find.lua` for smart-case.

### Wikilinks (obsidian.nvim)
| Key | Command | Does |
|---|---|---|
| **`<F2>`** | `:Rename` | **rename a note — and the scene list, if it's a chapter** |
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
| `<C-o>` | jump back to the **previous file** |
| `<C-i>` | jump forward to the next file |
| `<C-^>` | toggle between the two most recent files |
| `` ` `` `` ` `` | back to your position before the last jump in this file |

> **These two are changes to stock vim**, not vim behaviour. Everything else in
> this config adds keys rather than redefining them; `<C-o>` and `<C-i>` are the
> exception. Delete the two `map` lines in `lua/core/keymaps.lua` to get vim's
> own behaviour back — worth knowing, since your `vim` setup for code still has
> the stock keys and the two will differ.

`<C-o>` here is **not** vim's stock jump: it walks the jumplist until the *file*
changes, skipping searches and motions inside the file you're already in.
Getting back to the chapter after following a link is one press, not a dozen.
For within-file history use `g;` / `g,` (the change list) or `''` (position
before the last jump). `<C-^>` flips between the two most recent files.

### Resizing panes

| Key | Does |
|---|---|
| `<C-Left>` / `<C-Right>` | narrower / wider |
| `<C-Up>` / `<C-Down>` | taller / shorter |
| `<Leader>=` | equalise every pane |

These are additions, not replacements — stock `<C-w><` `<C-w>>` `<C-w>+`
`<C-w>-` `<C-w>=` and `:vertical resize 100` all still work.

`<C-Left>`/`<C-Right>` are **reading-aware**: in a centred pane a plain
`:vertical resize` hits the 80-column text window, so the margins stay put and
the split boundary never moves. These resize the pane's whole slot instead —
the text stays at its width and the margins take up the slack.

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

**Reading mode works one pane at a time.** `<Leader>wr` centres the window you're
in and leaves the others alone, so each pane can be toggled independently and
opening or closing a split doesn't disturb anything already centred.
`:ReadingOff` uncentres everything.

That's deliberate. Centring the whole layout and keeping it centred as windows
came and went needed a watcher, a re-apply on every change, a saved size
snapshot and a separate "wanted" flag — and produced a run of bugs: panes
crushed into a narrow channel, stale sizes restored, and a message from an
automatic re-apply that arrived as a hit-enter prompt and read as the cursor
freezing. Per pane needs none of it.

A pane narrower than about 90 columns can't hold an 80-column centre and says so.

Enabling reading mode on one pane leaves every other pane **exactly** as it was.
That needs enforcing: `leftabove vsplit` takes its columns from the pane's left
*neighbour*, so creating the margins silently shrank an unrelated pane by 40
columns. The pads, the centred pane and every untouched pane are now pinned
against one target map and converged together — pinning them in sequence just
means whichever went last wins.

Three further details that took some finding: the centred pane is **not** pinned with
`winfixwidth`, because pinning it means vim takes columns from the *other* panes
when a split opens — which looks like reading mode resizing windows it has
nothing to do with. Instead it reclaims width from its own margins. Splitting a
centred pane drops its centring rather than squeezing the new sibling into the
margins, detected by a stranger appearing between the pads (width alone can't
tell: vim borrows from the pads too, so a split leaves the pane at ~74 rather
than halving it). And the cursor is stepped off a padding window if anything
lands it there — `<C-w><C-w>` cycles through them otherwise, which reads as the
editor jumping to a corner of the screen.

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

## One-key file opening

`<Leader>f` then a key opens a file listed in `<vault>/.scriptorium/Bookmarks.md`:

```markdown
| Key | File |
| --- | ---- |
| e   | Metadata/Larger-Scale Edits.md |
| o   | Metadata/Outline.md |
| t   | TODOs.md |
```

`<Leader>f` on its own (or an unknown key) lists what's available; `:Bookmarks`
does the same, `:BookmarksEdit` opens the file.

It's **one mapping, resolved per vault** rather than one mapping per bookmark, so
`<Leader>fo` means a different outline in each book and nothing leaks between
them. Paths are relative to the vault root; absolute paths work too. A bookmark
pointing at a missing file says so instead of opening an empty buffer.

## Per-vault abbreviations

Each vault defines its own in `<vault>/.scriptorium/abbreviations.vim`, as
ordinary vim commands:

```vim
" Brass, Bone & Steel
iabbrev bsh Bayze Shab
iabbrev nmr Namarûn
iab dk D'khara
```

Real vimscript, so `:help abbreviations` applies and the file can be sourced by
hand. `<buffer>` is added automatically on the way in — that's what keeps vaults
apart, so `dk` can mean one thing in one book and something else in another with
both open at once. Plain global `:iabbrev` would leak across every vault.

An older `Abbreviations.md` table still works if there's no `.vim` file, and
`:AbbrevEdit` converts one to vim commands the first time you open it.

**They expand on punctuation as well as space** — `f.` `f,` `f!` `f?` `f:` `f"`
all work. That needed fixing: prose mode maps `.` `,` `!` `?` `:` for undo
breakpoints, and a mapped character *swallows* the expansion, since vim expands
on an unmapped non-keyword character. Those mappings now lead with `<C-]>` to
expand explicitly first. Worth knowing before adding any other insert-mode
mapping on a punctuation character.

They install **buffer-locally**, so two vaults' abbreviations can be open at
once without collision. `:AbbrevEdit` creates the file if it doesn't exist.

**Adding one is `<Leader>wa`, type the row, `:w`.** Saving the file reapplies it
to every open markdown buffer automatically -- no reload step. `:AbbrevReload`
(`<Leader>wA`) is only needed if the file changed outside nvim, e.g. edited in
Obsidian or pulled from git.

> **Never set `paste`.** It silently disables insert-mode abbreviations,
> insert mappings and `textwidth`. It is deliberately absent from this config.

## The statusline

```
 5 - Steel Heart.md          2,090 words  brass-bone-and-steel  41:17  32%
```

The word count is the **same one `:WordCount` and the compiler report** —
frontmatter, `%%comments%%` and wikilink syntax excluded — so the number in the
corner matches the number in a draft total. It's cached per buffer and refreshed
on a debounce, not recomputed on every redraw.

obsidian.nvim's own counts are turned off. It has two easily-confused options:
`footer` draws greyed virtual text at the *end of the file*
(`N backlinks  N properties  N words  N chars`), while `statusline` only sets
`b:obsidian_status`. Both are off — a count belongs in the statusline, not
appended to the prose, and backlinks, properties and character counts aren't
wanted at all.

`laststatus = 3` gives one bar for the whole window rather than one per split —
otherwise reading mode's padding columns would each get their own.

## Spelling

A fantasy manuscript is full of words no dictionary has, so each vault keeps its
own dictionary at `<vault>/.scriptorium/dictionary.utf-8.add`:

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
in its own git repo -- the same arrangement as `.scriptorium/Abbreviations.md`.

`zg` also writes a compiled `dictionary.utf-8.add.spl` beside it. Commit the
`.add` (it's your word list); the `.spl` is generated and can be ignored:

```gitignore
.scriptorium/*.spl
```

Misspellings are **underlined** by default. Undercurl is deliberately not the
default: terminals that can't draw it (notably `xterm-256color` over ssh or
tmux) fall back to **reverse video**, which looks like broken highlighting. Set
`M.spell_style` in `lua/core/highlights.lua` to `"undercurl"`, `"text"` or
`"off"` to taste.

## Notes to self

`%%comments%%` are dimmed and italicised so they read as annotation rather than
prose. Treesitter's markdown parser doesn't know about them — they're an
Obsidian extension — so nothing highlighted them otherwise, and a note sat in
the text looking exactly like the sentence beside it.

Multi-line comments are handled, and `<!-- html -->` ones too. The colour is
`comment` in the `M.palette` table (`lua/core/highlights.lua`).

They're stripped from the manuscript by `compile.rb`'s `crunch_comments` step,
so nothing here reaches a reader.

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

## Tests

```
nvim/tests/run              # everything
nvim/tests/run reading      # one spec
```

**One neovim per spec file.** State set by one spec — filetype detection, window
layout, module state — can't leak into the next, and a crash takes down only its
own file rather than the whole run.

Two things about `nvim -l` that the harness has to correct for, both of which
hide the same way (specs calling functions directly keep passing):

- it puts the config on the runtimepath but does **not** source `init.lua`, so
  `require` finds every module while none of their `setup()` has run — no
  autocmds, no commands, no keymaps;
- it starts with **filetype detection off**, so buffers open with no filetype
  and every `FileType` autocmd silently never fires. Specs that need it call
  `V.filetypes()`; it's opt-in because loading ftplugins makes the
  window-resizing specs trip an assertion in neovim's grid code. Each builds a throwaway
vault under `~/Writing` (vault detection needs `.obsidian`, and obsidian.nvim
only registers workspaces found there) and removes it afterwards. Exit status is
non-zero on failure, so it drops into CI or a git hook unchanged.

No plenary or busted: a suite that needs installing before you can check
anything works is one more thing to get wrong on a new machine.

Specs that need `obsidian-ls` **skip rather than fail** — the workspace list is
built when the plugin loads, so a vault created mid-run can't attach one.

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

## Picking up where you left off

Closing nvim in a vault saves its files and splits; opening `nvim` there again
restores them. Per vault, so each book keeps its own layout.

| Command | Does |
|---|---|
| `:SessionSave` | save now (also automatic on exit) |
| `:SessionRestore` | restore now |
| `:SessionInfo` | where the session is, when it was saved, how many files |
| `:SessionDelete` | forget this vault's layout |

**Only a bare `nvim` restores.** `nvim chapter.md` opens that chapter and leaves
the layout alone.

**It lives in the vault** — `.scriptorium/session.vim` — so it follows the book
between machines, and paths inside it are written **relative to the session
file** (`../Novels/Volume 1/5 - Steel Heart.md`). Nothing absolute, nothing
`$HOME`-dependent: move or clone the vault anywhere and the layout still opens
its own files. Window sizes are proportional, so they scale to the terminal.

The sidebar is remembered and **reopened** rather than restored, so it comes
back correctly configured. Reading mode and the Vale quickfix list are
deliberately excluded — they'd return as empty padding columns and a stale
results list.

Buffers from outside the vault aren't saved; they can't be expressed portably.

> **It changes on every exit,** so it will show in `git status` constantly and
> `bin/upload.sh` will sweep it into commits. That's the cost of it syncing at
> all. If both machines edit before syncing it can conflict — it's generated, so
> take either side.

A session is only saved if at least one file from the vault is open, so opening
nvim, doing nothing and quitting can't wipe the layout you saved yesterday.

> **Nested vaults.** The session belongs to the *nearest* directory containing
> `.obsidian`, walking up. If a subfolder of a vault has its own `.obsidian` —
> often a leftover from opening that folder in Obsidian once — it counts as a
> separate vault, with its own session, abbreviations and dictionary. Check with
> `<Leader>wv` (`:VaultInfo`) if a vault isn't behaving as one.

Turn either half off with `M.autosave` / `M.autorestore` in
`lua/writing/session.lua`.

## Setting up a vault

Scriptorium keeps its per-vault files in **`.scriptorium/`** — hidden, so it sits
with `.vale/` and `.harper-ignored/` rather than among your own note folders.
The name is one constant, `M.support` in `lua/writing/vault.lua`; change it
there and the spellfile, harper's dictionary and the abbreviations all follow.


```
cd ~/Writing/some-vault && scriptorium init    # or :VaultInit inside nvim
scriptorium init --dry-run                    # show what it would do
```

Installs, from `../vault-template/`:

| Path | For |
|---|---|
| `.gitignore` | keeps the generated `.scriptorium/*.spl` and Obsidian's per-machine UI state out of git |
| `.vale.ini`, `.vale/Prose/*.yml` | the prose rules |
| `.scriptorium/Abbreviations.md` | per-vault abbreviations |
| `.scriptorium/dictionary.utf-8.add` | shared by vim's speller and harper-ls |

**Non-destructive.** An existing file is never overwritten — it's reported as
kept. `.gitignore` is the one exception and is only appended to. Safe to re-run,
including to pick up rules added to the template later.

Edit the templates in `dotfiles/vault-template/`; they're real files, not
strings in a config, so a rule can be tested with `vale` directly before it goes
out to a vault.

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
| `<Leader>x` | **ignore this one** (`:HarperIgnore`) — leaves the prose alone |
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

`:HarperSync` forces a round trip if you want it immediately, and
`:HarperRefresh` makes harper re-read the dictionary without one.

This works because the files hold *content hashes* rather than positions, so
only the filename needed rewriting. One trap if you ever touch this code: the
hashes are u64 and must never pass through `vim.json.decode`, which turns them
into floats and silently destroys the match.

**Both checkers start OFF**, in step with each other. `<F3>` (`:Checks`) turns
spell and grammar on together for a revision pass. They're deliberately coupled:
with spell on and grammar off, the underlines that remained looked like harper
having only half-started. `M.enabled_by_default` (`lua/core/lsp.lua`) and
`M.spell_on_start` (`lua/writing/prose.lua`) set the startup state.

**Grammar starts OFF.** Drafting is undisturbed; `<Leader>h` (`:Harper`) or
`<F3>` turns it on for a revision pass without restarting the server, so nothing
is recomputed. Flip `M.enabled_by_default` in `lua/core/lsp.lua` to start every
session with it on instead.

It reads **the same dictionary `zg` writes** (`.scriptorium/dictionary.utf-8.add`), so a
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
| | `:VaultInit` | set this vault up (see below); `:ValeInit` is an alias |

> **"file" vs "draft."** A *file* is the buffer you're in — one chapter. A
> *draft* is the whole book: the scene list in `Index.md`, all 63 of them.
> "Draft" is Longform's word for a manuscript project (scene list + workflow),
> which unfortunately collides with the everyday "first draft / second draft".
> Same distinction applies to `:WordCount` vs `:WordCountDraft`.
>
> Draft-wide commands read the **scene list**, not the folder — the folder also
> contains `Index.md`, notes, and the compiled manuscript, and linting that
> would report every issue in the book twice.

The rules are copied into the vault by `:VaultInit`, so they're versioned with
the book and free to diverge per project. The starting set comes from the craft
analysis of BBaS:

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
| **`<F9>`** | `:Compile` | build the manuscript (works from insert mode too) |
| `<Leader>mc` | `:Compile` | same |
| `<Leader>mk` | `:CompileCheck` | build **without writing**, show the diff |
| `<Leader>ml` | `:CompileList` | drafts in this vault (`*` = selected) |
| `<Leader>ms` | `:CompileSteps` | show the pipeline and every available step |
| `<Leader>mn` | `:NewScene` | **new chapter from a template, added to the draft** |
| `<Leader>mr` | `:Rename` | same as `<F2>` |

From a shell, via the `scriptorium` front end:

| Command | Does |
|---|---|
| `scriptorium init` | set this vault up |
| `scriptorium compile` | build the manuscript |
| `scriptorium check` | build without writing; diff against the current output |
| `scriptorium steps` | the pipeline, and every step available |
| `scriptorium drafts` | list the drafts here (`*` = selected) |
| `scriptorium select <Index.md>` | remember which draft to build |
| `scriptorium docx` | build, and render a `.docx` |

`compile.rb` and `vault-init` still work directly — `scriptorium` is a front door
so there's one name to remember, not a replacement. nvim calls the underlying
scripts, so both symlinks are still needed.

**Modified buffers in the vault are written first.** `compile.rb` reads from
disk, so without this an unsaved edit is simply absent from the build — and
because nothing on disk changed, `git status` stays clean and it looks as
though the compile did nothing. Set `M.autosave = false` in
`lua/writing/compile.lua` if you'd rather it never wrote for you.

### Adding a chapter

`<Leader>mn` (`:NewScene "12 - Chapter Title"`, or no argument to be prompted)
creates the file from `<vault>/.scriptorium/Scene.md` and **adds it to the
draft's scene list**, then opens it. `:SceneTemplate` edits the template.

This is the only thing in Scriptorium that writes `Index.md`, so it takes two
precautions:

- **It refuses while Obsidian is running.** Obsidian caches `Index.md` in
  memory and flushes on change, so it would overwrite the new scene and you'd
  lose it silently.
- **It appends one line textually** rather than parsing and re-emitting the
  YAML, which would lose your `compile:` block's formatting and could reorder
  keys.

Longform sees the new chapter next time you open Obsidian; a chapter added over
there shows up here with no action needed.

**Renaming: one key for everything.** `<F2>` (`:Rename "12 - New Title"`) works on
any note. When the buffer is a **scene of the current draft** it also rewrites the
scene list — which a plain rename cannot, because scene entries are plain strings
rather than wikilinks, so the draft would end up pointing at a file that no longer
exists and `compile.rb` would report a missing scene.

Anything else — a note outside a draft, or an unlisted file sitting in the draft
folder — gets an ordinary rename with its wikilinks rewritten.

The decision is `scene.plan()`, a pure function with no IO, so all four cases are
covered by specs; only the LSP rename itself is left to obsidian.nvim. The
Obsidian-not-running guard applies when the scene list is being touched.

### Which draft gets compiled

First match wins:

1. **The nearest `Index.md` at or above the current file.** nvim runs the
   compiler from the buffer's directory, so `<F9>` builds *the book you're
   editing* — in a vault with five novels, the chapter under your cursor
   settles it, with nothing to remember.
2. **`<vault>/.compile-draft`** — set it with `compile.rb --select <Index.md>`.
   Useful for building one book while reading another.
3. **Longform's own selection**, read from its `data.json`. Choosing a draft in
   Obsidian's dropdown steers the CLI too. Read-only: nvim's choice goes in
   `.compile-draft` instead, since writing Longform's files while Obsidian is
   open can be silently clobbered.
4. **The only draft**, if the vault has exactly one.

If none of those apply it **lists the drafts and stops** rather than guessing:

```
compile.rb: 5 drafts here and nothing to choose between them.

Pick one by:
  cd-ing into the book's folder, or
  compile.rb <path to its Index.md>, or
  compile.rb --select <path to its Index.md>   (remembers it)
```

`--list` marks the current selection with `*`; `--steps` names the draft on its
first line. Both are cheap ways to confirm before building.

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

### Scene steps vs document steps

Steps run in one of three positions, and **position in the list is what decides
which** — everything before `concatenate` runs once per chapter, everything
after runs once over the assembled manuscript:

| Kind | Runs | Steps |
|---|---|---|
| `scene` | once per chapter | `strip_frontmatter` `remove_links` `crunch_comments` `prepend_title` |
| `join` | once, combining them | `concatenate` — **exactly one required** |
| `document` | once over the whole book | `msword_hrs` `markdown_hrs` |

Most steps work in either position; `prepend_title` is scene-only, since it
needs a chapter title.

**`compile.rb --steps` (`<Leader>ms`) prints the pipeline labelled by kind,
followed by every step available** — what each one does, and a `*` beside the
ones this draft uses. That's the quick way both to check an order before
running it and to see what else you could add. A bad order is caught
before any work happens:

```
compile.rb: `prepend_title` cannot run after the join -- it is a scene
            step. Move it before `concatenate`.
compile.rb: no join step: add `- concatenate: "\n\n---\n\n"` ...
```

The missing-join case used to be the dangerous one: it silently joined chapters
with a blank line instead of your separator, and produced a plausible-looking
manuscript.

Reorder steps by moving lines. Omit the block entirely and the Longform default
workflow is used. A vault can add its own steps in `<vault>/bin/compile_steps.rb`, so custom
behaviour is versioned with the book rather than duplicated here. They must be
module functions and take `(text, scene, opts)`:

```ruby
module_function

def squash_blanks(text, _scene, _opts)
  text.gsub(/\n{3,}/, "\n\n")
end
```

They appear in `--steps` under *from this vault*, and are exempt from the
ordering check — they can't declare a kind, so they're assumed to know where
they belong.

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
