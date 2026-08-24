local M = {}

local uv = vim.uv or vim.loop
local is_list = vim.islist or vim.tbl_islist

local function default_notify(msg, level)
  if vim.notify then
    vim.notify(msg, level or vim.log.levels.INFO, { title = "notes.nvim" })
  else
    vim.api.nvim_echo({ { msg, "Normal" } }, true, {})
  end
end

local default_config = {
  notes_path = nil,
  frontmatter = nil,
  notify = default_notify,
  note_extensions = { "md", "markdown" },
  ignore_hidden = true,
  telescope = {
    find_files = {},
    live_grep = {},
  },
}

local valid_config_keys = {
  frontmatter = true,
  ignore_hidden = true,
  note_extensions = true,
  notes_path = true,
  notify = true,
  telescope = true,
}

local function validate_user_config(config)
  for key in pairs(config) do
    if not valid_config_keys[key] then
      return "unknown setup option: " .. tostring(key)
    end
  end
  if config.notes_path ~= nil and (type(config.notes_path) ~= "string" or vim.trim(config.notes_path) == "") then
    return "notes_path must be a non-empty string"
  end
  if config.frontmatter ~= nil then
    local frontmatter_type = type(config.frontmatter)
    if frontmatter_type ~= "function" and (frontmatter_type ~= "table" or not is_list(config.frontmatter)) then
      return "frontmatter must be a function or list"
    end
  end
  if config.notify ~= nil and type(config.notify) ~= "function" then
    return "notify must be a function"
  end
  if config.ignore_hidden ~= nil and type(config.ignore_hidden) ~= "boolean" then
    return "ignore_hidden must be a boolean"
  end
  if config.note_extensions ~= nil then
    if type(config.note_extensions) ~= "table" or not is_list(config.note_extensions) then
      return "note_extensions must be a list"
    end
    for _, extension in ipairs(config.note_extensions) do
      if type(extension) ~= "string" or extension:gsub("^%.", "") == "" then
        return "note_extensions entries must be non-empty strings"
      end
    end
  end
  if config.telescope ~= nil then
    if type(config.telescope) ~= "table" then
      return "telescope must be a table"
    end
    for _, picker in ipairs({ "find_files", "live_grep" }) do
      if config.telescope[picker] ~= nil and type(config.telescope[picker]) ~= "table" then
        return "telescope." .. picker .. " must be a table"
      end
    end
  end
  return nil
end

local config_state = vim.deepcopy(default_config)

local function merge_config(overrides)
  local merged = vim.tbl_deep_extend("force", {}, config_state, overrides or {})
  if type(overrides) == "table" and overrides.note_extensions ~= nil then
    merged.note_extensions = vim.deepcopy(overrides.note_extensions)
  end
  return merged
end

local function get_home_dir()
  local home = uv.os_homedir() or os.getenv("HOME")
  if not home then
    error("notes.nvim: unable to resolve home directory")
  end
  return home
end

local function fallback_join(first, ...)
  local sep = package.config:sub(1, 1)
  local parts = { first, ... }
  local result

  for _, part in ipairs(parts) do
    if part and part ~= "" then
      part = part:gsub("[/\\]", sep)
      result = result and (result:gsub("[/\\]+$", "") .. sep .. part:gsub("^[/\\]+", "")) or part
    end
  end

  return result or ""
end

local join_path = (vim.fs and vim.fs.joinpath) or fallback_join

local normalize_path = (vim.fs and vim.fs.normalize) or function(path)
  return path
end

local function notify(config, msg, level)
  local fn = config and config.notify
  if type(fn) ~= "function" then
    fn = default_notify
  end

  local ok = pcall(fn, msg, level or vim.log.levels.INFO)
  if not ok and fn ~= default_notify then
    pcall(default_notify, msg, level or vim.log.levels.INFO)
  end
end

local function get_notes_path(config)
  local path
  if config.notes_path and config.notes_path ~= "" then
    path = config.notes_path
  else
    path = join_path(get_home_dir(), "git", "notes", "vault")
  end

  return normalize_path(vim.fn.fnamemodify(normalize_path(path), ":p"))
end

local function ensure_dir(config, path)
  if vim.fn.isdirectory(path) == 1 then
    return true
  end

  local ok, result = pcall(vim.fn.mkdir, path, "p")
  if not ok or (result ~= 1 and vim.fn.isdirectory(path) == 0) then
    notify(config, "notes.nvim: unable to create directory at " .. path, vim.log.levels.ERROR)
    return false
  end

  return true
