
include $(SIMSCRIPTS_DIR)/mkfiles/plusargs.mk

TOP_MODULE ?= $(TB)
DEBUG ?= false

# RUN_ARGS

# Timeout selection
# - Test-specific timeout
# - Project-specific timeout
# - 1ms
TEST_TIMEOUT := $(call get_plusarg,TIMEOUT,$(PLUSARGS))

ifneq (,$(TEST_TIMEOUT))
TIMEOUT := $(TEST_TIMEOUT)
else
TIMEOUT ?= 1ms
endif

COMMON_SIM_MK := $(lastword $(MAKEFILE_LIST))
COMMON_SIM_MK_DIR := $(dir $(COMMON_SIM_MK))
export COMMON_SIM_MK_DIR


DLLEXT=.so
LIBPREF=lib
SVF_LIBDIR ?= $(BUILD_DIR)/libs
SVF_OBJDIR ?= $(BUILD_DIR)/objs

ifeq (,$(DEFAULT_SIM))
SIM:=qs
else
SIM:=$(DEFAULT_SIM)
endif

include $(COMMON_SIM_MK_DIR)/common_defs.mk

# Locate the simulator-support file
# - Don't include a simulator-support file if SIM='none'
# - Allow the test suite to provide its own
# - Allow the environment to provide its own
# - Finally, check if 'simscripts' provides an implementation
ifneq (none,$(SIM))
	ifneq ("$(wildcard $(SIM_DIR)/scripts/common_sim_$(SIM).mk)","")
		MK_INCLUDES += $(SIM_DIR)/scripts/common_sim_$(SIM).mk
	else
		ifneq ("$(wildcard $(SIMSCRIPTS_DIR)/../mkfiles/common_sim_$(SIM).mk)","")
			MK_INCLUDES += $(SIMSCRIPTS_DIR)/../mkfiles/common_sim_$(SIM).mk	
		else
			ifneq ("$(wildcard $(SIMSCRIPTS_DIR)/mkfiles/common_sim_$(SIM).mk)","") 
				MK_INCLUDES += $(SIMSCRIPTS_DIR)/mkfiles/common_sim_$(SIM).mk
			else
				BUILD_TARGETS += missing_sim_mk
			endif
		endif
	endif
endif

# Filter out tool-control options like +tool.foo.setting_bar=XXX
SIMSCRIPTS_PLUSARGS_TOOLS := $(sort $(patsubst +tool.%,%,$(filter +tool.%,$(shell echo $(PLUSARGS) | sed -e 's/\+tool\.[a-zA-Z][a-zA-Z0-9_]*\.[a-zA-Z][a-zA-Z0-9_\.]*//g'))))

# Build a full list of tools to bring in
SIMSCRIPTS_TOOLS += $(SIMSCRIPTS_PLUSARGS_TOOLS)

# Include tool-specific makefiles
MK_INCLUDES += $(foreach tool,$(SIMSCRIPTS_TOOLS),$(SIMSCRIPTS_DIR)/mkfiles/common_tool_$(tool).mk)

include $(MK_INCLUDES)

DPIEXT=$(DLLEXT)

CXXFLAGS += $(foreach dir, $(SRC_DIRS), -I$(dir))
CFLAGS += $(foreach dir, $(SRC_DIRS), -I$(dir))

vpath %.cpp $(SRC_DIRS)
vpath %.S $(SRC_DIRS)
vpath %.c $(SRC_DIRS)


#BUILD_TARGETS += build-pre-compile build-compile build-post-compile build-pre-link
BUILD_TARGETS += build-post-link	
BUILD_LINK_TARGETS += $(LIB_TARGETS) $(EXE_TARGETS)
	

post_build : $(POSTBUILD_TARGETS)
	if test "x$(TARGET_MAKEFILE)" != "x"; then \
		$(MAKE) -f $(TARGET_MAKEFILE) build; \
	fi

