#!/usr/bin/lua

local lfs = require "lfs"
local argparse = require "argparse"
local exception = require "exception"
local version = require "version"

-- Description of this script
description = {
   script_name = "build-stack.lua",
   name = "Grendel Package Manager 2000 (GPM2K), or just GPM for short :)",
   desc = "Grendels own easybuilder, yay!",
}

-- Default config
config = {
   gps_directory = lfs.currentdir(),
}

-------------------------------------
-- 
-------------------------------------
function bootstrap_stack(args)
   -- Load package file
   if args.gps then
      filename = args.gps .. ".gps"
      filepath = path.join(config.gps_directory, filename)
   elseif args.gpsf then
      filepath = args.gpsf
   else
      error("Must provide either -gps or -gpsf option.")
   end
   
   local f, msg = loadfile(filepath)
   if f then
      f()
   else
      error("Error loading package. Reason : '" .. msg .. "'.")
   end

   return stack
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
-- Main driver.
-------------------------------------
function main()
   -- Arg parser
   local parser = argparse(description.script_name, description.name .. ":\n" .. description.desc)
   --parser:argument("input", "Input file.")
   parser:mutex(
      parser:option("--gps" , "GPM Stack (GPS) to install (will look for .gps file)."):overwrite(false),
      parser:option("--gpsf", "GPM Stack (GPS) file to install."):overwrite(false)
   )
   --parser:option("-c --config", "Provide config file."):overwrite(false)
   parser:flag("--cleanup", "Cleanup by removing build directory after build is complete.")
   parser:flag("--debug", "Print debug information (mostly for developers).")
   parser:flag("-v --version", "Print '" .. version.get_version() .. "' and exit."):action(function()
      print(version.get_version())
      os.exit(0)
   end)

   args = parser:parse()
   --[[
   if args.debug then
      dump_args(args)
   end
   --]]
   
   -- Try
   exception.try(function() 
      -- Bootstrap stack
      stack = bootstrap_stack(args)
      
      -- Build the stack
      for key, value in pairs(stack) do
         execute_command(value)
      end
   end, function (e)
      exception.message(e)
      print("\n" .. parser:get_usage())
   end)
end

-- Run main driver.
main()
