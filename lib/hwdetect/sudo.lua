local function check_is_root()
   local pipe0 = io.popen("id -u")
   local idcmd = pipe0:read("*all") or ""
   pipe0:close()
   if idcmd == "0" then
      return true
   else
      return false
   end
end

local function sudo(command_str)
   local sudo_str = ""
   if not check_is_root() then
      sudo_str = "sudo"
   end

   local sudo_command_str = sudo_str .. " " .. command_str

   return sudo_command_str
end

local M = sudo

return M
