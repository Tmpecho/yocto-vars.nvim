# yocto-vars.nvim

Small Neovim helper for inspecting expanded BitBake variables from Yocto recipes.

The plugin asks BitBake for the real value through `bitbake-getvar`; it does not try to parse `.bb`, `.bbappend`, or `.conf` files itself. This matters for variables such as `WORKDIR`, `D`, `S`, `B`, and `PN`, where the final value depends on recipe context, overrides, inherited classes, and the active build configuration.

## Features

- `:YoctoVar` expands the variable under the cursor.
- `:YoctoVar WORKDIR` expands a named variable for the current recipe.
- `:YoctoVarRecipe bozios-fake-gps WORKDIR` expands a variable for an explicit recipe.
- Filetype-local `K` popup for BitBake files, enabled by default.
- Scoped filetype detection for `.bb`, `.bbappend`, and Yocto-looking `.inc` files.
- Direct backend for Linux/container development.
- Docker Compose backend for macOS host editing or container-first workflows.

## Install With AstroNvim

While developing from a local checkout:

```lua
-- ~/.config/nvim/lua/plugins/yocto-vars.lua
return {
  {
    dir = "/path/to/yocto-vars.nvim",
    config = function(_, opts)
      require("yocto_vars").setup(opts)
    end,
    opts = {
      backend = "auto",
      build_dir = "build",
      docker = {
        service = "yocto-mac",
      },
    },
  },
}
```

After publishing it to GitHub:

```lua
return {
  {
    "your-user/yocto-vars.nvim",
    config = function(_, opts)
      require("yocto_vars").setup(opts)
    end,
    opts = {
      backend = "auto",
      build_dir = "build",
    },
  },
}
```

## Configuration

```lua
require("yocto_vars").setup({
  backend = "auto", -- "auto", "direct", or "docker"
  build_dir = "build",
  docker = {
    service = nil, -- defaults to yocto-mac on macOS, yocto-linux elsewhere
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
})
```

`backend = "auto"` prefers Docker first on macOS and direct execution first elsewhere. Direct execution runs:

```sh
source ./init-build-env build >/dev/null && bitbake-getvar -q --value -r <recipe> <variable>
```

Docker execution runs the same command inside the configured Compose service:

```sh
docker compose run --rm -T <service> -lc 'source ./init-build-env build >/dev/null && bitbake-getvar -q --value -r <recipe> <variable>'
```

## Recipe Detection

For `.bb` and `.bbappend` files, the plugin infers the recipe from the filename:

- `bozios-fake-gps.bb` -> `bozios-fake-gps`
- `foo_1.2.3.bb` -> `foo`
- `plymouth_%.bbappend` -> `plymouth`

For ambiguous files, especially shared `.inc` files, use:

```vim
:YoctoVarRecipe <recipe> <variable>
```

## Notes

- The plugin expects to be run from a Yocto workspace with `init-build-env` at the project root by default.
- The active build configuration comes from the selected build directory.
- On macOS, use the Docker backend when the Yocto project depends on Linux-oriented build tools.
