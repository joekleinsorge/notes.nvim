-- Import required modules
local wk = require("which-key")
local telescope = require("telescope")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local trouble = require("trouble.providers.telescope")

-- Create a module to hold all the functions and configurations
local M = {}

-- Configuration (allow customization through Neovim's configuration)
M.notes_directory = vim.g.notes_directory or "~/git/notes/vault"
M.leader_key = vim.g.notes_leader_key or "<leader>"
M.default_file_extension = ".md" -- Default file extension for notes
M.default_metadata = {
  -- Default metadata fields
  id = true,
  created = true,
  updated = true,
  title = true,
  tags = true,
}

-- Utility function to change directory and run a function, then restore directory
local function run_in_directory(directory, func)
  local current_working_dir = vim.fn.getcwd()
  vim.fn.chdir(directory)
  func()
  vim.fn.chdir(current_working_dir)
end

-- Function to create a new note
function M.create_new_note()
  local note_name = vim.fn.input('Enter note name (or press Enter for default): ')
  if note_name == "" then
    note_name = os.date("daily.%d-%m-%y")
  end

  local note_path = M.notes_directory .. "/" .. note_name .. M.default_file_extension
  local metadata = "---\n"
  for field, _ in pairs(M.default_metadata) do
    if field == "id" then
      metadata = metadata .. field .. ": " .. vim.fn.strftime('%s') .. "\n"
    elseif field == "created" or field == "updated" then
      metadata = metadata .. field .. ": " .. os.date('%Y-%m-%d %H:%M:%S') .. "\n"
    else
      metadata = metadata .. field .. ": " .. note_name .. "\n"
    end
  end
  metadata = metadata .. "---\n"

  vim.fn.writefile({ metadata }, note_path, 'w')
  vim.cmd("silent! e " .. note_path)
  vim.api.nvim_out_write("Created new note: " .. note_name .. "\n")
end

-- Function to save and open a note
function M.save_and_open_note(note_name)
  local note_path = M.notes_directory .. "/" .. note_name .. M.default_file_extension

  run_in_directory(M.notes_directory, function()
    if vim.fn.filereadable(note_path) == 1 then
      vim.cmd("silent! e " .. note_path)
      vim.api.nvim_out_write("Opened note: " .. note_name .. "\n")
    else
      vim.api.nvim_out_write("Note not found: " .. note_name .. "\n")
    end
  end)
end

-- Function to search notes by name using Telescope
function M.search_note_by_name()
  require('telescope.builtin').find_files({
    prompt_title = 'Search Notes by Name',
    cwd = M.notes_directory,
  })
end

-- Function to search text in notes using Telescope
function M.search_text_in_note()
  local search_term = vim.fn.input("Search for: ")
  if search_term ~= "" then
    require('telescope.builtin').live_grep({
      prompt_title = 'Search Text in Notes',
      cwd = M.notes_directory,
      search = search_term,
    })
  else
    print("Search term cannot be empty.")
  end
end

-- Function to open notes using Trouble
function M.open_note_with_trouble()
  require("telescope.builtin").grep_string({
    prompt_title = 'Open Note with Trouble',
    search = "", -- Empty search to show all notes
    search_dirs = { M.notes_directory },
    attach_mappings = function(_, prompt_bufnr)
      actions.select_default:replace(function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        if selection and selection.value then
          run_in_directory(M.notes_directory, function()
            vim.fn["trouble.open"](selection.value)
            vim.api.nvim_out_write("Opened note with trouble: " .. selection.value .. "\n")
          end)
          actions.close(prompt_bufnr)
        end
      end)
      return true
    end,
  })
end

-- Set up which-key mappings
wk.register({
  [M.leader_key] = {
    name = "Notes Plugin",
    c = { "<cmd>lua require'notes.notes_plugin'.create_new_note()<CR>", "Create New Note" },
    o = { "<cmd>lua require'notes.notes_plugin'.save_and_open_note(vim.fn.input('Enter note name: '))<CR>",
      "Open Note by Name" },
    s = {
      n = { "<cmd>lua require'notes.notes_plugin'.search_note_by_name()<CR>", "Search Notes by Name" },
      t = { "<cmd>lua require'notes.notes_plugin'.search_text_in_note()<CR>", "Search Text in Notes" },
    },
    p = { "<cmd>lua require'notes.notes_plugin'.open_note_with_trouble()<CR>", "Open Note with Trouble" },
  },
}, { prefix = M.leader_key })

-- Provide user feedback
local function notify(message)
  vim.api.nvim_echo({ { "Notes Plugin: " .. message, "Type" } }, true, {})
end

-- Initialize the plugin
function M.setup(config)
  if config then
    M.notes_directory = config.notes_directory or M.notes_directory
    M.leader_key = config.leader_key or M.leader_key
    M.default_metadata = config.default_metadata or M.default_metadata
    M.default_file_extension = config.default_file_extension or M.default_file_extension
  end
  notify("Initialized")
end

-- Return the module for use
return M
