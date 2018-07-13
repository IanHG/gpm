local lfs = assert(require "lfs")

local util       = assert(require "lib.util")
local path       = assert(require "lib.path")
local filesystem = assert(require "lib.filesystem")
local exception  = assert(require "lib.exception")
local logging    = assert(require "lib.logging")
local logger     = logging.logger
local packages   = assert(require "lib.packages")
local database   = assert(require "lib.database")
local lmod       = assert(require "lib.lmod")
local downloader = assert(require "lib.downloader")
local class      = assert(require "lib.class")
local gpackage   = assert(require "lib.gpackage")

local M = {}

local function get_extension(url)
   local _, filename, ext = path.split_filename(url)
   
   local is_tar_gz = string.match(filename, "tar.gz")
   local is_tar_bz = string.match(filename, "tar.bz2")
   local is_tar_xz = string.match(filename, "tar.xz")
   
   if is_tar_gz then
      ext = "tar.gz"
   elseif is_tar_bz then
      ext = "tar.bz2"
   elseif is_tar_xz then
      ext = "tar.xz"
   end

   return ext
end

local function create_file(path, content)
   cfile = io.open(path, "w")
   cfile:write(content)
   cfile:close()
end

local function generate_ml_command(gpack)
   local ml_cmd = ". " .. global_config.stack_path .. "/bin/modules.sh --link-relative --force && "
   
   for k, v in util.ordered(gpack.dependencies) do
      ml_cmd = ml_cmd .. "ml " .. v .. " && "
   end
   
   return ml_cmd
end

--- Generate build path for package
local function generate_build_path(gpack)
   -- Create build path
   local build_path = "build-"
   --for key,prereq in util.ordered(gpack.prerequisite) do
   --   build_path = build_path .. string.gsub(prereq, "/", "-") .. "-"
   --end
   --for key,prereq in util.ordered(gpack.dependson) do
   --   build_path = build_path .. string.gsub(prereq, "/", "-") .. "-"
   --end
   --for key,prereq in util.ordered(gpack.moduleload) do
   --   build_path = build_path .. string.gsub(prereq, "/", "-") .. "-"
   --end
   
   build_path = build_path .. gpack.nameversion
   build_path = path.join(global_config.base_build_directory, build_path)
   
   -- Return
   return build_path
end

--- Generate install path for package
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

-- Generate setenv 
local function generate_setenv(gpack, install_path)
   local setenv = {}

   if gpack.lmod.setenv then
      for _, v in pairs(gpack.lmod.setenv) do
         table.insert(prepend_path, path.join(install_path, v))
      end
   end
   
   if gpack.lmod.setenv_abs then
      for _, v in pairs(gpack.lmod.setenv_abs) do
         table.insert(prepend_path, v)
      end
   end

   return setenv
end

--- Helper function to generate prepend_path for lmod.
-- 
-- This function will handle exports for directories named "include".
-- It will export both to INCLUDE, C_INCLUDE_PATH, CPLUS_INCLUDE_PATH.
--
-- @param{String}  include             "include".
-- @param{Table}   prepend_path        Will be appended with new paths for lmod to prepend.
-- @param{String}  install_path   The directory.
local function generate_prepend_path_include(include, prepend_path, install_path)
   -- Insert in paths
   table.insert(prepend_path, {"INCLUDE"           , path.join(install_path, include)})
   table.insert(prepend_path, {"C_INCLUDE_PATH"    , path.join(install_path, include)})
   table.insert(prepend_path, {"CPLUS_INCLUDE_PATH", path.join(install_path, include)})
end

