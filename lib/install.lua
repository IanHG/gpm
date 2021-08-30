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

local M = {}

--- Open log file. This will log all steps taken
-- when installing the package.
--
-- @param package   The package we are installing.
local function open_log_file(package)
   logpath = path.join(package.build_directory, package.definition.pkg .. ".log")
   logger:open_logfile("package", logpath)
end

--- Close log file after package has been
-- installed succesfully.
--
-- @param package   The package we are installing.
local function close_log_file(package)
   logger:close_logfile("package")
end

--- Create file with name and content.
--
-- @param{String} name     The name of the file.
-- @param{String} content  File content.
local function create_file(name, content, package)
   -- Create filename 
   local name = util.substitute_placeholders(package.definition, name)
   name = path.join(package.build_directory, name)

   -- Create content
   local content = util.substitute_placeholders(package.definition, content)
   
   -- Open file and write content
   cfile = io.open(name, "w")
   cfile:write(content)
   cfile:close()
end

-------------------------------------
-- Split filepath into path, filename, and file extension.
-- Special care needs to be taken for "tar.gz" etc. as 
-- path.split_filename only takes what comes after the last '.' as the extension.
--
-- @param{String} filepath    The path to split.
-- 
-- @return{String,String,String}  Returns path, filename, and extension.
-------------------------------------
local function split_filename(filepath)
   local source_path, source_file, source_ext = path.split_filename(filepath)
   
   local is_tar_gz = string.match(source_file, "tar.gz")
   local is_tar_bz = string.match(source_file, "tar.bz2")
   local is_tar_xz = string.match(source_file, "tar.xz")
   if is_tar_gz then
      source_ext = "tar.gz"
   elseif is_tar_bz then
      source_ext = "tar.bz2"
   elseif is_tar_xz then
      source_ext = "tar.xz"
   end

   return source_path, source_file, source_ext
end


-------------------------------------
-- Make the package files ready for installation.
-- This includes getting the package, either downloaded from a remote location or 
-- copied from a local file. 
-- Also unpacks the source if it is zipped or tarball.
-- When the function has run, there should be a directory with the package source
-- with the name of the package, e.g. gcc-6.3.0.
-- This directory is used to build the package.
-- 
-- @param{Table}  package   The package we are installing.
-------------------------------------
local function make_package_ready_for_install(package)
   -- Create files defined in .gpk
   if package.build.files then
      for _,f in pairs(package.build.files) do
         create_file(f[1], f[2], package)
      end
   end
   
   -- Get/download the package
   local source = util.substitute_placeholders(package.definition, package.build.source)
   local source_path, source_file, source_ext = split_filename(source)
   if source_ext == "git" then
      package.build.source_type = "git"
   end

   local source_file_strip = string.gsub(source_file, "%." .. source_ext, "")
   local destination 
   if package.build.source_type == "git" then
      destination = package.definition.pkg
   else
      destination = package.definition.pkg .. "." .. source_ext
   end

   package.build.source_destination = destination
   
   local dl = downloader:create()
   dl:download(source, destination)
   
   if package.build.source_type ~= "git" then
      --if (not filesystem.exists(path.join(package.build_directory, package.definition.pkg))) then
      --   line = "git clone --recursive " .. source .. " " .. package.definition.pkg
      --   util.execute_command(line)
      --end
      
      -- Unpak package
      -- If tar file untar
      if package.forceunpack then
         filesystem.rmdir(path.join(package.build_directory, package.definition.pkg), true)
      end
      if not lfs.attributes(path.join(package.build_directory, package.definition.pkg), 'mode') then
         local is_tar_gz = string.match(source_file, "tar.gz") or string.match(source_file, "tgz")
         local is_tar_bz = string.match(source_file, "tar.bz2") or string.match(source_file, "tbz2")
         local is_tar_xz = string.match(source_file, "tar.xz")
         local is_tar    = string.match(source_file, "tar")
         local is_zip = string.match(source_file, "zip")
         local tar_line = ""
         if is_tar_gz then
            tar_line = "tar -zxvf " .. destination .. " --transform 's/" .. source_file_strip .. "/" .. package.definition.pkg .. "/'"
         elseif is_tar_xz then
            tar_line = "tar -xvf " .. destination .. " --transform 's/" .. source_file_strip .. "/" .. package.definition.pkg .. "/'"
         elseif is_tar_bz then
            --line = "tar -jxvf " .. destination
            tar_line = "tar -jxvf " .. destination .. " --transform 's/" .. source_file_strip .. "/" .. package.definition.pkg .. "/'"
         elseif is_tar then
            tar_line = "tar -xvf " .. destination .. " --transform 's/" .. source_file_strip .. "/" .. package.definition.pkg .. "/'"
         elseif is_zip then
            tar_line = "unzip " .. destination
         end
         util.execute_command(tar_line)
      end
   end
   
   -- Create install directory
   local status, msg = filesystem.mkdir(package.definition.pkginstall, {}, true)
