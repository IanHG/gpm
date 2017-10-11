local M = {}

local _execcmd = require "execcmd"
local _logging = require "logging"

local function merge(a, b)
   if type(a) == 'table' and type(b) == 'table' then
      for k,v in pairs(b) do 
         if type(v)=='table' and type(a[k] or false)=='table' then 
            merge(a[k],v) 
         else 
            a[k]=v 
         end 
      end
   end
   return a
end

local function indent(level)
   local indention = ""
   for i=1,level do
      indention = indention .. "   "
   end
   return indention
end

local function recursive_table_print(a, level)
   local indention_outer = indent(level)
   local indention_inner = indent(level + 1)
   io.write("{\n")
   for k,v in pairs(a) do
      io.write(indention_inner, k, " = ")
      if type(v) == 'table' and type(a[k] or false)=='table' then
         recursive_table_print(v, level + 1)
      else
         io.write(tostring(v))
         io.write("\n")
      end
   end
   io.write(indention_outer .. "}\n")
end

local function table_print(a, name)
   io.write(name .. " = ")
   recursive_table_print(a, 0)
end

-------------------------------------
-- Run command in shell.
--
-- @param command
--
-- @return{Boolean}
-------------------------------------
local function execute_command(command, log)
   _logging.message("EXECUTING COMMAND : " .. command, log)
   bool, msg, status = _execcmd.execcmd_shexec(command, log)
   
   _logging.message("STATUS", log)
   _logging.message(bool, log)
   _logging.message(msg, log)
   _logging.message(status, log)

   if status ~= 0  then
      -- Differences in what os.execute returns depending on system
      if bool == 0 then
         status = bool
      else
         error("Command '" .. command .. "' exited with errors.")
      end
   end

   return status
end

-------------------------------------
-- Get name and version of program.
--
-- @return{String} Name and version.
-------------------------------------
local function substitute_placeholders(definition, line)
   for key,value in pairs(definition) do
      line = string.gsub(line, "<" .. key .. ">", value)
   end
   return line
end

-------------------------------------
-- Split a string
-------------------------------------
local function split(inputstr, sep)
   if inputstr == nil then
      return {}
   end
   if sep == nil then
      sep = "%s"
   end
   local t={} ; i=1
   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      t[i] = str
      i = i + 1
   end
   return t
end

-------------------------------------
-- Trim a string
-------------------------------------
local function trim(s)
   local n = s:find"%S"
   return n and s:match(".*%S", n) or ""
end

local function ordered_table(t)
   local currentIndex = 1
   local metaTable = {}
           
   function metaTable:__newindex(key,value)
      rawset(self, key, value)
      rawset(self, currentIndex, key)
      currentIndex = currentIndex + 1
   end
   return setmetatable(t or {}, metaTable)
end
                         
local function ordered(t)
   local currentIndex = 0
   local function iter(t)
      currentIndex = currentIndex + 1
      local key = t[currentIndex]
      if key then return key, t[key] end
   end
   return iter, t
end

local function conditional(condition, if_true, if_false)
   if condition then return if_true else return if_false end
end



-- Load module functions
M.print = table_print
M.merge = merge
M.execute_command = execute_command
M.substitute_placeholders = substitute_placeholders
M.split = split
M.trim = trim
M.ordered_table = ordered_table
M.ordered = ordered
M.conditional = conditional

return M
