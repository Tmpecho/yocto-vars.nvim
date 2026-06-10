package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local backend = require("yocto_vars.backend")

local function eq(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %q, got %q", label, expected, actual), 2)
  end
end

local env = backend._docker_env({ docker = {} })
eq(env.SSH_AUTH_SOCK, "", "docker env clears SSH_AUTH_SOCK")

local custom_env = backend._docker_env({ docker = { env = { FOO = "bar" }, clear_ssh_auth_sock = false } })
eq(custom_env.FOO, "bar", "docker env preserves custom entries")
eq(custom_env.SSH_AUTH_SOCK, nil, "docker env can keep SSH_AUTH_SOCK unset")

local order = backend._backend_order({ backend = "auto", docker = {} })
if vim.loop.os_uname().sysname == "Darwin" then
  eq(order[1], "docker", "macOS auto starts with docker")
  eq(order[2], nil, "macOS auto does not fall back to direct")

  local fallback = backend._backend_order({ backend = "auto", docker = { fallback_to_direct = true } })
  eq(fallback[1], "docker", "macOS fallback starts with docker")
  eq(fallback[2], "direct", "macOS fallback can include direct")
end

print("backend_spec.lua: ok")