end

-------------------------------------
-- Build the package. 
-- This includes downloading the source, and making files ready for install,
-- loading all needed modules and in the end building the current package.
--
-- @param{Table} package   The package to install.
-------------------------------------
local function build_package(package)
   if package.build then
      -- Load needed modules
      if not package.nomodulesource then
         ml = ". " .. global_config.stack_path .. "/bin/modules.sh --link-relative --force && "
         
         for key,value in util.ordered(package.prerequisite) do
            ml = ml .. "ml " .. value .. " && "
         end
         for key,value in util.ordered(package.dependson) do
            ml = ml .. "ml " .. value .. " && "
         end
         for key,value in util.ordered(package.moduleload) do
            ml = ml .. "ml " .. value .. " && "
         end
      end

      -- Download package
      make_package_ready_for_install(package)
      
      -- Build package
      package_directory = path.join(package.build_directory, package.definition.pkg)
      filesystem.chdir(package_directory)
      for line in string.gmatch(package.build.command, ".*$") do
         line = util.substitute_placeholders(package.definition, util.trim(line))
         if not (line == ""  or line == "\n") then
            if ml then
               util.execute_command(ml .. line)
            else
               util.execute_command(line)
            end
         end
      end
   end
end

--- Helper function to generate prepend_path for lmod.
-- 
-- This function will handle exports for directories named "include".
-- It will export both to INCLUDE, C_INCLUDE_PATH, CPLUS_INCLUDE_PATH.
--
-- @param{String}  include             "include".
-- @param{Table}   prepend_path        Will be appended with new paths for lmod to prepend.
-- @param{String}  install_directory   The directory.
local function generate_prepend_path_include(include, prepend_path, install_directory)
   -- Insert in paths
   table.insert(prepend_path, {"INCLUDE", include})
   table.insert(prepend_path, {"C_INCLUDE_PATH", include})
   table.insert(prepend_path, {"CPLUS_INCLUDE_PATH", include})
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
-- @param{String}  install_directory   The directory.
local function generate_prepend_path_lib(lib, prepend_path, install_directory)
   -- Insert in paths
   table.insert(prepend_path, {"LIBRARY_PATH", lib})
   table.insert(prepend_path, {"LD_LIBRARY_PATH", lib})
   table.insert(prepend_path, {"LD_RUN_PATH", lib})
   
   -- Check for pgkconfig
   for file in lfs.dir(path.join(install_directory, lib)) do
      if file:match("pkgconfig") then
         table.insert(prepend_path, {"PKG_CONFIG_PATH", path.join(lib, "pkgconfig")})
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
-- @param{String}  install_directory   The directory.
local function generate_prepend_path_share(share, prepend_path, install_directory)
   for f in lfs.dir(path.join(install_directory, "share")) do
      if f:match("info") then
         table.insert(prepend_path, {"INFOPATH", "share/info"})
      elseif f:match("man") then
         table.insert(prepend_path, {"MANPATH", "share/man"})
      end
   end
