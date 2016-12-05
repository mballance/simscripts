
ifneq (1,$(RULES))

PRE_RUN_TARGETS += start_sdm

POST_RUN_TARGETS += stop_sdm

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
