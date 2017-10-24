# Grendel Package Manager (GPM)

## Usage

### Basic commands

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

Some packages __depend__ on other packages, either to be installed or to function at all. 
There are three kinds of dependencies when installing packages with GPM:
* `--moduleload`
* `--depends-on`
* `--prereq`

The first kind of dependency is the `--moduleload`-dependency, and is a somewhat "loose" dependency, and it is used when a package only needs another package when it is installing. This could _e.g._ be a package thats needs `cmake` to build. Intalling `llvm` using `cmake/3.9.4`:
```
gpm-package install --gpk llvm --pkv 5.0.0 --moduleload='cmake/3.9.4'
```

The second kind of package dependency is `--depends-on`, which is a little stronger,
should be used when a package also needs other packages loaded when it itself is loaded through the module system. This could _e.g._ be a programs thats needs to load a specific dynamic library before it can run.
```
gpm-package install --gpk clang --pkv 5.0.0 --depends-on='llvm/5.0.0'
```
This means that every time the `clang/5.0.0` module is loaded the `llvm/5.0.0` module is also loaded.

The third and strongest kind of dependency is the prerequisite dependency given by `--prereq`.
Use `--prereq`, when a package has set a prerequisite in its `.gpk`file. For example, the `openmpi-gcc` package has a `compiler` prerequite, and to build this a compiler needs to be given.
```
gpm-package install --gpk openmpi-gcc --pkv 2.1.0 --prereq='compiler=gcc/6.3.0'
```
This means that before one is able to load `openmpi/2.1.0` compiled with `gcc-6.3.0` compiler, one first has to load the `gcc/6.3.0` module. 

### Grendel PacKage files (.gpk)

All packages are installed from so-called `.gpk` files.
The default location for these files is `<gpm-path>/gpk`.
The `.gpk` are like `gpm-package` itself written in `lua` code, and define how a given package should be installed/build.

```lua
-- GCC gpk script

-- Description of the gpk
description = [[
GCC - Gnu compiler suite, that is newer than the system default.
]]

-- Definition section
definition = { 
   pkgname = "gcc",
   pkggroup = "core",
   pkgfamily = "compiler",
}

-- Required types
prerequisite = { } 

-- Build section
build = { 
   -- Source of package
   source = "ftp://gcc.gnu.org/pub/gcc/releases/<pkg>/<pkg>.tar.bz2",
   -- Build command
   command = [[
      # Download and install prerequisites
      contrib/download_prerequisites
      
      # Build gcc
      mkdir build
      cd build
      ../configure --enable-lto --disable-multilib --enable-bootstrap --enable-shared --enable-threads=posix --prefix=<pkginstall> --with-local-prefix=<pkginstall>
      
      make -j<nprocesses>
      make -k check || true
      make install
   ]]
}

-- Lmod section
lmod = { 
   help = [[This module loads a newer version of gcc than the system default.]],
}

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