end

--- Automatically generate which env variables to prepend by looking at what is present in install directory.
--
-- Will automatically generate a table of paths the lmod script should prepend.
-- This is done based on the directories present in the install directory for the package.
--
-- @param{Table}  package  The package we are installing.
local function generate_prepend_path(package)
   -- If .gpk provides one we just use that
   if package.lmod.prepend_path then
      if global_config.debug then
         logger:debug("Taking prepend_path from .gpk file ( no auto-generation ).", nil, {io.stdout})
      end
      return package.lmod.prepend_path
   end

   -- Else we try to generate one auto-magically
   prepend_path = {}
   install_directory = package.definition.pkginstall
   for directory in lfs.dir(install_directory) do
      if directory:match("bin") then
         table.insert(prepend_path, {"PATH", "bin"})
      elseif directory:match("include") then
         generate_prepend_path_include("include", prepend_path, install_directory)
      elseif directory:match("lib64") then
         generate_prepend_path_lib("lib64", prepend_path, install_directory)
      elseif directory:match("lib$") then
         generate_prepend_path_lib("lib", prepend_path, install_directory)
      elseif directory:match("share") then
         generate_prepend_path_share("share", prepend_path, install_directory)
      elseif directory:match("libexec") then
         -- do nothing
      elseif directory:match("etc") then
         -- do nothing
      elseif directory:match("var") then
         -- do nothing
      end
   end

   -- Add any additions from .gpk
   if package.lmod.prepend_path_add then
      for _,v in pairs(package.lmod.prepend_path_add) do 
         table.insert(prepend_path, v)
      end
   end
   
   -- At last we return the constructed prepend_path table
   return prepend_path
end

