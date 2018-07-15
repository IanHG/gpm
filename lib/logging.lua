local ansicolor = assert(require "lib.ansicolor")
local class     = assert(require "lib.class")

M = {}

--- Create message
-- 
-- Create a message with a prefix, and an optional newline.
--
-- @param msg
-- @param prefix
-- @param format
--
-- @return Returns the created message.
local function create_message(msg, prefix, postfix, format)
   -- Create message
   
   -- Make sure variable msg is a string
   if msg == nil then
      msg = ""
   else
      msg = tostring(msg)
   end

   -- Create message with correct format
   if ((not format) or (format == "fancy")) then
      msg = msg:gsub("\n", "\n" .. prefix)
      msg = prefix .. msg .. postfix .. "\n"
   elseif (format == "newline") then
      msg = msg .. "\n"
   end

   return msg
end

--- Print a message to one or several logs.
--
-- @param msg    The message to log.
-- @param log    A single log or a set of logs.
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
-- @param format   Print raw message, or add newline to the end
local function message(msg, log, format)
   if log then
      -- Create message
      msg = create_message(msg, ansicolor.bold .. ansicolor.green .. " --> " .. ansicolor.default, ansicolor.reset, format)
      
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
-- @param format   Print format message, or add newline to the end
local function alert(msg, log, format)
   if log then
      -- Create message
      msg = create_message(msg, ansicolor.bold .. ansicolor.red .. " !!! " .. ansicolor.default, ansicolor.reset, format)
      
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
-- @param format   Print raw message, or add newline to the end
local function debug(msg, log, format)
   --if global_config.debug then
      if log then
         -- Create message
         msg = create_message(msg, ansicolor.bold .. ansicolor.blue .. " >>> " .. ansicolor.default, ansicolor.reset, format)
         
         -- Then write to log
         write_to_log(msg, log)
      end
   --end
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
         search_pos[#search_pos + 1] = str
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

--- Log the call to gpm in the stack log-file.
--
-- @param stack  Boolean, are we running a stack command?
--
-- Log the gpm-package call in the stack log-file, adding a date and username of
-- the user who made the call. This creates a log over all
-- calls such that it is easy to see how a package was installed,
-- and by whom.
local function log_call(stack)
   if global_config.log_path then
      -- Open log file
      local logfile = io.open(global_config.log_path, "a")
      
      -- Create call string
      local call = ""
      for count = 0,#arg do
         if count == 0 then
            call = arg[count]
         else
            call = call .. " " .. arg[count]
         end
      end

      -- Get user who ran the command
      local user = os.getenv("USER")
      if not user then
         user = "INCOGNITO"
      end

      -- Log command
      local msg = ansicolor.yellow .. ansicolor.bold .. "[ " .. os.date("%c") .. " ] ( " .. user .. " ) " .. ansicolor.default .. call
      if stack then
         msg = msg .. ansicolor.blue " ... " .. ansicolor.default .. "Running\n"
      end
      
      message(msg , {logfile}, "raw")

      logfile:close()
   end
end

--- Log success/failure
-- 
-- @param success Boolean, was the call to gpm a success.
-- @param stack   Boolean, are we running stack command.
--
-- Log whether call to gpm-package ended succesfully or with an error.
-- This is written to the stack log-file after the command.
local function log_call_end(success, stack)
   if global_config.log_path then
      -- Open log file
      local logfile = io.open(global_config.log_path, "a")
      
      -- If stack do extra printout
      if stack then
         -- Get user who ran the command
         local user = os.getenv("USER")
         if not user then
            user = "INCOGNITO"
         end

         local msg = ansicolor.yellow .. ansicolor.bold .. "[ " .. os.date("%c") .. " ] ( " .. user .. " ) " .. ansicolor.default .. "Stack call"
         message(msg, {logfile}, true)
      end
      
      -- Print success/fail
      if success then
         message("Success!", {logfile})
      else
         alert("Failed!", {logfile})
      end
      
      -- Close the log file
      logfile:close()
   end
end

--- Create class for logging.
local logger_class = class.create_class()

function logger_class:__init()
   self.logs   = { }
   self.format = "fancy"
end

function logger_class:add_log(name, log)
   self.logs[name] = log
end

function logger_class:open_logfile(name, path)
   local log = io.open(path, "w")
   if not log then
      print(name)
      print(path)
      assert(false)
   end
   self.logs[name] = log
end

function logger_class:close_logfile(name)
   self.logs[name]:close()
   self.logs[name] = nil
end

function logger_class:write(msg)
   for k, v in pairs(self.logs) do
      v:write(msg)
   end
end

function logger_class:message(msg, format, logs)
   if not format then
      format = self.format
   end
   if not logs then
      logs = self.logs
   end

   message(msg, logs, format)
end

function logger_class:alert(msg, format, logs)
   if not format then
      format = self.format
   end
   if not logs then
      logs = self.logs
   end

   alert(msg, logs, format)
end

function logger_class:debug(msg, format, logs)
   --if global_config.debug then
      if not format then
         format = self.format
      end
      if not logs then
         logs = self.logs
      end

      debug(msg, logs, format)
   --end
end

-- Load module
M.message      = message
M.alert        = alert
M.debug        = debug
M.logger       = logger_class:create()
M.grep         = grep
M.log_call     = log_call
M.log_call_end = log_call_end

return M
