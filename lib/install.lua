local lfs = require "lfs"

local util = require "util"
local path = require "path"
local filesystem = require "filesystem"
local exception = require "exception"
local logging = require "logging"

M = {}

-------------------------------------
-- Check package validity.
--
-- @param{Table} 
--
-- @return{bool, String} Return true if package is valid, and false otherwise. 
--                       If false a string describing the error is also returned.
-------------------------------------
local function check_package_is_valid(package)
   if not package.nomodulesource then
      if package.build then
         if not package.build.source then
            return false, "No source"
         end
      end
   end
   
   -- If we reach here package is valid and ready for installation
   return true, "Success"
end

-------------------------------------
-- Is pkgtype a hierarchical one?
--
-- @param{String} pkgtype
--
-- @param{Boolean} 
-------------------------------------
function is_heirarchical(pkgtype)
   for key,value in pairs(config.heirarchical) do
      if pkgtype == value then
         return true
      end
   end
   return false
end

--- Locate gpk file by searching gpk_path.
--
-- @param args   The input arguments.
--
-- @return   Returns gpk filename as string.
local function locate_gpk_file(args)
   -- Initialize to nil
   local filepath = nil

   -- Try to locate gpk file
   if args.gpk then
      local filename = args.gpk .. ".gpk"
      local function locate_gpk_impl()
         for gpk_path in path.iterator(config.gpk_path) do
            -- Check for abs path
            if not path.is_abs_path(gpk_path) then
               gpk_path = path.join(config.stack_path, gpk_path)
            end
            
            -- Create filename
            local filepath = path.join(gpk_path, filename)
            
            -- Check for existance
            if filesystem.exists(filepath) then
               return filepath
            end
         end
         return nil
      end
      filepath = locate_gpk_impl()
   elseif args.gpkf then
      filepath = args.gpkf
   else
      error("Must provide either -gpk or -gpkf option.")
   end
   
   -- Return found path
   return filepath
end

