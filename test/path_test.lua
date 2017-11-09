#!/usr/bin/lua

local lfs = require "lfs"
folder_of_this = arg[0]:match("(.-)[^\\/]+$") -- Get folder of executeable
if folder_of_this:sub(1,1) ~= "/" then
   folder_of_this = lfs.currentdir() .. "/" .. folder_of_this
end
package.path = folder_of_this .. '../lib/?.lua;' .. package.path -- Set package path

local pathmod = require "path"

local luaunit = require "luaunit"

TestPath = {} -- class
   -- Test splitting a file path into dirpath filename and extension.
   function TestPath:testExtension()
      local abspath = "/home/lol/myfile.1.tar.gz"
      local path, file, ext = pathmod.split_filename(abspath)

      luaunit.assertEquals(path, "/home/lol/")
      luaunit.assertEquals(file, "myfile.1.tar.gz")
      luaunit.assertEquals(ext, "gz")
   end
   
   -- Test removal of dir end
   function TestPath:testRemoveDirEnd1()
      local abspath = "/home/lol"
      local path = pathmod.remove_dir_end(abspath)

      luaunit.assertEquals(path, "/home/lol")
   end
   
   function TestPath:testRemoveDirEnd2()
      local abspath = "/home/lol/"
      local path = pathmod.remove_dir_end(abspath)

      luaunit.assertEquals(path, "/home/lol")
   end

   -- Test abs path
   function TestPath:testIsAbsPath()
      luaunit.assertTrue (pathmod.is_abs_path("/home/lol/dir"))
      luaunit.assertFalse(pathmod.is_abs_path("this/is/a/rel/path"))
   end

-- TestPath class

luaunit.LuaUnit:run()
