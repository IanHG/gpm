M = {}

local posix = assert(require "posix")
local io    = assert(require "io")
local os    = assert(require "os")

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

--- Make sure that fd' have correct format.
--
-- @param fd   A single fd or a set of fd's.
--
-- @return   Return a vector of fd,bool pairs.
local function fd_boostrap(fd)
   local vfd = {}
   if type(fd) == "table" then
      for k,v in pairs(fd) do
         vfd[#vfd + 1] = {v, true}
      end
   else
      vfd = { {fd, true} }
   end
   return vfd
end

--- Read a filedescriptor in chunks and log the output to a set of log files.
--
-- @param fd         The filedescriptor to read.
-- @param log        A set of optional logfiles.
-- @param chunksize  Optional chunksize (default 1024).
--
local function read_from_fds(fd, log, chunksize)
   -- Set default chunksize
   if not chunksize then
      chunksize = 2048
   end
   
   -- Bootstrap fd's into correct format
   fd = fd_boostrap(fd)
   
   -- Read the file descriptor
   while true do
      for ifd = 1, #fd do
         if fd[ifd][2] then
            local line, msg, errnum = posix_read(fd[ifd][1], chunksize)

            -- Check if we read something
            if (not line) or (line == "") then 
               -- If we didn't we check for EAGAIN
               if errnum ~= posix.EAGAIN then
                  fd[ifd][2] = false
               end
            else
               -- If we did, we log it
               if log then
                  if type(log) == "table" then
                     for key, value in pairs(log) do
                        if type(log[key]) == "string" then
                           log[key] = log[key] .. line
                        else
                           log[key]:write(line)
                        end
                     end
                  else
                     if type(log) == "string" then
                        log = log .. line
                     else
                        log:write(line)
                     end
                  end
               end
            end
         end
      end
      
      -- Check for break of while
      local dobreak = true
      for ifd = 1, #fd do
         if fd[ifd][2] then
            dobreak = false
         end
      end

      if dobreak then
         break
      end
   end
end

--- Execute shell command and log stdout and stderr to a set of output streams.
--
-- @param cmd   The command to run.
-- @param log   An optional set of log files.
--
-- @return     Returns bool, msg, and status of running command (more or less like os.execute).
local function execcmd_impl(cmd, log)
   -- Setup some output variables
   local wpid, msg, status

   -- Create io pipes 
   local stdout_rd, stdout_rw = pipe()
   local stderr_rd, stderr_rw = pipe()
   
   -- Make pipes read-end non-blocking
   --local outflag = posix.fcntl(stdout_rd, posix.F_GETFL)
   --local errflag = posix.fcntl(stderr_rd, posix.F_GETFL)
   posix.fcntl(stdout_rd, posix.F_SETFL, posix.O_NONBLOCK);
   posix.fcntl(stderr_rd, posix.F_SETFL, posix.O_NONBLOCK);
   
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
      read_from_fds({stdout_rd, stderr_rd}, log)
      
      -- We are done reading, so close read end of pipe on parent
      posix_close(stdout_rd)
      posix_close(stderr_rd)
      
      -- Wait for child
      wpid, msg, status = execwait(pid)
   end
      
   -- Return status of call
   if status == 0 then
      return true, msg, status
   else
      return false, msg, status
   end
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
   return execcmd_impl({[0] = "sh", "-exec", cmd}, log)
end

--- Execute command with 'bash -exec' and log output to a set of output streams.
--
-- @param cmd  The command.
-- @param log  An optional log.
--
-- @return   Returns status of cmd.
local function execcmd_bashexec(cmd, log)
   -- Fix input if needed
   cmd = cmd_ensure_string(cmd)
   
   -- Then call execcmd impl
   return execcmd_impl({[0] = "bash", "-exec", cmd}, log)
end

-- Load module
M.execcmd          = execcmd
M.execcmd_shexec   = execcmd_shexec
M.execcmd_bashexec = execcmd_bashexec

return M
