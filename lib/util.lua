local _execcmd = assert(require "lib.execcmd")
local _logging = assert(require "lib.logging")
local hwdetect_util = assert(require "lib.hwdetect.util")

local M = {}

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  return res
end

--- Merge two tables recursively.
-- 
-- If both tables have the same entry, 
-- the one from the primary table is carried over to the merged table.
--
-- @param a   Primary table.
-- @param b   Secondary table.
--
-- @return   Returns the merged table.
local function merge(a, b)
   if type(a) == 'table' and type(b) == 'table' then
      for k,v in pairs(b) do 
         if type(v)=='table' and type(a[k] or false)=='table' then 
            merge(a[k], v)
         elseif (a[k] or false) then
            -- Key was present in a, so we nothing as a is primary table
         else 
            -- Key was not present in a so we copy from b
            a[k] = copy(v)
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
local function execute_command(command, log, check)
   if check == nil then
      check = true
   end

   -- Do some pre-logging
   _logging.message("EXECUTING COMMAND : " .. command, log)

   -- Run the command
   --bool, msg, status = _execcmd.execcmd_shexec(command, log)
   bool, msg, status = _execcmd.execcmd_bashexec(command, log)
   
   -- Do some post logging
   if (not check) or bool then
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

--- Conditional statement.
--
-- Can take three parameters.
--
-- @param conditional
-- @param if_true
-- @param if_false
--
-- @return If conditional is true, returns if_true, else returns if_false.
local function conditional(condition, if_true, if_false)
   if condition then 
      return if_true 
   else 
      return if_false 
   end
end

function deepcompare(t1,t2,ignore_mt)
   local ty1 = type(t1)
   local ty2 = type(t2)
   if ty1 ~= ty2 then return false end
   -- non-table types can be directly compared
   if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
   -- as well as tables which have the metamethod __eq
   local mt = getmetatable(t1)
   if not ignore_mt and mt and mt.__eq then return t1 == t2 end
   for k1,v1 in pairs(t1) do
      local v2 = t2[k1]
      if v2 == nil or not deepcompare(v1,v2) then return false end
   end
   for k2,v2 in pairs(t2) do
      local v1 = t1[k2]
      if v1 == nil or not deepcompare(v1,v2) then return false end
   end
   return true
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
M.deepcompare = deepcompare
M.isempty = hwdetect_util.isempty

return M
