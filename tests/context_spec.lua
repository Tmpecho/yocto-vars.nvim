package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local context = require("yocto_vars.context")

local function eq(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %q, got %q", label, expected, actual), 2)
  end
end

eq(context.infer_recipe_from_path("recipes-navigation/bozios-fake-gps/bozios-fake-gps.bb"), "bozios-fake-gps", "plain recipe")
eq(context.infer_recipe_from_path("recipes-core/plymouth/plymouth_%.bbappend"), "plymouth", "wildcard append")
eq(context.infer_recipe_from_path("recipes/foo/foo_1.2.3.bb"), "foo", "versioned recipe")
eq(context.infer_recipe_from_path("recipes/foo/foo.inc"), nil, "include has no recipe")

eq(context.extract_variable_at("S = \"${WORKDIR}/git\"", 8), "WORKDIR", "braced variable")
eq(context.extract_variable_at("install -m 0644 ${D}${systemd_system_unitdir}", 19), "D", "single-letter braced variable")
eq(context.extract_variable_at("RDEPENDS:${PN} += \"foo\"", 2), "RDEPENDS", "override expression base variable")
eq(context.extract_variable_at("PN = \"foo\"", 1), "PN", "bare variable")

print("context_spec.lua: ok")
