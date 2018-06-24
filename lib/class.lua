local M = {}

--- Helper function to search for functions in bases.
--
local function search(k, plist)
   for i = 1, #plist do
      local v = plist[i][k]
      if v then return v end
   end
end

--- Create a class from a set of base classes.
--
--
local function create_class(...)
   local c = {}
   local parents = {...}

   setmetatable(c, { __index = function(t, k)
      return search(k, parents)
   end})

   c.__index = c
   c.__name  = c
   
   -- Create instance of class
   function c:create(o, ...)
      o = o or {}
      setmetatable(o, c)
      for i = 1, #parents do
         c[parents[i].__name] = parents[i]
      end
      if o.__init then
         o:__init(...)
      end
      return o
   end

   -- Get class type
   function c:class()
      return c
   end

   -- Return true if the caller is an instance of theClass
   function c:is_a( theClass )
      local b_isa = false
      local cur_class = c
      if cur_class == theClass then
         b_isa = true
      else
         for i = 1, #parents do
            if parents[i].is_a then
               b_isa = parents[i]:is_a(theClass)
            end

            if b_isa then
               return b_isa
            end
         end
      end
      return b_isa
   end

   return c
end

-- Load module
M.create_class = create_class

return M
