# nvim-notes

Minimal and opinionated note taking and searching plugin for Neovim inspired by Dendron.

![demo gif](assets/demo.gif)

## Description

After swtiching from VSCode to Neovim, I wanted a similar note taking experience that I had with Dendron.
There are a ton of wonderful note taking plugins already built for Neovim, but none of them did exactly what I wanted.
So I built this simple three function plugin, that uses telescope.nvim and some Which-Key bindings to help me write and read my notes quickly while never leaving the terminal.

### Features

- [x] Quickly create a new daily note with metadata: `<leader> nn`
- [x] Search notes by name (using telescope): `<leader> nf`
- [x] Search for text in all notes with Live Grep (using telescope): `<leader> ns`
- [x] Do the above from any directory
- [x] Open the notes in a new buffer

## 📦 Installation

Any plugin manager will do, I use [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "joekleinsorge/nvim-notes",
    lazy = true,
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        -- Default notes_path is ~/git/notes/vault/
        -- notes_path = "change/the/path/to/your/notes/here"
    end
}
```

### Which-Key bindings

[Which-Key](https://github.com/folke/which-key.nvim)

#### NeoVim

```lua
vim.api.nvim_set_keymap('n', '<leader>n', ':lua require("neovim_note").new_note()<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>f', ':lua require("neovim_note").find_note()<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>s', ':lua require("neovim_note").search_notes()<cr>', { noremap = true, silent = true })
```

#### LunarVim

```lua
lvim.builtin.which_key.mappings["n"] = {
  name = "Notes",
  n = { "<cmd>lua require('nvim-notes').new_note()<cr>", "New Note" },
  f = { "<cmd>lua require('nvim-notes').find_note()<cr>", "Find Note" },
  s = { "<cmd>lua require('nvim-notes').search_notes()<cr>", "Search Notes" },
}
```

