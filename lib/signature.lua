local M = {}

--- Load libraries
local luautil    = assert(require "lib.luautil")
local class      = assert(require "lib.class")
local util       = assert(require "lib.util")
local filesystem = assert(require "lib.filesystem")
local path       = assert(require "lib.path")
local logging    = assert(require "lib.logging")
local logger     = logging.logger
local http       = luautil.require("socket.http")

--- File signature checker
local signature_class = class.create_class()

function signature_class:__init()
   --
   self.shasum = "sha512sum"
end

function signature_class:__shasum_check_signature(file_path, sig_path)
   local cmd = self.shasum .. " " .. file_path
   local status = util.execute_command(cmd, false)
   return false
end

function signature_class:__gpg_check_signature(file_path, sig_path)
   local  cmd    = "gpg --keyserver-options auto-key-retrieve --verify " .. sig_path .. " " .. file_path
   local  status = util.execute_command(cmd, false)
   return status
end

function signature_class:check_signature(file_path, sig_path)
   -- Get signature extension
   local sig_ext = path.get_file_ext(sig_path)
   
   -- Based on extension of signature file, try to verify the signature
   local status = false
   if (sig_ext == "sig") or (sig_ext == "asc") then
      status = self:__gpg_check_signature(file_path, sig_path)
   elseif (sig_ext == "sum") then
      status = self:__shasum_check_signature(file_path, sig_path)
   else
      logger:alert("Signature extension '" .. sig_ext .. "' not known.")
   end
   
   -- Return status of verifycation
   return status
end

local function create()
   local  sig_checker = signature_class:create()
   return sig_checker
end

---
M.create = create

---
return M
