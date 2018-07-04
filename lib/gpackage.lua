local M = {}

local class = assert(require "class")
local util  = assert(require "util")

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

--- Class to implement a simple symbol table,
-- which can be used for string substitution.
--
local gpackage_symbol_table_class = class.create_class()

function gpackage_symbol_table_class:__init()
   self.sbeg    = "%"
   self.send    = "%"
   self.symbols = { }

   self.ftable = {
      add = self:add_symbol_setter(),
   }
end

function gpackage_symbol_table_class:add_symbol(symb, ssymb)
   if not (type(symb) == "string") or util.isempty(symb) then
      assert(false)
   end
   if not (type(ssymb) == "string") then
      assert(false)
   end

   local symbol = self.sbeg .. symb .. self.send
   if not self.symbols[symbol] then
      self.symbols[self.sbeg .. symb .. self.send] = ssymb
   end
end

function gpackage_symbol_table_class:add_symbol_setter()
   return function(symb, ssymb)
      self:add_symbol(symb, ssymb)
      return self.ftable
   end
end

function gpackage_symbol_table_class:substitute(str)
   local function escape(k)
      return k:gsub("%%", "%%%%"):gsub("<", "%%%%"):gsub(">", "%%%%")
   end

   for k, v in pairs(self.symbols) do
      str = string.gsub(str, escape(k), v)
   end
   
   return str
end

function gpackage_symbol_table_class:print()
   print("   Symbol table : ")
   for k, v in pairs(self.symbols) do
      print("      " .. k .. " : " .. v)
   end
end

--- Base class for the different gpackage classes.
-- Implemenents some general function for creating the
-- setter functions to be passed to the extern package.
--
local gpackage_creator_class = class.create_class()

function gpackage_creator_class:__init()
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

--- Lmod
--
--
local gpackage_lmod_class = class.create_class(gpackage_creator_class)

function gpackage_lmod_class:__init()
   self.help   = ""
   self.family = nil
   self.group  = "core"
   
   self.setenv           = {}
   self.setenv_abs       = {}
   self.prepend_path     = {}
   self.prepend_path_abs = {}
   self.alias            = {}

   -- Function table for loading package
   self.ftable = {
      -- General
      help         = self:string_setter("help"),
      family       = self:string_setter("family"),
      group        = self:string_setter("group"),

      -- Path
      setenv           = self:element_setter("setenv"          , 2),
      setenv_abs       = self:element_setter("setenv_abs"      , 2),
      prepend_path     = self:element_setter("prepend_path"    , 2),
      prepend_path_abs = self:element_setter("prepend_path_abs", 2),
      alias            = self:element_setter("alias"           , 2),
   }
end

function gpackage_lmod_class:print()
   print("Lmod : ")
   print("   Help : " .. self.help)
   
   print("   Prepend PATH : ")
   for k, v in pairs(self.prepend_path) do
      print("      " .. v[1] .. " : " .. v[2])
   end
end

---
--
--
local gpackage_class = class.create_class(gpackage_creator_class)

function gpackage_class:__init()
   --assert(type(name) == "string")

   -- General stuff
   self.name        = ""
   self.homepage    = nil
   self.url         = nil
   self.version     = nil
   self.signature   = nil
   self.description = ""

   -- Build
   self.autotool    = false
   self.cmake       = false
   self.files       = { }
   
   -- 
   self.symbol_table = gpackage_symbol_table_class:create()
   
   -- Lmod 
   self.lmod = gpackage_lmod_class:create()
   
   -- Function table for loading package
   self.ftable = {
      -- General
      homepage    = self:string_setter("homepage"),
      url         = self:string_setter("url"),
      version     = self:string_setter("version", "signature"),
      description = self:string_setter("description"),

      -- Build
      autotools   = self:autotools_setter(),
      cmake       = self:cmake_setter(),
      file        = self:element_setter("files", 2)
      
      -- Lmod
      lmod = self.lmod.ftable,

      --
      symbol = self.symbol_table.ftable,
   }
end

function gpackage_class:autotools_setter()
   return function(...)
      assert(not self.cmake)
      self.autotools = true
      local p = pack( ... )
      for k, v in pairs(p) do
         assert(type(v) == "string")
      end
      self.autotools_args = p
      return self.ftable
   end
end

function gpackage_class:cmake_setter()
   return function()
      assert(not self.autotools)
      self.cmake = true
      return self.ftable
   end
end

function gpackage_class:load(path)
   assert(type(path) == "string")
   self.path = path
   self.name = "libelf"
   
   local env  = self.ftable
   local file = dofile_into_environment(self.path, env)
   
   if env[self.name] then
      env[self.name]()
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
end

function gpackage_class:print()
   print("Name      : " .. self.name)
   print("Homepage  : " .. self.homepage)
   print("Url       : " .. self.url)
   print("Version   : " .. self.version)

   if self.signature then
      print("Signature : " .. self.signature)
   end

   if self.autotools then
      for k, v in pairs(self.autotools_args) do
         print("   Autotools arg : " .. v)
      end
   end
   
   self.lmod:print()

   self.symbol_table:print()
end

--- Load .gpk file into gpackage object.
-- 
-- @param path   The path of the .gpk.
local function load_gpackage(path)
   local gpack = gpackage_class:create()
   gpack:load(path)
   
   gpack:print()

   return gpack
end

--- Create the module
M.load_gpackage = load_gpackage

-- return module
return M
