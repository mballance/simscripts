#****************************************************************************

#* common_sim_vl.mk
#*
#* Build and run definitions and rules for Verilator
#*
#*
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
HAVE_XPROP:=$(call have_plusarg,tool.questa.xprop,$(PLUSARGS))
HAVE_MODELSIM_ASE:=$(call have_plusarg,tool.modelsim_ase,$(PLUSARGS))

ifeq (true,$(HAVE_MODELSIM_ASE))
QUESTA_ENABLE_VOPT := false
QUESTA_ENABLE_VCOVER := false
endif

ifeq (,$(VERILATOR_HOME))
  which_vl:=$(dir $(shell which verilator))
#  VERILATOR_ROOT:=$(abspath $(which_vl)/../share/verilator)
  VERILATOR_HOME:=$(abspath $(which_vl)/../share/verilator)

  CXXFLAGS += -I$(VERILATOR_HOME)/include -I$(VERILATOR_HOME)/include/vltstd
#  export VERILATOR_HOME
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

VERILATOR_INST=/project/tools/verilator/3.920
#VERILATOR_INST=/project/tools/verilator/v4-dev

CXXFLAGS += -Iobj_dir -ISRC_DIRS 
CXXFLAGS += -I$(VERILATOR_INST)/share/verilator/include
CXXFLAGS += -I$(VERILATOR_INST)/share/verilator/include/vltstd

#********************************************************************
#* Capabilities configuration
#********************************************************************
# VLOG_FLAGS += +define+HAVE_HDL_VIRTUAL_INTERFACE

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

# Include the definition of VERILATOR_DEPS 
-include verilator.d

#ifeq ($(ARCH),x86_64)
GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux_x86_64
#else
#GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux
#endif

endif # End Not Cygwin

BUILD_COMPILE_TARGETS += vl_compile
BUILD_LINK_TARGETS += vl_link

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
REDIRECT:= >simx.log 2>&1
else
REDIRECT:=2>&1 | tee simx.log
endif

VSIM_FLAGS += $(RUN_ARGS)
VSIM_FLAGS += -sv_seed $(SEED)

RUN_TARGETS += vl_run

#ifneq (false,$(QUESTA_ENABLE_VCOVER))
#POST_RUN_TARGETS += cov_merge
#endif

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

ifeq (,$(VLOG_ARGS_HDL))
ifneq (,$(wildcard $(SIM_DIR)/scripts/vlog_$(SIM)_hdl.f))
VLOG_ARGS_HDL += -f $(SIM_DIR_A)/scripts/vlog_$(SIM)_hdl.f
else
VLOG_ARGS_HDL += -f $(SIM_DIR_A)/scripts/vlog_hdl.f
endif
endif


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

vl_compile : vl_translate.d vl_compile.d


vl_translate.d : $(VERILATOR_DEPS)
	$(Q)verilator --cc --exe -sv -Wno-fatal -MMD --top-module $(TB_MODULES_HDL) \
		--trace-lxt2 \
		$(VLOG_FLAGS) $(VLOG_ARGS_HDL) 
	$(Q)sed -e 's/^[^:]*: /VERILATOR_DEPS=/' obj_dir/V$(TB_MODULES_HDL)__ver.d > verilator.d
	$(Q)touch $@
	
vl_compile.d : vl_translate.d
	$(Q)$(MAKE) -C obj_dir -f V$(TB_MODULES_HDL).mk V$(TB_MODULES_HDL)__ALL.a
	$(Q)touch $@
	
vl_link : obj_dir/V$(TB_MODULES_HDL)$(EXEEXT)

# Definitely need to relink of we recompiled
obj_dir/V$(TB_MODULES_HDL)$(EXEEXT) : vl_compile.d $(VL_TB_OBJS_LIBS)
	$(Q)$(MAKE) -C obj_dir -f V$(TB_MODULES_HDL).mk V$(TB_MODULES_HDL)$(EXEEXT) \
		VK_USER_OBJS="$(foreach l,$(VL_TB_OBJS_LIBS),$(abspath $(l)))" \
		VM_USER_LDLIBS="-lz -lpthread"


vl_run :
	$(Q)$(BUILD_DIR)/obj_dir/V$(TB_MODULES_HDL)$(EXEEXT) \
	  +TESTNAME=$(TESTNAME) -f sim.f $(REDIRECT)
	
ifneq (false,$(QUESTA_ENABLE_VOPT))
ifeq (true,$(HAVE_VISUALIZER))
vlog_build : vopt_opt
else
vlog_build : vopt_opt vopt_dbg
endif
else # QUESTA_ENABLE_VOPT=false
vlog_build : vlog_compile
endif

VOPT_OPT_DEPS += vlog_compile
VOPT_DBG_DEPS += vlog_compile

ifeq (true,$(HAVE_VISUALIZER))
	VOPT_FLAGS += +designfile -debug
	VSIM_FLAGS += -classdebug -uvmcontrol=struct,msglog 
	VSIM_FLAGS += -qwavedb=+report=class+signal+class+transaction+uvm_schematic+memory=256,2
endif

vopt_opt : $(VOPT_OPT_DEPS)
	$(Q)vopt -o $(TB)_opt $(TB_MODULES) $(VOPT_FLAGS) $(REDIRECT) 

vopt_dbg : $(VOPT_DBG_DEPS)
	$(Q)vopt +acc -o $(TB)_dbg $(TB_MODULES) $(VOPT_FLAGS) $(REDIRECT)


vlog_compile : $(VLOG_COMPILE_DEPS)
	$(Q)echo QUESTA_ENABLE_VOPT=$(QUESTA_ENABLE_VOPT)
	$(Q)rm -rf work
	$(Q)vlib work
	$(Q)vmap work $(BUILD_DIR_A)/work
	$(Q)MSYS2_ARG_CONV_EXCL="+incdir+;+define+" vlog -sv \
		$(VLOG_FLAGS) \
		$(QS_VLOG_ARGS) \
		$(VLOG_ARGS_PRE) $(VLOG_ARGS)


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

	
endif # Rules

