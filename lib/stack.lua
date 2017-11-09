local M = {}

local util       = require "util"
local exception  = require "exception"
local filesystem = require "filesystem"
local path       = require "path"

--- Locate gps file by searching gps_path.
--
-- @param args   The input arguments.
--
-- @return   Returns gps filename as string.
local function locate_gps_file(args)
   -- Initialize to nil
   local filepath = nil

   -- Try to locate gps file
   if args.gps then
      local filename = args.gps .. ".gps"
      local function locate_gps_impl()
         for gps_path in path.iterator(config.gps_path) do
            -- Check for abs path
            if not path.is_abs_path(gps_path) then
               gps_path = path.join(config.stack_path, gps_path)
            end

            -- Create file path
            local filepath = path.join(gps_path, filename)

            -- Check for existance
            if filesystem.exists(filepath) then
               return filepath
            end
         end
         return nil
      end
      filepath = locate_gps_impl()
   elseif args.gpsf then
      filepath = args.gpsf
   else
      error("Must provide either -gps or -gpsf option.")
   end
   
   -- Return found path
   return filepath
end

--- Bootstrap stack command.
--
-- @param{Table} args   The commandline arguments.
--
-- @return  Returns stack object.
local function bootstrap_stack(args)
   -- Load package file
   local filepath = locate_gps_file(args)
   
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
