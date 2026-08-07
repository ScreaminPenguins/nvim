---
name: nvim-plugin-config
description: >-
  Audit this Neovim config's plugin files for consistency, and make changes to
  them that match the existing house style. Use this skill whenever the user
  asks to review, audit, sanity-check, or clean up their Neovim config; whenever
  they want to add, remove, replace, or reconfigure a plugin; whenever they want
  to change a keymap, a toggle, a filetype behaviour, an LSP server, or a
  formatter; and whenever they describe a desired editor interaction ("I want
  <leader>x to do Y", "make markdown files wrap", "why doesn't my picker show
  hidden files"). Use it even if the request sounds like a one-line edit — this
  config registers each plugin in three separate places and uses vim.pack rather
  than lazy.nvim, so edits that look local usually are not. Triggers on mentions
  of nvim, neovim, init.lua, pack.lua, vim.pack, packadd, plugin specs, keymaps,
  which-key, ftplugin, conform, blink, treesitter, or any file under
  lua/plugins/, lua/config/, lsp/, or after/ftplugin/.
---

# Neovim plugin config: audit and edit

This config is a hand-rolled `vim.pack` setup with a deliberate three-file
registration pattern. Its consistency is load-bearing rather than cosmetic: load
order encodes real dependency constraints, and a plugin registered in two of
three places silently does nothing. Your job is to protect those invariants
while making the change the user actually asked for.

## Read this before editing anything

**This config does not use lazy.nvim, packer, or vim-plug.** It uses Neovim's
built-in `vim.pack`. This matters more than anything else in this skill, because
the reflex to write a lazy.nvim spec is strong and the result is silently dead
code — a `return { "owner/repo", opts = {...} }` table at the top of a file in
`lua/plugins/` is never read by anything here. There is no plugin manager
scanning that directory. `lua/plugins/*.lua` files are plain modules that run
their configuration as a side effect when `init.lua` requires them.

If you catch yourself writing `opts =`, `event =`, `cmd =`, `ft =`, `keys =`,
`dependencies =`, or `config = function()` inside a `lua/plugins/` file, stop —
that is lazy.nvim vocabulary and none of it applies.

## The registration triangle

Adding one plugin means touching three files. Miss one and the failure is quiet:

1. **`lua/pack.lua`** — the `vim.pack.add({...})` list. Full GitHub URL, placed
   inside the correct category banner. Three entry forms:
   - `"https://github.com/owner/repo"` — eager, most plugins
   - `{ src = "...", version = "v3.x" }` — pinned to a branch or tag
   - `{ src = "...", load = false }` — cloned but not sourced; the plugin's own
     file is then responsible for `packadd` (see *Deferred loading* below)
2. **`lua/plugins/<name>.lua`** — the configuration module. Runs `setup()` and
   registers that plugin's keymaps.
3. **`init.lua`** — a `require("plugins.<name>")` line under the category
   heading that matches its `pack.lua` group.

Ordering is not arbitrary in either list. `pack.lua` puts shared dependencies
first and depended-upon plugins before their dependents. `init.lua` loads the
colorscheme first to avoid an unstyled flash, and the whole LSP stack (blink →
mason → conform → lazydev → dap) before `config.lsp`, because `config/lsp.lua`
calls `blink.cmp.get_lsp_capabilities()` and will error if blink has not been
set up. When you add to either file, put the entry where its category says it
goes rather than at the end.

## The audit script

```bash
python3 .claude/skills/nvim-plugin-config/scripts/audit.py     # --json for machine-readable
```

Run it from the config root. It checks the registration triangle, the
`load = false` → `packadd` contract, `<leader>` keymap collisions, header
comments, stylua cleanliness, missing keymap `desc`s, which-key group coverage,
and the `<leader>t` toggle naming convention.

**Run it when it will tell you something you don't already know:**

- the user asked for a review — always
- you added, removed, or renamed a plugin — run it after, to confirm the triangle
  and the `packadd` contract still hold
- you added a keymap — run it after, since the collision check is the one thing
  here you cannot eyeball (a shadowed mapping is invisible until you press the key)

**Skip it** for a change that cannot affect any of the above: editing a
`setup()` option, adjusting an existing `desc`, adding a comment, changing an
`after/ftplugin/` option. A full sweep on either side of a one-line edit is
wasted work, and re-running it to confirm a number you already know is worse.

Trust its output. The checks are mechanical and the known-deliberate exceptions
are already filtered out, so re-deriving a finding by hand is only worth it when
the finding surprises you or the fix is risky. Do not re-implement a check the
script already performs.

It is a first pass, not the whole review — it cannot judge whether a plugin's
options are sensible, whether two plugins overlap, or whether a keymap is
ergonomic. That part is yours.

## Two modes

### Auditing

Run the script, read the files it flags plus anything recently changed
(`git diff`, `git log --name-only`), and report inline. Every finding carries a
`file:line` so the user can jump to it.

```
## Broken
A plugin silently does not load, a mapping is unreachable, startup errors.

## Drift
Real inconsistency with the house style. Mechanical, low-risk to fix.

## Worth considering
Judgement calls — overlapping plugins, stale options, ergonomics. State the
tradeoff in a sentence and let the user decide.
```

**Lead with a one-line verdict** — how many broken things, and whether the
config is broadly healthy. That is the sentence the user actually needs.

**Budget the report.** Aim for the ten or so findings that would change what the
user does, ordered by what they cost to leave alone. An audit that lists every
cosmetic nit buries the two things that matter, and a reader who skims past a
real bug because it sat at position 40 was not well served. When you cut, say so
in a line ("plus ~15 minor formatting nits — ask if you want them") rather than
implying the list is exhaustive.

Group repeated findings into one entry with a count. Eighteen files failing
`stylua --check` is one finding with a root cause (no `stylua.toml`), not
eighteen findings.

Skip a "what's good" section unless the user asked how the config is doing
overall. Praise costs tokens and rarely changes a decision; the exception is
when a convention is worth preserving and the user might not realise it, which
is worth one line at the end.

**Do not edit during an audit** unless the user says to. This config reflects
strong accumulated opinions, and a silent "helpful" fix to something deliberate
is worse than the drift. Close by asking which items to apply.

### Changing behaviour

When the user describes an interaction they want, work out which layer owns it
before writing anything. Putting a change in the wrong layer is the most common
way this config gets messy, because the change works and so nobody notices:

| The user wants | It belongs in |
| --- | --- |
| A plugin's own behaviour, or **any** keymap that drives that plugin | `lua/plugins/<name>.lua` |
| A keymap not tied to any plugin | `lua/config/keymaps.lua` |
| An LSP keymap or global LSP behaviour | `lua/config/lsp.lua` |
| One language server's settings | `lsp/<server>.lua` |
| A filetype's options — indent, wrap, folding | `after/ftplugin/<ft>.lua` |
| Overriding an existing keymap for one filetype | `after/ftplugin/<ft>.lua` |
| A global editor option | `lua/config/options.lua` |
| An autocommand not tied to a plugin | `lua/config/autocmds.lua` |
| Non-trivial custom logic | `lua/custom/<name>.lua`, called from the layer above |

**Plugin ownership beats filetype scoping.** A keymap that invokes a plugin lives
in that plugin's file even when it should only exist for one filetype — scope it
there with a `FileType` autocmd and `buffer = ev.buf`, the way `lookml.lua` does.
Do not route it to `after/ftplugin/` just because it is filetype-scoped. The
reason is deletion: everything a plugin owns should disappear in one edit when the
plugin does, and a dadbod mapping stranded in `after/ftplugin/sql.lua` outlives
dadbod and starts erroring.

`after/ftplugin/` earns a keymap only in the other direction — when you are
*overriding* a mapping that already exists, for one filetype. Otherwise it holds
options, set with `vim.opt_local`.

Prefer the narrowest layer that works. A `vim.opt` change in `options.lua` to fix
one filetype's indentation is a global side effect; `after/ftplugin/` is where
that belongs.

## Guardrails

**A `lua/plugins/*.lua` file with no `pack.lua` entry is unfinished work, not
dead code.** This is the single most important thing to get right, because the
intuitive read is exactly backwards. The user's workflow is to write the config
file first and register it in `pack.lua` once they are happy with it, so an
unregistered file means "in progress" — review it and offer to add the missing
`pack.lua` entry and `init.lua` require. Never propose deleting one as cleanup.

**Never edit `nvim-pack-lock.json` by hand.** It is generated. Plugins update
via `:lua vim.pack.update()` and roll back via
`:lua vim.pack.update(nil, { target = 'lockfile' })`.

**Do not reorder `pack.lua` or `init.lua` to tidy them.** The comments saying
order is intentional are accurate. Reordering to satisfy alphabetisation or
aesthetics can break startup in ways that only show up on a cold install.

**Treesitter parsers are manual.** After a plugin update, parsers need
`:TSUpdate`. If a change involves a new language, check whether
`plugins/treesitter.lua` needs the parser adding.

**Verify plugin APIs rather than recalling them.** Neovim plugin APIs churn hard
and a plausible-looking option that no longer exists fails silently or throws at
startup. When adding a plugin or reaching for an option you are not certain
about, check the real thing: read the source under
`~/.local/share/nvim/site/pack/core/opt/<plugin>/`, or use the `context7` MCP
server to pull current docs. Say so if you could not verify something.

**Check the change actually loads.** Config edits are cheap to verify:

```bash
nvim --headless "+checkhealth" +qa 2>&1 | tail -30   # or
nvim --headless "+lua require('plugins.<name>')" +qa
```

A clean exit means it parsed and ran. Report the real result — a config that
errors on startup is a bad afternoon, so do not claim it works without having
run something.

## Deferred loading

`load = false` in `pack.lua` means the plugin is cloned but not sourced, so its
own file must both `packadd` it and configure it, behind a trigger. The
established shape:

```lua
-- <plugin> — <one-line purpose>
-- https://github.com/<owner>/<repo>

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("<plugin>-load", { clear = true }),
	pattern = "<filetype>",
	once = true,
	callback = function()
		vim.cmd.packadd("<repo-name>")
		require("<module>").setup({})
		vim.keymap.set("n", "<leader>xx", "<cmd>Whatever<cr>", { desc = "..." })
	end,
})
```

Three things bite here. `packadd` takes the **on-disk directory name**, which is
the repo name including any `.nvim` suffix (`markview.nvim`, not `markview`) —
not the Lua module name. `once = true` matters because without it the callback
re-runs on every matching buffer and re-registers everything. And keymaps have
to go **inside** the callback: registered outside, they would fire before the
plugin exists.

Defer a plugin when it is only useful for one filetype or one workflow. Load
eagerly when it affects startup appearance, or when something else needs it at
require time.

## House style

The full detail — header comment format, indentation, keymap `desc`
conventions, which-key registration, comment banners, and the `pack.lua` name to
file name mapping — is in `references/conventions.md`. Read it before writing a
new plugin file or when the audit flags a style finding you need to fix
correctly.

Two things worth knowing up front, because they are the most frequently
violated:

**Indentation is tabs.** `conform.nvim` formats Lua with `stylua`, and there is
no `stylua.toml`, so stylua's default applies: tabs, width 4. Much of the config
predates consistent formatting and is space-indented, some files mixing both.
Match tabs in new code. When touching a space-indented file, either reformat the
whole file or match its local style — do not add tabs to a spaces file, since
mixing is worse than either.

**Every keymap needs a `desc`.** which-key surfaces them, so a missing `desc`
degrades a UI the user actually relies on. If a keymap introduces a new
`<leader><letter>` prefix, register a group for it in the same change — centrally
in `plugins/which-key.lua` for eager plugins, or inside the `packadd` callback
for deferred ones, which is what `uv.lua`, `obsidian.lua`, and `claude-code.lua`
do.
