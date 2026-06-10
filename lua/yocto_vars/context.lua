local M = {}

local path_sep = package.config:sub(1, 1)

local function is_sep(char)
  return char == "/" or char == "\\"
end

local function basename(path)
  return (path:gsub("[/\\]+$", ""):match("([^/\\]+)$")) or path
end

local function dirname(path)
  local trimmed = path:gsub("[/\\]+$", "")
  local dir = trimmed:match("^(.*)[/\\][^/\\]+$")
  if dir == "" then
    return path_sep
  end
  return dir
end

local function exists(path)
  if vim and vim.uv and vim.uv.fs_stat then
    return vim.uv.fs_stat(path) ~= nil
  end
  if vim and vim.loop and vim.loop.fs_stat then
    return vim.loop.fs_stat(path) ~= nil
  end
  local handle = io.open(path, "r")
  if handle then
    handle:close()
    return true
  end
  return false
end

local function join(...)
  local parts = { ... }
  return table.concat(parts, path_sep)
end

local function parent(path)
  local dir = dirname(path)
  if not dir or dir == path then
    return nil
  end
  return dir
end

function M.find_project_root(start_path, markers)
  markers = markers or { "init-build-env", "sources/poky/oe-init-build-env", "docker-compose.yml", ".git" }

  local current = start_path
  if not current or current == "" then
    current = vim and vim.fn and vim.fn.getcwd() or "."
  end

  if exists(current) and not current:match("[/\\]$") then
    local stat = (vim and (vim.uv or vim.loop) and (vim.uv or vim.loop).fs_stat(current)) or nil
    if stat and stat.type ~= "directory" then
      current = dirname(current)
    elseif current:match("%.[%w_%-]+$") then
      current = dirname(current)
    end
  end

  while current and current ~= "" do
    for _, marker in ipairs(markers) do
      if exists(join(current, marker)) then
        return current
      end
    end
    current = parent(current)
  end

  return nil
end

function M.infer_recipe_from_path(path)
  if not path or path == "" then
    return nil
  end

  local file = basename(path)
  local stem = file:match("^(.*)%.bbappend$") or file:match("^(.*)%.bb$")
  if not stem then
    return nil
  end

  stem = stem:gsub("%%", "")
  local recipe = stem:match("^([^_]+)_") or stem
  if recipe == "" then
    return nil
  end

  return recipe
end

local function is_var_char(char)
  return char and char:match("[%w_]") ~= nil
end

function M.extract_variable_at(line, col)
  if not line or line == "" then
    return nil
  end

  col = tonumber(col) or 1
  if col < 1 then
    col = 1
  end

  local search_start = 1
  while true do
    local start_pos, end_pos, var = line:find("%${([%w_:+%.%-]+)}", search_start)
    if not start_pos then
      break
    end
    if col >= start_pos and col <= end_pos then
      return var
    end
    search_start = end_pos + 1
  end

  local left = col
  if left > #line then
    left = #line
  end
  while left > 1 and is_var_char(line:sub(left - 1, left - 1)) do
    left = left - 1
  end

  local right = col
  while right <= #line and is_var_char(line:sub(right, right)) do
    right = right + 1
  end

  local var = line:sub(left, right - 1)
  if var == "" or not var:match("[%a_]") then
    return nil
  end

  return var
end

function M.current_buffer_path()
  if not vim or not vim.api then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil
  end
  return name
end

function M.variable_under_cursor()
  if not vim or not vim.api then
    return nil
  end
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return M.extract_variable_at(line, cursor[2] + 1)
end

function M.infer_recipe()
  return M.infer_recipe_from_path(M.current_buffer_path())
end

return M
