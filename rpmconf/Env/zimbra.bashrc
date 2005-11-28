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

PATH=/opt/zimbra/bin:/opt/zimbra/zimbramon:/opt/zimbra/postfix-2.2.5/sbin:/opt/zimbra/openldap/bin:${JAVA_HOME}/bin:/opt/zimbra/snmp/bin:${PATH}
export PATH

LD_LIBRARY_PATH=/opt/zimbra/lib:${LD_LIBRARY_PATH}
export LD_LIBRARY_PATH

SNMPCONFPATH=/opt/zimbra/conf
export SNMPCONFPATH

PERLLIB=/opt/zimbra/zimbramon/lib:/opt/zimbra/zimbramon/lib/i386-linux-thread-multi:/opt/zimbra/zimbramon/lib/i586-linux-thread-multi:/opt/zimbra/zimbramon/lib/darwin-thread-multi-2level
export PERLLIB
