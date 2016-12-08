#********************************************************************
#* common_tool_infact.mk
#*
#* Variables
#* - INFACT_SRC_PROJECTS      - list of source projects to be build
#* - INFACT_IMPORT_TARGETS    - 
#* - INFACT_INI_FILES         - .ini files to add 
#* - INFACT_BUILDDIR_PROJECTS - Projects that will exist in the build directory
#*
#* Plusargs
#* +tool.infact.ini=<path>
#* +tool.infact.sdm.monitor  -- launch the SDM monitor GUI
#********************************************************************
ifneq (1,$(RULES))

SIMSCRIPTS_TOOL_OPTIONS += "+tool.infact.ini=<path>"

PRE_RUN_TARGETS += start_sdm

POST_RUN_TARGETS += stop_sdm

INFACT_INI_FILES += $(foreach proj,$(INFACT_BUILDDIR_PROJECTS),$(BUILD_DIR_A)/$(proj)/$(notdir $(proj)).ini)

# Ensure 
RUN_ARGS += $(foreach ini,$(INFACT_INI_FILES),+infact=$(ini))
RUN_ARGS += +infact=$(BUILD_DIR_A)/infactsdm_info.ini

BUILD_POSTCOMPILE_TARGETS += $(INFACT_IMPORT_TARGETS)
BUILD_PRELINK_TARGETS += $(INFACT_RECOMPILE_TARGETS)

# BUILD_PRECOMPILE_TARGETS += $(foreach 
LAUNCH_SDM_MONITOR:=$(call have_plusarg,tool.infact.sdm.monitor,$(PLUSARGS))

else

start_sdm :
	@echo "NOTE: Starting inFact SDM"
	nohup infactsdm start -clean -nobackground \
	  < /dev/null > infactsdm.out 2>&1 &
	cnt=0; while test ! -f infactsdm_info.ini && test $$cnt -lt 10; do \
		sleep 1; \
		cnt=`expr $$cnt + 1`; \
	done
	if test "x$(LAUNCH_SDM_MONITOR)" = "xtrue"; then \
		nohup infactsdm monitor < /dev/null > infactsdm_monitor.out 2>&1 & \
	fi
	cat infactsdm_info.ini

stop_sdm :
	@echo "NOTE: Stopping inFact SDM"
	infactsdm status -summary 2>&1 | tee infactsdm.status
	infactsdm stop
	
mk_infact_incdir :
	@echo "" > infact_incdir.f
	@for proj in $(INFACT_BUILDDIR_PROJECTS); do \
		for dir in $${proj}/*; do \
			if test -f $${dir}/*.tmd; then \
				echo "+incdir+./$${dir}" >> infact_incdir.f; \
			fi \
		done \
	done
	

endif
