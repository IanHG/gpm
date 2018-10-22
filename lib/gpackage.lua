local M = {}

local filesystem = assert(require "lib.filesystem")
local class   = assert(require "lib.class")
local util    = assert(require "lib.util")
local path    = assert(require "lib.path")
local logging = assert(require "lib.logging")
local logger  = logging.logger
local downloader  = assert(require "lib.downloader")
local symbtab     = assert(require "lib.symbtab")
local ftable = assert(require "lib.ftable" )
local luautil = assert(require "lib.luautil" )

local function get_gpack_name_version(name)
   local split = util.split(name, "@")
   if #split == 1 then
      return split[1], nil
   elseif #split == 2 then
      return split[1], split[2]
   else
      assert(false)
   end
end

local function pack(...)
   return { ... }

   --if not table.pack then
   --   table.pack = function(...)
   --      return { n = select("#", ...), ...}
   --   end
   --end
end

local function dofile_into_environment(filename, env)
   function readall(file)
      local f = assert(io.open(file, "rb"))
      local content = f:read("*all")
      f:close()
      return content
   end

   setmetatable ( env, { __index = _G } )
   local status = nil
   local result = nil
   if luautil.version() == "Lua 5.1" then
      status, result = assert(pcall(setfenv(assert(loadfile(filename)), env)))
   else
      local content  = readall(filename)
      status, result = assert(pcall(load(content, nil, nil, env)))
   end
   setmetatable(env, nil)
   return result
end

local function get_name(gpackage_path)
   local p, f, e = path.split_filename(gpackage_path)
   return f:gsub("." .. e, "")
end

local build_definition_class = class.create_class()

function build_definition_class:__init(args)
   -- Definition
   self.version_prefix = "@"
   self.tag_prefix     = ":"
   
   --
   self.name     = nil
   self.version  = nil
   self.tag      = nil
   
   if args ~= nil then
      self.url      = args.url
   else
      self.url = nil
   end
end

function build_definition_class:initialize(name_version_tag)
   local match_pattern   = "["  .. self.version_prefix .. self.tag_prefix .. "]"
   local nomatch_pattern = "[^" .. self.version_prefix .. self.tag_prefix .. "]"
   local pattern = "(" .. match_pattern .. nomatch_pattern .. "*)"
   
   -- Loop over pattern matches
   while true do
      local match = string.match(name_version_tag, pattern)
      if match == nil then
         -- If no match we break the loop
         break
      end

      if string.match(match, self.tag_prefix) then
         self.tag = string.gsub(match, self.tag_prefix, "")
      elseif string.match(match, self.version_prefix) then
         self.version = string.gsub(match, self.version_prefix, "")
      else
         assert(false)
      end

      name_version_tag = string.gsub(name_version_tag, match, "")
   end
   
   -- What is left is the name
   self.name = name_version_tag
end


--- Base class for the different gpackage classes.
-- Implemenents some general function for creating the
-- setter functions to be passed to the extern package.
--
local gpackage_creator_class = class.create_class()

function gpackage_creator_class:__init()
end

function gpackage_creator_class:true_setter(var)
   return function()
      self[var] = true
   end
end

function gpackage_creator_class:false_setter(var)
   return function()
      self[var] = false
   end
end

function gpackage_creator_class:string_setter(...)
   local t_outer = pack( ... )
   return function(...)
      local t_inner = pack( ... )

      -- Check sizes fit
      if #t_inner > #t_outer then
         assert(false)
      end

      -- Check all are strings, and set.
      for i = 1, #t_inner do
         if not (type(t_inner[i]) == "string") then
            assert(false) -- for now we just crash
         end
         self[t_outer[i]] = t_inner[i]
      end
   end
end

