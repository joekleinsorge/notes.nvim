local M = {}

-- Define default configuration
local default_config = {
  notes_path = nil, -- Custom notes path, nil for default (based on HOME)
}

-- Merge the user-provided configuration with the default configuration
local function merge_config(user_config)
  local config = vim.tbl_deep_extend("force", default_config, user_config or {})
  return config
end

-- Helper function to calculate the notes_path
local function get_notes_path(config)
  local home = os.getenv("HOME")
  return config.notes_path or (home .. "/git/notes/vault")
end

M.new_note = function(config)
  config = merge_config(config)

  local name = vim.fn.input("Note Name (press Enter to use default format): ")
  if name == "" then
    name = os.date("daily.%Y-%m-%d.md")
  end

  local notes_path = get_notes_path(config)
  local full_path = notes_path .. "/" .. name

  -- Check if the file already exists
  if vim.fn.filereadable(full_path) == 1 then
    vim.cmd("e " .. full_path)
    return
  end

  local template = string.format([[
---
id: "%s"
aliases:
tags: []
---
]], name)

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

M.find_note = function(config)
  config = merge_config(config)

  local telescope = require("telescope.builtin")
  local notes_path = get_notes_path(config)

  telescope.find_files({
    prompt_title = "Find Note",
    cwd = notes_path,
  })
end

M.search_notes = function(config)
  config = merge_config(config)

  local telescope = require("telescope.builtin")
  local notes_path = get_notes_path(config)

  telescope.live_grep({
    prompt_title = "Search Notes",
    cwd = notes_path,
  })
end

return M
