local lfs = assert(require "lfs")

local util        = assert(require "lib.util")
local path        = assert(require "lib.path")
local filesystem  = assert(require "lib.filesystem")
local exception   = assert(require "lib.exception")
local logging     = assert(require "lib.logging")
local logger      = logging.logger
local database    = assert(require "lib.database")
local lmod        = assert(require "lib.lmod")
local downloader  = assert(require "lib.downloader")
local class       = assert(require "lib.class")
local gpackage    = assert(require "lib.gpackage")
local commander   = assert(require "lib.commander")
local execcmd     = assert(require "lib.execcmd")
local pathhandler = assert(require "lib.pathhandler")
local symbtab     = assert(require "lib.symbtab")
local env         = assert(require "lib.env")
local version     = assert(require "lib.version")
local signature   = assert(require "lib.signature")

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

local function generate_ml_command(gpack, include_self)
   local ml_cmd = ". " .. global_config.stack_path .. "/bin/modules.sh --link-relative --force && "
   
   for k, _ in util.ordered(gpack.dependencies.heirarchical) do
      ml_cmd = ml_cmd .. "ml " .. k.name .. "/" .. k.version .. " && "
   end
   
   for k, v in pairs(gpack.dependencies.dependson) do
      print(v.name)
      print(v.version)
      ml_cmd = ml_cmd .. "ml " .. v.name .. "/" .. v.version .. " && "
   end
   
   for k, v in pairs(gpack.dependencies.load) do
      ml_cmd = ml_cmd .. "ml " .. v.name .. "/" .. v.version .. " && "
   end

   if include_self then
      ml_cmd = ml_cmd .. "ml " .. gpack.name .. "/" .. gpack.version .. " && "
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
      
      -- Take care of heirachical dependencies
      for prereq, _ in util.ordered(gpack.dependencies.heirarchical) do
         install_path = path.join(install_path, prereq.name .. "-" .. prereq.version)
      end
      
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
   local module_group  = gpack.lmod.group
   
   -- Take care of heirarchial dependencies
   local heirarchical = gpack.dependencies.heirarchical
   
   if #heirarchical > 0 then
      nprereq = #heirarchical
   else
      nprereq = 0
   end

   if nprereq ~= 0 then
      module_group = heirarchical[nprereq].group
   end
   
   module_install_path = path.join(module_install_path, module_group)

   for prereq, _ in util.ordered(heirarchical) do
      module_install_path = path.join(module_install_path, path.join(prereq.name, prereq.version))
   end
  
   -- Append name of new package
   module_install_path = path.join(module_install_path, gpack.name)

   return module_install_path
   
end

-- Generate setenv 
local function generate_setenv(gpack, install_path, setenv)
   if setenv == nil then
      setenv = {}
   end

   if gpack.lmod.setenv then
      for _, v in pairs(gpack.lmod.setenv) do
         if not util.isempty(v[2]) then
            table.insert(setenv, {v[1], path.join(install_path, v[2])})
         else
            table.insert(setenv, {v[1], install_path})
         end
      end
   end
   
   if gpack.lmod.setenv_abs then
      for _, v in pairs(gpack.lmod.setenv_abs) do
         -- Abs path cannot be empty
         assert(not util.isempty(v[2]))
         print("HERE")
         print(v[1], v[2])
         table.insert(setenv, v)
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
      elseif f:match("pkgconfig") then
         table.insert(prepend_path, {"PKG_CONFIG_PATH" , path.join(install_path, "share/pkgconfig" )})
      end
   end
end

