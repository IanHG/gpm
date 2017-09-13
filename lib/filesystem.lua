M = {}

local posix = require "posix"
local lfs   = require "lfs"
local path  = require "path"

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
   return posix.symlink(path, linkpath)
end

--- Unlink a hard- or symbolic-link.
-- Unlink a hard- or symbolic-link using the posix module of Lua.
-- This currently only works on Linux.
--
-- @param path   The path to unlink.
--
-- @return 
local function unlink(path)
   return posix.unlink(path)
end

--- Make a directory.
--
-- Make a directory with modes.
--
-- @param path
-- @param mode
--
-- @return

--- Remove a directory.
--
-- @param path          The path of the directory.
-- @param recursively   Do the remove recursively, i.e. if the directory is not empty remove the contents.
--
-- @return   Returns whether the removal was succesful or not, and a message if it failed.
local function rmdir(path, recursively)
   -- Check that directory actually exists
   if not (lfs.attributes(path, "mode") == "directory") then 
      return true
   end
   
   -- If required do recursive remove
   if recursively then
      for file in lfs.dir(path) do
         if (not (file == "..") and not (file == ".")) then
            file = path .. "/" .. file
            
            if lfs.attributes(file, "mode") == "file" then
               -- Remove file
               local status, msg = remove(file)
               if not status then
                  return status, msg
               end
            elseif lfs.attributes(file, "mode") == "directory" then 
               -- Recursively remove files in sub-directory
               local status, msg = rmdir(file, recursively)
               if not status then
                  return status, msg
               end
            elseif lfs.symlinkattributes (file , "mode") then
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
   return lfs.rmdir(path)
end


--- Load module
M.remove = remove
M.link   = link
M.unlink = unlink
M.rmdir  = rmdir

return M