-------------------------------------
-- Read GPM package file (GPK).
--
-- @return{Table} Returns definition of build.
-------------------------------------
local function bootstrap_package(args)
   if args.debug then
      logging.debug("Bootstrapping package", io.stdout)
   end

   package = {}
   
   -- Load the gpk file
   local filepath = assert(locate_gpk_file(args))
   
   local f, msg = loadfile(filepath)
   if f then
      f()
   else
      error("Error loading package. Reason : '" .. msg .. "'.")
   end
   
   logging.message("GPK : " .. filepath, io.stdout)
   
   package.description = description
   package.definition = definition
   if build then
      package.build = build
      if args.source then
         package.build.source = args.source
      end
   end
   if lmod then
      package.lmod = lmod
   else
      package.lmod = {}
   end

   if post then
      package.post = post
   else
      package.post = {}
   end
   
   -- Setup some version numbers and other needed variables
   package.definition.pkgversion = args.pkv
   version_array = util.split(args.pkv, ".")
   if version_array[1] then
      package.definition.pkgmajor = version_array[1]
   end
   if version_array[2] then
      package.definition.pkgminor = version_array[2]
   end
   if version_array[3] then
      package.definition.pkgrevision = version_array[3]
   end
   package.definition.pkg = package.definition.pkgname .. "-" .. package.definition.pkgversion

   -- Bootstrap prerequisite
   package.prerequisite = util.ordered_table({})
   if #prerequisite ~= 0 then
      prereq_array = util.split(args.prereq, ",")
      for key, value in pairs(prerequisite) do
         found = false
         for count = 1, #prereq_array do
            p = util.split(prereq_array[count], "=")
            if value == p[1] then
               package.prerequisite[value] = p[2]
               found = true
               break
            end
         end
         if not found then
            error("Prequisite '" .. value .. "' not set.")
         end
      end
   elseif args.prereq then
      prereq_array = util.split(args.prereq, ",")
      for count = 1, #prereq_array do
         p = util.split(prereq_array[count], "=")
         if not p[2] then
            package.prerequisite["prereq" .. count] = p[1]
         else
            package.prerequisite[p[1]] = p[2]
         end
      end
   end
   
   package.dependson = util.ordered_table({})
   if args.depends_on then
      do_array = util.split(args.depends_on, ",")
      for count = 1, #do_array do
         d = util.split(do_array[count], "=")
         if not d[2] then
            package.dependson["dependson" .. count] = d[1]
         else
            package.dependson[d[1]] = d[2]
         end
      end
   elseif depends_on then
      do_array = util.split(depends_on, ",")
      for count = 1, #do_array do
         d = util.split(do_array[count], "=")
         if not d[2] then
            package.dependson["dependson" .. count] = d[1]
         else
            package.dependson[d[1]] = d[2]
         end
      end
   end

   package.moduleload = util.ordered_table({})
   if args.moduleload then
      ml_array = util.split(args.moduleload, ",")
      for count = 1, #ml_array do
         m = util.split(ml_array[count], "=")
         if not m[2] then
            package.moduleload["moduleload" .. count] = m[1]
         else
            package.moduleload[m[1]] = m[2]
         end
      end
   end
   
   -- Setup build, install and modulefile directories
   build_directory = "build-"
   for key,prereq in util.ordered(package.prerequisite) do
      build_directory = build_directory .. string.gsub(prereq, "/", "-") .. "-"
   end
   for key,prereq in util.ordered(package.dependson) do
      build_directory = build_directory .. string.gsub(prereq, "/", "-") .. "-"
   end
   for key,prereq in util.ordered(package.moduleload) do
      build_directory = build_directory .. string.gsub(prereq, "/", "-") .. "-"
   end
   build_directory = build_directory .. package.definition.pkg
   package.build_directory = path.join(config.base_build_directory, build_directory)
   package.definition.pkgbuild = package.build_directory
   
   if package.definition.pkggroup then
      pkginstall = path.join(config.stack_path, package.definition.pkggroup)
      if is_heirarchical(package.definition.pkggroup) then
         for key,prereq in util.ordered(package.prerequisite) do
            pkginstall = path.join(pkginstall, string.gsub(prereq, "/", "-"))
         end
      end
      pkginstall = path.join(path.join(pkginstall, package.definition.pkgname), package.definition.pkgversion)
   else
      -- Special care for lmod
      if package.definition.pkgname == "lmod" then
         pkginstall = config.stack_path
      else
         pkginstall = path.join(path.join(config.stack_path, package.definition.pkgname), package.definition.pkgversion)
      end
   end
   package.definition.pkginstall = pkginstall
   
   -- Lmod stuff
   if package.lmod then
      lmod_base = package.definition.pkggroup
      if is_heirarchical(package.definition.pkggroup) then
         if prerequisite then
            nprereq = #prerequisite
         else
            nprereq = 0
         end
         --for _ in pairs(package.prerequisite) do
         --   nprereq = nprereq + 1
         --end

         if nprereq ~= 0 then
            lmod_base = prerequisite[nprereq]
         end
      end

      package.lmod.base = lmod_base
      package.nprerequisite = nprereq
      package.lmod.modulefile_directory = path.join(config.lmod_directory, lmod_base)
      
      if is_heirarchical(package.definition.pkggroup) then
         for key,prereq in util.ordered(package.prerequisite) do
            package.lmod.modulefile_directory = path.join(package.lmod.modulefile_directory, prereq)
         end
      end
      
      package.lmod.modulefile_directory = path.join(package.lmod.modulefile_directory, package.definition.pkgname)
   end
   
   -- Miscellaneous (spellcheck? :) )
   package.definition.nprocesses = config.nprocesses
   --if args.nomodulesource then
   --   package.nomodulesource = args.nomodulesource
   --end
   package.nomodulesource = util.conditional(args.nomodulesource, args.nomodulesource, false)
   package.forcedownload  = util.conditional(args.force_download, args.force_download, false)
   package.forceunpack    = util.conditional(args.force_unpack  , args.force_unpack  , false)
   package.is_lmod        = util.conditional(args.is_lmod       , true               , false)

   -- check package validity
   check, reason = check_package_is_valid(package)
   if not check then
      error("Package not valid: " .. reason)
   end

   if args.debug then
      logging.debug("Done bootstrapping package", io.stdout)
   end

   -- return package
   return package
end

-------------------------------------
-- Open log file. This will log all steps taken
-- when installing the package.
--
-- @param package   The package we are installing.
-------------------------------------
local function open_log_file(package)
   logpath = path.join(package.build_directory, package.definition.pkg .. ".log")
   package.logfile = io.open(logpath, "w")
   package.log = {package.logfile, io.stdout}
end

-------------------------------------
-- Close log file after package has been
-- installed succesfully.
--
-- @param package   The package we are installing.
-------------------------------------
local function close_log_file(package)
   package.logfile:close()
end

