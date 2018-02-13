local lfs = require "lfs"

local util      = require "lib.util"
local path      = require "lib.path"
local version   = require "lib.version"
local install   = require "lib.install"
local exception = require "lib.exception"

M = {}

-------------------------------------
-- Install luarocks package manager
-------------------------------------
local function install_luarocks(args)
   args.gpk = "luarocks"
   args.pkv = "2.4.1"
   args.nomodulesource = true
   args.is_lmod = false
   args.no_lmod = false

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
      args.pkv = "7.7.13"
      args.nomodulesource = true
      args.is_lmod = true
      args.no_lmod = true
      
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
      args.is_lmod = false
      args.no_lmod = false

      install.install(args)
   end
end

--- Create modulepaths and return these.
--
-- @return{string,string}   Returns modulepath_root and modulepath strings.
local function create_modulepaths()
   local modulepath_root = config.lmod_directory
   local modulepath = ""
   for k,v in pairs(config.groups) do
      modulepath = modulepath .. path.join(modulepath_root, v) .. ":"
   end
   if modulepath[-1] == ":" then
      modulepath = modulepath.sub(1, -2)
   end

   return modulepath_root, modulepath
end

--- Create source file for csh/tsch environments
-- 
-- @param args
-- @param bin_path
-- @param source_filename
local function write_csh_source(args, bin_path, source_filename)
   -- Get modulepaths and source_path
   local modulepath_root, modulepath = create_modulepaths()
   local source_path     = path.join(bin_path, source_filename)
   local lmodsource_path = path.join(config.stack_path, "tools/lmod/7.7.13/lmod/lmod/init/csh")
   local config_path     = path.join(config.stack_path, args.config)
   
   -- Open file
   local source_file = io.open(path.join(bin_path, source_filename), "w")
   
   -- Write shebang
   source_file:write("#!/bin/csh\n")
   source_file:write("\n")
   
   -- Source parentstacks
   if args.parentstack then
      local parentstack_split = util.split(args.parentstack, ",")
      source_file:write("# Source parent stacks\n")
      for k,v in pairs(parentstack_split) do
         source_file:write("source " .. v .. source_filename .. " $*\n")
      end
      source_file:write("\n")
   end
   
   -- Setup input parsing
   source_file:write("## Usage function\n")
   source_file:write("alias usage 'echo \"Use me correctly please :) (and btw change to bash!).\";'\n")
   source_file:write("\n")
   source_file:write("# Parameters\n")
   source_file:write("set SILENT=0\n")
   source_file:write("set FORCE=0\n")
   source_file:write("set GPM_USE_LD_RUN_PATH=1\n")
   source_file:write("\n")
   source_file:write("# Process command line\n")
   source_file:write("while ( $#argv != 0 )\n")
   source_file:write("   switch ( $argv[1] )\n")
   source_file:write("      case \"--force\":\n")
   source_file:write("         set FORCE=1;\n")
   source_file:write("         breaksw\n")
   source_file:write("      case \"--silent\":\n")
   source_file:write("         set SILENT=1;\n")
   source_file:write("         breaksw\n")
   source_file:write("      case \"--link-relative\":\n")
   source_file:write("         set GPM_USE_LD_RUN_PATH=1\n")
   source_file:write("         breaksw\n")
   source_file:write("      case \"--help\":\n")
   source_file:write("         usage;\n")
   source_file:write("         exit 0\n")
   source_file:write("         breaksw\n")
   source_file:write("      default:\n")
   source_file:write("         usage;\n")
   source_file:write("         exit 1\n")
   source_file:write("         breaksw\n")
   source_file:write("   endsw\n")
   source_file:write("   shift\n")
   source_file:write("end\n")
   source_file:write("\n")

   -- Check if we should source
   source_file:write("# Check if this file should be sourced\n")
   source_file:write("set SOURCEME=1\n")
   source_file:write("set delimiter = ':'\n")
   source_file:write("foreach gpmpath ($GPMSTACKPATH)\n")
   source_file:write("   if ($gpmpath == \"" .. source_path .. "\") then\n")
   source_file:write("      set SOURCEME=0\n")
   source_file:write("   endif\n")
   source_file:write("end\n")
   source_file:write("\n")

   -- Do the actual source 
   source_file:write("# Source\n")
   source_file:write("if (($SOURCEME == 1) || ($FORCE == 1)) then\n")
   source_file:write("   if ($SILENT == 0) then\n")
   source_file:write("      echo \"Sourcing" .. source_path .. "\"\n")
   source_file:write("   endif\n")
   source_file:write("\n")

   if args.parentstack then
      source_file:write("   # Setup module paths\n")
      source_file:write("   setenv MODULEPATH_ROOT $MODULEPATH_ROOT\":" .. modulepath_root .."\"\n")
      source_file:write("   setenv MODULEPATH $MODULEPATH\":" .. modulepath .. "\"\n")
      source_file:write("\n")
      source_file:write("   # Export stack path\n")
      source_file:write("   setenv GPMSTACKPATH $GPMSTACKPATH\":" .. source_path .. "\"\n")
   else
      source_file:write("   # Unset paths\n")
      source_file:write("   unset MODULEPATH_ROOT\n")
      source_file:write("   unset MODULEPATH\n")
      source_file:write("   unset GPMSTACKPATH\n")
      source_file:write("   unset MANPATH\n")
      source_file:write("\n")
      source_file:write("   # Setup module paths\n")
      source_file:write("   setenv MODULEPATH_ROOT \"" .. modulepath_root .."\"\n")
      source_file:write("   setenv MODULEPATH \"" .. modulepath .. "\"\n")
      source_file:write("   setenv MANPATH manpath\n")
      source_file:write("\n")
      source_file:write("   # Source lmod \n")
      source_file:write("   source " .. lmodsource_path .. "\n")
      source_file:write("\n")
      source_file:write("   # Export stack path\n")
      source_file:write("   setenv GPMSTACKPATH \"" .. source_path .. "\"\n")
      source_file:write("\n")
      source_file:write("   # Export stack path\n")
      source_file:write("   setenv GPM_USE_LD_RUN_PATH \n")
      source_file:write("\n")
      source_file:write("   # Export some GPM\n")
      source_file:write("   setenv GPM_CONFIG \"" .. config_path .. "\"\n")
   end

   source_file:write("else\n")
   source_file:write("   if ($SILENT == 0) then\n")
   source_file:write("      echo \"NOT sourcing " .. source_path .. "\"\n")
   source_file:write("   endif\n")
   source_file:write("endif\n")
   
   -- Close source file
   source_file:close()
