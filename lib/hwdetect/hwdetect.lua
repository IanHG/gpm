local M = {}

local _class = assert(require "lib.class")
local _cpu   = assert(require "lib.hwdetect.cpu")
local _gpu   = assert(require "lib.hwdetect.gpu")
local _mem   = assert(require "lib.hwdetect.mem")

local hw_info_class = _class.create_class()

function hw_info_class:__init()
   self.cpu_info = _cpu.detect_cpu()
   self.gpu_info = _gpu.detect_gpu()
   self.mem_info = _mem.detect_mem()
end

local function detect_hw()
   local hw_info = hw_info_class:create()

   return hw_info
end

-- Create module
M.detect_cpu = _cpu.detect_cpu
M.detect_gpu = _gpu.detect_gpu
M.detect_mem = _mem.detect_mem
M.detect_hw  = detect_hw

return M
