local lfs = require "lfs"

M = {}

local function install(args)
   exception.try(function() 
      -- Bootstrap build
      package = bootstrap_package(args)

      if args.debug then
         util.print(package, "package")
      end

      -- Create build dir
      lfs.rmdir(package.build_directory)
      lfs.mkdir(package.build_directory)
      lfs.chdir(package.build_directory)
      
      -- Do the build
      if not args.no_build then
         build_package(package)
      end

      -- Create Lmod file
      if package.lmod and not args.no_lmod then
         build_lmod_modulefile(package)
      end
      
      -- Change back to calling dir
      lfs.chdir(config.current_directory)
      
      -- Remove build dir
      if args.cleanup then
         status, msg = lfs.rmdir(build_directory)
         print("Did not remove build directory. Reason : '" .. msg .. "'.") 
      end
   end, function(e)
      --[[
      status, msg = lfs.rmdir(build_directory)
      if not status then
         print("did not rm dir :C")
      end
      --]]
      error(e)
   end)
end

M.install = install

return M
