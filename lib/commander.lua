local M = {}

local class   = require "lib.class"

--- Class to hold single commands.
-- A command definition includes a 'fn' taking up to 3 arguments:
--    options
--    input
--    output
--
-- Options are defined on command creation, and on runtime input will hold the output from the last command.
-- On output, everything that should be passed to the next command, must be put in the output dictionary.
--
local command_class = class.create_class()

function command_class:__init()
   self.ctype   = nil
   self.fn      = nil
   self.options = nil
end

function command_class:substitute(symbtab)
   if self.options then
      for k, v in pairs(self.options) do
         self.options[k] = symbtab:substitute(v)
      end
   end
end

--- Class for creating commands.
-- Commands are added with a label and a function, and can subsequently be created using the same label,
-- and a dictionary with command options. Options may vary from command to command.
--
local command_creator_class = class.create_class()

function command_creator_class:__init(logger)
   print(logger)
   self._logger   = logger
   self._fn_table = {}
end

function command_creator_class:add(ctype, fn, overwrite)
   if (self._fn_table[ctype] ~= nil) and (not overwrite) then
      assert(false)
   end
   
   self._fn_table[ctype] = fn
end

function command_creator_class:command(ctype, options)
   if not self._fn_table then
      assert(false)
   end

   if not self._fn_table[ctype] then
      if self._logger then
         self._logger:alert("No such command '" .. ctype .. "'.")
      end
      return nil
   end

   local command = command_class:create()
   command.ctype   = ctype
   command.fn      = self._fn_table[ctype]
   command.options = options

   return command
end

--- Class for executing command.
--  Use this class to execute commands. 
--  Will pipe the output from one command to the next.
--  Can also check status of a command after running it.
--  
local command_executor_class = class.create_class()

function command_executor_class:__init(logger)
   self._logger = logger

   self._last = {
      status = 0 ,
      output = {},
   }
end

function command_executor_class:_log_pre_execute_command(command)
   if self._logger then
      self._logger:message("Running command : '" .. command.ctype .. "'.")
   end
end

function command_executor_class:_log_post_execute_command(command)
   if self._logger then
      if self._last.output.stdout then
         self._logger:message(tostring(self._last.output.stdout), "raw")
      end
      if not self._last.status then
         self._logger:alert("   Exit status : " .. tostring(self._last.status))
      else
         self._logger:message("   Exit status : " .. tostring(self._last.status))
      end
   end
end

function command_executor_class:_execute_command(command)
   if command.is_a and command:is_a(command_class) then
      self:_log_pre_execute_command(command)
      local input = self._last.output
      input.logger = self._logger
      self._last = { status = 0, output = { } }
      command.fn(command.options, input, self._last)
      self:_log_post_execute_command(command)
      
      if self._last.status == false then
         assert(false)
      end
   else
      if self._logger then
         self._logger:alert("Executor was passed something that is not a command!")
      end
      if type(command) == "string" then
         self._last = {
            status = false,
            output = {
               string = command,
            },
         }
      else
         self._last = {
            status = false,
            output = {
               stdout = "",
               stderr = "",
            },
         }
      end
   end
end

function command_executor_class:execute(command)
   if type(command) == "table" then
      for k, v in pairs(command) do
         self:_execute_command(v)
      end
   else
      self:_execute_command(command)
   end
end

--- Create a command 'executor'
local function create_executor(...)
   local  executor = command_executor_class:create(...)
   return executor
end

--- Create a command 'creator'
local function create_creator(...)
   local  creator = command_creator_class:create(...)
   return creator
end

M.create_executor = create_executor
M.create_creator  = create_creator

return M