--- Helper function to generate prepend_path for lmod.
-- 
-- This function will handle exports for directories named "lib" or "lib64.
-- It will export both to LIBRARY_PATH, LD_LIBRARY_PATH, and LD_RUN_PATH.
-- It will look for a directory called pkgconfig, which it will add to
-- PKG_CONFIG_PATH if found.
--
-- @param{String}  lib                 "lib" or "lib64".
-- @param{Table}   prepend_path        Will be appended with new paths for lmod to prepend.
-- @param{String}  install_path   The directory.
local function generate_prepend_path_lib(lib, prepend_path, install_path)
   -- Insert in paths
   table.insert(prepend_path, {"LIBRARY_PATH"   , path.join(install_path, lib)})
   table.insert(prepend_path, {"LD_LIBRARY_PATH", path.join(install_path, lib)})
   table.insert(prepend_path, {"LD_RUN_PATH"    , path.join(install_path, lib)})
   
   -- Check for pgkconfig
   for file in lfs.dir(path.join(install_path, lib)) do
      if file:match("pkgconfig") then
         table.insert(prepend_path, {"PKG_CONFIG_PATH", path.join(install_path, path.join(lib, "pkgconfig"))})
      end
   end
end

--- Helper function to generate prepend_path for lmod.
--
-- This function will handle exports for "share" directory.
-- Will look for "info" and "man", and if found will prepend to
-- "INFOPATH" and "MANPATH" respectively.
--
-- @param{String}  share               Always "share" (for now).
-- @param{Table}   prepend_path        Will be appended with new paths for lmod to prepend.
-- @param{String}  install_path   The directory.
local function generate_prepend_path_share(share, prepend_path, install_path)
   for f in lfs.dir(path.join(install_path, "share")) do
      if f:match("info") then
         table.insert(prepend_path, {"INFOPATH", path.join(install_path, "share/info")})
      elseif f:match("man") then
         table.insert(prepend_path, {"MANPATH" , path.join(install_path, "share/man" )})
      end
   end
end

--- Automatically generate which env variables to prepend by looking at what is present in install directory.
--
-- Will automatically generate a table of paths the lmod script should prepend.
-- This is done based on the directories present in the install directory for the package.
--
-- @param  gpack   The gpackage we are installing.
local function generate_prepend_path(gpack, install_path)
   local prepend_path = {}
   
   -- Try to auto-generate
   if gpack.lmod.autopath then
      for directory in lfs.dir(install_path) do
         if directory:match("bin") then
            table.insert(prepend_path, {"PATH", "bin"})
         elseif directory:match("include") then
            generate_prepend_path_include("include", prepend_path, install_path)
         elseif directory:match("lib64") then
            generate_prepend_path_lib("lib64", prepend_path, install_path)
         elseif directory:match("lib$") then
            generate_prepend_path_lib("lib", prepend_path, install_path)
         elseif directory:match("share") then
            generate_prepend_path_share("share", prepend_path, install_path)
         elseif directory:match("libexec") then
            -- do nothing
         elseif directory:match("etc") then
            -- do nothing
         elseif directory:match("var") then
            -- do nothing
         end
      end
   end
   
   -- Add paths from package
   if gpack.lmod.prepend_path then
      for _, v in pairs(gpack.lmod.prepend_path) do
         table.insert(prepend_path, { v[1], path.join(install_path, v[2])} )
      end
   end
   
   if gpack.lmod.prepend_path_abs then
      for _, v in pairs(gpack.lmod.prepend_path_abs) do
         table.insert(prepend_path, v)
      end
   end
   
   -- At last we return the constructed prepend_path table
   return prepend_path
end

-- Handle "install" of lmod stuff (module file)
local lmod_installer_class = class.create_class()

function lmod_installer_class:__init()
   -- Settings
   self.gpack          = nil
   self.build_path      = nil
   self.install_path    = nil
   
   -- Internal work 
   self.modulefile     = nil
end

function lmod_installer_class:file_build_path()
   return path.join(self.build_path, self.gpack.version .. ".lua")
end

function lmod_installer_class:file_install_path()
   return path.join(self.module_install_path, self.gpack.version .. ".lua")
end

function lmod_installer_class:open_modulefile()
   self.modulefile = io.open(self:file_build_path(), "w")
end

function lmod_installer_class:close_modulefile()
   self.modulefile:close()
end

