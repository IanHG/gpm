local M = {}

local settings
settings = {
   --  Members
   log    = {},
   format = "newline",
   
   -- Initialize settings
   initialize = function (args)
      if not args.quiet then
         table.insert(settings.log, io.stdout)
      end
   
      if args.fancy then
         settings.format = "fancy"
      end
   end
}


M = settings

return M
