-- Create module
local M = {}

local posix      = assert(require "posix")

-- Load local packages
local filesystem = assert(require "lib.filesystem")
local util       = assert(require "lib.util")
local path       = assert(require "lib.path")
local logging    = assert(require "lib.logging")
local logger     = logging.logger

local function setup_posix_binds()
   if posix.unistd then
      posix_getuid  = posix.unistd.getuid
      posix_geteuid = posix.unistd.geteuid
      posix_getgroups = posix.unistd.getgroups
   else
      posix_getuid  = posix.getuid
      posix_geteuid = posix.geteuid
      posix_getgroups = posix.getgroups
   end

   if not posix_getuid then
      posix_getuid = function() 
         return -1
      end
   end
   if not posix_geteuid then
      posix_geteuid = function() 
         return -1
      end
   end
   if not posix_getgroups then
      posix_getgroups = function() 
         return -1
      end
   end
end

setup_posix_binds()

-- Helper function to find folder of current script.
local function folder_of_this()
   local folder = arg[0]:match("(.-)[^\\/]+$") -- Get folder of executeable
   if folder:sub(1,1) ~= "/" then
      folder = lfs.currentdir() .. "/" .. folder
   end
   return folder
end

-- Default config
local global_default_config = {
   -- Set a default name
   stack_name = "DEFAULT",
   -- Set current directory
   current_directory = filesystem.cwd(),  
   -- Set folder of running script
   folder = folder_of_this(),
   --
   stack_path = folder_of_this(),
   ---- Set default .gpk path
   --gpk_path = folder_of_this() .. "../gpk",
   gpk_path = "",
   ---- Set default .gps path
   --gps_path = folder_of_this() .. "../gps",
   gps_path = "",

   template_path = folder_of_this() .. "../templates",
   --
   repo = "https://raw.githubusercontent.com/IanHG/gpm-gpackages/master",
   -- As of now we must give the hierarchical keyword, so we just default to empty
   heirarchical = {},
   
   -- Meta stack
   meta_stack = {
      parent = nil,
      allow_registration = false,
      register = true,
   },

   -- User id
   user = {
      uid  = nil,
      euid = nil,
      groups = nil,
   }
}

-- Global config
global_config = {
}

local bootstrap

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
   local config_path = ""

   -- Make sure we have a config path
   if args.config then
      config_path = args.config
   else
      -- If none was given we check for the environment one.
      local env_config_paths = os.getenv("GPM_CONFIG")
      if env_config_paths then
         for env_config_path in path.iterator(env_config_paths) do
            if args.token then
               local env_config = bootstrap(env_config_path, nil, {}, false)
               if env_config.stack_token == args.token then
                  return env_config_path
               end
            else
               return env_config_path
            end
         end

         error("Token not found.")
      else
         -- If enviroment config wasn't found, we check current directory
         config_path = path.join(filesystem.cwd(), "config.lua")
      end
   end
   
   -- Return path to check
   return config_path
end

---
--
local function check(config)
   -- Assert that current user has write access to base build path
   local function check_owned_by_group()
      local group = filesystem.group(config.base_build_directory)
      for k, v in pairs(config.user.groups) do
         if v == group then
            return true
         end
      end
      return false
   end
   
   local owned_by_user  = (filesystem.owner(config.base_build_directory) == config.user.euid)
   local owned_by_group = check_owned_by_group()

   local build_path_permissions = filesystem.permissions(config.base_build_directory)
   
   if build_path_permissions then
      local build_path_rw_permission 
         =  (owned_by_user  and string.find(build_path_permissions, "rw......."))
         or (owned_by_group and string.find(build_path_permissions, "...rw...."))
         or string.find(build_path_permissions, "......rw.")
      
      if not build_path_rw_permission then
         error("Current user does not have RW permission for build path '" .. config.base_build_directory .. "'")
      end
   end
end