function gpackage_creator_class:element_setter(var, num)
   assert(type(var) == "string")

   return function(...)
      local t_inner = pack(...)
      
      assert(#t_inner == num)

      table.insert(self[var], t_inner)
   end
end

function gpackage_creator_class:print_setter()
   return function(...)
      local t_inner = pack( ... )

      for i = 1, #t_inner do
         logger:message(t_inner[i], self.log_format)
      end
   end
end

--local gpackage_directory_class = class.create_class()
--
--function gpackage_directory_class:__init(commands, ftable)
--   self.ftable = {
--      pop_directory = function()
--         table.insert(commands, { command = "popdir" })
--         return ftable 
--      end,
--   }
--
--   setmetatable(self.ftable, {
--      __index = ftable,
--   })
--end

--- Builder bootstrapper
--
-- Defines how to build either using cmake or autoconf
local gpackage_builder_class = class.create_class(gpackage_creator_class)

function gpackage_builder_class:__init(btype, upstream_ftable, logger)
   self.logger   = logger
   self.commands = {}
   self.btype    = btype
   self.cmakeargs = {}
   self.configargs = {}

   self.ftable = ftable.create_ftable({}, nil, self.logger)

   self.ftable_def = {
      configure = function(...) 
         table.insert(self.commands, { command = "configure", options = { options = pack(...) } })
         self.configargs = pack(...)
      end,
      make = function()
         table.insert(self.commands, { command = "make" }) 
      end,
      makeinstall = function() 
         table.insert(self.commands, { command = "makeinstall" }) 
      end,
      shell = function(cmd)
         table.insert(self.commands, { command = "shell", options = { cmd = cmd } })
      end,
      install = function(...)
         table.insert(self.commands, { command = "install", options = { install = pack(...) } })
      end,
      
      with_directory = function(dir)
         table.insert(self.commands, { command = "pushdir", options = { dir = dir} })
         --table.insert(self.storage, gpackage_directory_class:create(self.commands, self.ftable))
         self.ftable:push({
            popdir = function()
               table.insert(self.commands, { command = "popdir", options = { dir = dir} })
               self.ftable:pop()
            end
         })
      end,
      chdir = function(dir)
         table.insert(self.commands, { command = "chdir", options = { dir = dir } })
         return self.ftable
      end,

      buildend = function()
         return upstream_ftable:get()
      end,
   }

   if (self.btype == "autoconf") or (self.btype == "build") then
      self.ftable_def["autoconf"] = function()
         table.insert(self.commands, { command = "autoconf" } ) 
      end
   end
   if (self.btype == "cmake") or (self.btype == "build") then
      self.ftable_def["cmake"] = function(...)
         table.insert(self.commands, { command = "cmake", options = { options = pack(...) } } ) 
         self.btype = "cmake"
      end
   end

   self.ftable:push(self.ftable_def)
end

function gpackage_builder_class:debug(str)
   if global_config.debug and self.logger then
      logger:debug(str)
   end
end

--- Lmod
--
--
local gpackage_lmod_class = class.create_class(gpackage_creator_class)

function gpackage_lmod_class:__init(upstream_ftable, logger)
   -- Util
   self.logger = logger
   self.is_set = false

   --
   self.help   = [[]]
   self.family = {}
   self.group  = "core"
   self.heirarchical = false
   
   -- Some env stuff
   self.setenv           = {}
   self.setenv_abs       = {}
   self.prepend_path     = {}
   self.prepend_path_abs = {}
   self.alias            = {}
   self.autopath         = true
   
   --
   self.ftable     = ftable.create_ftable(nil, nil, logger)
   -- Function table for loading package
   self.ftable_def = {
      -- General
      help         = self:string_setter ("help"),
      family       = self:element_setter("family", 1),
      group        = self:string_setter ("group"),
      heirarchical = self:true_setter   ("heirarchical"),

      -- Path
      setenv           = self:element_setter("setenv"          , 2),
      setenv_abs       = self:element_setter("setenv_abs"      , 2),
      prepend_path     = self:element_setter("prepend_path"    , 2),
      prepend_path_abs = self:element_setter("prepend_path_abs", 2),
      alias            = self:element_setter("alias"           , 2),
      noautopath       = self:false_setter("autopath"),

      lmodend = function()
         return upstream_ftable:get()
      end,
   }

   self.ftable:push(self.ftable_def)
end

function gpackage_lmod_class:print()
   logger:message("Lmod : ")
   logger:message("   Help : " .. self.help)
   
   logger:message("   Prepend PATH : ")
   for k, v in pairs(self.prepend_path) do
      logger:message("      " .. v[1] .. " : " .. v[2])
   end
end

---
--
--
local gpackage_class = class.create_class(gpackage_creator_class)

function gpackage_class:__init(logger)
   -- Versioning
   self.gpack_version = 2
   
   -- Util
   self.log_format    = "newline"
   self.logger        = logger

   -- General stuff
   self.name        = ""
   self.homepage    = nil
   self.url         = nil
   self.version     = nil
   self.signature   = nil
   self.description = ""
   self.nameversion = ""

   -- Build
   self.builds   = {}
   self.files    = {}
   self.post     = {}

   -- Dependencies
   self.dependencies = {
      heirarchical = {},
      dependson    = {},
      load         = {},
   }
   
   -- Function table for loading package
   self.ftable       = ftable.create_ftable({}, nil, self.logger)
   
   -- 
   self.symbol_table = symbtab.create({}, self.ftable, self.logger)
   
   -- Lmod 
   self.lmod         = gpackage_lmod_class:create({}, self.ftable, self.logger)
   
   --
   self.ftable_def = {
      -- Util
      print       = self:print_setter(),
      format      = self:string_setter("log_format"),

      -- General
      name        = self:string_setter("name"),
      homepage    = self:string_setter("homepage"),
      url         = self:string_setter("url"),
      version     = self:string_setter("version", "signature"),
      description = self:string_setter("description"),

      -- Depend
      dependson = self:dependson_setter(),
      depend    = self:dependson_setter(),

      -- Build
      autoconf    = self:autoconf_setter(),
      cmake       = self:cmake_setter(),
      build       = self:build_setter(),
      file        = self:element_setter("files", 2),
      post        = self:element_setter("post", 1),
      
      -- Lmod
      lmod   = function() 
         self.lmod.is_set = true
         return self.lmod.ftable:get()
      end,

      --
      symbol = function()
         return self.symbol_table.ftable:get()
      end,
   }

   self.ftable:push(self.ftable_def)
end

function gpackage_class:dependson_setter()
   return function(gpack_name_version_tag, dependency)
      if util.isempty(dependency) then
         dependency = "dependson"
      end

      local depend_build_definition = build_definition_class:create({})
      depend_build_definition:initialize(gpack_name_version_tag)

      if dependency == "heirarchical" then
         table.insert(self.dependencies.heirarchical, depend_build_definition)
      elseif dependency == "dependson" then
         table.insert(self.dependencies.dependson, depend_build_definition)
      elseif dependency == "load" then
         table.insert(self.dependencies.load, depend_build_definition)
      else
         assert(false)
      end
   end
end

function gpackage_class:autoconf_setter()
   return function(version, options, ...)
      if options == nil then
         options = {}
      end
      local p = pack( ... )
      for k, v in pairs(p) do
         assert(type(v) == "string")
      end
      local build = gpackage_builder_class:create(nil, "autoconf", self.ftable, self.logger)
      build.version    = version
      build.options    = options
      build.configargs = p
      table.insert(self.builds, build)
      return build.ftable:get()
   end
end

function gpackage_class:cmake_setter()
   return function(version, ...)
      local p = pack( ... )
      for k, v in pairs(p) do
         assert(type(v) == "string")
      end
      local build = gpackage_builder_class:create(nil, "cmake", self.ftable, self.logger)
      build.version   = version
      build.cmakeargs = p
      table.insert(self.builds, build)
      return build.ftable:get()
   end
end

function gpackage_class:build_setter()
   return function(tags)
      if tags == nil then
         tags = {}
      end
      local build = gpackage_builder_class:create(nil, "build", self.ftable, self.logger)
      build.tags = tags
      table.insert(self.builds, build)
      return build.ftable:get()
   end
end

function gpackage_class:load(gpackage_path, build_definition)
   assert(type(gpackage_path) == "string")
   self.path = gpackage_path
   self.name = get_name(gpackage_path)
   
   local env  = self.ftable:get()
   local file = dofile_into_environment(self.path, env)

   local function parse_name(str)
      return str:gsub("-", "_"):gsub("%.", "_")
   end

   -- Run the gpack
   local fname = parse_name(self.name)
   if env[fname] then
      env[fname]()
   else
      logger:alert("Could not load.")
   end
   
   -- Bootstrap from build definition
   if build_definition.version ~= nil then
      self.version = build_definition.version
   end

   if build_definition.url ~= nil then
      self.url = build_definition.url
   end
   
   self.nameversion = self.name .. "-" .. self.version
   
   -- Create symbol table
   self.symbol_table:add_symbol("version"    , self.version)
   self.symbol_table:add_symbol("nameversion", self.nameversion)
   
   local version_split = util.split(self.version, ".")
   if #version_split >= 1 then
      self.symbol_table:add_symbol("version_major", version_split[1])
      if #version_split >= 2 then
         self.symbol_table:add_symbol("version_minor", version_split[2])
         if #version_split >= 3 then
            self.symbol_table:add_symbol("version_patch", version_split[3])
         end
      end
   end

   -- Substitute in self
   for k, v in pairs(self) do
      --if type(v) == "string" then
         self[k] = self.symbol_table:substitute(v)
      --end
   end

   for k, v in pairs(self.lmod) do
      --if type(v) == "string" then
         self.lmod[k] = self.symbol_table:substitute(v)
      --end
   end
end

function gpackage_class:is_git()
   return self.url:match("git$")
end

-- Check validity of gpackage
function gpackage_class:is_valid()
   if util.isempty(self.name) then
      logger:alert("No name in Gpack.")
      assert(false)
   end

   if util.isempty(self.url) then
      logger:alert("No url given in Gpack.")
      assert(false)
   end
end

function gpackage_class:print()
   logger:message("Name      : " .. self.name)
   logger:message("Homepage  : " .. self.homepage)
   logger:message("Url       : " .. self.url)
   logger:message("Version   : " .. self.version)

   if self.signature then
      logger:message("Signature : " .. self.signature)
   end

   if self.autoconf then
      for k, v in pairs(self.autoconf.configargs) do
         logger:message("   Autotools arg : " .. v)
      end
   end
   
   self.lmod:print()

   self.symbol_table:print()
end


--- Locator class
local gpackage_locator_class = class.create_class()

function gpackage_locator_class:__init()
   self.name   = ""
   self.config = nil
   self.ext    = ".lua"
end

-- Try to find package locally
function gpackage_locator_class:try_local()
   -- Try to locate gpk file
   for gpk_path in path.iterator(self.config.gpk_path) do
      if(global_config.debug) then
         logger:debug("Checking path : " .. gpk_path)
      end

      -- Check for abs path
      if not path.is_abs_path(gpk_path) then
         gpk_path = path.join(self.config.stack_path, gpk_path)
      end
      
      -- Create filename
      local filepath = path.join(gpk_path, self.name .. self.ext)
      
      -- Check for existance
      if filesystem.exists(filepath) then
         return filepath
      end
   end

   return nil
end

-- Try to download package
function gpackage_locator_class:try_download()
   local source      = path.join(global_config.repo  , self.name .. self.ext)
   local destination = path.join(self.config.gpk_path, self.name .. self.ext)
 
   logger:message(" Source      gpack : '" .. source      .. "'.")
   logger:message(" Destination gpack : '" .. destination .. "'.")
   
   local dl = downloader:create()
   dl.has_luasocket_http = false
   dl:download(source, destination)
   
   if filesystem.exists(destination) then
      return destination
   end

   return nil
end

--
function gpackage_locator_class:locate(name, config)
   if not config then
      config = global_config
   end

   assert(name)

   self.name   = name
   self.config = config

   -- Try to find package locally
   local filepath = self:try_local()
   if filepath ~= nil then
      return filepath
   end
   
   -- Else we try to download from repo
   logger:message("Package not found locally, trying remotely.")
   
   filepath = self:try_download()
   if filepath == nil then
      logger:alert("No Gpackage with name '" .. self.name .. "' was found.")
      assert(false)
   end
   
   -- Return found path
   return filepath
end


--- Load .gpk file into gpackage object.
-- 
-- @param path   The path of the .gpk.
local function load_gpackage(build_definition)
   --local gpack_name, gpack_version = get_gpack_name_version(name)

   local gpackage_locator = gpackage_locator_class:create()
   local path             = gpackage_locator:locate(build_definition.name)

   if path == nil then
      logger:alert("Could not load Gpackage.")
      assert(false)
   end
   
   logger:message("Found gpack : '" .. path .. "'.")

   local gpack = gpackage_class:create()
   gpack:load(path, build_definition)
   
   gpack:print()
   
   gpack:is_valid()

   return gpack
end

local function create_locator()
   local  gl = gpackage_locator_class:create()
   return gl
end

local function create_build_definition(...)
   local  bd = build_definition_class:create(...)
   return bd
end

--- Create the module
M.load_gpackage           = load_gpackage
M.create_locator          = create_locator
M.create_build_definition = create_build_definition

-- return module
return M