end

local function is_absolute(path)
  return path:match("^[/\\]") ~= nil or path:match("^%a:[/\\]") ~= nil
end

local function comparable_path(path)
  local comparable = normalize_path(path):gsub("\\", "/")
  if comparable ~= "/" then
    comparable = comparable:gsub("/+$", "")
  end
  if package.config:sub(1, 1) == "\\" then
    comparable = comparable:lower()
  end
  return comparable
end

local function path_is_within(root, path)
  local comparable_root = comparable_path(root)
  local comparable_pathname = comparable_path(path)
  if comparable_root == "/" then
    return comparable_pathname:sub(1, 1) == "/"
  end
  return comparable_pathname == comparable_root
    or comparable_pathname:sub(1, #comparable_root + 1) == comparable_root .. "/"
end

local function normalize_note_name(name)
  if type(name) ~= "string" then
    return nil, "note name must be a string"
  end

  name = vim.trim(name):gsub("\\", "/")
  if name == "" then
    return nil, "note name cannot be empty"
  end
  if name:find("[%z\1-\31]") then
    return nil, "note name cannot contain control characters"
  end
  if is_absolute(name) then
    return nil, "absolute note paths are not allowed"
  end
  if name:sub(-1) == "/" then
    return nil, "note name must include a filename"
  end

  local segments = {}
  for segment in name:gmatch("[^/]+") do
    if segment == "." or segment == ".." then
      return nil, "dot path segments are not allowed"
    end
    segments[#segments + 1] = segment
  end

  if #segments == 0 then
    return nil, "note name cannot be empty"
  end
  return table.concat(segments, "/")
end

local function has_symlink_component(root, relative_path)
  local current = root
  for segment in relative_path:gmatch("[^/]+") do
    current = join_path(current, segment)
    local stat = uv.fs_lstat(current)
    if stat and stat.type == "link" then
      return true
    end
  end
  return false
end

local function resolve_note_path(notes_path, name)
  local normalized_name, err = normalize_note_name(name)
  if not normalized_name then
    return nil, nil, err
  end

  local full_path = normalize_path(join_path(notes_path, normalized_name))
  if not path_is_within(notes_path, full_path) then
    return nil, nil, "note path must stay inside the configured vault"
  end
  if has_symlink_component(notes_path, normalized_name) then
    return nil, nil, "note path cannot contain symbolic links"
  end

  return full_path, normalized_name
end

local function list_dir(path)
  local handle = uv.fs_scandir(path)
  if not handle then
    return {}
  end

  local entries = {}
  while true do
    local name, entry_type = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    entries[#entries + 1] = { name = name, type = entry_type }
  end
  return entries
end

local function yaml_string(value)
  local string_value = tostring(value)
  local encoder = vim.json and vim.json.encode or vim.fn.json_encode
  local ok, encoded = pcall(encoder, string_value)
  if ok and type(encoded) == "string" then
    return encoded
  end
  return '"' .. string_value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
end

local function format_list(items)
  if type(items) ~= "table" or vim.tbl_isempty(items) then
    return "[]"
  end

  local quoted = {}
  for _, item in ipairs(items) do
    quoted[#quoted + 1] = yaml_string(item)
  end
  return "[ " .. table.concat(quoted, ", ") .. " ]"
end

local function default_frontmatter(ctx)
  return {
    "---",
    "id: " .. yaml_string(ctx.id),
    "aliases: " .. format_list(ctx.metadata.aliases),
    "created: " .. yaml_string(ctx.created),
    "tags: " .. format_list(ctx.metadata.tags),
    "---",
    "",
  }
end

local function build_frontmatter(config, ctx)
  local template = config.frontmatter
  local lines

  if type(template) == "function" then
    lines = template(ctx)
  elseif type(template) == "table" then
    lines = template
  end

  if type(lines) ~= "table" then
    lines = default_frontmatter(ctx)
  end

  local normalized = {}
  for _, line in ipairs(lines) do
    normalized[#normalized + 1] = tostring(line)
  end
  return normalized
end

local function edit_file(config, path)
  local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
  if not ok then
    notify(config, "notes.nvim: unable to open note at " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function extension_set(extensions)
  local result = {}
  if type(extensions) ~= "table" then
    return result
  end
  for _, extension in ipairs(extensions) do
    extension = tostring(extension):lower():gsub("^%.", "")
    if extension ~= "" then
      result[extension] = true
    end
  end
  return result
end

local function is_note_file(name, extensions, allow_all)
  if allow_all then
    return true
  end
  local extension = name:match("%.([^./]+)$")
  return extension ~= nil and extensions[extension:lower()] == true
end

local function scan_latest(dir, acc, config, extensions, allow_all)
  local handle = uv.fs_scandir(dir)
  if not handle then
    return acc
  end

  while true do
    local name, entry_type = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    local hidden = name:sub(1, 1) == "."
    if not (config.ignore_hidden and hidden) then
      local full_path = join_path(dir, name)
      if entry_type == "directory" then
        acc = scan_latest(full_path, acc, config, extensions, allow_all)
      elseif entry_type ~= "link" and is_note_file(name, extensions, allow_all) then
        local stat = uv.fs_stat(full_path)
        if stat and stat.type == "file" and stat.mtime then
          local mtime = stat.mtime.sec + (stat.mtime.nsec or 0) / 1e9
          if mtime > acc.mtime or (mtime == acc.mtime and (not acc.path or full_path < acc.path)) then
            acc.mtime = mtime
            acc.path = full_path
          end
        end
      end
    end
  end

  return acc
end

local function load_telescope(config)
  local builtin_ok, builtin = pcall(require, "telescope.builtin")
  if not builtin_ok then
    notify(config, "notes.nvim: telescope.nvim is required for this command", vim.log.levels.ERROR)
    return nil
  end
  return builtin
end

local function build_telescope_opts(config, picker, notes_path)
  local defaults
  if picker == "find_files" then
    defaults = {
      prompt_title = "Find Note",
      cwd = notes_path,
      sorting_strategy = "ascending",
      layout_strategy = "horizontal",
      layout_config = { prompt_position = "top", preview_width = 0.55 },
      dynamic_preview_title = true,
      path_display = { "truncate" },
      hidden = not config.ignore_hidden,
    }
  else
    defaults = {
      prompt_title = "Search Notes",
      cwd = notes_path,
      sorting_strategy = "descending",
      layout_strategy = "horizontal",
      layout_config = { preview_width = 0.6 },
      dynamic_preview_title = true,
      path_display = { "truncate" },
      results_title = "Matches",
      additional_args = config.ignore_hidden and nil or { "--hidden" },
    }
  end

  local telescope_config = config.telescope or {}
  return vim.tbl_deep_extend("force", {}, defaults, telescope_config[picker] or {})
end

local function create_note(config, name, metadata)
  local notes_path = get_notes_path(config)
  local full_path, normalized_name, resolve_error = resolve_note_path(notes_path, name)
  if not full_path then
    notify(config, "notes.nvim: " .. resolve_error, vim.log.levels.ERROR)
    return nil
  end

  if not ensure_dir(config, notes_path) then
    return nil
  end

  if vim.fn.filereadable(full_path) == 1 then
    return edit_file(config, full_path) and full_path or nil
  end

  local parent_dir = vim.fn.fnamemodify(full_path, ":h")
  if not ensure_dir(config, parent_dir) then
    return nil
  end

  local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local id = vim.fn.fnamemodify(normalized_name, ":t:r")
  local ok, frontmatter = pcall(build_frontmatter, config, {
    name = normalized_name,
    path = full_path,
    id = id,
    created = timestamp,
    metadata = metadata,
    config = config,
  })
  if not ok then
    notify(config, "notes.nvim: front matter callback failed: " .. tostring(frontmatter), vim.log.levels.ERROR)
    return nil
  end

  local write_ok, write_result = pcall(vim.fn.writefile, frontmatter, full_path)
  if not write_ok or write_result ~= 0 then
    notify(config, "notes.nvim: error creating note at " .. full_path, vim.log.levels.ERROR)
    return nil
  end

  return edit_file(config, full_path) and full_path or nil
end

M.setup = function(user_config)
  if user_config ~= nil and type(user_config) ~= "table" then
    error("notes.nvim: setup options must be a table", 2)
  end
  user_config = user_config or {}
  local config_error = validate_user_config(user_config)
  if config_error then
    error("notes.nvim: " .. config_error, 2)
  end

  config_state = vim.tbl_deep_extend("force", {}, default_config, user_config)
  if user_config.note_extensions ~= nil then
    config_state.note_extensions = vim.deepcopy(user_config.note_extensions)
  end
  return vim.deepcopy(config_state)
end

M.get_config = function()
  return vim.deepcopy(config_state)
end

M.notes_path = function(opts)
  return get_notes_path(merge_config(type(opts) == "table" and opts or nil))
end

M.complete_note_name = function(arglead, opts)
  local config = merge_config(type(opts) == "table" and opts or nil)
  local notes_path = get_notes_path(config)
  local input = type(arglead) == "string" and arglead:gsub("\\", "/") or ""

  if vim.fn.isdirectory(notes_path) == 0 or is_absolute(input) or input:find("[%z\1-\31]") then
    return {}
  end
  local dir_part, partial = input:match("^(.*)/([^/]*)$")
  if not dir_part then
    dir_part = ""
    partial = input
  end
  if partial == ".." then
    return {}
  end
  for segment in dir_part:gmatch("[^/]+") do
    if segment == "." or segment == ".." then
      return {}
    end
  end

  local search_path = dir_part == "" and notes_path or normalize_path(join_path(notes_path, dir_part))
  if not path_is_within(notes_path, search_path) or has_symlink_component(notes_path, dir_part) then
    return {}
  end
  if vim.fn.isdirectory(search_path) == 0 then
    return {}
  end

  local rel_prefix = dir_part == "" and "" or dir_part .. "/"
  local results = {}
  for _, entry in ipairs(list_dir(search_path)) do
    local hidden = entry.name:sub(1, 1) == "."
    local show_hidden = not config.ignore_hidden or partial:sub(1, 1) == "."
    if entry.type ~= "link" and (show_hidden or not hidden) and entry.name:sub(1, #partial) == partial then
      local candidate = rel_prefix .. entry.name
      if entry.type == "directory" then
        candidate = candidate .. "/"
      end
      results[#results + 1] = candidate
    end
  end

  table.sort(results)
  return results
end

M.new_note = function(opts)
  local name
  local metadata = {}
  local overrides

  if type(opts) == "table" then
    name = opts.name
    metadata = type(opts.metadata) == "table" and opts.metadata or {}
    overrides = vim.tbl_deep_extend("force", {}, opts)
    overrides.name = nil
    overrides.metadata = nil
  end

  local config = merge_config(overrides)
  if type(name) == "string" and name ~= "" then
    return create_note(config, name, metadata)
  end
  if name ~= nil and name ~= "" then
    notify(config, "notes.nvim: note name must be a string", vim.log.levels.ERROR)
    return nil
  end

  local input_ok, input_error = pcall(
    vim.ui.input,
    { prompt = "Note name (empty creates today's daily note): " },
    function(input)
      if input == nil then
        return
      end
      create_note(config, input == "" and os.date("daily.%Y-%m-%d.md") or input, metadata)
    end
  )
  if not input_ok then
    notify(config, "notes.nvim: unable to open note prompt: " .. tostring(input_error), vim.log.levels.ERROR)
  end
  return nil
end

M.find_note = function(opts)
  local config = merge_config(type(opts) == "table" and opts or nil)
  local notes_path = get_notes_path(config)
  if not ensure_dir(config, notes_path) then
    return nil
  end

  local telescope = load_telescope(config)
  if not telescope then
    return nil
  end
  telescope.find_files(build_telescope_opts(config, "find_files", notes_path))
  return true
end

M.search_notes = function(opts)
  local config = merge_config(type(opts) == "table" and opts or nil)
  local notes_path = get_notes_path(config)
  if vim.fn.executable("rg") ~= 1 then
    notify(config, "notes.nvim: ripgrep (rg) is required to search note contents", vim.log.levels.ERROR)
    return nil
  end
  if not ensure_dir(config, notes_path) then
    return nil
  end

  local telescope = load_telescope(config)
  if not telescope then
    return nil
  end
  telescope.live_grep(build_telescope_opts(config, "live_grep", notes_path))
  return true
end

M.last_note = function(opts)
  local config = merge_config(type(opts) == "table" and opts or nil)
  local notes_path = get_notes_path(config)
  if vim.fn.isdirectory(notes_path) == 0 then
    notify(config, "notes.nvim: no notes found", vim.log.levels.WARN)
    return nil
  end

  local extensions = extension_set(config.note_extensions)
  local allow_all = type(config.note_extensions) == "table" and vim.tbl_isempty(config.note_extensions)
  local latest = scan_latest(notes_path, { path = nil, mtime = -math.huge }, config, extensions, allow_all)
  if not latest.path then
    notify(config, "notes.nvim: no notes found", vim.log.levels.WARN)
    return nil
  end

  return edit_file(config, latest.path) and latest.path or nil
end

return M
