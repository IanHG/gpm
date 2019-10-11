local M = {}

local class      = require "lib.class"
local filesystem = require "lib.filesystem"
local logging    = require "lib.logging"
local logger     = logging.logger
local path       = require "lib.path"

---
local path_handler_class = class.create_class()

function path_handler_class:__init(st, add_cwd)
   self.paths = {}

   if add_cwd then
      local cwd, error_msg = filesystem.cwd()
      if not cwd then
         logger:alert(error_msg)
         assert(false)
      end
      self:push(filesystem.cwd())
   end
   
   self.symbol_table = st
end

function path_handler_class:push(ppath)
   logger:message(" Pushing path : '" .. ppath .. "'.")
   
   if path.is_abs_path(ppath) then
      table.insert(self.paths, ppath)
   else
      table.insert(self.paths, path.join(self:current(), ppath))
   end
   
   if self.symbol_table then
      self.symbol_table:add_symbol("cwd", self.paths[#self.paths], true)
   end

   local status, error_msg = filesystem.chdir(self.paths[#self.paths])
   
   if status == nil then
      logger:alert("Filesystem: " .. error_msg)
      assert(false)
   end
end

function path_handler_class:pop()
   if #self.paths > 0 then
      logger:message(" Popping path : '" .. self.paths[#self.paths] .. "'.")
      self.paths[#self.paths] = nil
      if #self.paths > 0 then
         if self.symbol_table then
            self.symbol_table:add_symbol("cwd", self.paths[#self.paths], true)
         end
         local status = filesystem.chdir(self.paths[#self.paths])
         if status == nil then
            assert(false)
         end
         logger:message(" New path is: '" .. self.paths[#self.paths] .. "'.")
      else
         logger:message(" No new path to chdir to :C.")
      end
   else
      logger:message(" Popping nothing.")
   end

   return #self.paths
end

function path_handler_class:pop_all()
   while (self:pop() > 0) do
   end

   if add_cwd then
      self:push(filesystem.cwd())
   end
end

function path_handler_class:current()
   if #self.paths > 0 then
      return self.paths[#self.paths]
   else
      return filesystem.cwd()
   end
end

function path_handler_class:print()
   for k, v in pairs(self.paths) do
      logger:message(" Path Handler : " .. v)
   end
end

local function create(...)
   local  ph = path_handler_class:create(...)
   return ph
end

M.create = create

return M
