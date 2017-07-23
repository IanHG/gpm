local lfs = require "lfs"

local util = require "util"

M = {}

-------------------------------------
-- Read GPM package file (GPK).
--
-- @return{Dictionary} Returns definition og build.
-------------------------------------
local function bootstrap_package(args)
   if args.debug then
      print("Bootstrapping package")
   end

   package = {}
   
   -- Load package file
   if args.gpk then
      filename = args.gpk .. ".gpk"
      filepath = path.join(config.gpk_directory, filename)
   elseif args.gpkf then
      filepath = args.gpkf
   else
      error("Must provide either -gpk or -gpkf option.")
   end
   
   local f, msg = loadfile(filepath)
   if f then
      f()
   else
      error("Error loading package. Reason : '" .. msg .. "'.")
   end
   
   package.description = description
   package.definition = definition
   if build then
      package.build = build
   end
   if lmod then
      package.lmod = lmod
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
               print("VALUE SET : " .. value .. " = " .. p[2]) 
               found = true
               break
            end
         end
         if not found then
            error("Prequisite '" .. value .. "' not set.")
         end
      end
   end
   
   -- Setup build, install and modulefile directories
   build_directory = "build-"
   for key,prereq in util.ordered(package.prerequisite) do
      build_directory = build_directory .. string.gsub(prereq, "/", "-") .. "-"
   end
   build_directory = build_directory .. package.definition.pkg
   package.build_directory = path.join(config.base_build_directory, build_directory)
   
   if package.definition.pkggroup then
      pkginstall = path.join(config.install_directory, package.definition.pkggroup)
      if is_heirarchical(package.definition.pkggroup) then
         for key,prereq in util.ordered(package.prerequisite) do
            pkginstall = path.join(pkginstall, string.gsub(prereq, "/", "-"))
         end
      end
      pkginstall = path.join(path.join(pkginstall, package.definition.pkgname), package.definition.pkgversion)
   else
      pkginstall = config.install_directory
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
   if args.nomodulesource then
      package.nomodulesource = args.nomodulesource
   end

   return package
end


-------------------------------------
--
-- 
-------------------------------------
local function make_package_ready_for_install(package)
   -- Get/download the package
   source = util.substitute_line(package.definition, package.build.source)
   source_extentsion = path.extension(source)
   destination = package.defition.pkg .. source_extension
   
   if package.build.source_type == "git" then
      line = "git clone " .. source .. " " .. package.definition.pkg
      execute_command(line)
   else
      -- if ftp or http download with wget
      is_http_or_ftp = string.gmatch(source, "http://") or string.gmatch(source, "https://") or string.gmatch(source, "ftp://")
      if is_http_or_ftp then
         line = "wget -O " .. destination .. " " .. source
         execute_command(line)
      end
      
      -- Unpak package
      -- If tar file untar
      is_tar_gz = string.gmatch(extension, "tar.gz") or string.gmatch(source, "tgz")
      if is_tar_gz then
         line = "tar -xvf " .. destination
         execute_command(line)
      end
   end

   --for line in string.gmatch(package.build.source, ".*$") do
   --   line = util.substitute_placeholders(package.definition, util.trim(line))
   --   util.execute_command(line)
   --end
end

-------------------------------------
-- Build the package.
--
-- @param package
-------------------------------------
local function build_package(package)
   if package.build then
      -- Load needed modules
      if not package.nomodulesource then
         ml = ". " .. config.install_directory .. "/bin/modules.sh && "
         --for key,value in pairs(package.prerequisite) do
         for key,value in util.ordered(package.prerequisite) do
            ml = ml .. "ml " .. value .. " && "
         end
         print("ML LINE " .. ml)
      end

      -- Download package
      make_package_ready_for_install(package)
      
      -- Build package
      package_directory = path.join(package.build_directory, package.definition.pkg)
      lfs.chdir(package_directory)
      for line in string.gmatch(package.build.command, ".*$") do
         line = util.substitute_placeholders(package.definition, util.trim(line))
         print("LINE : " .. line)
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

-------------------------------------
-- Generate Lmod script.
--
-- @param package
--
-- @return{Boolean}
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
      lmod_file:write("local installDir  = pathJoin(\"" .. path.join(config.install_directory, package.definition.pkggroup) .. "\", packageName)\n")
   end
   
   lmod_file:write("\n")
   lmod_file:write("-- Compiler optional modules setup\n")
   lmod_file:write("local dir = pathJoin(fam, packagePrereq)\n")
   lmod_file:write("prepend_path('MODULEPATH', pathJoin(os.getenv(\"MODULEPATH_ROOT\"), dir))\n")
   lmod_file:write("\n")
   
   lmod_file:write("-- Package specific\n")
   
   -- Do all setenv
   if package.lmod.setenv then
      for key,value in pairs(package.lmod.setenv) do
         lmod_file:write("setenv('" .. value[1] .. "', pathJoin(installDir, '" .. value[2] .. "'))\n")
      end
   end
   
   -- Do all prepend_path
   if package.lmod.prepend_path then
      for key,value in pairs(package.lmod.prepend_path) do
         lmod_file:write("prepend_path('" .. value[1] .. "', pathJoin(installDir, '" .. value[2] .. "'))\n")
      end
   end

   -- Close file after wirting it
   lmod_file:close()

   -- Put the file in the correct place
   modulefile_directory = package.lmod.modulefile_directory
   util.mkdir_recursively(modulefile_directory)
   lmod_filename_new = path.join(modulefile_directory, package.definition.pkgversion .. ".lua")
   print(lmod_filename_new)
   util.copy_file(lmod_filename, lmod_filename_new)
end

-------------------------------------
-- Wrapper for installing a package.
--
-- @param args
-------------------------------------
local function install(args)
   exception.try(function() 
      -- Bootstrap build
      package = bootstrap_package(args)

      if args.debug then
         util.print(package, "package")
      end

      -- Create build dir
      lfs.rmdir(package.build_directory)
      lfs.mkdir(package.build_directory)
      lfs.chdir(package.build_directory)
      
      -- Do the build
      if not args.no_build then
         build_package(package)
      end

      -- Create Lmod file
      if package.lmod and not args.no_lmod then
         build_lmod_modulefile(package)
      end
      
      -- Change back to calling dir
      lfs.chdir(config.current_directory)
      
      -- Remove build dir
      if args.cleanup then
         status, msg = lfs.rmdir(build_directory)
         print("Did not remove build directory. Reason : '" .. msg .. "'.") 
      end
   end, function(e)
      --[[
      status, msg = lfs.rmdir(build_directory)
      if not status then
         print("did not rm dir :C")
      end
      --]]
      error(e)
   end)
end

M.install = install

return M
