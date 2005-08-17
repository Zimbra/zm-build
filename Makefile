# Makefile for entire install tree, for RPM packages.

.PHONY: perllibs mta mail

BUILD_ROOT	:= $(shell pwd)

MAJOR	:= 2
MINOR	:= 0
BUILD_PLATFORM := $(shell sh $(BUILD_ROOT)/rpmconf/get_plat_tag.sh)

USER := $(shell id -un)

DEV_INSTALL_ROOT := /opt/liquid

ifeq ($(TAG), )
	TAG := HEAD
else
	TAG	:= $(shell echo $$TAG)
endif

HOST	:= $(shell hostname)
DATE	:= $(shell date +%Y%m%d%H%M%S)
ifeq ($(RELEASE), )
	RELEASE	:= $(DATE)_$(TAG)
else
	 RELEASE := $(RELEASE)_$(TAG)
	 DATE	:= $(RELEASE)
endif

DEV_CLEAN_TARGETS := \
	$(DEV_INSTALL_ROOT)/$(LDAP_DIR) \
	$(DEV_INSTALL_ROOT)/$(MYSQL_DIR) \
	$(DEV_INSTALL_ROOT)/$(TOMCAT_DIR) \

CLEAN_TARGETS	=	\
		$(QA_DEST_ROOT) \
		$(MTA_DEST_ROOT) \
		$(DEST_ROOT) \
		$(LDAP_DEST_ROOT) \
		$(SNMP_DEST_ROOT) \
		$(CORE_DEST_ROOT) \
		$(TMPDIR) \
		liquidmail \
		liquidmail-2*.tgz \
		liquid.rpmrc \
		liquidcore.spec \
		liquidsnmp.spec \
		liquid.spec \
		liquidmta.spec \
		liquidldap.spec \
		i386

PERL 		:= $(shell which perl)

ANT		:= $(shell which ant)

THIRD_PARTY	:= $(BUILD_ROOT)/../ThirdParty

QA_DIR	:= $(BUILD_ROOT)/../LiquidQA

BACKUP_DIR  := $(BUILD_ROOT)/../LiquidBackup
CONVERT_DIR	:= $(BUILD_ROOT)/../LiquidConvertd
SERVICE_DIR	:= $(BUILD_ROOT)/../LiquidArchive
CONSOLE_DIR	:= $(BUILD_ROOT)/../LiquidConsole

LDAP_VERSION	:= 2.2.26
LDAP_DIR	:= openldap-$(LDAP_VERSION)
LDAP_SOURCE	:= $(THIRD_PARTY)/openldap/builds/$(LDAP_DIR)

BDB_VERSION	:= 4.2.52.2
BDB_DIR		:= sleepycat-$(BDB_VERSION)
BDB_SOURCE	:= $(THIRD_PARTY)/sleepycat/builds/$(BDB_DIR)

TOMCAT_VERSION	:= 5.5.7
TOMCAT_DIR	:= jakarta-tomcat-$(TOMCAT_VERSION)
TOMCAT_SOURCE 	:= $(THIRD_PARTY)/jakarta-tomcat/$(TOMCAT_DIR)

MYSQL_VERSION	:= standard-4.1.10a-pc-linux-gnu-i686
MYSQL_DIR	:= mysql-$(MYSQL_VERSION)
MYSQL_SOURCE 	:= $(THIRD_PARTY)/mysql/$(MYSQL_DIR)

POSTFIX_VERSION := 2.2.3
POSTFIX_DIR	:= postfix-$(POSTFIX_VERSION)
POSTFIX_SOURCE	:= $(THIRD_PARTY)/PostFix/PostFix-$(POSTFIX_VERSION)/builds/$(POSTFIX_DIR)

RRD_VERSION	:= 1.0.49
RRD_DIR 	:= rrdtool-$(RRD_VERSION)
RRD_SOURCE	:= $(THIRD_PARTY)/rrdtool/$(RRD_DIR)

MRTG_VERSION	:= 2.10.15
MRTG_DIR 	:= mrtg-$(MRTG_VERSION)
MRTG_SOURCE	:= $(THIRD_PARTY)/mrtg/builds/$(MRTG_DIR)

SNMP_VERSION := 5.1.2
SNMP_DIR	:= snmp-$(SNMP_VERSION)
SNMP_SOURCE	:= $(THIRD_PARTY)/snmp/$(SNMP_DIR)

JAVA_VERSION	:= 1.5.0_04
JAVA_FILE	:= jdk
JAVA_DIR	:= java
JAVA_SOURCE	:= $(THIRD_PARTY)/$(JAVA_DIR)/$(JAVA_FILE)$(JAVA_VERSION)

CLAMAV_VERSION := 0.85.1
CLAMAV_DIR :=  clamav
CLAMAV_SOURCE := $(THIRD_PARTY)/$(CLAMAV_DIR)/builds/clamav-$(CLAMAV_VERSION)

AMAVISD_VERSION := 2.3.1
AMAVISD_DIR :=  amavisd
AMAVISD_SOURCE := $(THIRD_PARTY)/$(AMAVISD_DIR)/amavisd-new-$(AMAVISD_VERSION)

SASL_VERSION := 2.1.21.LIQUID
SASL_DIR := cyrus-sasl
SASL_SOURCE := $(THIRD_PARTY)/$(SASL_DIR)/builds/$(SASL_DIR)-$(SASL_VERSION)

VERITY_SOURCE := $(THIRD_PARTY)/verity/linux

MTA_DEST_ROOT		:= $(BUILD_ROOT)/mtabuild
MTA_DEST_DIR		:= $(MTA_DEST_ROOT)/opt/liquid

LDAP_DEST_ROOT		:= $(BUILD_ROOT)/ldapbuild
LDAP_DEST_DIR		:= $(LDAP_DEST_ROOT)/opt/liquid

CORE_DEST_ROOT		:= $(BUILD_ROOT)/corebuild
CORE_DEST_DIR		:= $(CORE_DEST_ROOT)/opt/liquid

QA_DEST_ROOT		:= $(BUILD_ROOT)/qabuild
QA_DEST_DIR			:= $(QA_DEST_ROOT)/opt/liquid/qa

SNMP_DEST_ROOT		:= $(BUILD_ROOT)/snmpbuild
SNMP_DEST_DIR		:= $(SNMP_DEST_ROOT)/opt/liquid

DEST_ROOT		:= $(BUILD_ROOT)/build
DEST_DIR		:= $(DEST_ROOT)/opt/liquid
RPM_DIR			:= $(BUILD_ROOT)/i386
WEBAPP_DIR		:= $(DEST_ROOT)/opt/liquid/$(TOMCAT_DIR)/webapps

RPM_CONF_DIR		:= $(BUILD_ROOT)/rpmconf
LIQUIDMON_DIR		:= $(BUILD_ROOT)/liquidmon
LIQUID_BIN_DIR		:= $(BUILD_ROOT)/bin

PERL_LIB_SOURCE	:= $(THIRD_PARTY)/Perl

# Order is important here
DBD_PERL_LIBS 	:= \
	DBD-mysql-2.9005_3 \

