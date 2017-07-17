local M = {}

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
-- Make a directory recursively
-------------------------------------
local function mkdir_recursively(dir)
   function find_last(haystack, needle)
      local i=haystack:match(".*"..needle.."()")
      if i==nil then return nil else return i-1 end
   end
   p = dir:sub(1, find_last(dir, "/") - 1)
   if not lfs.attributes(p) then
      mkdir_recursively(p)
   end
   lfs.mkdir(dir)
end

-------------------------------------
-- Run command in shell.
--
-- @param command
--
-- @return{Boolean}
-------------------------------------
local function execute_command(command)
   bool, flag, status = os.execute(command)

   if not bool then
      error("Command '" .. command .. "' exited with errors.")
   end
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
-- Copy a file
-------------------------------------
local function copy_file(src, dest)
   infile = io.open(src, "r")
   instr = infile:read("*a")
   infile:close()

   outfile = io.open(dest, "w")
   outfile:write(instr)
   outfile:close()
end

-------------------------------------
-- Split a string
-------------------------------------
local function split(inputstr, sep)
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
function trim(s)
    local n = s:find"%S"
     return n and s:match(".*%S", n) or ""
end

-- Load module functions
M.print = table_print
M.merge = merge
M.mkdir_recursively = mkdir_recursively
M.execute_command = execute_command
M.substitute_placeholders = substitute_placeholders
M.copy_file = copy_file
M.split = split
M.trim = trim

return M
