path = { }

local function join(pathl, pathr)   
   return pathl .. "/" .. pathr
end

path.join = join

return path
