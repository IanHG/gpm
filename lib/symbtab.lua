local M = {}

local class   = require "lib.class"
local logging = require "lib.logging"
local logger  = logging.logger
local ftable  = require "lib.ftable"

-- Check if string or table is empty.
local function isempty(s)
   if not s then
      return true
   end

   if type(s) == "string" then
      -- string
      return s == nil or s == ''
   elseif type(s) == "table" then
      -- table
      if next(s) == nil then
         return true
      else
         return false
      end
   else
      return false
   end
end

--- Class to implement a simple symbol table,
-- which can be used for string substitution.
--
local symbol_table_class = class.create_class()

function symbol_table_class:__init(upstream_ftable, logger)
   self.sbeg    = "%"
   self.send    = "%"
   self.symbols = { }
   
   self.ftable  = ftable.create_ftable({}, nil, logger)
   self.ftable_def = {
      add = self:add_symbol_setter(),
   }

   if upstream_ftable then
      self.ftable_def.symbolend = function() upstream_ftable:get() end
   end

   self.ftable:push(self.ftable_def)
end

function symbol_table_class:add_symbol(symb, ssymb, overwrite, format_fcn)
   if not (type(symb) == "string") or isempty(symb) then
      logger:alert("Cannot add : Symbol is empty.")
      assert(false)
   end
   if not (type(ssymb) == "string") then
      ssymb = tostring(ssymb)
   end

   local symbol = self.sbeg .. symb .. self.send
   if (not self.symbols[symbol]) or overwrite then
      self.symbols[self.sbeg .. symb .. self.send] = { ssymb = ssymb, format_fcn = format_fcn }
   end
end

function symbol_table_class:remove_symbol(symb)
   if not (type(symb) == "string") or isempty(symb) then
      assert(false)
   end
   
   local symbol = self.sbeg .. symb .. self.send
   if self.symbols[symbol] then
      self.symbols[symbol] = nil
   end
end

function symbol_table_class:add_symbol_setter()
   return function(symb, ssymb, overwrite, format_fcn)
      self:add_symbol(symb, ssymb, overwrite, format_fcn)
   end
end

function symbol_table_class:escape(str)
   if type(str) ~= "string" then
      str = tostring(str)
   end

   local  pattern, _ = str:gsub("%%", "%%%%")
   return pattern
end

function symbol_table_class:substitute(str)
   local pattern = self:escape(self.sbeg .. ".+" .. self.send)
   
   -- Declare implementation function
   local function substitute_impl(str)
      if str:match(pattern) then
         -- loop over symbols
         for k, v in pairs(self.symbols) do
            if str:match(self:escape(k)) then
               local formatet_ssymb = v.ssymb
               
               if v.ssymb:match(pattern) then
                  formatet_ssymb = substitute_impl(formatet_ssymb)
               end

               if v.format_fcn then
                  formatet_ssymb = v.format_fcn(formatet_ssymb)
               end
               
               -- Do actual substitution
               str = string.gsub(str, self:escape(k), self:escape(formatet_ssymb))
            end
         end
      end
      

      return str
   end
   
   -- Call substitution implementation
   if type(str) == "string" then
      str = substitute_impl(str)
   elseif type(str) == "table" then
      for k, v in pairs(str) do
         str[k] = self:substitute(v)
      end
   end

   return str
end

function symbol_table_class:contains_symbol(str)
   local pattern = self:escape(self.sbeg .. ".+" .. self.send)

   if str:match(pattern) then
      return true
   else
      return false
   end
end

function symbol_table_class:merge(st)
   for k, v in pairs(st.symbols) do
      if not self.symbols[k] then
         self.symbols[k] = v
      end
   end
end

function symbol_table_class:check(str)
   -- Check for any missing substitutions
   local pattern = self:escape(self.sbeg .. ".+" .. self.send)
   if str:match(pattern) then
      logger:alert(" String '" .. str .. "' contains un-substitued symbols!")
      assert(false)
   end
end

function symbol_table_class:print()
   logger:message("   Symbol table : ")
   for k, v in pairs(self.symbols) do
      logger:message("      " .. k .. " : " .. v.ssymb)
   end
end

local function create(...)
   local  st = symbol_table_class:create(...)
   return st
end

M.create = create

return M
