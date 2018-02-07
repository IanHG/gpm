local M = {}

local filesystem = require "lib.filesystem"
local util = require "lib.util"
local path = assert(require "lib.path")
local logging = assert(require "lib.logging")

local function folder_of_this()
   local folder = arg[0]:match("(.-)[^\\/]+$") -- Get folder of executeable
   if folder:sub(1,1) ~= "/" then
      folder = lfs.currentdir() .. "/" .. folder
   end
   return folder
end

-- Default config
local global_default_config = {
   current_directory = filesystem.cwd(),  
   folder = folder_of_this(),
   gpk_path = folder_of_this() .. "../gpk",
   gps_path = folder_of_this() .. "../gps",
   heirarchical = {},
}

config = {
}

--- Search for config path.
--
-- Will first check commandline args, then check the ENV variable GPM_CONFIG.
-- If none of these were set the function will return:
--    
--    <cwd>/config.lua
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

--- Boostrap config dictionary.
-- 
-- @param args
-- @param default_config
--
-- @return{Dictionary} Returns definition og build.
local function bootstrap(args, default_config)
   -- Do some debug output if requested
   if args.debug then
      logging.debug("Bootstrapping config.", io.stdout)
   end
   
   -- Load config file
   local cpath = configpath(args)
   assert(loadfile(cpath))()
   
   -- Merge with default config
   default_config = util.merge(global_default_config, default_config)
   default_config = util.merge(default_config, config)

   -- Setup stack_path
   if (not default_config.stack_path) then
      local stack_path, _, _ = path.split_filename(args.config)
      print(stack_path)
      default_config.stack_path = path.remove_dir_end(stack_path)
   end

   -- Setup log_path
   if default_config.log_path and (not path.is_abs_path(default_config.log_path)) then
      default_config.log_path = path.join(default_config.stack_path, default_config.log_path)
   end
   
   -- Setup gpk_path and gps_path
   if config.gpk_path then
      default_config.gpk_path = default_config.gpk_path .. ":" .. default_config.folder .. "../gpk"
   end
   if config.gps_path then
      default_config.gps_path = default_config.gps_path .. ":" .. default_config.folder .. "../gps"
   end
   
   -- Setup build_path and lmod_path
   if not default_config.base_build_directory then 
      default_config.base_build_directory = default_config.stack_path .. "/build" 
   end
   if not default_config.lmod_directory then 
      default_config.lmod_directory = default_config.stack_path .. "/modulefiles" 
   end

   -- Setup whether we are printing debug information.
   default_config.debug = util.conditional(args.debug, true, false)
   
   -- If requested printout some debug information
   if(args.debug) then
      logging.debug(util.print(config, "config"), io.stdout)
   end

   return default_config
end

--- Load module
M.configpath = configpath
M.bootstrap  = bootstrap

return M