--- Boostrap config dictionary.
--
-- Read in config file, and set some default configurations if needed.
-- 
-- @param config_path      The config path if 'nil' will be found from args.
-- @param args             Optional arguments.
-- @param default_config   Default configuration for module calling bootstrap (usually just {}). 
-- @param set_global       Set the global config?
--
-- @return{Dictionary} Returns definition og build.
--local function bootstrap(config_path, args, default_config, set_global)
bootstrap = function (config_path, args, default_config, set_global)
   -- Set default
   if  args == nil then
      args = {}
   end
   
   if args.debug then
      logger:debug("Starting to bootstrap config.")
   end
   
   if not default_config then
      default_config = {}
   end

   local local_config = {}

   -- Do some debug output if requested
   if args.debug then
      logger:debug("Bootstrapping config.")
   end
   
   -- Load config file
   if not config_path then
      config_path = configpath(args)
   end
   
   --print(config_path)
   if (type(config_path) == "string") and (not util.isempty(config_path)) then
      assert(loadfile(config_path))()
   else
      config = {}
   end
   
   if config then
      local_config = util.merge(local_config, config)
   end
   
   -- Merge with default config
   local_config = util.merge(local_config, default_config)
   local_config = util.merge(local_config, global_default_config)
   
   
   -- Set this_path
   if (type(config_path) == "string") and (not util.isempty(config_path)) then
      local_config.this_path = util.conditional(path.is_abs_path(config_path), config_path, local_config.current_directory .. "/" .. config_path)
   end

   --
   -- Setup defaults
   --
   if (not local_config.stack_token) then
      local token = string.lower(util.split(local_config.stack_name)[1])
      local_config.stack_token = token
   end

   -- Setup stack_path
   if (not local_config.stack_path) then
      local stack_path, _, _  = path.split_filename(args.config)
      local_config.stack_path = path.remove_dir_end(stack_path)
   end

   -- Setup log_path
   if local_config.log_path and (not path.is_abs_path(local_config.log_path)) then
      local_config.log_path = path.join(local_config.stack_path, local_config.log_path)
   end
   
   -- Setup gpk_path and gps_path
   if config.gpk_path then
      local_config.gpk_path = util.conditional(path.is_abs_path(config.gpk_path), config.gpk_path, path.join(config.stack_path, config.gpk_path))
   end
   if config.gps_path then
      local_config.gps_path = config.gps_path
   end
   
   -- Setup build_path and lmod_path
   if not local_config.base_build_directory then 
      local_config.base_build_directory = local_config.stack_path .. "/build" 
   end
   if not local_config.lmod_directory then 
      local_config.lmod_directory = local_config.stack_path .. "/modulefiles" 
   end
   
   -- Lmod block
   if (not local_config.lmod) then
      local_config.lmod = {}
   end

   if (not local_config.lmod.cache_path) then
      local_config.lmod.cache_path = local_config.stack_path .. "/modulesdata"
   elseif path.is_rel_path(local_config.lmod.cache_path) then
      local_config.lmod.cache_path = local_config.stack_path .. "/" .. local_config.lmod.cache_path
   end

   if (not local_config.lmod) or (not local_config.lmod.version) then
      local_config.lmod.version = "7.7.13"
   end

   -- Setup meta stack data
   if args.parentstack then
      if filesystem.exists(args.parentstack) then
         local_config.meta_stack.parent = args.parentstack
      end
   end

   -- Setup whether we are printing debug information.
   local_config.debug = util.conditional(args.debug, true, false)

   --
   -- Do some clean-up
   --
   
   -- If requested printout some debug information
   if(args.debug) then
      logger:debug("Done reading config...")
      logger:debug(util.print(local_config, "config"))
   end
   
   -- Unset the loaded config (which has been loaded into global space!)
   config = nil
   
   -- If requested set the global config
   if set_global then
      global_config = local_config
   end

   local_config.user.uid    = posix_getuid()
   local_config.user.euid   = posix_geteuid()
   local_config.user.groups = posix_getgroups()

   -- Check sanity of config
   check(local_config)
   
   -- Return the created config (return can be ignored if setting global config).
   return local_config
end


--- Print configuration.
--
-- @param config   The config to print.
-- @param log      The log to print to.
--
local function print_config(config, log)
   if not log then
      log = io.stdout
   end
   logger:debug(util.print(default_config, "config"), nil, log)
end

-- Load module
M.configpath   = configpath
M.bootstrap    = bootstrap
M.check        = check
M.print_config = print_config

return M
