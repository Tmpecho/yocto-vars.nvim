local M = {}

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\"'\"'") .. "'"
end

local function trim(value)
  return (value or ""):gsub("%s+$", "")
end

local function append_data(target, data)
  if not data then
    return
  end
  for _, line in ipairs(data) do
    if line ~= "" then
      table.insert(target, line)
    end
  end
end

local function run_command(cmd, cwd, callback)
  if vim.system then
    vim.system(cmd, { cwd = cwd, text = true }, function(result)
      vim.schedule(function()
        callback(result.code, result.stdout or "", result.stderr or "")
      end)
    end)
    return
  end

  local stdout = {}
  local stderr = {}
  local job = vim.fn.jobstart(cmd, {
    cwd = cwd,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      append_data(stdout, data)
    end,
    on_stderr = function(_, data)
      append_data(stderr, data)
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        callback(code, table.concat(stdout, "\n"), table.concat(stderr, "\n"))
      end)
    end,
  })

  if job <= 0 then
    callback(127, "", "failed to start command")
  end
end

local function bitbake_script(opts)
  local build_dir = opts.build_dir or "build"
  local args = {
    "source ./init-build-env " .. shell_quote(build_dir) .. " >/dev/null",
    "bitbake-getvar -q --value -r " .. shell_quote(opts.recipe) .. " " .. shell_quote(opts.variable),
  }
  return table.concat(args, " && ")
end

local function direct_command(opts)
  return { "bash", "-lc", bitbake_script(opts) }
end

local function default_docker_service()
  local uname = vim.loop.os_uname()
  if uname and uname.sysname == "Darwin" then
    return "yocto-mac"
  end
  return "yocto-linux"
end

local function docker_command(opts)
  local docker = opts.docker or {}
  local service = docker.service or default_docker_service()
  local compose = docker.compose_command or { "docker", "compose" }
  local cmd = {}

  for _, part in ipairs(compose) do
    table.insert(cmd, part)
  end

  table.insert(cmd, "run")
  table.insert(cmd, "--rm")
  table.insert(cmd, "-T")

  if docker.user then
    table.insert(cmd, "--user")
    table.insert(cmd, docker.user)
  end

  table.insert(cmd, service)
  table.insert(cmd, "-lc")
  table.insert(cmd, bitbake_script(opts))

  return cmd
end

local function backend_order(opts)
  if opts.backend == "direct" then
    return { "direct" }
  end
  if opts.backend == "docker" then
    return { "docker" }
  end

  local uname = vim.loop.os_uname()
  if uname and uname.sysname == "Darwin" then
    return { "docker", "direct" }
  end
  return { "direct", "docker" }
end

local function make_command(kind, opts)
  if kind == "docker" then
    return docker_command(opts)
  end
  return direct_command(opts)
end

function M.query(opts, callback)
  local order = backend_order(opts)
  local errors = {}
  local index = 1

  local function try_next()
    local kind = order[index]
    if not kind then
      callback({
        ok = false,
        backend = order[#order],
        value = nil,
        error = table.concat(errors, "\n\n"),
      })
      return
    end

    local cmd = make_command(kind, opts)
    run_command(cmd, opts.root, function(code, stdout, stderr)
      if code == 0 then
        callback({
          ok = true,
          backend = kind,
          value = trim(stdout),
          error = nil,
        })
        return
      end

      table.insert(errors, kind .. " failed: " .. trim(stderr ~= "" and stderr or stdout))
      index = index + 1
      try_next()
    end)
  end

  try_next()
end

M._shell_quote = shell_quote
M._bitbake_script = bitbake_script
M._direct_command = direct_command
M._docker_command = docker_command

return M
