# KC705 MobileNetV3 Driver Makefile
# Supports both Linux and Windows compilation

# Compiler Configuration
CC = gcc
CXX = g++
AR = ar

# Project Information
PROJECT = kc705_mobilenet
VERSION = 1.0.0

# Directories
SRC_DIR = .
BUILD_DIR = build
BIN_DIR = bin
LIB_DIR = lib

# Source Files
LIB_SOURCES = kc705_mobilenet_driver.c
EXAMPLE_SOURCES = example_programs.c
TEST_SOURCES = test_driver.c

# Object Files
LIB_OBJECTS = $(BUILD_DIR)/kc705_mobilenet_driver.o
EXAMPLE_OBJECTS = $(BUILD_DIR)/example_programs.o
TEST_OBJECTS = $(BUILD_DIR)/test_driver.o

# Library Files
STATIC_LIB = $(LIB_DIR)/libkc705.a
SHARED_LIB = $(LIB_DIR)/libkc705.so

# Executables
EXAMPLE_EXE = $(BIN_DIR)/kc705_examples
TEST_EXE = $(BIN_DIR)/kc705_test

# Detect Operating System
UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)

ifeq ($(UNAME_S),Linux)
    OS = linux
    SHARED_LIB = $(LIB_DIR)/libkc705.so
    EXE_EXT = 
endif
ifeq ($(UNAME_S),Darwin)
    OS = macos
    SHARED_LIB = $(LIB_DIR)/libkc705.dylib
    EXE_EXT = 
endif
ifneq (,$(findstring MINGW,$(UNAME_S)))
    OS = windows
    SHARED_LIB = $(LIB_DIR)/kc705.dll
    EXE_EXT = .exe
    CC = x86_64-w64-mingw32-gcc
    CXX = x86_64-w64-mingw32-g++
endif
ifneq (,$(findstring CYGWIN,$(UNAME_S)))
    OS = windows
    SHARED_LIB = $(LIB_DIR)/kc705.dll
    EXE_EXT = .exe
endif

# Compiler Flags
CFLAGS = -Wall -Wextra -std=c99 -fPIC
CXXFLAGS = -Wall -Wextra -std=c++11 -fPIC
LDFLAGS = 

# Debug/Release Configuration
ifdef DEBUG
    CFLAGS += -g -DDEBUG -O0
    CXXFLAGS += -g -DDEBUG -O0
    BUILD_TYPE = debug
else
    CFLAGS += -O2 -DNDEBUG
    CXXFLAGS += -O2 -DNDEBUG
    BUILD_TYPE = release
endif

# OS-Specific Flags and Libraries
ifeq ($(OS),linux)
    CFLAGS += -D__LINUX__
    LIBS = -lpci -lm -lpthread
    LDFLAGS += -Wl,-rpath,./lib
endif

ifeq ($(OS),macos)
    CFLAGS += -D__MACOS__
    LIBS = -lm -lpthread
    LDFLAGS += -Wl,-rpath,./lib
endif

ifeq ($(OS),windows)
    CFLAGS += -D_WIN32 -DWIN32_LEAN_AND_MEAN
    LIBS = -lsetupapi -lcfgmgr32 -ladvapi32 -lkernel32
    STATIC_LIB = $(LIB_DIR)/libkc705.lib
endif

# Include Directories
INCLUDES = -I$(SRC_DIR)

# Default Target
.PHONY: all
all: directories $(STATIC_LIB) $(SHARED_LIB) $(EXAMPLE_EXE) $(TEST_EXE)
	@echo "Build complete for $(OS) ($(BUILD_TYPE))"
	@echo "Libraries: $(LIB_DIR)/"
	@echo "Executables: $(BIN_DIR)/"

# Create Directories
.PHONY: directories
directories:
	@mkdir -p $(BUILD_DIR) $(BIN_DIR) $(LIB_DIR)

# Static Library
$(STATIC_LIB): $(LIB_OBJECTS)
	@echo "Creating static library: $@"
	$(AR) rcs $@ $^

# Shared Library
$(SHARED_LIB): $(LIB_OBJECTS)
	@echo "Creating shared library: $@"
ifeq ($(OS),linux)
	$(CC) -shared -Wl,-soname,libkc705.so.1 -o $@ $^ $(LIBS)
endif
ifeq ($(OS),macos)
	$(CC) -shared -Wl,-install_name,libkc705.dylib -o $@ $^ $(LIBS)
endif
ifeq ($(OS),windows)
	$(CC) -shared -o $@ $^ $(LIBS) -Wl,--out-implib,$(LIB_DIR)/libkc705.lib
endif

# Example Programs
$(EXAMPLE_EXE): $(EXAMPLE_OBJECTS) $(STATIC_LIB)
	@echo "Building examples: $@"
	$(CC) $(LDFLAGS) -o $@ $< -L$(LIB_DIR) -lkc705 $(LIBS)

# Test Programs
$(TEST_EXE): $(TEST_OBJECTS) $(STATIC_LIB)
	@echo "Building tests: $@"
	$(CC) $(LDFLAGS) -o $@ $< -L$(LIB_DIR) -lkc705 $(LIBS)

