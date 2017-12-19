local M = {}

--- Search for config path.
--
-- @return Returns config path to search.
local function configpath(args)
   -- Init path variable
   local path = ""

   -- Make sure we have a config path
   if args.config then
      path = args.config
   else
      -- If none was given we check for the environtment one.
      path = os.getenv("GPM_CONFIG")
      if not path then
         -- If enviroment config wasn't found, we check current directory
         args.config = path.join(config.current_directory, "config.lua")
      end
   end
   
   -- Return path to check
   return path
end

--- Load module
M.configpath = configpath

return M
