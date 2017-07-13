#!/usr/bin/lua

local lfs = require "lfs"
local exception = require "exception"
local path = require "path"
local argparse = require "argparse"

-- Define version number
version = {  
   major = 1,
   minor = 0,
   patch = 0,
}

-- Description of this script
description = {
   script_name = "build-package.lua",
   name = "Grendel Package Manager 2000 (GPM2K), or just GPM for short :)",
   desc = "Grendels own easybuilder, yay!",
}

-- Set config defaults
config = {  
   current_directory = lfs.currentdir(),  
   gpk_directory = lfs.currentdir() .. "/gpk",
   base_build_directory = "/tmp/",
   nprocesses = 20,
   lmod_directory = "/comm/modulefiles",
   heirarchical = {},
}

-------------------------------------
-- Get version number.
--
-- @return{String} Version number.
-------------------------------------
function get_version_number()
   return version.major .. "." .. version.minor .. "." .. version.patch
end

-------------------------------------
-- Get name and version of program.
--
-- @return{String} Name and version.
-------------------------------------
function get_version()
   return description.name .. " Vers. " .. get_version_number()
end

-------------------------------------
-- Is pkgtype a hierarchical one?
--
-- @param{String} pkgtype
--
-- @param{Boolean} 
-------------------------------------
function is_heirarchical(pkgtype)
   for key,value in pairs(config.heirarchical) do
      if pkgtype == value then
         return true
      end
   end
   return false
end

-------------------------------------
-- Dump args to stdout.
--
-- @param{Dictionary} args The argument dictionary to print.
-------------------------------------
function dump_args(args)
   for key,value in pairs(args) do
      print(key .. " = " .. tostring(value))
   end
end

-------------------------------------
-- Copy a file
-------------------------------------
function copy_file(src, dest)
   infile = io.open(src, "r")
   instr = infile:read("*a")
   infile:close()

   outfile = io.open(dest, "w")
   outfile:write(instr)
   outfile:close()
end

function split(inputstr, sep)
   if sep == nil then
      sep = "%s"
   end
   local t={} ; i=1
   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      t[i] = str
      i = i + 1
   end
   return t
end


-------------------------------------
-- Read GPM package file (GPK).
--
-- @return{Dictionary} Returns definition og build.
-------------------------------------
function bootstrap_config(args, default_config)
   assert(loadfile(args.config))()
   for key,value in pairs(config) do
      default_config[key] = value
   end
   return default_config
end

-------------------------------------
-- Read GPM package file (GPK).
--
-- @return{Dictionary} Returns definition og build.
-------------------------------------
function bootstrap_package(args)
   package = {}
   
   -- Load package file
   if args.gpk then
      filename = args.gpk .. ".gpk"
      filepath = path.join(config.gpk_directory, filename)
   elseif args.gpkf then
      filepath = args.gpkf
   else
      error("Must provide either -gpk or -gpkf option.")
   end
   
   local f, msg = loadfile(filepath)
   if f then
      f()
   else
      error("Error loading package. Reason : '" .. msg .. "'.")
   end
   
   package.description = description
   package.definition = definition
   package.prequisites = prerequisites
   package.build = build
   package.lmod = lmod
   
   package.definition.pkgversion = args.pkv
   version_array = split(args.pkv, ".")
   if version_array[1] then
      package.definition.pkgmajor = version_array[1]
   end
   if version_array[2] then
      package.definition.pkgminor = version_array[2]
   end
   if version_array[3] then
      package.definition.pkgrevision = version_array[3]
   end
   package.definition.pkg = package.definition.pkgname .. "-" .. package.definition.pkgversion
   
   pkginstall = path.join(config.install_directory, package.definition.pkggroup)
   --[[
   if is_heirarchical(package.definition.pkggroup) then
      for key,prereq in pairs(package.prerequisite) do
         pkginstall = path.join(pkginstall, args.prerequisite[prereq])
      end
   end
   --]]
   pkginstall = path.join(path.join(pkginstall, package.definition.pkgname), package.definition.pkgversion)
   package.definition.pkginstall = pkginstall
   
   package.definition.nprocesses = config.nprocesses

   package.build_directory = path.join(config.base_build_directory, "build-" .. package.definition.pkg)

   return package
end

-------------------------------------
-- Get name and version of program.
--
-- @return{String} Name and version.
-------------------------------------
function substitute_placeholders(definition, line)
   for key,value in pairs(definition) do
      line = string.gsub(line, "<" .. key .. ">", value)
   end
   return line
end

-------------------------------------
-- Run command in shell.
--
-- @param command
--
-- @return{Boolean}
-------------------------------------
function execute_command(command)
   bool, flag, status = os.execute(command)

   if not bool then
      error("Command '" .. command .. "' exited with errors.")
   end
end

-------------------------------------
-- Build the package.
--
-- @param package
-------------------------------------
function build_package(package)
   -- Download package
   for line in string.gmatch(package.build.source, ".*$") do
      line = substitute_placeholders(package.definition, line)
      execute_command(line)
   end
   
   -- Build package
   package_directory = path.join(package.build_directory, package.definition.pkg)
   lfs.chdir(package_directory)
   for line in string.gmatch(package.build.command, ".*$") do
      line = substitute_placeholders(package.definition, line)
      execute_command(line)
   end
