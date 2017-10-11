M = {}

--- Log a message
--
-- @param msg   The message
-- @param log   A single output stream or a set of output streams
-- @param raw   Print raw message, or add newline to the end
local function message(msg, log, raw)
   if log then
      -- Create message
      if not msg then
         msg = ""
      end
      if not raw then
         msg = msg .. "\n"
      end
      msg = " --> " .. msg

      -- Print  message to logs
      if type(log) == "table" then
         for key, value in pairs(log) do
            value:write(msg)
         end
      else
         log:write(msg)
      end
   end
end

-- Load module
M.message = message

return M
