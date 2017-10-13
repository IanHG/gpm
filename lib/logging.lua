M = {}

local ansicolor = require "ansicolor"

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

-- Load module
M.message = message
M.alert   = alert
M.debug   = debug

return M