-------------------------------------
-- Create file with name and content.
--
-- @param{String} name     The name of the file.
-- @param{String} content  File content.
-------------------------------------
local function create_file(name, content, package)
   name = util.substitute_placeholders(package.definition, name)
   name = path.join(package.build_directory, name)
   content = util.substitute_placeholders(package.definition, content)
   
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
   source_path, source_file, source_ext = path.split_filename(source)
   
   is_tar_gz = string.match(source_file, "tar.gz")
   is_tar_bz = string.match(source_file, "tar.bz2")
   is_tar_xz = string.match(source_file, "tar.xz")
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
   source = util.substitute_placeholders(package.definition, package.build.source)
   source_path, source_file, source_ext = split_filename(source)
   source_file_strip = string.gsub(source_file, "%." .. source_ext, "")
   destination = package.definition.pkg .. "." .. source_ext
   package.build.source_destination = destination
   print(source_file_strip)
   
   if package.build.source_type == "git" then
      if (not filesystem.exists(path.join(package.build_directory, package.definition.pkg))) then
         line = "git clone " .. source .. " " .. package.definition.pkg
         util.execute_command(line, package.log)
      end
   else
      -- if ftp or http download with wget
      print("source:")
      print(source) 
      local status = 0
      if package.forcedownload then
         filesystem.remove(path.join(package.build_directory, destination))
      end
      if not lfs.attributes(path.join(package.build_directory, destination), 'mode') then
         is_http_or_ftp = string.match(source, "http://") or string.match(source, "https://") or string.match(source, "ftp://")
         print(is_http_or_ftp)
         if is_http_or_ftp then
            line = "wget --progress=dot -O " .. destination .. " " .. source
            status = util.execute_command(line, package.log)
         else -- we assume local file
            line = "cp " .. source .. " " .. destination
            status = util.execute_command(line, package.log)
         end
      end
      if status ~= 0 then
         filesystem.remove(path.join(package.build_directory, destination))
         error("Could not retrive source...")
      end
      
      -- Unpak package
      -- If tar file untar
      if package.forceunpack then
         filesystem.rmdir(path.join(package.build_directory, package.definition.pkg), true)
      end
      if not lfs.attributes(path.join(package.build_directory, package.definition.pkg), 'mode') then
         is_tar_gz = string.match(source_file, "tar.gz") or string.match(source_file, "tgz")
         is_tar_bz = string.match(source_file, "tar.bz2") or string.match(source_file, "tbz2")
         is_tar_xz = string.match(source_file, "tar.xz")
         is_tar    = string.match(source_file, "tar")
         is_zip = string.match(source_file, "zip")
         if is_tar_gz or is_tar_xz then
            line = "tar -zxvf " .. destination .. " --transform 's/" .. source_file_strip .. "/" .. package.definition.pkg .. "/'"
            util.execute_command(line, package.log)
         elseif is_tar_bz then
            --line = "tar -jxvf " .. destination
            line = "tar -jxvf " .. destination .. " --transform 's/" .. source_file_strip .. "/" .. package.definition.pkg .. "/'"
            util.execute_command(line, package.log)
         elseif is_tar then
            line = "tar -xvf " .. destination .. " --transform 's/" .. source_file_strip .. "/" .. package.definition.pkg .. "/'"
            util.execute_command(line, package.log)
         elseif is_zip then
            line = "unzip " .. destination
            util.execute_command(line, package.log)
         end
      end
   end
   
   status, msg = filesystem.mkdir(package.definition.pkginstall, {}, true)

   --for line in string.gmatch(package.build.source, ".*$") do
   --   line = util.substitute_placeholders(package.definition, util.trim(line))
   --   util.execute_command(line, package.log)
   --end
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
         ml = ". " .. config.stack_path .. "/bin/modules.sh --link-relative --force && "
         --for key,value in pairs(package.prerequisite) do
         for key,value in util.ordered(package.prerequisite) do
            ml = ml .. "ml " .. value .. " && "
         end
         for key,value in util.ordered(package.dependson) do
            ml = ml .. "ml " .. value .. " && "
         end
         for key,value in util.ordered(package.moduleload) do
            ml = ml .. "ml " .. value .. " && "
         end
         print("ML LINE " .. ml)
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
               util.execute_command(ml .. line, package.log)
            else
               util.execute_command(line, package.log)
            end
         end
      end
   end
end

-------------------------------------
-- Helper function to generate prepend_path for lmod.
-- This function will handle exports for directories named "include".
-- It will export both to INCLUDE, C_INCLUDE_PATH, CPLUS_INCLUDE_PATH.
--
-- @param{String}  include             "include".
-- @param{Table}   prepend_path        Will be appended with new paths for lmod to prepend.
-- @param{String}  install_directory   The directory.
-------------------------------------
local function generate_prepend_path_include(include, prepend_path, install_directory)
   -- Insert in paths
   table.insert(prepend_path, {"INCLUDE", include})
   table.insert(prepend_path, {"C_INCLUDE_PATH", include})
   table.insert(prepend_path, {"CPLUS_INCLUDE_PATH", include})
end

