local M = {}

local class = assert(require "lib.class")

-- Some string helper functions
local function isempty(s)
   return s == nil or s == ''
end

local function split(inputstr, sep, noccur)
   if inputstr == nil then
      return {}
   end
   if sep == nil then
      sep = "%s"
   end
   local t={} ; i=1
   if noccur == nil then
      for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
         t[i] = str
         i = i + 1
      end
   else
      noccur = noccur + 1
      for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
         if i <= noccur then
            t[i] = str
            i = i + 1
         else
            t[noccur] = t[noccur] .. sep .. str
            i = i + i
         end
      end
   end
   return t
end

local function trim(s)
   local n = s:find"%S"
   return n and s:match(".*%S", n) or ""
end

-- Vector instruction set dictionary
local function generate_vector_instruction_set_dictionary()
   local uid = -1
   local function get_uid_greater()
      uid = uid + 1
      return uid
   end

   local vector_instruction_set_dictionary = {}
   vector_instruction_set_dictionary["unknown"] = get_uid_greater()
   vector_instruction_set_dictionary["sse" ]    = get_uid_greater()
   vector_instruction_set_dictionary["sse2"]    = get_uid_greater()
   vector_instruction_set_dictionary["sse3"]    = get_uid_greater()
   vector_instruction_set_dictionary["sse4"]    = get_uid_greater()
   vector_instruction_set_dictionary["avx"]     = get_uid_greater()
   vector_instruction_set_dictionary["avx2"]    = get_uid_greater()
   vector_instruction_set_dictionary["avx512"]  = get_uid_greater()

   return vector_instruction_set_dictionary
end

local vector_instruction_set_dictionary = generate_vector_instruction_set_dictionary()

--- Get number of cores
--
local function get_ncores(cpuinfo)
   local count = select(2, string.gsub(cpuinfo, "processor", ""))
   return count
end

--- Get key/value pair from string.
-- @param s {string}    String with key/value pair using ":" delimeter.
--
-- @return Returns key, value.
local function key_value_pair(s)
   local t = split(s, ":", 1)
   if not t[1] then
      t[1] = "UNKNOWN_KEY"
   end
   if not t[2] then
      t[2] = "UNKNOWN_VALUE"
   end
   t[1] = trim(t[1])
   t[2] = trim(t[2])
   return t[1], t[2]
end

local function set_flags(isa_local_flags, flags)
   if flags:match("avx512") then
      isa_local_flags.vec_is       = "avx512"
      isa_local_flags.vec_is_level = vector_instruction_set_dictionary["avx512"]
   elseif flags:match("avx2") then
      isa_local_flags.vec_is       = "avx2"
      isa_local_flags.vec_is_level = vector_instruction_set_dictionary["avx2"]
   elseif flags:match("avx") then
      isa_local_flags.vec_is       = "avx"
      isa_local_flags.vec_is_level = vector_instruction_set_dictionary["avx"]
   elseif flags:match("sse2") then
      isa_local_flags.vec_is       = "sse2"
      isa_local_flags.vec_is_level = vector_instruction_set_dictionary["sse2"]
   elseif flags:match("sse") then
      isa_local_flags.vec_is       = "sse"
      isa_local_flags.vec_is_level = vector_instruction_set_dictionary["sse"]
   end

   for _, flag in pairs(split(flags, " ")) do
      isa_local_flags[flag] = true
   end

   if isa_local_flags["bmi1"] then
      isa_local_flags["bmi"] = true
   end

   if isa_local_flags["ssse3"] then
      isa_local_flags["sse3"] = true
   end

   if isa_local_flags["pclmulqdq"] then
      isa_local_flags["pclmul"] = true
   end

   if isa_local_flags["3dnowprefetch"] then
      isa_local_flags["prefetchw"] = true
   end
end

local function detect_intel_cpu_type(isa_local)
   local uid = -1
   local function get_uid_greater()
      uid = uid + 1
      return uid
   end

   local intel_cpu_types = { }
   intel_cpu_types[get_uid_greater()] = { 
         cpu_type = "skylake", 
         flags =  {  "movbe", "mmx", "sse", "sse2", "sse3", "ssse3", "sse4_1", "sse4_2", 
                     "popcnt", "pku", "avx", "avx2", "aes", "pclmul", "fsgsbase", "rdrand", "fma", 
                     "bmi", "bmi2", "f16c", "rdseed", "adx", "prefetchw", "clflushopt", 
                     "xsavec", "xsaves", "avx512f", "clwb", "avx512vl", "avx512bw", "avx512dq", "avx512cd"
                  }
            }
   intel_cpu_types[get_uid_greater()] = { 
         cpu_type = "skylake", 
         flags =  {  "movbe", "mmx", "sse", "sse2", "sse3", "ssse3", "sse4_1", "sse4_2", 
                     "popcnt", "avx", "avx2", "aes", "pclmul", "fsgsbase", "rdrand", "fma", 
                     "bmi", "bmi2", "f16c", "rdseed", "adx", "prefetchw", "clflushopt", 
                     "xsavec", "xsaves"
                  }
            }

   
   for i = 1, #intel_cpu_types do
      cpu_type_dict = intel_cpu_types[i]
      found = true
      for _, value in pairs(cpu_type_dict.flags) do
         if not isa_local.flags[value] then
            print("breaking at : " .. value)
            found = false
            break
         end
      end
      if found then
         print(cpu_type_dict.cpu_type)
         isa_local.cpu_type = cpu_type_dict.cpu_type
         break
      end
   end
