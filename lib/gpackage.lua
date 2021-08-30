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
local env     = assert(require "lib.env")

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

   function assert_load(loaded, err)
      if not loaded then
         error("GPack is buggy: '" .. err .. "'.")
      end
   end

   setmetatable ( env, { __index = _G } )
   local status = nil
   local result = nil

   logger:message("Trying to load file : '" .. filename .. "'.")

   if luautil.version() == "Lua 5.1" then
      local loaded, err = loadfile(filename)
      assert_load(loaded, err)
      status, result = assert(pcall(setfenv(loaded, env)))
   else
      local content     = readall(filename)
      local loaded, err = load(content, nil, nil, env)
      assert_load(loaded, err)
      status, result    = assert(pcall(loaded))
   end
   setmetatable(env, nil)
   return result
end

local function get_name(gpackage_path)
   local p, f, e = path.split_filename(gpackage_path)
   return f:gsub("." .. e, "")
end

math.randomseed(os.clock()+os.time())

local function generate_uid(template)
   if util.isempty(template) then
      template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
   end

   local random = math.random
   
   local function uuid()
      return string.gsub(template, '[xy]', function (c)
         local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
         return string.format('%x', v)
      end)
   end

   return uuid()
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
   self.group    = nil
   
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
   self.name = path.remove_file_ext(name_version_tag)
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

