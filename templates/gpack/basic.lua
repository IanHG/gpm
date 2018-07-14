function <gpack-name>()
   homepage    ("<homepage>")
   .url        ("<url>")
   .version    ("%version%")
   .description([[
      <description>
   ]])
   
   cmake()

   lmod  
      .help  ([[This module loads %name% v. %version%.]])
      .family("<family>")
      .group ("<group>")

   symbol
      .add("name"   , "<gpack-name>")
      .add("version", "<version>")
end
