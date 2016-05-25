
TOP_MODULE ?= $(TB)
DEBUG ?= false
TIMEOUT ?= 1ms

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
include $(MK_INCLUDES)

ifeq (true,$(DYNLINK))
DPIEXT=.so
else
DPIEXT=.o
endif

#ifeq (Cygwin,$(OS))
#BUILD_DIR := $(shell cygpath -w $(BUILD_DIR))
#SIM_DIR := $(shell cygpath -w $(SIM_DIR))
#endif

CXXFLAGS += $(foreach dir, $(SRC_DIRS), -I$(dir))

vpath %.cpp $(SRC_DIRS)
vpath %.S $(SRC_DIRS)
vpath %.c $(SRC_DIRS)

	
BUILD_TARGETS += $(LIB_TARGETS) $(EXE_TARGETS)
	

include $(COMMON_SIM_MK_DIR)/sim_mk/common_sim_$(SIM).mk	

post_build : $(POSTBUILD_TARGETS)
	echo "SIM=$(SIM)"
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

all :
	echo "Error: Specify target of build or run
	exit 1
	
build : $(BUILD_TARGETS)

include $(COMMON_SIM_MK_DIR)/common_rules.mk
include $(COMMON_SIM_MK_DIR)/sim_mk/common_sim_$(SIM).mk	
include $(MK_INCLUDES)



	