function lmod_installer_class:write_modulefile()
   self.modulefile:write("-- -*- lua -*-\n")
   self.modulefile:write("help(\n")
   self.modulefile:write("[[\n")
   self.modulefile:write(self.gpack.lmod.help .. "\n")
   self.modulefile:write("]])\n")
   self.modulefile:write("------------------------------------------------------------------------\n")
   self.modulefile:write("-- This file was generated automagically by Grendel Package Manager (GPM)\n")
   self.modulefile:write("------------------------------------------------------------------------\n")
   self.modulefile:write("-- Description\n")
   self.modulefile:write("whatis([[\n")
   self.modulefile:write(self.gpack.description .. "\n")
   self.modulefile:write("]])\n")
   self.modulefile:write("\n")
   self.modulefile:write("-- Set family\n")
   for k, v in pairs(self.gpack.lmod.family) do
      self.modulefile:write("family(\"" .. v[1] .. "\")\n")
   end
   self.modulefile:write("\n")
   self.modulefile:write("-- Basic module setup\n")
   self.modulefile:write("local version     = myModuleVersion()\n")
   self.modulefile:write("local name        = myModuleName()\n")
   self.modulefile:write("local fileName    = myFileName()\n")
   self.modulefile:write("local nameVersion = pathJoin(name, version)\n")
   
   -- SOME STUFF PERTAINING TO HEIRARCH
   --self.modulefile:write("\n")
   --self.modulefile:write("-- Optional modules setup\n")
   --self.modulefile:write("local dir = pathJoin(fam, packagePrereq)\n")
   --self.modulefile:write("for str in os.getenv(\"MODULEPATH_ROOT\"):gmatch(\"([^:]+)\") do\n")
   --self.modulefile:write("   prepend_path('MODULEPATH', pathJoin(str, dir))\n")
   --self.modulefile:write("end\n")
   --self.modulefile:write("\n")
   --self.modulefile
   --self.modulefile:write("-- Package specific\n")
   
   -- Alias
   for k, v in pairs(self.gpack.lmod.alias) do
      self.modulefile:write("alias('" .. v[1] .. "')\n")
   end
   
   -- Setenv
   local setenv = generate_setenv(self.gpack, self.install_path)
   for k, v in pairs(setenv) do
      self.modulefile:write("setenv('" .. v[1] .. "', '" .. v[2] .. "')\n")
   end
   
   -- Prepend path
   local prepend_path = generate_prepend_path(self.gpack, self.install_path)
   for k, v in pairs(prepend_path) do
      if v[1] == "LD_RUN_PATH" then
         self.modulefile:write("if os.getenv(\"GPM_USE_LD_RUN_PATH\") == \"1\" then\n")
         self.modulefile:write("   prepend_path('" .. v[1] .. "', '" .. v[2] .. "')\n")
         self.modulefile:write("end\n")
      else
         self.modulefile:write("prepend_path('" .. v[1] .. "', '" .. v[2] .. "')\n")
      end
   end
end

-- Copy file to correct location
function lmod_installer_class:install_modulefile()
   filesystem.mkdir(self.module_install_path, "", true)
   filesystem.copy (self:file_build_path(), self:file_install_path())
end

function lmod_installer_class:install(gpack, build_path, install_path)
   assert(gpack)
   assert(build_path)
   assert(install_path)
   
   -- Setup
   self.gpack               = gpack
   self.build_path          = build_path
   self.install_path        = install_path
   self.module_install_path = generate_module_install_path(self.gpack)

   logger:message(" Lmod modulefile installer:")
   logger:message("    module_install_path : " .. self.module_install_path)
   
   -- Create file
   self:open_modulefile()
   self:write_modulefile()
   self:close_modulefile()
   
   -- Install file
   self:install_modulefile()
end

-- Update lmod cache files
function lmod_installer_class:update_cache()
   lmod.update_lmod_cache()
end

-- Handle installation of gpackages
local installer_class = class.create_class()

