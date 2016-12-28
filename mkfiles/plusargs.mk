

comma:= ,

define get_plusarg
$(sort $(patsubst +$(1)=%,%,$(filter +$(1)=%,$(2))))
endef

define have_plusarg
$(word 1,$(subst +$(1),true,$(filter +$(1),$(2))))
endef

#PLUSARGS=$(shell perl scripts/argfile.pl ../units/units.f)

#define extract
#$(patsubst +$(1)=%,%,$(filter +$(1)=%,$(2)))
#endef

#define extract_incdirs
#$(patsubst +incdir+%,%,$(filter +incdir+%,$(1)))
#endef


#all :
#	@echo "$(filter +testname=%,$(PLUSARGS))"
#	@echo "$(filter +value,$(PLUSARGS))"
#	@echo "$(patsubst +sw_image=%,%,$(filter +sw_image=%,$(PLUSARGS)))"
#	@echo "INC: $(call extract_incdirs,$(PLUSARGS))"
#	@echo "plusargs: $(PLUSARGS)"



# perl scripts/argfile.pl -m -print-paths ../units/units.f
