local M = {}

local cpu = assert(require "lib.system.cpu")
local gpu = assert(require "lib.system.gpu")
local mem = assert(require "lib.system.mem")

-- Create module
M.detect_cpu = cpu.detect_cpu
M.detect_gpu = gpu.detect_gpu
M.detect_mem = mem.detect_mem

return M