# Object Files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "Compiling: $<"
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	@echo "Compiling: $<"
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# Install Dependencies (Linux)
.PHONY: install-deps
install-deps:
ifeq ($(OS),linux)
	@echo "Installing dependencies for Linux..."
	@echo "Please run: sudo apt-get update && sudo apt-get install -y libpci-dev build-essential"
	@echo "Or on RHEL/CentOS: sudo yum install pciutils-devel gcc make"
endif
ifeq ($(OS),macos)
	@echo "Installing dependencies for macOS..."
	@echo "Please install Xcode command line tools: xcode-select --install"
endif
ifeq ($(OS),windows)
	@echo "For Windows, install MinGW-w64 or Visual Studio"
	@echo "Or use MSYS2: pacman -S mingw-w64-x86_64-gcc"
endif

# Quick Setup for First-Time Users
.PHONY: setup
setup: install-deps directories
	@echo "Setting up KC705 driver build environment..."
	@echo "OS detected: $(OS)"
	@echo "Build type: $(BUILD_TYPE)"
	@echo "Ready to build! Run 'make' to compile everything."

# Clean Build Files
.PHONY: clean
clean:
	@echo "Cleaning build files..."
	rm -rf $(BUILD_DIR) $(BIN_DIR) $(LIB_DIR)

# Clean and Rebuild
.PHONY: rebuild
rebuild: clean all

# Debug Build
.PHONY: debug
debug:
	$(MAKE) DEBUG=1

# Release Build
.PHONY: release
release:
	$(MAKE) DEBUG=0

# Test the Driver
.PHONY: test
test: $(TEST_EXE)
	@echo "Running driver tests..."
	$(TEST_EXE)

# Run Examples
.PHONY: examples
examples: $(EXAMPLE_EXE)
	@echo "Running example programs..."
	$(EXAMPLE_EXE)

# Install System-Wide (Linux/macOS)
.PHONY: install
install: all
ifeq ($(OS),linux)
	@echo "Installing to system directories..."
	sudo cp $(SHARED_LIB) /usr/local/lib/
	sudo cp kc705_mobilenet_driver.h /usr/local/include/
	sudo ldconfig
	@echo "Installation complete. You can now link with -lkc705"
endif
ifeq ($(OS),macos)
	@echo "Installing to system directories..."
	sudo cp $(SHARED_LIB) /usr/local/lib/
	sudo cp kc705_mobilenet_driver.h /usr/local/include/
	@echo "Installation complete. You can now link with -lkc705"
endif
ifeq ($(OS),windows)
	@echo "For Windows, copy files manually:"
	@echo "  $(SHARED_LIB) -> C:\\Windows\\System32\\"
	@echo "  kc705_mobilenet_driver.h -> your include directory"
endif

# Uninstall System-Wide
.PHONY: uninstall
uninstall:
ifeq ($(OS),linux)
	sudo rm -f /usr/local/lib/libkc705.*
	sudo rm -f /usr/local/include/kc705_mobilenet_driver.h
	sudo ldconfig
endif
ifeq ($(OS),macos)
	sudo rm -f /usr/local/lib/libkc705.*
	sudo rm -f /usr/local/include/kc705_mobilenet_driver.h
endif

# Create Distribution Package
.PHONY: dist
dist: all
	@echo "Creating distribution package..."
	mkdir -p dist/$(PROJECT)-$(VERSION)
	cp -r $(BIN_DIR) $(LIB_DIR) *.h *.md dist/$(PROJECT)-$(VERSION)/
	cd dist && tar -czf $(PROJECT)-$(VERSION)-$(OS).tar.gz $(PROJECT)-$(VERSION)
	@echo "Distribution package created: dist/$(PROJECT)-$(VERSION)-$(OS).tar.gz"

# Documentation
.PHONY: docs
docs:
	@echo "Generating documentation..."
	@echo "Driver API documentation can be found in kc705_mobilenet_driver.h"
	@echo "Setup guide: see README.md and setup guides"
	@echo "Examples: see example_programs.c"

# Show Build Information
.PHONY: info
info:
	@echo "KC705 MobileNetV3 Driver Build Information"
	@echo "=========================================="
	@echo "Project: $(PROJECT)"
	@echo "Version: $(VERSION)"
	@echo "OS: $(OS)"
	@echo "Compiler: $(CC)"
	@echo "Build Type: $(BUILD_TYPE)"
	@echo "C Flags: $(CFLAGS)"
	@echo "LD Flags: $(LDFLAGS)"
	@echo "Libraries: $(LIBS)"
	@echo "Static Lib: $(STATIC_LIB)"
	@echo "Shared Lib: $(SHARED_LIB)"

# Help
.PHONY: help
help:
	@echo "KC705 MobileNetV3 Driver Makefile"
	@echo "================================="
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build everything (default)"
	@echo "  setup        - First-time setup"
	@echo "  debug        - Build with debug symbols"
	@echo "  release      - Build optimized release"
	@echo "  test         - Run tests"
	@echo "  examples     - Run example programs"
	@echo "  clean        - Remove build files"
	@echo "  rebuild      - Clean and build"
	@echo "  install      - Install system-wide"
	@echo "  uninstall    - Remove system installation"
	@echo "  dist         - Create distribution package"
	@echo "  info         - Show build configuration"
	@echo "  help         - Show this help"
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup   # First time only"
	@echo "  make         # Build everything"
	@echo "  make test    # Test the driver"

# Prevent deletion of intermediate files
.PRECIOUS: $(BUILD_DIR)/%.o