local M = {}

local function health_api()
  local health = vim.health or require("health")
  return {
    error = health.error or health.report_error,
    ok = health.ok or health.report_ok,
    start = health.start or health.report_start,
    warn = health.warn or health.report_warn,
  }
end

M.check = function()
  local health = health_api()
  health.start("notes.nvim")

  if vim.fn.has("nvim-0.9") == 1 then
    health.ok("Neovim 0.9 or newer is available")
  else
    health.error("Neovim 0.9 or newer is required")
  end

  local notes = require("notes")
  local path_ok, notes_path = pcall(notes.notes_path)
  if not path_ok then
    health.error("Unable to resolve notes_path: " .. tostring(notes_path))
  elseif vim.fn.isdirectory(notes_path) == 1 then
    health.ok("Notes directory exists: " .. notes_path)
    if vim.fn.filewritable(notes_path) ~= 2 then
      health.warn("Notes directory may not be writable: " .. notes_path)
    end
  else
    health.warn("Notes directory does not exist yet and will be created on first use: " .. notes_path)
  end

  if pcall(require, "telescope.builtin") then
    health.ok("telescope.nvim is available")
  else
    health.error("telescope.nvim is required for :NotesFind and :NotesSearch")
  end

  if vim.fn.executable("rg") == 1 then
    health.ok("ripgrep is available")
  else
    health.warn("ripgrep is required for :NotesSearch")
  end
end

return M
