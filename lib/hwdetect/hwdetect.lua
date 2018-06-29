local M = {}

local class = assert(require "lib.class")
local cpu   = assert(require "lib.hwdetect.cpu")
local gpu   = assert(require "lib.hwdetect.gpu")
local mem   = assert(require "lib.hwdetect.mem")
local net   = assert(require "lib.hwdetect.net")

local hw_info_class = class.create_class()

function hw_info_class:__init()
   self.cpu_info = cpu.detect_cpu()
   self.gpu_info = gpu.detect_gpu()
   self.mem_info = mem.detect_mem()
   self.net_info = net.detect_net()
end

local function detect_hw()
   local hw_info = hw_info_class:create()

   return hw_info
end

-- Create module
M.cpu = cpu
M.gpu = gpu
M.mem = mem
M.net = net
M.detect_hw  = detect_hw

return M
