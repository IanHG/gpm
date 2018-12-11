local M = {}

local math  = assert(require "math")

local class = assert(require "lib.class")
local util  = assert(require "lib.hwdetect.util")

--- Mem class
local mem_class = class.create_class()

-- Constructor
function mem_class:__init()
   self.saved_as      = "kB"
   self.conversion    = 1024
   self.relation      = {"B", "kB", "MB", "GB", "TB", "PB"}
   self.relation_idx  = {}
   for k,v in pairs(self.relation) do
      self.relation_idx[v] = k
   end
   
   self.mem = {
      total     = nil,
      available = nil,
      free      = nil,

      swap_total = nil,
      swap_free  = nil,
   }
end

function mem_class:conversion_factor(from, to)
   local from_idx = self.relation_idx[from]
   local to_idx   = self.relation_idx[to]

   return math.pow(self.conversion, from_idx - to_idx)
end

-- Print
function mem_class:print(args)
   local unit              = args.convert
   local conversion_factor = self:conversion_factor(self.saved_as, unit)
   
   if util.isempty(args.thing) then
      print("MEMINFO:")
      print("   MEM_TOTAL     : " .. self.mem.total)
      print("   MEM_AVAILABLE : " .. self.mem.available)
      print("   MEM_FREE      : " .. self.mem.free)
   else
      local str = self.mem[args.thing] * conversion_factor
      if not args.no_suffix then
         str = str .. unit
      end
      print(str)
   end
end

--- Set value in mem structure
local function set_value(mem_local, strvalue, value, unit)
   if not unit then
      unit = "kB"
   end

   mem_local.mem[strvalue] = tonumber(value) * mem_local:conversion_factor(unit, mem_local.saved_as)
end

--- Detect memory from /proc/meminfo file
--
local function detect_mem_from_meminfo(mem_local)
   local pipe0   = io.popen("cat /proc/meminfo")
   local meminfo = pipe0:read("*all") or "0"
   pipe0:close()

   for line in meminfo:gmatch(".-\n") do
      line = line:gsub("\n", "")
      
      -- Parse key/value pairs
      local key, value  = util.key_value_pair(line)
      local value_split = util.split(value, " ")
      
      if key:match("MemTotal") then
         set_value(mem_local, "total",      value_split[1], value_split[2])
      elseif key:match("MemAvailable") then
         set_value(mem_local, "available",  value_split[1], value_split[2])
      elseif key:match("MemFree") then
         set_value(mem_local, "free",       value_split[1], value_split[2])
      elseif key:match("MemFree") then
         set_value(mem_local, "free",       value_split[1], value_split[2])
      elseif key:match("SwapTotal") then
         set_value(mem_local, "swap_total", value_split[1], value_split[2])
      elseif key:match("SwapFree") then
         set_value(mem_local, "swap_free", value_split[1], value_split[2])
      end
   end
end

--- Detect memory
--
local function detect_mem()
   local mem_local = mem_class:create({})
   
   detect_mem_from_meminfo(mem_local)

   return mem_local
end

-- Load module
M.detect_mem = detect_mem

return M