--- Automatically generate which env variables to prepend by looking at what is present in install directory.
--
-- Will automatically generate a table of paths the lmod script should prepend.
-- This is done based on the directories present in the install directory for the package.
--
-- @param  gpack   The gpackage we are installing.
local function generate_prepend_path(gpack, install_path, prepend_path)
   if prepend_path == nil then
      prepend_path = {}
   end

   local function generate_prepend_path_auto(install_path)
      for directory in lfs.dir(install_path) do
         if directory:match("^bin$") then
            table.insert(prepend_path, {"PATH", path.join(install_path, "bin")})
         elseif directory:match("^include$") then
            generate_prepend_path_include("include", prepend_path, install_path)
         elseif directory:match("^lib64$") then
            generate_prepend_path_lib("lib64", prepend_path, install_path)
         elseif directory:match("^lib$") then
            print(directory)
            generate_prepend_path_lib("lib", prepend_path, install_path)
         elseif directory:match("^share$") then
            generate_prepend_path_share("share", prepend_path, install_path)
         elseif directory:match("^libexec$") then
            -- do nothing
         elseif directory:match("^etc$") then
            -- do nothing
         elseif directory:match("^var$") then
            -- do nothing
         end
      end
   end
   
   -- Try to auto-generate
   if gpack.lmod.autopath then
      generate_prepend_path_auto(install_path)
   end

   for key, value in pairs(gpack.lmod.autopaths) do
      if path.is_rel_path(value) then
         value = path.join(install_path, value)
      end
      generate_prepend_path_auto(value)
   end
   
   -- Add paths from package
   if gpack.lmod.prepend_path then
      for _, v in pairs(gpack.lmod.prepend_path) do
         table.insert(prepend_path, { v[1], path.join(install_path, v[2]), v[3]} )
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


local builder_class = class.create_class()

function builder_class:__init(executor, creator, options)
   self.executor = executor
   self.creator  = creator

   self.tag = options.tag
   self.n_jobs = options.n_jobs
   
   -- Some internals
   self._ml_cmd   = nil
end

function builder_class:_generate_exec_command(cmd)
   local  command = self._ml_cmd .. cmd
   return command
end

function builder_class:_generate_cmake_exec_command(build, cmakeargs)
   local cmake_command = self._ml_cmd .. "cmake ../. -DCMAKE_INSTALL_PREFIX=" .. build.install_path
   for k, v in pairs(cmakeargs) do
      cmake_command = cmake_command .. " " .. v
   end
   return cmake_command
end

function builder_class:_generate_configure_exec_command(build, configargs)
   local configure_command = self._ml_cmd .. "./configure --prefix=" .. build.install_path
   for k, v in pairs(configargs) do
      configure_command = configure_command .. " " .. v
   end
   return configure_command
end

function builder_class:_generate_make_exec_command(make_type, args)
   local  make_command = self._ml_cmd .. "make -j" .. self.n_jobs
   if args then
      for key, value in pairs(args) do
         make_command = make_command .. " " .. value
      end
   end
   if make_type then
      make_command = make_command .. " " .. make_type
   end
   return make_command
end

function builder_class:_generate_copy_exec_command(build, p)
   local copy_command = "cp"
   if filesystem.isdir(p) then
      copy_command = copy_command .. " -r"
   end
   local source = nil
   if path.is_abs_path(p) then
      source = p
   else
      source = path.join(build.unpack_path, p)
   end
   
   copy_command = copy_command .. " " .. source .. " " .. build.install_path

   return copy_command
end