end

-------------------------------------
-- Generate Lmod script.
--
-- @param package
--
-- @return{Boolean}
-------------------------------------
function build_lmod_modulefile(package)
   lmod_filename = path.join(package.build_directory, package.definition.pkgversion .. ".lua")
   lmod_file = io.open(lmod_filename, "w")

   lmod_file:write("-- -*- lua -*-\n")
   lmod_file:write("help(\n")
   lmod_file:write("[[\n")
   lmod_file:write(substitute_placeholders(package.lmod.help, package.definition) .. "\n")
   lmod_file:write("]])\n")
   lmod_file:write("------------------------------------------------------------------------\n")
   lmod_file:write("-- This file was generated automagically by Grendel Package Manager (GPM)\n")
   lmod_file:write("------------------------------------------------------------------------\n")
   lmod_file:write("-- Description\n")
   lmod_file:write("whatis([[\n")
   lmod_file:write(substitute_placeholders(package.description, package.definition))
   lmod_file:write("]])\n")
   lmod_file:write("\n")
   lmod_file:write("-- Set family\n")
   lmod_file:write("local fam = \"" .. package.definition.pkgfamily .. "\"\n")
   lmod_file:write("family(fam)\n")
   lmod_file:write("\n")
   lmod_file:write("-- Basic module setup\n")
   lmod_file:write("local version     = myModuleVersion()\n")
   lmod_file:write("local name        = myModuleName()\n")
   lmod_file:write("local fileName    = myFileName()\n")
   lmod_file:write("local nameVersion = pathJoin(name, version)\n")
   lmod_file:write("local installDir  = pathJoin(os.getenv(\"GRENDEL_COMM_CORE_PATH\"), nameVersion)\n")
   lmod_file:write("\n")
   lmod_file:write("-- Compiler optional modules setup\n")
   lmod_file:write("local dir = pathJoin(fam, nameVersion)\n")
   lmod_file:write("prepend_path('MODULEPATH', pathJoin(os.getenv(\"MODULEPATH_ROOT\"), dir))\n")
   lmod_file:write("\n")
   
   lmod_file:write("-- Package specific\n")
   
   -- Do all setenv
   if package.lmod.setenv then
      for key,value in pairs(package.lmod.setenv) do
         lmod_file:write("setenv('" .. value[1] .. "', pathJoin(installDir, '" .. value[2] .. "'))\n")
      end
   end
   
   -- Do all prepend_path
   if package.lmod.prepend_path then
      for key,value in pairs(package.lmod.prepend_path) do
         lmod_file:write("prepend_path('" .. value[1] .. "', pathJoin(installDir, '" .. value[2] .. "'))\n")
      end
   end

   -- Close file after wirting it
   lmod_file:close()

   -- Put the file in the correct place
   if false then
   else
      modulefile_directory = path.join(path.join(config.lmod_directory, package.definition.pkggroup), package.definition.pkgname)
      lmod_filename_new = path.join(modulefile_directory, package.definition.pkgversion .. ".lua")
      copy_file(lmod_filename, lmod_filename_new)
   end
end


-------------------------------------
-- Main driver.
-------------------------------------
function main()
   -- Arg parser
   local parser = argparse(description.script_name, description.name .. ":\n" .. description.desc)
   --parser:argument("input", "Input file.")
   parser:mutex(
      parser:option("--gpk" , "GPM Package (GPK) to install (will look for .gpk file)."):overwrite(false),
      parser:option("--gpkf", "GPM Package (GPK) file to install."):overwrite(false)
   )
   parser:option("--pkv", "Set Package Version (PKV) of the package to install."):overwrite(false)
   parser:option("-c --config", "Provide config file."):overwrite(false)
   parser:flag("--nobuild", "Do not build package, only create Lmod script.")
   parser:flag("--cleanup", "Cleanup by removing build directory after build is complete.")
   parser:flag("-v --version", "Print '" .. get_version() .. "' and exit."):action(function()
      print(get_version())
      os.exit(0)
   end)

   args = parser:parse()
   dump_args(args)
   
   -- Try the build
   exception.try(function() 
      -- Bootstrap build
      config = bootstrap_config(args, config)
      package = bootstrap_package(args)

      -- Create build dir
      lfs.rmdir(package.build_directory)
      lfs.mkdir(package.build_directory)
      lfs.chdir(package.build_directory)
      
      -- Do the build
      if not args.nobuild then
         build_package(package)
      end

      -- Create Lmod file
      build_lmod_modulefile(package)
      
      -- Change back to calling dir
      lfs.chdir(config.current_directory)
      
      -- Remove build dir
      if args.cleanup then
         status, msg = lfs.rmdir(build_directory)
         print("Did not remove build directory. Reason : '" .. msg .. "'.") 
      end
   end, function(e)
      exception.message(e)
      --[[
      status, msg = lfs.rmdir(build_directory)
      if not status then
         print("did not rm dir :C")
      end
      --]]
      print("\n" .. parser:get_usage())
   end)
   
end

-- Run main driver.
main()
