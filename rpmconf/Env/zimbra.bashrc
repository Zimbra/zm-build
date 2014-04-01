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

if [ -x "/opt/zimbra/libexec/get_plat_tag.sh" ]; then
  ZCS_PLATFORM=$(/opt/zimbra/libexec/get_plat_tag.sh)
else 
  ZCS_PLATFORM=unknown
fi

JAVA_HOME=/opt/zimbra/java
export JAVA_HOME

if [[ $ZCS_PLATFORM == MACOSXx86_10.* && x$ZCS_PLATFORM != "xMACOSXx86_10.7" ]]; then
  JAVA_JVM_VERSION=CurrentJDK
  export JAVA_JVM_VERSION
fi

PATH=/opt/zimbra/bin:/opt/zimbra/postfix/sbin:/opt/zimbra/openldap/bin:/opt/zimbra/snmp/bin:/opt/zimbra/rsync/bin:/opt/zimbra/bdb/bin:/opt/zimbra/openssl/bin:${JAVA_HOME}/bin:/usr/sbin:${PATH}
export PATH

if [ `uname -s` == "Darwin" ]; then
  unset DYLD_LIBRARY_PATH
else 
  unset LD_LIBRARY_PATH
fi

SNMPCONFPATH=/opt/zimbra/conf
export SNMPCONFPATH

eval `/usr/bin/perl -V:archname`
PERLLIB=/opt/zimbra/zimbramon/lib/$archname:/opt/zimbra/zimbramon/lib
export PERLLIB

PERL5LIB=$PERLLIB
export PERL5LIB

JYTHONPATH=/opt/zimbra/zimbramon/pylibs
export JYTHONPATH

ulimit -n 524288 > /dev/null 2>&1
umask 0027

unset DISPLAY

export MANPATH=/opt/zimbra/pflogsumm/man:/opt/zimbra/opendkim/share/man:/opt/zimbra/unbound/share/man:${MANPATH}
