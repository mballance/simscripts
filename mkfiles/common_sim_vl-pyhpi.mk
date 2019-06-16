#****************************************************************************
#* common_sim_vl-pyhpi.mk
#*
#* Build and run definitions and rules for Verilator
#*
#* PYHPI_BFMS=[list of BFMs to create]
#* PYHPI_MODULES=[list of modules to load]
#* PYHPI_CLOCKSPEC=[-clk name=period]
#*
#****************************************************************************

#********************************************************************
#* Compile rules
#********************************************************************

ifneq (1,$(RULES))

ifeq (,$(VERILATOR_HOME))
  which_vl:=$(dir $(shell which verilator))
#  VERILATOR_ROOT:=$(abspath $(which_vl)/../share/verilator)
  VERILATOR_HOME:=$(abspath $(which_vl)/../share/verilator)

  CXXFLAGS += -I$(VERILATOR_HOME)/include -I$(VERILATOR_HOME)/include/vltstd
#  export VERILATOR_HOME
endif

#VERILATOR_INST=/project/tools/verilator/3.920
#VERILATOR_INST=/project/tools/verilator/v4-dev

CXXFLAGS += -Iobj_dir -ISRC_DIRS 
#CXXFLAGS += -I$(VERILATOR_INST)/share/verilator/include
#CXXFLAGS += -I$(VERILATOR_INST)/share/verilator/include/vltstd

#********************************************************************
#* Capabilities configuration
#********************************************************************
VLOG_FLAGS += +define+HAVE_DPI

# Include the definition of VERILATOR_DEPS 
-include verilator.d

BUILD_COMPILE_TARGETS += vl_compile
BUILD_LINK_TARGETS += vl_link

ifeq (,$(TB_MODULES))
ifneq (,$(TB_MODULES_HDL))
TB_MODULES = $(TB_MODULES_HDL) $(TB_MODULES_HVL)
else
TB_MODULES = $(TB)
endif
endif

ifeq (true,$(QUIET))
REDIRECT:= >simx.log 2>&1
else
REDIRECT:=2>&1 | tee simx.log
endif

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

ifeq (,$(VLOG_ARGS_HDL))
ifneq (,$(wildcard $(SIM_DIR)/scripts/vlog_$(SIM)_hdl.f))
VLOG_ARGS_HDL += -f $(SIM_DIR_A)/scripts/vlog_$(SIM)_hdl.f
else
VLOG_ARGS_HDL += -f $(SIM_DIR_A)/scripts/vlog_hdl.f
endif
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

PYTHONPATH := $(shell echo $(PY_SRC_DIRS) | sed -e 's/[ ][ ]*/:/g'):$(PYTHONPATH)
SPACE := 
pyhpi-launcher :
	$(Q)export PYTHONPATH=$(PYTHONPATH) ; \
		hpi gen-launcher-vl --trace-fst $(TB_MODULES_HDL) $(PYHPI_CLOCKSPEC)
	
pyhpi-dpi :
	$(Q)export PYTHONPATH=$(PYTHONPATH) ; \
		hpi gen-dpi $(foreach m,$(PYHPI_MODULES),-m $(m))

PYTHON_CFLAGS := $(shell python3-config --cflags)
PYTHON_LDFLAGS := $(shell python3-config --ldflags)

vl_translate.d : pyhpi-launcher pyhpi-dpi
	$(Q)verilator --cc --exe -sv -Wno-fatal -MMD --top-module $(TB_MODULES_HDL) \
		--trace-fst \
		-CFLAGS "$(PYTHON_CFLAGS)" \
		-LDFLAGS "$(PYTHON_LDFLAGS)" \
		$(VLOG_FLAGS) $(VLOG_ARGS_HDL) \
		launcher_vl.cpp pyhpi_dpi.c
	$(Q)sed -e 's/^[^:]*: /VERILATOR_DEPS=/' obj_dir/V$(TB_MODULES_HDL)__ver.d > verilator.d
	$(Q)touch $@
	
vl_compile.d : vl_translate.d
	$(Q)$(MAKE) -C obj_dir -f V$(TB_MODULES_HDL).mk
	$(Q)touch $@
	
#vl_link : obj_dir/V$(TB_MODULES_HDL)$(EXEEXT)

# Definitely need to relink of we recompiled
#obj_dir/V$(TB_MODULES_HDL)$(EXEEXT) : vl_compile.d $(VL_TB_OBJS_LIBS) $(DPI_OBJS_LIBS)
#	$(Q)$(MAKE) -C obj_dir -f V$(TB_MODULES_HDL).mk V$(TB_MODULES_HDL)$(EXEEXT) \
#		VK_USER_OBJS="$(foreach l,$(VL_TB_OBJS_LIBS) $(DPI_OBJS_LIBS),$(abspath $(l)))" \
#		VM_USER_LDLIBS="-lz -lpthread"

ifeq (true,$(VALGRIND_ENABLED))
  VALGRIND=valgrind --tool=memcheck 
endif

ifeq (true,$(DEBUG))
RUN_ARGS += +vl.trace=simx.fst
endif

vl_run :
	$(Q)export PYTHONPATH=$(PYTHONPATH) ; \
	$(VALGRIND)$(BUILD_DIR)/obj_dir/V$(TB_MODULES_HDL)$(EXEEXT) \
          +vl.timeout=$(TIMEOUT) \
	  +TESTNAME=$(TESTNAME) -f sim.f $(RUN_ARGS) $(REDIRECT)
	
endif # Rules

