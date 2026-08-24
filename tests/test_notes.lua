local uv = vim.uv or vim.loop
local notes = require("notes")

local failures = {}
local roots = {}
local tests_run = 0

local function fail(message)
  error(message, 2)
end

local function assert_equal(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    fail(
      (message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual)
    )
  end
end

local function assert_truthy(value, message)
  if not value then
    fail(message or "expected a truthy value")
  end
end

local function assert_contains(haystack, needle, message)
  if not haystack:find(needle, 1, true) then
    fail((message or "text not found") .. "\nneedle: " .. needle .. "\nhaystack: " .. haystack)
  end
end

local function temp_dir()
  local root = vim.fn.tempname()
  assert_equal(1, vim.fn.mkdir(root, "p"), "could not create test directory")
  if vim.fs and vim.fs.normalize then
    root = vim.fs.normalize(root)
  end
  roots[#roots + 1] = root
  return root
end

local function join(...)
  if vim.fs and vim.fs.joinpath then
    return vim.fs.joinpath(...)
  end
  return table.concat({ ... }, "/")
end

local function write_file(path, lines)
  assert_equal(1, vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p"))
  assert_equal(0, vim.fn.writefile(lines or { "fixture" }, path))
end

local function messages_config(root, extra)
  local messages = {}
  local config = vim.tbl_deep_extend("force", {
    notes_path = root,
    notify = function(message, level)
      messages[#messages + 1] = { message = message, level = level }
    end,
  }, extra or {})
  notes.setup(config)
  return messages
end

local function test(name, callback)
  tests_run = tests_run + 1
  local ok, err = xpcall(callback, debug.traceback)
  if ok then
    print("ok - " .. name)
  else
    failures[#failures + 1] = name .. "\n" .. err
    print("not ok - " .. name)
  end
  vim.cmd("silent! enew!")
end

test("setup returns defensive configuration copies", function()
  local root = temp_dir()
  local config = notes.setup({ notes_path = root, note_extensions = { "txt" } })
  config.note_extensions[1] = "changed"
  assert_equal({ "txt" }, notes.get_config().note_extensions)
  assert_equal(root, notes.notes_path())
end)

test("setup rejects unknown and malformed options without replacing configuration", function()
  local root = temp_dir()
  notes.setup({ notes_path = root })

  local unknown_ok, unknown_error = pcall(notes.setup, { note_extensons = { "md" } })
  local invalid_ok, invalid_error = pcall(notes.setup, { note_extensions = "md" })

  assert_equal(false, unknown_ok)
  assert_contains(unknown_error, "unknown setup option: note_extensons")
  assert_equal(false, invalid_ok)
  assert_contains(invalid_error, "note_extensions must be a list")
  assert_equal(root, notes.notes_path())
end)

test("creates nested notes and safely encodes YAML strings", function()
  local root = temp_dir()
  messages_config(root)
  local path = notes.new_note({
    name = "projects/example.md",
    metadata = { tags = { 'quote"value', "slash\\value", "line\nbreak" } },
  })

  assert_equal(join(root, "projects", "example.md"), path)
  local contents = table.concat(vim.fn.readfile(path), "\n")
  assert_contains(contents, 'id: "example"')
  assert_contains(contents, 'quote\\"value')
  assert_contains(contents, "slash\\\\value")
  assert_contains(contents, "line\\nbreak")
end)

test("rejects traversal and absolute note names before creating the vault", function()
  local parent = temp_dir()
  local vault = join(parent, "vault")
  local messages = messages_config(vault)

  assert_equal(nil, notes.new_note({ name = "../escaped.md" }))
  assert_equal(nil, notes.new_note({ name = join(parent, "absolute.md") }))
  assert_equal(0, vim.fn.filereadable(join(parent, "escaped.md")))
  assert_equal(0, vim.fn.filereadable(join(parent, "absolute.md")))
  assert_equal(0, vim.fn.isdirectory(vault))
  assert_contains(messages[1].message, "dot path segments")
  assert_contains(messages[2].message, "absolute note paths")
end)

test("rejects paths through symbolic links", function()
  local root = temp_dir()
  local vault = join(root, "vault")
  local outside = join(root, "outside")
  assert_equal(1, vim.fn.mkdir(vault, "p"))
  assert_equal(1, vim.fn.mkdir(outside, "p"))
  local linked, link_error = uv.fs_symlink(outside, join(vault, "linked"), { dir = true })
  if not linked then
    print("skip detail - symlink unavailable: " .. tostring(link_error))
    return
  end

  local messages = messages_config(vault)
  assert_equal(nil, notes.new_note({ name = "linked/escaped.md" }))
  assert_equal(0, vim.fn.filereadable(join(outside, "escaped.md")))
  assert_contains(messages[1].message, "symbolic links")
  assert_equal({}, notes.complete_note_name("linked/"))
end)

test("completion remains inside the vault and filters hidden entries", function()
  local root = temp_dir()
  write_file(join(root, "alpha.md"))
  write_file(join(root, ".hidden.md"))
  write_file(join(root, "projects", "beta.md"))
  messages_config(root)

  assert_equal({ "alpha.md" }, notes.complete_note_name("a"))
  assert_equal({ "projects/beta.md" }, notes.complete_note_name("projects/b"))
  assert_equal({}, notes.complete_note_name("../"))
  assert_equal({ ".hidden.md" }, notes.complete_note_name("."))
end)

test("cancelling the prompt does not create a daily note", function()
  local root = join(temp_dir(), "vault")
  messages_config(root)
  local original_input = vim.ui.input
  vim.ui.input = function(_, callback)
    callback(nil)
  end
  notes.new_note()
  vim.ui.input = original_input
  assert_equal(0, vim.fn.isdirectory(root))
end)

test("an empty prompt creates today's daily note", function()
  local root = join(temp_dir(), "vault")
  messages_config(root)
  local original_input = vim.ui.input
  vim.ui.input = function(_, callback)
    callback("")
  end
  notes.new_note()
  vim.ui.input = original_input
  assert_equal(1, vim.fn.filereadable(join(root, os.date("daily.%Y-%m-%d.md"))))
end)

test("prompt failures are reported through notify", function()
  local root = temp_dir()
  local messages = messages_config(root)
  local original_input = vim.ui.input
  vim.ui.input = function()
    error("input provider exploded")
  end
  notes.new_note()
  vim.ui.input = original_input
  assert_contains(messages[1].message, "unable to open note prompt")
end)

test("front matter callback failures are reported without creating a file", function()
  local root = temp_dir()
  local messages = messages_config(root, {
    frontmatter = function()
      error("template exploded")
    end,
  })
  assert_equal(nil, notes.new_note({ name = "broken.md" }))
  assert_equal(0, vim.fn.filereadable(join(root, "broken.md")))
  assert_contains(messages[1].message, "front matter callback failed")
end)

test("filesystem failures use the configured notifier", function()
  local root = temp_dir()
  local blocker = join(root, "not-a-directory")
  write_file(blocker)
  local messages = messages_config(blocker)
  assert_equal(nil, notes.new_note({ name = "note.md" }))
  assert_contains(messages[1].message, "unable to create directory")
end)

test("last_note ignores hidden files, attachments, and symbolic links", function()
  local root = temp_dir()
  local older = join(root, "older.md")
  local latest = join(root, "nested", "latest.markdown")
  local attachment = join(root, "attachment.png")
  local hidden = join(root, ".hidden.md")
  write_file(older)
  write_file(latest)
  write_file(attachment)
  write_file(hidden)
  uv.fs_symlink(attachment, join(root, "linked.md"))
  uv.fs_utime(older, 100, 100)
  uv.fs_utime(latest, 200, 200)
  uv.fs_utime(attachment, 300, 300)
  uv.fs_utime(hidden, 400, 400)

  messages_config(root)
  assert_equal(latest, notes.last_note())
  assert_equal(vim.fn.resolve(latest), vim.api.nvim_buf_get_name(0))
  assert_equal(attachment, notes.last_note({ note_extensions = {} }))
end)

test("last_note supports custom extensions and per-call notifications", function()
  local root = temp_dir()
  local markdown = join(root, "note.md")
  local text = join(root, "note.txt")
  write_file(markdown)
  write_file(text)
  uv.fs_utime(markdown, 100, 100)
  uv.fs_utime(text, 200, 200)
  messages_config(root)

  assert_equal(text, notes.last_note({ note_extensions = { "txt" } }))

  local per_call = {}
  notes.last_note({
    notes_path = join(root, "missing"),
    notify = function(message)
      per_call[#per_call + 1] = message
    end,
  })
  assert_contains(per_call[1], "no notes found")
end)

test("missing Telescope is reported instead of raised", function()
  local root = temp_dir()
  local messages = messages_config(root)
  local old_builtin_loaded = package.loaded["telescope.builtin"]
  local old_config_loaded = package.loaded["telescope.config"]
  local old_builtin_preload = package.preload["telescope.builtin"]
  local old_config_preload = package.preload["telescope.config"]

  package.loaded["telescope.builtin"] = nil
  package.loaded["telescope.config"] = nil
  package.preload["telescope.builtin"] = function()
    error("forced missing dependency")
  end
  package.preload["telescope.config"] = function()
    error("forced missing dependency")
  end

  local ok = pcall(notes.find_note)
  package.loaded["telescope.builtin"] = old_builtin_loaded
  package.loaded["telescope.config"] = old_config_loaded
  package.preload["telescope.builtin"] = old_builtin_preload
  package.preload["telescope.config"] = old_config_preload

  assert_truthy(ok)
  assert_contains(messages[1].message, "telescope.nvim is required")
end)

test("missing ripgrep is reported before opening Telescope", function()
  local root = temp_dir()
  local messages = messages_config(root)
  local original_executable = vim.fn.executable
  vim.fn.executable = function(command)
    if command == "rg" then
      return 0
    end
    return original_executable(command)
  end

  local ok = pcall(notes.search_notes)
  vim.fn.executable = original_executable

  assert_truthy(ok)
  assert_contains(messages[1].message, "ripgrep (rg) is required")
end)

test("Telescope options are merged and scoped to the vault", function()
  local root = temp_dir()
  messages_config(root)
  local captured
  local old_builtin = package.loaded["telescope.builtin"]
  local old_config = package.loaded["telescope.config"]
  package.loaded["telescope.builtin"] = {
    find_files = function(options)
      captured = options
    end,
  }
  package.loaded["telescope.config"] = { values = { file_previewer = "preview" } }

  assert_truthy(notes.find_note({ telescope = { find_files = { path_display = { "smart" } } } }))
  package.loaded["telescope.builtin"] = old_builtin
  package.loaded["telescope.config"] = old_config

  assert_equal(root, captured.cwd)
  assert_equal({ "smart" }, captured.path_display)
  assert_equal(false, captured.hidden)
  assert_equal(nil, captured.previewer)
end)

test("plugin commands are registered once", function()
  vim.cmd("runtime plugin/notes.lua")
  vim.cmd("runtime plugin/notes.lua")
  assert_equal(2, vim.fn.exists(":NotesNew"))
  assert_equal(2, vim.fn.exists(":NotesFind"))
  assert_equal(2, vim.fn.exists(":NotesSearch"))
  assert_equal(2, vim.fn.exists(":NotesLast"))
end)

test("checkhealth reports the runtime, vault, and dependencies", function()
  local root = temp_dir()
  notes.setup({ notes_path = root })
  local reports = {}
  local original_health = vim.health
  local original_telescope = package.loaded["telescope.builtin"]
  vim.health = {
    error = function(message)
      reports[#reports + 1] = "error:" .. message
    end,
    ok = function(message)
      reports[#reports + 1] = "ok:" .. message
    end,
    start = function(message)
      reports[#reports + 1] = "start:" .. message
    end,
    warn = function(message)
      reports[#reports + 1] = "warn:" .. message
    end,
  }
  package.loaded["telescope.builtin"] = {}
  package.loaded["notes.health"] = nil

  local ok, health_error = pcall(require("notes.health").check)
  vim.health = original_health
  package.loaded["telescope.builtin"] = original_telescope

  assert_truthy(ok, health_error)
  assert_equal("start:notes.nvim", reports[1])
  assert_truthy(#reports >= 4)
end)

for _, root in ipairs(roots) do
  vim.fn.delete(root, "rf")
end

if #failures > 0 then
  print("\n" .. table.concat(failures, "\n\n"))
  print(("\n%d/%d tests failed"):format(#failures, tests_run))
  vim.cmd("cquit 1")
else
  print(("\n%d tests passed"):format(tests_run))
end
