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

JAVA_HOME=/opt/zimbra/java
export JAVA_HOME

JAVA_JVM_VERSION=1.5
export JAVA_JVM_VERSION

PATH=/opt/zimbra/bin:/opt/zimbra/zimbramon:/opt/zimbra/postfix/sbin:/opt/zimbra/openldap/bin:/opt/zimbra/snmp/bin:/opt/zimbra/bdb/bin:/opt/zimbra/openssl/bin:${JAVA_HOME}/bin:${PATH}
export PATH

unset LD_LIBRARY_PATH

if [ `uname -s` == "Darwin" ]; then
  unset DYLD_LIBRARY_PATH
fi

SNMPCONFPATH=/opt/zimbra/conf
export SNMPCONFPATH

eval `/usr/bin/perl -V:archname`
PERLLIB=/opt/zimbra/zimbramon/lib/$archname:/opt/zimbra/zimbramon/lib
export PERLLIB

PERL5LIB=$PERLLIB
export PERL5LIB

ulimit -n 524288 > /dev/null 2>&1
umask 0027
