M = {}

local _posix = require "posix"
local _lfs   = require "lfs"
local _path  = require "path"

--- Check existance of file object.
--
-- @param path   The file path.
--
-- @return   Returns true if file exists otherwise false.
local function exists(path)
   return _lfs.attributes(path, "mode") ~= nil
end

--- Check if path points to a file.
--
-- @param path  The path to check.
--
-- @return   Returns true if file exists and is a file otherwise false.
local function isfile(path)
   return _lfs.attributes(path, "mode") == "file"
end

--- Check if path points to a directory.
--
-- @param path  The path to check.
--
-- @return   Returns true if path exists and is a directory otherwise false.
local function isdir(path)
   return _lfs.attributes(path, "mode") == "directory"
end

--- Check if path points to a symlink.
--
-- @param path  The path to check.
--
-- @return   Returns true if path exists and is a symlink otherwise false.
local function issymlink(path)
   return _lfs.symlinkattributes(path, "mode") ~= nil
end

--- Remove a file.
--
-- @param path   The path of the file.
--
-- @return    Returns status and message if remove failed.
local function remove(path)
   local status, msg = os.remove(path)
   return status, msg
end

--- Create a symbolic link.
-- Create a symbolic link using the posix module of Lua.
--
-- @param path       The path to link.
-- @param linkpath   The path for the symlink.
--
-- @return 
local function symlink(path, linkpath) 
   return _posix.symlink(path, linkpath)
end

--- Unlink a hard- or symbolic-link.
-- Unlink a hard- or symbolic-link using the posix module of Lua.
-- This currently only works on Linux.
--
-- @param path   The path to unlink.
--
-- @return 
local function unlink(path)
   return _posix.unlink(path)
end

--- Make a directory.
--
-- Make a directory with modes.
--
-- @param path          The path to create.
-- @param mode          Create directory in mode.
-- @param recursively   Create directory recursively.
--
-- @return     Return whether succesful or not, and a message if not.
local function mkdir(path, mode, recursively)
   print("PATH " .. path)
   if (not path) then
      return false
   end

   does_exist = exists(path)

   if does_exist then
      if not isdir(path) then
         return nil, "Cannot create directory: File exists."
      end
   else
      if recursively then
         base_path = string.gsub(_path.remove_dir_end(path), "/[^/]*$", "")
         if not exists(base_path) then
            mkdir(base_path, mode, recursively)
         end
      end
   end

   return _lfs.mkdir(path)
end

--- Remove a directory.
--
-- @param path          The path of the directory.
-- @param recursively   Do the remove recursively, i.e. if the directory is not empty remove the contents.
--
-- @return   Returns whether the removal was succesful or not, and a message if it failed.
local function rmdir(path, recursively)
   -- Check input validity
   if (not path) then
      return false
   end

   -- Check that directory actually exists
   if not (_lfs.attributes(path, "mode") == "directory") then 
      return true
   end
   
   -- If required do recursive remove
   if recursively then
      for file in _lfs.dir(path) do
         if (not (file == "..") and not (file == ".")) then
            file = path .. "/" .. file
            
            if _lfs.attributes(file, "mode") == "file" then
               -- Remove file
               local status, msg = remove(file)
               if not status then
                  return status, msg
               end
            elseif _lfs.attributes(file, "mode") == "directory" then 
               -- Recursively remove files in sub-directory
               local status, msg = rmdir(file, recursively)
               if not status then
                  return status, msg
               end
            elseif _lfs.symlinkattributes (file , "mode") then
               -- Unlink symlinks
               local status, msg = unlink(file)
               --if not status then
               --   return status, msg
               --end
            else
               print("UNKNOWN MODE :S")
            end
         end
      end
   end

   -- Remove directory
   return _lfs.rmdir(path)
end

--- Change working directory.
--
-- @param path   The path to change to.
--
-- @return 
local function chdir(path)
   return lfs.chdir(path)
end


--- Load module
M.exists    = exists
M.isfile    = isfile
M.isdir     = isdir
M.issymlink = issymlink
M.remove    = remove
M.link      = link
M.unlink    = unlink
M.mkdir     = mkdir
M.rmdir     = rmdir
M.chdir     = chdir

return M
