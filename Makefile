# Makefile for entire install tree, for RPM packages.

.PHONY: core mta store ldap snmp 

# BASE VARIABLES

BUILD_ROOT	:= $(shell pwd)

DEFS_DIR := $(BUILD_ROOT)/defs

include $(DEFS_DIR)/globals.def

include $(DEFS_DIR)/devglobals.def

include $(DEFS_DIR)/paths.def

# 3rd PARTY INCLUDES

THIRD_PARTY	:= $(BUILD_ROOT)/../ThirdParty

include $(DEFS_DIR)/$(BUILD_PLATFORM).def

include $(DEFS_DIR)/destination.def

# COMPONENTS

include $(DEFS_DIR)/components.def

# PACKAGE TARGETS

all: rpms zcs-$(RELEASE).tgz

include $(DEFS_DIR)/releasetargets.def

include $(DEFS_DIR)/coretargets.def

include $(DEFS_DIR)/ldaptargets.def

include $(DEFS_DIR)/mtatargets.def

include $(DEFS_DIR)/loggertargets.def

include $(DEFS_DIR)/storetargets.def

include $(DEFS_DIR)/webapptargets.def

include $(DEFS_DIR)/jartargets.def

include $(DEFS_DIR)/snmptargets.def

include $(DEFS_DIR)/sourcetargets.def

include $(DEFS_DIR)/devtargets.def

include $(DEFS_DIR)/clean.def

include $(DEFS_DIR)/devclean.def

# DIRS

$(RPM_DIR):
	mkdir -p $(RPM_DIR)

perllibsbuild: 
	make -C $(PERL_LIB_SOURCE)

# MISC

showtag:
	echo $(RELEASE)
	echo $(TAG)

force: ;
