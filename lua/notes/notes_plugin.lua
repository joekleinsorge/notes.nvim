-- Import required modules
local telescope = require("telescope")
local actions = require("telescope.actions")
local trouble = require("trouble.providers.telescope")

-- Create a module to hold all the functions and configurations
local M = {}

-- Configuration (allow customization through Neovim's configuration)
M.notes_directory = vim.g.notes_directory or "~/git/notes/vault"
M.default_file_extension = ".md" -- Default file extension for notes

-- Utility function to change directory and run a function, then restore directory
local function run_in_directory(directory, func)
  local current_working_dir = vim.fn.getcwd()
  vim.fn.chdir(directory)
  func()
  vim.fn.chdir(current_working_dir)
end

-- Function to open notes using Trouble
function M.open_note_with_trouble(note_name)
  local note_path = M.notes_directory .. "/" .. note_name .. M.default_file_extension

  run_in_directory(M.notes_directory, function()
    if vim.fn.filereadable(note_path) == 1 then
      vim.fn["trouble.open"](note_path)
      vim.api.nvim_out_write("Opened note with trouble: " .. note_name .. "\n")
    else
      vim.api.nvim_out_write("Note not found: " .. note_name .. "\n")
    end
  end)
end

-- Set up Telescope for searching existing notes
function M.search_existing_notes(note_name)
  local note_files = vim.fn.globpath(M.notes_directory, note_name .. M.default_file_extension, false, true)

  telescope.extensions.fzf_writer.staged_grep({
    prompt_title = "Search Existing Notes",
    cwd = M.notes_directory,
    git_dir = M.notes_directory,
    files = note_files,
    file_icons = true,
    color_devicons = true,
    git_icons = {
      changed = "M",
      staged = "S",
      untracked = "U",
    },
    git_hl = true,
  })
end

-- Function to create a new note
function M.create_new_note()
  local note_name = vim.fn.input('Enter note name (or press Enter for default): ')
  if note_name == "" then
    note_name = os.date("daily.%d-%m-%y")
  end

  local note_path = M.notes_directory .. "/" .. note_name .. M.default_file_extension
  local metadata = "---\n"
  metadata = metadata .. "title: " .. note_name .. "\n"
  metadata = metadata .. "---\n"

  vim.fn.writefile({ metadata }, note_path, 'w')
  vim.cmd("silent! e " .. note_path)
  vim.api.nvim_out_write("Created new note: " .. note_name .. "\n")

  M.search_existing_notes(note_name) -- Search for existing notes with the same name
end

-- Initialize the plugin
function M.setup(config)
  if config then
    M.notes_directory = config.notes_directory or M.notes_directory
    M.default_file_extension = config.default_file_extension or M.default_file_extension
  end
end

-- Return the module for use
return M

