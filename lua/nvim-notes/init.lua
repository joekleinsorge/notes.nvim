local M = {}

M.find_note = function()
  local telescope = require("telescope.builtin")
  local notes_path = "~/git/notes/vault"

  telescope.find_files({
    prompt_title = "Find Note",
    cwd = notes_path,
  })
end

M.create_note = function()
  local name = vim.fn.input("Note Name: ")
  if name == "" then
    name = os.date("daily.%Y-%m-%d.md")
  end
  local notes_path = "~/git/notes/vault"
  local full_path = notes_path .. "/" .. name
  vim.fn.writefile({}, full_path)
  vim.cmd("e " .. full_path)
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
