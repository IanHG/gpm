path = { }

local function join(pathl, pathr)   
   return pathl .. "/" .. pathr
end


function get_filename(url)
  return url:match("^.+/(.+)$")
end

function get_file_extension(url)
  return url:match("^.+(%..+)$")
end

path.join = join
path.filename = get_filename
path.extension = get_file_extension

return path