-------------------------------------
-- Generate Lmod script for package, and place in the correct place.
--
-- @param{Table} package  The package we are installing.
-------------------------------------
local function build_lmod_modulefile(package)
   lmod_filename = path.join(package.build_directory, package.definition.pkgversion .. ".lua")
   lmod_file = io.open(lmod_filename, "w")

   lmod_file:write("-- -*- lua -*-\n")
   lmod_file:write("help(\n")
   lmod_file:write("[[\n")
   if package.lmod.help then
      lmod_file:write(util.substitute_placeholders(package.definition, package.lmod.help) .. "\n")
   end
   lmod_file:write("]])\n")
   lmod_file:write("------------------------------------------------------------------------\n")
   lmod_file:write("-- This file was generated automagically by Grendel Package Manager (GPM)\n")
   lmod_file:write("------------------------------------------------------------------------\n")
   lmod_file:write("-- Description\n")
   lmod_file:write("whatis([[\n")
   lmod_file:write(util.substitute_placeholders(package.definition, package.description))
   lmod_file:write("]])\n")
   lmod_file:write("\n")
   lmod_file:write("-- Set family\n")
   lmod_file:write("local fam = \"" .. package.definition.pkgfamily .. "\"\n")
   lmod_file:write("family(fam)\n")
   lmod_file:write("\n")
   lmod_file:write("-- Basic module setup\n")
   lmod_file:write("local version     = myModuleVersion()\n")
   lmod_file:write("local name        = myModuleName()\n")
   lmod_file:write("local fileName    = myFileName()\n")
   lmod_file:write("local nameVersion = pathJoin(name, version)\n")
   
   if packages.is_heirarchical(package.definition.pkggroup) and package.nprerequisite ~= 0 then
      lmod_file:write("local prereq = string.match(fileName,\"/" .. package.lmod.base .. "/(.-)/\" .. nameVersion:gsub(\"-\", \"?-\"))\n")
      lmod_file:write("local packagePrereq = pathJoin(prereq, nameVersion)\n")
      lmod_file:write("local packageName = pathJoin(prereq:gsub(\"[^/]+/[^/]+\", function (str) return str:gsub(\"/\", \"-\") end), nameVersion)\n")
   else
      lmod_file:write("local packagePrereq = nameVersion\n")
      lmod_file:write("local packageName = nameVersion\n")
   end

   if package.lmod.install_path then
      lmod_file:write("local installDir  = \"" .. package.lmod.install_path .. "\"\n")
   else
      lmod_file:write("local installDir  = pathJoin(\"" .. path.join(global_config.stack_path, package.definition.pkggroup) .. "\", packageName)\n")
   end
   lmod_file:write("\n")

   if (not packages.is_heirarchical(package.definition.pkggroup)) and package.prerequisite then
      for key, prereq in pairs(package.prerequisite) do
         if tonumber(key) == nil then
            lmod_file:write("depends_on(\"" .. prereq .. "\")\n")
         end
      end
   end
   
   if package.dependson then
      for key, prereq in pairs(package.dependson) do
         if tonumber(key) == nil then
            lmod_file:write("depends_on(\"" .. prereq .. "\")\n")
         end
      end
   end
   
   lmod_file:write("\n")
   lmod_file:write("-- Optional modules setup\n")
   lmod_file:write("local dir = pathJoin(fam, packagePrereq)\n")
   lmod_file:write("for str in os.getenv(\"MODULEPATH_ROOT\"):gmatch(\"([^:]+)\") do\n")
   lmod_file:write("   prepend_path('MODULEPATH', pathJoin(str, dir))\n")
   lmod_file:write("end\n")
   lmod_file:write("\n")
   
   lmod_file:write("-- Package specific\n")
   
   -- Do all setenv
   if package.lmod.setenv then
      for key,value in pairs(package.lmod.setenv) do
         dir = util.substitute_placeholders(package.definition, value[2])
         lmod_file:write("setenv('" .. value[1] .. "', pathJoin(installDir, '" .. dir .. "'))\n")
      end
   end
   
   -- Do all setenv_abs (i.e. do not prepend installDir)
   if package.lmod.setenv_abs then
      for key,value in pairs(package.lmod.setenv_abs) do
         dir = util.substitute_placeholders(package.definition, value[2])
         lmod_file:write("setenv('" .. value[1] .. "','" .. dir .. "')\n")
      end
   end
   
   -- Do all prepend_path
   prepend_path = generate_prepend_path(package)
   for key,value in pairs(prepend_path) do
      dir = util.substitute_placeholders(package.definition, value[2])
      if value[1] == "LD_RUN_PATH" then
         lmod_file:write("if os.getenv(\"GPM_USE_LD_RUN_PATH\") == \"1\" then\n")
         lmod_file:write("   prepend_path('" .. value[1] .. "', pathJoin(installDir, '" .. dir .. "'))\n")
         lmod_file:write("end\n")
      else
         lmod_file:write("prepend_path('" .. value[1] .. "', pathJoin(installDir, '" .. dir .. "'))\n")
      end
   end

   if package.lmod.prepend_path_abs then
      for key,value in pairs(package.lmod.prepend_path_abs) do
         dir = util.substitute_placeholders(package.definition, value[2])
         lmod_file:write("prepend_path('" .. value[1] .. "','" .. dir .. "')\n")
      end
   end

   -- Close file after wirting it
   lmod_file:close()

   -- Put the file in the correct place
   local modulefile_directory = package.lmod.modulefile_directory
   --util.mkdir_recursively(modulefile_directory)
   filesystem.mkdir(modulefile_directory, "", true)
   local lmod_filename_new = path.join(modulefile_directory, package.definition.pkgversion .. ".lua")
   filesystem.copy(lmod_filename, lmod_filename_new)
end

