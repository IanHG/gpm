# Grendel Package Manager (GPM)

## Usage

To __install__ packages using GPM you first load `gpm` using the module system:
```
ml gpm
```
This gives you access to the `gpm-package` script.
Now you can run `gpm-package`'s `install` command providing the package you want to install and which version of that package you want:
```
gpm-package install --gpk <package> --pkv <version>
```
For example, to install the `gcc` compiler version `7.1.0` you run:
```
gpm-pacakge install --gpk gcc --pkv 7.2.0
```
To __remove__ a package you can use the `remove` command:
```
gpm-package remove --gpk gcc --pkv 7.2.0
```

Some times packages depends on other packages. There are three kinds of dependencies in GPM:
* `--moduleload`
* `--depends-on`
* `--prereq`

Use `--moduleload` when a package only needs another package when it is installing. This could _e.g._ be a package thats needs `cmake` to build. Intalling `llvm` using `cmake/3.9.4`:
```
gpm-package install --gpk llvm --pkv 5.0.0 --moduleload='cmake/3.9.4'
```

Use `--depends-on` when a package also needs another package loaded when it itself is loaded through the module system. This could _e.g._ be a programs thats needs to load a specific dynamic library before it can run.
```
gpm-package install --gpk 
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
* `.gpk` : GPM PacKage file
* `.gps` : GPM Package Stack file

Special macros for .gpk files:
* `<pkgname>`     : Name of package, e.g. 'gcc'.
* `<pkgversion>`  : Version of package, e.g. '7.1.0'.
* `<pkg>`         : Name and version of package, e.g. 'gcc-7.1.0'.
* `<pkgmajor>`    : Major version number.
* `<pkgminor>`    : Minor version number.
* `<pkgrevison>`  : Revision version number.
* `<pkginstall>`  : Install directory for package, should be passed as prefix.
* `<pkgbuild>`    : Build directory for package.

## Maintainer:
Ian H. Godtliebsen

ian@chem.au.dk
