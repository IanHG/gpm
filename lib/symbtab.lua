local class   = require "lib.class"

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

--- Initialize symbtab class
--
--
function symbol_table_class:__init(upstream_symbtabs, check_string, logger)
   self.sbeg    = "%"
   self.send    = "%"
   self.symbols = { }
   
   -- Init upstream
   if upstream_symbtabs ~= nil and upstream_symbtabs:is_a(symbol_table_class) then
      self.upstream_symbtabs = { upstream_symbtabs }
   else
      self.upstream_symbtabs = { }
   end
   
   -- Init logger
   if logger then
      self.logger = logger
   end

   self.check_string = check_string
end

--- Log a message, either to a log, or to stdout
--
function symbol_table_class:log(msg, alert)
   if self.logger then
      if alert then
         logger:alert(msg)
      else
         logger:message(msg)
      end
   else
      print(msg)
   end
end

--- Check if symbol table has a symbol defined
--
--
function symbol_table_class:has_symbol(symb)
   local symbol = self.sbeg .. symb ..self.send
   
   local function has_symbol_upstream()
      for k, v in pairs(self.upstream_symbtabs) do
         if v:has_symbol(symb) then
            return true
         end
      end
      return false
   end

   return (self.symbols[symbol] ~= nil) or has_symbol_upstream()
end

--- Add a symbol to symbol table
--
function symbol_table_class:add_symbol(symb, ssymb, overwrite, format_fcn)
   if not (type(symb) == "string") or isempty(symb) then
      self:log("Cannot add : Symbol is empty.", true)
      assert(false)
   end
   if (not (type(ssymb) == "string") and not (type(ssymb) == "function")) then
      ssymb = tostring(ssymb)
   end

   if (not self:has_symbol(symb)) or overwrite then
      self.symbols[self.sbeg .. symb .. self.send] = { ssymb = ssymb, format_fcn = format_fcn }
   end
end

--- Remove symbol from symbol table
--
function symbol_table_class:remove_symbol(symb)
   if not (type(symb) == "string") or isempty(symb) then
      assert(false)
   end
   
   local symbol = self.sbeg .. symb .. self.send
   if self.symbols[symbol] then
      self.symbols[symbol] = nil
   end
end

--- Escape '%'
--
--
function symbol_table_class:escape(str)
   if type(str) ~= "string" then
      str = tostring(str)
   end

   local  pattern, _ = str:gsub("%%", "%%%%")
   return pattern
end

--- Recursively substitute symbols in string
--
--
function symbol_table_class:substitute(str, check_string)
   local pattern = self:escape(self.sbeg .. ".+" .. self.send)
   
   -- Declare implementation function
   local function substitute_impl(str)
      if str:match(pattern) then
         -- loop over symbols
         for k, v in pairs(self.symbols) do
            if str:match(self:escape(k)) then
               local ssymb
               if type(v.ssymb) == "function" then
                  ssymb = v.ssymb()
               else
                  ssymb = v.ssymb
               end
               local formatet_ssymb = ssymb
               
               if ssymb:match(pattern) then
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

   -- Call substitute on upstream
   for k, v in pairs(self.upstream_symbtabs) do
      str = v:substitute(str)
   end

   if check_string or self.check_string then
      self:check(str)
   end

   return str
end

--- Check if a string contains a symbol
--
--
function symbol_table_class:contains_symbol(str)
   local pattern = self:escape(self.sbeg .. ".+" .. self.send)

   if str:match(pattern) then
      return true
   else
      return false
   end
end

--- Merge another symbol table into this
--
function symbol_table_class:merge(st)
   for k, v in pairs(st.symbols) do
      if not self.symbols[k] then
         self.symbols[k] = v
      end
   end
end

--- Check for missing substitutions
--
function symbol_table_class:check(str)
   -- Check for any missing substitutions
   if self:contains_symbol(str) then
      self:log(" String '" .. str .. "' contains un-substitued symbols!", true)
      assert(false)
   end
end

--- Print symbol table to log
--
--
function symbol_table_class:print()
   self:log("   Symbol table : ")
   for k, v in pairs(self.symbols) do
      if type(v.ssymb) == "function" then
         self:log("      " .. k .. " : " .. v.ssymb())
      else
         self:log("      " .. k .. " : " .. v.ssymb)
      end
   end
end

--- Create a symbol table
local function create(...)
   local  st = symbol_table_class:create({}, ...)
   return st
end

--- Create a symbol table
local function create_with_inheritance(...)
   local  st = symbol_table_class:create(...)
   return st
end

--- Create module
local M = {}

M.create                  = create
M.create_with_inheritance = create_with_inheritance

return M
