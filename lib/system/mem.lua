local M = {}

local class = assert(require "lib.class")
local util  = assert(require "lib.system.util")

local mem_class = class.create_class()

function mem_class:__init()
   self.mem_available = "UNKNOWN"
   self.mem_total     = "UNKNOWN"
   self.mem_free      = "UNKNOWN"
end

function mem_class:print()
   print("MEMINFO:")
   print("   MEM_TOTAL     : " .. self.mem_total)
   print("   MEM_AVAILABLE : " .. self.mem_available)
   print("   MEM_FREE      : " .. self.mem_free)
end

---
--
local function detect_mem()
   local mem_local = mem_class:create({})
   
   local pipe0   = io.popen("cat /proc/meminfo")
   local meminfo = pipe0:read("*all") or "0"
   pipe0:close()

   for line in meminfo:gmatch(".-\n") do
      line = line:gsub("\n", "")
      
      -- Parse key/value pairs
      local key, value = util.key_value_pair(line)
      
      if key:match("MemTotal") then
         mem_local.mem_total = value
      elseif key:match("MemAvailable") then
         mem_local.mem_available = value
      elseif key:match("MemFree") then
         mem_local.mem_free = value
      end
   end

   return mem_local
end

-- Load module
M.detect_mem = detect_mem

return M