function installer_class:__init()
   self.lmod_installer = lmod_installer_class:create()
   self.downloader     = downloader:create()
   self.gpack          = nil

   self.options = {
      force_download = false,
      force_unpack   = false,
   }

   self.build = {
      build_path   = "",
      source_path  = "",
      unpack_path  = "",
      install_path = "",
      
      log_path    = "",
      unpack_path = "",
   }
end

--- Initialize installation of package.
function installer_class:initialize()
   self.build.build_path = generate_build_path(self.gpack)
   self.build.source_path = path.join(self.build.build_path, self.gpack.nameversion .. "." .. get_extension(self.gpack.url))
   self.build.unpack_path = path.join(self.build.build_path, self.gpack.nameversion)
   self.build.log_path    = path.join(self.build.build_path, self.gpack.nameversion .. ".log")
   self.build.install_path = generate_install_path(self.gpack)

   -- Change directory to build_path
   filesystem.rmdir(self.build.build_path, false)
   filesystem.mkdir(self.build.build_path, {}, true)
   filesystem.chdir(self.build.build_path)
   
   -- Open package log file
   logger:open_logfile("package", self.build.log_path)

   -- Log initialization
   logger:message("Gpackage installer initialized.")
   logger:message("   build_path   : " .. self.build.build_path)
   logger:message("   source_path  : " .. self.build.source_path)
   logger:message("   unpack_path  : " .. self.build.unpack_path)
   logger:message("   install_path : " .. self.build.install_path)
end

--- Finalize installation of package.
function installer_class:finalize()
   -- 
   logger:message("Gpackage installer finalizing.")
   
   -- Close package log file
   logger:close_logfile("package")
   
   -- Change directory back to where we started
   filesystem.chdir(global_config.current_directory)
end

function installer_class:unpack_command()
end

function installer_class:unpack()
   if self.options.force_unpack then
      filesystem.rmdir(self.build.unpack_path, true)
   end
   if not lfs.attributes(self.build.unpack_path, 'mode') then
      filesystem.mkdir(self.build.unpack_path, {}, true)

      local is_tar_gz = string.match(self.build.source_path, "tar.gz" ) or string.match(self.build.source_path, "tgz")
      local is_tar_bz = string.match(self.build.source_path, "tar.bz2") or string.match(self.build.source_path, "tbz2")
      local is_tar_xz = string.match(self.build.source_path, "tar.xz")
      local is_tar    = string.match(self.build.source_path, "tar")
      local is_zip    = string.match(self.build.source_path, "zip")
      local tar_line = nil
      if is_tar_gz then
         tar_line = "tar -zxvf " .. self.build.source_path .. " -C " .. self.build.unpack_path .. " --strip-components=1"
      elseif is_tar_xz then
         tar_line = "tar -xvf "  .. self.build.source_path .. " -C " .. self.build.unpack_path .. " --strip-components=1"
      elseif is_tar_bz then
         tar_line = "tar -jxvf " .. self.build.source_path .. " -C " .. self.build.unpack_path .. " --strip-components=1"
      elseif is_tar then
         tar_line = "tar -xvf "  .. self.build.source_path .. " -C " .. self.build.unpack_path .. " --strip-components=1"
      elseif is_zip then
         tar_line = "unzip "     .. self.build.source_path
      end
      
      local status = util.execute_command(tar_line)
      if status == nil then
         logger:alert("Failed to unpack source file '" .. self.build.source_path .. "'")
         error("FAIL")
      end
   end
end

function installer_class:create_files()
   for _, v in pairs(self.gpack.files) do
      logger:message("Creating file '" .. v[1] .. "'.")
      create_file(v[1], v[2])
   end
end

function installer_class:download(is_git)
   if is_git then
      self.downloader:download(self.gpack.url, self.build.unpack_path)
   else
      self.downloader:download(self.gpack.url, self.build.source_path)
   end
end