ifeq (,$(wildcard $(SIM_DIR)/scripts/vlog_$(SIM).f))
#ifeq (Cygwin,$(OS))
#VLOG_ARGS += -f $(shell cygpath -w $(SIM_DIR)/scripts/vlog.f)
#else
VLOG_ARGS += -f $(SIM_DIR_A)/scripts/vlog.f
#endif
else
#ifeq (Cygwin,$(OS))
#VLOG_ARGS += -f $(shell cygpath -w $(SIM_DIR)/scripts/vlog_$(SIM).f)
#else
VLOG_ARGS += -f $(SIM_DIR_A)/scripts/vlog_$(SIM).f
#endif
endif


LD_LIBRARY_PATH := $(BUILD_DIR)/libs:$(LD_LIBRARY_PATH)

LD_LIBRARY_PATH := $(foreach path,$(BFM_LIBS),$(dir $(path)):)$(LD_LIBRARY_PATH)
export LD_LIBRARY_PATH

RULES := 1

.phony: all build run target_build
.phony: pre-run post-run

all :
	echo "Error: Specify target of build or run
	exit 1
	
# Build Targets
# - Pre-Compile
# - Compile
# - Post-Compile
# - Pre-Link
# - Link
# - Post-Link

#.phony: build-pre-compile build-compile build-post-compile
#.phony: build-pre-link build-link build-post-link

build-pre-compile : $(BUILD_PRECOMPILE_TARGETS)
	@touch $@

build-compile : build-pre-compile $(BUILD_COMPILE_TARGETS)
	@touch $@
	
$(BUILD_COMPILE_TARGETS) : build-pre-compile

build-post-compile : build-compile $(BUILD_POSTCOMPILE_TARGETS)
	@touch $@
	
$(BUILD_POSTCOMPILE_TARGETS) : build-compile

build-pre-link : build-post-compile $(BUILD_PRELINK_TARGETS)
	@touch $@
	
$(BUILD_PRELINK_TARGETS) : build-post-compile

build-link : build-pre-link $(BUILD_LINK_TARGETS)
	@touch $@
	
$(BUILD_LINK_TARGETS) : build-pre-link

build-post-link : build-link $(BUILD_POSTLINK_TARGETS)
	@touch $@
	
$(BUILD_POSTLINK_TARGETS) : build-link
	
# build : $(BUILD_TARGETS)
build : build-post-link
	@echo "SIMSCRIPTS_TOOLS: $(SIMSCRIPTS_TOOLS)"
	@echo "SIMSCRIPTS_PLUSARGS_TOOLS: $(SIMSCRIPTS_PLUSARGS_TOOLS)"
	@echo "PLUSARGS: $(sort $(PLUSARGS))"
	@echo "INFACT_IMPORT_TARGETS: $(INFACT_IMPORT_TARGETS)"
	@echo "build-pre-compile: $(BUILD_PRECOMPILE_TARGETS)"
	@echo "build-compile: $(BUILD_COMPILE_TARGETS)"
	@echo "build-post-compile: $(BUILD_POSTCOMPILE_TARGETS)"
	@echo "build-pre-link: $(BUILD_PRELINK_TARGETS)"
	@echo "build-link: $(BUILD_LINK_TARGETS)"
	@echo "build-post-link: $(BUILD_POSTLINK_TARGETS)"
	@touch $@


run : $(RUN_TARGETS)

pre-run: init-tools $(PRE_RUN_TARGETS)

post-run: $(POST_RUN_TARGETS)

init-tools:
	@echo "== Simulator: $(SIM) == "
	@echo "== Enabled Tools =="
	@for tool in $(SIMSCRIPTS_TOOLS); do \
		echo "  - $${tool}"; \
	done

missing_sim_mk :
	@echo "Error: Failed to find makefile for sim $(SIM) in \$$(SIMSCRIPTS_DIR)/mkfiles/sim_mk and \$$(SIMSCRIPTS_DIR)/../mkfiles"
	@exit 1

include $(COMMON_SIM_MK_DIR)/common_rules.mk
include $(MK_INCLUDES)



	
