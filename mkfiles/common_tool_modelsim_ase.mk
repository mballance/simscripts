#****************************************************************************
#* common_tool_modelsim.ase.mk
#*
#* Customizations to run the Altera Starter Edition of Modelsim
#*
#****************************************************************************

ifneq (1,$(RULES))

BUILD_PRECOMPILE_TARGETS += modelsim_ase_uvm
QUESTA_LIBS += mtiUvm
QUESTA_ENABLE_VOPT=false

VLOG_FLAGS += +incdir+$(QUESTA_HOME)/verilog_src/uvm-1.2/src
VLOG_FLAGS += -suppress 2186 +define+UVM_OBJECT_DO_NOT_NEED_CONSTRUCTOR
VSIM_FLAGS += -suppress 8785

else # Rules

modelsim_ase_uvm : 
	$(Q)echo "QUESTA_HOME=$(QUESTA_HOME)"
	$(Q)vlib mtiUvm
	$(Q)vmap mtiUvm $(BUILD_DIR_A)/mtiUvm
	$(Q)vlog -sv $(VLOG_FLAGS) -work mtiUvm -ccflags "-DQUESTA" \
		$(QUESTA_HOME)/verilog_src/uvm-1.2/src/uvm_pkg.sv \
		$(QUESTA_HOME)/verilog_src/uvm-1.2/src/dpi/uvm_dpi.cc

endif
