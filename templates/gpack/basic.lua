---
-- This package builds <name>
--
function <name>()
   -- Generel
   homepage    ("<homepage>")
   .url        ("<url>")
   .version    ("%version%")
   .description([[
      <description>
   ]])
   
   -- Build
   build()
   
   -- Lmod
   lmod()
      .help  ([[This module loads %name% v. %version%.]])
      .family("<family>")
      .group ("<group>")
   
   -- Custom symbols
   symbol()
      .add("name"   , "<name>")
      .add("version", "<version>")
end