---
--
--
--
local function setup_lmod_for_lmod(package)
   -- Create lmod modules directory
   local modulefile_directory = package.lmod.modulefile_directory
   filesystem.mkdir(modulefile_directory, "", true)
   
   local lmod_filename_1   = package.definition.pkginstall .. "/lmod/" .. package.definition.pkgversion .. "/modulefiles/Core/lmod.lua"
   local lmod_filename_new = path.join(modulefile_directory, package.definition.pkgversion .. ".lua")
   local status            = filesystem.copy(lmod_filename_1, lmod_filename_new)
   if not status then
      local lmod_filename_2 = path.join(package.definition.pkginstall .. "/lmod/" .. package.definition.pkgversion .. "/modulefiles/Core/lmod/", package.definition.pkgversion .. ".lua")
      local status          = filesystem.copy(lmod_filename_2, lmod_filename_new)
      if not status then
         error("Cannot copy lmod modules file.")
      end
   end
   
   -- Create settarg modules directory
   local settarg_modulefile_directory = package.lmod.modulefile_directory:gsub("lmod", "settarg")
   filesystem.mkdir(settarg_modulefile_directory, "", true)
   
   --local settarg_filename     = path.join(package.definition.pkginstall .. "/lmod/" .. package.definition.pkgversion .. "/modulefiles/Core/settarg/", package.definition.pkgversion .. ".lua")
   local settarg_filename     = package.definition.pkginstall .. "/lmod/" .. package.definition.pkgversion .. "/modulefiles/Core/settarg.lua"
   local settarg_filename_new = path.join(settarg_modulefile_directory, package.definition.pkgversion .. ".lua")
   filesystem.copy(settarg_filename, settarg_filename_new)
end

---
--
--
local function postprocess_package(package)
   if package.post.command then
      local ml = ". " .. global_config.stack_path .. "/bin/modules.sh --link-relative --force && "
      for key,value in util.ordered(package.prerequisite) do
         ml = ml .. "ml " .. value .. " && "
      end
      local cmd = ml .. package.post.command
      cmd = util.substitute_placeholders(package.definition, util.trim(cmd))
      util.execute_command(cmd)
   end
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
      local package = packages.bootstrap(args)
      database.load_db(global_config)
      
      if args.debug then
         logger:debug(util.print(package, "package"))
      end
      
      -- If package is not installed we install it
      if (util.conditional(database.use_db(), not database.installed(package), true)) or args.force then

         -- Create build dir
         logger:message("BUILD DIR")
         logger:message(package.build_directory)
         
         filesystem.rmdir(package.build_directory, false)
         filesystem.mkdir(package.build_directory, {}, true)
         filesystem.chdir(package.build_directory)
         
         -- Open a log file
         open_log_file(package)
         
         -- Do the build
         if not args.no_build then
            build_package(package)
         end

         -- Create Lmod file
         if package.lmod and not args.no_lmod then
            build_lmod_modulefile(package)
         elseif package.is_lmod then
            setup_lmod_for_lmod(package)
         end
         
         -- Change back to calling dir
         filesystem.chdir(global_config.current_directory)

         -- Post process
         postprocess_package(package)

         --
         lmod.update_lmod_cache(package)

         database.insert_package(package)
         database.save_db(global_config)
         
         -- 
         logger:message("Succesfully installed '" .. package.definition.pkg .. "'")

         -- Close log file
         close_log_file(package)
         
         -- Remove build dir if requested (and various other degress of removing source data)
         if args.purgebuild then
            local status, msg = filesystem.rmdir(package.build_directory, true)
            if not status then
               print("Could not purge build directory. Reason : '" .. msg .. "'.") 
            end
         else 
            if args.delete_source then
               local status, msg = filesystem.remove(path.join(package.build_directory, package.build.source_destination))
            end
            if (not args.keep_build_directory) then
               local status, msg = filesystem.rmdir(path.join(package.build_directory, package.definition.pkg), true)
               if not status then
                  print(msg)
               end
            end
         end
      else
         logger:message("Package already installed!")
      end
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
