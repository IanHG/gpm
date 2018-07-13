local M = {}

-- Search for lua module, with callback if not found.
-- If module is not found will return 'nil'.
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

-- Create module
M.require = loadrequire

return M
