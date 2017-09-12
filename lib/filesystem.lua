M = {}

local posix = require "posix"
local lfs   = require "lfs"
local path  = require "path"

--- Remove a file.
--
-- @param path   The path of the file.
local function remove(path)
   os.remove(path)
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

--- Remove a directory.
--
-- @param path          The path of the directory.
-- @param recursively   Do the remove recursively, i.e. if the directory is not empty remove the contents.
--
-- @return   Returns whether the removal was succesful or not.
local function rmdir(path, recursively)
   --print("HERE " .. path .. "   " .. lfs.attributes(path, "mode"))
   if not (lfs.attributes(path, "mode") == "directory") then 
      print("LOL " .. path)
      return true
   end
   
   print("TRYING TO " .. path)

   if recursively then
      for file in lfs.dir(path) do
         if (not (file == "..") and not (file == ".")) then
            file = path .. "/" .. file
            
            if lfs.attributes(file, "mode") == "file" then
               -- Remove file
               remove(file)
            elseif lfs.attributes(file, "mode") == "directory" then 
               -- Recursively remove files in sub-directory
               local success = rmdir(file, recursively)
            elseif lfs.symlinkattributes (file , "mode") then
               -- Unlink symlinks
               unlink(file)
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
