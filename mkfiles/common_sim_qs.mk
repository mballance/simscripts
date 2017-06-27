#****************************************************************************

#* common_sim_qs.mk
#*
#* Build and run definitions and rules for Questa Sim
#*
#*
#* +tool.questa.codecov    - Enables code coverage
#* +tool.questa.ucdb       - Specifies the name of the merged UCDB file
#* +tool.questa.valgrind   - Runs Questa under valgrind
#* +tool.questa.gdb        - Runs Questa under gdb
#* +tool.questa.xprop      - Enables xprop
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

HAVE_VISUALIZER:=$(call have_plusarg,tool.visualizer,$(PLUSARGS))
CODECOV_ENABLED:=$(call have_plusarg,tool.questa.codecov,$(PLUSARGS))
VALGRIND_ENABLED:=$(call have_plusarg,tool.questa.valgrind,$(PLUSARGS))
GDB_ENABLED:=$(call have_plusarg,tool.questa.gdb,$(PLUSARGS))
UCDB_NAME:=$(call get_plusarg,tool.questa.ucdb,$(PLUSARGS))
HAVE_XPROP := $(call have_plusarg,tool.questa.xprop,$(PLUSARGS))

ifeq (,$(UCDB_NAME))
UCDB_NAME:=cov_merge.ucdb
endif

ifeq (Cygwin,$(uname_o))
# Ensure we're using a Windows-style path for QUESTA_HOME
QUESTA_HOME:= $(shell cygpath -w $(QUESTA_HOME))

DPI_LIB := -Bsymbolic -L $(QUESTA_HOME)/win64 -lmtipli
endif

# Auto-identify GCC installation
ifeq ($(OS),Windows)
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

#ifeq ($(ARCH),x86_64)
GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux_x86_64
#else
#GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux
#endif

endif # End Not Cygwin

CC:=$(GCC_INSTALL)/bin/gcc
CXX:=$(GCC_INSTALL)/bin/g++

ifeq ($(DEBUG),true)
ifeq (true,$(HAVE_VISUALIZER))
	BUILD_LINK_TARGETS += vopt_opt
	TOP=$(TOP_MODULE)_opt
	ifeq (true, $(INTERACTIVE))
		VSIM_FLAGS += -visualizer=design.bin
	endif
else
	DOFILE_COMMANDS += "log -r /\*;"
	BUILD_LINK_TARGETS += vopt_dbg
	TOP=$(TOP_MODULE)_dbg
endif
else
	TOP=$(TOP_MODULE)_opt
	BUILD_LINK_TARGETS += vopt_opt
endif

ifeq (true,$(DYNLINK))
define MK_DPI
	$(LINK) $(DLLOUT) -o $@ $^ $(DPI_LIB)
endef
else
define MK_DPI
	rm -f $@
	$(LD) -r -o $@ $^ 
endef
endif

ifeq (true,$(QUIET))
VSIM_FLAGS += -nostdout
REDIRECT:= >/dev/null 2>&1
else
endif

VSIM_FLAGS += $(RUN_ARGS)
VSIM_FLAGS += -sv_seed $(SEED)

BUILD_COMPILE_TARGETS += vlog_compile

RUN_TARGETS += run_vsim

POST_RUN_TARGETS += cov_merge

SIMSCRIPTS_SIM_INFO_TARGETS   += questa-sim-info
SIMSCRIPTS_SIM_OPTION_TARGETS += questa-sim-options

ifneq (,$(DPI_OBJS_LIBS))
DPI_LIBRARIES += $(BUILD_DIR_A)/dpi
LIB_TARGETS += $(BUILD_DIR_A)/dpi$(DPIEXT)
endif

ifeq ($(OS),Windows)
DPI_SYSLIBS += -lpsapi -lkernel32
endif

ifeq (true,$(CODECOV_ENABLED))
	VOPT_FLAGS += +cover
	VSIM_FLAGS += -coverage
endif

VOPT_FLAGS += -dpiheader $(TB)_dpi.h

ifeq (true,$(HAVE_XPROP))
VOPT_FLAGS += -xprop
endif

ifeq (true,$(VALGRIND_ENABLED))
	VSIM_FLAGS += -valgrind --tool=memcheck
endif

else # Rules

questa-sim-info :
	@echo "qs - QuestaSim"

