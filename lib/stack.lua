local M = {}

local util = require "util"
local exception = require "exception"

--- Bootstrap stack command.
--
-- @param{Table} args   The commandline arguments.
--
-- @return  Returns stack object.
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

   if not definitions then
      local definitions = {}
   end

   return stack, definitions
end

--- Install a whole software stack.
--  
--  Install a whole sofware stack as defined by a .gps.
--  If a package fails to install, execution will be abandoned.
--  As later packages might depend on the failed package, it is 
--  better to just stop execution.
--
-- @param{Table} args   The commandline arguments.
local function stack(args)
   -- Try
   exception.try(function() 
      -- Bootstrap stack
      local stack, definitions = bootstrap_stack(args)
      
      -- Build the stack
      local command = arg[0] .. " --config " .. args.config .. " "
      
      if args.no_build then
         command = command .. "--no-build "
      end

      if args.no_lmod then
         command = command .. "--no-lmod "
      end
      
      -- Loop over stack level
      for level = 1, #stack do
         for key, value in pairs(stack[level]) do
            -- Create specific command
            local execcmd = command .. value
            if definitions then
               print("LOL")
               execcmd = util.substitute_placeholders(definitions, execcmd)
            end
            
            -- Run the command
            local status = util.execute_command(execcmd, { io.stdout })
            if status ~= 0 then
               error("Failed to build package : " .. value)
            end
         end
      end
   end, function (e)
      -- Propagate the error
      error(e)
   end)
end

-- Load module
M.stack = stack

return M
