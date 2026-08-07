# House style reference

Derived from the existing config. Where the config is inconsistent, this file
says which form dominates and is therefore the target — that is noted explicitly
rather than glossed over, so you can tell a rule from an aspiration.

## Contents

- [File header comments](#file-header-comments)
- [Comment banners](#comment-banners)
- [Indentation and formatting](#indentation-and-formatting)
- [Plugin file anatomy](#plugin-file-anatomy)
- [Keymaps](#keymaps)
- [which-key groups](#which-key-groups)
- [pack.lua name to file name mapping](#packlua-name-to-file-name-mapping)
- [LSP servers](#lsp-servers)
- [Filetype settings](#filetype-settings)
- [Known deliberate exceptions](#known-deliberate-exceptions)

## File header comments

Every file in `lua/plugins/` opens with exactly two comment lines: what the
plugin is, then where it came from. The em dash is the separator, not a hyphen.

```lua
-- gitsigns.nvim — git signs and hunk actions
-- https://github.com/lewis6991/gitsigns.nvim
```

The name used is the plugin's real name (`blink.cmp`, `nvim-treesitter`,
`neo-tree.nvim`), which is not always the file name. The description is a short
noun phrase, lowercase, no trailing period.

Variants that are correct in context:

- Branch-pinned plugins note it: `-- https://github.com/ThePrimeagen/harpoon (branch: harpoon2)`
- A file configuring several related plugins lists each URL on its own line
  (`vim-dadbod.lua` covers dadbod, dadbod-ui, and dadbod-completion)
- Locally implemented "plugins" point at the implementation instead of a URL:
  `-- Implementation: lua/custom/scratch.lua`
- A `---@diagnostic` directive has to be line 1, so the header starts on line 2
  (`venv-selector.lua`)

Anything longer than the two lines goes below them, still as comments, explaining
non-obvious decisions — `lookml.lua` and `vim-dadbod.lua` are good models. Prose
explaining *why* is welcome; prose restating what the code plainly does is not.

## Comment banners

Two widths, used for different scopes. Both are 79 characters wide.

File-level, used in `pack.lua`, `init.lua`, and `lua/config/*.lua`:

```lua
-- =============================================================================
-- config/keymaps.lua
-- =============================================================================
-- Global keymaps not tied to a specific plugin.
-- =============================================================================
```

Section-level, dividing groups within a file:

```lua
-- -----------------------------------------------------------------------------
-- Windows
-- -----------------------------------------------------------------------------
```

Inside the `vim.pack.add({...})` table the section banners are indented one tab
to match the entries they head.

## Indentation and formatting

Tabs, width 4 — this is stylua's default, and `conform.nvim` runs stylua on Lua
with no `stylua.toml` to override it. Formatting is on `<leader>f` and via
conform's `default_format_opts`.

The config is not currently uniform — as of the last audit, 18 of 54 Lua files
are not stylua-clean, a legacy of files written before conform was wired up.

Do not enumerate which files those are from memory; ask stylua, since it is the
tool that actually decides and its answer changes as files get touched:

```bash
stylua --check <file>      # or let scripts/audit.py sweep the whole config
```

Counting tab- versus space-prefixed lines is a poor substitute. It misjudges any
file containing `[[ ]]` long strings — `dashboard.lua`'s ASCII-art blocks make it
look badly mixed when only the closing `]]` delimiters are involved.

New code uses tabs. In an existing space-indented file, either run stylua over
the whole file as its own change or match the file's local style — introducing
tabs into a spaces file makes it strictly worse. Reformatting produces a large
diff, so offer it as a separate change rather than burying it inside a behaviour
change. Note that format-on-save means touching an unclean file reformats it
wholesale anyway, which is why doing it deliberately keeps diffs readable.

Other formatting habits: double-quoted strings, trailing commas in multi-line
tables, and a blank line between logical groups inside a `setup()` call.

## Plugin file anatomy

The order within a plugin file is consistent: header, then any local helper
values, then `setup()`, then keymaps, then any autocommands.

Simple case:

```lua
-- marks.nvim — visible marks in the sign column with motions
-- https://github.com/chentoast/marks.nvim
require("marks").setup({
	default_mappings = true,
})
```

With keymaps, aliasing `vim.keymap.set` once a file has three or more:

```lua
-- <plugin> — <purpose>
-- https://github.com/<owner>/<repo>

local set = vim.keymap.set

require("<module>").setup({
	-- options
})

set("n", "<leader>xa", function() ... end, { desc = "Thing: action" })
set("n", "<leader>xb", "<cmd>Command<cr>", { desc = "Thing: other action" })
```

Some plugins expose a module whose name differs from the file name — check the
plugin's `lua/` directory rather than assuming `require("<file name>")`.

Plugin files should not `require` each other. Cross-plugin coordination goes
through `init.lua` load order, or through an autocommand that waits for the
other plugin to exist.

## Keymaps

**Every keymap has a `desc`.** No exceptions — which-key renders them and an
absent `desc` shows as a raw command.

**Where they live** follows ownership, and ownership beats scoping:

- A keymap that drives a plugin goes in that plugin's file — *even if it should
  only exist for one filetype*. Scope it there with a `FileType` autocmd and
  `buffer = ev.buf`, as `lookml.lua` does for `<leader>ss`/`gd`/`K`. The point is
  that removing the plugin should remove its keymaps in the same edit.
- LSP keymaps go in the `LspAttach` handler in `config/lsp.lua`.
- `after/ftplugin/<ft>.lua` gets a keymap only when *overriding* one that already
  exists, for a single filetype. Otherwise those files hold options
  (`vim.opt_local`) — indent, wrap, folding.
- Everything else goes in `config/keymaps.lua`.
- Keymaps for a deferred plugin go inside its `packadd` callback, since they
  would otherwise fire before the plugin exists.

**Buffer-local keymaps pass `buffer = bufnr`** rather than relying on the
current buffer, which is what `gitsigns.lua`'s `on_attach` does.

**`desc` wording** has one firm convention and one loose one:

- `<leader>t*` toggles use `"Toggle: <thing>"` — `"Toggle: listchars"`,
  `"Toggle: Markview"`, `"Toggle: Mason"`, `"Toggle: Neotree"`,
  `"Toggle: Harpoon menu"`, `"Toggle: scroll-lock"`, `"Toggle: diagnostics"`.
  Two stragglers predate the convention and use Title Case instead:
  `<leader>tt` `"Toggle Terminal"` and `<leader>tb` `"Toggle Line Blame"`. New
  toggles use the colon form.
- Everything else is Title Case describing the action: `"Split Right"`,
  `"Close Buffer"`, `"Next Hunk"`, `"Stage Hunk"`, `"Open Git Remote in
  Browser"`. Plugin-namespaced actions may prefix with the plugin
  (`"Harpoon: add file"`) where that disambiguates.

A `<leader>t*` mapping that is not actually a toggle should not claim to be —
`<leader>tD` is `"Open Dashboard"`, which is correct.

## which-key groups

Prefixes are registered in `plugins/which-key.lua` so the popup shows a label
instead of a bare key:

```lua
require("which-key").add({
	{ "<leader>b", group = "Buffers" },
	{ "<leader>d", group = "Debug" },
	...
})
```

Registered centrally in `which-key.lua`: `<leader>b` Buffers, `<leader>d`
Debug, `<leader>D` Database, `<leader>h` Harpoon, `<leader>s` Search,
`<leader>t` Toggle, `<leader>w` Windows, and `g` Go to.

**Deferred plugins register their own group inside the packadd callback**, which
is the correct pattern — registering centrally would label a prefix whose
mappings do not exist yet. Three do this: `uv.lua` adds `<leader>u` "uv",
`obsidian.lua` adds `<leader>n` "Notes", and `claude-code.lua` adds `<leader>c`
"Claude". So when checking group coverage, search the whole config rather than
just `which-key.lua`, or you will report groups as missing when they are not.

Adding a mapping under a new prefix means registering its group in the same
change — centrally if the plugin loads eagerly, in the callback if it defers.

## pack.lua name to file name mapping

The file in `lua/plugins/` is usually the repo name with `.nvim` / `.vim`
stripped and a leading `nvim-` dropped — `markview.nvim` → `markview.lua`,
`nvim-treesitter` → `treesitter.lua`, `blink.cmp` → `blink-cmp.lua`.

Two names do not follow that rule:

| `pack.lua` entry | Config file |
| --- | --- |
| `neo-tree.nvim` | `neotree.lua` |
| `lkml.vim` | `lookml.lua` |

Not every `pack.lua` entry gets its own file. Shared dependencies have none
(`plenary.nvim`, `nvim-web-devicons`, `nui.nvim`, `nvim-nio`,
`friendly-snippets`, `nvim-notify`), some are configured as a group by one file
(the three `vim-dadbod*` plugins in `vim-dadbod.lua`; the DAP family in
`dap.lua`), and `nvim-lspconfig` is driven from `config/lsp.lua` plus `lsp/`.

`scripts/audit.py` holds this mapping in its `ALIASES`, `NO_CONFIG_FILE`, and
`CONFIGURED_BY` tables. When a plugin is added that needs an entry there, update
the script in the same change so future audits stay clean.

## LSP servers

Servers get one file each in `lsp/<server>.lua`, returning a settings table
consumed by `vim.lsp.config`. Global LSP behaviour — the `vim.lsp.config("*")`
defaults, capabilities from blink, and the `LspAttach` keymaps — lives in
`config/lsp.lua`. Adding a server means a file in `lsp/`, enabling it in
`config/lsp.lua`, and usually adding it to `plugins/mason.lua` so it installs.

## Filetype settings

Buffer-local options go in `after/ftplugin/<ft>.lua` using `vim.opt_local`, not
in a global `FileType` autocommand and not in `options.lua`. Existing files
cover lua, python, markdown, yaml, json, sql, and make.

## Known deliberate exceptions

Do not "fix" these — they are intentional, and flagging them repeatedly is
noise:

- `pack.lua` and `init.lua` are ordered by dependency, not alphabetically
- `lookml.lua` is named for the filetype it serves, not its plugin
- `scratch.lua` and `terminal.lua` are local implementations in `lua/custom/`,
  with no upstream repo and so no `pack.lua` entry
- `venv-selector.lua` opens with `---@diagnostic disable: missing-fields`
- `markview.nvim` is `load = false` and deferred to the markdown `FileType`
  despite being a UI plugin
- `vim-helm.lua` deletes its own augroup after `packadd` instead of using
  `once = true`. That is correct here, not sloppy: the callback has to keep
  firing until a path/`Chart.yaml` condition matches, so `once` would give up
  after the first buffer. Treat augroup deletion, `once = true`, and a callback
  returning `true` as equivalent one-shot mechanisms.
- `lookml.lua`'s two other `FileType` autocmds have no `once = true` on purpose —
  they register buffer-local keymaps and must run for every matching buffer.
  Only the autocmd doing the `packadd` needs to be one-shot.

Genuine violations worth reporting, by contrast: `dashboard.lua` has no header
comment at all, `flash.lua`'s header has no description, and `noice.lua` uses a
hyphen where the convention is an em dash.
