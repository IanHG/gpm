-- GPM config file
config = {
   -- Path to search for gpk files
   gpk_directory = "/comm/build/gpk",
   
   -- Temporary build directory
   --base_build_directory = "/tmp",
   base_build_directory = "/scratch/ian",

   -- Install directory
   install_directory = "/comm",

   -- Modulefiles setup
   lmod_directory = "/comm/modulefiles",
   groups = {"core", "apps", "tools"},
   heirarchical = {"core"},
}