function installer_class:build_gpack()
   filesystem.chdir(self.build.unpack_path)
   
   if self.gpack.autotools then
      local ml_cmd = generate_ml_command(self.gpack)
      local configure_command    = ml_cmd .. "./configure --prefix=" .. self.build.install_path
      for k, v in pairs(self.gpack.autotools_args) do
         configure_command = configure_command .. " " .. v
      end
      local make_command         = ml_cmd .. "make -j" .. global_config.nprocesses
      local make_install_command = ml_cmd .. "make install"

      local status_configure    = util.execute_command(configure_command)
      local status_make         = util.execute_command(make_command)
      local status_make_install = util.execute_command(make_install_command)
   elseif self.gpack.cmake then
      local cmake_build_path = path.join(self.build.unpack_path, "build")
      filesystem.mkdir(cmake_build_path)
      filesystem.chdir(cmake_build_path)

      local ml_cmd        = generate_ml_command(self.gpack)
      local cmake_command = ml_cmd .. "cmake ../. -DCMAKE_INSTALL_PREFIX=" .. self.build.install_path
      for k, v in pairs(self.gpack.cmake_args) do
         cmake_command = cmake_command .. " " .. v
      end
      local make_command         = ml_cmd .. "make -j" .. global_config.nprocesses
      local make_install_command = ml_cmd .. "make install"

      local status_cmake        = util.execute_command(cmake_command)
      local status_make         = util.execute_command(make_command)
      local status_make_install = util.execute_command(make_install_command)

      filesystem.chdir(self.build.unpack_path)
   else
      error("Unknown configure method. Use either autotool() or cmake().")
   end
end

function installer_class:post()
   local ml_cmd = generate_ml_command(self.gpack)

   for k, v in pairs(self.gpack.post) do
      local cmd = ml_cmd .. v
      local status = util.execute_command(cmd)

      if status == nil then
         logger:alert("Command '" .. v .. "' failed to execute.")
      end
   end
end

function installer_class:install(gpack)
   self.gpack = gpack

   self:initialize()
   
   self:create_files()
   
   if self.gpack:is_git() then
      self:download(true)
   else
      self:download(false)
      self:unpack()
   end

   self:build_gpack()

   self.lmod_installer:install(self.gpack, self.build.build_path, self.build.install_path)
   self.lmod_installer:update_cache()
   
   self:post()
   self:finalize()
end

-------------------------------------
-- Wrapper for installing a package.
--
-- @param args
-------------------------------------
local function install(args)
   exception.try(function() 
      -- Bootstrap build
      logger:message("BOOTSTRAP PACKAGE")
      args.gpack = args.gpk

      local gpack = gpackage.load_gpackage(args.gpack)
      
      local installer = installer_class:create()
      installer:install(gpack)
      
      --database.load_db(global_config)
      
      --if args.debug then
      --   logger:debug(util.print(package, "package"))
      --end
      
      -- If package is not installed we install it
      --if (util.conditional(database.use_db(), not database.installed(package), true)) or args.force then

         --database.insert_package(package)
         --database.save_db(global_config)
         
         ---- Remove build dir if requested (and various other degress of removing source data)
         --if args.purgebuild then
         --   local status, msg = filesystem.rmdir(package.build_directory, true)
         --   if not status then
         --      print("Could not purge build directory. Reason : '" .. msg .. "'.") 
         --   end
         --else 
         --   if args.delete_source then
         --      local status, msg = filesystem.remove(path.join(package.build_directory, package.build.source_destination))
         --   end
         --   if (not args.keep_build_directory) then
         --      local status, msg = filesystem.rmdir(path.join(package.build_directory, package.definition.pkg), true)
         --      if not status then
         --         print(msg)
         --      end
         --   end
         --end
   --   else
   --      logger:message("Package already installed!")
   --   end
   end, function(e)
      --local status, msg = filesystem.rmdir(package.build_directory, true)
      --if not status then
      --   print("Could not purge build directory after ERROR. Reason : '" .. msg .. "'.") 
      --end
      logger:alert("There was a PROBLEM installing the package")
      error(e)
   end)
end

-- Load module
M.install = install

return M
