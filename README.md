# nvim-notes

Minimal and opinionated note taking and searching plugin for Neovim inspired by Dendron.

## Features

- Create new notes with daily-name fallback and optional metadata
- Telescope-powered search across filenames and note contents
- Jump to the most recently modified Markdown note in your vault
- Customisable front matter so notes fit your workflow
- Vault-safe paths that reject traversal, absolute names, and symbolic-link escapes

## Requirements

- Neovim 0.9 or newer
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ripgrep](https://github.com/BurntSushi/ripgrep) for `:NotesSearch`

## Installation

Example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "joe/notes.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("notes").setup({
      notes_path = vim.fn.expand("~/git/notes/vault"),
    })
  end,
}
```

## Setup

Call `require("notes").setup()` from your config to override defaults:

Unknown options and invalid option types raise a descriptive error during setup so configuration mistakes are caught immediately.

- `notes_path` (string) path to your vault; defaults to `~/git/notes/vault`.
- `frontmatter` (function or list) customise the file header. Functions receive a context table with `name`, `path`, `id`, `created`, `metadata`, and `config`.
- `notify` (function) override how messages are reported (defaults to `vim.notify`).
- `note_extensions` (list) extensions considered by `last_note`; defaults to `{ "md", "markdown" }`. Use an empty list to allow every regular file.
- `ignore_hidden` (boolean) hide dotfiles and dot-directories from completion, Telescope, and `last_note`; defaults to `true`.
- `telescope` (table) tweak picker behaviour; accepts `find_files` and `live_grep` option tables merged into the built-in defaults.

Example with custom front matter:

```lua
require("notes").setup({
  notes_path = vim.fn.expand("~/notes"),
  note_extensions = { "md", "markdown", "mdx" },
  ignore_hidden = true,
  frontmatter = function(ctx)
    return {
      "---",
      ('id: "%s"'):format(ctx.id),
      ('title: "%s"'):format(ctx.name),
      ('created: "%s"'):format(ctx.created),
      "tags: []",
      "---",
      "",
    }
  end,
  telescope = {
    find_files = { layout_config = { preview_width = 0.65 } },
    live_grep = { path_display = { "smart" } },
  },
})
```

## Commands

- `:NotesNew [name]` create a new note (prompts when name is omitted and supports path completion). Submit an empty prompt for today's daily note or cancel to do nothing.
- `:NotesFind` open Telescope `find_files` scoped to the vault.
- `:NotesSearch` open Telescope `live_grep` scoped to the vault.
- `:NotesLast` open the most recently modified file matching `note_extensions`.

Run `:checkhealth notes` to verify your Neovim version, vault path, Telescope installation, and ripgrep installation.

You can also call the Lua API directly:

```lua
require("notes").new_note({
  name = "projects/notes.nvim.md",
  metadata = { tags = { "neovim", "plugin" } },
})
```

## Keymaps

```lua
local notes = require("notes")

vim.keymap.set("n", "<leader>nn", notes.new_note, { desc = "Notes: new note" })
vim.keymap.set("n", "<leader>nf", notes.find_note, { desc = "Notes: find note" })
vim.keymap.set("n", "<leader>ns", notes.search_notes, { desc = "Notes: search notes" })
vim.keymap.set("n", "<leader>nl", notes.last_note, { desc = "Notes: last note" })
```

## Safety

Note names are always relative to `notes_path`. Absolute paths, `.` and `..` path segments, control characters, and paths through symbolic links are rejected before any directory or file is created. Existing symbolic links inside the vault are also excluded from completion and recent-note scanning.

Filesystem, custom front matter, Telescope, and editor errors are reported through the configured `notify` function instead of raising an unhandled error.

## Development

The test suite has no Lua test-framework dependency. It runs inside headless Neovim:

```sh
make check
```

`make check` runs both the test and lint targets. Formatting and lint checks require [StyLua](https://github.com/JohnnyMorganz/StyLua) and [Luacheck](https://github.com/lunarmodules/luacheck). You can also run either target independently:

```sh
make test
make lint
```

CI runs the suite on Neovim 0.9.5, stable, and nightly, and checks formatting.

Native help is available through `:help notes.nvim`.

## License

[MIT](LICENSE) © 2026 Joe Kleinsorge
