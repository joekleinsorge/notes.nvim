-- Import required modules
local wk = require("which-key")
local telescope = require("telescope")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local trouble = require("trouble.providers.telescope")

-- Create a module to hold all the functions and configurations
local M = {}

-- Configuration
M.notes_directory = "~/git/notes/vault"
M.leader_key = "<leader>"

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

  local note_path = M.notes_directory .. "/" .. note_name .. ".md"
  vim.cmd("silent! e " .. note_path)   -- Use "silent!" to suppress error messages
  vim.api.nvim_out_write("Created new note: " .. note_name .. "\n")
end

-- Function to save and open a note
function M.save_and_open_note(note_name)
  local note_path = M.notes_directory .. "/" .. note_name .. ".md"

  run_in_directory(M.notes_directory, function()
    vim.cmd("silent! e " .. note_path)     -- Use "silent!" to suppress error messages
    vim.api.nvim_out_write("Opened note: " .. note_name .. "\n")
  end)
end

-- Function to search notes by name
function M.search_note_by_name()
  local note_files = vim.fn.globpath(M.notes_directory, "*.md", false, true)

  pickers.new({}, {
    prompt_title = 'Search Notes by Name',
    finder = finders.new_table {
      results = note_files,
      entry_maker = function(entry)
        return {
          display = entry,
          filename = entry,
        }
      end,
    },
    sorter = require('telescope.sorters').get_generic_fuzzy_sorter(),
    attach_mappings = function(_, prompt_bufnr)
      actions.select_default:replace(function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        if selection and selection.filename then
          run_in_directory(M.notes_directory, function()
            vim.cmd("silent! e " .. selection.filename)             -- Use "silent!" to suppress error messages
            vim.api.nvim_out_write("Opened note: " .. selection.filename .. "\n")
          end)
          actions.close(prompt_bufnr)
        end
      end)
      return true
    end,
  }):find()
end

-- Function to search text in notes
function M.search_text_in_note()
  local search_term = vim.fn.input("Search for: ")
  if search_term ~= "" then
    require('telescope.builtin').grep_string({
      prompt_title = 'Search Text in Notes',
      search = search_term,
      search_dirs = { M.notes_directory },
    })
  else
    print("Search term cannot be empty.")
  end
end

-- Function to open notes using trouble.nvim
function M.open_note_with_trouble()
  require("telescope.builtin").grep_string({
    prompt_title = 'Open Note with Trouble',
    search = "",     -- Empty search to show all notes
    search_dirs = { M.notes_directory },
    attach_mappings = function(_, prompt_bufnr)
      actions.select_default:replace(function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        if selection and selection.filename then
          run_in_directory(M.notes_directory, function()
            vim.fn["trouble.open"](selection.filename)
            vim.api.nvim_out_write("Opened note with trouble: " .. selection.filename .. "\n")
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

return M
