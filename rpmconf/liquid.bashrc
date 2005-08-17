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

LIQUID_HOME=/opt/liquid
export LIQUID_HOME

JAVA_HOME=/opt/liquid/java
export JAVA_HOME

PATH=/opt/liquid/bin:/opt/liquid/liquidmon:/opt/liquid/postfix-2.2.3/sbin:/opt/liquid/openldap/bin:${JAVA_HOME}/bin:/opt/liquid/snmp/bin:${PATH}
export PATH

LD_LIBRARY_PATH=/opt/liquid/lib:${LD_LIBRARY_PATH}
export LD_LIBRARY_PATH

SNMPCONFPATH=/opt/liquid/conf
export SNMPCONFPATH

PERLLIB=/opt/liquid/liquidmon/lib:/opt/liquid/liquidmon/lib/i386-linux-thread-multi/; 
export PERLLIB
