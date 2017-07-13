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
      package.definition = definition
      package.prequisites = prerequisites
      package.build = build
      package.lmod = lmod
   else
      error("Error loading package. Reason : '" .. msg .. "'.")
   end

   package.definition.pkgversion = args.pkv
   package.definition.pkg = package.definition.pkgname .. "-" .. package.definition.pkgversion
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
-- @param build
--
-- @return{Boolean}
-------------------------------------
function build_package(package)
   exception.try(function()
         -- try block
         build_directory = path.join(config.base_build_directory, "build-" .. package.definition.pkg)
         package_directory = path.join(build_directory, package.definition.pkg)

         lfs.rmdir(build_directory)
         lfs.mkdir(build_directory)

         -- Download package
         lfs.chdir(build_directory)
         for line in string.gmatch(package.build.source, ".*$") do
            line = substitute_placeholders(package.definition, line)
            execute_command(line)
         end
         
         -- Build package
         lfs.chdir(package_directory)
         for line in string.gmatch(package.build.command, ".*$") do
            line = substitute_placeholders(package.definition, line)
            execute_command(line)
         end
      end, function(e)
         -- catch block
         print ("exeption caught : " .. e)
         print ("but i cannot print here :CC")
         lfs.chdir(config.current_directory)
         status = lfs.rmdir(build_directory)
         if not status then
            print("did not rm dir :C")
         end
      end)
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
   parser:flag("-v --version", "Print '" .. get_version() .. "' and exit."):action(function()
      print(get_version())
      os.exit(0)
   end)

   args = parser:parse()
   dump_args(args)
   
   -- Bootstrap build
   exception.try(function() 
      config = bootstrap_config(args, config)
      package = bootstrap_package(args)
   end, function(e)
      exception.message(e)
      print("\n" .. parser:get_usage())
   end)
   
   -- Do the build
   build_package(package)
end

-- Run main driver.
main()
