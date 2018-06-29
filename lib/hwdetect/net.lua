local M = {}

local class = assert(require "lib.class")
local util  = assert(require "lib.hwdetect.util")

local net_iface_class = class.create_class()

function net_iface_class:__init()
   self.name      = "UNKNOWN"
   self.operstate = "UNKNOWN"
   self.carrier   = -1
   self.mtu       = -1
end

function net_iface_class:print()
   io.write(string.format("%-10s", self.name))
   io.write(string.format(":"))
   if self.carrier == 1 then
      io.write("   Is UP with state : " .. self.operstate)
   elseif self.carrier == 0 then
      io.write("   Is DOWN with state : " .. self.operstate)
   else
      io.write("   Unknown carrier flag.")
   end
   io.write("\n")
end

local net_ib_class = class.create_class()

function net_ib_class:__init()
   self.status = 0
   self.serror = nil
   
   self.ports  = {}
end

function net_ib_class:error(status, str)
   self.status = status
   self.serror = str
end

function net_ib_class:print()
   -- print all
   for k, v in pairs(self.ports) do
      print("  IB " .. k)
      for kinner, vinner in pairs(self.ports[k]) do
         print("      " .. kinner .. " : " .. vinner)
      end
   end
end

local net_info_class = class.create_class()

function net_info_class:__init()
   self.status = 0
   self.serror = nil

   self.ifaces = {}
   self.mellanox_infiniband_detected = false
   self.ib     = nil
end

function net_info_class:print()
   --print("Infiniband : " .. util.booltostr(self.mellanox_infiniband_detected))

   for k, v in pairs(self.ifaces) do
      self.ifaces[k]:print()
   end
   
   if self.ib then
      self.ib:print()
   end
end

--- Mellanox infiniband was found, try to figure out specifics.
-- Uses 'ibstat' command.
--
-- @param net_info     On output will hold infiniband specs.
local function detect_mellanox_infiniband(net_info)
   net_info.mellanox_infiniband_detected = true
   net_info.ib = net_ib_class:create()
   
   local pipe0  = io.popen("ibstat")
   
   if not pipe0 then
      net_info.ib.error(-1, "'ibstat' failed")
      return
   end

   local ibstat = pipe0:read("*all") or "0"
   pipe0:close()
   
   local iterator     = ibstat:gmatch(".-\n")
   local running      = true
   local already_read = false
   local var          = nil
   while running do
      if not already_read then
         var = iterator()
      else
         already_read = false
      end

      if var == nil then
         running = false
      else
         var = var:gsub ("\n", "")
         
         -- Parse key/value pairs
         local key, value = util.key_value_pair(var)
         
         if key:match("Port %d+") then
            local port = key
            net_info.ib.ports[port] = { }
            local inner_running = true
            while inner_running do
               var = iterator()
               if var == nil then
                  running = false
                  break
               end
               
               var = var:gsub("\n", "")
               
               if var:match("Port %d+") then
                  already_read = true
                  inner_running = false
               else
                  -- Parse key/value pairs
                  local key, value = util.key_value_pair(var)

                  net_info.ib.ports[port][util.key(key)] = value
               end
            end
         else
            net_info.ib[util.key(key)] = value
         end
      end
   end
end

--- Detect fast network (infiniband/omnipath (NOT IMPLEMENTED)).
-- Will look at output from 'lspci' command and try to figure out whether
-- a fast network is available.
--
-- @param net_info     On output will hold fast network specs.
local function detect_fast_network(net_info)
   local mellanox_infiniband = false
   
   local pipe0 = io.popen("lspci")
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
end

--- 
--
local function detect_network_interface(interface, net_info)
   net_info.ifaces[interface] = net_iface_class:create()
   net_info.ifaces[interface].name = interface

   local pipe0 = io.popen("grep \"\" -sH /sys/class/net/" .. interface .. "/*")
   local grep  = pipe0:read("*all") or "0"
   pipe0:close()

   for line in grep:gmatch(".-\n") do
      line = line:gsub("\n", "")
      
      -- Parse key/value pairs
      local key, value = util.key_value_pair(line)
      key = util.getfilename(key)

      if key == "operstate" then
         net_info.ifaces[interface].operstate = value
      elseif key == "carrier" then
         net_info.ifaces[interface].carrier   = tonumber(value)
      elseif key == "mtu" then
         net_info.ifaces[interface].mtu       = tonumber(value)
      end
   end
end

---
--
local function detect_network_interfaces(net_info)
   local pipe0 = io.popen("ls /sys/class/net")
   local lssysclassnet = pipe0:read("*all") or "0"
   pipe0:close()
      
   for interface in lssysclassnet:gmatch(".-\n") do
      interface = interface:gsub("\n", "")

      detect_network_interface(interface, net_info)
   end
end

--- Create instance of net_info_class and return.
-- This is for use with specialized network detection functions.
--
-- @return     Returns instance of net_info_class.
local function create_net_info()
   local  net_info = net_info_class:create()
   return net_info
end

--- Detect everything e can about networking.
-- This will try to detect fast network (e.g. infiniband) as well.
--
-- @return    Returns instance of net_info_class.
local function detect_net()
   local net_info = net_info_class:create({})

   detect_network_interfaces(net_info)
   
   detect_fast_network(net_info)
  
   return net_info
end

-- Load module
M.create_net_info   = create_net_info
M.detect_net        = detect_net
M.detect_interfaces = detect_network_interfaces
M.detect_fast       = detect_fast_network

return M
