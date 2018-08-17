-- GPM config file
config = {
   nprocesses = <nprocesses>,

   -- Main directory
   stack_name = <stack_name>,
   stack_token= "main",
   stack_path = <stack_path>,

   -- Setup some paths
   log_path = "stack.log",
   gpk_path = "gpk",
   gps_path = "gps",

   -- Set remote repository
   -- repo = "<repo>",
   
   --
   meta_stack = {
      allow_registration = true,
   },
   
   -- Database stuff
   db = {
      path = "db",
   },
   
   --
   lmod = {
      version = <lmod_version>,
      cache_path = "modulesdata",
   },

   --
   groups = {"core", "tools", "apps"},
}
