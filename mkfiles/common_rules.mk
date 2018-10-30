
#%.o : %.cpp
#	$(Q)if test ! -d `dirname $@`; then mkdir -p `dirname $@`; fi
#	$(Q)$(CXX) -c -o $@ $(CXXFLAGS) $^
#
#%.o : %.cc
#	$(Q)if test ! -d `dirname $@`; then mkdir -p `dirname $@`; fi
#	$(Q)$(CXX) -c -o $@ $(CXXFLAGS) $^
#	
#%.o : %.c
#	$(Q)if test ! -d `dirname $@`; then mkdir -p `dirname $@`; fi
#	$(Q)$(CC) -c -o $@ $(CFLAGS) $^

