local M = {}

local class = assert(require "lib.class")
local util  = assert(require "lib.hwdetect.util")

local net_info_class = class.create_class()

function net_info_class:__init()
end

function net_info_class:print()
   print("Infiniband : " .. util.booltostr(self.mellanox_infiniband_detected))
end

--- Mellanox infiniband was found, try to figure out specifics.
--
-- @param net_info     On output will hold infiniband specs.
local function detect_mellanox_infiniband(net_info)
   net_info.mellanox_infiniband_detected = true
end

---
--
local function detect_net()
   local net_info = net_info_class:create({})
   
   local mellanox_infiniband = false
   
   local pipe0   = io.popen("lspci")
   local lspci = pipe0:read("*all") or "0"
   pipe0:close()
   
   for line in lspci:gmatch(".-\n") do
      line = line:gsub ("\n", "")

      if line:match("Mellanox") and line:match("Infiniband") then
         mellanox_infiniband = true
      end
   end
   
   -- Mellanox inifiband
   if mellanox_infiniband then
      detect_mellanox_infiniband(net_info)
   end

   return net_info
end

-- Load module
M.detect_net = detect_net

return M
