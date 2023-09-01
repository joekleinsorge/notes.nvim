local M = {}

M.find_or_create_note = function()
  local telescope = require("telescope.builtin")
  local notes_path = "~/git/notes/vault"

  telescope.find_files({
    prompt_title = "Find or Create Note",
    cwd = notes_path,
    attach_mappings = function(_, map)
      map("i", "<CR>", function(bufnr)
        local name = vim.fn.input("Note Name: ")
        if name == "" then
          name = os.date("daily.%Y-%m-%d.md")
        end
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { name })
        vim.fn.execute("write")
        vim.cmd("edit " .. name)
        require("telescope.actions").close(bufnr)
      end)
      return true
    end,
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
