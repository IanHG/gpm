local M = {}

-- Some string helper functions

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

-- Special split function that takes number of occurences to split.
local function split(inputstr, sep, noccur)
   if inputstr == nil then
      return {}
   end
   if sep == nil then
      sep = "%s"
   end
   local t={} ; i=1
   if noccur == nil then
      for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
         t[i] = str
         i = i + 1
      end
   else
      noccur = noccur + 1
      for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
         if i <= noccur then
            t[i] = str
            i = i + 1
         else
            t[noccur] = t[noccur] .. sep .. str
            i = i + i
         end
      end
   end
   return t
end

local function trim(s)
   local n = s:find"%S"
   return n and s:match(".*%S", n) or ""
end

local function getfilename(path)
   return path:match("^.+/(.+)$")
end

--- Create uid generator
--
-- @return   Returns Unique ID (uid) generator function.
local function create_uid_generator()
   local uid = 0
   local function uid_generator()
      uid = uid + 1
      return uid
   end

   return uid_generator
end

--- Get key/value pair from string.
-- @param s {string}    String with key/value pair using ":" delimeter.
--
-- @return Returns key, value.
local function key_value_pair(s)
   local t = split(s, ":", 1)
   if not t[1] then
      t[1] = "UNKNOWN_KEY"
   end
   if not t[2] then
      t[2] = "UNKNOWN_VALUE"
   end
   t[1] = trim(t[1])
   t[2] = trim(t[2])
   return t[1], t[2]
end

--- Convert bool to string for pretty printing.
local function booltostr(b)
   if b then
      return "true"
   else
      return "false"
   end
end

--- Make key from trimmed string.
-- This amounts to making everything lowercase and substituting space (" ") for underscore ("_").
-- 
-- @param str    The str to make into a key.
--
-- @return       Returns key from str.
local function key(str)
   local key = string.lower(str):gsub(" ", "_")
   return key
end

-- Load module
M.isempty              = isempty
M.split                = split
M.trim                 = trim
M.key_value_pair       = key_value_pair
M.create_uid_generator = create_uid_generator
M.booltostr            = booltostr
M.getfilename          = getfilename
M.key                  = key

return M
