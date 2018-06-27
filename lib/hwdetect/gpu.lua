local M = {}

local class = assert(require "lib.class")
local util  = assert(require "lib.hwdetect.util")

-- Create gpu class
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
         local key, value = util.key_value_pair(gpu_line)
         
         if key == "Model" then
            gpus_local.gpus[gpus_local.ngpus].model = value
         end
      end
   end
end

--- Detect any gpu's on the system
--
local function detect_gpu()
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

-- Create module
M.detect_gpu = detect_gpu

return M
