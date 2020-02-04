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
#COCOTB_SHARE_DIR:=$(shell cocotb-config --share)
#export COCOTB_SHARE_DIR

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

#********************************************************************
#* Build the coctb libraries
#*
#* Note: The cocotb makefiles directly reference 'gcc' and 'g++'.
#*       In order to use Conda, we need to use $(CC) and $(CXX)
#*       instead. The code below does a little switch-around, 
#*       copying and modifying the Makefiles from cocotb such that
#*       they can be used standalone, and so they reference the
#*       compilers correctly.
#********************************************************************
build-cocotb-libs :
	$(Q)COCOTB_SHARE_DIR=`cocotb-config --share`; \
                cp -r $$COCOTB_SHARE_DIR/makefiles . ; \
                cp $$COCOTB_SHARE_DIR/lib/Makefile makefiles
	$(Q)for file in `find makefiles -type f`; do \
		sed -i -e 's%include $$(COCOTB_SHARE_DIR)/makefiles%include $$(SIMSCRIPTS_BUILD_DIR)/makefiles%g' \
                       -e 's%\<gcc\>%$$(CC)%g' \
                       -e 's%\<g\+\+\>%$$(CXX)%g' \
                    $$file; \
            done
	$(Q)$(MAKE) -f $(SIMSCRIPTS_MKFILES_DIR)/cocotb_libs.mk \
		USER_DIR=$(BUILD_DIR)/cocotb \
                SIMSCRIPTS_BUILD_DIR=$(BUILD_DIR) \
                -j1 vpi-libs
		
gen-cocotb-bfms :
	$(Q)cocotb-bfmgen generate --language $(COCOTB_BFM_LANGUAGE) \
		$(foreach m,$(COCOTB_BFM_MODULES),-m $(m))

endif