-------------------------------------
-- Helper function to generate prepend_path for lmod.
-- This function will handle exports for directories named "lib" or "lib64.
-- It will export both to LIBRARY_PATH, LD_LIBRARY_PATH, and LD_RUN_PATH.
-- It will look for a directory called pkgconfig, which it will add to
-- PKG_CONFIG_PATH if found.
--
-- @param{String}  lib                 "lib" or "lib64".
-- @param{Table}   prepend_path        Will be appended with new paths for lmod to prepend.
-- @param{String}  install_directory   The directory.
-------------------------------------
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

-------------------------------------
-- Helper function to generate prepend_path for lmod.
-- This function will handle exports for "share" directory.
-- Will look for "info" and "man", and if found will prepend to
-- "INFOPATH" and "MANPATH" respectively.
--
-- @param{String}  share               Always "share" (for now).
-- @param{Table}   prepend_path        Will be appended with new paths for lmod to prepend.
-- @param{String}  install_directory   The directory.
-------------------------------------
local function generate_prepend_path_share(share, prepend_path, install_directory)
   for f in lfs.dir(path.join(install_directory, "share")) do
      if f:match("info") then
         table.insert(prepend_path, {"INFOPATH", "share/info"})
      elseif f:match("man") then
         table.insert(prepend_path, {"MANPATH", "share/man"})
      end
   end
end

-------------------------------------
-- Will automatically generate a table of paths the lmod script should prepend.
-- This is done based on the directories present in the install directory for the package.
--
-- @param{Table}  package  The package we are installing.
-------------------------------------
local function generate_prepend_path(package)
   -- If .gpk provides one we just use that
   if package.lmod.prepend_path then
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
   if package.lmod.preped_path_add then
      for _,v in pairs(package.lmod.preped_path_add) do 
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
   lmod_file:write(util.substitute_placeholders(package.definition, package.lmod.help) .. "\n")
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
   
   if is_heirarchical(package.definition.pkggroup) and package.nprerequisite ~= 0 then
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
      lmod_file:write("local installDir  = pathJoin(\"" .. path.join(config.stack_path, package.definition.pkggroup) .. "\", packageName)\n")
   end
   lmod_file:write("\n")

   if (not is_heirarchical(package.definition.pkggroup)) and package.prerequisite then
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
   
   local lmod_filename     = path.join(package.definition.pkginstall .. "/lmod/" .. package.definition.pkgversion .. "/modulefiles/Core/lmod/", package.definition.pkgversion .. ".lua")
   local lmod_filename_new = path.join(modulefile_directory, package.definition.pkgversion .. ".lua")
   print("LMOD : ")
   print("old : " .. lmod_filename)
   print("new : " .. lmod_filename_new)
   filesystem.copy(lmod_filename, lmod_filename_new)
   
   -- Create settarg modules directory
   local settarg_modulefile_directory = package.lmod.modulefile_directory:gsub("lmod", "settarg")
   filesystem.mkdir(settarg_modulefile_directory, "", true)
   
   local settarg_filename     = path.join(package.definition.pkginstall .. "/lmod/" .. package.definition.pkgversion .. "/modulefiles/Core/settarg/", package.definition.pkgversion .. ".lua")
   local settarg_filename_new = path.join(settarg_modulefile_directory, package.definition.pkgversion .. ".lua")
   print("SET ARG : ")
   print("old : " .. settarg_filename)
   print("new : " .. settarg_filename_new)
   filesystem.copy(settarg_filename, settarg_filename_new)
end

---
--
--
local function postprocess_package(package)
   if package.post.command then
      local ml = ". " .. config.stack_path .. "/bin/modules.sh --link-relative --force && "
      for key,value in util.ordered(package.prerequisite) do
         ml = ml .. "ml " .. value .. " && "
      end
      local cmd = ml .. package.post.command
      cmd = util.substitute_placeholders(package.definition, util.trim(cmd))
      util.execute_command(cmd, package.log)
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
      logging.message("BOOTSTRAP PACKAGE", io.stdout)
      package = bootstrap_package(args)

      if args.debug then
         logging.debug(util.print(package, "package"), io.stdout)
      end

      -- Create build dir
      logging.message("BUILD DIR", io.stdout)
      logging.message(package.build_directory, io.stdout)
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
      filesystem.chdir(config.current_directory)

      -- Post process
      postprocess_package(package)
      
      -- 
      logging.message("Succesfully installed '" .. package.definition.pkg .. "'", package.log)

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
   end, function(e)
      --local status, msg = filesystem.rmdir(package.build_directory, true)
      --if not status then
      --   print("Could not purge build directory after ERROR. Reason : '" .. msg .. "'.") 
      --end
      logging.alert("There was a PROBLEM installing the package", io.stdout)
      error(e)
   end)
end

M.bootstrap_package = bootstrap_package
M.install = install

return M
