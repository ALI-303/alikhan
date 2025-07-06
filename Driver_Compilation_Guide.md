# KC705 MobileNetV3 Driver Compilation Guide

This guide shows you exactly how to compile the KC705 MobileNetV3 driver on Linux, Windows, and macOS.

## Quick Start (Most Common)

```bash
# 1. First-time setup (installs dependencies)
make setup

# 2. Compile everything
make

# 3. Test the driver
make test
```

That's it! The compiled libraries will be in `lib/` and executables in `bin/`.

## Detailed Compilation Instructions

### 🐧 Linux (Ubuntu/Debian)

#### Prerequisites
```bash
# Install build tools and dependencies
sudo apt-get update
sudo apt-get install -y build-essential libpci-dev git

# For older systems, also install:
sudo apt-get install -y gcc make libc6-dev
```

#### Compilation Steps
```bash
# Clone or navigate to your KC705 driver directory
cd /path/to/kc705_driver

# Method 1: Automatic (Recommended)
make setup          # Install dependencies and setup
make               # Build everything
make test          # Verify it works

# Method 2: Manual steps
mkdir -p build bin lib
gcc -Wall -Wextra -std=c99 -fPIC -O2 -D__LINUX__ -c kc705_mobilenet_driver.c -o build/kc705_mobilenet_driver.o
ar rcs lib/libkc705.a build/kc705_mobilenet_driver.o
gcc -shared -Wl,-soname,libkc705.so.1 -o lib/libkc705.so build/kc705_mobilenet_driver.o -lpci -lm -lpthread

# Build examples
gcc -Wall -Wextra -std=c99 -O2 -c example_programs.c -o build/example_programs.o
gcc -o bin/kc705_examples build/example_programs.o -Llib -lkc705 -lpci -lm -lpthread
```

#### Red Hat/CentOS/Fedora
```bash
# Install dependencies
sudo yum install gcc make pciutils-devel
# or on newer systems:
sudo dnf install gcc make pciutils-devel

# Then compile as above
make setup
make
```

### 🪟 Windows

#### Method 1: MinGW-w64 (Recommended)

**Install MinGW-w64:**
```bash
# Option A: Via MSYS2 (easiest)
# Download and install MSYS2 from https://www.msys2.org/
# Open MSYS2 terminal and run:
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-make

# Option B: Standalone MinGW-w64
# Download from https://www.mingw-w64.org/downloads/
```

**Compile:**
```bash
# In MSYS2 or MinGW terminal:
cd /c/path/to/kc705_driver
make setup
make

# Manual compilation if needed:
x86_64-w64-mingw32-gcc -Wall -Wextra -std=c99 -fPIC -O2 -D_WIN32 -c kc705_mobilenet_driver.c -o build/kc705_mobilenet_driver.o
x86_64-w64-mingw32-gcc -shared -o lib/kc705.dll build/kc705_mobilenet_driver.o -lsetupapi -lcfgmgr32
```

#### Method 2: Visual Studio

**Create a new project:**
1. Open Visual Studio
2. Create new "Console App" project
3. Add these files to the project:
   - `kc705_mobilenet_driver.c`
   - `kc705_mobilenet_driver.h`
   - `example_programs.c`

**Project Settings:**
- Configuration Properties → VC++ Directories → Include Directories: Add your project folder
- Configuration Properties → Linker → Input → Additional Dependencies: Add `setupapi.lib cfgmgr32.lib`

**Build:**
- Press F7 or Build → Build Solution

#### Method 3: Command Line (Windows SDK)

```cmd
# Open "Developer Command Prompt for VS"
cd C:\path\to\kc705_driver

# Compile driver
cl /c /TC kc705_mobilenet_driver.c /Fo:build\
link /DLL /OUT:lib\kc705.dll build\kc705_mobilenet_driver.obj setupapi.lib cfgmgr32.lib

# Compile examples
cl /c /TC example_programs.c /Fo:build\
link /OUT:bin\kc705_examples.exe build\example_programs.obj lib\kc705.lib
```

### 🍎 macOS

#### Prerequisites
```bash
# Install Xcode command line tools
xcode-select --install

# Or install Xcode from App Store
```

#### Compilation
```bash
cd /path/to/kc705_driver

# Automatic method
make setup
make

# Manual method
gcc -Wall -Wextra -std=c99 -fPIC -O2 -D__MACOS__ -c kc705_mobilenet_driver.c -o build/kc705_mobilenet_driver.o
gcc -shared -Wl,-install_name,libkc705.dylib -o lib/libkc705.dylib build/kc705_mobilenet_driver.o -lm -lpthread
```

## Alternative Compilation Methods

### Using CMake (Cross-Platform)

Create `CMakeLists.txt`:
```cmake
cmake_minimum_required(VERSION 3.10)
project(KC705_Driver)

set(CMAKE_C_STANDARD 99)

# Find PCI library on Linux
if(UNIX AND NOT APPLE)
    find_library(PCI_LIB pci REQUIRED)
endif()

# Create library
add_library(kc705 SHARED kc705_mobilenet_driver.c)
add_library(kc705_static STATIC kc705_mobilenet_driver.c)

# Link libraries
if(WIN32)
    target_link_libraries(kc705 setupapi cfgmgr32 advapi32 kernel32)
elseif(UNIX AND NOT APPLE)
    target_link_libraries(kc705 ${PCI_LIB} m pthread)
else()
    target_link_libraries(kc705 m pthread)
endif()

# Create executables
add_executable(kc705_examples example_programs.c)
target_link_libraries(kc705_examples kc705)
```