end

-------------------------------------
-- Create shell environtment file
-------------------------------------
local function write_sh_source(args, bin_path, source_filename)
   -- Get modulepaths
   local modulepath_root, modulepath = create_modulepaths()
   local source_path     = path.join(bin_path, source_filename)
   local lmodsource_path = path.join(config.stack_path, "tools/lmod/7.7.13/lmod/lmod/init/profile")
   local config_path     = path.join(config.stack_path, args.config)
   
   -- Open file for writing
   local bin_file = io.open(path.join(bin_path, "modules.sh"), "w")
   
   -- Set shebang
   bin_file:write("#!/bin/sh\n")
   bin_file:write("\n")
   
   -- Source parent stacks
   if args.parentstack then
      local parentstack_split = util.split(args.parentstack, ",")
      bin_file:write("# Source parent stacks\n")
      for k,v in pairs(parentstack_split) do
         bin_file:write(". " .. v .. source_filename .. " \"$@\"\n")
      end
      bin_file:write("\n")
   end

   -- Setup input reader
   bin_file:write("# Usage function\n")
   bin_file:write("usage() {\n")
   bin_file:write("   echo \"Use me correctly please :)\"\n")
   bin_file:write("}\n")
   bin_file:write("\n")
   bin_file:write("# Parameters\n")
   bin_file:write("SILENT=0\n")
   bin_file:write("FORCE=0\n")
   bin_file:write("GPM_USE_LD_RUN_PATH=1\n")
   bin_file:write("\n")
   bin_file:write("# Process command line\n")
   bin_file:write("while [ \"$1\" != \"\" ]; do\n")
   bin_file:write("   case $1 in\n")
   bin_file:write("      --force)\n")
   bin_file:write("         FORCE=1\n")
   bin_file:write("         ;;\n")
   bin_file:write("      --silent)\n")
   bin_file:write("         SILENT=1\n")
   bin_file:write("         ;;\n")
   bin_file:write("      --link-relative)\n")
   bin_file:write("         GPM_USE_LD_RUN_PATH=0\n")
   bin_file:write("         ;;\n")
   bin_file:write("      -h | --help )\n")
   bin_file:write("         usage\n")
   bin_file:write("         return 1\n")
   bin_file:write("         ;;\n")
   bin_file:write("      * )\n")
   bin_file:write("         usage\n")
   bin_file:write("         return 1\n")
   bin_file:write("   esac\n")
   bin_file:write("   shift\n")
   bin_file:write("done\n")
   bin_file:write("\n")

   -- Do some setup
   bin_file:write("# Check if this file should be sourced\n")
   bin_file:write("SOURCEME=$(\n")
   bin_file:write("   SOURCEME=1\n")
   bin_file:write("   IFS=:\n")
   bin_file:write("   for path in $GPMSTACKPATH; do\n")
   bin_file:write("      if [ \"$path\" = \"" .. source_path .. "\" ]; then\n")
   bin_file:write("         SOURCEME=0\n")
   bin_file:write("      fi\n")
   bin_file:write("   done\n")
   bin_file:write("   echo $SOURCEME\n")
   bin_file:write(")\n")
   bin_file:write("\n")

   -- Setup sourcing code
   bin_file:write("# Source\n")
   bin_file:write("if [ \"$SOURCEME\" = \"1\" ] || [ \"$FORCE\" = \"1\" ]; then\n")
   bin_file:write("   if [ \"$SILENT\" = \"0\" ]; then\n")
   bin_file:write("      echo \"Sourcing " .. source_path .. "\"\n")
   bin_file:write("   fi\n")
   
   if args.parentstack then
      bin_file:write("\n")
      bin_file:write("   # Setup module paths\n")
      bin_file:write("   export MODULEPATH_ROOT=$MODULEPATH_ROOT:\"" .. modulepath_root .. "\"\n")
      bin_file:write("   export MODULEPATH=$MODULEPATH:\"" .. modulepath .. "\"\n")
      bin_file:write("\n")
      bin_file:write("   # Export stack path\n")
      bin_file:write("   export GPMSTACKPATH=\"$GPMSTACKPATH:" .. source_path .. "\"\n")
      bin_file:write("\n")
   else
      bin_file:write("   # Unset paths\n")
      bin_file:write("   unset MODULEPATH_ROOT\n")
      bin_file:write("   unset MODULEPATH\n")
      bin_file:write("   unset MANPATH\n")
      bin_file:write("   unset GPMSTACKPATH\n")
      bin_file:write("\n")
      bin_file:write("   # Setup module paths\n")
      bin_file:write("   export MODULEPATH_ROOT=\"" .. modulepath_root .. "\"\n")
      bin_file:write("   export MODULEPATH=\"" .. modulepath .. "\"\n")
      bin_file:write("   export MANPATH=$(manpath)");
      bin_file:write("\n")
      bin_file:write("   # Source lmod \n")
      bin_file:write("  . ".. lmodsource_path .. "\n")
      bin_file:write("\n")
      bin_file:write("   # Export stack path\n")
      bin_file:write("   export GPMSTACKPATH=\"" .. source_path .. "\"\n")
      bin_file:write("\n")
      bin_file:write("   # Export stack path\n")
      bin_file:write("   export GPM_USE_LD_RUN_PATH\n")
      bin_file:write("\n")
   end

   bin_file:write("   # Export some GPM\n")
   bin_file:write("   export GPM_CONFIG=\"" .. config_path .. "\"\n")
   
   bin_file:write("else\n")
   bin_file:write("   if [ \"$SILENT\" = \"0\" ]; then\n")
   bin_file:write("      echo \"NOT sourcing " .. source_path .. "\"\n")
   bin_file:write("   fi\n")
   bin_file:write("fi\n")

   bin_file:close()
end

--- Create shell enviroment sourcing scripts.
-- 
-- @param args
local function create_shell_environment(args)
   --
   local bin_path = path.join(config.stack_path, "bin")
   lfs.mkdir(bin_path)
   
   -- Write files for each shell type
   write_sh_source (args, bin_path, "modules.sh")
   write_csh_source(args, bin_path, "modules.csh")
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
         lfs.mkdir(path.join(config.stack_path, v))
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
