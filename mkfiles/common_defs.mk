
# Determine the platform
COMMON_DEFS_MK := $(lastword $(MAKEFILE_LIST))
COMMON_DEFS_MK_DIR := $(dir $(COMMON_DEFS_MK))

# export MSYS2_ARG_CONV_EXCL=*

include $(COMMON_DEFS_MK_DIR)/plusargs.mk

uname_o=$(shell uname -o)
ARCH=$(shell uname -m)

PYTHON_BIN ?= python3

ifeq (Cygwin,$(uname_o))
OS:=Windows
define native_path
$(shell echo $(1) | sed -e 's%^/\([a-zA-Z]\)%\1:%')
endef
else
ifeq (Msys,$(uname_o))
OS:=Windows
define native_path
$(shell cygpath -w $(1) | sed -e 's%\\%/%g')
endef
else # Not Cygwin and not Msys
OS:=Linux
define native_path
$(1)
endef
endif
endif # uname_o,Cygwin

ifeq (Windows,$(OS))
  DYNLINK=false
  DLLEXT=.dll
  ifeq ($(ARCH), x86_64)
    PLATFORM=cygwin64
  else
    PLATFORM=cygwin
  endif
else # Linux
ifeq (Linux,$(OS))
  DLLEXT=.so
  LIBPREF=lib
  DYNLINK=true
  ifeq ($(ARCH), x86_64)
    PLATFORM=linux_x86_64
  else
    PLATFORM=linux
  endif
else
  PLATFORM=unknown
  DYNLINK=unknown
endif
endif


ifeq (Cygwin,$(uname_o))
  ifeq ($(ARCH),x86_64)
    SYSTEMC_LIBDIR=$(SYSTEMC)/lib-cygwin64
  else
    SYSTEMC_LIBDIR=$(SYSTEMC)/lib-cygwin
  endif
  SYSTEMC_LIB=$(SYSTEMC_LIBDIR)/libsystemc.a
  LINK_SYSTEMC=$(SYSTEMC_LIBDIR)/libsystemc.a
endif

ifeq (,$(A23_CXX))
A23_CXX=arm-none-eabi-g++
endif
ifeq (,$(A23_AR))
A23_AR=arm-none-eabi-ar
endif

LINK=$(CXX)
DLLOUT=-shared

# CXXFLAGS += -I$(SYSTEMC)/include
ifneq (Windows,$(OS))
CXXFLAGS += -fPIC
CFLAGS += -fPIC
else
CXXFLAGS += -Wno-attributes
endif

CXXFLAGS += -g
CXXFLAGS += -I$(VERILATOR_ROOT)/include
CXXFLAGS += -I$(VERILATOR_ROOT)/include/vltstd
CXXFLAGS += -std=c++0x

# VERBOSE=true

ifneq (true,$(VERBOSE))
Q=@
endif

