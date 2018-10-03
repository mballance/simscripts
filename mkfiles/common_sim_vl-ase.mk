#****************************************************************************

#* common_sim_vl-ase.mk
#*
#* Build and run definitions and rules for Verilator running in 
#* cosimulation mode
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
PATH := $(QUESTA_HOME)/gcc-4.7.4-linux/bin:$(PATH)
export PATH

CXX := $(QUESTA_HOME)/gcc-4.7.4-linux/bin/g++
CC := $(QUESTA_HOME)/gcc-4.7.4-linux/bin/gcc
LD := $(LD) -m elf_i386

SRC_DIRS += $(QUESTA_HOME)/verilog_src/uvm-1.2/src/dpi
SRC_DIRS += $(QUESTA_HOME)/include
CFLAGS += -DQUESTA
CXXFLAGS += -DQUESTA

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

ifeq (,$(VERILATOR_HOME))
  which_vl:=$(dir $(shell which verilator))
#  VERILATOR_ROOT:=$(abspath $(which_vl)/../share/verilator)
  VERILATOR_HOME:=$(abspath $(which_vl)/../share/verilator)

  CXXFLAGS += -I$(VERILATOR_HOME)/include -I$(VERILATOR_HOME)/include/vltstd
#  export VERILATOR_HOME
endif

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
REDIRECT:= >/dev/null 2>&1
else
endif

VSIM_FLAGS += $(RUN_ARGS)
VSIM_FLAGS += +OBJ_DIR=$(BUILD_DIR)/obj_dir
VSIM_FLAGS += -sv_seed $(SEED)
VSIM_FLAGS += -modelsimini $(BUILD_DIR)/modelsim.ini

RUN_TARGETS += vl_run

#ifneq (false,$(QUESTA_ENABLE_VCOVER))
#POST_RUN_TARGETS += cov_merge
#endif

SIMSCRIPTS_SIM_INFO_TARGETS   += questa-sim-info
SIMSCRIPTS_SIM_OPTION_TARGETS += questa-sim-options

DPI_OBJS_LIBS += uvm_dpi.o

ifneq (,$(DPI_OBJS_LIBS))
DPI_LIBRARIES += $(BUILD_DIR)/dpi
LIB_TARGETS += $(BUILD_DIR)/dpi$(DPIEXT)
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

ifeq (,$(VLOG_ARGS_HVL))
ifneq (,$(wildcard $(SIM_DIR)/scripts/vlog_$(SIM)_hvl.f))
VLOG_ARGS_HVL += -f $(SIM_DIR_A)/scripts/vlog_$(SIM)_hvl.f
else
VLOG_ARGS_HVL += -f $(SIM_DIR_A)/scripts/vlog_hvl.f
endif
endif


DPI_LIB_OPTIONS := -ldflags "$(foreach l,$(DPI_OBJS_LIBS),$(BUILD_DIR_A)/$(l)) $(DPI_SYSLIBS)"
VOPT_OPT_DEPS += $(DPI_OBJS_LIBS)
VOPT_DBG_DEPS += $(DPI_OBJS_LIBS)

ifneq (true,$(INTERACTIVE))
	VSIM_FLAGS += -batch -do "run 10us; quit -f"
endif

ifeq (true,$(DEBUG))
  VSIM_FLAGS += +verilator.debug
endif

# Add in the vl_ase top
TB_MODULES_HVL += top_vl_ase

else # Rules

questa-sim-info :
	@echo "qs - QuestaSim"

questa-sim-options :
	@echo "Simulator: qs (QuestaSim)"
	@echo "  +tool.questa.codecov      - Enables collection of code coverage"
	@echo "  +tool.questa.ucdb=<name>  - Specifies the name of the merged UCDB file"

.phony: vopt_opt vopt_dbg vlog_compile

vl_compile : vl_translate.d vl_compile.d vlog_compile


vl_translate.d : $(VERILATOR_DEPS)
	$(Q)echo "VERILATOR_ROOT=$(VERILATOR_ROOT)"
	$(Q)verilator --cc --exe -sv -Wno-fatal -MMD \
		--trace-lxt2 \
		-CFLAGS "-fPIC -m32" \
		-LDFLAGS "-shared -m32" \
		--top-module $(TB_MODULES_HDL) \
		$(VLOG_FLAGS) $(VLOG_ARGS_HDL) 
	$(Q)python $(SIMSCRIPTS_DIR)/scripts/vl_ase.py -top $(TB_MODULES_HDL)
#	$(Q)sed -e 's/^[^:]*: /VERILATOR_DEPS=/' obj_dir/V$(TB_MODULES_HDL)__ver.d > verilator.d
	$(Q)touch $@
	
vl_compile.d : vl_translate.d
	$(Q)echo "VERILATOR_ROOT=$(VERILATOR_ROOT)"
	$(Q)$(MAKE) CC=$(CC) CXX=$(CXX) \
		-C obj_dir -f V$(strip $(TB_MODULES_HDL)).mk \
		V$(strip $(TB_MODULES_HDL))__ALL.a 
	$(Q)touch $@

vlog_compile : vl_compile.d
	$(Q)vlib work
	$(Q)vmap work $(BUILD_DIR)/work
	$(Q)vmap mtiUvm $(BUILD_DIR)/work
	$(Q)vlog -sv \
		+incdir+$(QUESTA_HOME)/verilog_src/uvm-1.2/src \
		+define+UVM_OBJECT_DO_NOT_NEED_CONSTRUCTOR \
		$(QUESTA_HOME)/verilog_src/uvm-1.2/src/uvm_pkg.sv
	$(Q)vlog -sv \
		+define+UVM_OBJECT_DO_NOT_NEED_CONSTRUCTOR \
		+incdir+$(QUESTA_HOME)/verilog_src/uvm-1.2/src \
		obj_dir/top_vl_ase.sv \
		obj_dir/hvl_dpi.c \
		$(VLOG_ARGS_HVL) 
	
vl_link : obj_dir/V$(strip $(TB_MODULES_HDL))$(EXEEXT)

# Definitely need to relink of we recompiled
obj_dir/V$(TB_MODULES_HDL)$(EXEEXT) : vl_compile.d $(VL_TB_OBJS_LIBS)
	$(Q)$(MAKE) CC=$(CC) CXX=$(CXX) \
		VK_USER_OBJS="hdl_dpi.o" \
		-C obj_dir -f V$(strip $(TB_MODULES_HDL)).mk 
#	$(Q)cp obj_dir/V$(strip $(TB_MODULES_HDL))$(EXEEXT) \
#		lib$(strip $(TB_MODULES_HDL))$(DLIBEXT)


vl_run :
	$(Q)vsim \
		-l simx.log +TESTNAME=$(TESTNAME) -f sim.f \
		$(VSIM_FLAGS) \
		$(foreach lib,$(DPI_LIBRARIES),-sv_lib $(lib)) \
		$(TB_MODULES_HVL)
	
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

$(BUILD_DIR)/dpi$(DPIEXT) : $(DPI_OBJS_LIBS)
	$(Q)$(CXX) -shared -o $@ $(DPI_OBJS_LIBS) $(DPI_SYSLIBS)
	
endif # Rules

