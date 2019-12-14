#********************************************************************
#* common_tool_cocotb.mk
#********************************************************************
ifneq (1,$(RULES))

BUILD_PRECOMPILE_TARGETS += gen-cocotb-bfms
BUILD_COMPILE_TARGETS += build-cocotb-libs
#USER_DIR=$(BUILD_DIR)/cocotb
#export USER_DIR
#COCOTB_SHARE_DIR = $(shell /usr/bin/env cocotb-config --share)

COCOTB_DPI_LIBS = libgpi.so libcocotbutils.so libgpilog.so libcocotb.so

VPI_LIBRARIES += $(BUILD_DIR)/cocotb/build/libs/x86_64/cocotb.vpi
DPI_OBJS_LIBS += $(foreach l,$(COCOTB_DPI_LIBS), $(BUILD_DIR)/cocotb/build/libs/x86_64/$(l))
LD_LIBRARY_PATH:=$(BUILD_DIR)/cocotb/build/libs/x86_64:$(LD_LIBRARY_PATH)
export LD_LIBRARY_PATH

DPI_LDFLAGS += -L$(shell python3-config --prefix)/lib $(shell python3-config --libs)

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

$(foreach l,$(COCOTB_DPI_LIBS),$(BUILD_DIR)/cocotb/build/libs/x86_64/$(l)) : build-cocotb-libs

build-cocotb-libs :
	$(Q)COCOTB_SHARE_DIR=`cocotb-config --share` ; \
		$(MAKE) USER_DIR=$(BUILD_DIR)/cocotb -j1 -f $$COCOTB_SHARE_DIR/makefiles/Makefile.lib
		
gen-cocotb-bfms :
	$(Q)cocotb-bfmgen generate --language $(COCOTB_BFM_LANGUAGE) \
		$(foreach m,$(COCOTB_BFM_MODULES),-m $(m))

endif

