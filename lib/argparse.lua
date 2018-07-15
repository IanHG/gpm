local argparse = assert(require "argparse")

local version = assert(require "lib.version")

local M = {}

local function create(description)
   -- Some general arguments
   local parser = argparse(description.script_name, description.name .. ":\n" .. description.desc)
   
   parser:option("-c --config", "Provide config file."):overwrite(false)
   parser:option("-t --token"   , "Set a stack token."):overwrite(false)
   parser:flag("--debug", "Print debug information (mostly for developers).")
   parser:flag("--quiet", "Do not print anything to stdout.")
   parser:option("--format", "Set printout format.", "fancy")
   parser:flag("-v --version", "Print '" .. version.get_version() .. "' and exit."):action(function()
      print(version.get_version())
      os.exit(0)
   end)

   return parser
end

M.create = create

return M
