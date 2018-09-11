function <name>()
   homepage    ("<homepage>")
   .url        ("<url>")
   .version    ("%version%")
   .description([[
      <description>
   ]])
   
   cmake()

   lmod()
      .help  ([[This module loads %name% v. %version%.]])
      .family("<family>")
      .group ("<group>")

   symbol()
      .add("name"   , "<name>")
      .add("version", "<version>")
end
