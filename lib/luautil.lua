local M = {}

local function loadrequire(module, callback)
   local function requiref(module)
      return require(module)
   end
   local res, m = pcall(requiref, module)
   if not(res) then
      -- Do Stuff when no module
      if callback then
         m = callback(module)
      else
         m = nil
      end
   end

   return m
end

M.require = loadrequire

return M
