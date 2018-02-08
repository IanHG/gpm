M = {}

local ansicolor = require "lib.ansicolor"

--- Create message
-- 
-- Create a message with a prefix, and an optional newline.
--
-- @param msg
-- @param prefix
-- @param raw
--
-- @return Returns the created message.
local function create_message(msg, prefix, postfix, raw)
   -- Create message
   if not msg then
      msg = ""
   else
      msg = tostring(msg)
   end
   if not raw then
      msg = msg:gsub("\n", "\n" .. prefix)
      msg = prefix .. msg .. postfix .. "\n"
   end
   return msg
end

--- Print a message to one or several logs.
--
-- @param msg
-- @param log
local function write_to_log(msg, log)
   -- Print  message to logs
   if type(log) == "table" then
      for key, value in pairs(log) do
         value:write(msg)
      end
   else
      log:write(msg)
   end
end

--- Log a message
--
-- Print message to log files.
--
-- @param msg   The message
-- @param log   A single output stream or a set of output streams
-- @param raw   Print raw message, or add newline to the end
local function message(msg, log, raw)
   if log then
      -- Create message
      msg = create_message(msg, ansicolor.bold .. ansicolor.green .. " --> " .. ansicolor.default, ansicolor.reset, raw)
      
      -- Then write to log
      write_to_log(msg, log)
   end
end

--- Print alert to log.
--
-- Print alert to log files.
--
-- @param msg   The message
-- @param log   A single output stream or a set of output streams
-- @param raw   Print raw message, or add newline to the end
local function alert(msg, log, raw)
   if log then
      -- Create message
      msg = create_message(msg, ansicolor.bold .. ansicolor.red .. " !!! " .. ansicolor.default, ansicolor.reset, raw)
      
      -- Then write to log
      write_to_log(msg, log)
   end
end

--- Print alert to log.
--
-- Print alert to log files.
--
-- @param msg   The message
-- @param log   A single output stream or a set of output streams
-- @param raw   Print raw message, or add newline to the end
local function debug(msg, log, raw)
   if log then
      -- Create message
      msg = create_message(msg, ansicolor.bold .. ansicolor.blue .. " >>> " .. ansicolor.default, ansicolor.reset, raw)
      
      -- Then write to log
      write_to_log(msg, log)
   end
end

--- Match line with a list of strings.
--
-- Grep helper function. Will check whether a speficic string matches a set of search strings.
-- These can be positive or negative matches.
--
-- @param search_strings  The strings to search for.
-- @param line            The line to check.
-- @param negate          Look for negative matches.
--
-- @return   Returns true if line matches all strings, otherwise false.
local function search_for_strings(search_strings, line, negate)
   -- Initialize default variable
   if negate == nil then
      negate = false
   end

   -- Loop through list of strings and if a match is not found we return false.
   for _,str in pairs(search_strings) do
      if not negate then
         -- Look for match, so if the line doesn't match we return false now.
         if not line:match(str) then
            return false
         end
      else
         -- Look for negative match, so ifthe line matches we return false now.
         if line:match(str) then
            return false
         end
      end
   end

   -- All strings matched, so we return true.
   return true
end

--- "Grep" in log file and return list of hits.
--
-- Grep in file for matching hits. 
-- Prepending a string with '*', will make it a negative search,
-- which will exclude all matching hits.
-- Can search for both positive and negative matches in same search.
--
-- @param search_str  String or array of strings to search for.
-- @param log_path    Path of log file.
--
-- @return    Returns list of hits.
local function grep(search_strings, log_path)
   local result = {}
   local search_pos = {}
   local search_neg = {}
   
   -- Setup search strings
   for _,str in pairs(search_strings) do
      if str:match("*") then --and (not str:match("\*"))) then
         search_neg[#search_neg + 1] = str:gsub("*","")
      else
         search_pos[#search_neg + 1] = str
      end
   end

   -- Do the search
   for line in io.lines(log_path) do
      if search_for_strings(search_pos, line) then 
         if search_for_strings(search_neg, line, true) then
            result[#result + 1] = line
         end
      end
   end

   -- Return results
   return result
end

-- Load module
M.message = message
M.alert   = alert
M.debug   = debug
M.grep    = grep

return M
