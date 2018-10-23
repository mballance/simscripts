#****************************************************************************
#* common_sim_qs_ase.mk
#*
#* Build and run definitions and rules for Questa Sim (Altera Starter Edition)
#*
#*
#* +tool.questa.codecov    - Enables code coverage
#* +tool.questa.ucdb       - Specifies the name of the merged UCDB file
#* +tool.questa.valgrind   - Runs Questa under valgrind
#* +tool.questa.gdb        - Runs Questa under gdb
#****************************************************************************

#********************************************************************
#* Compile rules
#********************************************************************

SIMSCRIPTS_MKFILES_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

ifneq (1,$(RULES))

include $(SIMSCRIPTS_MKFILES_DIR)/common_tool_gcc.mk

# Take QUESTA_HOME if set. Otherwise, probe from where executables are located
#ifeq (,$(QUESTA_HOME))
QUESTA_HOME := $(dir $(shell which vsim))
QUESTA_HOME := $(shell dirname $(QUESTA_HOME))
#endif

HAVE_VISUALIZER:=$(call have_plusarg,tool.visualizer,$(PLUSARGS))
CODECOV_ENABLED:=$(call have_plusarg,tool.questa.codecov,$(PLUSARGS))
VALGRIND_ENABLED:=$(call have_plusarg,tool.questa.valgrind,$(PLUSARGS))
GDB_ENABLED:=$(call have_plusarg,tool.questa.gdb,$(PLUSARGS))
UCDB_NAME:=$(call get_plusarg,tool.questa.ucdb,$(PLUSARGS))
HAVE_XPROP:=$(call have_plusarg,tool.questa.xprop,$(PLUSARGS))
HAVE_MODELSIM_ASE:=$(call have_plusarg,tool.modelsim_ase,$(PLUSARGS))

SRC_DIRS += $(QUESTA_HOME)/verilog_src/uvm-1.2/src/dpi
CFLAGS += -I$(QUESTA_HOME)/include -DQUESTA
CXXFLAGS += -I$(QUESTA_HOME)/include -DQUESTA
LDFLAGS += -m elf_i386
# --oformat elf32-i386 -b elf32-i386
DPI_OBJS_LIBS += libuvm_dpi.o


ifeq (,$(UCDB_NAME))
UCDB_NAME:=cov_merge.ucdb
endif

ifeq (Cygwin,$(uname_o))
# Ensure we're using a Windows-style path for QUESTA_HOME
QUESTA_HOME:= $(shell cygpath -w $(QUESTA_HOME) | sed -e 's%\\%/%g')

DPI_LIB := -Bsymbolic -L $(QUESTA_HOME)/win64 -lmtipli
else
ifeq (Msys,$(uname_o))
# Ensure we're using a Windows-style path for QUESTA_HOME
# QUESTA_HOME:=$(shell cygpath -w $(QUESTA_HOME) | sed -e 's%\\%/%g')
QUESTA_HOME:=$(shell echo $(QUESTA_HOME) | sed -e 's%\\%/%g' -e 's%^/\([a-zA-Z]\)%\1:/%')
# QUESTA_BAR := 1
endif
endif

#********************************************************************
#* Capabilities configuration
#********************************************************************
VLOG_FLAGS += +define+HAVE_HDL_VIRTUAL_INTERFACE
VLOG_FLAGS += +define+HAVE_HDL_CLKGEN
VLOG_FLAGS += +define+HAVE_UVM
VLOG_FLAGS += +incdir+$(QUESTA_HOME)/verilog_src/uvm-1.2/src

ifneq (,$(QUESTA_MVC_HOME))
VSIM_FLAGS += -mvchome $(QUESTA_MVC_HOME)
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
#ifeq (,$(wildcard $(QUESTA_HOME)/gcc-5.3.0-linux-*))
#GCC_VERSION := 5.3.0
#else
#  ifeq (,$(wildcard $(QUESTA_HOME)/gcc-4.7.4-linux-*))
#      GCC_VERSION := 4.7.4
#  else
#    ifeq (,$(wildcard $(QUESTA_HOME)/gcc-4.5.0-linux-*))
#      GCC_VERSION := 4.5.0
#    else
#      GCC_VERSION := UNKNOWN
#    endif
#  endif
#endif

#ifeq ($(ARCH),x86_64)
GCC_INSTALL := $(QUESTA_HOME)/gcc-4.7.4-linux
#else
#GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux
#endif

endif # End Not Cygwin

CC:=$(GCC_INSTALL)/bin/gcc
CXX:=$(GCC_INSTALL)/bin/g++

TOP=$(TOP_MODULE)
ifeq ($(DEBUG),true)
	DOFILE_COMMANDS += "vcd file sim.vcd; vcd add -r /\*;"
endif

ifeq (,$(TB_MODULES))
ifneq (,$(TB_MODULES_HDL))
TB_MODULES = $(TB_MODULES_HDL) $(TB_MODULES_HVL)
else
TB_MODULES = $(TB)
endif
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

BUILD_PRECOMPILE_TARGETS += compile_uvm
BUILD_COMPILE_TARGETS += vlog_compile

RUN_TARGETS += run_vsim

SIMSCRIPTS_SIM_INFO_TARGETS   += questa-sim-info
SIMSCRIPTS_SIM_OPTION_TARGETS += questa-sim-options

ifneq (,$(DPI_OBJS_LIBS))
# DPI_LIBRARIES += $(BUILD_DIR_A)/dpi
# LIB_TARGETS += $(BUILD_DIR_A)/dpi$(DPIEXT)
endif

ifeq ($(OS),Windows)
DPI_SYSLIBS += -lpsapi -lkernel32 -lstdc++ -lws2_32
else
DPI_SYSLIBS += -lstdc++
endif

