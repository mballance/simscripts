#********************************************************************
#* common_tool_pybfms.mk
#********************************************************************
SIMSCRIPTS_MKFILES_DIR:=$(dir $(lastword $(MAKEFILE_LIST)))

ifneq (1,$(RULES))

COCOTB_MODULE:=$(call get_plusarg,cocotb.module,$(PLUSARGS))

BUILD_PRECOMPILE_TARGETS += gen-pybfms

VPI_LIBRARIES += $(shell $(PYTHON_BIN) -m pybfms lib --vpi)
DPI_OBJS_LIBS += $(shell $(PYTHON_BIN) -m pybfms lib --dpi)

PYBFMS_LIBDIR = $(dir $(shell $(PYTHON_BIN) -m pybfms lib --vpi))

LD_LIBRARY_PATH:=$(PYBFMS_LIBDIR):$(LD_LIBRARY_PATH)
export LD_LIBRARY_PATH

#DPI_LDFLAGS += -L$(shell python3-config --prefix)/lib $(shell python3-config --libs)

# TODO: Add different files based on simulator capabilities?
ifeq (systemverilog,$(SIM_LANGUAGE))
PYBFMS_LANGUAGE=sv
VLOG_ARGS_HDL += $(BUILD_DIR)/pybfms.sv $(BUILD_DIR)/pybfms.c
else
ifeq (verilog,$(SIM_LANGUAGE))
PYBFMS_LANGUAGE=vlog
VLOG_ARGS_HDL += $(BUILD_DIR)/pybfms.v
else
COCOTB_BFM_LANGUAGE=UNKNOWN-$(SIM_LANGUAGE)
endif
endif

else

#********************************************************************
#* Generate pybfms wrappers
#********************************************************************
gen-pybfms :
	$(Q)$(PYTHON_BIN) -m pybfms generate -l $(PYBFMS_LANGUAGE) \
		$(foreach m,$(COCOTB_BFM_MODULES),-m $(m))

endif

