local lfs = require "lfs"

local util = require "util"
local path = require "path"
local version = require "version"
local install = require "install"

M = {}

-------------------------------------
-- Install luarocks package manager
-------------------------------------
local function install_luarocks(args)
   args.gpk = "luarocks"
   args.pkv = "2.4.1"
   args.nomodulesource = true

   install.install(args)
end

-------------------------------------
-- 
-------------------------------------
local function install_luapackages(args, packages_to_install)
   install_luarocks(args)

   for _,v in pairs(packages_to_install) do
      print(v)
   end
end

-------------------------------------
-- 
-------------------------------------
local function check_luapackages(args)
   packages_to_install = {}
   -- Try posix (needed for Lmod)
   exception.try(function()
      local posix = require "posix"
   end, function(e)
      packages_to_install[#packages_to_install + 1] = "luaposix"
   end)
   
   -- Install needed packages
   if #packages_to_install then
      install_luapackages(args, packages_to_install)
   end
end

-------------------------------------
-- Install lmod
-------------------------------------
local function install_lmod(args)
   do_install_lmod = not args.parentstack
   if do_install_lmod then
      args.gpk = "lmod"
      args.pkv = "7.5.11"
      args.nomodulesource = true
      
      install.install(args)
   end
end

-------------------------------------
-- Install gpm
-------------------------------------
local function install_gpm(args)
   do_install_gpm = not args.parentstack
   if do_install_gpm then
      args.gpk = "gpm"
      args.pkv = version.get_version_number()
      args.no_build = true
      args.nomodulesource = false

      install.install(args)
   end
end

-------------------------------------
-- Create shell environtment file
-------------------------------------
local function create_shell_environment(args)
   bin_dir = path.join(config.install_directory, "bin")
   lfs.mkdir(bin_dir)
   bin_file = io.open(path.join(bin_dir, "modules.sh"), "w")

   modulepath_root = config.lmod_directory
   modulepath = ""
   for k,v in pairs(config.groups) do
      modulepath = modulepath .. path.join(modulepath_root, v) .. ":"
   end
   if modulepath[-1] == ":" then
      modulepath = modulepath.sub(1, -2)
   end
   
   if args.parentstack then
      parentstack_split = util.split(args.parentstack, ",")
      bin_file:write("# Source parent stacks\n")
      for k,v in pairs(parentstack_split) do
         bin_file:write(". " .. v .. "\n")
      end
      bin_file:write("\n")
      bin_file:write("# Setup module paths\n")
      bin_file:write("export MODULEPATH_ROOT=$MODULEPATH_ROOT:\"" .. modulepath_root .. "\"\n")
      bin_file:write("export MODULEPATH=$MODULEPATH:\"" .. modulepath .. "\"\n")
   else
      bin_file:write("#\n")
      bin_file:write("unset MODULEPATH_ROOT\n")
      bin_file:write("unset MODULEPATH\n")
      bin_file:write("\n")
      bin_file:write("# Setup module paths\n")
      bin_file:write("export MODULEPATH_ROOT=\"" .. modulepath_root .. "\"\n")
      bin_file:write("export MODULEPATH=\"" .. modulepath .. "\"\n")
      bin_file:write("\n")
      bin_file:write("# Source lmod \n")
      bin_file:write(". ".. path.join(config.install_directory, "lmod/lmod/init/profile") .. "\n")
   end

   bin_file:write("\n")
   bin_file:write("#Export config path\n")
   bin_file:write("export GPM_CONFIG=\"" .. path.join(config.install_directory, args.config) .. "\"\n")

   bin_file:close()
end

-------------------------------------
-- Function for initialized software tree
--
-- @param args
-------------------------------------
local function initialize(args)
   -- Try
   exception.try(function() 
      -- Bootstrap initialize
      -- config = bootstrap_initialize(args)
      
      -- Create a build directory
      if not lfs.attributes(config.base_build_directory) then
         lfs.mkdir(config.base_build_directory)
      end

      -- Check that required luapackages exist
      --check_luapackages(args)
      
      -- Install lmod if needed
      install_lmod(args)
      
      -- Create shell file to source new software tree
      create_shell_environment(args)

      -- Create directories
      if not lfs.attributes(config.lmod_directory) then
         lfs.mkdir(config.lmod_directory)
      end
      
      for k,v in pairs(config.groups) do
         lfs.mkdir(path.join(config.install_directory, v))
         lfs.mkdir(path.join(config.lmod_directory, v))
      end

      -- Create module file for gpm
      install_gpm(args)
      
   end, function (e)
      exception.message(e)
   end)
end

M.initialize = initialize

return M
