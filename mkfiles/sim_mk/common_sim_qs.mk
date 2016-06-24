#****************************************************************************
#* common_sim_qs.mk
#*
#* Build and run definitions and rules for Questa Sim
#****************************************************************************

#********************************************************************
#* Compile rules
#********************************************************************

ifneq (1,$(RULES))

# Take QUESTA_HOME if set. Otherwise, probe from where executables are located
ifeq (,$(QUESTA_HOME))
QUESTA_HOME := $(dir $(shell which vsim))
QUESTA_HOME := $(shell dirname $(QUESTA_HOME))
endif

ifeq (Cygwin,$(OS))
# Ensure we're using a Windows-style path for QUESTA_HOME
QUESTA_HOME:= $(shell cygpath -w $(QUESTA_HOME))

DPI_LIB := -Bsymbolic -L $(QUESTA_HOME)/win64 -lmtipli
endif

# Auto-identify GCC installation
ifeq ($(OS),Cygwin)
GCC_VERSION := 4.5.0

ifeq ($(ARCH),x86_64)
GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-mingw64vc12
LD:=$(GCC_INSTALL)/libexec/gcc/$(ARCH)-w64-mingw32/$(GCC_VERSION)/ld
else
GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-mingw32vc12
LD:=$(GCC_INSTALL)/libexec/gcc/$(ARCH)-w32-mingw32/$(GCC_VERSION)/ld
endif

else # Not Cygwin
ifeq (,$(wildcard $(QUESTA_HOME)/gcc-4.7.4-linux-*))
GCC_VERSION := 4.7.4
else
GCC_VERSION := 4.5.0
endif

ifeq ($(ARCH),x86_64)
GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux_x86_64
else
GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux
endif

endif # End Not Cygwin

CC:=$(GCC_INSTALL)/bin/gcc
CXX:=$(GCC_INSTALL)/bin/g++

ifeq ($(DEBUG),true)
	TOP=$(TOP_MODULE)_dbg
	DOFILE_COMMANDS += "log -r /\*;"
else
	TOP=$(TOP_MODULE)_opt
endif

ifeq (true,$(DYNLINK))
define MK_DPI
	$(LINK) $(DLLOUT) -o $@ $^ $(DPI_LIB)
endef
else
define MK_DPI
	rm -f $@
	$(LD) -r -o $@ $^ 
#	$(AR) vcq $@ $^ 
endef
endif

ifeq (true,$(QUIET))
VSIM_FLAGS += -nostdout
REDIRECT:= >/dev/null 2>&1
else
endif

BUILD_TARGETS += vlog_build

ifneq (,$(DPI_OBJS_LIBS))
DPI_LIBRARIES += $(BUILD_DIR_A)/dpi
LIB_TARGETS += $(BUILD_DIR_A)/dpi$(DPIEXT)
endif

ifeq ($(OS),Windows)
DPI_SYSLIBS += -lpsapi -lkernel32
endif

else # Rules

# VOPT_FLAGS += +cover

.phony: vopt_opt vopt_dbg vlog_compile
vlog_build : vopt_opt vopt_dbg

VOPT_OPT_DEPS += vlog_compile
VOPT_DBG_DEPS += vlog_compile

vopt_opt : $(VOPT_OPT_DEPS)
	$(Q)vopt -o $(TB)_opt $(TB) $(VOPT_FLAGS) $(REDIRECT) 

vopt_dbg : $(VOPT_DBG_DEPS)
	$(Q)vopt +acc -o $(TB)_dbg $(TB) $(VOPT_FLAGS) $(REDIRECT)

vlog_compile : $(VLOG_COMPILE_DEPS)
	$(Q)rm -rf work
	$(Q)vlib work
	$(Q)vlog -sv \
		$(QS_VLOG_ARGS) \
		$(VLOG_ARGS)

#********************************************************************
#* Simulation settings
#********************************************************************
#ifeq ($(DEBUG),true)
#	TOP:=$(TOP_MODULE)_dbg
#	DOFILE_COMMANDS += "log -r /*;"
#else
#	TOP:=$(TOP_MODULE)_opt
#endif
#	vsim -c -do run.do $(TOP) -qwavedb=+signal \

ifneq (,$(DPI_OBJS_LIBS))
$(BUILD_DIR_A)/dpi$(DPIEXT) : $(DPI_OBJS_LIBS)
	$(Q)$(CXX) -shared -o $@ $^ $(DPI_SYSLIBS)
endif

DPI_LIB_OPTIONS := $(foreach dpi,$(DPI_LIBRARIES),-sv_lib $(dpi))

ifeq (true,$(DYNLINK))
else
# DPI_LIB_OPTIONS := $(foreach dpi,$(DPI_LIBRARIES),-dpilib $(dpi)$(DPIEXT))
# DPI_LIB_OPTIONS := $(foreach dpi,$(DPI_LIBRARIES),-ldflags $(dpi)$(DPIEXT))
endif


run :
	$(Q)echo $(DOFILE_COMMANDS) > run.do
	$(Q)echo "coverage save -onexit cov.ucdb" >> run.do
	$(Q)echo "run $(TIMEOUT); quit -f" >> run.do
	$(Q)vmap work $(BUILD_DIR_A)/work $(REDIRECT)
#	$(Q)vsim $(VSIM_FLAGS) -batch -do run.do $(TOP) -coverage -l simx.log \
#		+TESTNAME=$(TESTNAME) -f sim.f $(DPI_LIB_OPTIONS) $(REDIRECT)
	$(Q)vsim $(VSIM_FLAGS) -batch -do run.do $(TOP) -l simx.log \
		+TESTNAME=$(TESTNAME) -f sim.f $(DPI_LIB_OPTIONS) $(REDIRECT)

endif
