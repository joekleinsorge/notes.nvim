# nvim-notes

Minimal and opinionated note taking and searching plugin for Neovim inspired by Dendron.


## Features

- [x] Quickly create new notes and search old ones in place
- [x] Search notes by name (using telescope)
- [x] Search for text in all your notes with Live Grep (using telescope)
- [x] Create new daily notes with metadata

## Requirements

This plugin is entirely dependent on [telescope](https://github.com/nvim-telescope/telescope.nvim), follow their installation instructions [here](https://github.com/nvim-telescope/telescope.nvim#installation).

## Which-Key bindings

[Which-Key](https://github.com/folke/which-key.nvim)

### NeoVim

```lua
vim.api.nvim_set_keymap('n', '<leader>n', ':lua require("neovim_note").new_note()<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>f', ':lua require("neovim_note").find_note()<cr>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>s', ':lua require("neovim_note").search_notes()<cr>', { noremap = true, silent = true })
```
### LunarVim

```lua
lvim.builtin.which_key.mappings["n"] = {
  name = "Notes",
  n = { "<cmd>lua require('nvim-notes').new_note()<cr>", "New Note" },
  f = { "<cmd>lua require('nvim-notes').find_note()<cr>", "Find Note" },
  s = { "<cmd>lua require('nvim-notes').search_notes()<cr>", "Search Notes" },
}
```


