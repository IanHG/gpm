local util = require "util"
local install = require "install"

local M = {}

-------------------------------------
-- Bootstrap the remove command.
--
-- @param{Table} args   The commandline arguments.
-------------------------------------
local function bootstrap_remove(args)
end

-------------------------------------
-- Remove a package from the software stack.
--
-- @param{Table} args   The commandline arguments.
-------------------------------------
local function remove(args)
   -- Try
   exception.try(function()
      -- Bootstrap the package we are removing
      package = install.bootstrap_package(args)

   end, function (e)
      exception.message(e)
      error(e)
   end)
end

M.remove = remove

return M
