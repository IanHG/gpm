local lfs = assert(require "lfs")

local util       = assert(require "lib.util")
local path       = assert(require "lib.path")
local version    = assert(require "lib.version")
local install    = assert(require "lib.install")
local exception  = assert(require "lib.exception")
local configload = assert(require "lib.configload")
local database   = assert(require "lib.database")

M = {}

---
--
-- @return   Returns table with parent configs.
local function get_parent_configs(config)
   local parent_configs = nil

   if config.meta_stack.parent then
      parent_configs = {}
      print(config.meta_stack.parent)
      for _, v in pairs(util.split(config.meta_stack.parent, ",")) do
         local empty = {}
         table.insert(parent_configs, #parent_configs, configload.bootstrap(v, nil, nil, false))
      end
   end

   return parent_configs
end

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
   do_install_lmod = not global_config.meta_stack.parent
   if do_install_lmod then
      args.gpk = "lmod"
      args.pkv = global_config.lmod.version
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
   do_install_gpm = not global_config.meta_stack.parent
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
   local modulepath_root = global_config.lmod_directory
   local modulepath = ""
   for k,v in pairs(global_config.groups) do
      modulepath = modulepath .. path.join(modulepath_root, v) .. ":"
   end
   if modulepath[-1] == ":" then
      modulepath = modulepath.sub(1, -2)
   end

   return modulepath_root, modulepath
end

--- Create source file for csh/tsch environments
-- 
-- @param bin_path
-- @param source_filename
local function write_csh_source(bin_path, source_filename, parent_configs)
   -- Get modulepaths and source_path
   local modulepath_root, modulepath = create_modulepaths()
   local source_path     = path.join(bin_path, source_filename)
   local lmodsource_path = path.join(global_config.stack_path, "tools/lmod/" .. global_config.lmod.version .. "/lmod/lmod/init/csh")
   local config_path     = global_config.this_path
   
   -- Open file
   local source_file = io.open(path.join(bin_path, source_filename), "w")
   
   -- Write shebang
   source_file:write("#!/bin/csh\n")
   source_file:write("\n")
   
   -- Source parentstacks
   if parent_configs then
      source_file:write("# Source parent stacks\n")
      for _, v in pairs(parent_configs) do
         source_file:write("source " .. v.stack_path .. "/bin/" .. source_filename .. " $*\n")
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
   source_file:write("if (! $?GPMSTACKPATH) then\n")
   source_file:write("   setenv GPMSTACKPATH \"\"\n")
   source_file:write("endif\n")
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

   if parent_configs then
      source_file:write("   # Setup module paths\n")
      source_file:write("   setenv MODULEPATH_ROOT $MODULEPATH_ROOT\":" .. modulepath_root .."\"\n")
      source_file:write("   setenv MODULEPATH $MODULEPATH\":" .. modulepath .. "\"\n")
      source_file:write("\n")
      source_file:write("   # Export stack path\n")
      source_file:write("   setenv GPMSTACKPATH $GPMSTACKPATH\":" .. source_path .. "\"\n")
      source_file:write("\n")
      source_file:write("   # Export some GPM\n")
      source_file:write("   setenv GPM_CONFIG \"" .. config_path .. "\":$GPM_CONFIG\n")
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
local function write_sh_source(bin_path, source_filename, parent_configs)
   -- Get modulepaths
   local modulepath_root, modulepath = create_modulepaths()
   local source_path     = path.join(bin_path, source_filename)
   local lmodsource_path = path.join(global_config.stack_path, "tools/lmod/" .. global_config.lmod.version .. "/lmod/lmod/init/profile")
   local config_path     = global_config.this_path
   
   -- Open file for writing
   local bin_file = assert(io.open(path.join(bin_path, "modules.sh"), "w"))
   
   -- Set shebang
   bin_file:write("#!/bin/sh\n")
   bin_file:write("\n")
   
   -- Source parent stacks
   if parent_configs then
      bin_file:write("# Source parent stacks\n")
      for _, v in pairs(parent_configs) do
         bin_file:write(". " .. v.stack_path .. "/bin/" .. source_filename .. " \"$@\"\n")
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
   
   if parent_configs then
      bin_file:write("\n")
      bin_file:write("   # Setup module paths\n")
      bin_file:write("   export MODULEPATH_ROOT=$MODULEPATH_ROOT:\"" .. modulepath_root .. "\"\n")
      bin_file:write("   export MODULEPATH=$MODULEPATH:\"" .. modulepath .. "\"\n")
      bin_file:write("\n")
      bin_file:write("   # Export stack path\n")
      bin_file:write("   export GPMSTACKPATH=\"$GPMSTACKPATH:" .. source_path .. "\"\n")
      bin_file:write("\n")
      bin_file:write("   # Export some GPM\n")
      bin_file:write("   export GPM_CONFIG=\"" .. config_path .. "\":$GPM_CONFIG\n")
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
      bin_file:write("   # Export some GPM\n")
      bin_file:write("   export GPM_CONFIG=\"" .. config_path .. "\"\n")
      bin_file:write("\n")
   end

   
   bin_file:write("else\n")
   bin_file:write("   if [ \"$SILENT\" = \"0\" ]; then\n")
   bin_file:write("      echo \"NOT sourcing " .. source_path .. "\"\n")
   bin_file:write("   fi\n")
   bin_file:write("fi\n")

   bin_file:close()
end

--- Create shell enviroment sourcing scripts.
-- 
-- @param parents
local function create_shell_environment(parent_configs)
   --
   local bin_path = path.join(global_config.stack_path, "bin")
   lfs.mkdir(bin_path)
   
   -- Write files for each shell type
   write_sh_source (bin_path, "modules.sh" , parent_configs)
   write_csh_source(bin_path, "modules.csh", parent_configs)
end

local function register_in_parents(parent_configs)
   for _, v in pairs(parent_configs) do
      local db_path = v.stack_path .. "/" .. v.db.path .. ".childstack"
      local db_file = assert(io.open(db_path, "a"))

      db_file:write(database.create_db_line({ config = global_config.this_path }))

      db_file:close()
   end
end

-------------------------------------
-- Function for initialized software tree
--
-- @param args
-------------------------------------
local function initialize(args)
   -- Try
   exception.try(function() 
      -- Create a build directory
      if not lfs.attributes(global_config.base_build_directory) then
         lfs.mkdir(global_config.base_build_directory)
      end

      -- Check that required luapackages exist
      --check_luapackages(args)
      local parent_configs = get_parent_configs(global_config)
      
      -- Install lmod if needed
      install_lmod(args)
         
      print("CREATE SHELL")
      -- Create shell file to source new software tree
      create_shell_environment(parent_configs)

      if ((global_config.meta_stack.parent) and (global_config.meta_stack.register)) then
         register_in_parents(parent_configs)
      end

      -- Create directories
      if not lfs.attributes(global_config.lmod_directory) then
         lfs.mkdir(global_config.lmod_directory)
      end
      
      for k,v in pairs(global_config.groups) do
         lfs.mkdir(path.join(global_config.stack_path, v))
         lfs.mkdir(path.join(global_config.lmod_directory, v))
      end

      -- Create module file for gpm
      install_gpm(args)
      
   end, function (e)
      exception.message(e)
   end)
end

M.initialize = initialize

return M
