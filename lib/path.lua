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

--- Check if path is relative.
--
-- @param {string} path   The path to check
--
-- @return {boolean}  Returns true if path is relative, false otherwise.
local function is_rel_path(path)
   return (not is_abs_path(path))
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
   if type(pathl) ~= "string" then
      assert(false)
   end

   if type(pathr) ~= "string" then
      assert(false)
   end

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
   if lfs.attributes(strFilename, "mode") == "directory" then
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
  local _, file, _ = split_filename(url)
  return file
end

---
--
--
local function get_file_extension(url)
  --return url:match("^.+(%..+)$")
  local path, file, ext = split_filename(url)
  return ext
end

--- Take a separated string of paths and return an iterator to loop over the paths.
--
-- @param  path    The separated path string.
-- @param  sep     A custom separator (defaults to ":").
--
-- @return Returns path iterator.
local function iterator(path, sep)
   if not sep then
      sep = ":"
   end
   
   return path:gmatch("([^" .. sep .. "]+)" .. sep .. "?")
end

-- Load functions for module
M.is_abs_path    = is_abs_path
M.is_rel_path    = is_rel_path
M.has_dir_end    = has_dir_end
M.remove_dir_end = remove_dir_end
M.join           = join

M.filename       = get_filename
M.extension      = get_file_extension
M.split_filename = split_filename

M.iterator       = iterator

return M