PERL_LIBS 	:= \
	DBI-1.47 \
	HTML-Tagset-3.03 \
	HTML-Parser-3.36 \
	URI-1.31 \
	libwww-perl-5.800 \
	HTTP-Parser-0.02 \
	IO-stringy-1.220 \
	MIME-Lite-3.01 \
	MailTools-1.62 \
	MIME-tools-5.411 \
	SOAP-Lite-0.55 \
	XML-Parser-2.34 \
	Net-Telnet-3.03 \
	Device-SerialPort-1.000002 \
	Date-Calc-5.4 \
	DateManip-5.42a \
	TimeDate-1.16 \
	Time-HiRes-1.65 \
	swatch-3.1.1 \
	perl-ldap-0.3202 \
	Convert-ASN1-0.18 \
	Crypt-SSLeay-0.51 \
	Net-Server-0.85 \
	Net-Server-0.87 \
	Unix-Syslog-0.99 \
	Compress-Zlib-1.34 \
	BerkeleyDB-0.26 \
	Digest-SHA1-2.10 \
	Convert-TNEF-0.17 \
	Convert-UUlib-1.051 \
	Archive-Tar-1.24 \
	Net-IP-1.23 \
	Net-DNS-0.51 \
	Archive-Zip-1.14

SA_PERL_LIBS = \
	Mail-SpamAssassin-3.0.4

WEBAPPS	:= \
	$(WEBAPP_DIR)/service.war \
	$(WEBAPP_DIR)/liquidAdmin.war \
	$(WEBAPP_DIR)/liquid.war 

QA_COMPONENTS	:= \
	$(QA_DEST_DIR) \
	$(QA_DEST_DIR)/scripts \
	$(QA_DEST_DIR)/TestMailRaw 

CORE_COMPONENTS	:= \
	$(CORE_DEST_DIR) \
	$(CORE_DEST_DIR)/db \
	$(CORE_DEST_DIR)/lib \
	$(CORE_DEST_DIR)/bin \
	$(CORE_DEST_DIR)/liquidmon \
	$(CORE_DEST_DIR)/$(JAVA_FILE)$(JAVA_VERSION) \
	$(CORE_DEST_DIR)/conf

MTA_COMPONENTS	:= \
	$(MTA_DEST_DIR)/$(POSTFIX_DIR) \
	$(MTA_DEST_DIR)/$(BDB_DIR) \
	$(MTA_DEST_DIR)/$(AMAVISD_DIR) \
	$(MTA_DEST_DIR)/$(CLAMAV_DIR)  \
	$(MTA_DEST_DIR)/$(SASL_DIR)

MAIL_COMPONENTS := \
	$(DEST_DIR)/$(TOMCAT_DIR) \
	$(DEST_DIR)/$(TOMCAT_DIR)/common/lib/liquidos.jar \
	$(DEST_DIR)/$(TOMCAT_DIR)/common/lib/KeyView.jar \
	$(DEST_DIR)/$(TOMCAT_DIR)/common/lib/mail.jar \
	$(DEST_DIR)/$(TOMCAT_DIR)/common/endorsed/liquidcharset.jar \
	$(DEST_DIR)/$(TOMCAT_DIR)/common/lib/activation.jar \
	$(DEST_DIR)/$(MYSQL_DIR) \
	$(DEST_DIR)/verity \
	$(WEBAPPS) \
	$(DEST_DIR)/libexec 

LDAP_COMPONENTS := \
	$(LDAP_DEST_DIR)/$(LDAP_DIR)  

SNMP_COMPONENTS := \
	$(SNMP_DEST_DIR)/$(SNMP_DIR) 

PROFILE_SOURCE		:= $(RPM_CONF_DIR)/liquid.bash_profile
PROFILE_DEST		:= .bash_profile
ENV_FILE_SOURCE		:= $(RPM_CONF_DIR)/liquid.bashrc
ENV_FILE_DEST		:= .bashrc
EXRC_SOURCE			:= $(RPM_CONF_DIR)/liquid.exrc
EXRC_DEST			:= .exrc

PERL_MM_USE_DEFAULT	:= 1
export PERL_MM_USE_DEFAULT

JAVA_HOME		:= /usr/local/java
export JAVA_HOME

TMPDIR	:= tmp

all: rpms qa liquidmail-$(RELEASE).tgz

showtag:
	echo $(RELEASE)
	echo $(TAG)

qa: 
	cd $(QA_DIR);  CLASSPATH=$(SERVICE_DIR)/build/classes $(ANT) jar; 

