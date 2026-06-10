local backend = require("yocto_vars.backend")
local context = require("yocto_vars.context")

local M = {}

local defaults = {
  backend = "auto",
  build_dir = "build",
  root_markers = {
    "init-build-env",
    "sources/poky/oe-init-build-env",
    "docker-compose.yml",
    ".git",
  },
  docker = {
    service = nil,
    compose_command = { "docker", "compose" },
    user = nil,
  },
  keymaps = {
    enable = true,
    hover = "K",
  },
  popup = {
    width = 100,
    max_height = 20,
    border = "rounded",
  },
  set_filetype = true,
}

M.config = vim.deepcopy(defaults)

local function split_lines(value)
  local lines = {}
  value = value or ""
  if value == "" then
    return { "" }
  end
  value = value:gsub("\r\n", "\n")
  for line in (value .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end
  return lines
end

local function max_width(lines)
  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  return width
end

local function open_float(lines, title)
  local popup = M.config.popup
  local columns = vim.o.columns
  local rows = vim.o.lines
  local width = math.min(popup.width, math.max(20, max_width(lines)), math.max(20, columns - 6))
  local height = math.min(#lines, popup.max_height, math.max(3, rows - 6))
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "yocto-vars")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((rows - height) / 2) - 1,
    col = math.floor((columns - width) / 2),
    style = "minimal",
    border = popup.border,
    title = title and (" " .. title .. " ") or nil,
    title_pos = "left",
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<cmd>close<CR>", { silent = true, nowait = true })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", "<cmd>close<CR>", { silent = true, nowait = true })

  return bufnr, winid
end

local function replace_float(bufnr, winid, lines, title)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(winid) then
    return open_float(lines, title)
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local popup = M.config.popup
  local columns = vim.o.columns
  local rows = vim.o.lines
  local width = math.min(popup.width, math.max(20, max_width(lines)), math.max(20, columns - 6))
  local height = math.min(#lines, popup.max_height, math.max(3, rows - 6))

  vim.api.nvim_win_set_config(winid, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((rows - height) / 2) - 1,
    col = math.floor((columns - width) / 2),
    style = "minimal",
    border = popup.border,
    title = title and (" " .. title .. " ") or nil,
    title_pos = "left",
  })

  return bufnr, winid
end

local function format_result(query, result)
  local lines = {
    query.variable,
    "recipe: " .. query.recipe,
    "backend: " .. (result.backend or "unknown"),
    "",
  }

  if result.ok then
    vim.list_extend(lines, split_lines(result.value))
  else
    table.insert(lines, "Failed to expand variable.")
    table.insert(lines, "")
    vim.list_extend(lines, split_lines(result.error))
  end

  return lines
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.WARN, { title = "yocto-vars.nvim" })
end

local function resolve_query(opts)
  opts = opts or {}
  local variable = opts.variable or context.variable_under_cursor()
  if not variable or variable == "" then
    return nil, "No BitBake variable under cursor"
  end

  local path = context.current_buffer_path()
  local root = opts.root or context.find_project_root(path or vim.fn.getcwd(), M.config.root_markers)
  if not root then
    return nil, "Could not find a Yocto project root"
  end

  local recipe = opts.recipe or context.infer_recipe()
  if not recipe or recipe == "" then
    return nil, "Could not infer recipe from current file; use :YoctoVarRecipe <recipe> <variable>"
  end

  return {
    root = root,
    build_dir = opts.build_dir or M.config.build_dir,
    variable = variable,
    recipe = recipe,
    backend = opts.backend or M.config.backend,
    docker = vim.deepcopy(M.config.docker),
  }
end

function M.show(opts)
  local query, err = resolve_query(opts)
  if not query then
    notify(err)
    return
  end

  local bufnr, winid = open_float({
    query.variable,
    "recipe: " .. query.recipe,
    "",
    "Querying BitBake...",
  }, "Yocto Variable")

  backend.query(query, function(result)
    replace_float(bufnr, winid, format_result(query, result), "Yocto Variable")
  end)
end

local function yocto_var_command(command)
  local args = command.fargs
  if #args > 1 then
    notify("Usage: :YoctoVar [variable]")
    return
  end
  M.show({ variable = args[1] })
end

local function yocto_var_recipe_command(command)
  local args = command.fargs
  if #args ~= 2 then
    notify("Usage: :YoctoVarRecipe <recipe> <variable>")
    return
  end
  M.show({ recipe = args[1], variable = args[2] })
end

local function create_commands()
  vim.api.nvim_create_user_command("YoctoVar", yocto_var_command, {
    nargs = "*",
    desc = "Show expanded BitBake variable for the current recipe",
  })
  vim.api.nvim_create_user_command("YoctoVarRecipe", yocto_var_recipe_command, {
    nargs = "*",
    desc = "Show expanded BitBake variable for an explicit recipe",
  })
end

local function setup_filetypes()
  if not M.config.set_filetype then
    return
  end
  vim.filetype.add({
    extension = {
      bb = "bitbake",
      bbappend = "bitbake",
    },
    pattern = {
      [".*/recipes-.*/.*%.inc"] = "bitbake",
      [".*/conf/.*%.inc"] = "bitbake",
    },
  })
end

local function setup_keymaps()
  if not M.config.keymaps.enable then
    return
  end

  local group = vim.api.nvim_create_augroup("YoctoVarsKeymaps", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "bitbake",
    callback = function(event)
      vim.keymap.set("n", M.config.keymaps.hover, function()
        M.show()
      end, {
        buffer = event.buf,
        silent = true,
        desc = "Show expanded Yocto variable",
      })
    end,
  })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  setup_filetypes()
  create_commands()
  setup_keymaps()
end

M._defaults = defaults

return M