ifeq (true,$(CODECOV_ENABLED))
	VOPT_FLAGS += +cover
	VSIM_FLAGS += -coverage
endif

VSIM_FLAGS += $(foreach l,$(QUESTA_LIBS),-L $(l))
VLOG_FLAGS += $(foreach l,$(QUESTA_LIBS),-L $(l))

VLOG_FLAGS += $(foreach d,$(VLOG_DEFINES),+define+$(d))
VLOG_FLAGS += $(foreach i,$(VLOG_INCLUDES),+incdir+$(call native_path,$(i)))

VOPT_FLAGS += -dpiheader $(TB)_dpi.h

ifeq (true,$(HAVE_XPROP))
VOPT_FLAGS += -xprop
endif

ifeq (true,$(VALGRIND_ENABLED))
	VSIM_FLAGS += -valgrind --tool=memcheck
endif

VLOG_ARGS_PRE += $(VLOG_ARGS_PRE_1) $(VLOG_ARGS_PRE_2) $(VLOG_ARGS_PRE_3) $(VLOG_ARGS_PRE_4) $(VLOG_ARGS_PRE_5)


DPI_LIB_OPTIONS := -ldflags "$(foreach l,$(DPI_OBJS_LIBS),$(BUILD_DIR_A)/$(l)) $(DPI_SYSLIBS)"
VOPT_OPT_DEPS += $(DPI_OBJS_LIBS)
VOPT_DBG_DEPS += $(DPI_OBJS_LIBS)

#ifeq ($(OS),Windows)
#DPI_LIB_OPTIONS := -ldflags "$(foreach l,$(DPI_OBJS_LIBS),$(BUILD_DIR_A)/$(l)) $(DPI_SYSLIBS)"
#VOPT_OPT_DEPS += $(DPI_OBJS_LIBS)
#VOPT_DBG_DEPS += $(DPI_OBJS_LIBS)
#else # Not Windows
#
#ifneq (,$(DPI_OBJS_LIBS))
#$(BUILD_DIR_A)/dpi$(DPIEXT) : $(DPI_OBJS_LIBS)
#	$(Q)$(CXX) -shared -o $@ $(DPI_OBJS_LIBS) $(DPI_SYSLIBS)
#endif
#
#DPI_LIB_OPTIONS := $(foreach dpi,$(DPI_LIBRARIES),-sv_lib $(dpi))
#endif

ifneq (true,$(INTERACTIVE))
	VSIM_FLAGS += -c -do run.do
endif

else # Rules

questa-sim-info :
	@echo "qs - QuestaSim"

questa-sim-options :
	@echo "Simulator: qs (QuestaSim)"
	@echo "  +tool.questa.codecov      - Enables collection of code coverage"
	@echo "  +tool.questa.ucdb=<name>  - Specifies the name of the merged UCDB file"

.phony: vopt_opt vopt_dbg vlog_compile

vlog_build : vlog_compile

compile_uvm : 
	$(Q)rm -rf work
	$(Q)vlib work
	$(Q)vmap work $(BUILD_DIR_A)/work $(REDIRECT)
	$(Q)vmap mtiUvm $(BUILD_DIR_A)/work $(REDIRECT)
	$(Q)vlog -sv $(VLOG_FLAGS) $(QUESTA_HOME)/verilog_src/uvm-1.2/src/uvm_pkg.sv

vlog_compile : $(VLOG_COMPILE_DEPS) $(DPI_OBJS_LIBS)
#	$(Q)vmap work $(BUILD_DIR_A)/work
	$(Q)MSYS2_ARG_CONV_EXCL="+incdir+;+define+" vlog -sv \
		$(VLOG_FLAGS) \
		$(QS_VLOG_ARGS) \
		$(VLOG_ARGS_PRE) $(VLOG_ARGS)
		
libuvm_dpi.o : uvm_dpi.o 
	$(Q)$(LD) $(LDFLAGS) -r -o $@ uvm_dpi.o 

VSIM_FLAGS += -modelsimini $(BUILD_DIR_A)/modelsim.ini

ifeq (true,$(GDB_ENABLED))
run_vsim : 
	$(Q)echo $(DOFILE_COMMANDS) > run.do
	$(Q)echo "echo \"SV_SEED: $(SEED)\"" >> run.do
	$(Q)echo "coverage attribute -name TESTNAME -value $(TESTNAME)_$(SEED)" >> run.do
	$(Q)echo "coverage save -onexit cov.ucdb" >> run.do
	$(Q)echo "run $(TIMEOUT); quit -f" >> run.do
#	$(Q)vmap work $(BUILD_DIR_A)/work $(REDIRECT)
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
	$(Q)if test -f $(BUILD_DIR_A)/design.bin; then cp $(BUILD_DIR_A)/design.bin .; fi
	echo "DPI_LIBRARIES = $(DPI_LIBRARIES)"
	$(Q)vsim $(VSIM_FLAGS) $(TOP) -l simx.log \
		+TESTNAME=$(TESTNAME) -f sim.f $(DPI_LIB_OPTIONS) \
		$(foreach lib,$(DPI_LIBRARIES),-sv_lib $(lib)) $(REDIRECT)
endif

UCDB_FILES := $(foreach	test,$(call get_plusarg,TEST,$(PLUSARGS)),$(RUN_ROOT)/$(test)/cov.ucdb)
cov_merge:
	vcover merge $(RUN_ROOT)/$(UCDB_NAME) $(UCDB_FILES)
	
include $(SIMSCRIPTS_MKFILES_DIR)/common_tool_gcc.mk
endif
