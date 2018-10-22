local logging    = assert(require "lib.logging")
local logger     = logging.logger
local path       = assert(require "lib.path")
local util       = assert(require "lib.util")
local filesystem = assert(require "lib.filesystem")
local class      = assert(require "lib.class")
local gpackage   = assert(require "lib.gpackage")

local package_class = class.create_class()

function package_class:__init()
   self.gpack_version = 1
end

function package_class:is_git_source()
   return (self.build.source_type == "git")
end

local M = {}

--- Locate gpk file by searching gpk_path.
--
-- @param args   The input arguments.
-- @param config A config.
--
-- @return   Returns gpk filename as string.
local function locate_gpk_file(args, config)
   if not config then
      config = global_config
   end

   -- Initialize to nil
   local filepath = nil

   -- Try to locate gpk file
   if args.gpk then
      local gl = gpackage.create_locator()
      gl.ext = ".gpk"
      filepath = gl:locate(args.gpk)
      ----local filename = args.gpk .. ".gpk"
      --local function locate_gpk_impl()
      --   for gpk_path in path.iterator(config.gpk_path) do
      --      if(global_config.debug) then
      --         logger:debug("Checking path : " .. gpk_path)
      --      end

      --      -- Check for abs path
      --      if not path.is_abs_path(gpk_path) then
      --         gpk_path = path.join(config.stack_path, gpk_path)
      --      end
      --      
      --      -- Create filename
      --      local filepath = path.join(gpk_path, filename)
      --      
      --      -- Check for existance
      --      if filesystem.exists(filepath) then
      --         return filepath
      --      end
      --   end
      --end
      --filepath = locate_gpk_impl()
   elseif args.gpkf then
      filepath = args.gpkf
   else
      error("Must provide either -gpk or -gpkf option.")
   end
   
   -- Return found path
   return filepath
end

--- Load .gpk file into the program.
-- 
-- @param filepath    Path to file.
-- @param package     Package object.
local function load_gpk_file(filepath, package)
   local f, msg = assert(loadfile(filepath))
   if f then
      f()
   else
      error("Error loading package. Reason : '" .. msg .. "'.")
   end
   
   logger:message("GPK : " .. filepath)
   
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
end

---
-- Is pkgtype a hierarchical one?
--
-- @param{String} pkgtype
--
-- @param{Boolean} 
local function is_heirarchical(pkgtype)
   for key,value in pairs(global_config.heirarchical) do
      if pkgtype == value then
         return true
      end
   end
   return false
end

---
-- Check package validity.
--
-- @param{Table} 
--
-- @return{bool, String} Return true if package is valid, and false otherwise. 
--                       If false a string describing the error is also returned.
local function is_valid(package)
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

--- Set build path for package
-- 
-- @param package   The package to set build directory for.
local function set_build_path(package)
   -- Create build path
   local build_directory = "build-"
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

   -- Set build path in package table
   package.build_directory = path.join(global_config.base_build_directory, build_directory)
   package.definition.pkgbuild = package.build_directory
end

--- Set install path for package
--
-- @param package   The package to set install path for.
local function set_install_path(package)
   -- Create install path
   local pkginstall = ""
   if package.definition.pkggroup then
      pkginstall = path.join(global_config.stack_path, package.definition.pkggroup)
      if is_heirarchical(package.definition.pkggroup) then
         for key,prereq in util.ordered(package.prerequisite) do
            pkginstall = path.join(pkginstall, string.gsub(prereq, "/", "-"))
         end
      end
      pkginstall = path.join(path.join(pkginstall, package.definition.pkgname), package.definition.pkgversion)
   else
      -- Special care for lmod
      if package.definition.pkgname == "lmod" then
         pkginstall = global_config.stack_path
      else
         pkginstall = path.join(path.join(global_config.stack_path, package.definition.pkgname), package.definition.pkgversion)
      end
   end

   -- Set install path
   package.definition.pkginstall = pkginstall
end

--- Read GPM package file (GPK).
--
-- Bootstrap package dictionary by reading .gpk file and command line arguments.
--
-- @return{Table} Returns definition of build.
local function bootstrap(args)
   -- Do some debug printout if requested
   if args.debug then
      logger:debug("Bootstrapping package")
   end
   
   -- Create local package table
   local package = package_class:create()
   
   -- Load the gpk file
   local filepath = assert(locate_gpk_file(args, global_config))
   load_gpk_file(filepath, package)
   
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
   set_build_path  (package)
   set_install_path(package)
   
   -- Lmod stuff
   if package.lmod then
      lmod_base = package.definition.pkggroup
      if is_heirarchical(package.definition.pkggroup) then
         if prerequisite then
            nprereq = #prerequisite
         else
            nprereq = 0
         end

         if nprereq ~= 0 then
            lmod_base = prerequisite[nprereq]
         end
      end

      package.lmod.base = lmod_base
      package.nprerequisite = nprereq
      package.lmod.modulefile_directory = path.join(global_config.lmod_directory, lmod_base)
      
      if is_heirarchical(package.definition.pkggroup) then
         for key,prereq in util.ordered(package.prerequisite) do
            package.lmod.modulefile_directory = path.join(package.lmod.modulefile_directory, prereq)
         end
      end
      
      package.lmod.modulefile_directory = path.join(package.lmod.modulefile_directory, package.definition.pkgname)
   end
   
   -- Miscellaneous (spellcheck? :) )
   package.definition.nprocesses = global_config.nprocesses
   package.nomodulesource = util.conditional(args.nomodulesource, args.nomodulesource, false)
   package.forcedownload  = util.conditional(args.force_download, args.force_download, false)
   package.forceunpack    = util.conditional(args.force_unpack  , args.force_unpack  , false)
   package.is_lmod        = util.conditional(args.is_lmod       , true               , false)

   -- check package validity
   check, reason = is_valid(package)

   if not check then
      error("Package not valid: " .. reason)
   end

   if args.debug then
      logger:debug("Done bootstrapping package")
   end

   -- return package
   return package
end


-- Load module
M.is_heirarchical     = is_heirarchical
M.is_valid            = is_valid
M.bootstrap           = bootstrap
M.prerequisite_string = prerequisite_string

return M
