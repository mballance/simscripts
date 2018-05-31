#****************************************************************************

#* common_sim_vel.mk
#*
#* Build and run definitions and rules for Veloce3
#*
#****************************************************************************

#********************************************************************
#* Compile rules
#********************************************************************

ifneq (1,$(RULES))

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

GCC_INSTALL := $(QUESTA_HOME)/gcc-$(GCC_VERSION)-linux_x86_64

CC:=$(GCC_INSTALL)/bin/gcc
CXX:=$(GCC_INSTALL)/bin/g++

ifneq (false,$(QUESTA_ENABLE_VOPT))
ifeq ($(DEBUG),true)
ifeq (true,$(HAVE_VISUALIZER))
	TOP=$(TOP_MODULE)_opt
	ifeq (true, $(INTERACTIVE))
		VSIM_FLAGS += -visualizer=design.bin
	endif
else
	DOFILE_COMMANDS += "log -r /\*;"
#	BUILD_LINK_TARGETS += vopt_dbg
	TOP=$(TOP_MODULE)_dbg
endif
else
	TOP=$(TOP_MODULE)_opt
endif
else # QUESTA_ENABLE_VOPT=false
	TOP=$(TOP_MODULE)
ifeq ($(DEBUG),true)
	DOFILE_COMMANDS += "log -r /\*;"
endif
endif

ifeq (,$(TB_MODULES))
TB_MODULES = $(TB)
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

BUILD_COMPILE_TARGETS += velhvl.build

RUN_TARGETS += run_vel

ifneq (false,$(QUESTA_ENABLE_VCOVER))
POST_RUN_TARGETS += cov_merge
endif

SIMSCRIPTS_SIM_INFO_TARGETS   += questa-sim-info
SIMSCRIPTS_SIM_OPTION_TARGETS += questa-sim-options

ifneq (,$(DPI_OBJS_LIBS))
# DPI_LIBRARIES += $(BUILD_DIR_A)/dpi
LIB_TARGETS += $(BUILD_DIR_A)/dpi$(DPIEXT)
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

ifneq (true,$(INTERACTIVE))
	VSIM_FLAGS += -c -do run.do
endif

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

ifeq (,$(VLOG_ARGS_HDL_HVL))
ifneq (,$(wildcard $(SIM_DIR)/scripts/vlog_$(SIM)_hdl_hvl.f))
VLOG_ARGS_HDL_HVL += -f $(SIM_DIR_A)/scripts/vlog_$(SIM)_hdl_hvl.f
else
VLOG_ARGS_HDL_HVL += -f $(SIM_DIR_A)/scripts/vlog_hdl_hvl.f
endif
endif

else # Rules

vel-sim-info :
	@echo "vel - Veloce3"

vel-sim-options :
	@echo "Simulator: vel (Veloce)"
#	@echo "  +tool.questa.codecov      - Enables collection of code coverage"
#	@echo "  +tool.questa.ucdb=<name>  - Specifies the name of the merged UCDB file"

velhvl.build : velcomp.build
	$(Q)echo "velhvl.build"
	$(Q)vlog -sv \
		$(VLOG_FLAGS) \
		$(VEL_VLOG_FLAGS) \
		$(VLOG_ARGS_PRE) $(VLOG_ARGS_HVL)
	$(Q)MGC_HOME=$(QUESTA_HOME) velhvl -cppinstall 4.5.0
	$(Q)touch $@

velcomp.build : velanalyze.build
	$(Q)echo "velcomp.build"
	$(Q)velcomp $(foreach top,$(TB_MODULES_HDL),-top $(top))
	$(Q)touch $@

velanalyze.build : $(VLOG_COMPILE_DEPS) $(SIM_DIR)/scripts/veloce.config
	$(Q)cp $(SIM_DIR)/scripts/veloce.config .
	$(Q)rm -rf work
#	$(Q)vellib work
#	$(Q)velmap work work
	$(Q)velanalyze -sv \
		$(VLOG_FLAGS) \
		$(VEL_VLOG_ARGS) \
		$(VLOG_ARGS_PRE) $(VLOG_ARGS_HDL) -mfcu +define+VELOCE_SLA +define+VELOCE
	$(Q)touch $@

run_vel :
	$(Q)echo "TODO: run Veloce"

endif
