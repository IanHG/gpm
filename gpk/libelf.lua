function libelf()
   print("LOADING libelf")

   homepage    ("http://www.mr511.de")
   .url        ("http://www.mr511.de/software/libelf-%version%.tar.gz")
   .version    ("%version%")
   .description([[
      This is a description of the package.
   ]])
   
   .autotools( "--enable-extended-format")

   --.file("lol.txt", [[This is some content]])

   lmod  
      .help  ([[This module loads %name% v. %version%.]])
      .family("libelf")
      .group ("tools")
      .prepend_path("PATH", "LOLPATH")

   symbol
      .add("name"   , "LibELF")
      .add("version", "0.8.13")
end