end

local function detect_cpu_type(isa_local)
   if isa_local.vendor_id == "GenuineIntel" then
      detect_intel_cpu_type(isa_local)
   end
end

local isa_class = class.create_class()

function isa_class:__init()
   self.ncores    = 0
   self.vendor_id = "unknown"
   self.cpu_type  = "unknown"
   self.flags = {
      vec_is       = "unknown",
      vec_is_level = vector_instruction_set_dictionary["unknown"],
   }
end

function isa_class:print()
   print("CPUINFO:")
   print("   Ncores : " .. self.ncores)
   print("   Vendor : " .. self.vendor_id)
   print("   VECIS  : " .. self.flags.vec_is)
   print("   cpu_type  : " .. self.cpu_type)
   if self.flags.lm then
      print("   BIT    : 64")
   else
      print("   BIT    : 32")
   end
end

function isa_class:is_avx()
   return (self.flags.vec_is_level >= vector_instruction_set_dictionary["avx"])
end

function isa_class:is_sse()
   return (self.flags.vec_is_level >= vector_instruction_set_dictionary["sse"])
end

local gpu_class = class.create_class()

function gpu_class:__init()
   self.ngpu   = -1
   self.vendor = "unknown"
   self.model  = "unknown"
end

function gpu_class:print()
   print("GPU " .. tostring(self.ngpu) .. ":")
   print("   VENDOR : " .. self.vendor)
   print("   MODEL  : " .. self.model)
end

local gpus_class = class.create_class()

function gpus_class:__init()
   self.ngpus  = 0
   self.gpus   = {}
end

function gpus_class:has_gpus()
   return (self.ngpus > 0)
end

function gpus_class:print()
   for i = 1, self.ngpus do
      self.gpus[i]:print()
   end

   if self.ngpus == 0 then
      print("No GPUs found")
   end
end

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

--- Find and identify nvidia gpus.
-- 
-- @param gpus_local    Class for holding information on gpus. 
--                      On output will hold information on found nvidia gpus.
local function parse_nvidia_gpus(gpus_local)
   local pipe0   = io.popen("ls /proc/driver/nvidia/gpus")
   local ls_nvidia_driver = pipe0:read("*all") or "0"
   pipe0:close()
   
   -- Loop over gpus
   for line in ls_nvidia_driver:gmatch(".-\n") do
      gpus_local.ngpus = gpus_local.ngpus + 1
      gpus_local.gpus[gpus_local.ngpus] = gpu_class:create({})
      gpus_local.gpus[gpus_local.ngpus].vendor = "NVIDIA"
      gpus_local.gpus[gpus_local.ngpus].ngpu   = gpus_local.ngpus

      line = line:gsub("\n", "")
      local pipe0   = io.popen("cat /proc/driver/nvidia/gpus/" .. line .. "/information")
      local nvidia_driver = pipe0:read("*all") or "0"
      pipe0:close()
      
      -- Loop over information file for each gpu
      for gpu_line in nvidia_driver:gmatch(".-\n") do
         gpu_line = gpu_line:gsub("\n", "")

         -- Parse key/value pairs
         local key, value = key_value_pair(gpu_line)
         
         if key == "Model" then
            gpus_local.gpus[gpus_local.ngpus].model = value
         end
      end
   end
end

--- Create modulepaths and return these.
--
-- @return{string,string}   Returns modulepath_root and modulepath strings.
local function deduce_isa()
   local isa_local = isa_class:create({})

   local pipe0   = io.popen("cat /proc/cpuinfo")
   local cpuinfo = pipe0:read("*all") or "0"
   pipe0:close()

   isa_local.ncores = get_ncores(cpuinfo)
   
   for line in cpuinfo:gmatch(".-\n") do
      --
      line = line:gsub("\n", "")
      if isempty(line) then
         break
      end
      
      -- Parse key/value pairs
      local key, value = key_value_pair(line)
      
      if key == "vendor_id" then
         isa_local.vendor_id = value
      elseif key == "flags" then
         set_flags(isa_local.flags, value)
      end
   end

   detect_cpu_type(isa_local)

   return isa_local
end

---
--
local function deduce_gpus()
   local gpus_local = gpus_class:create({})
   
   local pipe0   = io.popen("lspci")
   local lspci = pipe0:read("*all") or "0"
   pipe0:close()

   local nvidia_gpu = false

   for line in lspci:gmatch(".-\n") do
      line = line:gsub ("\n", "")

      if line:match("NVIDIA") then
         nvidia_gpu = true
      end
   end
   
   -- Parse Nvidia gpu
   if nvidia_gpu then
      parse_nvidia_gpus(gpus_local)
   end

   return gpus_local
end

---
--
local function deduce_mem()
   local mem_local = mem_class:create({})
   
   local pipe0   = io.popen("cat /proc/meminfo")
   local meminfo = pipe0:read("*all") or "0"
   pipe0:close()

   for line in meminfo:gmatch(".-\n") do
      line = line:gsub("\n", "")
      
      -- Parse key/value pairs
      local key, value = key_value_pair(line)
      
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
M.deduce_isa  = deduce_isa
M.deduce_gpus = deduce_gpus
M.deduce_mem  = deduce_mem

return M
