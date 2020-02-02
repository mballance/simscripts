#********************************************************************
#* common_tool_cocotb.mk
#********************************************************************
SIMSCRIPTS_MKFILES_DIR:=$(dir $(lastword $(MAKEFILE_LIST)))

ifneq (1,$(RULES))

COCOTB_MODULE:=$(call get_plusarg,cocotb.module,$(PLUSARGS))

RUN_ENV_VARS += MODULE=$(COCOTB_MODULE)

BUILD_PRECOMPILE_TARGETS += gen-cocotb-bfms
BUILD_COMPILE_TARGETS += build-cocotb-libs
#USER_DIR=$(BUILD_DIR)/cocotb
#export USER_DIR
#COCOTB_SHARE_DIR = $(shell /usr/bin/env cocotb-config --share)

VPI_LIBRARIES += $(BUILD_DIR)/cocotb/build/libs/x86_64/cocotb.vpi
DPI_OBJS_LIBS += $(BUILD_DIR)/cocotb/build/libs/x86_64/libgpi.so
LD_LIBRARY_PATH:=$(BUILD_DIR)/cocotb/build/libs/x86_64:$(LD_LIBRARY_PATH)
export LD_LIBRARY_PATH

# Would be nice to not need to do this
PYTHONPATH:=$(BUILD_DIR)/cocotb/build/libs/x86_64:$(PYTHONPATH)
export PYTHONPATH

VLOG_DEFINES += HAVE_COCOTB
# TODO: Add different files based on simulator capabilities?
ifeq (systemverilog,$(SIM_LANGUAGE))
COCOTB_BFM_LANGUAGE=sv
VLOG_ARGS_HDL += $(BUILD_DIR)/cocotb_bfms.sv $(BUILD_DIR)/cocotb_bfms.c
# VLOG_ARGS_HDL += $(BUILD_DIR)/cocotb_bfms.sv
else
ifeq (verilog,$(SIM_LANGUAGE))
COCOTB_BFM_LANGUAGE=vlog
VLOG_ARGS_HDL += $(BUILD_DIR)/cocotb_bfms.v
else
COCOTB_BFM_LANGUAGE=UNKNOWN-$(SIM_LANGUAGE)
endif
endif

#COCOTB_SIM=icarus
#export COCOTB_SIM

else

$(BUILD_DIR)/cocotb/build/libs/x86_64/libgpi.so : build-cocotb-libs

build-cocotb-libs :
	$(Q)$(MAKE) -f $(SIMSCRIPTS_MKFILES_DIR)/cocotb_libs.mk \
		USER_DIR=$(BUILD_DIR)/cocotb -j1 vpi-libs
		
gen-cocotb-bfms :
	$(Q)cocotb-bfmgen generate --language $(COCOTB_BFM_LANGUAGE) \
		$(foreach m,$(COCOTB_BFM_MODULES),-m $(m))

endif

