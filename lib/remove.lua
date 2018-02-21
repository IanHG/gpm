-- Load packages
local util       = assert(require "lib.util")
local install    = assert(require "lib.install")
local path       = assert(require "lib.path")
local filesystem = assert(require "lib.filesystem")
local exception  = assert(require "lib.exception")
local logging    = assert(require "lib.logging")
local packages   = assert(require "lib.packages")
local database   = assert(require "lib.database")

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
      --
      if args.debug then
         logging.debug("Removing package", io.stdout)
      end

      -- Hack, we dont need source to uninstall
      args.source = ""
      
      -- Bootstrap the package we are removing
      package = packages.bootstrap(args)
      
      -- Load database
      database.load_db(config)
      
      if database.installed(package) or args.force then
         -- Remove the package
         remove_package(package)
      else
         logging.message("Package not installed.", io.stdout)
      end
      
      -- Fix the database
      database.remove_element(package)
      database.save_db(config)

   end, function (e)
      exception.message(e)
      error(e)
   end)
end

M.remove = remove

return M
