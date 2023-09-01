local M = {}

M.new_note = function()
  local name = vim.fn.input("Note Name (press Enter to use default format): ")
  if name == "" then
    name = os.date("daily.%Y-%m-%d.md")
  end

  local home = os.getenv("HOME")
  local notes_path = home .. "/git/notes/vault"
  local full_path = notes_path .. "/" .. name

  local template = [[
---
id: "tools.notes"
aliases:
  - "Notes"
tags: [neovim, notes]
---

# New Note

-- Insert your content here --
]]

  -- Create the notes directory if it doesn't exist
  vim.fn.mkdir(notes_path, "p")

  local success = pcall(function()
    vim.fn.writefile(vim.split(template, "\n"), full_path)
    vim.cmd("e " .. full_path)
  end)

  if not success then
    vim.api.nvim_err_writeln("Error creating note.")
  end
end

M.find_note = function()
  local telescope = require("telescope.builtin")
  local notes_path = "~/git/notes/vault"

  telescope.find_files({
    prompt_title = "Find Note",
    cwd = notes_path,
  })
end


M.search_notes = function()
  local telescope = require("telescope.builtin")
  local notes_path = "~/git/notes/vault"

  telescope.live_grep({
    prompt_title = "Search Notes",
    cwd = notes_path,
  })
end

return M
