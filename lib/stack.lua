#!/usr/bin/lua

local util = require "util"

local M = {}

-------------------------------------
-- 
-------------------------------------
local function bootstrap_stack(args)
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
-- Main driver.
-------------------------------------
local function stack(args)
   -- Try
   exception.try(function() 
      -- Bootstrap stack
      stack = bootstrap_stack(args)
      
      -- Build the stack
      command = arg[0] .. " --config " .. args.config .. " install "
      
      if args.no_build then
         command = command .. "--no-build "
      end

      if args.no_lmod then
         command = command .. "--no-lmod "
      end

      for key, value in pairs(stack) do
         util.execute_command(command .. value)
      end
   end, function (e)
      exception.message(e)
      print("\n" .. parser:get_usage())
   end)
end

M.stack = stack

return M
