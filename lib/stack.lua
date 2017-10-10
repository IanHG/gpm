local util = require "util"

local M = {}

-------------------------------------
-- Bootstrap stack command.
--
-- @param{Table} args   The commandline arguments.
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
-- Install a whole software stack.
--
-- @param{Table} args   The commandline arguments.
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
      
      for level = 1, #stack do
         for key, value in pairs(stack[level]) do
            util.execute_command(command .. value)
         end
      end
   end, function (e)
      exception.message(e)
      error(e)
   end)
end

M.stack = stack

return M