function builder_class:_locate_build(gpack, build_definition)
   if #gpack.builds == 0 then
      logger:alert("No build...")
      assert(false)
   elseif #gpack.builds == 1 then
      return gpack.builds[1]
   else
      local function match_version(match_version, check_version)
         local function parse_match_version(match_version)
            if     string.match(match_version, ">=") then
               return string.gsub(match_version, ">=", ""), ">="
            elseif string.match(match_version, ">") then
               return string.gsub(match_version, ">" , ""), ">"
            elseif string.match(match_version, "<=") then
               return string.gsub(match_version, "<=", ""), "<="
            elseif string.match(match_version, "<") then
               return string.gsub(match_version, "<" , ""), "<"
            elseif string.match(match_version, "=") then
               return string.gsub(match_version, "=" , ""), "="
            else
               return match_version, "="
            end
         end

         local match_version, match_operator = parse_match_version(match_version)
         local function match(m, c, last) 
            if match_operator == ">" then
               return c > m
            elseif match_operator == ">=" then
               if last then
                  return c >= m
               else
                  return c > m
               end
            elseif match_operator == "<" then
               return c < m
            elseif match_operator == "<=" then
               if last then
                  return c <= m
               else
                  return c < m
               end
            elseif match_operator == "=" then
               return c == m
            else
               return c == m
            end
         end

         local match_split = util.split(match_version, ".")
         local check_split = util.split(check_version, ".")
         --print("check")
         --for k,v in pairs(check_split) do
         --   print(k)
         --   print(v)
         --end
         --print("match")
         --for k,v in pairs(match_split) do
         --   print(k)
         --   print(v)
         --end
         --assert(#check_split >= #match_split)
         --local n_min = math.min(#check_split, #match_split)
         --for i = 1, n_min do
         --   if match(match_split[i], check_split[i], true) then
         --      if match_split[i] ~= check_split[i] then
         --         return true
         --      end
         --   else
         --      return false
         --   end
         --end

         return false
      end

      local function match_build_version(build, version)
         if build.tags ~= nil then
            if build.tags.version ~= nil then
               if match_version(build.tags.version, version) then
                  return true
               end
            end
         end

         return false
      end

      for k, v in pairs(gpack.builds) do
         if (build_definition.tag == nil and v.tags.tag == nil) or (v.tags.tag == build_definition.tag) then
            if match_build_version(v, gpack.version) then
               return v
            end
         end
      end
      
      -- If we have a tag we check for a build with no version
      if build_definition.tag ~= nil then
         for k, v in pairs(gpack.builds) do
            if (v.tags.tag == build_definition.tag) and (v.tags.version == nil) then
               return v
            end
         end
      else
         -- If nothing was found, we return the first build without a tag
         for k, v in pairs(gpack.builds) do
            if v.tags.tag == nil then
               return v
            end
         end
      end
   end

   logger:alert("No build found")
   assert(false)
end

function builder_class:install(gpack, build_definition, build)
   self._ml_cmd = generate_ml_command(gpack)

   local gpack_build   = self:_locate_build(gpack, build_definition)
   local command_stack = {}
   if not gpack_build.commands then
      gpack_build.commands = {
         { command = gpack_build.btype },
         { command = "configure" },
         { command = "make" },
         { command = "makeinstall" },
      }
   end

   for k, v in pairs(gpack_build.commands) do
      if v.command == "autoconf" then
         table.insert(command_stack, self.creator:command("exec", { command = self:_generate_exec_command("autoconf") }))
      elseif v.command == "cmake" then
         table.insert(command_stack, self.creator:command("exec", { command = self:_generate_cmake_exec_command(build, v.options.options) }))
      elseif v.command == "configure" then
         table.insert(command_stack, self.creator:command("exec", { command = self:_generate_configure_exec_command(build, v.options.options) }))
      elseif v.command == "make" then
         table.insert(command_stack, self.creator:command("exec", { command = self:_generate_make_exec_command(nil,       v.options.options) }))
      elseif v.command == "makeinstall" then
         table.insert(command_stack, self.creator:command("exec", { command = self:_generate_make_exec_command("install", v.options.options) }))
      elseif v.command == "shell" then
         table.insert(command_stack, self.creator:command("exec", { command = self:_generate_exec_command(v.options.cmd) }))
      elseif v.command == "chdir" then
         table.insert(command_stack, self.creator:command("chdir", { dir = v.options.dir }))
      elseif v.command == "install" then
         table.insert(command_stack, self.creator:command("mkdir", { path = build.install_path, mode = {}, recursive = true }))
         for k, v in pairs(v.options.install) do
            table.insert(command_stack, self.creator:command("exec", { command = self:_generate_copy_exec_command(build, v)}))
         end
      elseif v.command == "pushdir" then
         table.insert(command_stack, self.creator:command("mkdir", { path = v.options.dir, mode = {}, recursive = true }))
         table.insert(command_stack, self.creator:command("chdir", { path = v.options.dir }))
      elseif v.command == "popdir" then
         table.insert(command_stack, self.creator:command("popdir", { }))
      elseif v.command == "prepend_env" then
         table.insert(command_stack, self.creator:command("prepend_env", v.options ))
      elseif v.command == "set_env" then
         table.insert(command_stack, self.creator:command("set_env", v.options ))
      end
   end

   -- Make substitutions in command stack
   local st = symbtab.create()
   st:add_symbol("build"  , build.build_path)
   st:add_symbol("install", build.install_path)
   st:add_symbol("install_dbl_slash", build.install_path:gsub("/", "\\/"))
   for k, v in pairs(command_stack) do
      v:substitute(st)
   end
   
   -- Execute build commands
   if gpack_build.btype == "cmake" then
      local cmake_build_path = path.join(build.unpack_path, "build")
      filesystem.mkdir(cmake_build_path)
      filesystem.chdir(cmake_build_path)
   end

   self.executor:execute(command_stack)
   
   if gpack_build.btype == "cmake" then
      filesystem.chdir(build.unpack_path)
   end
end

-- Handle "install" of lmod stuff (module file)
local lmod_installer_class = class.create_class()

function lmod_installer_class:__init()
   -- Settings
   self.gpack        = nil
   self.build_path   = nil
   self.install_path = nil
   
   -- Internal work 
   self.modulefile   = nil

   self.symbtab = nil
end

function lmod_installer_class:file_build_path()
   return path.join(self.build_path, self.gpack.version .. ".lua")
end

function lmod_installer_class:file_install_path()
   local filename
   if self.gpack.lmod.name then
      filename = self.gpack.lmod.name
   else
      filename = self.gpack.version
   end

   return path.join(self.module_install_path, filename .. ".lua")
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
   self.modulefile:write("-------------------------------------------------------------------------\n")
   self.modulefile:write("-- This file was generated automagically by Grendel Package Manager (GPM)\n")
   self.modulefile:write("-- \n")
   self.modulefile:write("-- Generated by GPM Version : " .. version.get_version_number() .. " \n")
   self.modulefile:write("-------------------------------------------------------------------------\n")
   self.modulefile:write("-- Description\n")
   self.modulefile:write("whatis([[\n")
   self.modulefile:write(self.gpack.description .. "\n")
   self.modulefile:write("]])\n")
   self.modulefile:write("\n")
   self.modulefile:write("-- Set family\n")
   local first = true
   for k, v in pairs(self.gpack.lmod.family) do
      self.modulefile:write("family(\"" .. v[1] .. "\")\n")
      if first then
         self.modulefile:write("local fam = \"" .. v[1] .. "\"\n")
      end
      first = false
   end

   self.modulefile:write("\n")
   self.modulefile:write("-- Basic module setup\n")
   self.modulefile:write("local version       = myModuleVersion()\n")
   self.modulefile:write("local name          = myModuleName()\n")
   self.modulefile:write("local fileName      = myFileName()\n")
   self.modulefile:write("local nameVersion   = pathJoin(name, version)\n")
   self.modulefile:write("local packagePrereq = nameVersion\n")
   
   -- Heirarchial
   self.modulefile:write("\n")
   self.modulefile:write("-- Heirarchical modules setup\n")
   self.modulefile:write("local dir = pathJoin(fam and fam or name, packagePrereq)\n")
   self.modulefile:write("for str in os.getenv(\"MODULEPATH_ROOT\"):gmatch(\"([^:]+)\") do\n")
   self.modulefile:write("   prepend_path('MODULEPATH', pathJoin(str, dir))\n")
   self.modulefile:write("end\n")
   self.modulefile:write("\n")
   
   -- Dependencies
   for k, v in pairs(self.gpack.dependencies.dependson) do
      self.modulefile:write("depends_on(\"" .. v.name .. "/" .. v.version .. "\")\n")
   end
   
   ---
   -- Setup package
   --
   self.modulefile:write("-- Package enviroment\n")
   
   -- Alias
   for k, v in pairs(self.gpack.lmod.alias) do
      self.modulefile:write("set_alias('" .. v[1] .. "', '" .. self.symbtab:substitute(v[2]) .. "')\n")
   end
   
   -- Setenv
   local setenv = generate_setenv(self.gpack, self.install_path)
   for k, v in pairs(setenv) do
      self.modulefile:write("setenv('" .. v[1] .. "', '" .. self.symbtab:substitute(v[2]) .. "')\n")
   end
   
   -- Prepend path
   local prepend_path = generate_prepend_path(self.gpack, self.install_path)
   for k, v in pairs(prepend_path) do
      local tab = ""
      if v[1] == "LD_RUN_PATH" then
         self.modulefile:write("if os.getenv(\"GPM_USE_LD_RUN_PATH\") == \"1\" then\n")
         tab = "   "
      end
      if(v[3]) then
         self.modulefile:write(tab .. "prepend_path('" .. v[1] .. "', '" .. self.symbtab:substitute(v[2]) .. "', '" .. v[3] .. "')\n")
      else
         self.modulefile:write(tab .. "prepend_path('" .. v[1] .. "', '" .. self.symbtab:substitute(v[2]) .. "')\n")
      end
      if v[1] == "LD_RUN_PATH" then
         self.modulefile:write("end\n")
      end
   end
end

-- Copy file to correct location
function lmod_installer_class:install_modulefile()
   filesystem.mkdir(self.module_install_path, "", true)
   filesystem.copy (self:file_build_path(), self:file_install_path())
end

-- Create and install lmod script files.
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
   self.symbtab        = symbtab.create()
   self.lmod_installer = lmod_installer_class:create()
   self.lmod_installer.symbtab = symbtab.create(self.symbtab)
   self.pathhandler    = pathhandler.create()
   self.downloader     = downloader.create()
   self.executor       = commander.create_executor({}, logger)
   self.creator        = commander.create_creator ({}, logger)
   self.creator:add("exec", function(options, input, output)
      input.logger:message("Running in shell : '" .. options.command .. "'.")
      local out = { out = "", logger = input.logger }
      local status = execcmd.execcmd_bashexec(options.command, out)

      output.status = status
      output.output = {
         stdout = out.out
      }
   end)
   self.creator:add("chdir", function(options, input, output)
      self.pathhandler:push(options.path)
      output.status = 0
      output.output = {}
   end)
   self.creator:add("popdir", function(options, input, output)
      self.pathhandler:pop()
      output.status = 0
      output.output = {}
   end)
   self.creator:add("mkdir", function(options, input, output)
      local status, error_msg, error_code  = filesystem.mkdir(options.path, options.mode, options.recursive)
      output.status = status
      output.stdout = error_msg
      output.output = {}
   end)
   self.creator:add("prepend_env", function(options, input, output)
      local status = env.prepend_env(options.name, options.value, options.delimeter)
      output.status = status
      output.output = {}
   end)
   self.creator:add("set_env", function(options, input, output)
      input.logger:message("Set ENV : '" .. options.name .. " = " .. options.value .. "'.")
      local status = env.set_env(options.name, options.value)
      input.logger:message("     status : '" .. tostring(status))
      output.status = status
      output.output = {}
   end)

   self.gpack          = nil

   self.options = {
      force_download = false,
      force_unpack   = false,
      purge          = false,
      keep_source    = true,
      keep_build     = false,
   }

   self.build = {
      build_path   = "",
      unpack_path  = "",
      install_path = "",
      
      log_path    = "",
      unpack_path = "",
   }

end

--- Initialize installation of package.
function installer_class:initialize()
   -- Generate paths
   self.build.build_path     = generate_build_path(self.gpack)
   self.build.unpack_path    = path.join(self.build.build_path, self.gpack.nameversion)
   self.build.log_path       = path.join(self.build.build_path, self.gpack.nameversion .. ".log")
   self.build.install_path   = generate_install_path(self.gpack)

   -- Add symbols to symbol table
   self.symbtab:add_symbol("build",   self.build.build_path  )
   self.symbtab:add_symbol("install", self.build.install_path)
   
   -- Assert that we have access to different paths
   if filesystem.exists(self.build.build_path) then
      if (global_config.user.euid ~= -1) and (filesystem.owner(self.build.build_path) ~= global_config.user.euid) then
         error("Build path '" .. self.build.build_path .. "' not owned by current user.")
      end
   end
   if filesystem.exists(self.build.install_path) then
      if (global_config.user.euid ~= -1) and (filesystem.owner(self.build.install_path) ~= global_config.user.euid) then
         error("Install path '" .. self.build.install_path .. "' not owned by current user.")
      end
   end

   -- Change directory to build_path
   filesystem.rmdir(self.build.build_path, true)
   filesystem.mkdir(self.build.build_path, {}, true)
   self.pathhandler:push(self.build.build_path)
   
   -- Open package log file
   logger:open_logfile("package", self.build.log_path)

   -- Log initialization
   logger:message("Gpackage installer initialized.")
   logger:message("   build_path   : " .. self.build.build_path)
   logger:message("   unpack_path  : " .. self.build.unpack_path)
   logger:message("   install_path : " .. self.build.install_path)
end

--- Finalize installation of package.
function installer_class:finalize()
   -- 
   logger:message("Gpackage installer finalizing.")
   
   -- Close package log file
   logger:close_logfile("package")

   -- Check for purge and keep source/build
   if self.options.purge then
      filesystem.rmdir(self.build.build_path, true)
   else
      if not self.options.keep_source then
         for key, value in pairs(self.sources) do
            filesystem.remove(value.source_path)
         end
      end
      if not self.options.keep_build then
         for key, value in pairs(self.sources) do
            filesystem.rmdir(value.unpack_path, true)
         end
      end
   end

   -- Change directory back to where we started
   filesystem.chdir(global_config.current_directory)
   
   -- Print name and version of the package we just installed
   if(self.gpack) then
      logger:message("Installed " .. self.gpack.nameversion);
   end
end

-- Create unpacking command
function installer_class:unpack_command()
end

-- Unpack source code before building
function installer_class:unpack()
   -- check for force unpack
   if self.options.force_unpack then
      filesystem.rmdir(self.build.unpack_path, true)
   end

   -- Define local function for unpacking
   local function unpack_source_file(source_path, unpack_path)
      if not unpack_path then
         unpack_path = self.build.unpack_path
      end

      local is_tar_gz = string.match(source_path, "tar.gz" ) or string.match(source_path, "tgz")
      local is_tar_bz = string.match(source_path, "tar.bz2") or string.match(source_path, "tbz2")
      local is_tar_xz = string.match(source_path, "tar.xz")
      local is_tar    = string.match(source_path, "tar")
      local is_zip    = string.match(source_path, "zip")
      local is_rpm    = string.match(source_path, "rpm")
      
      -- If its not something we know how to unpack (e.g. a .sh script), we just return 
      if not (is_tar_gz or is_tar_bz or is_tar_xz or is_tar or is_zip or is_rpm) then
         return
      end
      
      -- Find longest common prefix, if not empty will strip 1 directory
      local tar_line_strip = nil
      local n_strip = 0
      if is_tar_gz then
         tar_line_strip = "tar -ztf "
      elseif is_tar_gz then
         tar_line_strip = "tar -jtf "
      elseif is_tar_xz or is_tar then
         tar_line_strip = "tar -tf "
      end
      
      if tar_line_strip then
         tar_line_strip = tar_line_strip .. source_path
         
         local output = { output = tostring("") }
         local status = util.execute_command(tar_line_strip, true, output)
         if status then
            local split  = util.split(output.output, "\n")
            local size   = #split
            
            -- Remove lines start with '+' (this is the tar command itself)
            for i = 1, size do
               if split[i]:gmatch("^+") then
                  for j = i + 1, size do
                     split[j - 1] = split[j]
                  end
                  size = size - 1
               end
            end

            local prefix = util.lcp(split)
            if util.isempty(prefix) then
               n_strip = 0
            else
               n_strip = 1
            end
         end
      end

      local tar_line  = nil
      if is_tar_gz then
         tar_line = "tar -zxvf " .. source_path .. " -C " .. unpack_path .. " --strip-components=" .. tostring(n_strip)
      elseif is_tar_xz then
         tar_line = "tar -xvf "  .. source_path .. " -C " .. unpack_path .. " --strip-components=" .. tostring(n_strip)
      elseif is_tar_bz then
         tar_line = "tar -jxvf " .. source_path .. " -C " .. unpack_path .. " --strip-components=" .. tostring(n_strip)
      elseif is_tar then
         tar_line = "tar -xvf "  .. source_path .. " -C " .. unpack_path .. " --strip-components=" .. tostring(n_strip)
      elseif is_zip then
         tar_line = "unzip "     .. source_path
      elseif is_rpm then
         tar_line = "cd " .. unpack_path .. "; rpm2cpio " .. source_path .. " | cpio --no-absolute-filenames -idmv"
      end
      
      local status = util.execute_command(tar_line)
      if status == nil then
         logger:alert("Failed to unpack source file '" .. source_path .. "'")
         error("FAIL")
      end
   end

   -- Check what to unpack
   for key, value in pairs(self.sources) do
      if value.unpack_path then
         if not lfs.attributes(value.unpack_path, 'mode') then
            self.sources[key].mark_for_unpack = true
         else
            self.sources[key].mark_for_unpack = false
         end
      else
         self.sources[key].mark_for_unpack = false
      end
   end

   -- Do unpacking
   for key, value in pairs(self.sources) do
      if value.mark_for_unpack then
         filesystem.mkdir(value.unpack_path, {}, true)
         unpack_source_file(value.source_path, value.unpack_path)
      end
   end
end

-- Create needed files
function installer_class:create_files()
   for _, v in pairs(self.gpack.files) do
      logger:message("Creating file '" .. v[1] .. "'.")
      create_file(self.symbtab:substitute(v[1]), self.symbtab:substitute(v[2]))
   end
end

-- Download source code
function installer_class:download(is_git)
   self.sources = {}
   
   local count = 1
   for key, value in pairs(self.gpack.urls) do
      local unpack_path = nil
      if value.unpack then
         if (not is_git) and (value.unpack == "do_not_unpack") then
            unpack_path = nil
         else
            unpack_path = value.unpack
         end
      else
         unpack_path = self.build.unpack_path
      end
      local source_path = nil
      if is_git then
         source_path = self.build.unpack_path
      else
         local _, filename, extension = path.split_filename(value.url)
         source_path     = path.join(self.build.build_path, filename) 
         if not string.match(filename, extension) then
            source_path = source_path .. "." .. extension
         end
      end

      local status = self.downloader:download(value.url, source_path, self.options.force_download)
      
      if not status then
         logger:alert("Could not download package : '" .. value.url .. "'.")
         assert(false)
      end
      
      -- download signature file
      if value.sig then
         logger:message("Checking file signature")
         local _, filename, extension = path.split_filename(value.sig)
         local sig_path = path.join(self.build.build_path, filename) 

         status = self.downloader:download(value.sig, sig_path, self.options.force_download)
         if not status then
            logger:alert("Could not download file signature : '" .. value.sig .. "'.")
            assert(false)
         end

         local sig_checker = signature.create()
         local is_signed   = sig_checker:check_signature(source_path, sig_path)
         
         -- check signature
         if (not is_signed) then
            logger:alert("Could not verify source signature.")
            assert(false)
         end
      else
         logger:message("Not checking file signature")
      end

      table.insert(self.sources, {source_path = source_path, unpack_path = unpack_path})
   end

end

-- Build the package
function installer_class:build_gpack()
   self.pathhandler:push(self.build.unpack_path)
   --filesystem.chdir(self.build.unpack_path)
   
   local builder = builder_class:create(nil, self.executor, self.creator, { tag = self.tag, n_jobs = self.gpack.n_jobs})
   builder:install(self.gpack, self.build_definition, self.build)
end

-- Do post install commands
function installer_class:post()
   local ml_cmd = generate_ml_command(self.gpack, true)

   for k, v in pairs(self.gpack.post) do
      local cmd    = ml_cmd .. v[1]
      local status = util.execute_command(cmd)

      if status == nil then
         logger:alert("Command '" .. v[1] .. "' failed to execute.")
      end
   end
end

-- Install package
function installer_class:install(gpack, build_definition)
   self.gpack = gpack
   self.build_definition = build_definition

   self:initialize()
   
   self:create_files()
   
   if self.gpack:is_git() then
      self:download(true)
   else
      self:download(false)
      self:unpack()
   end

   self:build_gpack()
   
   if self.gpack.lmod.is_set then
      self.lmod_installer:install(self.gpack, self.build.build_path, self.build.install_path)
      self.lmod_installer:update_cache()
   end
   
   self:post()
   self:finalize()
end

local function run_installer(args, gpack, build_definition, force)
   if force == nil then
      force = args.force
   end

   if (util.conditional(database.use_db(), not database.installed(gpack), true)) or force then
      -- Install gpack
      local installer = installer_class:create()
      installer.options.force_download = args.force_download
      installer.options.purge          = args.purge_build
      installer.options.keep_source    = not args.remove_source
      installer.options.keep_build     = args.keep_build or args.keep_build_directory
      installer:install(gpack, build_definition)
   
      database.insert_package(gpack)
   else
      logger:message("Package already installed!")
   end
end

local function check_and_fix_dependencies(args, gpack)
   local function install_dependency(depend)
      --local name_version = depend.name
      --if not util.isempty(depend.version) then
      --   name_version = name_version .. "@" .. depend.version
      --end
      --if not util.isempty(depend.tag) then
      --   name_version = name_version .. ":" .. depend.tag
      --end
      
      local gpack_depend = gpackage.load_gpackage(depend)
      
      -- Check dependencies
      check_and_fix_dependencies(args, gpack_depend)

      run_installer(args, gpack_depend, depend, util.conditional(args.force_dependencies, true, false))
   end

   -- Check and install dependson
   for k, v in pairs(gpack.dependencies.dependson) do
      install_dependency(v)
   end
   
   -- Check and install load
   for k, v in pairs(gpack.dependencies.load) do
      install_dependency(v)
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
      logger:message("BOOTSTRAP PACKAGE NEW")
      
      -- Load database
      database.load_db(global_config)
      
      for kgpack, vgpack in pairs(args.gpack) do
         local build_definition = gpackage.create_build_definition({}, args)
         build_definition:initialize(vgpack)
         
         -- Load gpack
         local gpack = gpackage.load_gpackage(build_definition)
         
         -- Check dependencies
         check_and_fix_dependencies(args, gpack)

         -- Install package
         run_installer(args, gpack, build_definition)
      end
      
      -- Save database
      database.save_db(global_config)
   end, function(e)
      logger:alert("There was a PROBLEM installing the package")
      error(e)
   end)
end

-- Load module
M.install = install

return M
