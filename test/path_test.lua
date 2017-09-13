#!/usr/bin/lua

local lfs = require "lfs"
folder_of_this = arg[0]:match("(.-)[^\\/]+$") -- Get folder of executeable
if folder_of_this:sub(1,1) ~= "/" then
   folder_of_this = lfs.currentdir() .. "/" .. folder_of_this
end
package.path = folder_of_this .. '../lib/?.lua;' .. package.path -- Set package path

local path = require "path"

local luaunit = require "luaunit"

TestPath = {} -- class
   function TestPath:testExtension()
      abspath = "/home/lol/myfile.1.tar.gz"
      path, file, ext = path.split_filename(abspath)

      luaunit.assertEquals(path, "/home/lol/")
      luaunit.assertEquals(file, "myfile.1.tar.gz")
      luaunit.assertEquals(ext, "gz")
   end
   
   function TestPath:testRemoveDirEnd()
      abspath = "/home/lol"
      path = path.remove_dir_end(abspath)

      luaunit.assertEquals(path, "/home")
   end

-- TestPath class

luaunit.LuaUnit:run()
