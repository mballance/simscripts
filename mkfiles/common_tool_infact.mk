#********************************************************************
#* common_tool_infact.mk
#*
#* Variables
#* - INFACT_SRC_PROJECTS   - list of source projects to be build
#* - INFACT_IMPORT_TARGETS - 
#* - INFACT_INI_FILES      - .ini files to add 
#*
#* Plusargs
#* +tool.infact.ini=<path>
#********************************************************************
ifneq (1,$(RULES))

PRE_RUN_TARGETS += start_sdm

POST_RUN_TARGETS += stop_sdm

# Ensure 
RUN_ARGS += +infact=$(BUILD_DIR_A)/infactsdm_info.ini


# BUILD_PRECOMPILE_TARGETS += $(foreach 

else

start_sdm :
	@echo "NOTE: Starting inFact SDM"
	nohup infactsdm start -clean -nobackground \
	  < /dev/null > infactsdm.out 2>&1 &
	cnt=0; while test ! -f infactsdm_info.ini && test $$cnt -lt 10; do \
		sleep 1; \
		cnt=`expr $$cnt + 1`; \
	done
	cat infactsdm_info.ini

stop_sdm :
	@echo "NOTE: Stopping inFact SDM"
	infactsdm status -summary 2>&1 | tee infactsdm.status
	infactsdm stop

endif
