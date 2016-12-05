
ifneq (1,$(RULES))

PRE_RUN_TARGETS += start_sdm

POST_RUN_TARGETS += stop_sdm

else

start_sdm :
	infactsdm start

stop_sdm :
	infactsdm status -summary 2>&1 | tee infactsdm.status
	infactsdm stop

endif
