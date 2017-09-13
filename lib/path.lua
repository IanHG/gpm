local M = { }

M.sep = "/"

--- Check if path is absolute
--
-- @param {string} path   The path to check
--
-- @return {boolean}   Returns true if path is absolute, false otherwise.
local function is_abs_path(path)
   return (string.find(path, "^[/]")) and true
end

--- Check if a path has dir end.
-- 
-- @param {string} path   The path to check.
--
-- @return {boolean}   Return true if dir-end, false otherwise
local function has_dir_end(path)
   return (string.find(path, "[\\/]$")) and true
end

--- Remove last dir in path.
--
-- @param {string} path   The path.
--
-- @return {string}    Returns the updated path.
local function remove_dir_end(path)
   return (string.gsub(path, '[\\/]+$', ''))
end

--- Join paths.
-- Join two paths using correct separator.
--
-- @param {string} pathl   Left path.
-- @param {string} pathr   Right path.
--
-- @return {string}   Return joined path.
local function join(pathl, pathr)   
   if has_dir_end(pathl) then
      return pathl .. pathr
   else
      return pathl .. M.sep .. pathr
   end
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
M.is_abs_path    = is_abs_path
M.has_dir_end    = has_dir_end
M.remove_dir_end = remove_dir_end
M.join           = join
M.filename       = get_filename
M.extension      = get_file_extension
M.split_filename = split_filename

return M
