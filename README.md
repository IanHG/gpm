# Grendel Package Manager (GPM)

## Usage

To install packages you just load `gpm` using the module system 
```
ml gpm
```
and afterwards run the install command of the `gpm-package` script providing the desired package and version of that package
```
gpm-package install --gpk <package> --pkv <version>
```
For example, to install the `gcc` compiler version `7.1.0` you run:
```
gpm-pacakge install --gpk gcc --pkv 7.2.0
```

## Dependencies 

System packages needed for installation:
* lua
* luarocks (optional)
* git   (for Lmod)
* tclsh (for Lmod)
      
Lua Packages (can be installed with luarocks):
* luafilesystem
* argparse
* luaposix  

For using `gpm-package` command to install packages you will need the following programs:
* wget
* tar

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
