# Grendel Package Manager (GPM)

## Dependencies 

   System packages needed for installation:
      lua
      luarocks (optional)
      
   Lua Packages (can be installed with luarocks):
      luafilesystem
      argparse
      luaposix  

   GPM needs:
      wget
      tar

   Lmod needs:
      git
      tclsh

## Special extenstions

Special file extensions:
* .gpk : GPM PacKage file
* .gps : GPM Package Stack file

Special macros for .gpk files:
* <pkgname>     : Name of package, e.g. 'gcc'.
* <pkgversion>  : Version of package, e.g. '7.1.0'.
* <pkg>         : Name and version of package, e.g. 'gcc-7.1.0'.
* <pkgmajor>    : Major version number.
* <pkgminor>    : Minor version number.
* <pkgrevison>  : Revision version number.
* <pkginstall>  : Install directory for package, should be passed as prefix.
* <pkgbuild>    : Build directory for package.

## Maintainer:
Ian H. Godtliebsen

ian@chem.au.dk
