M = {}

require "posix"

-- Setup posix binds, such that the module works with different versions of luaposix
local posix_read = nil
local posix_pipe = nil
local posix_fork = nil
local posix_execp = nil
local posix_dup2 = nil
local posix_close = nil

local function setup_posix_binds()
   if posix.unistd then
      posix_read  = posix.unistd.read
      posix_pipe  = posix.unistd.pipe
      posix_fork  = posix.unistd.fork
      posix_execp = posix.unistd.execp
      posix_dup2  = posix.unistd.dup2
      posix_close = posix.unistd.close
   else
      posix_read  = posix.read
      posix_pipe  = posix.pipe
      posix_fork  = posix.fork
      posix_execp = posix.execp
      posix_dup2  = posix.dup2
      posix_close = posix.close
   end

   if posix.sys then
      if posix.sys.wait then
         posix_wait = posix.sys.wait.wait
      else
         posix_wait = posix.wait
      end
   else
      posix_wait = posix.wait
   end

   if posix.stdio then
      posix_fileno = posix.stdio.fileno
   else
      posix_fileno = posix.fileno
   end
end

setup_posix_binds()


--- Create a posix pipe
--
-- @return    If successful return read- and write- ends of pipe.
local function pipe()
   -- Returns:
   -- int  read end file descriptor
   -- int  write end file descriptor
   --
   -- Or:
   -- nil
   -- string  error message
   -- int     errnum
   local rd, rw, errnum = posix_pipe()
   if not rd then
      print("could not create pipe : " .. rw .. " " .. string(errnum))
   end
   return rd, rw
end

--- Wait for process
local function execwait(pid)
   -- Returns:
   -- 
   -- int     pid of terminated child, if successful
   -- string  "exited", "killed" or "stopped"
   -- int     exit status, or signal number responsible for "killed" or "stopped"
   -- 
   -- Or:
   --
   -- nil
   -- string  error message
   -- int     errnum
   --
   print("WAIT")
   local pid, msg, status = posix_wait(pid)
   
   if not pid then
      print("Could not wait : " .. msg)
   end

   return pid, msg, status
end

--- Shift command index to start from 0, as required by posix/C.
-- 
-- @param cmd   The command vector to shift.
--
-- @return Returns the shifted cmd vector.
local function cmd_ensure_vector(cmd)
   if type(cmd) == "table" then
      return cmd
   else
      return {[0] = cmd}
   end
end

--- Ensure that command is a single string.
--
-- @param cmd   The command.
-- 
-- @return   Return command as single string.
local function cmd_ensure_string(cmd)
   local scmd = ""
   if type(cmd) == "table" then
      for idx = 1, #cmd do
         scmd = scmd .. " " .. cmd[idx] 
      end
      return scmd
   else
      return cmd
   end
end

--- Read a filedescriptor in chunks and log the output to a set of log files.
--
-- @param fd         The filedescriptor to read.
-- @param log        A set of optional logfiles.
-- @param chunksize  Optional chunksize (default 1024).
--
local function read_from_fd(fd, log, chunksize)
   -- Set default chunksize
   if not chunksize then
      chunksize = 1024
   end
   
   -- Read the file descriptor
   while true do
      local line = posix_read(fd, 1024)
      if (not line) or (line == "") then break end

      if log then
         if type(log) == "table" then
            for key, value in pairs(log) do
               value:write(line)
            end
         else
            log:write(line)
         end
      end
   end
end

--- Execute shell command and log stdout and stderr to a set of output streams.
--
-- @param cmd   The command to run.
-- @param log   An optional set of log files.
--
-- @return     Returns status of running command.
local function execcmd_impl(cmd, log)
   -- Setup some output variables
   local wpid, msg, status

   -- Create io pipes 
   local stdout_rd, stdout_rw = pipe()
   local stderr_rd, stderr_rw = pipe()
   
   -- Fork process
   local pid, errmsg, errnum = posix_fork()
   
   if pid == nil then
      -- Error 
      error (errmsg)
   elseif pid == 0 then
      -- Child
      -- Duplicate write end of pipes to childs stdout and stderr
      posix_dup2(stdout_rw, posix_fileno(io.stdout))
      posix_dup2(stderr_rw, posix_fileno(io.stderr))
      
      -- Close fd's on child (the called process should not know of these, and they have already been duplicated)
      posix_close(stdout_rd)
      posix_close(stderr_rd)
      posix_close(stdout_rw)
      posix_close(stderr_rw)
      
      -- Do exec call
      print("EXEC")
      local bool, msg = posix_execp(cmd[0], cmd)

      -- If there is an error we report and exit child
      if not bool then
         print("could not exec : " .. msg)
      end
      os.exit(1)
   else
      -- Parent
      -- Close write end of pipe on parent
      posix_close(stdout_rw)
      posix_close(stderr_rw)
      
      -- Read output from child
      read_from_fd(stdout_rd, log)
      read_from_fd(stderr_rd, log)
      
      -- We are done reading, so close read end of pipe on parent
      posix_close(stdout_rd)
      posix_close(stderr_rd)
      
      -- Wait for child
      wpid, msg, status = execwait(pid)
   end
      
   -- Return status of call
   return status
end

--- Execute command and log output to a set of output streams.
--
-- @param cmd  The command.
-- @param log  An optional log.
--
-- @return   Returns status of cmd.
local function execcmd(cmd, log)
   -- Fix input if needed
   cmd = cmd_ensure_vector(cmd)
   
   -- Then call execcmd impl
   return execcmd_impl(cmd, log)
end

--- Execute command with 'sh -exec' and log output to a set of output streams.
--
-- @param cmd  The command.
-- @param log  An optional log.
--
-- @return   Returns status of cmd.
local function execcmd_shexec(cmd, log)
   -- Fix input if needed
   cmd = cmd_ensure_string(cmd)
   
   -- Then call execcmd impl
   return execcmd_impl({[0] = "/bin/sh", "-exec", cmd}, log)
end

-- Load module
M.execcmd        = execcmd
M.execcmd_shexec = execcmd_shexec

return M