function gpackage_creator_class:element_setter(var, num_min, num_max)
   assert(type(var) == "string")

   if not num_max then
      num_max = num_min
   end

   return function(...)
      local t_inner = pack(...)
      
      assert((#t_inner >= num_min) and (#t_inner <= num_max))

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
      make = function(...)
         table.insert(self.commands, { command = "make", options = {options = pack(...) } }) 
      end,
      makeinstall = function(...) 
         table.insert(self.commands, { command = "makeinstall", options = { options = pack(...) } }) 
      end,
      make_install = function(...) 
         table.insert(self.commands, { command = "makeinstall", options = { options = pack(...) } } ) 
      end,
      shell = function(cmd)
         table.insert(self.commands, { command = "shell", options = { cmd = cmd } })
      end,
      install = function(...)
         table.insert(self.commands, { command = "install", options = { install = pack(...) } })
      end,
      
      with_directory = function(dir)
         table.insert(self.commands, { command = "pushdir", options = { dir = dir} })
         self.ftable:push({
            popdir = function()
               table.insert(self.commands, { command = "popdir", options = { dir = dir} })
               self.ftable:pop()
            end,
            pop_directory = function()
               table.insert(self.commands, { command = "popdir", options = { dir = dir} })
               self.ftable:pop()
            end
         })
      end,
      chdir = function(dir)
         table.insert(self.commands, { command = "chdir", options = { dir = dir } })
         return self.ftable
      end,
      prepend_path = function(name, value, delimeter)
         if(delimeter) then
            table.insert(self.commands, { command = "prepend_env", options = { name = name, value = value, delimeter = delimeter } })
         else
            table.insert(self.commands, { command = "prepend_env", options = { name = name, value = value, delimeter = ":" } })
         end
      end,
      prepend_env = function(name, value, delimeter)
         if(delimeter) then
            table.insert(self.commands, { command = "prepend_env", options = { name = name, value = value, delimeter = delimeter } })
         else
            table.insert(self.commands, { command = "prepend_env", options = { name = name, value = value, delimeter = ":" } })
         end
      end,
      set_env = function(name, value)
         table.insert(self.commands, { command = "set_env", options = { name = name, value = value } })
      end,
      buildend = function()
         return upstream_ftable:get()
      end,
      build_end = function()
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
   self.name   = nil
   
   -- Some env stuff
   self.setenv           = {}
   self.setenv_abs       = {}
   self.prepend_path     = {}
   self.prepend_path_abs = {}
   self.alias            = {}
   self.autopath         = true -- Try to autmatically figure out paths to prepend
   self.autopaths        = {}   -- Paths to check in autopath'ing algorithm
   
   --
   self.ftable     = ftable.create_ftable(nil, nil, logger)
   -- Function table for loading package
   self.ftable_def = {
      -- General
      help         = self:string_setter ("help"),
      family       = self:element_setter("family", 1),
      group        = self:string_setter ("group"),
      heirarchical = self:true_setter   ("heirarchical"),
      name         = self:string_setter ("name"),

      -- Path
      setenv             = self:element_setter("setenv"            , 2),
      setenv_abs         = self:element_setter("setenv_abs"        , 2),
      prepend_path       = self:element_setter("prepend_path"      , 2, 3),
      prepend_path_abs   = self:element_setter("prepend_path_abs"  , 2, 3),
      alias              = self:element_setter("alias"             , 2),
      noautopath         = self:false_setter("autopath"),
      autopath           = function(path) table.insert(self.autopaths, path) end,

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
   self.urls        = {}
   self.version     = nil
   self.signature   = nil
   self.description = ""
   self.nameversion = ""
   self.n_jobs      = global_config.nprocesses

   -- Build
   self.builds   = {}
   self.files    = {}
   self.post     = {}

   -- Dependencies
   self.dependencies = {
      heirarchical = util.ordered_table({}),
      dependson    = {},
      load         = {},
   }
   
   -- Function table for loading package
   self.ftable       = ftable.create_ftable({}, nil, self.logger)
   
   --  Setup symbol table and function table for interacting with it
   self.symbol_table   = symbtab.create(nil, self.logger)
   self.symbtab_ftable = ftable.create_ftable({}, nil, self.logger)
   local symbtab_ftable_def = {
      --
      add = function(symb, ssymb, overwrite, format_fcn) 
         self.symbol_table:add_symbol(symb, ssymb, overwrite, format_fcn)
      end,
      -- synonym for above
      add_symbol = function(symb, ssymb, overwrite, format_fcn) 
         self.symbol_table:add_symbol(symb, ssymb, overwrite, format_fcn)
      end,
      --
      symbolend = function()
         return self.ftable:get()
      end
   }
   self.symbtab_ftable:push(symbtab_ftable_def)
   
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
      url         = self:url_setter(),
      version     = self:string_setter("version"),
      signature   = self:string_setter("signature"),
      description = self:string_setter("description"),

      -- Depend
      depends_on = self:dependson_setter(),
      dependson  = self:dependson_setter(),
      depends    = self:dependson_setter(),
      depend     = self:dependson_setter(),

      -- Build
      autoconf    = self:autoconf_setter(),
      cmake       = self:cmake_setter(),
      build       = self:build_setter(),
      file        = self:element_setter("files", 2),
      post        = self:element_setter("post", 1),
      get_env     = env.get_env,
      set_n_jobs  = self:n_jobs_setter(),
      
      -- Lmod
      lmod   = function() 
         self.lmod.is_set = true
         return self.lmod.ftable:get()
      end,

      --
      symbol = function()
         return self.symbtab_ftable:get()
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

      if string.match(dependency, "heirarchical") then
         local split = util.split(dependency, ":")
         depend_build_definition.group = split[2]
         table.insert(self.dependencies.heirarchical, depend_build_definition)
      elseif dependency == "dependson" then
         table.insert(self.dependencies.dependson, depend_build_definition)
      elseif dependency == "load" then
         table.insert(self.dependencies.load, depend_build_definition)
      else
         print("Unknown dependency type '" .. dependency .. "'.")
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

function gpackage_class:url_setter()
   return function(url, sig, unpack)
      table.insert(self.urls, { url = url, sig = sig, unpack = unpack} )
   end
end

function gpackage_class:n_jobs_setter()
   return function(n_jobs)
      self.n_jobs = n_jobs
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
      table.insert(self.urls, { url = build_definition.url, sig = nil})
   end

   self.version = self.symbol_table:substitute(self.version)
   
   self.nameversion = self.name .. "-" .. self.version
   
   -- Create symbol table
   if (not self.symbol_table:contains_symbol(self.version)) then
      self.symbol_table:add_symbol("version"    , self.version)
   end
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

   self.symbol_table:add_symbol("uid", generate_uid("xxxxxx"))

   local function substitute_recursive(reference)
      for k, v in pairs(reference.ref) do
         if type(v) == "string" then
            reference.ref[k] = self.symbol_table:substitute(v)
         elseif type(v) == "table" then
            local reference = { ref = v }
            substitute_recursive(reference)
         end
      end
   end

   -- Substitute in self
   local reference = { ref = self }
   substitute_recursive(reference)
end

function gpackage_class:is_git()
   return self.urls[1].url:match("git$")
end

--function gpackage_class:get_heirarchical()
--   return self.dependencies.heirarchical
--end

-- Check validity of gpackage
function gpackage_class:is_valid()
   if util.isempty(self.name) then
      logger:alert("No name in Gpack.")
      assert(false)
   end
   
   local count = 0
   for key, value in pairs(self.urls) do
      count = count + 1
   end

   if count == 0 then
      logger:alert("No url given in Gpack.")
      --assert(false)
   end
end

function gpackage_class:print()
   logger:message("Name      : " .. self.name)
   logger:message("Homepage  : " .. self.homepage)
   logger:message("Urls      : ")
   for key, value in pairs(self.urls) do
      logger:message("   Source   : " .. value.url)
      if value.sig then
         logger:message("   Signature: " .. value.sig)
      end
   end
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

-- 
function gpackage_locator_class:name_list(name)
   local list = {}

   table.insert(list, name)
   table.insert(list, path.join(string.sub(name, 1, 1), name))

   return list
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
   logger:message("Trying to download gpack.")

   -- Destination path
   local gpk_path_download = util.split(self.config.gpk_path)[1]
   local destination       = path.join(gpk_path_download , self.name .. self.ext)
   logger:message(" Download destination : '" .. destination .. "'.")
   
   -- Create downloader
   local dl = downloader:create()
   dl.has_luasocket_http = false
   
   local list = self:name_list(self.name .. self.ext)

   for key, value in pairs(list) do
      local source = path.join(global_config.repo, value)
      logger:message(" Trying source destination : '" .. source .. "'.")
      
      local status = dl:download(source, destination)
      
      if status and filesystem.exists(destination) then
         logger:message(" Source '" .. source .. "' SUCCESS!")
         return destination
      else
         logger:message(" Source '" .. source .. "' failed...")
      end
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
      logger:message("Package '" .. self.name .. "' found locally.")
      return filepath
   end
   
   -- Else we try to download from repo
   logger:message("Package not found locally, trying remotely.")
   
   filepath = self:try_download()
   
   if filepath == nil then
      logger:alert("No Gpackage with name '" .. self.name .. "' was found.")
      assert(false)
   else
      logger:message("Package '" .. self.name .. "' found remotely and was downloaded.")
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
