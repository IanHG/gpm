local M = {}

-- Define version number
local version = {  
   major = 1,
   minor = 3,
   patch = 0,
}

-------------------------------------
-- Get version number.
--
-- @return{String} Version number.
-------------------------------------
local function get_version_number()
   return version.major .. "." .. version.minor .. "." .. version.patch
end

-------------------------------------
-- Get name and version of program.
--
-- @return{String} Name and version.
-------------------------------------
local function get_version()
   return description.name .. " Vers. " .. get_version_number()
end

-- Load module
M.get_version_number = get_version_number
M.get_version = get_version

return M
