# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias h='history 40'
alias j='jobs'

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

ZIMBRA_HOME=/opt/zimbra
export ZIMBRA_HOME

if [ -x "${ZIMBRA_HOME}/libexec/get_plat_tag.sh" ]; then
  ZCS_PLATFORM=$(${ZIMBRA_HOME}/libexec/get_plat_tag.sh)
else 
  ZCS_PLATFORM=unknown
fi

JAVA_HOME=${ZIMBRA_HOME}/java
export JAVA_HOME

if [ x"$ZCS_PLATFORM" = "xMACOSXx86_10.6" ]; then
  JAVA_JVM_VERSION=1.6
else
  JAVA_JVM_VERSION=1.5
fi
export JAVA_JVM_VERSION

PATH=${ZIMBRA_HOME}/bin:${ZIMBRA_HOME}/postfix/sbin:${ZIMBRA_HOME}/openldap/bin:${ZIMBRA_HOME}/snmp/bin:${ZIMBRA_HOME}/bdb/bin:${ZIMBRA_HOME}/openssl/bin:${JAVA_HOME}/bin:/usr/sbin:${PATH}
export PATH

if [ `uname -s` == "Darwin" ]; then
  unset DYLD_LIBRARY_PATH
else 
  unset LD_LIBRARY_PATH
fi

SNMPCONFPATH=${ZIMBRA_HOME}/conf
export SNMPCONFPATH

eval `/usr/bin/perl -V:archname`
PERLLIB=${ZIMBRA_HOME}/zimbramon/lib/$archname:${ZIMBRA_HOME}/zimbramon/lib
export PERLLIB

PERL5LIB=$PERLLIB
export PERL5LIB

JYTHONPATH=/opt/zimbra/zimbramon/pylibs
export JYTHONPATH

ulimit -n 524288 > /dev/null 2>&1
umask 0027
