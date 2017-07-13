ml = {}

-- Define version number
version = {  
   major = 1,
   minor = 1,
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

ml.get_version_number = get_version_number
ml.get_version = get_version

return ml
