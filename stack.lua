#!/usr/bin/lua

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
-- Run command in shell.
--
-- @param command
--
-- @return{Boolean}
-------------------------------------
local function execute_command(command)
   bool, flag, status = os.execute(command)

   if not bool then
      error("Command '" .. command .. "' exited with errors.")
   end
end

-------------------------------------
-- Main driver.
-------------------------------------
function stack(args)
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
