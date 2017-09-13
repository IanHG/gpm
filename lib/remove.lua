-- Load packages
local util       = require "util"
local install    = require "install"
local path       = require "path"
local filesystem = require "filesystem"

-- Create module
local M = {}

-------------------------------------
-- Bootstrap the remove command.
--
-- @param{Table} args   The commandline arguments.
-------------------------------------
local function bootstrap_remove(args)
end

-------------------------------------
-- Remove the package.
--
-- @param{Table} package   The package to remove.
-------------------------------------
local function remove_package(package)
   -- Remove binaries
   local status, msg = filesystem.rmdir(package.definition.pkginstall, true)
   if not status then
      print(msg)
   end
   
   local bin_base_path = path.remove_dir_end(string.gsub(package.definition.pkginstall, package.definition.pkgversion, ""))
   local status, msg = filesystem.rmdir(bin_base_path)
   
   -- Remove lmod scripts
   lmod_filename = path.join(package.lmod.modulefile_directory, package.definition.pkgversion .. ".lua")
   local status, msg = filesystem.remove(lmod_filename)
   if not status then
      print(msg)
   end
   filesystem.rmdir(package.lmod.modulefile_directory)
end

-------------------------------------
-- Remove a package from the software stack.
--
-- @param{Table} args   The commandline arguments.
-------------------------------------
local function remove(args)
   -- Try
   exception.try(function()
      -- Bootstrap the package we are removing
      package = install.bootstrap_package(args)

      -- Remove the package
      remove_package(package)

   end, function (e)
      exception.message(e)
      error(e)
   end)
end

M.remove = remove

return M