questa-sim-options :
	@echo "Simulator: qs (QuestaSim)"
	@echo "  +tool.questa.codecov      - Enables collection of code coverage"
	@echo "  +tool.questa.ucdb=<name>  - Specifies the name of the merged UCDB file"

.phony: vopt_opt vopt_dbg vlog_compile

ifeq (true,$(HAVE_VISUALIZER))
vlog_build : vopt_opt
else
vlog_build : vopt_opt vopt_dbg
endif

VOPT_OPT_DEPS += vlog_compile
VOPT_DBG_DEPS += vlog_compile

ifeq (true,$(HAVE_VISUALIZER))
	VOPT_FLAGS += +designfile -debug
	VSIM_FLAGS += -classdebug -uvmcontrol=struct,msglog -qwavedb=+report=class+signal+class+transaction+uvm_schematic
endif

vopt_opt : $(VOPT_OPT_DEPS)
	$(Q)vopt -o $(TB)_opt $(TB) $(VOPT_FLAGS) $(REDIRECT) 

vopt_dbg : $(VOPT_DBG_DEPS)
	$(Q)vopt +acc -o $(TB)_dbg $(TB) $(VOPT_FLAGS) $(REDIRECT)

vlog_compile : $(VLOG_COMPILE_DEPS)
	$(Q)rm -rf work
	$(Q)vlib work
	$(Q)vlog -sv \
		$(VLOG_FLAGS) \
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
	$(Q)$(CXX) -shared -o $@ $(DPI_OBJS_LIBS) $(DPI_SYSLIBS)
endif

DPI_LIB_OPTIONS := $(foreach dpi,$(DPI_LIBRARIES),-sv_lib $(dpi))

ifeq (true,$(DYNLINK))
else
# DPI_LIB_OPTIONS := $(foreach dpi,$(DPI_LIBRARIES),-dpilib $(dpi)$(DPIEXT))
# DPI_LIB_OPTIONS := $(foreach dpi,$(DPI_LIBRARIES),-ldflags $(dpi)$(DPIEXT))
endif

ifneq (true,$(INTERACTIVE))
#	VSIM_FLAGS += -batch -do run.do
	VSIM_FLAGS += -c -do run.do
endif


ifeq (true,$(GDB_ENABLED))
run_vsim :
	$(Q)echo $(DOFILE_COMMANDS) > run.do
	$(Q)echo "echo \"SV_SEED: $(SEED)\"" >> run.do
	$(Q)echo "coverage attribute -name TESTNAME -value $(TESTNAME)_$(SEED)" >> run.do
	$(Q)echo "coverage save -onexit cov.ucdb" >> run.do
	$(Q)echo "run $(TIMEOUT); quit -f" >> run.do
	$(Q)vmap work $(BUILD_DIR_A)/work $(REDIRECT)
	$(Q)gdb --args $(QUESTA_HOME)/linux_x86_64/vsimk $(VSIM_FLAGS) -batch -do run.do $(TOP) -l simx.log \
		+TESTNAME=$(TESTNAME) -f sim.f $(DPI_LIB_OPTIONS) $(REDIRECT)
else
run_vsim :
	$(Q)echo $(DOFILE_COMMANDS) > run.do
	$(Q)echo "echo \"SV_SEED: $(SEED)\"" >> run.do
	$(Q)echo "coverage attribute -name TESTNAME -value $(TESTNAME)_$(SEED)" >> run.do
	$(Q)echo "coverage save -onexit cov.ucdb" >> run.do
	$(Q)if test "x$(INTERACTIVE)" = "xtrue"; then \
			echo "run $(TIMEOUT)" >> run.do ; \
		else \
			echo "run $(TIMEOUT); quit -f" >> run.do ; \
		fi
	$(Q)vmap work $(BUILD_DIR_A)/work $(REDIRECT)
	$(Q)if test -f $(BUILD_DIR_A)/design.bin; then cp $(BUILD_DIR_A)/design.bin .; fi
	$(Q)vsim $(VSIM_FLAGS) $(TOP) -l simx.log \
		+TESTNAME=$(TESTNAME) -f sim.f $(DPI_LIB_OPTIONS) $(REDIRECT)
endif

UCDB_FILES := $(foreach	test,$(call get_plusarg,TEST,$(PLUSARGS)),$(RUN_ROOT)/$(test)/cov.ucdb)
cov_merge:
	vcover merge $(RUN_ROOT)/$(UCDB_NAME) $(UCDB_FILES)
	
endif
