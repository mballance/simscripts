#********************************************************************
#* common_tool_cocotb.mk
#********************************************************************
ifneq (1,$(RULES))

BUILD_COMPILE_TARGETS += build-cocotb-libs
USER_DIR=$(BUILD_DIR)/cocotb
export USER_DIR
#COCOTB_SHARE_DIR = $(shell /usr/bin/env cocotb-config --share)

VPI_LIBRARIES += $(BUILD_DIR)/cocotb/build/libs/x86_64/cocotb.vpi
LD_LIBRARY_PATH:=$(BUILD_DIR)/cocotb/build/libs/x86_64:$(LD_LIBRARY_PATH)
export LD_LIBRARY_PATH

# Would be nice to not need to do this
PYTHONPATH:=$(BUILD_DIR)/cocotb/build/libs/x86_64:$(PYTHONPATH)
export PYTHONPATH

#COCOTB_SIM=icarus
#export COCOTB_SIM

else

build-cocotb-libs :
	$(Q)COCOTB_SHARE_DIR=`cocotb-config --share` ; \
		$(MAKE) -j1 -f $$COCOTB_SHARE_DIR/makefiles/Makefile.lib

endif

