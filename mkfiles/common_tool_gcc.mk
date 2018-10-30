#****************************************************************************
#* common_tool_gcc.mk
#*
#* Provides defines for working with GCC
#*
#* Configuration variables:
#* - GCC_ARCH - specifies the GCC architecture (eg riscv64-unknown-elf)
#*
#****************************************************************************
ifneq (1,$(RULES))


ifneq (,$(GCC_ARCH))
CC:=$(GCC_ARCH)-gcc
CXX:=$(GCC_ARCH)-g++
OBJCOPY:=$(GCC_ARCH)-objcopy
LD:=$(GCC_ARCH)-ld
NM:=$(GCC_ARCH)-nm
AS:=$(CC)
endif


CFLAGS += $(foreach d,$(SRC_DIRS),-I$(d))
CXXFLAGS += $(foreach d,$(SRC_DIRS),-I$(d))
ASFLAGS += $(foreach d,$(SRC_DIRS),-I$(d))

#CFLAGS += -Wno-error=format= -Wno-error=format-extra-args
#CXXFLAGS += -Wno-error=format= -Wno-error=format-extra-args

LD_REL = $(LD) $(LDFLAGS) -r

else # Rules

vpath %.cpp $(SRC_DIRS)
vpath %.cc $(SRC_DIRS)
vpath %.S $(SRC_DIRS)
vpath %.c $(SRC_DIRS)

%.o : %.S
	$(Q)if test ! -d `dirname $@`; then mkdir -p `dirname $@`; fi
	$(Q)$(AS) -c $(ASFLAGS) -o $@ $^
	
%.o : %.c
	$(Q)if test ! -d `dirname $@`; then mkdir -p `dirname $@`; fi
	$(Q)$(CC) -c $(CFLAGS) -o $@ $(filter %.c,$^)
	
%.o : %.cpp
	$(Q)if test ! -d `dirname $@`; then mkdir -p `dirname $@`; fi
	$(Q)echo "Deps: $^"
	$(Q)$(CXX) -c $(CXXFLAGS) -o $@ $(filter %.cpp,$^)

endif
