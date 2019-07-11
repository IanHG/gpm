local posix = assert(require "posix")

-- Setup posix stuff
local function setup_posix_binds()
   if posix.stdlib then
      posix_setenv = posix.stdlib.setenv
      posix_getenv = posix.stdlib.getenv
   else
      posix_setenv = posix.setenv
      posix_getenv = posix.getenv
   end
end

setup_posix_binds()

-- Functions
local function prepend_env(name, value)
   local path = posix_getenv(name)
   if path then
      path = value .. ":" .. path
   else
      path = value
   end
   local status = posix_setenv(name, path, true)

   return status
end

-- 
local function set_env(name, value)
   local status = posix_setenv(name, value, true)

   return status
end

--
local function get_env(name)
   local env = posix_getenv(name)

   return env
end

-- Create module
local M = {}

M.prepend_env = prepend_env
M.set_env     = set_env
M.get_env     = get_env

return M
