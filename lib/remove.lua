-- Load packages
local util       = assert(require "lib.util")
local install    = assert(require "lib.install")
local path       = assert(require "lib.path")
local filesystem = assert(require "lib.filesystem")
local exception  = assert(require "lib.exception")
local logging    = assert(require "lib.logging")
local logger     = logging.logger
local packages   = assert(require "lib.packages")
local database   = assert(require "lib.database")
local lmod       = assert(require "lib.lmod")
local class      = assert(require "lib.class")
local gpackage   = assert(require "lib.gpackage")

-- Create module
local M = {}

--- Generate install path for package (copied from installer...)
local function generate_install_path(gpack)
   -- Create install path
   local install_path = ""
   if gpack.lmod.group then
      install_path = path.join(global_config.stack_path, gpack.lmod.group)
      
      --if is_heirarchical(gpack.lmod.group) then
      --   for key,prereq in util.ordered(gpack.prerequisite) do
      --      assert(false) -- not tested
      --      install_path = path.join(install_path, string.gsub(prereq, "/", "-"))
      --   end
      --end
      
      install_path = path.join(path.join(install_path, gpack.name), gpack.version)
   else
      -- Special care for lmod
      if gpack.name == "lmod" then
         install_path = global_config.stack_path
      else
         install_path = path.join(path.join(global_config.stack_path, gpack.name), gpack.version)
      end
   end

   -- Set install path
   return install_path
end

-- Generate install path for module file
local function generate_module_install_path(gpack)
   -- Lmod stuff
   local module_install_path = global_config.lmod_directory
   module_install_path = path.join(module_install_path, gpack.lmod.group)
   
   --if is_heirarchical(package.definition.pkggroup) then
   --   if prerequisite then
   --      nprereq = #prerequisite
   --   else
   --      nprereq = 0
   --   end

   --   if nprereq ~= 0 then
   --      lmod_base = prerequisite[nprereq]
   --   end
   --end

   
   --if is_heirarchical(package.definition.pkggroup) then
   --   for key,prereq in util.ordered(package.prerequisite) do
   --      package.lmod.modulefile_directory = path.join(package.lmod.modulefile_directory, prereq)
   --   end
   --end
   
   module_install_path = path.join(module_install_path, gpack.name)

   return module_install_path
   
end

local remover_class = class.create_class()

function remover_class:__init()
   self.build = {
      install_path = "",
   }
end

function remover_class:initialize()
   self.build.install_path = generate_install_path(self.gpack)
   self.build.module_path  = generate_module_install_path(self.gpack)
end

function remover_class:remove(gpack)
   self.gpack = gpack

   self:initialize()
   
   -- Remove installation
   local status, msg = filesystem.rmdir(self.build.install_path, true)

   -- Remove lmod scripts
   local lmod_filename = path.join(self.build.module_path, gpack.version .. ".lua")
   local status, msg   = filesystem.remove(lmod_filename)
   filesystem.rmdir(self.build.module_path)
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
      if args.old then
         --
         if args.debug then
            logger:debug("Removing package")
         end

         -- Hack, we dont need source to uninstall
         args.source = ""
         
         -- Bootstrap the package we are removing
         package = packages.bootstrap(args)
         
         -- Load database
         database.load_db(global_config)
         
         if (util.conditional(database.use_db(), database.installed(package), true)) or args.force then
            -- Remove the package
            remove_package(package)
            
            lmod.update_lmod_cache()
         else
            logger:message("Package not installed.")
         end

         
         -- Fix the database
         database.remove_package(package)
         database.save_db(global_config)
      else
         local build_definition = gpackage.create_build_definition({})
         build_definition:initialize(args.gpack)
         local gpack = gpackage.load_gpackage(build_definition)
         
         -- Load database
         database.load_db(global_config)
         
         if (util.conditional(database.use_db(), database.installed(gpack), true)) or args.force then
            local remover = remover_class:create()
            remover:remove(gpack)
            lmod.update_lmod_cache()
         else
            logger:message("Package not installed.")
         end

         -- Fix the database
         database.remove_package(gpack)
         database.save_db(global_config)
      end
   end, function (e)
      exception.message(e)
      error(e)
   end)
end

M.remove = remove

return M