liquidmail-$(RELEASE).tgz: rpms
	mkdir -p liquidmail/packages
	mkdir -p liquidmail/bin
	mkdir -p liquidmail/data
	cp -f $(SERVICE_DIR)/build/versions-init.sql liquidmail/data
	cp $(LDAP_DEST_ROOT)/opt/liquid/$(LDAP_DIR)/bin/ldapsearch liquidmail/bin
	cp $(RPM_CONF_DIR)/install.sh liquidmail
	chmod 755 liquidmail/install.sh
	cp $(RPM_DIR)/*rpm liquidmail/packages
	rm -f liquidmail/packages/liquid-qatest*
	tar czf liquidmail-$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)_$(RELEASE).tgz liquidmail
	cp liquidmail-$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)_$(RELEASE).tgz $(RPM_DIR)
	(cd $(RPM_DIR); ln -s liquidmail-$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)_$(RELEASE).tgz liquidmail.tgz)
	@echo "*** BUILD COMPLETED ***"

rpms: core mta mail ldap snmp qatest
	@echo "*** Creating RPMS in $(RPM_DIR)"

qatest: $(RPM_DIR) qa_stage
	cat $(RPM_CONF_DIR)/liquidqa.spec | sed -e 's/@@VERSION@@/$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)/' \
		| sed -e 's/@@RELEASE@@/$(RELEASE)/' > $(BUILD_ROOT)/liquidqa.spec
	(cd $(QA_DEST_ROOT); find opt -type f -o -type l | sed -e 's|^|%attr(-, liquid, liquid) /|' >> \
		$(BUILD_ROOT)/liquidqa.spec; \
		rpmbuild  --target i386 --quiet --define '_rpmdir $(BUILD_ROOT)' \
		--buildroot=$(QA_DEST_ROOT) -bb $(BUILD_ROOT)/liquidqa.spec )

qa_stage: $(QA_COMPONENTS)

core: $(RPM_DIR) core_stage
	cat $(RPM_CONF_DIR)/liquidcore.spec | sed -e 's/@@VERSION@@/$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)/' \
		| sed -e 's/@@RELEASE@@/$(RELEASE)/' > $(BUILD_ROOT)/liquidcore.spec
	(cd $(CORE_DEST_ROOT); find opt -type f -o -type l -maxdepth 2 \
		| sed -e 's|^|%attr(-, liquid, liquid) /|' >> \
		$(BUILD_ROOT)/liquidcore.spec )
	echo "%attr(755, liquid, liquid) /opt/liquid/bin" >> \
		$(BUILD_ROOT)/liquidcore.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/conf" >> \
		$(BUILD_ROOT)/liquidcore.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/db" >> \
		$(BUILD_ROOT)/liquidcore.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/jdk1.5.0_04" >> \
		$(BUILD_ROOT)/liquidcore.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/lib" >> \
		$(BUILD_ROOT)/liquidcore.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/liquidmon" >> \
		$(BUILD_ROOT)/liquidcore.spec
	(cd $(CORE_DEST_ROOT);\
		rpmbuild  --target i386 --quiet --define '_rpmdir $(BUILD_ROOT)' \
		--buildroot=$(CORE_DEST_ROOT) -bb $(BUILD_ROOT)/liquidcore.spec )

core_stage: $(CORE_COMPONENTS)

mta: $(RPM_DIR) mta_stage
	cat $(RPM_CONF_DIR)/liquidmta.spec | sed -e 's/@@VERSION@@/$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)/' \
		| sed -e 's/@@RELEASE@@/$(RELEASE)/' > $(BUILD_ROOT)/liquidmta.spec
	(cd $(MTA_DEST_ROOT); find opt -type f -o -type l -maxdepth 2 \
		| sed -e 's|^|%attr(-, liquid, liquid) /|' >> \
		$(BUILD_ROOT)/liquidmta.spec )
	echo "%attr(-, liquid, liquid) /opt/liquid/amavisd" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(555, liquid, liquid) /opt/liquid/clamav-0.85.1/bin" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(755, liquid, liquid) /opt/liquid/clamav-0.85.1/db" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/clamav-0.85.1/etc/" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/clamav-0.85.1/include" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/clamav-0.85.1/lib" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/clamav-0.85.1/man" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(555, liquid, liquid) /opt/liquid/clamav-0.85.1/sbin" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/clamav-0.85.1/share" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/postfix-2.2.3" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/sleepycat-4.2.52.2" >> \
		$(BUILD_ROOT)/liquidmta.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/cyrus-sasl-2.1.21.LIQUID" >> \
		$(BUILD_ROOT)/liquidmta.spec
	(cd $(MTA_DEST_ROOT); \
		rpmbuild  --target i386 --quiet --define '_rpmdir $(BUILD_ROOT)' \
		--buildroot=$(MTA_DEST_ROOT) -bb $(BUILD_ROOT)/liquidmta.spec )

mta_stage: $(MTA_COMPONENTS)

mail: $(RPM_DIR) mail_stage
	cat $(RPM_CONF_DIR)/liquid.spec | sed -e 's/@@VERSION@@/$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)/' \
		| sed -e 's/@@RELEASE@@/$(RELEASE)/' > $(BUILD_ROOT)/liquid.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/jakarta-tomcat-5.5.7" >> \
		$(BUILD_ROOT)/liquid.spec
	echo "%attr(755, liquid, liquid) /opt/liquid/libexec" >> \
		$(BUILD_ROOT)/liquid.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/mysql-standard-4.1.10a-pc-linux-gnu-i686" >> \
		$(BUILD_ROOT)/liquid.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/verity/conf" >> \
		$(BUILD_ROOT)/liquid.spec
	echo "%attr(755, liquid, liquid) /opt/liquid/verity/ExportSDK/bin" >> \
		$(BUILD_ROOT)/liquid.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/verity/ExportSDK/ini" >> \
		$(BUILD_ROOT)/liquid.spec
	echo "%attr(755, liquid, liquid) /opt/liquid/verity/FilterSDK/bin" >> \
		$(BUILD_ROOT)/liquid.spec
	(cd $(DEST_ROOT); \
		rpmbuild  --target i386 --quiet --define '_rpmdir $(BUILD_ROOT)' \
		--buildroot=$(DEST_ROOT) -bb $(BUILD_ROOT)/liquid.spec )

mail_stage: $(MAIL_COMPONENTS)

snmp: $(RPM_DIR) snmp_stage
	cat $(RPM_CONF_DIR)/liquidsnmp.spec | sed -e 's/@@VERSION@@/$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)/' \
		| sed -e 's/@@RELEASE@@/$(RELEASE)/' > $(BUILD_ROOT)/liquidsnmp.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/snmp-5.1.2" >> \
		$(BUILD_ROOT)/liquidsnmp.spec
	(cd $(SNMP_DEST_ROOT); \
		rpmbuild  --target i386 --quiet --define '_rpmdir $(BUILD_ROOT)' \
		--buildroot=$(SNMP_DEST_ROOT) -bb $(BUILD_ROOT)/liquidsnmp.spec )

snmp_stage: $(SNMP_COMPONENTS)

ldap: $(RPM_DIR) ldap_stage
	cat $(RPM_CONF_DIR)/liquidldap.spec | sed -e 's/@@VERSION@@/$(MAJOR).$(MINOR)_$(BUILD_PLATFORM)/' \
		| sed -e 's/@@RELEASE@@/$(RELEASE)/' > $(BUILD_ROOT)/liquidldap.spec
	echo "%attr(-, liquid, liquid) /opt/liquid/openldap-$(LDAP_VERSION)" >> \
		$(BUILD_ROOT)/liquidldap.spec
	(cd $(LDAP_DEST_ROOT); \
		rpmbuild  --target i386 --quiet --define '_rpmdir $(BUILD_ROOT)' \
		--buildroot=$(LDAP_DEST_ROOT) -bb $(BUILD_ROOT)/liquidldap.spec )

ldap_stage: $(LDAP_COMPONENTS)

tars: $(RPM_DIR) mta_stage mail_stage ldap_stage
		(cd $(MTA_DEST_ROOT); \
		tar czf ../i386/liquid-mta-$(MAJOR).$(MINOR)-$(RELEASE).tgz opt)
		(cd $(DEST_ROOT); \
		tar czf ../i386/liquid-store-$(MAJOR).$(MINOR)-$(RELEASE).tgz opt)
		(cd $(LDAP_DEST_ROOT); \
		tar czf ../i386/liquid-ldap-$(MAJOR).$(MINOR)-$(RELEASE).tgz opt)

$(RPM_DIR):
	mkdir -p $(RPM_DIR)

$(QA_DEST_DIR)/TestMailRaw:
	rm -rf $@
	cp -Rf $(SERVICE_DIR)/data/TestMailRaw $@

$(QA_DEST_DIR)/scripts:
	mkdir -p $@
	cp -f $(QA_DIR)/src/bin/runtests.sh $@
	cp -f $(QA_DIR)/src/bin/createUsers.sh $@
	cp -f $(QA_DIR)/src/bin/injectTestMail.sh $@

$(QA_DEST_DIR):
	mkdir -p $@

$(CORE_DEST_DIR):
	mkdir -p $@
	cp $(ENV_FILE_SOURCE) $(CORE_DEST_DIR)/$(ENV_FILE_DEST)
	cp $(PROFILE_SOURCE) $(CORE_DEST_DIR)/$(PROFILE_DEST)
	cp $(EXRC_SOURCE) $(CORE_DEST_DIR)/$(EXRC_DEST)

$(MTA_DEST_DIR):
	mkdir -p $@

$(DEST_DIR):
	mkdir -p $@

$(LDAP_DEST_DIR):
	mkdir -p $@

$(SNMP_DEST_DIR):
	mkdir -p $@

$(SNMP_DEST_DIR)/$(SNMP_DIR): $(SNMP_DEST_DIR)
	@echo "*** Creating SNMP"
	(cd $(SNMP_DEST_DIR); tar xzf $(SNMP_SOURCE).tar.gz;)
	cp $(RPM_CONF_DIR)/snmpd.conf.in $(SNMP_DEST_DIR)/$(SNMP_DIR)/share/snmp/snmpd.conf.in
	mkdir -p $(SNMP_DEST_DIR)/$(SNMP_DIR)/conf
	cp $(RPM_CONF_DIR)/snmp.conf $(SNMP_DEST_DIR)/$(SNMP_DIR)/conf/snmp.conf
	cp $(RPM_CONF_DIR)/snmp.conf $(SNMP_DEST_DIR)/$(SNMP_DIR)/share/snmp/snmp.conf
	cp $(RPM_CONF_DIR)/mibs/*mib $(SNMP_DEST_DIR)/$(SNMP_DIR)/share/snmp/mibs

$(CORE_DEST_DIR)/liquidmon: $(CORE_DEST_DIR) perllibs
	@echo "*** Creating liquidmon"
	mkdir -p $@
	cp -R $(LIQUIDMON_DIR)/lqmon $@
	chmod 755 $@/lqmon
	cp -R $(LIQUIDMON_DIR)/lqcontrol $@
	chmod 755 $@/lqcontrol
	cp -R $(RPM_CONF_DIR)/liquid.cf.in $@
	cp -R $(RPM_CONF_DIR)/liquidcore.cf $@
	cp -R $(RPM_CONF_DIR)/liquidmail.cf $@
	cp -R $(RPM_CONF_DIR)/liquidmta.cf $@
	cp -R $(RPM_CONF_DIR)/liquidldap.cf $@
	cp -R $(RPM_CONF_DIR)/liquidsnmp.cf $@
	mkdir -p $@/lib/liquidpm
	@cp $(wildcard $(BUILD_ROOT)/lib/liquidpm/*.pm) $@/lib/liquidpm
	mkdir -p $@/lib/liquidpm/SOAP
	@cp -f $(wildcard $(SERVICE_DIR)/src/perl/soap/*.pm) $@/lib/liquidpm/SOAP
	(cd $(CORE_DEST_DIR)/liquidmon; tar xzf $(MRTG_SOURCE).tgz)
	mkdir -p $(CORE_DEST_DIR)/liquidmon/mrtg/work
	mkdir -p $(CORE_DEST_DIR)/liquidmon/mrtg/conf
	cp $(RPM_CONF_DIR)/mrtg.cfg $(CORE_DEST_DIR)/liquidmon/mrtg/conf
	cp $(RPM_CONF_DIR)/crontab $(CORE_DEST_DIR)/liquidmon/crontab
	(cd $(CORE_DEST_DIR)/liquidmon; tar xzf $(RRD_SOURCE).tar.gz)

perllibs: 
	mkdir -p $(CORE_DEST_DIR)/liquidmon/lib
	(cd $(CORE_DEST_DIR)/liquidmon/lib; \
	tar xzf $(PERL_LIB_SOURCE)/builds/perllib.tgz)
	cp -R $(BUILD_ROOT)/lib/Liquid $(CORE_DEST_DIR)/liquidmon/lib

perllibsbuild: 
	mkdir -p $(TMPDIR)
	@for lib in $(PERL_LIBS); do \
		echo "Compiling perl lib $$lib"; \
		cp $(PERL_LIB_SOURCE)/$$lib.tar.gz $(TMPDIR); \
		(cd $(TMPDIR); tar xzf $$lib.tar.gz; cd $$lib; \
		$(PERL) -I$(CORE_DEST_DIR)/liquidmon/lib Makefile.PL PREFIX=$(CORE_DEST_DIR)/liquidmon/ LIB=$(CORE_DEST_DIR)/liquidmon/lib; \
		make; make install;) \
	done

	@for lib in $(DBD_PERL_LIBS); do \
		cp $(PERL_LIB_SOURCE)/$$lib.tar.gz $(TMPDIR); \
		(cd $(TMPDIR); tar xzf $$lib.tar.gz; cd $$lib; \
		$(PERL) -I$(CORE_DEST_DIR)/liquidmon/lib Makefile.PL PREFIX=$(CORE_DEST_DIR)/liquidmon/ LIB=$(CORE_DEST_DIR)/liquidmon/lib --mysql_config=/opt/liquid/mysql/bin/mysql_config --libs="-L/usr/lib -lmysqlclient -lz -lcrypt -lnsl -lm"; \
		make; make install;) \
	done	

	@for lib in $(SA_PERL_LIBS); do \
		cp $(PERL_LIB_SOURCE)/$$lib.tar.gz $(TMPDIR); \
		(cd $(TMPDIR); tar xzf $$lib.tar.gz; cd $$lib; \
		$(PERL) -I$(CORE_DEST_DIR)/liquidmon/lib Makefile.PL PREFIX=$(CORE_DEST_DIR)/liquidmon/ LIB=$(CORE_DEST_DIR)/liquidmon/lib DATADIR=$(CORE_DEST_DIR)/liquidmon/share CONFDIR=$(CORE_DEST_DIR)/liquidmon/spamassassin; \
		make; make install;) \
	done	

	(cd $(CORE_DEST_DIR)/liquidmon/lib; tar czf $(CORE_DEST_DIR)/perllib.tgz .)

$(MTA_DEST_DIR)/$(POSTFIX_DIR): $(MTA_DEST_DIR)
	@echo "*** Creating postfix"
	(cd $(MTA_DEST_DIR); tar xzf $(POSTFIX_SOURCE).tgz;)
	cp $(SERVICE_DIR)/conf/postfix/main.cf $(MTA_DEST_DIR)/$(POSTFIX_DIR)/conf/main.cf
	cp $(SERVICE_DIR)/conf/postfix/master.cf $(MTA_DEST_DIR)/$(POSTFIX_DIR)/conf/master.cf

$(DEST_DIR)/$(MYSQL_DIR):
	@echo "*** Creating mysql"
	(cd $(DEST_DIR); tar xzf $(MYSQL_SOURCE).tar.gz;)

$(CORE_DEST_DIR)/lib: $(WEBAPP_DIR)/service.war $(LDAP_DEST_DIR)/$(LDAP_DIR) $(MTA_DEST_DIR)/$(BDB_DIR)
	mkdir -p $@
	cp -pr $(SERVICE_DIR)/build/dist/lib/* $@
	cp -pr $(LDAP_DEST_DIR)/$(LDAP_DIR)/lib/* $@
	cp -pr $(MTA_DEST_DIR)/$(BDB_DIR)/lib/* $@
	cp -pr $(SERVICE_DIR)/build/dist/lib/* $@
	cp $(THIRD_PARTY)/curl/curl.tgz $@
	cp $(THIRD_PARTY)/idn/idn.tgz $@
	(cd $@; tar xzf $(THIRD_PARTY)/mysql/mysql-standard-4.1.10a-clientlibs.tgz)

$(CORE_DEST_DIR)/jdk1.5.0_04:
	@echo "*** Creating java"
	(cd $(CORE_DEST_DIR); tar xzf $(JAVA_SOURCE).tgz;)

$(DEST_DIR)/$(TOMCAT_DIR): $(DEST_DIR)
	@echo "*** Creating tomcat"
	(cd $(DEST_DIR); tar xzf $(TOMCAT_SOURCE).tar.gz;)
	cp $(THIRD_PARTY)/jakarta-tomcat/jmxri.jar $(DEST_DIR)/$(TOMCAT_DIR)/bin/jmx.jar
	cp $(SERVICE_DIR)/conf/tomcat-5.5/server.xml.production $(DEST_DIR)/$(TOMCAT_DIR)/conf/server.xml
	cp $(SERVICE_DIR)/conf/liquid.xml $(DEST_DIR)/$(TOMCAT_DIR)/conf/Catalina/localhost/liquid.xml
	mkdir -p $(DEST_DIR)/$(TOMCAT_DIR)/conf/AdminService/localhost
	cp $(SERVICE_DIR)/conf/liquidAdmin.xml $(DEST_DIR)/$(TOMCAT_DIR)/conf/AdminService/localhost/liquidAdmin.xml
	cp $(SERVICE_DIR)/conf/tomcat-5.5/tomcat-users.xml $(DEST_DIR)/$(TOMCAT_DIR)/conf
	cp -f $(SERVICE_DIR)/conf/log4j.properties.production  $(DEST_DIR)/$(TOMCAT_DIR)/conf/log4j.properties
	mkdir -p $(DEST_DIR)/$(TOMCAT_DIR)/temp
	touch $(DEST_DIR)/$(TOMCAT_DIR)/temp/.emptyfile

$(DEST_DIR)/verity:
	mkdir -p $@/conf
	cp -R $(VERITY_SOURCE)/ExportSDK $@
	cp -R $(VERITY_SOURCE)/FilterSDK $@
	cp $(VERITY_SOURCE)/../conf/mimetypes.properties $@/conf

$(LDAP_DEST_DIR)/$(LDAP_DIR): $(LDAP_DEST_DIR) 
	@echo "*** Creating openldap"
	(cd $(LDAP_DEST_DIR); tar xzf $(LDAP_SOURCE).tgz;)
	cp $(SERVICE_DIR)/conf/ldap/DB_CONFIG $(LDAP_DEST_DIR)/$(LDAP_DIR)/var/openldap-data
	cp $(SERVICE_DIR)/conf/ldap/slapd.conf $(LDAP_DEST_DIR)/$(LDAP_DIR)/etc/openldap/slapd.conf
	cp $(SERVICE_DIR)/conf/ldap/amavisd.schema $(LDAP_DEST_DIR)/$(LDAP_DIR)/etc/openldap/schema
	cp $(SERVICE_DIR)/conf/ldap/liquid.schema $(LDAP_DEST_DIR)/$(LDAP_DIR)/etc/openldap/schema
	cp $(SERVICE_DIR)/conf/ldap/liquid.ldif $(LDAP_DEST_DIR)/$(LDAP_DIR)/etc/openldap/liquid.ldif
	cp $(SERVICE_DIR)/conf/ldap/liquid_opensrc_mimehandlers.ldif $(LDAP_DEST_DIR)/$(LDAP_DIR)/etc/openldap/liquid_opensrc_mimehandlers.ldif
	cp $(SERVICE_DIR)/build/dist/openldap-2.2.17/etc/openldap/liquid_mimehandlers.ldif $(LDAP_DEST_DIR)/$(LDAP_DIR)/etc/openldap/liquid_mimehandlers.ldif
	cp $(SERVICE_DIR)/conf/ldap/widgets.ldif $(LDAP_DEST_DIR)/$(LDAP_DIR)/etc/openldap/widgets.ldif

$(MTA_DEST_DIR)/$(CLAMAV_DIR): $(MTA_DEST_DIR)
	@echo "*** Creating clamav"
	(cd $(MTA_DEST_DIR); tar xzf $(CLAMAV_SOURCE).tgz;)
	mkdir -p $(MTA_DEST_DIR)/$(CLAMAV_DIR)-$(CLAMAV_VERSION)/db
	cp $(RPM_CONF_DIR)/main.cvd $(MTA_DEST_DIR)/$(CLAMAV_DIR)-$(CLAMAV_VERSION)/db/main.cvd.init
	cp $(RPM_CONF_DIR)/daily.cvd $(MTA_DEST_DIR)/$(CLAMAV_DIR)-$(CLAMAV_VERSION)/db/daily.cvd.init

$(MTA_DEST_DIR)/$(AMAVISD_DIR): $(MTA_DEST_DIR)
	@echo "*** Creating amavisd"
	mkdir -p $@/sbin
	cp -f $(AMAVISD_SOURCE)/amavisd $@/sbin
	mkdir -p $@/.spamassassin/init
	cp -f $(RPM_CONF_DIR)/bayes* $@/.spamassassin/init

$(MTA_DEST_DIR)/$(SASL_DIR): $(MTA_DEST_DIR)
	@echo "*** Creating cyrus-sasl"
	(cd $(MTA_DEST_DIR); tar xzf $(SASL_SOURCE).tgz;)
	mkdir -p $(MTA_DEST_DIR)/$(SASL_DIR)-$(SASL_VERSION)/etc
	cp -f $(SERVICE_DIR)/conf/saslauthd.conf.in $(MTA_DEST_DIR)/$(SASL_DIR)-$(SASL_VERSION)/etc/
	cp -f $(SERVICE_DIR)/conf/postfix_sasl_smtpd.conf $(MTA_DEST_DIR)/$(SASL_DIR)-$(SASL_VERSION)/lib/sasl2/smtpd.conf

$(MTA_DEST_DIR)/$(BDB_DIR): $(MTA_DEST_DIR)
	@echo "*** Creating sleepycat"
	(cd $(MTA_DEST_DIR); tar xzf $(BDB_SOURCE).tgz; chmod u+w $(BDB_DIR)/bin/*)

$(WEBAPP_DIR): $(DEST_DIR)/$(TOMCAT_DIR)
	mkdir -p $@

$(WEBAPP_DIR)/service.war: $(WEBAPP_DIR)
	(cd $(CONVERT_DIR); $(ANT) -Dliquid.buildinfo.version=$(MAJOR).$(MINOR)_$(BUILD_PLATFORM) -Dliquid.buildinfo.release=$(RELEASE) -Dliquid.buildinfo.date=$(DATE) -Dliquid.buildinfo.host=$(HOST) dev-dist)
	(cd $(BACKUP_DIR); $(ANT) -Dliquid.buildinfo.version=$(MAJOR).$(MINOR)_$(BUILD_PLATFORM) -Dliquid.buildinfo.release=$(RELEASE) -Dliquid.buildinfo.date=$(DATE) -Dliquid.buildinfo.host=$(HOST) dev-dist)
	(cd $(SERVICE_DIR);  \
	cp build/dist/jakarta-tomcat-5.0.28/webapps/service.war $@)

$(WEBAPP_DIR)/liquidAdmin.war: $(WEBAPP_DIR)
	(cd $(CONSOLE_DIR); $(ANT) admin-war; \
	cp build/dist/jakarta-tomcat-5.0.28/webapps/liquidAdmin.war $@)

$(WEBAPP_DIR)/liquid.war: $(WEBAPP_DIR)
	(cd $(CONSOLE_DIR); $(ANT) prod-war; \
	cp build/dist/jakarta-tomcat-5.0.28/webapps/liquid.war $@)

$(DEST_DIR)/$(TOMCAT_DIR)/common/lib/mail.jar: $(DEST_DIR)/$(TOMCAT_DIR) $(WEBAPP_DIR)/service.war
	mkdir -p $(DEST_DIR)/$(TOMCAT_DIR)/common/lib
	cp $(SERVICE_DIR)/build/dist/lib/mail.jar $(DEST_DIR)/$(TOMCAT_DIR)/common/lib

$(DEST_DIR)/$(TOMCAT_DIR)/common/endorsed/liquidcharset.jar: $(DEST_DIR)/$(TOMCAT_DIR) $(WEBAPP_DIR)/service.war
	cp $(SERVICE_DIR)/build/dist/lib/liquidcharset.jar $(DEST_DIR)/$(TOMCAT_DIR)/common/endorsed

$(DEST_DIR)/$(TOMCAT_DIR)/common/lib/activation.jar: $(DEST_DIR)/$(TOMCAT_DIR) $(WEBAPP_DIR)/service.war
	mkdir -p $(DEST_DIR)/$(TOMCAT_DIR)/common/lib
	cp $(SERVICE_DIR)/build/dist/lib/activation.jar $(DEST_DIR)/$(TOMCAT_DIR)/common/lib

$(DEST_DIR)/$(TOMCAT_DIR)/common/lib/KeyView.jar: $(DEST_DIR)/$(TOMCAT_DIR) $(WEBAPP_DIR)/service.war
	mkdir -p $(DEST_DIR)/$(TOMCAT_DIR)/common/lib
	cp $(SERVICE_DIR)/build/dist/lib/KeyView.jar $(DEST_DIR)/$(TOMCAT_DIR)/common/lib

$(DEST_DIR)/$(TOMCAT_DIR)/common/lib/liquidos.jar: $(DEST_DIR)/$(TOMCAT_DIR) $(WEBAPP_DIR)/service.war
	mkdir -p $(DEST_DIR)/$(TOMCAT_DIR)/common/lib
	cp $(SERVICE_DIR)/build/dist/lib/liquidos.jar $(DEST_DIR)/$(TOMCAT_DIR)/common/lib

$(DEST_DIR)/libexec:
	mkdir -p $@
	cp -R $(SERVICE_DIR)/libexec/[a-z]* $@
	cp -R $(SERVICE_DIR)/src/libexec/[a-z]* $@
	#cp -R $(BUILD_ROOT)/lqhac.pl $@
	#cp -R $(BUILD_ROOT)/lqhad.pl $@

$(CORE_DEST_DIR)/db: $(WEBAPP_DIR)/service.war
	mkdir -p $@
	cp -R $(SERVICE_DIR)/src/db/db.sql $@
	cp -R $(SERVICE_DIR)/src/db/create_database.sql $@
	cp -R $(SERVICE_DIR)/build/versions-init.sql $@

$(CORE_DEST_DIR)/conf:
	mkdir -p $@
	cp $(RPM_CONF_DIR)/swatchrc $@/swatchrc.in
	cp -R $(SERVICE_DIR)/conf/localconfig.xml $@/localconfig.xml
	grep -vi stats $(SERVICE_DIR)/conf/log4j.properties.production > $@/log4j.properties
	cp $(RPM_CONF_DIR)/liqssl.cnf.in $@
	cp $(SERVICE_DIR)/conf/amavisd.conf.in $@
	cp $(SERVICE_DIR)/conf/clamd.conf.in $@
	cp $(SERVICE_DIR)/conf/freshclam.conf.in $@
	cp $(SERVICE_DIR)/conf/postfix_header_checks.in $@
	cp $(SERVICE_DIR)/conf/salocal.cf $@
	cp $(SERVICE_DIR)/conf/lqmta.cf $@
	cp $(SERVICE_DIR)/conf/postfix_recipient_restrictions.cf $@
	mkdir -p $@/spamassassin
	cp $(SERVICE_DIR)/conf/spamassassin/* $@/spamassassin

$(CORE_DEST_DIR)/bin:
	mkdir -p $@
	cp -R $(SERVICE_DIR)/build/dist/bin/[a-z]* $@
	cp -R $(CONVERT_DIR)/src/bin/[a-z]* $@
	rm -f $(CORE_DEST_DIR)/bin/lqtransserver.bat
	rm -f $(CORE_DEST_DIR)/bin/ldap
	mv $(CORE_DEST_DIR)/bin/ldap.production $(CORE_DEST_DIR)/bin/ldap
	cp $(LIQUID_BIN_DIR)/swatch $@
	cp $(LIQUID_BIN_DIR)/swatchctl $@
	cp $(LIQUID_BIN_DIR)/lqloadstats $@
	cp $(LIQUID_BIN_DIR)/lqaggregatestats $@
	cp $(LIQUID_BIN_DIR)/lqaggregatestatsdaily $@
	cp $(LIQUID_BIN_DIR)/lqgetstats $@
	cp $(LIQUID_BIN_DIR)/lqlogrotate $@
	cp $(LIQUID_BIN_DIR)/lqsnmpinit $@
	cp $(LIQUID_BIN_DIR)/lqgengraphs $@
	cp $(LIQUID_BIN_DIR)/lqgensystemwidegraphs $@
	cp $(LIQUID_BIN_DIR)/lqfetchstats $@
	cp $(LIQUID_BIN_DIR)/lqfetchallstats $@
	cp $(LIQUID_BIN_DIR)/lqcreatecert $@
	cp $(LIQUID_BIN_DIR)/lqcertinstall $@
	cp $(LIQUID_BIN_DIR)/roll_catalina.sh $@
	cp $(LIQUID_BIN_DIR)/lqtlsctl $@
	cp $(LIQUID_BIN_DIR)/lqfixperms.sh $@

clean:
	rm -rf $(CLEAN_TARGETS)

allclean: clean
	(cd $(SERVICE_DIR); $(ANT) clean)
	(cd $(CONVERT_DIR); $(ANT) clean)
	(cd $(BACKUP_DIR); $(ANT) clean)
	(cd $(CONSOLE_DIR); $(ANT) clean)
	(cd $(QA_DIR); $(ANT) clean)

#
# Dev installs
#

dev-allclean:
	-su - liquid -c lqcontrol shutdown
	rm -rf $(DEV_INSTALL_ROOT)/*

dev-clean: dev-stop
	rm -rf $(DEV_CLEAN_TARGETS)

$(DEV_INSTALL_ROOT):
	mkdir -p $@

dev-mta-install: $(DEV_INSTALL_ROOT)/$(POSTFIX_DIR) 
	rm -f $(DEV_INSTALL_ROOT)/postfix
	ln -s $(DEV_INSTALL_ROOT)/$(POSTFIX_DIR) $(DEV_INSTALL_ROOT)/postfix
	echo "*** MTA Install complete"

$(DEV_INSTALL_ROOT)/$(POSTFIX_DIR): $(DEV_INSTALL_ROOT)
	@echo "*** Installing postfix"
	(cd $(DEV_INSTALL_ROOT); tar xzf $(POSTFIX_SOURCE).tgz;)
	cp -f $(SERVICE_DIR)/conf/postfix/main.cf $(DEV_INSTALL_ROOT)/$(POSTFIX_DIR)/conf/main.cf
	cp -f $(SERVICE_DIR)/conf/postfix/master.cf $(DEV_INSTALL_ROOT)/$(POSTFIX_DIR)/conf/master.cf
	sh -x $(LIQUID_BIN_DIR)/lqfixperms.sh

$(DEV_INSTALL_ROOT)/$(CLAMAV_DIR): $(DEV_INSTALL_ROOT)
	@echo "*** Installing clamav"
	(cd $(DEV_INSTALL_ROOT); tar xzf $(CLAMAV_SOURCE).tgz;)
	mkdir -p $(DEV_INSTALL_ROOT)/$(CLAMAV_DIR)-$(CLAMAV_VERSION)/db
	cp -f $(RPM_CONF_DIR)/main.cvd $(DEV_INSTALL_ROOT)/$(CLAMAV_DIR)-$(CLAMAV_VERSION)/db/main.cvd.init
	cp -f $(RPM_CONF_DIR)/daily.cvd $(DEV_INSTALL_ROOT)/$(CLAMAV_DIR)-$(CLAMAV_VERSION)/db/daily.cvd.init

dev-install: $(DEV_INSTALL_ROOT)/$(MYSQL_DIR) $(DEV_INSTALL_ROOT)/$(LDAP_DIR) $(DEV_INSTALL_ROOT)/$(TOMCAT_DIR) $(DEV_INSTALL_ROOT)/$(CLAMAV_DIR) $(DEV_INSTALL_ROOT)/$(AMAVISD_DIR) $(DEV_INSTALL_ROOT)/liquidmon $(DEV_INSTALL_ROOT)/db $(DEV_INSTALL_ROOT)/lib $(DEV_INSTALL_ROOT)/bin $(DEV_INSTALL_ROOT)/conf $(DEV_INSTALL_ROOT)/$(JAVA_FILE)$(JAVA_VERSION) $(DEV_INSTALL_ROOT)/$(BDB_DIR)
	rm -f $(DEV_INSTALL_ROOT)/clamav $(DEV_INSTALL_ROOT)/tomcat $(DEV_INSTALL_ROOT)/mysql $(DEV_INSTALL_ROOT)/openlap
	ln -s $(DEV_INSTALL_ROOT)/$(CLAMAV_DIR)-$(CLAMAV_VERSION) $(DEV_INSTALL_ROOT)/clamav
	ln -s $(DEV_INSTALL_ROOT)/$(TOMCAT_DIR) $(DEV_INSTALL_ROOT)/tomcat
	ln -s $(DEV_INSTALL_ROOT)/$(MYSQL_DIR) $(DEV_INSTALL_ROOT)/mysql
	ln -s $(DEV_INSTALL_ROOT)/$(LDAP_DIR) $(DEV_INSTALL_ROOT)/openldap
	ln -s $(DEV_INSTALL_ROOT)/$(JAVA_FILE)$(JAVA_VERSION) $(DEV_INSTALL_ROOT)/java
	ln -s $(DEV_INSTALL_ROOT)/$(BDB_DIR) $(DEV_INSTALL_ROOT)/sleepycat
	@echo "*** Installation complete"

$(SERVICE_DIR)/build/dist/jakarta-tomcat-5.0.28/webapps/service.war:
	(cd $(CONVERT_DIR); $(ANT) -Dliquid.buildinfo.version=$(MAJOR).$(MINOR)_$(BUILD_PLATFORM) -Dliquid.buildinfo.release=$(RELEASE) -Dliquid.buildinfo.date=$(DATE) -Dliquid.buildinfo.host=$(HOST) dev-dist ; )
	(cd $(BACKUP_DIR); $(ANT) -Dliquid.buildinfo.version=$(MAJOR).$(MINOR)_$(BUILD_PLATFORM) -Dliquid.buildinfo.release=$(RELEASE) -Dliquid.buildinfo.date=$(DATE) -Dliquid.buildinfo.host=$(HOST) dev-dist ; )

$(CONSOLE_DIR)/build/dist/jakarta-tomcat-5.0.28/webapps/liquid.war: 
	(cd $(CONSOLE_DIR); $(ANT) clean)
	(cd $(CONSOLE_DIR); $(ANT) prod-war; )

$(DEV_INSTALL_ROOT)/$(MYSQL_DIR): $(DEV_INSTALL_ROOT)
	@echo "*** Installing mysql"
	(cd $(DEV_INSTALL_ROOT); tar xzf $(MYSQL_SOURCE).tar.gz;)

$(DEV_INSTALL_ROOT)/$(LDAP_DIR): $(DEV_INSTALL_ROOT)
	@echo "*** Installing openldap"
	(cd $(DEV_INSTALL_ROOT); tar xzf $(LDAP_SOURCE).tgz;)
	cp -f $(SERVICE_DIR)/conf/ldap/DB_CONFIG $@/var/openldap-data
	cp -f $(SERVICE_DIR)/conf/ldap/slapd.conf $@/etc/openldap/slapd.conf
	cp -f $(SERVICE_DIR)/conf/ldap/amavisd.schema $@/etc/openldap/schema
	cp -f $(SERVICE_DIR)/conf/ldap/liquid.schema $@/etc/openldap/schema
	cp -f $(SERVICE_DIR)/conf/ldap/liquid.ldif $@/etc/openldap/liquid.ldif
	cp -f $(SERVICE_DIR)/conf/ldap/widgets.ldif $@/etc/openldap/widgets.ldif

$(DEV_INSTALL_ROOT)/$(TOMCAT_DIR): $(DEV_INSTALL_ROOT) $(SERVICE_DIR)/build/dist/jakarta-tomcat-5.0.28/webapps/service.war  $(CONSOLE_DIR)/build/dist/jakarta-tomcat-5.0.28/webapps/liquid.war
	@echo "*** Installing tomcat"
	(cd $(DEV_INSTALL_ROOT); tar xzf $(TOMCAT_SOURCE).tar.gz;)
	cp -f $(THIRD_PARTY)/jakarta-tomcat/jmxri.jar $@/bin/jmx.jar
	cp -f $(SERVICE_DIR)/conf/tomcat-5.5/server.xml.production $@/conf/server.xml
	cp -f $(SERVICE_DIR)/conf/liquid.xml $@/conf/Catalina/localhost/liquid.xml
	mkdir -p $@/conf/AdminService/localhost
	cp -f $(SERVICE_DIR)/conf/liquidAdmin.xml $@/conf/AdminService/localhost/liquidAdmin.xml
	cp -f $(SERVICE_DIR)/conf/tomcat-5.5/tomcat-users.xml $@/conf
	cp -f $(SERVICE_DIR)/conf/log4j.properties.production  $@/conf/log4j.properties
	mkdir -p $@/temp
	touch $@/temp/.emptyfile

$(DEV_INSTALL_ROOT)/$(AMAVISD_DIR): $(DEV_INSTALL_ROOT)
	@echo "*** Installing amavisd"
	mkdir -p $@/sbin
	cp -f $(AMAVISD_SOURCE)/amavisd $@/sbin
	mkdir -p $@/.spamassassin/init
	cp -f $(RPM_CONF_DIR)/bayes* $@/.spamassassin/init

devperllibs: 
	mkdir -p $(DEV_INSTALL_ROOT)/liquidmon/lib
	(cd $(DEV_INSTALL_ROOT)/liquidmon/lib; \
	tar xzf $(PERL_LIB_SOURCE)/builds/perllib.tgz)
	cp -fR $(BUILD_ROOT)/lib/Liquid $(DEV_INSTALL_ROOT)/liquidmon/lib

$(DEV_INSTALL_ROOT)/liquidmon: $(DEV_INSTALL_ROOT) devperllibs
	@echo "*** Installing liquidmon"
	mkdir -p $@
	cp -f -R $(LIQUIDMON_DIR)/lqmon $@
	chmod 755 $@/lqmon
	cp -f -R $(LIQUIDMON_DIR)/lqcontrol $@
	chmod 755 $@/lqcontrol
	cp -f -R $(RPM_CONF_DIR)/liquid.cf.in $@
	cp -f -R $(RPM_CONF_DIR)/liquidcore.cf $@
	cp -f -R $(RPM_CONF_DIR)/liquidmail.cf $@
	cp -f -R $(RPM_CONF_DIR)/liquidmta.cf $@
	cp -f -R $(RPM_CONF_DIR)/liquidldap.cf $@
	cp -f -R $(RPM_CONF_DIR)/liquidsnmp.cf $@
	mkdir -p $@/lib/liquidpm
	@cp -f $(wildcard $(BUILD_ROOT)/lib/liquidpm/*.pm) $@/lib/liquidpm
	mkdir -p $@/lib/liquidpm/SOAP
	@cp -f $(wildcard $(SERVICE_DIR)/src/perl/soap/*.pm) $@/lib/liquidpm/SOAP
	(cd $(DEV_INSTALL_ROOT)/liquidmon; tar xzf $(MRTG_SOURCE).tgz)
	mkdir -p $(DEV_INSTALL_ROOT)/liquidmon/mrtg/work
	mkdir -p $(DEV_INSTALL_ROOT)/liquidmon/mrtg/conf
	cp -f $(RPM_CONF_DIR)/mrtg.cfg $(DEV_INSTALL_ROOT)/liquidmon/mrtg/conf
	cp -f $(RPM_CONF_DIR)/crontab $(DEV_INSTALL_ROOT)/liquidmon/crontab
	(cd $(DEV_INSTALL_ROOT)/liquidmon; tar xzf $(RRD_SOURCE).tar.gz)

$(DEV_INSTALL_ROOT)/db:
	@echo "*** Installing db"
	mkdir -p $@
	cp -f -R $(SERVICE_DIR)/src/db/db.sql $@
	cp -f -R $(SERVICE_DIR)/src/db/create_database.sql $@
	cp -f -R $(SERVICE_DIR)/build/versions-init.sql $@

$(DEV_INSTALL_ROOT)/$(BDB_DIR): $(DEV_INSTALL_ROOT)
	@echo "*** Installing sleepycat"
	(cd $(DEV_INSTALL_ROOT); tar xzf $(BDB_SOURCE).tgz; chmod u+w $(BDB_DIR)/bin/*)

$(DEV_INSTALL_ROOT)/lib: $(DEV_INSTALL_ROOT)/$(LDAP_DIR) $(DEV_INSTALL_ROOT)/$(BDB_DIR)
	@echo "*** Installing lib"
	mkdir -p $@
	cp -f -pr $(SERVICE_DIR)/build/dist/lib/* $@
	cp -f -pr $(DEV_INSTALL_ROOT)/$(LDAP_DIR)/lib/* $@
	cp -f -pr $(DEV_INSTALL_ROOT)/$(BDB_DIR)/lib/* $@
	cp -f -pr $(SERVICE_DIR)/build/dist/lib/* $@
	cp -f $(THIRD_PARTY)/curl/curl.tgz $@
	cp -f $(THIRD_PARTY)/idn/idn.tgz $@
	(cd $@; tar xzf $(THIRD_PARTY)/mysql/mysql-standard-4.1.10a-clientlibs.tgz)

$(DEV_INSTALL_ROOT)/bin:
	@echo "*** Installing bin"
	mkdir -p $@
	cp -f -R $(SERVICE_DIR)/build/dist/bin/[a-z]* $@
	rm -f $(DEV_INSTALL_ROOT)/bin/lqtransserver.bat
	rm -f $(DEV_INSTALL_ROOT)/bin/ldap
	mv $@/ldap.production $@/ldap
	cp -f $(LIQUID_BIN_DIR)/swatch $@
	cp -f $(LIQUID_BIN_DIR)/swatchctl $@
	cp -f $(LIQUID_BIN_DIR)/lqloadstats $@
	cp -f $(LIQUID_BIN_DIR)/lqaggregatestats $@
	cp -f $(LIQUID_BIN_DIR)/lqaggregatestatsdaily $@
	cp -f $(LIQUID_BIN_DIR)/lqgetstats $@
	cp -f $(LIQUID_BIN_DIR)/lqlogrotate $@
	cp -f $(LIQUID_BIN_DIR)/lqsnmpinit $@
	cp -f $(LIQUID_BIN_DIR)/lqgengraphs $@
	cp -f $(LIQUID_BIN_DIR)/lqgensystemwidegraphs $@
	cp -f $(LIQUID_BIN_DIR)/lqfetchstats $@
	cp -f $(LIQUID_BIN_DIR)/lqfetchallstats $@
	cp -f $(LIQUID_BIN_DIR)/lqcreatecert $@
	cp -f $(LIQUID_BIN_DIR)/roll_catalina.sh $@
	cp -f $(LIQUID_BIN_DIR)/lqtlsctl $@
	cp -f $(LIQUID_BIN_DIR)/lqfixperms.sh $@
	chmod u+x $@/*

$(DEV_INSTALL_ROOT)/conf:
	@echo "*** Installing conf"
	mkdir -p $@
	cp -f $(RPM_CONF_DIR)/swatchrc $@/swatchrc.in
	cp -f -R $(SERVICE_DIR)/conf/localconfig.xml $@/localconfig.xml
	grep -vi stats $(SERVICE_DIR)/conf/log4j.properties.production > $@/log4j.properties
	cp -f $(RPM_CONF_DIR)/liqssl.cnf.in $@
	cp -f $(SERVICE_DIR)/conf/amavisd.conf.in $@
	cp -f $(SERVICE_DIR)/conf/clamd.conf $@
	cp -f $(SERVICE_DIR)/conf/freshclam.conf $@
	cp -f $(SERVICE_DIR)/conf/salocal.cf $@
	mkdir -p $@/spamassassin
	cp -f $(SERVICE_DIR)/conf/spamassassin/* $@/spamassassin

$(DEV_INSTALL_ROOT)/$(JAVA_FILE)$(JAVA_VERSION):
	@echo "*** Installing $(JAVA_FILE)$(JAVA_VERSION)"
	(cd $(DEV_INSTALL_ROOT); tar xzf $(JAVA_SOURCE).tgz;)

dev-stop:
	-$(DEV_INSTALL_ROOT)/bin/mysql.server stop
	-$(DEV_INSTALL_ROOT)/bin/ldap stop
	-$(DEV_INSTALL_ROOT)/bin/tomcat stop
	-$(DEV_INSTALL_ROOT)/bin/postfix stop
