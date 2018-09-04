local class = require "lib.class"

local M = {}

local ftable_class = class.create_class()

function ftable_class:__init(ftable, logger, add_push_pop)
   local allow_upstream_return = false

   self.logger     = logger
   self.ftable_def = {}
   self.metaftable = {}
   
   if add_push_pop then
      self.ftable_def_default = {
         push = function(ftable_def)
            self:push(ftable_def)
         end,
         pop = function()
            self:pop()
         end,
      }
   else
      self.ftable_def_default = {}
   end

   setmetatable(self.metaftable, {
      __index = function(tab, key)
         return function(...)
            local ftable_return = nil
            if (ftable ~= nil) and ftable:is_a(ftable_class) then
               ftable_return = ftable.metaftable[key](...)
            else
               if self.logger then
                  logger:message("No function called '" .. key .. "'.")
                  logger:message("Called with args : ")
                  logger:message(...)
               else
                  print("No function called '" .. key .. "'.")
                  print("Called with args : ")
                  print(...)
               end
            end
            if allow_upstream_return and (ftable_return ~= nil) then
               return ftable_return
            else
               return self.metaftable
            end
         end
      end,
   })
   self:push(self.ftable_def_default)
end

function ftable_class:_setup_metaftable()
   for k, v in pairs(self.metaftable) do
      self.metaftable[k] = nil
   end
   
   for k, v in pairs(self.ftable_def) do
      for fk, fv in pairs(v) do
         self.metaftable[fk] = function(...)
            print("CALLING FUNCTION" .. fk)
            local ftable_return = fv(...)
            if ftable_return ~= nil then
               print("RETURN FTABLE_RETURN")
               return ftable_return
            else
               print("RETURNING METATABLE")
               return self.metaftable
            end
         end
      end
   end
end

function ftable_class:push(ftable_def)
   table.insert(self.ftable_def, ftable_def)
   self:_setup_metaftable()
end

function ftable_class:pop()
   if #self.ftable_def > 1 then
      self.ftable_def[#self.ftable_def] = nil
   else
      if self.logger then
         self.logger:message("Popping nothing.")
      end
   end
   self:_setup_metaftable()
end

function ftable_class:get()
   return self.metaftable
end

local function create_ftable(...)
   local  ftable = ftable_class:create(...)
   return ftable
end

M.create_ftable = create_ftable

return M
