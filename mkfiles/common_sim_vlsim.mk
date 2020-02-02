#****************************************************************************
#* common_sim_vlsim.mk
#*
#* Build and run definitions and rules for using the vlsim Verilator wrapper
#*
#* +tool.sim.codecov
#*
#****************************************************************************

#********************************************************************
#* Compile rules
#********************************************************************

ifneq (1,$(RULES))

VALGRIND_ENABLED:=$(call have_plusarg,tool.vl.valgrind,$(PLUSARGS))
CODECOV_EN:=$(call have_plusarg,tool.sim.codecov,$(PLUSARGS))

ifeq (true,$(CODECOV_EN))
  VLOG_FLAGS += --coverage
endif

VERILATOR_INST=/project/tools/verilator/3.920
#VERILATOR_INST=/project/tools/verilator/v4-dev

CXXFLAGS += -Iobj_dir -ISRC_DIRS 
CXXFLAGS += -I$(VERILATOR_INST)/share/verilator/include
CXXFLAGS += -I$(VERILATOR_INST)/share/verilator/include/vltstd

ifeq (ms,$(findstring ms,$(TIMEOUT)))
  timeout=$(shell expr $(subst ms,,$(TIMEOUT)) '*' 1000000)
else
  ifeq (us,$(findstring us,$(TIMEOUT)))
    timeout=$(shell expr $(subst ns,,$(TIMEOUT)) '*' 1000)
  else
    ifeq (ns,$(findstring ns,$(TIMEOUT)))
      timeout=$(shell expr $(subst ns,,$(TIMEOUT)) '*' 1)
    else
      ifeq (s,$(findstring s,$(TIMEOUT)))
        timeout=$(shell expr $(subst s,,$(TIMEOUT)) '*' 1000000000)
      else
        timeout=error: unknown $(TIMEOUT)
      endif
    endif
  endif
endif

#********************************************************************
#* Capabilities configuration
#********************************************************************
# VLOG_FLAGS += +define+HAVE_HDL_VIRTUAL_INTERFACE
# VLOG_FLAGS += +define+HAVE_DPI
#VLOG_DEFINES += HAVE_HDL_DUMP HAVE_HDL_CLKGEN

SIM_LANGUAGE=systemverilog

# Include the definition of VERILATOR_DEPS 
-include verilator.d

BUILD_COMPILE_TARGETS += vlsim_compile
#BUILD_LINK_TARGETS += vl_link

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
REDIRECT:= >simx.log 2>&1
else
REDIRECT:=2>&1 | tee simx.log
endif

VSIM_FLAGS += $(RUN_ARGS)
VSIM_FLAGS += -sv_seed $(SEED)

RUN_TARGETS += vlsim_run

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

VLOG_FLAGS += $(foreach d,$(VLOG_DEFINES),+define+$(d))
VLOG_FLAGS += $(foreach i,$(VLOG_INCLUDES),+define+$(call native_path,$(i)))

VOPT_FLAGS += -dpiheader $(TB)_dpi.h

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

.phony: vopt_opt vopt_dbg vlog_compile

VLOG_FLAGS += $(foreach clk,$(VLSIM_CLOCKSPEC),-clkspec $(clk))

ifneq (,$(VPI_LIBRARIES))
    VLOG_FLAGS += --vpi
endif

vlsim_compile : $(DPI_OBJS_LIBS)
	$(Q)vlsim -sv --trace-fst --top-module $(TB_MODULES_HDL) -Wno-fatal \
		$(VLOG_FLAGS) $(VLOG_ARGS_HDL) \
		$(foreach l,$(DPI_OBJS_LIBS),$(abspath $(l)))
	
ifeq (true,$(VALGRIND_ENABLED))
  VALGRIND=valgrind --tool=memcheck 
endif

ifeq (true,$(DEBUG))
RUN_ARGS += +vlsim.trace
endif

vlsim_run :
	$(Q)filelist-flatten -o arguments.txt -f sim.f $(RUN_ARGS)
	$(Q)$(RUN_ENV_VARS_V)$(BUILD_DIR)/simv \
		+vlsim.timeout=$(TIMEOUT) \
		+TESTNAME=$(TESTNAME) \
		$(foreach v,$(VPI_LIBRARIES),+vpi=$(abspath $(v))) \
		`cat arguments.txt` $(REDIRECT)
	
endif # Rules

