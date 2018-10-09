#********************************************************************
#* common_tool_infact.mk
#*
#* Variables
#* - INFACT_SRC_PROJECTS      - list of source projects to be build
#* - INFACT_IMPORT_TARGETS    - 
#* - INFACT_INI_FILES         - .ini files to add to the commandline
#* - INFACT_IMPORT_TARGETS    - Make targets that run TBI
#* - INFACT_SRC_PROJECTS      - List of project source directories to
#*                              copy and generate
#* - INFACT_BUILDDIR_PROJECTS - Projects that will exist in the build directory
#*
#* Plusargs
#* +tool.infact.ini=<path>
#* +tool.infact.sdm.start    -- 
#* +tool.infact.sdm.monitor  -- launch the SDM monitor GUI
#********************************************************************
ifneq (1,$(RULES))

HAVE_START_SDM:=$(call have_plusarg,tool.infact.sdm,$(PLUSARGS))
HAVE_START_SDM_MONITOR:=$(call have_plusarg,tool.infact.sdm.monitor,$(PLUSARGS))

ifeq (true,$(HAVE_START_SDM))
PRE_RUN_TARGETS += start_sdm

POST_RUN_TARGETS += stop_sdm

RUN_ARGS += +infact=$(BUILD_DIR_A)/infactsdm_info.ini
endif

INFACT_INI_FILES += $(foreach proj,$(INFACT_BUILDDIR_PROJECTS),$(BUILD_DIR_A)/$(proj)/$(notdir $(proj)).ini)

# Add source projects that will be copied to the build directory to the list of projects there
INFACT_BUILDDIR_PROJECTS += $(foreach proj,$(INFACT_SRC_PROJECTS),$(notdir $(proj)))

# Ensure 
RUN_ARGS += $(foreach ini,$(INFACT_INI_FILES),+infact=$(ini))

BUILD_PRECOMPILE_TARGETS += infact-build-nonimport-projects
BUILD_POSTCOMPILE_TARGETS += $(INFACT_IMPORT_TARGETS) 
BUILD_PRELINK_TARGETS += $(INFACT_RECOMPILE_TARGETS)

SIMSCRIPTS_TOOL_INFO_TARGETS += infact-tool-info
SIMSCRIPTS_TOOL_OPTIONS_TARGETS += infact-tool-options 

VLOG_DEFINES += INFACT

# SRC_DIRS += $(foreach proj,$(INFACT_SRC_PROJECTS),$(notdir $(INFACT_BUILDDIR_PROJECTS)/

else

infact-tool-info :
	@echo "+tool.infact - Provides support for Questa inFact"
	
infact-tool-options :
	@echo "Tool: infact"
	@echo "  +tool.infact.ini=<path>    - Specifies a runtime .ini file"
	@echo "  +tool.infact.sdm.monitor   - Launches the SDM monitor GUI"

infact-build-nonimport-projects : $(INFACT_IMPORT_TARGETS)
	@if test "x$(INFACT_SRC_PROJECTS)" != "x"; then \
		for proj in $(INFACT_SRC_PROJECTS); do \
			proj_name=`basename $$proj`; \
			rm -rf $$proj_name ; \
			cp -r $$proj . ; \
			rm -f `find $$proj_name -name '*.cpp' ; find $$proj_name -name '*.h'`; \
			echo "Generating project $$proj_name"; \
			infact cmd genproject -rebuild $$proj_name ; \
			touch $${proj_name}.d ; \
		done \
	fi

start_sdm :
	@echo "NOTE: Starting inFact SDM"
	nohup infactsdm start -clean -nobackground -timeout 1 \
	  < /dev/null > infactsdm.out 2>&1 &
	cnt=0; while test ! -f infactsdm_info.ini && test $$cnt -lt 10; do \
		sleep 1; \
		cnt=`expr $$cnt + 1`; \
	done
	if test "x$(HAVE_START_SDM_MONITOR)" = "xtrue"; then \
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
		echo "proj=$$proj"; \
		for dir in $${proj}/*; do \
			echo "dir=$$dir"; \
			if test -f $${dir}/*.tmd; then \
				echo "+incdir+./$${dir}" >> infact_incdir.f; \
			fi \
		done \
	done
	

endif
