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
# $(call have_plusarg,tool.visualizer,$(PLUSARGS))
HAVE_VISUALIZER=true
CODECOV_ENABLED:=$(call have_plusarg,tool.questa.codecov,$(PLUSARGS))
VALGRIND_ENABLED:=$(call have_plusarg,tool.questa.valgrind,$(PLUSARGS))
GDB_ENABLED:=$(call have_plusarg,tool.questa.gdb,$(PLUSARGS))
UCDB_NAME:=$(call get_plusarg,tool.questa.ucdb,$(PLUSARGS))
HAVE_XPROP:=$(call have_plusarg,tool.questa.xprop,$(PLUSARGS))
HAVE_MODELSIM_ASE:=$(call have_plusarg,tool.modelsim_ase,$(PLUSARGS))

VOPT ?= vopt

ifeq (true,$(HAVE_MODELSIM_ASE))
QUESTA_ENABLE_VOPT := false
QUESTA_ENABLE_VCOVER := false
endif

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
ifeq (,$(wildcard $(QUESTA_HOME)/gcc-5.3.0-linux-*))
GCC_VERSION := 5.3.0
else
  ifeq (,$(wildcard $(QUESTA_HOME)/gcc-4.7.4-linux-*))
      GCC_VERSION := 4.7.4
  else
    ifeq (,$(wildcard $(QUESTA_HOME)/gcc-4.5.0-linux-*))
      GCC_VERSION := 4.5.0
    else
      GCC_VERSION := UNKNOWN
    endif
  endif
endif

#ifeq ($(ARCH),x86_64)
GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux_x86_64
#else
#GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux
#endif

endif # End Not Cygwin

CC:=$(GCC_INSTALL)/bin/gcc
CXX:=$(GCC_INSTALL)/bin/g++

ifneq (false,$(QUESTA_ENABLE_VOPT))
ifeq ($(DEBUG),true)
ifeq ($(HAVE_VISUALIZER),true)
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
else # QUESTA_ENABLE_VOPT=false
	TOP=$(TOP_MODULE)
ifeq ($(DEBUG),true)
	DOFILE_COMMANDS += "log -r /\*;"
endif
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


BUILD_COMPILE_TARGETS += vlog_compile

RUN_TARGETS += run_vsim

ifneq (false,$(QUESTA_ENABLE_VCOVER))
POST_RUN_TARGETS += cov_merge
endif

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
	VOPT_FLAGS += +cover$(VOPT_COVEROPTS)
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
	VSIM_FLAGS += -batch -do run.do
endif

else # Rules

questa-sim-info :
	@echo "qs - QuestaSim"

questa-sim-options :
	@echo "Simulator: qs (QuestaSim)"
	@echo "  +tool.questa.codecov      - Enables collection of code coverage"
	@echo "  +tool.questa.ucdb=<name>  - Specifies the name of the merged UCDB file"

.phony: vopt_opt vopt_dbg vlog_compile

ifneq (false,$(QUESTA_ENABLE_VOPT))
ifeq ($(HAVE_VISUALIZER),true)
vlog_build : vopt_opt
else
vlog_build : vopt_opt vopt_dbg
endif
else # QUESTA_ENABLE_VOPT=false
vlog_build : vlog_compile
endif

VOPT_OPT_DEPS += vlog_compile
VOPT_DBG_DEPS += vlog_compile

ifeq ($(HAVE_VISUALIZER),true)
	VOPT_FLAGS += +designfile -debug
	VSIM_FLAGS += -classdebug -uvmcontrol=struct,msglog 
	VSIM_FLAGS += -qwavedb=+report=class+signal+class+transaction+uvm_schematic+memory=256,2
endif

vopt_opt : $(VOPT_OPT_DEPS)
	$(Q)$(VOPT) -o $(TB)_opt $(TB_MODULES) $(VOPT_FLAGS) $(REDIRECT) 

vopt_dbg : $(VOPT_DBG_DEPS)
	$(Q)$(VOPT) +acc -o $(TB)_dbg $(TB_MODULES) $(VOPT_FLAGS) $(REDIRECT)

work_lib : 
	$(Q)rm -rf work
	$(Q)vlib work
	$(Q)vmap work $(BUILD_DIR_A)/work

vlog_compile : work_lib
	$(Q)echo "VCOM_ARGS=$(VCOM_ARGS)"
	$(Q)MSYS2_ARG_CONV_EXCL="+incdir+;+define+" vlog -sv \
		$(VLOG_FLAGS) \
		$(QS_VLOG_ARGS) \
		$(VLOG_ARGS_PRE) $(VLOG_ARGS)
	$(Q)if test "x$(VCOM_ARGS)" != "x"; then \
		MSYS2_ARG_CONV_EXCL="+incdir+;+define+" vcom \
			$(VCOM_FLAGS) $(QS_VCOM_ARGS) $(VCOM_ARGS) ; \
	fi

vhdl_compile : $(VLOG_COMPILE_DEPS)
	$(Q)echo "VCOM_ARGS=$(VCOM_ARGS)"

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
	$(Q)vsim $(VSIM_FLAGS) $(TOP) -l simx.log \
		+TESTNAME=$(TESTNAME) -f sim.f $(DPI_LIB_OPTIONS) \
		$(foreach lib,$(DPI_LIBRARIES),-sv_lib $(lib)) $(REDIRECT)
endif

UCDB_FILES := $(foreach	test,$(call get_plusarg,TEST,$(PLUSARGS)),$(RUN_ROOT)/$(test)/cov.ucdb)
cov_merge:
	vcover merge $(RUN_ROOT)/$(UCDB_NAME) $(UCDB_FILES)
	
endif
