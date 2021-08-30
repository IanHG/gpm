local util = assert(require "lib.util")
local path = assert(require "lib.path")

local M = {}

--- Create modulepaths and return these.
--
-- @return{string,string}   Returns modulepath_root and modulepath strings.
local function generate_module_paths()
   local modulepath_root = global_config.lmod_directory
   local modulepath = ""
   for k,v in pairs(global_config.groups) do
      modulepath = modulepath .. path.join(modulepath_root, v) .. ":"
   end
   if modulepath[-1] == ":" then
      modulepath = modulepath.sub(1, -2)
   end

   return modulepath_root, modulepath
end

--- Generate cache paths.
--
-- @return{string,string}   Returns cache_dir and cache_timestamp strings.
local function generate_cache_paths()
   local cache_path = global_config.lmod.cache_path
   
   local cache_dir       = path.join(cache_path, "cache")
   local cache_timestamp = path.join(cache_path, "system.txt")
   
   return cache_dir, cache_timestamp
end

--- Update the lmod cache.
--
-- @param log    An optional log.
local function update_lmod_cache()
   -- Get some lmod directories
   local cache_dir, cache_timestamp  = generate_cache_paths()
   local modulepath_root, modulepath = generate_module_paths()
   local lmod_version = global_config.lmod.version;
   
   -- Create command
   local cmd = ". " .. global_config.stack_path .. "/bin/modules.sh --link-relative --force && "
   cmd       = cmd .. "ml lmod/" .. lmod_version .. " && update_lmod_system_cache_files -d " .. cache_dir .. " -t " .. cache_timestamp .. " " .. modulepath
   
   -- Run command
   local status = util.execute_command(cmd)
   if status ~= 0 then
      logger:alert("Could not update lmod-cache.")
   end
end

-- Load module
M.generate_module_paths = generate_module_paths
M.generate_cache_paths  = generate_cache_paths
M.update_lmod_cache     = update_lmod_cache

return M
