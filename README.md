# Grendel Package Manager (GPM)

For installation instructions look below.

## Usage

### Basic setup
To configure and initialize a software stack `gpm` uses a config file written `lua` code,
which is usually named `config.lua`.
A basic `config.lua` might look like the following:
```lua
-- GPM config file
config = {
   -- Main directory
   stack_path = "<stack-path>",

   -- Setup some paths
   log_path = "stack.log",

   -- Modulefiles setup
   groups = {"core", "apps", "tools"},
   heirarchical = {"core"},
}
Here `<stack-path>` is the directory where you want your software stack to be installed, 
_i.e._ where all binaries, modulefiles, etc. are to placed.
```
To __initialize__ a sofware stack with the this `config.lua` run:
```bash
<gpm-path>/gpm-package -c <config-path>/config.lua initialize
```
This will initialize and setup the software stack, which can now be loaded by:
```bash
source <stack-path>/bin/modules.sh
```
To view your new software stack use the Lmod command:
```bash
ml av
```

### Basic commands

Once a `gpm` stack is setup you can install and remove software packages using the `gpm-package` script.
To __install__ packages using GPM you first load `gpm` using the module system:
```bash
ml gpm
```
This gives you access to the `gpm-package` script.
Now you can run `gpm-package`'s `install` command providing the package you want to install and which version of that package you want:
```bash
gpm-package install --gpk <package> --pkv <version>
```
For example, to install the `gcc` compiler version `7.1.0` you run:
```bash
gpm-pacakge install --gpk gcc --pkv 7.2.0
```
To __remove__ a package you can use the `remove` command:
```bash
gpm-package remove --gpk gcc --pkv 7.2.0
```

Some packages __depend__ on other packages, either to be installed or to function at all. 
There are three kinds of dependencies when installing packages with GPM:
* `--moduleload`
* `--depends-on`
* `--prereq`

The first kind of dependency is the `--moduleload`-dependency, and is a somewhat "loose" dependency. It is used when a package only needs another package when it is installing. This could _e.g._ be a package thats needs `cmake` to build. Installing `llvm` using `cmake/3.9.4`:
```bash
gpm-package install --gpk llvm --pkv 5.0.0 --moduleload='cmake/3.9.4'
```

The second kind of package dependency is `--depends-on`, which is a little stronger,
and should be used when a package also needs other packages loaded when it itself is loaded through the module system. This could _e.g._ be a programs thats needs to load a specific dynamic library before it can run.
```bash
gpm-package install --gpk clang --pkv 5.0.0 --depends-on='llvm/5.0.0'
```
This means that every time the `clang/5.0.0` module is loaded the `llvm/5.0.0` module is also loaded.

The third and strongest kind of dependency is the prerequisite dependency given by `--prereq`.
Use `--prereq`, when a package has set a prerequisite in its `.gpk`file. For example, the `openmpi-gcc` package has a `compiler` prerequite, and to build this a compiler needs to be given.
```bash
gpm-package install --gpk openmpi-gcc --pkv 2.1.0 --prereq='compiler=gcc/6.3.0'
```
This means that before one is able to load `openmpi/2.1.0` compiled with `gcc-6.3.0` compiler, one first has to load the `gcc/6.3.0` module. 

### Grendel PacKage files (.gpk)

All packages are installed from so-called `.gpk` files.
The default location for these files is 
```
<gpm-path>/gpk
```
The `.gpk` files are like `gpm-package` itself written in Lua. They are used to define how a given package should be build and installed. 
A `.gpk` file to install a `gcc` compiler module could look like:
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

Going through the file step-by-step:

* `description` : Lua string containing a short description of the package.
* `definition`  : Lua table containing the "definition" of package. Furthermore every entry here can be used for string substitution in the `build`, `lmod`, and `post` blocks using angle brackets, `<` and `>`.
    * `pkgname`  : Name of the package. This is the name the package will get in the module system.
    * `pkggroup` : Group in which the module will be installed. This could _e.g._ be `core`, `tools`, _etc._
    * `pkgfamily`: The family of the module. Modules in the same family are mutually exclusive and cannot be loaded simultaneously.
* `build`       : This is the build section of the `.gpk` file, and defines how the package should be built.
    * `source`   : Source files for package installation. This can be either a local file or a remote file, in which case it will be downloaded using `wget`.
    * `command`  : Lua string containing a `bash` script for building the package. Notice here the special macro `<pkginstall>`, which before the command is run, will be substituted with the required install location.
* `lmod`        : Lua table defining how the Lmod Lua script should be created.
    * `help`     : Lua string containing a help message that will displayed when `ml help <pkg>` is run. 

There are a few more settings that can be put in `.gpk`files, but these are the basics, and will be sufficient for most cases.

### Special extentions and macros

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

## Installation 

To get GPM just do a:
```bash
git clone git@github.com:IanHG/gpm.git
```
or download a zip and unpack.
There is no installation or configuring as such, 
but please make sure that all dependencies are met or `gpm-package` will not run.

### Dependencies 

Make sure all dependencies are met on your system.

System packages needed for installation:

* `lua`
* `luarocks` (optional)
* `git`   (for Lmod)
* `tclsh` (for Lmod)
      
Lua Packages needed by `gpm-package` (can be installed with luarocks):

* `luafilesystem`
* `argparse`
* `luaposix`

For using `gpm-package` command to install packages you will need the following programs:

* `wget`
* `tar`

## Maintainer
Ian H. Godtliebsen

ian@chem.au.dk
