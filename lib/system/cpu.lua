local M = {}

local class = assert(require "lib.class")
local util  = assert(require "lib.system.util")

-- Vector instruction set dictionary
local function generate_vector_instruction_set_dictionary()
   local get_uid_greater = util.create_uid_generator()

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


local function set_flags(cpu_local_flags, flags)
   if flags:match("avx512") then
      cpu_local_flags.vec_is       = "avx512"
      cpu_local_flags.vec_is_level = vector_instruction_set_dictionary["avx512"]
   elseif flags:match("avx2") then
      cpu_local_flags.vec_is       = "avx2"
      cpu_local_flags.vec_is_level = vector_instruction_set_dictionary["avx2"]
   elseif flags:match("avx") then
      cpu_local_flags.vec_is       = "avx"
      cpu_local_flags.vec_is_level = vector_instruction_set_dictionary["avx"]
   elseif flags:match("sse2") then
      cpu_local_flags.vec_is       = "sse2"
      cpu_local_flags.vec_is_level = vector_instruction_set_dictionary["sse2"]
   elseif flags:match("sse") then
      cpu_local_flags.vec_is       = "sse"
      cpu_local_flags.vec_is_level = vector_instruction_set_dictionary["sse"]
   end

   for _, flag in pairs(util.split(flags, " ")) do
      cpu_local_flags[flag] = true
   end

   if cpu_local_flags["bmi1"] then
      cpu_local_flags["bmi"] = true
   end

   if cpu_local_flags["ssse3"] then
      cpu_local_flags["sse3"] = true
   end

   if cpu_local_flags["pclmulqdq"] then
      cpu_local_flags["pclmul"] = true
   end

   if cpu_local_flags["3dnowprefetch"] then
      cpu_local_flags["prefetchw"] = true
   end
   
   if cpu_local_flags["xsave"] then
      cpu_local_flags["xsaves"] = true
   end
end

local function detect_intel_cpu_type(cpu_local)
   local uid = 0
   local function get_uid_greater()
      uid = uid + 1
      return uid
   end

   local intel_cpu_types = { }
   intel_cpu_types[get_uid_greater()] = { 
         cpu_type = "skylake-avx512", 
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
      print("Testing for " .. cpu_type_dict.cpu_type)
      found = true
      for _, value in pairs(cpu_type_dict.flags) do
         if not cpu_local.flags[value] then
            print("breaking at : " .. value)
            found = false
            break
         end
      end
      if found then
         print(cpu_type_dict.cpu_type)
         cpu_local.cpu_type = cpu_type_dict.cpu_type
         break
      end
   end
end

local function detect_cpu_type(cpu_local)
   if cpu_local.vendor_id == "GenuineIntel" then
      detect_intel_cpu_type(cpu_local)
   end
end

local cpu_class = class.create_class()

function cpu_class:__init()
   self.ncores    = 0
   self.vendor_id = "unknown"
   self.cpu_type  = "unknown"
   self.flags = {
      vec_is       = "unknown",
      vec_is_level = vector_instruction_set_dictionary["unknown"],
   }
end

function cpu_class:print()
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

function cpu_class:is_avx()
   return (self.flags.vec_is_level >= vector_instruction_set_dictionary["avx"])
end

function cpu_class:is_sse()
   return (self.flags.vec_is_level >= vector_instruction_set_dictionary["sse"])
end

--- Create modulepaths and return these.
--
-- @return{string,string}   Returns modulepath_root and modulepath strings.
local function detect_cpu()
   local cpu_local = cpu_class:create({})

   local pipe0   = io.popen("cat /proc/cpuinfo")
   local cpuinfo = pipe0:read("*all") or "0"
   pipe0:close()

   cpu_local.ncores = get_ncores(cpuinfo)
   
   for line in cpuinfo:gmatch(".-\n") do
      --
      line = line:gsub("\n", "")
      if util.isempty(line) then
         break
      end
      
      -- Parse key/value pairs
      local key, value = util.key_value_pair(line)
      
      if key == "vendor_id" then
         cpu_local.vendor_id = value
      elseif key == "flags" then
         set_flags(cpu_local.flags, value)
      end
   end

   detect_cpu_type(cpu_local)

   return cpu_local
end

-- Load module
M.detect_cpu  = detect_cpu

return M
