#********************************************************************
#* common_tool_codelink.mk
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
#* +tool.infact.sdm.monitor  -- launch the SDM monitor GUI
#********************************************************************
ifneq (1,$(RULES))

VLOG_DEFINES += CODELINK

else


endif
