path = { }

local function join(pathl, pathr)   
   return pathl .. "/" .. pathr
end

local function split_filename(strFilename)
   -- Returns the Path, Filename, and Extension as 3 values
   if lfs.attributes(strFilename,"mode") == "directory" then
      local strPath = strFilename:gsub("[\\/]$","")
      return strPath.."\\","",""
   end
   return strFilename:match("(.-)([^\\/]-%.?([^%.\\/]*))$")
end


local function get_filename(url)
  --return url:match("^.+/(.+)$")
  _, file, _ = split_filename(url)
  return file
end

local function get_file_extension(url)
  --return url:match("^.+(%..+)$")
  path, file, ext = split_filename(url)
  return ext
end

path.join = join
path.filename = get_filename
path.extension = get_file_extension
path.split_filename = split_filename

return path
