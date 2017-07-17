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

M.print = table_print
M.merge = merge
M.mkdir_recursively = mkdir_recursively

return M
