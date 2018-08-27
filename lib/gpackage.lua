local M = {}

local filesystem = assert(require "lib.filesystem")
local class   = assert(require "lib.class")
local util    = assert(require "lib.util")
local path    = assert(require "lib.path")
local logging = assert(require "lib.logging")
local logger  = logging.logger
local downloader = assert(require "lib.downloader")
local symbtab    = assert(require "lib.symbtab")

local function pack(...)
   return { ... }

   --if not table.pack then
   --   table.pack = function(...)
   --      return { n = select("#", ...), ...}
   --   end
   --end
end

local function dofile_into_environment(filename, env)
    setmetatable ( env, { __index = _G } )
    local status, result = assert(pcall(setfenv(assert(loadfile(filename)), env)))
    setmetatable(env, nil)
    return result
end

local function get_name(gpackage_path)
   local p, f, e = path.split_filename(gpackage_path)
   return f:gsub("." .. e, "")
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
      return self.ftable
   end
end

function gpackage_creator_class:false_setter(var)
   return function()
      self[var] = false
      return self.ftable
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
      return self.ftable
   end
end

function gpackage_creator_class:element_setter(var, num)
   assert(type(var) == "string")

   return function(...)
      local t_inner = pack(...)
      
      assert(#t_inner == num)

      table.insert(self[var], t_inner)

      return self.ftable
   end
end

function gpackage_creator_class:print_setter()
   return function(...)
      local t_inner = pack( ... )

      for i = 1, #t_inner do
         logger:message(t_inner[i], self.log_format)
      end

      return self.ftable
   end
end

--- Lmod
--
--
local gpackage_lmod_class = class.create_class(gpackage_creator_class)

function gpackage_lmod_class:__init()
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

   -- Function table for loading package
   self.ftable = {
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
      noautopath       = self:false_setter("autopath")
   }
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

function gpackage_class:__init()
   -- Versioning
   self.gpack_version = 2
   
   -- Util
   self.log_format    = "newline"

   -- General stuff
   self.name        = ""
   self.homepage    = nil
   self.url         = nil
   self.version     = nil
   self.signature   = nil
   self.description = ""
   self.nameversion = ""

   -- Build
   self.autotools   = nil
   self.cmake       = false
   self.files       = {}
   self.post        = {}

   -- Dependencies
   self.dependencies = {}
   
   -- 
   self.symbol_table = symbtab.create()
   
   -- Lmod 
   self.lmod = gpackage_lmod_class:create()
   
   -- Function table for loading package
   self.ftable = {
      -- Util
      print       = self:print_setter(),
      format      = self:string_setter("log_format"),

      -- General
      homepage    = self:string_setter("homepage"),
      url         = self:string_setter("url"),
      version     = self:string_setter("version", "signature"),
      description = self:string_setter("description"),

      -- Build
      autotools   = self:autotools_setter(),
      cmake       = self:cmake_setter(),
      file        = self:element_setter("files", 2),
      post        = self:element_setter("post", 1),
      
      -- Lmod
      lmod = self.lmod.ftable,

      --
      symbol = self.symbol_table.ftable,
   }
end

function gpackage_class:autotools_setter()
   return function(version, options, ...)
      if options == nil then
         options = {}
      end
      assert(not self.cmake)
      assert(not self.autotools)
      local p = pack( ... )
      for k, v in pairs(p) do
         assert(type(v) == "string")
      end
      self.autotools_args = p
      self.autotools = {
         version = version,
         options = options,
         args    = p,
      }
      return self.ftable
   end
end

function gpackage_class:cmake_setter()
   return function(version, ...)
      assert(not self.autotools)
      self.cmake = true
      self.cmake_version = version
      local p = pack( ... )
      for k, v in pairs(p) do
         assert(type(v) == "string")
      end
      self.cmake_args = p
      return self.ftable
   end
end

function gpackage_class:load(gpackage_path)
   assert(type(gpackage_path) == "string")
   self.path = gpackage_path
   self.name = get_name(gpackage_path)
   
   local env  = self.ftable
   local file = dofile_into_environment(self.path, env)
   
   if env[self.name] then
      env[self.name]()
   else
      logger:alert("Could not load.")
   end
   
   self.symbol_table:add_symbol("version", self.version)

   for k, v in pairs(self) do
      if type(v) == "string" then
         self[k] = self.symbol_table:substitute(v)
      end
   end

   for k, v in pairs(self.lmod) do
      if type(v) == "string" then
         self.lmod[k] = self.symbol_table:substitute(v)
      end
   end

   self.nameversion = self.name .. "-" .. self.version
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

   if self.autotools then
      for k, v in pairs(self.autotools_args) do
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
   end
   
   -- Return found path
   return filepath
end

--- Load .gpk file into gpackage object.
-- 
-- @param path   The path of the .gpk.
local function load_gpackage(name)
   local gpackage_locator = gpackage_locator_class:create()
   local path             = gpackage_locator:locate(name)

   if path == nil then
      logger:alert("Could not load Gpackage.")
      assert(false)
   end
   
   logger:message("Found gpack : '" .. path .. "'.")

   local gpack = gpackage_class:create()
   gpack:load(path)
   
   gpack:print()
   
   gpack:is_valid()

   return gpack
end

local function create_locator()
   local  gl = gpackage_locator_class:create()
   return gl
end

--- Create the module
M.load_gpackage       = load_gpackage
M.create_locator      = create_locator

-- return module
return M