Compile with CMake:
```bash
mkdir build_cmake && cd build_cmake
cmake ..
make
```

### Using Meson Build System

Create `meson.build`:
```meson
project('kc705_driver', 'c', version: '1.0.0')

# Dependencies
deps = []
if host_machine.system() == 'linux'
  deps += dependency('libpci')
endif

# Library
kc705_lib = library('kc705',
  'kc705_mobilenet_driver.c',
  dependencies: deps,
  install: true)

# Executable
executable('kc705_examples',
  'example_programs.c',
  link_with: kc705_lib,
  install: true)
```

Compile:
```bash
meson setup builddir
meson compile -C builddir
```

## Build Verification

After successful compilation, verify your build:

```bash
# Check if libraries exist
ls -la lib/
# Should show: libkc705.a, libkc705.so (or .dylib/.dll)

# Check if executables exist
ls -la bin/
# Should show: kc705_examples, kc705_test

# Test the library
make test

# Or manually:
bin/kc705_test
```

## Troubleshooting Common Issues

### ❌ "libpci not found" (Linux)
```bash
# Install pci development library
sudo apt-get install libpci-dev     # Ubuntu/Debian
sudo yum install pciutils-devel     # RHEL/CentOS
sudo dnf install pciutils-devel     # Fedora
```

### ❌ "gcc: command not found"
```bash
# Install build tools
sudo apt-get install build-essential    # Ubuntu/Debian
sudo yum groupinstall "Development Tools"  # RHEL/CentOS
xcode-select --install                   # macOS
```

### ❌ "Permission denied" errors
```bash
# Make sure you have write permissions
chmod +x build_script.sh
sudo chown -R $USER:$USER /path/to/project
```

### ❌ Windows compilation errors
```cmd
# Make sure MinGW is in PATH
set PATH=C:\mingw64\bin;%PATH%

# Or use full path to compiler
C:\mingw64\bin\gcc.exe -o kc705.dll ...
```

### ❌ "Cannot find -lpci" on Linux
```bash
# Find where libpci is installed
find /usr -name "libpci*" 2>/dev/null

# Add library path if needed
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
```

### ❌ Linking errors
```bash
# Verbose linking to see what's happening
gcc -v -Wl,--verbose ...

# Check library dependencies
ldd lib/libkc705.so  # Linux
otool -L lib/libkc705.dylib  # macOS
```

## Cross-Compilation

### Linux → Windows (Cross-compile)
```bash
# Install cross-compiler
sudo apt-get install gcc-mingw-w64

# Compile
x86_64-w64-mingw32-gcc -shared -o kc705.dll kc705_mobilenet_driver.c -lsetupapi -lcfgmgr32
```

### Build for Different Architectures
```bash
# 32-bit build
make CFLAGS="-m32" LDFLAGS="-m32"

# ARM build (requires cross-compiler)
make CC=arm-linux-gnueabi-gcc AR=arm-linux-gnueabi-ar
```

## Installation Options

### System-Wide Installation
```bash
# Install to system directories (requires sudo)
make install

# Manual installation
sudo cp lib/libkc705.so /usr/local/lib/
sudo cp kc705_mobilenet_driver.h /usr/local/include/
sudo ldconfig  # Update library cache
```

### User Installation
```bash
# Install to user directory
mkdir -p ~/lib ~/include
cp lib/libkc705.* ~/lib/
cp kc705_mobilenet_driver.h ~/include/
export LD_LIBRARY_PATH=~/lib:$LD_LIBRARY_PATH
```

### Portable Installation
```bash
# Keep everything in project directory
# Libraries in lib/, executables in bin/
# No system installation needed
export LD_LIBRARY_PATH=./lib:$LD_LIBRARY_PATH
```

## Using the Compiled Driver

### In Your C Code
```c
#include "kc705_mobilenet_driver.h"

// Link with: -lkc705
// Or full path: gcc myapp.c -L./lib -lkc705
```

### Library Paths
```bash
# If not installed system-wide, set library path:
export LD_LIBRARY_PATH=./lib:$LD_LIBRARY_PATH    # Linux
export DYLD_LIBRARY_PATH=./lib:$DYLD_LIBRARY_PATH  # macOS
set PATH=.\lib;%PATH%  # Windows
```

## Performance Optimization

### Optimized Build
```bash
# Maximum optimization
make CFLAGS="-O3 -march=native -mtune=native"

# Debug build for development
make debug

# Profile-guided optimization
make CFLAGS="-fprofile-generate"
# Run your application
make clean
make CFLAGS="-fprofile-use"
```

Now you have a complete guide to compile the KC705 driver on any system! The Makefile handles most cases automatically, but these detailed instructions help when you need more control or encounter issues.