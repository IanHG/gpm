#!/usr/bin/lua

local lfs = require "lfs"
local exception = require "exception"
local path = require "path"
local argparse = require "argparse"
local version = require "version"

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
-- Make a directory recursively
-------------------------------------
function mkdir_recursively(dir)
   function find_last(haystack, needle)
      local i=haystack:match(".*"..needle.."()")
      if i==nil then return nil else return i-1 end
   end
   p = dir:sub(1, find_last(dir, "/") - 1)
   if not lfs.attributes(p) then
      mkdir_recursively(p)
   end
   lfs.mkdir(dir)
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

-------------------------------------
-- Split a string
-------------------------------------
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
   package.build = build
   package.lmod = lmod
   
   -- Setup some version numbers and other needed variables
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

   -- Bootstrap prerequisite
   package.prerequisite = {}
   if #prerequisite ~= 0 then
      prereq_array = split(args.prereq, ",")
      for key, value in pairs(prerequisite) do
         found = false
         for count = 1, #prereq_array do
            p = split(prereq_array[count], "=")
            if value == p[1] then
               package.prerequisite[value] = p[2]
               found = true
               break
            end
         end
         if not found then
            error("Prequisite '" .. value .. "' not set.")
         end
      end
   end
   
   -- Setup build, install and modulefile directories
   build_directory = "build-"
   for key,prereq in pairs(package.prerequisite) do
      build_directory = build_directory .. string.gsub(prereq, "/", "-") .. "-"
   end
   build_directory = build_directory .. package.definition.pkg
   package.build_directory = path.join(config.base_build_directory, build_directory)
   
   pkginstall = path.join(config.install_directory, package.definition.pkggroup)
   if is_heirarchical(package.definition.pkggroup) then
      for key,prereq in pairs(package.prerequisite) do
         pkginstall = path.join(pkginstall, string.gsub(prereq, "/", "-"))
      end
   end
   pkginstall = path.join(path.join(pkginstall, package.definition.pkgname), package.definition.pkgversion)
   package.definition.pkginstall = pkginstall

   lmod_base = package.definition.pkggroup
   if is_heirarchical(package.definition.pkggroup) then
      nprereq = 0
      for _ in pairs(package.prerequisite) do
         nprereq = nprereq + 1
      end

      if nprereq ~= 0 then
         lmod_base = prerequisite[nprereq]
      end
   end

   package.lmod.base = lmod_base
   package.nprerequisite = nprereq
   package.lmod.modulefile_directory = path.join(config.lmod_directory, lmod_base)
   
   if is_heirarchical(package.definition.pkggroup) then
      for key,prereq in pairs(package.prerequisite) do
         package.lmod.modulefile_directory = path.join(package.lmod.modulefile_directory, prereq)
      end
   end
   
   package.lmod.modulefile_directory = path.join(package.lmod.modulefile_directory, package.definition.pkgname)
   
   -- Miscellaneous (spellcheck? :) )
   package.definition.nprocesses = config.nprocesses

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
   -- Load needed modules
   ml = ""
   for key,value in pairs(package.prerequisite) do
      ml = ml .. "ml " .. value .. " && "
   end

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
      execute_command(ml .. line)
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
   lmod_file:write(substitute_placeholders(package.definition, package.lmod.help) .. "\n")
   lmod_file:write("]])\n")
   lmod_file:write("------------------------------------------------------------------------\n")
   lmod_file:write("-- This file was generated automagically by Grendel Package Manager (GPM)\n")
   lmod_file:write("------------------------------------------------------------------------\n")
   lmod_file:write("-- Description\n")
   lmod_file:write("whatis([[\n")
   lmod_file:write(substitute_placeholders(package.definition, package.description))
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
   
   if is_heirarchical(package.definition.pkggroup) and package.nprerequisite ~= 0 then
      lmod_file:write("local prereq = string.match(fileName,\"/" .. package.lmod.base .. "/(.+/.+)/\" .. nameVersion):gsub(\"/\", \"-\")\n")
      lmod_file:write("local packageName = pathJoin(prereq, nameVersion)\n")
   else
      lmod_file:write("local packageName = nameVersion\n")
   end
   lmod_file:write("local installDir  = pathJoin(\"" .. path.join(config.install_directory, package.definition.pkggroup) .. "\", packageName)\n")
   
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
   modulefile_directory = package.lmod.modulefile_directory
   mkdir_recursively(modulefile_directory)
   lmod_filename_new = path.join(modulefile_directory, package.definition.pkgversion .. ".lua")
   print(lmod_filename_new)
   copy_file(lmod_filename, lmod_filename_new)
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
   parser:option("--prereq", "Set pre-requisites. Example --prereq='compiler=gcc/7.1.0,mpi=openmpi/2.1.1'."):overwrite(false)
   parser:option("-c --config", "Provide config file."):overwrite(false)
   parser:flag("--no-build", "Do not build package.")
   parser:flag("--no-lmod", "Do not create Lmod script.")
   parser:flag("--cleanup", "Cleanup by removing build directory after build is complete.")
   parser:flag("--debug", "Print debug information (mostly for developers).")
   parser:flag("-v --version", "Print '" .. version.get_version() .. "' and exit."):action(function()
      print(version.get_version())
      os.exit(0)
   end)

   args = parser:parse()
   if args.debug then
      dump_args(args)
   end
   
   -- Try the build
   exception.try(function() 
      -- Bootstrap build
      config = bootstrap_config(args, config)
      package = bootstrap_package(args)

      if args.debug then
         dump_args(package)
         dump_args(package.definition)
         dump_args(package.prerequisite)
         dump_args(package.lmod)
      end

      -- Create build dir
      lfs.rmdir(package.build_directory)
      lfs.mkdir(package.build_directory)
      lfs.chdir(package.build_directory)
      
      -- Do the build
      if not args.no_build then
         build_package(package)
      end

      -- Create Lmod file
      if not args.no_lmod then
         build_lmod_modulefile(package)
      end
      
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
