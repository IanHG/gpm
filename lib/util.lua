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

--- Table print implementation function.
-- 
-- @param a       The current sub-table.
-- @param level   The current level (used to calculate identation).
--
-- @return Returns string which contains all sub-tables.
local function recursively_generate_table_string(a, level)
   -- Setup some indentation
   local function indent(level)
      local indention = ""
      for i=1,level do
         indention = indention .. "   "
      end
      return indention
   end

   local indentation_outer = indent(level)
   local indentation_inner = indent(level + 1)
   
   -- Begin scope
   local stable = "{"
   local firstpass = true
   for k,v in pairs(a) do
      -- If first pass we print newline
      if firstpass then
         firstpass = false
         stable = stable .. "\n"
      end
      
      -- Print current
      stable = stable .. indentation_inner .. k .. " = "
      
      -- Print recursive
      if type(v) == 'table' and type(a[k] or false)=='table' then
         stable = stable .. recursively_generate_table_string(v, level + 1)
      else
         stable = stable .. tostring(v) .. "\n"
      end
   end
   
   -- End scope
   stable = stable .. indentation_outer .. "}\n"
   return stable
end

--- Turn a table into a string.
--
-- @param a      The table.
-- @param name   The name of the table.
--
-- @return  Returns string with table.
local function table_print(a, name)
   local stable = name .. " = "
   stable = stable .. recursively_generate_table_string(a, 0)
   return stable
end

--- Run command in shell.
--
-- @param command    The command to run.
-- @param log        An optional log.
--
-- @return Returns status of command.
local function execute_command(command, log)
   -- Do some pre-logging
   _logging.message("EXECUTING COMMAND : " .. command, log)

   -- Run the command
   bool, msg, status = _execcmd.execcmd_shexec(command, log)
   
   -- Do some post logging
   if bool then
      _logging.message("COMMAND : " .. command, log)
      _logging.message("STATUS", log)
      _logging.message(bool, log)
      _logging.message(msg, log)
      _logging.message(status, log)
   else
      _logging.alert("COMMAND :" .. command, log)
      _logging.alert("STATUS", log)
      _logging.alert(bool, log)
      _logging.alert(msg, log)
      _logging.alert(status, log)
      error("Command '" .. command .. "' exited with errors.")
   end
   
   -- Return status
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
