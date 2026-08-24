if vim.g.loaded_notes_nvim == 1 then
  return
end
vim.g.loaded_notes_nvim = 1

local notes = require("notes")

vim.api.nvim_create_user_command("NotesNew", function(opts)
  local name = opts.args ~= "" and opts.args or nil
  notes.new_note({ name = name })
end, {
  nargs = "?",
  desc = "Create a new note",
  complete = function(arglead)
    return notes.complete_note_name(arglead)
  end,
})

vim.api.nvim_create_user_command("NotesFind", function()
  notes.find_note()
end, { desc = "Find a note" })

vim.api.nvim_create_user_command("NotesSearch", function()
  notes.search_notes()
end, { desc = "Search across notes" })

vim.api.nvim_create_user_command("NotesLast", function()
  notes.last_note()
end, { desc = "Open the most recently modified note" })
