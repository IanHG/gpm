local M = { }

--- Join paths.
-- Join two paths using correct separator.
--
-- @param {string} pathl   Left path.
-- @param {string} pathr   Right path.
--
-- @return {string}   Return joined path.
local function join(pathl, pathr)   
   return pathl .. "/" .. pathr
end

--- Remove last dir in path.
--
-- @param {string} path   The path.
--
-- @return {string}    Returns the updated path.
local function remove_dir_end(path)
   return (string.gsub(path, '[\\/]+$', ''))
end

---
--
--
local function split_filename(strFilename)
   -- Returns the Path, Filename, and Extension as 3 values
   if lfs.attributes(strFilename,"mode") == "directory" then
      local strPath = strFilename:gsub("[\\/]$","")
      return strPath.."\\","",""
   end
   return strFilename:match("(.-)([^\\/]-%.?([^%.\\/]*))$")
end


---
--
--
local function get_filename(url)
  --return url:match("^.+/(.+)$")
  _, file, _ = split_filename(url)
  return file
end

---
--
--
local function get_file_extension(url)
  --return url:match("^.+(%..+)$")
  path, file, ext = split_filename(url)
  return ext
end

-- Load functions for module
M.join = join
M.remove_dir_end = remove_dir_end
M.filename = get_filename
M.extension = get_file_extension
M.split_filename = split_filename

return M
