exception = {}

-------------------------------------
-- Simulate exceptions in Lua.
--
-- @param f       Function to try.
-- @param catch_f Function to run on exception.
-------------------------------------
local function try(f, catch_f)
   local status, exception = xpcall(f, debug.traceback)
   if not status then
      catch_f(exception)
   end
end

-------------------------------------
-- Print exception message
--
-- @param e Exception to print.
-------------------------------------
local function message(e)
   print ("[Exception caught : ]" .. e)
end

exception.try = try
exception.message = message

return exception
